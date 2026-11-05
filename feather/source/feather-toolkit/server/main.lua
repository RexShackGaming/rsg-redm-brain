local resourceName = GetCurrentResourceName()

local function Capabilities()
    return ToolkitResults.Ok({
        resource = resourceName,
        contract = 1,
        version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        features = { clientUtilities = 1, ownershipCleanup = 1, progress = 1 }
    })
end

exports('GetCapabilities', Capabilities)

RegisterCommand('ToolkitServerContractSmokeTest', function(source)
    if source ~= 0 then return end
    local caps = Capabilities()
    local tests = {
        { 'capabilities',      caps.ok and caps.value.contract == 1 },
        { 'client utilities',  caps.ok and caps.value.features.clientUtilities == 1 },
        { 'ownership cleanup', caps.ok and caps.value.features.ownershipCleanup == 1 },
        { 'progress UI',       caps.ok and caps.value.features.progress == 1 }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ToolkitServerContractSmokeTest] %-20s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end

    print(('[ToolkitServerContractSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)
