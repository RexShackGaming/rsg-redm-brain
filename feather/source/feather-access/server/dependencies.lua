function Access.CheckDependencies()
    for _, resource in ipairs({ 'feather-core', 'feather-mysql' }) do
        if GetResourceState(resource) ~= 'started' then
            return Access.Err('dependency_unavailable', 'A required dependency is unavailable.',
                { resource = resource })
        end
    end
    local called, result = pcall(function() return exports['feather-core']:GetCapabilities() end)
    if not called or type(result) ~= 'table' or result.ok ~= true
        or type(result.value) ~= 'table' or result.value.contract ~= Config.RequiredCoreContract
        or result.value.state ~= 'ready' then
        return Access.Err('dependency_unavailable', 'Ready Core Contract 1 is required.')
    end
    return Access.Ok(true)
end

function Access.StartDependencies()
    Access.SetState('waiting', 'waiting_for_core')
    local ready = exports['feather-core']:AwaitReady(Config.ReadinessTimeoutMs)
    if type(ready) ~= 'table' or ready.ok ~= true then
        return Access.Err('dependency_unavailable', 'Core did not become ready.')
    end
    local checked = Access.CheckDependencies()
    if not checked.ok then return checked end
    Access.SetState('waiting', 'waiting_for_database')
    if DB.awaitReady(Config.ReadinessTimeoutMs) ~= true then
        return Access.Err('dependency_unavailable', 'Database did not become ready.')
    end
    return Access.CheckDependencies()
end
