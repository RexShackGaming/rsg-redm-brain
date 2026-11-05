AuthorityGrants = {}
local Ok, Err = Authority.Ok, Authority.Err

local function Token(value, maximum, lower)
    if type(value) ~= 'string' or #value < 1 or #value > maximum then return false end
    return value:match(lower and '^[a-z][a-z0-9._:%-]*$'
        or '^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end
local function CapabilityKey(value)
    return type(value) == 'string' and #value >= 3 and #value <= 100
        and value:match('^[a-z][a-z0-9_]*%.[a-z][a-z0-9_.]*$') ~= nil
        and value:sub(-1) ~= '.' and not value:find('..', 1, true)
end

function AuthorityGrants.ValidateIssue(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Role grant request required.') end
    local fields = { requestId = true, roleId = true, capabilityKey = true,
        expectedRevision = true, scopeType = true, reasonCode = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected role grant field.') end
    end
    if not Token(request.requestId, 128, false) or not Authority.Uuid(request.roleId)
        or not CapabilityKey(request.capabilityKey)
        or not Authority.Integer(request.expectedRevision, 1, 9007199254740991)
        or (request.scopeType ~= 'server' and request.scopeType ~= 'organization')
        or not Token(request.reasonCode, 64, true) then
        return Err('invalid_input', 'Stable request ID, role, capability, revision, scope, and reason are required.')
    end
    local fingerprint = {}
    for _, field in ipairs({ 'roleId', 'capabilityKey', 'expectedRevision', 'scopeType', 'reasonCode' }) do
        local value = tostring(request[field])
        fingerprint[#fingerprint + 1] = tostring(#value) .. ':' .. value
    end
    return Ok(table.concat(fingerprint))
end

function AuthorityGrants.Issue(request, resource)
    if Config.Access.trustedGrantors[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted grantor.')
    end
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = AuthorityGrants.ValidateIssue(request)
    if not valid.ok then return valid end
    request = Authority.Copy(request)
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_authority_role_grant_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]],
                resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json` FROM
                `feather_authority_role_grant_receipts` WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]],
                resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Err('internal_error', 'Grant receipt could not be reserved.') end
            if receipt.request_fingerprint ~= valid.value then
                return Err('idempotency_conflict', 'Request ID is bound to a different grant payload.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' or not Authority.Uuid(value.grantId) then
                    return Err('invalid_persistence', 'Stored grant receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local roles = tx.query('SELECT * FROM `feather_authority_roles` WHERE `role_id`=? FOR UPDATE',
                request.roleId:lower()) or {}
            local role = roles[1]
            if not role then return Err('role_not_found', 'Authority role was not found.') end
            if role.status ~= 'active' then return Err('role_inactive', 'Authority role is not active.') end
            if tonumber(role.revision) ~= request.expectedRevision then
                return Err('revision_conflict', 'Authority role revision changed.')
            end
            local capabilities = tx.query([[SELECT `capability_id`,`capability_key`,`status` FROM
                `feather_authority_capabilities` WHERE `capability_key`=? FOR UPDATE]],
                request.capabilityKey) or {}
            local capability = capabilities[1]
            if not capability then return Err('capability_not_found', 'Capability was not found.') end
            if capability.status ~= 'active' then return Err('capability_inactive', 'Capability is not active.') end
            if request.capabilityKey:sub(1, #role.role_class + 1) ~= role.role_class .. '.' then
                return Err('class_mismatch', 'Role and capability namespaces must match.')
            end
            local ids = tx.query('SELECT UUID() AS `grant_id`,UUID() AS `event_id`') or {}
            local grantId, eventId = ids[1] and ids[1].grant_id, ids[1] and ids[1].event_id
            tx.exec([[INSERT IGNORE INTO `feather_authority_role_grants`
                (`grant_id`,`role_id`,`capability_id`,`scope_type`) VALUES (?,?,?,?)]],
                grantId, request.roleId:lower(), capability.capability_id, request.scopeType)
            local grants = tx.query([[SELECT `grant_id`,`status`,`revision` FROM `feather_authority_role_grants`
                WHERE `role_id`=? AND `capability_id`=? AND `scope_type`=? FOR UPDATE]],
                request.roleId:lower(), capability.capability_id, request.scopeType) or {}
            if not grants[1] or grants[1].grant_id ~= grantId then
                return Err('grant_conflict', 'That role grant already exists.')
            end
            tx.exec('UPDATE `feather_authority_roles` SET `revision`=`revision`+1 WHERE `role_id`=?',
                request.roleId:lower())
            local value = { grantId = grantId, roleId = request.roleId:lower(),
                capabilityKey = request.capabilityKey, effect = 'allow', scopeType = request.scopeType,
                status = 'active', revision = 1, roleRevision = request.expectedRevision + 1, replayed = false }
            tx.exec([[INSERT INTO `feather_authority_role_events`
                (`event_id`,`role_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`)
                VALUES (?,?,'authority.role.grant_added',?,?,?,?)]],
                eventId, request.roleId:lower(), resource, request.requestId,
                    request.reasonCode, value.roleRevision)
            tx.exec([[UPDATE `feather_authority_role_grant_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]],
                json.encode(value), resource, request.requestId)
            tx.exec('UPDATE `feather_authority_policy_state` SET `policy_version`=`policy_version`+1 WHERE `id`=1')
            return Ok(value)
        end, debug.traceback)
        if not executed then result = Err('internal_error', 'Grant transaction failed.'); return false end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Grant did not confirm commit. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Grant did not complete. Retry the same request ID.')
end

function AuthorityGrants.List(request, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or not Authority.Uuid(request.roleId) then
        return Err('invalid_input', 'Role UUID required.')
    end
    for field in pairs(request) do
        if field ~= 'roleId' then return Err('invalid_input', 'Unexpected role grant read field.') end
    end
    local rows = DB.query([[SELECT g.`grant_id`,g.`role_id`,c.`capability_key`,g.`effect`,
        g.`scope_type`,g.`status`,g.`revision` FROM `feather_authority_role_grants` g
        JOIN `feather_authority_capabilities` c ON c.`capability_id`=g.`capability_id`
        WHERE g.`role_id`=? ORDER BY c.`capability_key` LIMIT 129]], request.roleId:lower()) or {}
    if #rows > 128 then return Err('grant_catalog_limit', 'Role grant catalog exceeds 128 entries.') end
    local result = {}
    for _, row in ipairs(rows) do
        if not Authority.Uuid(row.grant_id) or row.effect ~= 'allow'
            or (row.scope_type ~= 'server' and row.scope_type ~= 'organization')
            or (row.status ~= 'active' and row.status ~= 'revoked') then
            return Err('invalid_persistence', 'Persisted role grant is invalid.')
        end
        result[#result + 1] = { grantId = row.grant_id, roleId = row.role_id,
            capabilityKey = row.capability_key, effect = row.effect, scopeType = row.scope_type,
            status = row.status, revision = tonumber(row.revision) }
    end
    return Ok(result)
end

exports('GrantRoleCapability', function(request)
    local called, result = xpcall(function()
        return AuthorityGrants.Issue(request, GetInvokingResource())
    end, debug.traceback)
    if not called then
        print('[feather-authority] grant API failure: ' .. tostring(result))
        return Err('internal_error', 'Authority grant operation failed.')
    end
    return result
end)
exports('ListRoleGrants', function(request)
    return AuthorityGrants.List(request, GetInvokingResource())
end)
