Organizations = {}
local health = { state = 'starting', phase = 'not_started', contract = 1 }

function Organizations.RegisterDevCommand(name,handler,restricted)
    if Config.DevMode then RegisterCommand(name,handler,restricted==true) end
end

function Organizations.Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Organizations.Copy(child) end
    return result
end

function Organizations.Ok(value) return { ok = true, value = value } end
function Organizations.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end
function Organizations.Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value
        and value >= minimum and value <= maximum and value % 1 == 0
end
function Organizations.Uuid(value)
    return type(value) == 'string' and #value == 36
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end
function Organizations.SetState(state, phase, failure)
    health.state, health.phase = state, phase
    health.failure = Organizations.Copy(failure)
    print(('[feather-organizations] event=lifecycle.changed state=%s phase=%s'):format(state, phase))
end
function Organizations.Fail(result)
    Organizations.SetState('failed', 'startup_failed', result)
    print(('[feather-organizations] event=startup.failed code=%s message=%s'):format(result.code, result.message))
    return result
end
function Organizations.GetHealth() return Organizations.Ok(Organizations.Copy(health)) end
function Organizations.GetCapabilities()
    return Organizations.Ok({ resource = GetCurrentResourceName(), contract = 1,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        state = health.state, features = {
            lifecycle = 1, health = 1, migrations = 1, types = 1,
            organizations = 1, durableCreation = 1, auditRecords = 1,
            organizationLifecycle = 1, hierarchy = 1,
            directory = 1, identityUpdates = 1,
            outbox = 1, eventPublication = 1, auditHistory = 1, interestTypes = 1,
            relationships = 0, controllingInterests = 1, interestReads = 1, affiliations = 0
        } })
end
function Organizations.AwaitReady(timeoutMs)
    if timeoutMs == nil then timeoutMs = Config.ReadinessTimeoutMs end
    if not Organizations.Integer(timeoutMs, 0, 60000) then
        return Organizations.Err('invalid_input', 'Timeout must be an integer from 0 to 60000 ms.')
    end
    local started = GetGameTimer()
    while health.state ~= 'ready' and health.state ~= 'failed'
        and GetGameTimer() - started < timeoutMs do Wait(50) end
    if health.state == 'ready' then return Organizations.GetHealth() end
    if health.state == 'failed' then
        return Organizations.Err('startup_failed', 'Organizations failed to start.', { health = Organizations.Copy(health) })
    end
    return Organizations.Err('not_ready', 'Organizations is not ready.')
end
function Organizations.CheckRead(resource)
    if Config.Access.trustedReaders[resource or ''] ~= true then
        return Organizations.Err('authorization_denied', 'Calling resource is not a trusted reader.')
    end
    if health.state ~= 'ready' then return Organizations.Err('not_ready', 'Organizations is not ready.') end
    if GetResourceState('feather-core') ~= 'started' then
        return Organizations.Err('dependency_unavailable', 'Core is unavailable.')
    end
    return Organizations.Ok(true)
end
function Organizations.ValidateConfig()
    if Config.Contract ~= 1 or Config.RequiredCoreContract ~= 1
        or not Organizations.Integer(Config.ReadinessTimeoutMs, 0, 60000)
        or type(Config.Access) ~= 'table' or type(Config.Access.trustedReaders) ~= 'table'
        or Config.Access.trustedReaders[GetCurrentResourceName()] ~= true
        or type(Config.Access.trustedCreators) ~= 'table'
        or Config.Access.trustedCreators[GetCurrentResourceName()] ~= true
        or type(Config.Access.trustedMutators) ~= 'table'
        or Config.Access.trustedMutators[GetCurrentResourceName()] ~= true
        or type(Config.Access.privilegedMutators) ~= 'table'
        or type(Config.Access.trustedAuditors) ~= 'table'
        or Config.Access.trustedAuditors[GetCurrentResourceName()] ~= true
        or type(Config.Access.privilegedAuditors) ~= 'table'
        or type(Config.DevMode) ~= 'boolean' or type(Config.Authorization) ~= 'table'
        or type(Config.Authorization.enabled) ~= 'boolean'
        or type(Config.Authorization.createAction) ~= 'string' or Config.Authorization.createAction == ''
        or type(Config.Types) ~= 'table' or #Config.Types < 1 or #Config.Types > 32 then
        return Organizations.Err('invalid_config', 'Organization contract, readiness, access, or type configuration is invalid.')
    end
    if type(Config.Outbox)~='table' or not Organizations.Integer(Config.Outbox.pollIntervalMs,250,60000)
        or not Organizations.Integer(Config.Outbox.retryDelaySeconds,1,3600)
        or not Organizations.Integer(Config.Outbox.batchSize,1,100) then
        return Organizations.Err('invalid_config','Outbox configuration is invalid.')
    end
    for _,group in ipairs({'trustedAuditors','privilegedAuditors'}) do
        for resource,enabled in pairs(Config.Access[group]) do
            if type(resource)~='string' or #resource<1 or #resource>100 or type(enabled)~='boolean'
                or (enabled and Config.Access.trustedAuditors[resource]~=true) then
                return Organizations.Err('invalid_config','Audit access configuration is invalid.')
            end
        end
    end
    for _, group in ipairs({ 'trustedMutators', 'privilegedMutators' }) do
        for resource, enabled in pairs(Config.Access[group]) do
            if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean'
                or (enabled and Config.Access.trustedMutators[resource] ~= true) then
                return Organizations.Err('invalid_config', 'Mutator configuration is invalid.')
            end
        end
    end
    for _, action in ipairs({ 'updateAction', 'suspendAction', 'dissolveAction', 'hierarchyAction', 'interestAction' }) do
        if type(Config.Authorization[action]) ~= 'string' or Config.Authorization[action] == '' then
            return Organizations.Err('invalid_config', 'Lifecycle authorization actions are required.')
        end
    end
    for resource, enabled in pairs(Config.Access.trustedCreators) do
        if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean' then
            return Organizations.Err('invalid_config', 'Trusted creator configuration is invalid.')
        end
    end
    for resource, enabled in pairs(Config.Access.trustedReaders) do
        if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean' then
            return Organizations.Err('invalid_config', 'Trusted reader configuration is invalid.')
        end
    end
    local seen = {}
    for _, definition in ipairs(Config.Types) do
        if type(definition) ~= 'table' or type(definition.key) ~= 'string'
            or #definition.key > 48 or not definition.key:match('^[a-z][a-z0-9_]*$')
            or seen[definition.key] or type(definition.label) ~= 'string'
            or #definition.label < 1 or #definition.label > 100
            or definition.label:find('%c') or not definition.label:find('%S') then
            return Organizations.Err('invalid_config', 'Configured type keys/labels must be valid and unique.')
        end
        seen[definition.key] = true
    end
    return Organizations.Ok(true)
end

exports('GetHealth', Organizations.GetHealth)
exports('GetCapabilities', Organizations.GetCapabilities)
exports('AwaitReady', Organizations.AwaitReady)
