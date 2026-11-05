local resourceName = GetCurrentResourceName()
RegisterCommand('ChatLocaleSmokeTest', function(source)
    if source ~= 0 then return end
    local passed, tests = 0, ChatLocale.Smoke()
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatLocaleSmokeTest] %-36s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatLocaleSmokeTest] done %s/%s passed (no database writes)'):format(passed, #tests))
end, true)
local lifecycle = { state='starting', reason='waiting_for_core', readyAt=nil }

local function Features()
    local messaging = ChatMessaging and ChatMessaging.IsReady() and 1 or 0
    return {
        messaging=messaging, channels=messaging, channelProviders=messaging, proximity=messaging,
        suggestions=messaging, theming=1, themeRegistration=1, preferences=1,
        moderation=ChatModeration and 1 or 0, persistence=ChatModeration and 1 or 0,
        moderationProviders=ChatModeration and 1 or 0, playerIgnore=ChatModeration and 1 or 0,
        staffCases=0, privateMessages=0
    }
end

local function Capabilities()
    return ChatResults.Ok({
        resource=resourceName,
        contract=ChatContract.Name,
        contractVersion=ChatContract.Version,
        version=GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        state=lifecycle.state,
        features=Features()
    })
end

local function Health()
    return ChatResults.Ok({
        state=lifecycle.state,
        ready=lifecycle.state == 'ready',
        reason=lifecycle.reason,
        core=GetResourceState('feather-core'),
        mysql=GetResourceState('feather-mysql'),
        readyAt=lifecycle.readyAt
    })
end

local function AwaitReady(timeoutMs)
    local timeout = math.min(30000, math.max(0, math.floor(tonumber(timeoutMs) or 0)))
    local deadline = GetGameTimer() + timeout
    repeat
        if lifecycle.state == 'ready' then return ChatResults.Ok(Capabilities().value) end
        if timeout == 0 or GetGameTimer() >= deadline then break end
        Wait(25)
    until false
    return ChatResults.Err('not_ready', ChatLocale.T('error_feather_chat_is_not_ready'), {
        state=lifecycle.state, reason=lifecycle.reason
    })
end

exports('GetCapabilities', Capabilities)
exports('GetHealth', Health)
exports('AwaitReady', AwaitReady)

local booting = false
local function Boot()
    if booting or lifecycle.state == 'ready' then return end
    booting = true
    CreateThread(function()
        lifecycle = { state='starting', reason='validating_configuration', readyAt=nil }
        local validated = ChatContract.ValidateConfig(Config)
        if not validated.ok then
            lifecycle = { state='unavailable', reason=validated.code, readyAt=nil }
            print(ChatLocale.Format('operator_startup_rejected_code_value_message_value',
                tostring(validated.code), tostring(validated.message)))
            booting = false
            return
        end

        lifecycle.reason = 'waiting_for_core'
        while GetResourceState('feather-core') ~= 'started' do Wait(250) end
        while true do
            local called, result = pcall(function()
                return exports['feather-core']:AwaitReady(0)
            end)
            if called and type(result) == 'table' and result.ok == true then break end
            Wait(250)
        end

        local themeStart = ChatThemes.Start()
        local themeRoutes = themeStart.ok and ChatThemes.RegisterRoutes() or themeStart
        if type(themeRoutes) ~= 'table' or themeRoutes.ok ~= true then
            lifecycle = { state='unavailable', reason='theme_registration_failed', readyAt=nil }
            print(ChatLocale.Format('operator_theme_registration_failed_code_value',
                tostring(type(themeRoutes) == 'table' and themeRoutes.code or 'invalid_result')))
            booting = false
            return
        end

        local channelStart = ChatChannels.Start()
        local channelRoutes = channelStart.ok and ChatChannels.RegisterRoutes() or channelStart
        if type(channelRoutes) ~= 'table' or channelRoutes.ok ~= true then
            lifecycle = { state='unavailable', reason='channel_registration_failed', readyAt=nil }
            print(ChatLocale.Format('operator_channel_registration_failed_code_value',
                tostring(type(channelRoutes) == 'table' and channelRoutes.code or 'invalid_result')))
            booting = false
            return
        end
        local moderationStart = ChatModeration.Start()
        if type(moderationStart) ~= 'table' or moderationStart.ok ~= true then
            lifecycle = { state='unavailable', reason='moderation_persistence_failed', readyAt=nil }
            print(ChatLocale.Format('operator_moderation_startup_failed_code_value',
                tostring(type(moderationStart) == 'table' and moderationStart.code or 'invalid_result')))
            booting = false
            return
        end
        local moderationRoutes = ChatModeration.RegisterRoutes()
        if type(moderationRoutes) ~= 'table' or moderationRoutes.ok ~= true then
            lifecycle = { state='unavailable', reason='moderation_registration_failed', readyAt=nil }
            print(ChatLocale.Format('operator_moderation_route_registration_failed_code_value',
                tostring(type(moderationRoutes) == 'table' and moderationRoutes.code or 'invalid_result')))
            booting = false
            return
        end
        local messaging = ChatMessaging.Start()
        if type(messaging) ~= 'table' or messaging.ok ~= true then
            lifecycle = { state='unavailable', reason='messaging_registration_failed', readyAt=nil }
            print(ChatLocale.Format('operator_messaging_registration_failed_code_value',
                tostring(type(messaging) == 'table' and messaging.code or 'invalid_result')))
            booting = false
            return
        end

        lifecycle = { state='ready', reason=nil, readyAt=os.time() }
        booting = false
        TriggerEvent('chat.ready.v1', Capabilities().value)
    end)
