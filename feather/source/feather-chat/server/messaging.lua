ChatMessaging = {}

local sequence = 0
local rates = {}
local channelRates = {}
local repeats = {}
local submissions = {}
local ready = false
local maximumRememberedSubmissions = 32

local function Callable(value)
    return type(value) == 'function' or (type(value) == 'table'
        and type(rawget(value, '__cfx_functionReference')) == 'string')
end

local function NewUuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return (template:gsub('[xy]', function(token)
        local value = token == 'x' and math.random(0, 15) or math.random(8, 11)
        return ('%x'):format(value)
    end))
end

local function NormalizeText(text)
    text = text:gsub('\r\n', '\n'):gsub('\r', '\n')
    text = text:gsub('^[ \t\n]+', ''):gsub('[ \t\n]+$', '')
    if text == '' then return nil, 'Message cannot be empty.' end

    local lineCount = 1
    for _ in text:gmatch('\n') do lineCount = lineCount + 1 end
    if lineCount > Config.Limits.maxMessageLines then
        return nil, 'Message contains too many lines.'
    end

    local valid, failure = pcall(function()
        for _, codepoint in utf8.codes(text) do
            if (codepoint < 32 and codepoint ~= 9 and codepoint ~= 10)
                or codepoint == 127
                or (codepoint >= 0x202A and codepoint <= 0x202E)
                or (codepoint >= 0x2066 and codepoint <= 0x2069) then
                error('unsafe_character', 0)
            end
        end
    end)
    if not valid then
        return nil, failure == 'unsafe_character' and ChatLocale.T('error_message_contains_unsupported_characters')
            or ChatLocale.T('error_message_is_not_valid_utf_8')
    end
    return text
end

local function WindowAllowed(store, key, windowMs, maximum)
    local now = GetGameTimer()
    local window = store[key]
    if not window or (now - window.startedAt) % 4294967296 >= windowMs then
        store[key] = { startedAt=now, count=1 }
        return true
    end
    if window.count >= maximum then return false end
    window.count = window.count + 1
    return true
end

local function RateAllowed(source, channelKey, text)
    if not WindowAllowed(rates, source, Config.RateLimit.windowMs, Config.RateLimit.maxMessages) then
        return false
    end
    local profile = Config.RateLimit.channelProfiles[channelKey]
    channelRates[source] = channelRates[source] or {}
    if profile and not WindowAllowed(channelRates[source], channelKey,
        profile.windowMs, profile.maxMessages) then return false end
    local fingerprint = channelKey .. '\0' .. text:lower()
    repeats[source] = repeats[source] or {}
    return WindowAllowed(repeats[source], fingerprint, Config.RateLimit.repeatedWindowMs,
        Config.RateLimit.maxRepeatedMessages)
end

-- Official case traffic stays out of RP routing and ignore filters. Admin owns
-- participant authorization/persistence; Chat owns plain-text validation/rates.
exports('PrepareStaffCaseText', function(source, conversationId, text)
    if GetInvokingResource() ~= 'feather-admin' then
        return { ok = false, code = 'forbidden' }
    end
    if type(source) ~= 'number' or source < 1 or type(conversationId) ~= 'string'
        or #conversationId ~= 36 or type(text) ~= 'string' or #text > Config.Limits.maxMessageBytes then
        return { ok = false, code = 'invalid_input' }
    end
    local normalized = NormalizeText(text)
    if not normalized then return { ok = false, code = 'invalid_input' } end
    if not RateAllowed(source, 'staff.case', normalized) then return { ok = false, code = 'rate_limited' } end
    return { ok = true, text = normalized }
end)

local function Profile(characterId)
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    local implementation = type(provider) == 'table' and provider.ok == true
        and type(provider.value) == 'table' and provider.value.implementation or nil
    if type(implementation) ~= 'table' or not Callable(implementation.GetProfile) then
        return ChatResults.Err('identity_unavailable', ChatLocale.T('error_character_identity_is_unavailable'))
    end
    local called, result = pcall(implementation.GetProfile, characterId)
    if not called or type(result) ~= 'table' or result.ok ~= true
        or type(result.value) ~= 'table' then
        return ChatResults.Err('identity_unavailable', ChatLocale.T('error_character_identity_is_unavailable'))
    end
    local first = type(result.value.firstName) == 'string' and result.value.firstName or ''
    local last = type(result.value.lastName) == 'string' and result.value.lastName or ''
    local displayName = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    if displayName == '' or #displayName > 96 then
        return ChatResults.Err('identity_unavailable', ChatLocale.T('error_character_display_name_is_unavailable'))
    end
    return ChatResults.Ok({ characterId=characterId, displayName=displayName })
