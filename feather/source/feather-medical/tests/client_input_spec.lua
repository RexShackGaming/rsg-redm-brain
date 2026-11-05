local threads, commands = {}, {}
local enabled, focused, pressed, doctorRequests = false, 0, true, 0
local deadline = 1
Config = {medical = {enabled = true, respawnKey = 'E'}}
exports = {
    ['feather-toolkit'] = {ResolveControl = function() return {ok = true, value = 123} end},
    ['feather-character'] = {GetMedicalContext = function() return {sessionId = 'session', characterId = 'character'} end},
    ['feather-core'] = {CallRPCAsync = function(_, name)
        if name == 'medical.condition.get.v1' then return {ok = true, value = {
            characterId = 'character', sessionId = 'session',
            lifeState = 'dead', revision = 1, doctorAvailableAt = deadline, serverTime = 2}} end
        if name == 'medical.recovery.pending.v1' then return {ok = true, value = {pending = false}} end
        assert(name == 'medical.recovery.doctor.request.v1')
        doctorRequests = doctorRequests + 1
        return {ok = true, value = {operationId = 'operation'}}
    end}
}
setmetatable(exports, {__call = function() end})
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
RegisterCommand = function(name, fn) commands[name] = fn end
AddEventHandler = function() end
SendNUIMessage = function() end
TriggerEvent = function() end
GetResourceState = function() return 'started' end
GetGameTimer = function() return 0 end
PlayerPedId = function() return 10 end
DoesEntityExist = function() return true end
GetEntityModel = function() return 20 end
IsEntityDead = function() return 1 end
GetEntityHealth = function() return 0 end
IsNuiFocused = function() return focused end
EnableControlAction = function(_, control, active) assert(control == 123 and active); enabled = true end
IsControlJustPressed = function() return enabled and pressed and 1 or 0 end
IsDisabledControlJustPressed = function() return pressed and 1 or 0 end
json = {encode = function() return '{}' end}
MedicalInput = nil -- Observer input remains independent of the old input helper.
dofile('client/lifecycle.lua') -- Match the manifest's lifecycle-before-observer order.
dofile('client/observer.lua')
local function tick(index) local ok, err = coroutine.resume(threads[index]); assert(ok, err) end
tick(1); tick(1); tick(1) -- stable world ped, persisted dead snapshot, expired deadline
tick(2)
assert(enabled and #threads == 3, 'eligible dead input must enable configured control and dispatch request')
tick(3)
assert(doctorRequests == 1, 'key must reach existing server recovery route')
focused, enabled = 1, false
tick(2)
assert(not enabled and #threads == 3 and doctorRequests == 1, 'Admin focus must not enable key or dispatch recovery')
focused, deadline, enabled = 0, 10, false
tick(1); tick(2)
assert(not enabled and #threads == 3, 'before deadline control must not enable or dispatch')
print('PASS 4 client input integration harness checks (mock natives/transport)')
