local resourceName = GetCurrentResourceName()
local clientRate = { count = 0, resetsAt = 0 }
local activeTimedPresentations = 0
local timedHandles = {}

local function ClientRateSettings()
    local windowMs = math.min(60000, math.max(100,
        math.floor(tonumber(Config.clientRateWindowMs) or 1000)))
    local maxCalls = math.min(1000, math.max(1,
        math.floor(tonumber(Config.clientMaxCallsPerWindow) or 20)))
    return windowMs, maxCalls
end

local function CheckClientRateLimit()
    local now = GetGameTimer()
    local windowMs, maxCalls = ClientRateSettings()
    if now >= clientRate.resetsAt then
        clientRate.count = 0
        clientRate.resetsAt = now + windowMs
    end
    if clientRate.count >= maxCalls then
        return NotifyResults.Err('rate_limited', 'Notification presentation rate exceeded.', {
            retryAfterMs = math.max(0, clientRate.resetsAt - now),
            maxCalls = maxCalls,
            windowMs = windowMs
        })
    end
    clientRate.count = clientRate.count + 1
    return NotifyResults.Ok(true)
end

local function ResetClientRateLimit()
    clientRate.count = 0
    clientRate.resetsAt = 0
end

local function Buffer(size) return string.rep('\0', math.max(41, size)) end
local function Set(buffer, offset, format, value)
    local packed, first = string.pack('<' .. format, value), offset + 1
    return buffer:sub(1, first - 1) .. packed .. buffer:sub(first + #packed)
end
local function Literal(value)
    return Citizen.InvokeNative(0xFA925AC00EB830B9, 10, 'LITERAL_STRING', tostring(value or ''), Citizen.ResultAsLong())
end
local function Options(duration) return Set(Buffer(56), 0, 'i4', duration) end
local function Content(size, values)
    local content = Buffer(size)
    for _, value in ipairs(values) do content = Set(content, value[1], value[2], value[3]) end
    return content
end

local render = {}
local function Simple(hash, request, size, extra)
    local values = { { 8, 'i8', Literal(request.message) } }
    if extra then extra(values, request) end
    Citizen.InvokeNative(hash, Options(request.duration), Content(size or 24, values), 1)
end
render.tooltip = function(r) Simple(0x049D5C615BD38BAD, r) end
render.right = function(r) Simple(0xB2920B9760F0F36B, r) end
render.left = function(r) Citizen.InvokeNative(0xDD1232B332CBB9E7, 3, 1, 0); Simple(0xCEDBF17EFCC0E4A4, r) end
render.top = function(r) Simple(0x860DDFE97CC94DF0, r, 56) end
render.bottom_right = function(r) Simple(0x2024F4F333095FB1, r, 40) end
render.center = function(r) Simple(0x893128CDB4B81FBB, r, 32, function(v, x)
    v[#v+1] = { 16, 'i8', GetHashKey(x.color or 'COLOR_PURE_WHITE') }
end) end
render.standard = function(r)
    Citizen.InvokeNative(0xC927890AA64E9661, Options(r.duration), Content(48,
        { {8,'i8',Literal(r.message)}, {16,'i8',Literal(r.message)} }), 1, 1)
end
render.location = function(r)
    Citizen.InvokeNative(0xD05590C1AB38F068, Options(r.duration), Content(40,
        { {8,'i8',Literal(r.location)}, {16,'i8',Literal(r.message)} }), 0, 1)
end
render.top_banner = function(r)
    Citizen.InvokeNative(0xA6F4216AB10EB08E, Options(r.duration), Content(56,
        { {8,'i8',Literal(r.title)}, {16,'i8',Literal(r.message)} }), 1, 1)
end
render.advanced = function(r)
    Citizen.InvokeNative(0x26E87218390E6729, Options(r.duration), Content(64, {
        {8,'i8',Literal(r.title)}, {16,'i8',Literal(r.message)}, {32,'i8',GetHashKey(r.dictionary or '')},
        {40,'i8',GetHashKey(r.icon or '')}, {48,'i8',GetHashKey(r.color or 'COLOR_WHITE')} }), 1, 1)
end
render.advanced_right = function(r)
    local options = Options(r.duration)
    options = Set(options, 8, 'i8', Literal('Transaction_Feed_Sounds'))
    options = Set(options, 16, 'i8', Literal('Transaction_Positive'))
    Citizen.InvokeNative(0xB249EBCB30DD88E0, options, Content(80, {
        {8,'i8',Literal(r.message)}, {16,'i8',Literal(r.dictionary)}, {24,'i8',GetHashKey(r.icon or '')},
        {40,'i8',GetHashKey(r.color or 'COLOR_WHITE')}, {48,'i4',tonumber(r.quality) or 1} }), 1)
end
local function Timed(hash, r, mode)
    local maximum = math.min(64, math.max(1,
        math.floor(tonumber(Config.maxTimedPresentations) or 8)))
    if activeTimedPresentations >= maximum then
        return NotifyResults.Err('rate_limited', 'Timed notification concurrency exceeded.', {
            active = activeTimedPresentations,
            maximum = maximum
        })
    end
    local options, values = Buffer(40), nil
    if mode == 'audio' then
        options = Set(options, 0, 'i8', Literal(r.audioSource)); options = Set(options, 8, 'i8', Literal(r.audioName))
        options = Set(options, 16, 'i2', 4)
        values = r.style == 'warning' and { {16,'i8',Literal(r.title)}, {24,'i8',Literal(r.message)} }
            or { {8,'i8',Literal(r.message)} }
    else values = { {8,'i8',Literal(r.title)}, {16,'i8',Literal(r.message)} } end
    local handle = Citizen.InvokeNative(hash, options, Content(72, values), 1)
    if handle == nil then
        return NotifyResults.Err('presentation_failed', 'Timed notification did not return a presentation handle.', {
            style = r.style
        })
    end
    activeTimedPresentations = activeTimedPresentations + 1
    timedHandles[handle] = true
    CreateThread(function()
        Wait(r.duration)
        if timedHandles[handle] then
            timedHandles[handle] = nil
            activeTimedPresentations = math.max(0, activeTimedPresentations - 1)
            pcall(Citizen.InvokeNative, 0x00A15B94CBA4F76F, handle)
        end
    end)
    return NotifyResults.Ok(true)
end
render.mission_failed = function(r) Timed(0x9F2CC2439A04E7BA, r) end
render.dead_player = function(r) Timed(0x815C4065AE6E6071, r, 'audio') end
render.warning = function(r) Timed(0x339E16B41780FC35, r, 'audio') end

local function Show(request)
    local validated = NotifyContract.Validate(request)
    if not validated.ok then return validated end
    local rate = CheckClientRateLimit()
    if not rate.ok then return rate end
    local displayed, renderResult = pcall(render[validated.value.style], validated.value)
    if not displayed then
        return NotifyResults.Err('presentation_failed', 'Notification presentation failed.', {
            style = validated.value.style
        })
    end
    if type(renderResult) == 'table' and renderResult.ok == false then return renderResult end
    return NotifyResults.Ok({ displayed=true, style=validated.value.style })
end
exports('ShowNotification', Show)
RegisterNetEvent('feather-notify:show.v1', function(request)
    local result = Show(request)
    if not result.ok then
        print(('[feather-notify] presentation rejected code=%s style=%s'):format(
            tostring(result.code or 'invalid_result'),
            tostring(type(request) == 'table' and request.style or 'unknown')))
    end
end)
RegisterCommand('NotifyClientSmokeTest', function()
    ResetClientRateLimit()
    local right = Show({style='right', message='Feather Notify right notification.', duration=2500})
    local banner = Show({style='top_banner', title='Feather Notify', message='Top banner presentation is working.', duration=2500})
    local invalid = Show({style='unknown', message='invalid'})
    local invalidField = Show({style='right', message='invalid', dictionary={}})
    local limits = NotifyContract.Limits()
    local oversized = Show({style='right', message=string.rep('x', limits.maxMessageLength + 1)})
    local excessiveDuration = Show({style='right', message='invalid', duration=limits.maxDurationMs + 1})
    local fractionalQuality = Show({style='right', message='invalid', quality=1.5})
    local unknownField = Show({style='right', message='invalid', unexpected=true})
    local recursive = { style='right', message='invalid' }
    recursive.dictionary = recursive
    local recursiveField = Show(recursive)
    local boundariesRejected = not oversized.ok and not excessiveDuration.ok
        and not fractionalQuality.ok and not unknownField.ok and not recursiveField.ok
    print(('[NotifyClientSmokeTest] right=%s top_banner=%s invalid_rejected=%s invalid_field_rejected=%s boundaries_rejected=%s'):format(
        tostring(right.ok), tostring(banner.ok), tostring(invalid.ok == false),
        tostring(invalidField.ok == false and invalidField.code == 'invalid_input'),
        tostring(boundariesRejected)))
end, false)

RegisterCommand('NotifyClientLimitSmokeTest', function()
    CreateThread(function()
        ResetClientRateLimit()
        local windowMs, maximum = ClientRateSettings()
        local accepted = true
        for _ = 1, maximum do
            if not CheckClientRateLimit().ok then accepted = false break end
        end
        local limited = CheckClientRateLimit()
        Wait(windowMs + 50)
        local recovered = CheckClientRateLimit()
        ResetClientRateLimit()
        print(('[NotifyClientLimitSmokeTest] accepted=%s limited=%s recovered=%s'):format(
            tostring(accepted),
            tostring(not limited.ok and limited.code == 'rate_limited'),
            tostring(recovered.ok == true)))
    end)
end, false)

RegisterCommand('NotifyStyleSmokeTest', function()
    ResetClientRateLimit()
    local samples = {
        {style='tooltip', message='Tooltip'}, {style='advanced', title='Advanced', message='Advanced', dictionary='generic_textures', icon='tick', color='COLOR_WHITE'},
        {style='location', message='Location message', location='Valentine'}, {style='right', message='Right'},
        {style='left', message='Left'}, {style='top_banner', title='Top Banner', message='Top banner'},
        {style='advanced_right', message='Advanced right', dictionary='generic_textures', icon='tick', color='COLOR_WHITE', quality=1},
        {style='top', message='Top'}, {style='center', message='Center', color='COLOR_PURE_WHITE'},
        {style='standard', message='Standard'}, {style='bottom_right', message='Bottom right'},
        {style='mission_failed', title='Mission Failed', message='Test presentation'},
        {style='dead_player', message='Dead player', audioSource='', audioName=''},
        {style='warning', title='Warning', message='Warning presentation', audioSource='', audioName=''}
    }
    CreateThread(function()
        local passed = 0
        for _, sample in ipairs(samples) do
            sample.duration = 1500
            local result = Show(sample)
            if result.ok then passed = passed + 1 end
            print(('[NotifyStyleSmokeTest] %-18s %s'):format(sample.style, result.ok and 'PASS' or 'FAIL'))
            Wait(1800)
        end
        print(('[NotifyStyleSmokeTest] done %d/%d dispatched; verify each presentation visually'):format(passed, #samples))
    end)
end, false)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource ~= resourceName then return end
    for handle in pairs(timedHandles) do
        pcall(Citizen.InvokeNative, 0x00A15B94CBA4F76F, handle)
        timedHandles[handle] = nil
    end
    activeTimedPresentations = 0
end)
