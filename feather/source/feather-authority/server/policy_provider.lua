AuthorityPolicy = {}
local installed = false

local function Decision(allowed, code, reason, policyVersion, evidence)
    local value = { allowed = allowed == true, code = code, reason = reason,
        policyVersion = policyVersion }
    if type(evidence) == 'table' then
        value.assignmentId = evidence.assignmentId
        value.roleId = evidence.roleId
        value.grantId = evidence.grantId
    end
    return Authority.Ok(value)
end

function AuthorityPolicy.Evaluate(action, context)
    if type(action) ~= 'string' or type(context) ~= 'table' then
        return Authority.Err('invalid_input', 'Policy action and authenticated context are required.')
    end
    if tonumber(context.source) == nil or tonumber(context.source) <= 0
        or not Authority.Uuid(context.accountId) or not Authority.Uuid(context.characterId) then
        return Decision(false, 'unsupported_subject', 'Authority requires a connected account and active character.')
    end
    local session = exports['feather-core']:GetSessionContext(tonumber(context.source))
    if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
        or session.value.accountId ~= context.accountId
        or session.value.characterId ~= context.characterId then
        return Decision(false, 'subject_mismatch', 'Authority context does not match the active character session.')
    end
    local result = AuthorityEvaluation.Evaluate({ subjectType = 'character',
        subjectId = context.characterId, capabilityKey = action, scopeType = 'server' },
        GetCurrentResourceName())
    if not result.ok then return result end
    return Decision(result.value.allowed, result.value.allowed and 'allowed' or 'forbidden',
        result.value.reason, result.value.policyVersion, result.value)
end

function AuthorityPolicy.Install()
    if installed then return Authority.Ok(true) end
    local result = exports['feather-core']:RegisterPolicyProvider('feather-authority', {
        Evaluate = AuthorityPolicy.Evaluate
    }, {
        contract = 1,
        default = false,
        capabilities = { characterSubjects = 1, serverScope = 1, policyVersion = 1 }
    })
    if type(result) ~= 'table' or not result.ok then
        return Authority.Err('provider_registration_failed',
            type(result) == 'table' and result.message or 'Core returned an invalid provider result.')
    end
    installed = true
    return Authority.Ok(true)
end

function AuthorityPolicy.IsInstalled() return installed end
