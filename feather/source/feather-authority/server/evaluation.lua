AuthorityEvaluation = {}
local Ok, Err = Authority.Ok, Authority.Err

local function CapabilityKey(value)
    return type(value) == 'string' and #value >= 3 and #value <= 100
        and value:match('^[a-z][a-z0-9_]*%.[a-z][a-z0-9_.]*$') ~= nil
        and value:sub(-1) ~= '.' and not value:find('..', 1, true)
end

function AuthorityEvaluation.Validate(request)
    if type(request) ~= 'table' then return Err('invalid_input', 'Evaluation request required.') end
    local fields = { subjectType = true, subjectId = true, capabilityKey = true, scopeType = true }
    for field in pairs(request) do
        if not fields[field] then return Err('invalid_input', 'Unexpected evaluation field.') end
    end
    if (request.subjectType ~= 'account' and request.subjectType ~= 'character')
        or not Authority.Uuid(request.subjectId)
        or not CapabilityKey(request.capabilityKey) or request.scopeType ~= 'server' then
        return Err('invalid_input', 'Subject, capability, and server scope are required.')
    end
    return Ok(true)
end

local function Decision(allowed, reason, policyVersion, assignmentId, roleId, grantId)
    return Ok({ allowed = allowed == true, reason = reason, policyVersion = policyVersion,
        assignmentId = assignmentId, roleId = roleId, grantId = grantId })
end

function AuthorityEvaluation.Evaluate(request, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    local valid = AuthorityEvaluation.Validate(request)
    if not valid.ok then return valid end
    local policyVersion = tonumber(DB.value(
        'SELECT `policy_version` FROM `feather_authority_policy_state` WHERE `id`=1'))
    if not Authority.Integer(policyVersion, 1, 9007199254740991) then
        return Err('invalid_persistence', 'Authority policy version is invalid.')
    end
    local capability = DB.one([[SELECT `capability_id`,`status` FROM
        `feather_authority_capabilities` WHERE `capability_key`=?]], request.capabilityKey)
    if not capability or capability.status ~= 'active' then
        return Decision(false, 'capability_unavailable', policyVersion)
    end
    local row = DB.one([[SELECT a.`assignment_id`,a.`role_id`,g.`grant_id`
        FROM `feather_authority_assignments` a
        JOIN `feather_authority_roles` r ON r.`role_id`=a.`role_id` AND r.`status`='active'
        JOIN `feather_authority_role_grants` g ON g.`role_id`=r.`role_id`
            AND g.`capability_id`=? AND g.`effect`='allow' AND g.`scope_type`='server'
            AND g.`status`='active'
        WHERE a.`subject_type`=? AND a.`subject_id`=? AND a.`scope_type`='server'
            AND a.`status`='active' AND (a.`valid_until` IS NULL OR a.`valid_until`>CURRENT_TIMESTAMP)
        ORDER BY a.`assignment_id` LIMIT 1]], capability.capability_id, request.subjectType, request.subjectId:lower())
    if not row then return Decision(false, 'no_active_assignment', policyVersion) end
    return Decision(true, 'explicit_role_grant', policyVersion,
        row.assignment_id, row.role_id, row.grant_id)
end

function AuthorityEvaluation.ListEffective(request, resource)
    local allowed = Authority.CheckRead(resource)
    if not allowed.ok then return allowed end
    if type(request) ~= 'table'
        or (request.subjectType ~= 'account' and request.subjectType ~= 'character')
        or not Authority.Uuid(request.subjectId) or request.scopeType ~= 'server' then
        return Err('invalid_input', 'Subject and server scope are required.')
    end
    for field in pairs(request) do
        if field ~= 'subjectType' and field ~= 'subjectId' and field ~= 'scopeType' then
            return Err('invalid_input', 'Unexpected effective-capability field.')
        end
    end
    local policyVersion = tonumber(DB.value(
        'SELECT `policy_version` FROM `feather_authority_policy_state` WHERE `id`=1'))
    if not Authority.Integer(policyVersion, 1, 9007199254740991) then
        return Err('invalid_persistence', 'Authority policy version is invalid.')
    end
    local rows = DB.query([[SELECT DISTINCT c.`capability_key`
        FROM `feather_authority_assignments` a
        JOIN `feather_authority_roles` r ON r.`role_id`=a.`role_id` AND r.`status`='active'
        JOIN `feather_authority_role_grants` g ON g.`role_id`=r.`role_id`
            AND g.`effect`='allow' AND g.`scope_type`='server' AND g.`status`='active'
        JOIN `feather_authority_capabilities` c ON c.`capability_id`=g.`capability_id`
            AND c.`status`='active'
        WHERE a.`subject_type`=? AND a.`subject_id`=? AND a.`scope_type`='server'
            AND a.`status`='active' AND (a.`valid_until` IS NULL OR a.`valid_until`>CURRENT_TIMESTAMP)
        ORDER BY c.`capability_key` LIMIT 129]], request.subjectType, request.subjectId:lower()) or {}
    if #rows > 128 then return Err('capability_catalog_limit', 'Effective capability result exceeds 128.') end
    local capabilities = {}
    for _, row in ipairs(rows) do
        if not CapabilityKey(row.capability_key) then
            return Err('invalid_persistence', 'Effective capability key is invalid.')
        end
        capabilities[#capabilities + 1] = row.capability_key
    end
    return Ok({ capabilities = capabilities, policyVersion = policyVersion })
end

exports('Evaluate', function(request)
    local called, result = xpcall(function()
        return AuthorityEvaluation.Evaluate(request, GetInvokingResource())
    end, debug.traceback)
    if not called then return Err('internal_error', 'Authority evaluation failed.') end
    return result
end)
exports('ListEffectiveCapabilities', function(request)
    local called, result = xpcall(function()
        return AuthorityEvaluation.ListEffective(request, GetInvokingResource())
    end, debug.traceback)
    if not called then return Err('internal_error', 'Effective capability read failed.') end
    return result
end)
