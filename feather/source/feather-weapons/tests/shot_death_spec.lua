local command, thread, killed, logs
local total, tick, state, requestedMode
local function reset()
    command, thread, killed, logs = nil, nil, 0, {}
    total, tick = 6, 0
    state = {primary = 1, offhand = 12, primaryGeneration = 1, offhandGeneration = 2,
        epoch = 1, restoreGeneration = 1, ammoHash = 10, expected = 6}
    Config = {DevMode = true}
    FeatherWeaponsClient = {GetShotDeathContext = function(mode)
        requestedMode = mode
        local snapshot = {}
        for key, value in pairs(state) do snapshot[key] = value end
        return snapshot
    end}
    RegisterCommand = function(_, fn) command = fn end
    PlayerPedId = function() return 10 end
    GetPedAmmoByType = function() return total end
    GetGameTimer = function() return tick end
    SetEntityHealth = function(_, health) assert(health == 0); killed = killed + 1 end
    print = function(message) logs[#logs + 1] = message end
    CreateThread = function(fn) thread = coroutine.create(fn) end
    Wait = function() coroutine.yield() end
    dofile('tests/archive/client/dev_shot_death.lua')
end
local function step() local ok, err = coroutine.resume(thread); assert(ok, err) end
reset()
command(0, {'2'})
step()
total = 5; step(); assert(killed == 0)
total = 4; step(); assert(killed == 1 and logs[#logs]:find('observed=2'))
reset(); command(0, {'2'}); step()
command(0, {'cancel'}); step(); assert(killed == 0)
reset(); command(0, {'2'}); step()
state.epoch = 2; total = 4; step(); assert(killed == 0)
reset(); command(0, {'2'}); step()
tick = 30000; step(); assert(killed == 0)
reset(); command(0, {'2'}); step()
total = 7; step(); assert(killed == 0)
reset(); total = 5; command(0, {'2'}); assert(thread == nil and killed == 0)
reset(); command(0, {'0'}); assert(thread == nil)
reset(); command(0, {'1', 'longguns'}); assert(requestedMode == 'longguns'); step()
total = 5; step(); assert(killed == 1)
reset(); state.selectedHash = 20; command(0, {'1', 'longguns'}); step()
state.selectedHash = 21; total = 5; step(); assert(killed == 0)
reset(); command(0, {'1', 'invalid'}); assert(thread == nil)
reset(); Config.DevMode = false; command = nil
dofile('tests/archive/client/dev_shot_death.lua'); assert(command == nil)
io.write('PASS shot-death trigger, cancel, context, timeout, increase, mismatch, args, dev gate\n')
