local resourceName = GetCurrentResourceName()

local function Capabilities()
    return {
        ok = true,
        value = {
            resource = resourceName,
            contract = 1,
            version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
            state = 'ready',
            features = {
                population = 1,
                interiors = 1,
                wagonCleanup = 1,
                map = 1,
                playerSafeguards = 1,
                lootPromptSuppression = 1
            }
        }
    }
end

exports('GetCapabilities', Capabilities)

RegisterCommand('WorldContractSmokeTest', function(source)
    if source ~= 0 then return end

    local capabilities = Capabilities()
    local density = WorldPopulation.GetDensityMultipliers()
    local densityValidation = WorldPopulation.ValidateDensityMultipliers(Config.DensityMultipliers)
    local tests = {
        { 'capabilities', capabilities.ok and capabilities.value.contract == 1 },
        { 'density configuration', density.ok and densityValidation.ok },
        { 'defensive snapshot', density.ok and density.value ~= Config.DensityMultipliers },
        { 'player runtime configuration', type(Config.PlayerRuntime) == 'table'
            and type(Config.PlayerRuntime.clearChallengeFeed) == 'boolean'
            and type(Config.PlayerRuntime.disableWeaponSoftlockControls) == 'boolean'
            and type(Config.PlayerRuntime.disableFrameworkHudControls) == 'boolean'
            and type(Config.PlayerRuntime.suppressRandomLootPrompts) == 'boolean' },
        { 'map configuration', type(Config.Map) == 'table'
            and tonumber(Config.Map.gpsRouteColor) ~= nil
            and tonumber(Config.Map.gpsRouteColor) >= 0 },
        { 'interior fix configuration', type(Config.InteriorFix) == 'table'
            and type(Config.InteriorFix.enabled) == 'boolean'
            and tonumber(Config.InteriorFix.startupDelayMs) ~= nil
            and tonumber(Config.InteriorFix.startupDelayMs) >= 0
            and Config.InteriorFix.expectedInteriorDefinitions == 35
            and Config.InteriorFix.expectedInteriorMetadata == 35
            and Config.InteriorFix.expectedEntitySets == 494
            and Config.InteriorFix.expectedImapOperations == 400
            and Config.InteriorFix.expectedImapDescriptions == 217 },
        { 'wagon cleanup configuration', type(Config.WagonFix) == 'table'
            and type(Config.WagonFix.enabled) == 'boolean'
            and type(Config.WagonFix.removeOrphanedComponents) == 'boolean'
            and type(Config.WagonFix.components) == 'table'
            and type(Config.WagonFix.networkControl) == 'table'
            and #Config.WagonFix.components > 0
            and tonumber(Config.WagonFix.checkIntervalMs) ~= nil
            and tonumber(Config.WagonFix.checkIntervalMs) > 0
            and tonumber(Config.WagonFix.orphanCheckIntervalMs) ~= nil
            and tonumber(Config.WagonFix.orphanCheckIntervalMs) > 0
            and tonumber(Config.WagonFix.componentDistance) ~= nil
            and tonumber(Config.WagonFix.componentDistance) >= 0
            and tonumber(Config.WagonFix.occupantDistance) ~= nil
            and tonumber(Config.WagonFix.occupantDistance) >= 0
            and tonumber(Config.WagonFix.networkControl.maxAttempts) ~= nil
            and tonumber(Config.WagonFix.networkControl.maxAttempts) > 0
            and tonumber(Config.WagonFix.networkControl.waitMs) ~= nil
            and tonumber(Config.WagonFix.networkControl.waitMs) >= 0 }
    }

    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[WorldContractSmokeTest] %-30s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[WorldContractSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)
