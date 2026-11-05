ToolkitKeys = { listeners = {}, nextId = 0 }

local function IsCallable(value)
    return type(value) == 'function'
        or (type(value) == 'table' and type(rawget(value, '__cfx_functionReference')) == 'string')
end

function ToolkitKeys.Register(owner, control, callback, mode)
    local resolved = ToolkitControls.Resolve(control)
    if not resolved.ok or not IsCallable(callback) then
        return ToolkitResults.Err('invalid_input', 'Control and callback are required.')
    end

    control = resolved.value
    mode = mode or 'just_pressed'
    if mode ~= 'just_pressed' and mode ~= 'pressed' then
        return ToolkitResults.Err('invalid_input', 'Key listener mode must be just_pressed or pressed.')
    end

    local count = 0
    for _ in pairs(ToolkitKeys.listeners) do
        count = count + 1
    end

    if count >= Config.MaxKeyListeners then
        return ToolkitResults.Err('limit_exceeded', 'Key listener limit reached.')
    end

    ToolkitKeys.nextId = ToolkitKeys.nextId + 1
    local id = ('key:%d'):format(ToolkitKeys.nextId)
    ToolkitKeys.listeners[id] = { owner = owner, control = control, callback = callback, mode = mode }

    return ToolkitResults.Ok({ id = id, mode = mode })
end

function ToolkitKeys.Remove(owner, id)
    local item = ToolkitKeys.listeners[id]
    if not item then
        return ToolkitResults.Err('not_found', 'Key listener was not found.')
    end

    if item.owner ~= owner then
        return ToolkitResults.Err('forbidden', 'Key listener belongs to another resource.')
    end

    ToolkitKeys.listeners[id] = nil
    return ToolkitResults.Ok({ removed = true, id = id })
end

function ToolkitKeys.Cleanup(owner)
    local n = 0
    for id, v in pairs(ToolkitKeys.listeners) do
        if v.owner == owner then
            ToolkitKeys.listeners[id] = nil
            n = n + 1
        end
    end
    return n
end

function ToolkitKeys.CleanupAll()
    local count = 0
    for id in pairs(ToolkitKeys.listeners) do
        ToolkitKeys.listeners[id] = nil
        count = count + 1
    end
    return count
end

CreateThread(function()
    while true do
        Wait(0)
        for _, v in pairs(ToolkitKeys.listeners) do
            local active = v.mode == 'pressed' and Citizen.InvokeNative(0x580417101DDB492F, 0, v.control)
                or Citizen.InvokeNative(0x91AEF906BCA88877, 0, v.control)
            if active then
                local ok, err = pcall(v.callback)
                if not ok then
                    print(('[feather-toolkit] key callback failed: %s'):format(err))
                end
            end
        end
    end
end)
