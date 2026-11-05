Authority = {}
local health = { state = 'starting', phase = 'not_started', contract = 1 }

function Authority.RegisterDevCommand(name, handler, restricted)
    if Config.DevMode then RegisterCommand(name, handler, restricted == true) end
end

function Authority.Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Authority.Copy(child) end
    return result
end

function Authority.Ok(value) return { ok = true, value = value } end
function Authority.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end
function Authority.Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end
function Authority.Uuid(value)
    return type(value) == 'string' and #value == 36
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end
function Authority.SetState(state, phase, failure)
    health.state, health.phase, health.failure = state, phase, Authority.Copy(failure)
    print(('[feather-authority] event=lifecycle.changed state=%s phase=%s'):format(state, phase))
end
function Authority.Fail(result)
    Authority.SetState('failed', 'startup_failed', result)
    print(('[feather-authority] event=startup.failed code=%s message=%s'):format(result.code, result.message))
    return result
end
function Authority.GetHealth() return Authority.Ok(Authority.Copy(health)) end
function Authority.GetCapabilities()
    return Authority.Ok({
        resource = GetCurrentResourceName(),
        contract = Config.Contract,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        state = health.state,
        features = {
            lifecycle = 1,
            health = 1,
            migrations = 1,
            capabilityRegistry = 1,
            capabilityRegistrationContracts = 1,
            capabilityRegistration = 1,
            roles = 1,
            durableRoleCreation = 1,
            roleGrantContracts = 1,
            roleGrants = 1,
            assignmentContracts = 1,
            assignments = 1,
            characterAssignments = 1,
            assignmentReads = 1,
            assignmentLifecycle = 1,
            assignmentReplacement = 1,
            scopedEvaluation = 1,
            effectiveCapabilityReads = 1,
            policyProvider = 1,
            delegations = 0
        }
    })
end
function Authority.AwaitReady(timeoutMs)
    if timeoutMs == nil then timeoutMs = Config.ReadinessTimeoutMs end
    if not Authority.Integer(timeoutMs, 0, 60000) then
        return Authority.Err('invalid_input', 'Timeout must be an integer from 0 to 60000 ms.')
    end
    local started = GetGameTimer()
    while health.state ~= 'ready' and health.state ~= 'failed'
        and GetGameTimer() - started < timeoutMs do Wait(50) end
    if health.state == 'ready' then return Authority.GetHealth() end
    if health.state == 'failed' then
        return Authority.Err('startup_failed', 'Authority failed to start.', { health = Authority.Copy(health) })
    end
    return Authority.Err('not_ready', 'Authority is not ready.')
end
function Authority.CheckRead(resource)
    if Config.Access.trustedReaders[resource or ''] ~= true then
        return Authority.Err('authorization_denied', 'Calling resource is not a trusted Authority reader.')
    end
    if health.state ~= 'ready' then return Authority.Err('not_ready', 'Authority is not ready.') end
    if GetResourceState('feather-core') ~= 'started' or GetResourceState('feather-organizations') ~= 'started' then
        return Authority.Err('dependency_unavailable', 'A required Authority dependency is unavailable.')
    end
    return Authority.Ok(true)
end

local function ValidCapabilityKey(value)
    return type(value) == 'string' and #value >= 3 and #value <= 100
        and value:match('^[a-z][a-z0-9_]*%.[a-z][a-z0-9_.]*$') ~= nil
        and not value:find('..', 1, true)
end

function Authority.ValidateConfig()
    if Config.Contract ~= 1 or Config.RequiredCoreContract ~= 1
        or Config.RequiredOrganizationsContract ~= 1
        or not Authority.Integer(Config.ReadinessTimeoutMs, 0, 60000)
        or type(Config.DevMode) ~= 'boolean' or type(Config.Access) ~= 'table'
        or type(Config.Access.trustedReaders) ~= 'table'
        or Config.Access.trustedReaders[GetCurrentResourceName()] ~= true
        or type(Config.Access.trustedCapabilityRegistrars) ~= 'table'
        or Config.Access.trustedCapabilityRegistrars[GetCurrentResourceName()] ~= true
        or type(Config.Access.trustedRoleCreators) ~= 'table'
        or Config.Access.trustedRoleCreators[GetCurrentResourceName()] ~= true
        or type(Config.Access.trustedGrantors) ~= 'table'
        or Config.Access.trustedGrantors[GetCurrentResourceName()] ~= true
        or type(Config.Access.trustedAssigners) ~= 'table'
        or Config.Access.trustedAssigners[GetCurrentResourceName()] ~= true
        or type(Config.Capabilities) ~= 'table' or #Config.Capabilities < 1 or #Config.Capabilities > 128 then
        return Authority.Err('invalid_config', 'Authority contract, readiness, access, or capability configuration is invalid.')
    end
    for resource, enabled in pairs(Config.Access.trustedReaders) do
        if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean' then
            return Authority.Err('invalid_config', 'Trusted reader configuration is invalid.')
        end
    end
    for resource, enabled in pairs(Config.Access.trustedCapabilityRegistrars) do
        if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean'
            or (enabled and Config.Access.trustedReaders[resource] ~= true) then
            return Authority.Err('invalid_config', 'Trusted capability registrar configuration is invalid.')
        end
    end
    for resource, enabled in pairs(Config.Access.trustedRoleCreators) do
        if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean'
            or (enabled and Config.Access.trustedReaders[resource] ~= true) then
            return Authority.Err('invalid_config', 'Trusted role creator configuration is invalid.')
        end
    end
    for resource, enabled in pairs(Config.Access.trustedGrantors) do
        if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean'
            or (enabled and Config.Access.trustedReaders[resource] ~= true) then
            return Authority.Err('invalid_config', 'Trusted grantor configuration is invalid.')
        end
    end
    for resource, enabled in pairs(Config.Access.trustedAssigners) do
        if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean'
            or (enabled and Config.Access.trustedReaders[resource] ~= true) then
            return Authority.Err('invalid_config', 'Trusted assigner configuration is invalid.')
        end
    end
    local seen = {}
    for _, definition in ipairs(Config.Capabilities) do
        if type(definition) ~= 'table' or not ValidCapabilityKey(definition.key)
            or seen[definition.key] or type(definition.description) ~= 'string'
            or #definition.description < 1 or #definition.description > 255
            or definition.description:find('%c') or not definition.description:find('%S')
            or (definition.riskClass ~= 'low' and definition.riskClass ~= 'moderate'
                and definition.riskClass ~= 'high' and definition.riskClass ~= 'critical') then
            return Authority.Err('invalid_config', 'Capability definitions must be bounded, valid, and unique.')
        end
        local namespace = definition.key:match('^([a-z][a-z0-9_]*)%.')
        if namespace ~= 'staff' and namespace ~= 'rp' then
            return Authority.Err('invalid_config', 'Capability namespace must be staff or rp.')
        end
        seen[definition.key] = true
    end
    return Authority.Ok(true)
end

exports('GetHealth', Authority.GetHealth)
exports('GetCapabilities', Authority.GetCapabilities)
exports('AwaitReady', Authority.AwaitReady)
