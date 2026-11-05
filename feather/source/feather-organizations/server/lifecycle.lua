OrganizationLifecycle = {}
local Ok, Err = Organizations.Ok, Organizations.Err
local transitions = {
    pending = { active = true, dissolving = true },
    active = { suspended = true, dissolving = true },
    suspended = { active = true, dissolving = true },
    dissolving = { dissolved = true },
    dissolved = {}
}
function OrganizationLifecycle.CanTransition(from, to)
    return transitions[from] ~= nil and transitions[from][to] == true
end
function OrganizationLifecycle.Validate(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Lifecycle request required.') end
    local fields = { organizationId = true, expectedRevision = true, status = true,
        requestId = true, reasonCode = true }
    for key in pairs(request) do
        if not fields[key] then return Err('invalid_input', 'Unexpected lifecycle field.') end
    end
    if not Organizations.Uuid(request.organizationId)
        or not Organizations.Integer(request.expectedRevision, 1, 9007199254740990)
        or type(request.status) ~= 'string' or not transitions[request.status]
        or type(request.requestId) ~= 'string' or #request.requestId > 128
        or not request.requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or type(request.reasonCode) ~= 'string' or #request.reasonCode > 64
        or not request.reasonCode:match('^[a-z][a-z0-9._:%-]*$') then
        return Err('invalid_input', 'Organization UUID, integer revision, status, stable request ID and reason required.')
    end
    return Ok(table.concat({ request.organizationId:lower(), tostring(request.expectedRevision),
        request.status, request.reasonCode }, '|'))
end
function OrganizationLifecycle.Change(request, resource)
    if Config.Access.trustedMutators[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted lifecycle mutator.')
    end
    local allowed = Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = OrganizationLifecycle.Validate(request)
    if not valid.ok then return valid end
    request = Organizations.Copy(request); request.organizationId = request.organizationId:lower()
    if Config.Authorization.enabled then
        local action = request.status == 'suspended' and Config.Authorization.suspendAction
            or (request.status == 'dissolving' or request.status == 'dissolved') and Config.Authorization.dissolveAction
            or Config.Authorization.updateAction
        local decision = exports['feather-core']:Authorize(action, {
            correlationId = request.requestId, subject = { resource = resource,
                organizationId = request.organizationId, status = request.status }
        })
        if type(decision) ~= 'table' or not decision.ok or type(decision.value) ~= 'table'
            or decision.value.allowed ~= true then return Err('authorization_denied', 'Lifecycle policy denied.') end
    end
    local current = Organizations.CheckRead(resource)
    if not current.ok then return current end
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_organization_lifecycle_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]], resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json`
                FROM `feather_organization_lifecycle_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Err('internal_error', 'Could not reserve lifecycle receipt.') end
            if receipt.request_fingerprint ~= valid.value then
                return Err('idempotency_conflict', 'Lifecycle request ID is bound to another payload.')
            end
            local rows = tx.query([[SELECT `organization_id`,`status`,`revision`,`created_by_resource`
                FROM `feather_organizations` WHERE `organization_id`=? FOR UPDATE]], request.organizationId) or {}
            local organization = rows[1]
            if not organization then return Err('organization_not_found', 'Organization not found.') end
            if organization.created_by_resource ~= resource and Config.Access.privilegedMutators[resource] ~= true then
                return Err('authorization_denied', 'Caller does not own this organization lifecycle.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' or value.organizationId ~= request.organizationId
                    or value.status ~= request.status or value.revision ~= request.expectedRevision + 1
                    or not OrganizationLifecycle.CanTransition(value.previousStatus, value.status) then
                    return Err('invalid_persistence', 'Stored lifecycle receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local events = tx.query([[SELECT `event_id` FROM `feather_organization_events`
                WHERE `source_resource`=? AND `request_id`=?]], resource, request.requestId) or {}
            if #events > 0 then return Err('idempotency_conflict', 'Request ID already belongs to another organization operation.') end
            local revision = tonumber(organization.revision)
            if not Organizations.Integer(revision, 1, 9007199254740990) or not transitions[organization.status] then
                return Err('invalid_persistence', 'Persisted lifecycle is invalid.')
            end
            if revision ~= request.expectedRevision then return Err('revision_conflict', 'Organization revision changed.') end
            if not OrganizationLifecycle.CanTransition(organization.status, request.status) then
                return Err('invalid_transition', 'Organization status transition is not allowed.')
            end
            tx.exec([[UPDATE `feather_organizations` SET `status`=?,`revision`=`revision`+1
                WHERE `organization_id`=? AND `revision`=?]], request.status, request.organizationId, revision)
            OrganizationEvents.Record(tx,request.organizationId,'organization.status_changed',resource,
                request.requestId,request.reasonCode,revision+1,{status=request.status,previousStatus=organization.status})
            local value = { organizationId = request.organizationId, previousStatus = organization.status,
                status = request.status, revision = revision + 1, replayed = false }
            tx.exec([[UPDATE `feather_organization_lifecycle_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]], json.encode(value), resource, request.requestId)
            return Ok(value)
        end, debug.traceback)
        if not executed then
            print('[feather-organizations] lifecycle transaction failed: ' .. tostring(outcome))
            result = Err('internal_error', 'Lifecycle transaction failed.'); return false
        end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Lifecycle commit was not confirmed. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Lifecycle did not complete. Retry the same request ID.')
end
exports('ChangeOrganizationStatus', function(request)
    local called, result = xpcall(function() return OrganizationLifecycle.Change(request, GetInvokingResource()) end, debug.traceback)
    if not called then
        print('[feather-organizations] lifecycle API failed: ' .. tostring(result))
        return Err('internal_error', 'Lifecycle operation failed.')
    end
    return result
end)
