function DebugLog(...)
    if Config.DevMode then print('[feather-world]', ...) end
end

CreateThread(function()
    StartPlayerRuntime()
    StartNativeEventRuntime()
    StartPopulationDensity()

    if Config.InteriorFix.enabled then StartInteriorsFix() end
    if Config.WagonFix.enabled then StartWagonFix() end
end)

exports('SetFogOfWar', MapAPI.SetFogOfWar)
exports('DisplayWorldRadar', MapAPI.DisplayRadar)
exports('StartGpsRoute', MapAPI.StartGps)
exports('StopGpsRoute', MapAPI.StopGps)

RegisterCommand('WorldClientSmokeTest', function()
    local multipliers = Config.DensityMultipliers
    local densityReady = WorldPopulationActive == true and type(multipliers) == 'table'
        and tonumber(multipliers.ambientPeds) ~= nil and WorldPopulationFrames > 0
    local interiorsReady = not Config.InteriorFix.enabled or (InteriorsActive == true and IMapsActive == true
        and InteriorDefinitionCount == Config.InteriorFix.expectedInteriorDefinitions
        and InteriorMetadataCount == Config.InteriorFix.expectedInteriorMetadata
        and InteriorEntitySetCount == Config.InteriorFix.expectedEntitySets
        and IMapOperationCount == Config.InteriorFix.expectedImapOperations
        and IMapDescriptionCount == Config.InteriorFix.expectedImapDescriptions)
    local expectedListeners = Config.PlayerRuntime.clearChallengeFeed and 3 or 0
    local safeguardsReady = PlayerRuntimeActive == true and EventListenerCount == expectedListeners
        and LootPromptSuppressionActive == Config.PlayerRuntime.suppressRandomLootPrompts
    local wagonFixReady = not Config.WagonFix.enabled or WagonFixActive == true
    local invalidGps = MapAPI.StartGps(nil, nil)
    local mapReady = type(Config.Map) == 'table' and tonumber(Config.Map.gpsRouteColor) ~= nil
        and invalidGps.ok == false and invalidGps.error.code == 'invalid_coordinates'

    local tests = {
        { 'density loop', densityReady, ('frames=%s'):format(tostring(WorldPopulationFrames)) },
        { 'interior fixes', interiorsReady,
            ('interiors=%s metadata=%s sets=%s invalid=%s imaps=%s described=%s'):format(
                tostring(InteriorDefinitionCount), tostring(InteriorMetadataCount),
                tostring(InteriorEntitySetCount), tostring(InteriorInvalidCount),
                tostring(IMapOperationCount), tostring(IMapDescriptionCount)) },
        { 'player safeguards', safeguardsReady,
            ('listeners=%s lootPrompts=%s'):format(tostring(EventListenerCount),
                tostring(LootPromptSuppressionActive)) },
        { 'wagon cleanup', wagonFixReady },
        { 'map configuration', mapReady }
    }

    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        local detail = test[3] and (' -- ' .. test[3]) or ''
        print(('[WorldClientSmokeTest] %-24s %s%s'):format(test[1], test[2] and 'PASS' or 'FAIL', detail))
    end
    print(('[WorldClientSmokeTest] done %d/%d passed'):format(passed, #tests))
end, false)
