AuthorityRoles = {}
local Ok, Err = Authority.Ok, Authority.Err

local function Key(value)
    return type(value) == 'string' and #value >= 3 and #value <= 100
        and value:match('^[a-z][a-z0-9_]*%.[a-z][a-z0-9_.]*$') ~= nil
        and value:sub(-1) ~= '.' and not value:find('..', 1, true)
end
local function Text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and not value:find('%c') and value:find('%S') ~= nil
end
local function RequestToken(value, maximum, lower)
    if type(value) ~= 'string' or #value < 1 or #value > maximum then return false end
    local pattern = lower and '^[a-z][a-z0-9._:%-]*$' or '^[A-Za-z0-9][A-Za-z0-9._:%-]*$'
    return value:match(pattern) ~= nil
end

function AuthorityRoles.ValidateCreate(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Role creation request required.') end
    local fields = { requestId = true, roleKey = true, label = true, roleClass = true, reasonCode = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected role creation field.') end
    end
    if not RequestToken(request.requestId, 128, false) or not Key(request.roleKey)
        or not Text(request.label, 100) or (request.roleClass ~= 'staff' and request.roleClass ~= 'rp')
        or not RequestToken(request.reasonCode, 64, true)
        or request.roleKey:sub(1, #request.roleClass + 1) ~= request.roleClass .. '.' then
        return Err('invalid_input', 'Stable request ID, class-bound role key, label, and reason code required.')
    end
    local fingerprint = {}
    for _, field in ipairs({ 'roleKey', 'label', 'roleClass', 'reasonCode' }) do
        fingerprint[#fingerprint + 1] = tostring(#request[field]) .. ':' .. request[field]
    end
    return Ok(table.concat(fingerprint))
end

local function Snapshot(row)
    if not row then return Err('role_not_found', 'Authority role was not found.') end
    local revision = tonumber(row.revision)
    if not Authority.Uuid(row.role_id) or not Key(row.role_key) or not Text(row.label, 100)
        or (row.role_class ~= 'staff' and row.role_class ~= 'rp')
        or row.role_key:sub(1, #row.role_class + 1) ~= row.role_class .. '.'
        or type(row.owner_resource) ~= 'string' or #row.owner_resource < 1 or #row.owner_resource > 100
        or (row.status ~= 'active' and row.status ~= 'retired')
        or not Authority.Integer(revision, 1, 9007199254740991) then
        return Err('invalid_persistence', 'Persisted Authority role is invalid.')
    end
    return Ok({
        roleId = row.role_id,
        roleKey = row.role_key,
        label = row.label,
        roleClass = row.role_class,
        ownerResource = row.owner_resource,
        status = row.status,
        revision = revision
    })
end

function AuthorityRoles.Get(request, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or not Authority.Uuid(request.roleId) then
        return Err('invalid_input', 'Role UUID required.')
    end
    for field in pairs(request) do
        if field ~= 'roleId' then return Err('invalid_input', 'Unexpected role read field.') end
    end
    return Snapshot(DB.one('SELECT * FROM `feather_authority_roles` WHERE `role_id`=?',
        request.roleId:lower()
    ))
end

function AuthorityRoles.Find(request, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table' or not Key(request.roleKey) then
        return Err('invalid_input', 'Role key required.')
    end
    for field in pairs(request) do
        if field ~= 'roleKey' then return Err('invalid_input', 'Unexpected role lookup field.') end
    end
    return Snapshot(DB.one('SELECT * FROM `feather_authority_roles` WHERE `role_key`=?',
        request.roleKey
    ))
end

function AuthorityRoles.Create(request, resource)
    if Config.Access.trustedRoleCreators[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted role creator.')
    end
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = AuthorityRoles.ValidateCreate(request)
    if not valid.ok then return valid end
    request = Authority.Copy(request)
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            tx.exec([[INSERT IGNORE INTO `feather_authority_role_creation_receipts`
                (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)]],
                resource, request.requestId, valid.value)
            local receipts = tx.query([[SELECT `request_fingerprint`,`result_json`
                FROM `feather_authority_role_creation_receipts`
                WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], resource, request.requestId) or {}
            local receipt = receipts[1]
            if not receipt then return Err('internal_error', 'Role creation receipt could not be reserved.') end
            if receipt.request_fingerprint ~= valid.value then
                return Err('idempotency_conflict', 'Request ID is bound to a different role payload.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' or not Authority.Uuid(value.roleId)
                    or value.roleKey ~= request.roleKey or value.label ~= request.label
                    or value.roleClass ~= request.roleClass or value.status ~= 'active' or value.revision ~= 1 then
                    return Err('invalid_persistence', 'Stored role creation receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local ids = tx.query('SELECT UUID() AS `role_id`,UUID() AS `event_id`') or {}
            local id, eventId = ids[1] and ids[1].role_id, ids[1] and ids[1].event_id
            if not Authority.Uuid(id) or not Authority.Uuid(eventId) then
                return Err('internal_error', 'Could not generate Authority role identities.')
            end
            tx.exec([[INSERT IGNORE INTO `feather_authority_roles`
                (`role_id`,`role_key`,`label`,`role_class`,`owner_resource`) VALUES (?,?,?,?,?)]], id, request.roleKey, request.label, request.roleClass, resource)
            local rows = tx.query('SELECT * FROM `feather_authority_roles` WHERE `role_key`=? FOR UPDATE', request.roleKey) or {}
            if not rows[1] or rows[1].role_id ~= id then
                return Err('role_key_conflict', 'Role key is already reserved.')
            end
            local created = Snapshot(rows[1])
            if not created.ok then return created end
            created.value.replayed = false
            tx.exec([[INSERT INTO `feather_authority_role_events`
                (`event_id`,`role_id`,`event_type`,`source_resource`,`request_id`,`reason_code`,`revision`)
                VALUES (?,?,'authority.role.created',?,?,?,1)]], eventId, id, resource, request.requestId, request.reasonCode)
            tx.exec([[UPDATE `feather_authority_role_creation_receipts` SET `result_json`=?
                WHERE `source_resource`=? AND `request_id`=?]], json.encode(created.value), resource, request.requestId)
            tx.exec('UPDATE `feather_authority_policy_state` SET `policy_version`=`policy_version`+1 WHERE `id`=1')
            return created
        end, debug.traceback)
        if not executed then
            print('[feather-authority] role creation transaction failed: ' .. tostring(outcome))
            result = Err('internal_error', 'Role creation transaction failed.')
            return false
        end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Role creation did not confirm commit. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Role creation did not complete. Retry the same request ID.')
end

local function Boundary(operation, request)
    local called, result = xpcall(function() return operation(request, GetInvokingResource()) end, debug.traceback)
    if not called then
        print('[feather-authority] API failure: ' .. tostring(result))
        return Err('internal_error', 'Authority role operation failed.')
    end
    return result
end

exports('CreateRole', function(request) return Boundary(AuthorityRoles.Create, request) end)
exports('GetRole', function(request) return Boundary(AuthorityRoles.Get, request) end)
exports('FindRoleByKey', function(request) return Boundary(AuthorityRoles.Find, request) end)