end

local function AuthoritativePosition(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    if not coords then return nil end
    return coords, GetPlayerRoutingBucket(source)
end

local function Recipients(source, radius)
    local origin, bucket = AuthoritativePosition(source)
    if not origin then
        return nil, ChatResults.Err('position_unavailable', ChatLocale.T('error_authoritative_player_position_is_unavailable'))
    end
    local selected, radiusSquared = {}, radius * radius
    for _, rawTarget in ipairs(GetPlayers()) do
        local target = tonumber(rawTarget)
        if target and GetPlayerRoutingBucket(target) == bucket then
            local session = exports['feather-core']:GetSessionContext(target)
            local coords = type(session) == 'table' and session.ok == true
                and select(1, AuthoritativePosition(target)) or nil
            if coords then
                local dx, dy, dz = coords.x-origin.x, coords.y-origin.y, coords.z-origin.z
                if dx*dx + dy*dy + dz*dz <= radiusSquared then selected[#selected + 1] = target end
            end
        end
    end
    return selected
end

local function ConnectedSessions()
    local connected = {}
    for _, rawTarget in ipairs(GetPlayers()) do
        local target = tonumber(rawTarget)
        local session = target and exports['feather-core']:GetSessionContext(target) or nil
        if type(session) == 'table' and session.ok == true then
            connected[#connected + 1] = {
                source=target, accountId=session.value.accountId,
                characterId=session.value.characterId, sessionId=session.value.sessionId
            }
        end
    end
    return connected
end

local function PruneSubmissions(source)
    local cache = submissions[source]
    if not cache then return end
    local index = 1
    while #cache.order > maximumRememberedSubmissions and index <= #cache.order do
        local cacheKey = cache.order[index]
        local entry = cache.values[cacheKey]
        if entry and entry.state == 'complete' then
            cache.values[cacheKey] = nil
            table.remove(cache.order, index)
        else
            index = index + 1
        end
    end
end

local function Reserve(source, sessionId, submissionId)
    submissions[source] = submissions[source] or { order={}, values={} }
    local cache = submissions[source]
    local cacheKey = tostring(sessionId) .. '\0' .. submissionId
    local existing = cache.values[cacheKey]
    if existing then return existing, false end
    local entry = { state='pending' }
    cache.values[cacheKey] = entry
    cache.order[#cache.order + 1] = cacheKey
    PruneSubmissions(source)
    return entry, true
end

local function Complete(source, entry, result)
    entry.result = result
    entry.state = 'complete'
    PruneSubmissions(source)
    return result
end

local function DefaultDependencies()
    return {
        wait=function() Wait(0) end,
        isSessionCurrent=function(source, sessionId, characterId)
            return exports['feather-core']:IsSessionCurrent(source, sessionId, characterId)
        end,
        normalizeText=NormalizeText,
        rateAllowed=RateAllowed,
        profile=Profile,
        getChannel=ChatChannels.Get,
        canSend=ChatChannels.CanSend,
        moderationCanSend=ChatModeration.CanSend,
        moderateMessage=ChatModeration.EvaluateMessage,
        filterRecipients=ChatModeration.FilterRecipients,
        recordDelivery=ChatModeration.RecordDelivery,
        recipients=function(channel, actor, source)
            if channel.routing == 'proximity' then
                return Recipients(source, Config.Channels.proximity[channel.radius])
            end
            local connected = ConnectedSessions()
            local audience = ChatChannels.ResolveAudience(channel, actor, connected)
            if not audience.ok or type(audience.value) ~= 'table'
                or type(audience.value.sources) ~= 'table' then
                return nil, ChatResults.Err(audience.code or 'provider_unavailable',
                    audience.message or ChatLocale.T('error_channel_audience_is_unavailable'))
            end
            local recipients, allowed = {}, {}
            for _, session in ipairs(connected) do allowed[session.source] = true end
            for _, target in ipairs(audience.value.sources) do
                target = tonumber(target)
                if target and allowed[target] and #recipients < 256 then
                    recipients[#recipients + 1] = target
                end
            end
            return recipients
        end,
        newUuid=NewUuid,
        createdAt=function() return os.date('!%Y-%m-%dT%H:%M:%SZ') end,
        deliver=function(target, message)
            TriggerClientEvent('feather-chat:message:v1', target, message)
        end
    }
end

local function ProcessSubmission(payload, source, context, dependencies)
    if not dependencies.isSessionCurrent(source, context.sessionId, context.characterId) then
        return ChatResults.Err('session_stale', ChatLocale.T('error_character_session_changed'))
    end
    local text, textError = dependencies.normalizeText(payload.text)
    if not text then return ChatResults.Err('invalid_message', textError) end
    local identity = dependencies.profile(context.characterId)
    if not identity.ok then return identity end
    local channel = dependencies.getChannel(payload.channelKey)
    if not channel or channel.visibility == 'system' then
        return ChatResults.Err('channel_unavailable', ChatLocale.T('error_that_channel_is_unavailable'))
    end
    if #text > channel.input.maximumLength then
        return ChatResults.Err('invalid_message', ChatLocale.T('error_message_is_too_long_for_that_channel'))
    end
    local actor = { source=source, accountId=context.accountId,
        characterId=context.characterId, sessionId=context.sessionId }
    local access = dependencies.canSend(channel, actor)
    if not access.ok or type(access.value) ~= 'table'
        or (access.value.allowed ~= true and access.value.canSend ~= true) then
        return ChatResults.Err(access.code or 'forbidden', access.message or ChatLocale.T('error_you_cannot_send_to_that_channel'))
    end
    local moderation = dependencies.moderationCanSend(actor, channel)
    if not moderation.ok then return moderation end
    if not dependencies.rateAllowed(source, channel.channelKey, text) then
        return ChatResults.Err('rate_limited', ChatLocale.T('error_you_are_sending_messages_too_quickly'))
    end
    local moderated = dependencies.moderateMessage(actor, channel, text)
    if not moderated.ok then return moderated end
    text, textError = dependencies.normalizeText(moderated.value.text)
    if not text then return ChatResults.Err('invalid_content', textError) end
    if #text > channel.input.maximumLength then
        return ChatResults.Err('invalid_content', ChatLocale.T('error_moderated_message_is_too_long'))
    end
    local recipients, routingError = dependencies.recipients(channel, actor, source)
    if not recipients then return routingError end
    recipients = dependencies.filterRecipients(actor, recipients, channel)
    if not dependencies.isSessionCurrent(source, context.sessionId, context.characterId) then
        return ChatResults.Err('session_stale', ChatLocale.T('error_character_session_changed'))
    end

    sequence = sequence + 1
    local message = {
        messageId=dependencies.newUuid(), channelKey=payload.channelKey,
        channelLabel=channel.shortLabel or channel.label, kind=channel.kind or 'player',
        author=identity.value, body={ text=text, format='plain' },
        presentation=channel.presentation,
        createdAt=dependencies.createdAt(), sequence=sequence
    }
    for _, target in ipairs(recipients) do
        dependencies.recordDelivery(target, message, actor)
        dependencies.deliver(target, message)
    end
    return ChatResults.Ok({
        messageId=message.messageId, submissionId=payload.submissionId, recipientCount=#recipients
    })
end

local function Submit(payload, source, context, testDependencies)
    local dependencies = testDependencies or DefaultDependencies()
    local entry, claimed = Reserve(source, context.sessionId, payload.submissionId)
    if not claimed then
        while entry.state == 'pending' do dependencies.wait() end
        return entry.result
    end
    local called, result = pcall(ProcessSubmission, payload, source, context, dependencies)
    if not called then
        print(ChatLocale.Format('operator_submission_failed_unexpectedly_value', tostring(result)))
        result = ChatResults.Err('internal_error', ChatLocale.T('error_chat_submission_failed'))
    end
    return Complete(source, entry, result)
end

function ChatMessaging.Start()
    if ready then return ChatResults.Ok(true) end
    local registered = exports['feather-core']:RegisterContractRPC('chat.message.submit.v1', Submit, {
        contract=1, direction='client_to_server', requireCharacter=true,
        windowMs=3000, maxCalls=6, maxPayloadBytes=Config.Limits.maxMessageBytes + 256,
        maxDepth=4, maxNodes=16,
        validatePayload=function(payload)
            return ChatContract.ValidateSubmission(payload, Config.Limits)
        end
    })
    if type(registered) ~= 'table' or registered.ok ~= true then return registered end
    ready = true
    return ChatResults.Ok(true)
end

function ChatMessaging.IsReady() return ready end
function ChatMessaging.NormalizeText(text) return NormalizeText(text) end

function ChatMessaging.ConcurrencySmoke()
    local source = -2147483000
    submissions[source], rates[source] = nil, nil
    local deliveries, sessionChecks = 0, 0
    local dependencies = {
        wait=function() coroutine.yield('waiting') end,
        isSessionCurrent=function()
            sessionChecks = sessionChecks + 1
            return true
        end,
        normalizeText=NormalizeText,
        rateAllowed=function() return true end,
        profile=function(characterId)
            coroutine.yield('profile')
            return ChatResults.Ok({ characterId=characterId, displayName='Test Character' })
        end,
        getChannel=function()
            return { channelKey='local.say', label='Say', visibility='public', routing='proximity',
                input={ maximumLength=Config.Limits.maxMessageBytes }, presentation={ variant='speech' } }
        end,
        canSend=function() return ChatResults.Ok({ allowed=true }) end,
        moderationCanSend=function() return ChatResults.Ok({ allowed=true }) end,
        moderateMessage=function(_, _, text) return ChatResults.Ok({ text=text }) end,
        filterRecipients=function(_, recipients) return recipients end,
        recordDelivery=function() end,
        recipients=function() return { source } end,
        newUuid=function() return '00000000-0000-4000-8000-000000000001' end,
        createdAt=function() return '2000-01-01T00:00:00Z' end,
        deliver=function() deliveries = deliveries + 1 end
    }
    local payload = { channelKey='local.say', text='Concurrent', submissionId='smoke:concurrent' }
    local context = { accountId='account', characterId='character', sessionId='session' }
    local firstResult, secondResult
    local first = coroutine.create(function() firstResult = Submit(payload, source, context, dependencies) end)
    local second = coroutine.create(function() secondResult = Submit(payload, source, context, dependencies) end)
    local firstStarted, firstYield = coroutine.resume(first)
    local secondStarted, secondYield = coroutine.resume(second)
    local firstFinished = coroutine.resume(first)
    local secondFinished = coroutine.resume(second)
    local replay = Submit(payload, source, context, dependencies)
    local concurrentPassed = firstStarted and firstYield == 'profile'
        and secondStarted and secondYield == 'waiting' and firstFinished and secondFinished
        and firstResult == secondResult and replay == firstResult and deliveries == 1

    submissions[source], rates[source] = nil, nil
    deliveries, sessionChecks = 0, 0
    dependencies.profile=function(characterId)
        return ChatResults.Ok({ characterId=characterId, displayName='Test Character' })
    end
    dependencies.isSessionCurrent=function()
        sessionChecks = sessionChecks + 1
        return sessionChecks == 1
    end
    local stale = Submit({ channelKey='local.say', text='Stale', submissionId='smoke:stale' },
        source, context, dependencies)
    local stalePassed = stale.ok == false and stale.code == 'session_stale'
        and sessionChecks == 2 and deliveries == 0
    submissions[source], rates[source] = nil, nil
    return {
        { 'concurrent duplicate coalesced', concurrentPassed },
        { 'completed duplicate replayed', replay == firstResult },
        { 'in-flight stale session rejected', stalePassed }
    }
end

function ChatMessaging.RateLimitSmoke()
    local source = -2147482999
    local function Reset()
        rates[source], channelRates[source], repeats[source] = nil, nil, nil
    end
    Reset()
    local repeatFirst = RateAllowed(source, 'local.whisper', 'same')
    local repeatSecond = RateAllowed(source, 'local.whisper', 'same')
    local repeatThird = RateAllowed(source, 'local.whisper', 'same')
    Reset()
    local shout = {}
    for index = 1, 4 do shout[index] = RateAllowed(source, 'local.shout', 'shout-' .. index) end
    Reset()
    local global = {}
    for index = 1, Config.RateLimit.maxMessages + 1 do
        global[index] = RateAllowed(source, 'unprofiled.channel', 'global-' .. index)
    end
    Reset()
    return {
        { 'repeat flood bounded', repeatFirst and repeatSecond and not repeatThird },
        { 'channel profile bounded', shout[1] and shout[2] and shout[3] and not shout[4] },
        { 'global profile bounded', global[Config.RateLimit.maxMessages]
            and not global[Config.RateLimit.maxMessages + 1] }
    }
end

AddEventHandler('playerDropped', function()
    rates[source], channelRates[source], repeats[source], submissions[source] = nil, nil, nil, nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' then ready = false end
end)

