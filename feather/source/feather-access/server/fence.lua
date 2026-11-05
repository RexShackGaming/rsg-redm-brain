-- Serializes grant writes with trusted Inventory mutation callbacks. No SQL lock
-- is held while preparing domain/provider decisions. A timeout never releases an
-- executing callback; uncertain resource-stop state latches closed until restart.
Access.InventoryFence = {}
local F, held, sequence, stopped = Access.InventoryFence, nil, 0, false
local function Acquire(owner)
    local started = GetGameTimer()
    while held and not stopped do
        if GetGameTimer() - started >= 5000 then return nil end
        Wait(0)
    end
    if stopped then return nil end
    sequence = sequence + 1
    held = {owner = owner, token = tostring(sequence) .. ':' .. tostring(GetGameTimer())}
    return held
end
local function Execute(owner, fn)
    local lock = Acquire(owner)
    if not lock then return Access.Err('operation_timeout', 'Inventory authorization fence unavailable; retry or restart Access after stopped consumers.') end
    local called, result = pcall(fn, lock.token)
    if held == lock then held = nil end
    if not called then return Access.Err('internal_error', 'Inventory authorization callback failed.') end
    return result
end
function F.Mutate(fn, request, caller)
    return Execute(GetCurrentResourceName(), function() return fn(request, caller) end)
end
function F.Run(callback, caller)
    if caller ~= 'feather-inventory' or Config.Grants.Readers[caller] ~= true then
        return Access.Err('authorization_denied', 'Trusted Inventory callback required.')
    end
    local mt = (type(callback) == 'table' or type(callback) == 'userdata') and getmetatable(callback)
    if type(callback) ~= 'function' and not (type(mt) == 'table' and type(mt.__call) == 'function') then
        return Access.Err('invalid_input', 'Callable Inventory transaction required.')
    end
    local ready = Access.Ready(); if not ready.ok then return ready end
    return Execute(caller, function(token) return Access.Ok(callback(token)) end)
end
function F.Valid(token, caller)
    return Access.Ok(not stopped and caller == 'feather-inventory' and held ~= nil
        and held.owner == caller and held.token == token)
end
function F.Stopped(resource)
    if held and (held.owner == resource or resource == GetCurrentResourceName()
        or resource == 'feather-mysql' or resource == 'feather-core') then stopped = true end
end
function F.State() return {held = held ~= nil, owner = held and held.owner or nil, stopped = stopped} end
