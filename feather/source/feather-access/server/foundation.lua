Access = {}

local health = { state = 'starting', phase = 'not_started', contract = 1 }
function Access.LocalReady() return health.state == 'ready' end

function Access.Copy(value)
    if type(value) ~= 'table' then return value end
    local snapshot = {}
    for key, child in pairs(value) do snapshot[key] = Access.Copy(child) end
    return snapshot
end

function Access.Ok(value) return { ok = true, value = value } end

function Access.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end

function Access.Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

function Access.SetState(state, phase, failure)
    -- Dependency loss requires an explicit restart, even if startup later resumes.
    if health.state == 'failed' and state ~= 'failed' and state ~= 'stopped' then return end
    health.state, health.phase, health.failure = state, phase, Access.Copy(failure)
    print(('[feather-access] event=lifecycle.changed state=%s phase=%s'):format(state, phase))
end

function Access.Fail(result)
    Access.SetState('failed', 'dependency_or_startup_failure', result)
    return result
end

function Access.GetHealth()
    if health.state == 'ready' then
        local called, result = pcall(Access.CheckDependencies)
        if not called or not result.ok then
            Access.Fail(Access.Err('dependency_unavailable', 'A required dependency is unavailable. Restart Access.'))
        end
    end
    local snapshot = Access.Copy(health)
    snapshot.migrations = Access.Copy(Access.MigrationStatus)
    snapshot.providers = Access.Providers and Access.Providers.Counts() or nil
    snapshot.audit = Access.Audit and Access.Audit.State() or nil
    snapshot.inventoryFence = Access.InventoryFence and Access.InventoryFence.State() or nil
    return Access.Ok(snapshot)
end

function Access.GetCapabilities()
    return Access.Ok({
        resource = GetCurrentResourceName(),
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        contract = 1,
        state = Access.GetHealth().value.state,
        features = {
            lifecycle = 1, health = 1,
            migrations = 1, targetProviders = 1, membershipProviders = 1,
            grants = 1, revocation = 1, capabilityChecks = 1,
            grantLists = 1, auditRecords = 1, outbox = 1, eventPublication = Config.Audit.Enabled and 1 or 0,
            inventoryIntegration = 1, propertyIntegration = 1, assetsIntegration = 1,
            employmentIntegration = 1,
            transferPreservation = 1,
        },
    })
end

function Access.AwaitReady(timeoutMs)
    if timeoutMs == nil then timeoutMs = Config.ReadinessTimeoutMs end
    if not Access.Integer(timeoutMs, 0, 60000) then
        return Access.Err('invalid_input', 'Timeout must be an integer from 0 to 60000 ms.')
    end
    local started = GetGameTimer()
    while health.state ~= 'ready' and health.state ~= 'failed' and health.state ~= 'stopped'
        and GetGameTimer() - started < timeoutMs do Wait(25) end
    if health.state == 'ready' then
        local dependencies = Access.CheckDependencies()
        if not dependencies.ok then return Access.Fail(dependencies) end
        return Access.GetHealth()
    end
    if health.state == 'failed' then
        return Access.Err('startup_failed', 'Access requires restart after its dependencies are ready.',
            { health = Access.Copy(health) })
    end
    return Access.Err('not_ready', 'Access foundation is not ready.')
end

function Access.ValidateConfig()
    if type(Config) ~= 'table' or Config.Contract ~= 1 or Config.RequiredCoreContract ~= 1
        or not Access.Integer(Config.ReadinessTimeoutMs, 0, 60000)
        or type(Config.DevMode) ~= 'boolean' then
        return Access.Err('invalid_config', 'Contract 1 and a readiness timeout from 0 to 60000 ms are required.')
    end
    local providers = Access.Providers.ValidateConfig()
    if not providers.ok then return providers end
    local grants = Access.Grants.ValidateConfig()
    if not grants.ok then return grants end
    if Access.Employment then
        local employment = Access.Employment.ValidateConfig()
        if not employment.ok then return employment end
    end
    return Access.Audit.ValidateConfig()
end

function Access.Uuid(value)
    return type(value) == 'string' and value:match(
        '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

function Access.Key(value)
    return type(value) == 'string' and #value <= 64 and value:match('^[a-z][a-z0-9_.-]*$') ~= nil
end

function Access.OnlyFields(value, fields)
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return false end
    for key in pairs(value) do if not fields[key] then return false end end
    return true
end

function Access.Ready()
    if Access.GetHealth().value.state ~= 'ready' then return Access.Err('not_ready', 'Access is not ready.') end
    return Access.Ok(true)
end
