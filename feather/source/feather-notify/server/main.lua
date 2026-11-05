local resourceName = GetCurrentResourceName()

local function Capabilities()
    return NotifyResults.Ok({
        resource = resourceName,
        contract = NotifyContract.Version,
        version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        state = 'ready',
        features = {
            presentation = 1,
            provider = 1,
            styles = NotifyContract.Styles,
            limits = NotifyContract.Limits()
        }
    })
end

local function InstallProvider()
    local called, result = pcall(function()
        return exports['feather-core']:RegisterNotificationProvider('feather-notify', {
            Send = function(request)
                local presentation = {}
                for key, value in pairs(request) do
                    if key ~= 'source' then presentation[key] = value end
                end
                TriggerClientEvent('feather-notify:show.v1', request.source, presentation)
                return NotifyResults.Ok({ dispatched = true, style = request.style })
            end
        }, {
            contract = NotifyContract.Version,
            default = true,
            capabilities = { styles = NotifyContract.Styles, limits = NotifyContract.Limits() }
        })
    end)
    return called and type(result) == 'table' and result.ok == true, result
end

exports('GetCapabilities', Capabilities)

local installing = false
local function RegistrationLimit(name, fallback, maximum)
    local value = math.max(1, math.floor(tonumber(Config[name]) or fallback))
    return math.min(value, maximum)
end

local function WaitForCoreReady()
    while GetResourceState('feather-core') ~= 'started' do Wait(250) end
    while true do
        local called, ready = pcall(function() return exports['feather-core']:AwaitReady(0) end)
        if called and type(ready) == 'table' and ready.ok == true then return end
        Wait(250)
    end
end

local function IsPermanentRegistrationFailure(result)
    if type(result) ~= 'table' then return false end
    return result.code == 'conflict'
        or result.code == 'invalid_input'
        or result.code == 'forbidden'
        or result.code == 'unsupported_contract'
end

local function InstallWhenCoreReady()
    if installing then return end
    installing = true
    CreateThread(function()
        local attempts = RegistrationLimit('providerRegistrationAttempts', 5, 20)
        local baseDelay = RegistrationLimit('providerRegistrationBaseDelayMs', 500, 30000)
        local maxDelay = RegistrationLimit('providerRegistrationMaxDelayMs', 5000, 60000)
        local installed, result = false, nil

        for attempt = 1, attempts do
            WaitForCoreReady()
            Wait(0)
            installed, result = InstallProvider()
            if installed or IsPermanentRegistrationFailure(result) then break end
            if attempt < attempts then
                local delay = math.min(maxDelay, baseDelay * (2 ^ (attempt - 1)))
                Wait(delay)
            end
        end

        installing = false
        if not installed then
            print(('[feather-notify] provider registration failed code=%s message=%s'):format(
                tostring(type(result) == 'table' and result.code or 'export_failed'),
                tostring(type(result) == 'table' and result.message or result)))
        end
    end)
end

InstallWhenCoreReady()
AddEventHandler('onResourceStart', function(startedResource)
    if startedResource == 'feather-core' then InstallWhenCoreReady() end
end)

RegisterCommand('NotifyContractSmokeTest', function(source, args)
    if source ~= 0 then return end
    local target = tonumber(args and args[1])
    local capabilities = Capabilities()
    local provider = exports['feather-core']:GetProvider('notification', 'feather-notify', 1)
    local dispatched = target and exports['feather-core']:SendNotification({
        source = target, style = 'right', message = 'Feather Notify provider is working.', duration = 2500
    }) or NotifyResults.Err('invalid_input', 'A connected source is required.')
    local invalid = target and exports['feather-core']:SendNotification({
        source = target, style = 'unknown', message = 'invalid'
    }) or dispatched
    local tests = {
        { 'capabilities', capabilities.ok and capabilities.value.contract == 1
            and type(capabilities.value.features.limits) == 'table' },
        { 'provider registered', provider.ok and provider.value.provider.owner == resourceName },
        { 'dispatch envelope', dispatched.ok and dispatched.value.dispatched == true },
        { 'invalid style rejected', invalid.ok == false and invalid.code == 'invalid_input' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[NotifyContractSmokeTest] %-24s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[NotifyContractSmokeTest] done %d/%d passed source=%s'):format(
        passed, #tests, tostring(target or 'none')))
end, true)
