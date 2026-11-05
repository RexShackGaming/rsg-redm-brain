local function Caller()
    local owner = GetInvokingResource()
    if type(owner) ~= 'string' or owner == '' then
        return nil, RoutingResults.Err('unauthenticated', 'Routing exports require a calling resource.')
    end
    return owner
end

exports('CreateRoute', function(spec)
    local owner, failure = Caller()
    if not owner then return failure end
    return RoutingService.Create(owner, spec)
end)

exports('JoinRoute', function(routeId, source)
    local owner, failure = Caller()
    if not owner then return failure end
    return RoutingService.Join(owner, routeId, source)
end)

exports('LeaveRoute', function(source)
    local owner, failure = Caller()
    if not owner then return failure end
    return RoutingService.Leave(owner, source)
end)

exports('GetPlayerRoute', function(source)
    local owner, failure = Caller()
    if not owner then return failure end
    return RoutingService.GetPlayer(owner, source)
end)

exports('GetRoute', function(routeId)
    local owner, failure = Caller()
    if not owner then return failure end
    return RoutingService.Get(owner, routeId)
end)

exports('GetRoutePlayers', function(routeId)
    local owner, failure = Caller()
    if not owner then return failure end
    return RoutingService.GetPlayers(owner, routeId)
end)

exports('DeleteRoute', function(routeId)
    local owner, failure = Caller()
    if not owner then return failure end
    return RoutingService.Delete(owner, routeId)
end)

exports('GetCapabilities', RoutingService.Capabilities)

-- CFX may publish onResourceStart while a resource's function-reference host
-- is still re-entrant. Announce readiness only after the resource has reached
-- started state and this script has yielded out of the startup call stack.
CreateThread(function()
    while GetResourceState(GetCurrentResourceName()) ~= 'started' do Wait(0) end
    Wait(0)
    local capabilities = RoutingService.Capabilities()
    TriggerEvent('routing.ready.v1', capabilities.value)
end)

AddEventHandler('playerDropped', function()
    local disconnectedSource = source
    local result = RoutingService.Disconnect(disconnectedSource)
    if result.ok and result.value and result.value.routeId then
        print(('[feather-routing] disconnected source=%s released route membership=%s'):format(
            tostring(disconnectedSource), tostring(result.value.routeId)))
    end
end)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == GetCurrentResourceName() then
        local players, routes = RoutingService.Shutdown()
        print(('[feather-routing] shutdown released %d player(s) and %d route(s)'):format(players, routes))
        return
    end
    local released = RoutingService.CleanupOwner(stoppedResource)
    if released > 0 then
        print(('[feather-routing] released %d route(s) owned by %s'):format(released, stoppedResource))
    end
end)

RegisterCommand('RoutingContractSmokeTest', function(source)
    if source ~= 0 then return end
    local owner = 'routing-smoke-owner'
    local other = 'routing-smoke-other'
    RoutingService.CleanupOwner(owner)
    local created = RoutingService.Create(owner, {
        key = 'contract-smoke', mode = 'strict', populationEnabled = false
    })
    local repeated = created.ok and RoutingService.Create(owner, {
        key = 'contract-smoke', mode = 'strict', populationEnabled = false
    }) or created
    local routeId = created.ok and created.value.routeId or nil
    local inspected = routeId and RoutingService.Get(owner, routeId) or created
    local forbidden = routeId and RoutingService.Get(other, routeId) or created
    local removed = routeId and RoutingService.Delete(owner, routeId) or created
    local stale = routeId and RoutingService.Get(owner, routeId) or created
    local capabilities = RoutingService.Capabilities()
    local tests = {
        { 'capabilities', capabilities.ok and capabilities.value.contract == 1 },
        { 'opaque route created', created.ok and type(routeId) == 'string'
            and created.value.bucket == nil },
        { 'logical key idempotent', repeated.ok and repeated.value.routeId == routeId
            and repeated.meta.idempotent == true },
        { 'owner inspection', inspected.ok and inspected.value.owner == owner },
        { 'cross owner denied', forbidden.ok == false and forbidden.code == 'forbidden' },
        { 'route deleted', removed.ok and stale.ok == false and stale.code == 'not_found' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[RoutingContractSmokeTest] %-24s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[RoutingContractSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('RoutingLiveSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    if not target or GetPlayerName(target) == nil then
        print('[RoutingLiveSmokeTest] usage: RoutingLiveSmokeTest <connected source>')
        return
    end
    local owner = 'routing-live-smoke'
    RoutingService.CleanupOwner(owner)
    local before = GetPlayerRoutingBucket(target)
    if before ~= 0 then
        print(('[RoutingLiveSmokeTest] refused: source %d is already in native bucket %d'):format(target, before))
        return
    end
    local created = RoutingService.Create(owner, {
        key = ('live:%d'):format(target), mode = 'strict', populationEnabled = false
    })
    local routeId = created.ok and created.value.routeId or nil
    local joined = routeId and RoutingService.Join(owner, routeId, target) or created
    local current = routeId and RoutingService.GetPlayer(owner, target) or created
    local players = routeId and RoutingService.GetPlayers(owner, routeId) or created
    local nativeJoined = GetPlayerRoutingBucket(target) ~= 0
    local left = RoutingService.Leave(owner, target)
    local nativeLeft = GetPlayerRoutingBucket(target) == 0
    local deleted = routeId and RoutingService.Delete(owner, routeId) or created
    local tests = {
        { 'route created', created.ok and created.value.bucket == nil },
        { 'player joined', joined.ok and current.ok and current.value.routeId == routeId },
        { 'roster copied', players.ok and #players.value == 1 and players.value[1] == target },
        { 'native bucket assigned', nativeJoined },
        { 'player left', left.ok and nativeLeft },
        { 'route deleted', deleted.ok }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[RoutingLiveSmokeTest] %-24s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[RoutingLiveSmokeTest] done %d/%d passed source=%d'):format(passed, #tests, target))
end, true)
