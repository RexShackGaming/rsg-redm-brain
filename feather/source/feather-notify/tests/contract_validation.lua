local passed = 0
local failed = 0

local function Check(name, condition)
    if condition then
        passed = passed + 1
        print(('[contract] %-42s PASS'):format(name))
        return
    end

    failed = failed + 1
    print(('[contract] %-42s FAIL'):format(name))
end

local function IsOk(result)
    return type(result) == 'table' and result.ok == true
end

local function IsError(result, code)
    return type(result) == 'table' and result.ok == false and result.code == code
end

dofile('config.lua')
dofile('shared/results.lua')
dofile('shared/contract.lua')

Check('contract version', NotifyContract.Version == 1)
Check('public style set contains 14 styles', (function()
    local count = 0
    for _ in pairs(NotifyContract.Styles) do count = count + 1 end
    return count == 14
end)())
Check('public request set contains 11 fields', (function()
    local count = 0
    for _ in pairs(NotifyContract.Fields) do count = count + 1 end
    return count == 11
end)())
Check('default style and duration', (function()
    local result = NotifyContract.Validate({ message = 'Hello' })
    return IsOk(result) and result.value.style == 'right'
        and result.value.duration == Config.defaultDurationMs
end)())
Check('complete request accepted', IsOk(NotifyContract.Validate({
    style='advanced',
    message='Contract validation',
    title='Title',
    duration=1000,
    location='Valentine',
    dictionary='generic_textures',
    icon='tick',
    color='COLOR_WHITE',
    quality=1,
    audioSource='HUD_SHOP_SOUNDSET',
    audioName='PURCHASE'
})))

for style in pairs(NotifyContract.Styles) do
    local request = { style = style, message = 'Contract validation', duration = 1 }
    if style == 'top_banner' or style == 'advanced'
        or style == 'mission_failed' or style == 'warning' then
        request.title = 'Title'
    end
    Check(('style accepted: %s'):format(style), IsOk(NotifyContract.Validate(request)))
end

Check('non-table request rejected', IsError(NotifyContract.Validate('invalid'), 'invalid_input'))
Check('unknown field rejected', IsError(NotifyContract.Validate({ message='Hi', extra=true }), 'invalid_input'))
Check('unknown style rejected', IsError(NotifyContract.Validate({ message='Hi', style='unknown' }), 'invalid_input'))
Check('missing message rejected', IsError(NotifyContract.Validate({}), 'invalid_input'))
Check('empty message rejected', IsError(NotifyContract.Validate({ message='' }), 'invalid_input'))
Check('oversized message rejected', IsError(NotifyContract.Validate({
    message=string.rep('m', Config.maxMessageLength + 1)
}), 'invalid_input'))
Check('maximum message accepted', IsOk(NotifyContract.Validate({
    message=string.rep('m', Config.maxMessageLength)
})))
Check('fractional duration rejected', IsError(NotifyContract.Validate({ message='Hi', duration=1.5 }), 'invalid_input'))
Check('zero duration rejected', IsError(NotifyContract.Validate({ message='Hi', duration=0 }), 'invalid_input'))
Check('oversized duration rejected', IsError(NotifyContract.Validate({
    message='Hi', duration=Config.maxDurationMs + 1
}), 'invalid_input'))
Check('maximum duration accepted', IsOk(NotifyContract.Validate({
    message='Hi', duration=Config.maxDurationMs
})))
Check('required title rejected', IsError(NotifyContract.Validate({
    style='top_banner', message='Hi'
}), 'invalid_input'))
Check('oversized title rejected', IsError(NotifyContract.Validate({
    style='top_banner', message='Hi', title=string.rep('t', Config.maxTitleLength + 1)
}), 'invalid_input'))
Check('oversized location rejected', IsError(NotifyContract.Validate({
    style='location', message='Hi', location=string.rep('l', Config.maxLocationLength + 1)
}), 'invalid_input'))
Check('non-string identifier rejected', IsError(NotifyContract.Validate({
    message='Hi', dictionary={}
}), 'invalid_input'))
Check('oversized identifier rejected', IsError(NotifyContract.Validate({
    message='Hi', icon=string.rep('i', Config.maxIdentifierLength + 1)
}), 'invalid_input'))
Check('fractional quality rejected', IsError(NotifyContract.Validate({ message='Hi', quality=1.5 }), 'invalid_input'))
Check('quality below minimum rejected', IsError(NotifyContract.Validate({
    message='Hi', quality=Config.minQuality - 1
}), 'invalid_input'))
Check('quality above maximum rejected', IsError(NotifyContract.Validate({
    message='Hi', quality=Config.maxQuality + 1
}), 'invalid_input'))
Check('quality bounds accepted', (function()
    local minimum = NotifyContract.Validate({ message='Hi', quality=Config.minQuality })
    local maximum = NotifyContract.Validate({ message='Hi', quality=Config.maxQuality })
    return IsOk(minimum) and IsOk(maximum)
end)())
Check('normalized result is detached', (function()
    local request = { message='Hi', title='Original' }
    local result = NotifyContract.Validate(request)
    request.title = 'Changed'
    return IsOk(result) and result.value.title == 'Original' and result.value ~= request
end)())

print(('[contract] done %d/%d passed'):format(passed, passed + failed))
if failed > 0 then os.exit(1) end
