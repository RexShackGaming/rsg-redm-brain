FeatherAuditAuthorization = {}

local function forbidden()
    return { ok = false, code = 'forbidden', message = 'Audit read is not permitted.' }
end

local function identityFor(actorSource)
    if type(actorSource) ~= 'number' or actorSource < 1 or actorSource % 1 ~= 0 then return nil end
    local core = exports['feather-core']
    local session = core:GetSessionContext(actorSource)
    if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table' then return nil end
    local value = session.value
    if type(value.accountId) ~= 'string' or type(value.characterId) ~= 'string'
        or type(value.sessionId) ~= 'string' then return nil end
    local provider = core:GetProvider('policy', 'feather-authority', 1)
    if type(provider) ~= 'table' or not provider.ok or type(provider.value) ~= 'table'
        or type(provider.value.provider) ~= 'table'
        or provider.value.provider.owner ~= 'feather-authority'
        or type(provider.value.implementation) ~= 'table' then return nil end
    local function evaluate(capability)
        local called, decision = pcall(provider.value.implementation.Evaluate, capability, {
            source = actorSource, accountId = value.accountId, characterId = value.characterId,
            caller = 'feather-audit', subject = { resource = 'feather-audit' }
        })
        if not called or type(decision) ~= 'table' or decision.ok ~= true
            or type(decision.value) ~= 'table' or type(decision.value.allowed) ~= 'boolean'
            or type(decision.value.policyVersion) ~= 'number'
            or decision.value.policyVersion < 1 or decision.value.policyVersion % 1 ~= 0 then return nil end
        return decision.value
    end
    local search = evaluate('staff.admin.audit.search')
    if not search or not search.allowed then return nil end
    local sensitive = evaluate('staff.admin.audit.sensitive.view')
    if not sensitive or sensitive.policyVersion ~= search.policyVersion then return nil end
    local latest = core:GetSessionContext(actorSource)
    if type(latest) ~= 'table' or not latest.ok or type(latest.value) ~= 'table'
        or latest.value.sessionId ~= value.sessionId or latest.value.accountId ~= value.accountId
        or latest.value.characterId ~= value.characterId or latest.value.generation ~= value.generation then return nil end
    return { allowed = true, type = 'character', id = value.characterId, accountId = value.accountId,
        sessionId = value.sessionId, generation = value.generation,
        sensitive = sensitive.allowed, policyVersion = search.policyVersion }
end

function FeatherAuditAuthorization.Search(request, actorSource, caller, operation)
    -- Only trusted server adapters may supply a player source. No client event.
    local trusted = caller == 'feather-admin'
        or (caller == 'feather-audit-smoke-producer' and Config.Development.smokeCommands == true)
    if not trusted then return forbidden() end
    local identity = identityFor(actorSource)
    if not identity then return forbidden() end
    identity.caller = caller
    if not FeatherAudit.GetHealth().ready then
        return { ok = false, code = 'unavailable', message = 'Audit is unavailable.' }
    end
    if not FeatherAuditRateLimit.Allow('search:' .. actorSource, 30) then
        return { ok = false, code = 'rate_limited', message = 'Audit read rate exceeded.' }
    end
    local result = FeatherAuditSearch.Read(request, identity, operation)
    if not result.ok then return result end
    local paused = FeatherAuditReadPause and FeatherAuditReadPause.Await(actorSource, identity.sessionId)
    -- DB/provider calls can yield: discard results after logout, source reuse,
    -- assignment revocation, or loss of sensitive-read permission.
    local current = identityFor(actorSource)
    if not current or current.id ~= identity.id or current.accountId ~= identity.accountId
        or current.sessionId ~= identity.sessionId
        or current.generation ~= identity.generation
        or (identity.sensitive and not current.sensitive) then
        local denied = forbidden()
        if paused then denied.meta = { developmentPauseCompleted = true } end
        return denied
    end
    return result
end