end

Boot()

RegisterCommand('ChatSuggestionContractSmokeTest', function(source)
    if source ~= 0 then return end
    local passed, tests = 0, ChatChannels.SuggestionSmoke()
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatSuggestionContractSmokeTest] %-38s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatSuggestionContractSmokeTest] done %d/%d passed (temporary registry entries; no database writes)'):format(passed, #tests))
end, true)

AddEventHandler('onResourceStart', function(startedResource)
    if startedResource == 'feather-core' or startedResource == 'feather-mysql' then
        lifecycle = { state='starting', reason='waiting_for_dependencies', readyAt=nil }
        Boot()
    end
end)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == 'feather-core' or stoppedResource == 'feather-mysql' then
        lifecycle = { state='degraded', reason=stoppedResource .. '_unavailable', readyAt=nil }
    elseif stoppedResource == resourceName then
        lifecycle = { state='stopping', reason='resource_stop', readyAt=nil }
    end
end)

RegisterCommand('ChatFoundationSmokeTest', function(source)
    if source ~= 0 then return end
    local config = ChatContract.ValidateConfig(Config)
    local capabilities = Capabilities()
    local health = Health()
    local immediate = AwaitReady(0)
    capabilities.value.features.theming = 0
    local repeated = Capabilities()
    local tests = {
        { 'configuration', config.ok },
        { 'contract identity', repeated.ok and repeated.value.contract == 'feather.chat'
            and repeated.value.contractVersion == 1 },
        { 'foundation features', repeated.value.features.theming == 1
            and repeated.value.features.messaging == 1 },
        { 'health ready', health.ok and health.value.ready == true },
        { 'await ready', immediate.ok and immediate.value.state == 'ready' },
        { 'defensive capabilities', repeated.value.features.theming == 1 }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatFoundationSmokeTest] %-24s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatFoundationSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('ChatModerationSmokeTest', function(source)
    if source ~= 0 then return end
    local called, tests = pcall(ChatModeration.Smoke)
    if not called then
        print(('[ChatModerationSmokeTest] persistence check failed: %s'):format(tostring(tests)))
        return
    end
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatModerationSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatModerationSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('ChatModerationProviderSmokeTest', function(source)
    if source ~= 0 then return end
    local tests = ChatModeration.ProviderSmoke()
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatModerationProviderSmokeTest] %-34s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatModerationProviderSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('ChatChannelRegistrySmokeTest', function(source)
    if source ~= 0 then return end
    local tests = ChatChannels.Smoke()
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatChannelRegistrySmokeTest] %-26s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatChannelRegistrySmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('ChatMessageContractSmokeTest', function(source)
    if source ~= 0 then return end
    local valid = ChatContract.ValidateSubmission({
        channelKey='local.say', text='Hello', submissionId='smoke:1'
    }, Config.Limits)
    local spoofed = ChatContract.ValidateSubmission({
        channelKey='local.say', text='Hello', submissionId='smoke:2',
        author={ characterId='spoofed' }
    }, Config.Limits)
    local unknown = ChatContract.ValidateSubmission({
        channelKey='unknown', text='Hello', submissionId='smoke:3'
    }, Config.Limits)
    local clean = ChatMessaging.NormalizeText('  Safe plain text  ')
    local control = ChatMessaging.NormalizeText('unsafe' .. string.char(1))
    local tests = {
        { 'valid submission', valid == true },
        { 'spoofed identity rejected', spoofed == false },
        { 'unknown channel rejected', unknown == false },
        { 'plain text normalized', clean == 'Safe plain text' },
        { 'control rejected', control == nil }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatMessageContractSmokeTest] %-26s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatMessageContractSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('ChatMessageConcurrencySmokeTest', function(source)
    if source ~= 0 then return end
    local tests = ChatMessaging.ConcurrencySmoke()
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatMessageConcurrencySmokeTest] %-34s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatMessageConcurrencySmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('ChatRateLimitSmokeTest', function(source)
    if source ~= 0 then return end
    local tests = ChatMessaging.RateLimitSmoke()
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatRateLimitSmokeTest] %-28s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatRateLimitSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('ChatThemeContractSmokeTest', function(source)
    if source ~= 0 then return end
    local tests = ChatThemes.Smoke()
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatThemeContractSmokeTest] %-30s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatThemeContractSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)
