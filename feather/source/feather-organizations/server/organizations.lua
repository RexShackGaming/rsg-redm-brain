OrganizationIdentity = {}
local Ok, Err = Organizations.Ok, Organizations.Err
local function Key(value, maximum)
    return type(value) == 'string' and #value <= maximum
        and value:match('^[a-z][a-z0-9_]*$') ~= nil
end
local function Text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and not value:find('%c') and value:find('%S') ~= nil
end
function OrganizationIdentity.Validate(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Creation request required.') end
    local fields = { requestId = true, organizationType = true, organizationKey = true,
        legalName = true, displayName = true, reasonCode = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected creation request field.') end
    end
    if type(request.requestId) ~= 'string' or #request.requestId > 128
        or not request.requestId:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$')
        or not Key(request.organizationType, 48) or not Key(request.organizationKey, 64)
        or not Text(request.legalName, 160) or not Text(request.displayName, 100)
        or type(request.reasonCode) ~= 'string' or #request.reasonCode > 64
        or not request.reasonCode:match('^[a-z][a-z0-9._:%-]*$') then
        return Err('invalid_input', 'Stable request ID, type/key, names, and reason code required.')
    end
    -- Length-prefix each field: display names may contain delimiter characters.
    local fingerprint = {}
    for _, field in ipairs({ 'organizationType', 'organizationKey', 'legalName', 'displayName', 'reasonCode' }) do
        fingerprint[#fingerprint + 1] = tostring(#request[field]) .. ':' .. request[field]
    end
    return Ok(table.concat(fingerprint))
end
local function Snapshot(row)
    if not row then return Err('organization_not_found', 'Organization not found.') end
    if not Organizations.Uuid(row.organization_id) or not Organizations.Uuid(row.organization_type_id)
        or not Organizations.Integer(tonumber(row.revision), 1, 9007199254740991)
        or not Key(row.organization_key,64) or not Key(row.type_key,48)
        or not Text(row.legal_name,160) or not Text(row.display_name,100)
        or (row.parent_organization_id~=nil and not Organizations.Uuid(row.parent_organization_id))
        or (row.status~='pending' and row.status~='active' and row.status~='suspended'
            and row.status~='dissolving' and row.status~='dissolved') then
        return Err('invalid_persistence', 'Persisted organization identity is invalid.')
    end
    return Ok({ organizationId = row.organization_id, organizationTypeId = row.organization_type_id,
        organizationType = row.type_key, organizationKey = row.organization_key,
        legalName = row.legal_name, displayName = row.display_name,
        status = row.status, revision = tonumber(row.revision), parentOrganizationId = row.parent_organization_id })
end
local selectIdentity = [[SELECT o.*,t.`type_key`,p.`parent_organization_id` FROM `feather_organizations` o
    JOIN `feather_organization_types` t ON t.`organization_type_id`=o.`organization_type_id`
    LEFT JOIN `feather_organization_parents` p ON p.`organization_id`=o.`organization_id`]]
OrganizationIdentity.Snapshot = Snapshot
OrganizationIdentity.SelectSql = selectIdentity
function OrganizationIdentity.Get(request, resource)
    local allowed = Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or not Organizations.Uuid(request.organizationId) then
        return Err('invalid_input', 'Organization UUID required.')
    end
    for field in pairs(request) do
        if field ~= 'organizationId' then return Err('invalid_input', 'Unexpected read field.') end
    end
    return Snapshot(DB.one(selectIdentity .. ' WHERE o.`organization_id`=?', request.organizationId:lower()))
end
function OrganizationIdentity.Find(request, resource)
    local allowed = Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or not Key(request.organizationKey, 64) then
        return Err('invalid_input', 'Organization key required.')
    end
    for field in pairs(request) do
        if field ~= 'organizationKey' then return Err('invalid_input', 'Unexpected lookup field.') end
    end
    return Snapshot(DB.one(selectIdentity .. ' WHERE o.`organization_key`=?', request.organizationKey))
end
function OrganizationIdentity.Create(request, resource)
    if Config.Access.trustedCreators[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted creator.')
    end
    local allowed = Organizations.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = OrganizationIdentity.Validate(request)
    if not valid.ok then return valid end
    request = Organizations.Copy(request)
    if Config.Authorization.enabled then
        local decision = exports['feather-core']:Authorize(Config.Authorization.createAction, {
            correlationId = request.requestId,
            subject = { resource = resource, organizationType = request.organizationType,
                organizationKey = request.organizationKey }
        })
        if type(decision) ~= 'table' or not decision.ok or type(decision.value) ~= 'table'
            or decision.value.allowed ~= true then return Err('authorization_denied', 'Creation policy denied.') end
    end
    local current = Organizations.CheckRead(resource)
    if not current.ok then return current end
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_organization_creation_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]], resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json`
                FROM `feather_organization_creation_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Err('internal_error', 'Creation receipt could not be reserved.') end
            if receipt.request_fingerprint ~= valid.value then
                return Err('idempotency_conflict', 'Request ID is bound to a different creation payload.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' or not Organizations.Uuid(value.organizationId)
                    or value.organizationKey ~= request.organizationKey or value.organizationType ~= request.organizationType
                    or value.legalName ~= request.legalName or value.displayName ~= request.displayName
                    or value.status ~= 'pending' or value.revision ~= 1 then
                    return Err('invalid_persistence', 'Stored creation receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local events = tx.query([[SELECT `event_id` FROM `feather_organization_events`
                WHERE `source_resource`=? AND `request_id`=?]], resource, request.requestId) or {}
            if #events > 0 then
                return Err('idempotency_conflict', 'Request ID already belongs to another organization operation.')
            end
            local types = tx.query([[SELECT `organization_type_id`,`status` FROM `feather_organization_types`
                WHERE `type_key`=? FOR UPDATE]], request.organizationType) or {}
            if not types[1] then return Err('type_not_found', 'Organization type not found.') end
            if types[1].status ~= 'active' then return Err('type_retired', 'Organization type is retired.') end
            local ids = tx.query('SELECT UUID() AS id') or {}
            local id = ids[1] and ids[1].id
            if not Organizations.Uuid(id) then return Err('internal_error', 'Could not generate organization UUID.') end
            tx.exec([[INSERT IGNORE INTO `feather_organizations`
                (`organization_id`,`organization_type_id`,`organization_key`,`legal_name`,`display_name`,`created_by_resource`)
                VALUES (?,?,?,?,?,?)]], id, types[1].organization_type_id, request.organizationKey,
                    request.legalName, request.displayName, resource)
            local rows = tx.query(selectIdentity .. ' WHERE o.`organization_key`=? FOR UPDATE', request.organizationKey) or {}
            if not rows[1] or rows[1].organization_id ~= id then
                return Err('organization_key_conflict', 'Organization key is already reserved.')
            end
            local created = Snapshot(rows[1])
            if not created.ok then return created end
            created.value.replayed = false
            OrganizationEvents.Record(tx,id,'organization.created',resource,request.requestId,request.reasonCode,1,
                {status=created.value.status,organizationType=request.organizationType})
            tx.exec([[UPDATE `feather_organization_creation_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]], json.encode(created.value), resource, request.requestId)
            return created
        end, debug.traceback)
        if not executed then
            print('[feather-organizations] creation transaction failed: ' .. tostring(outcome))
            result = Err('internal_error', 'Creation transaction failed.')
            return false
        end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Creation did not confirm commit. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Creation did not complete. Retry the same request ID.')
end
local function Boundary(operation, request)
    local called, result = xpcall(function() return operation(request, GetInvokingResource()) end, debug.traceback)
    if not called then
        print('[feather-organizations] API failure: ' .. tostring(result))
        return Err('internal_error', 'Organization operation failed.')
    end
    return result
end
exports('CreateOrganization', function(request) return Boundary(OrganizationIdentity.Create, request) end)
exports('GetOrganization', function(request) return Boundary(OrganizationIdentity.Get, request) end)
exports('FindOrganizationByKey', function(request) return Boundary(OrganizationIdentity.Find, request) end)
