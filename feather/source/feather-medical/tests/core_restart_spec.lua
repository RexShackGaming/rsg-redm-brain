local threads, handlers, callbacks = {}, {}, {}
local declarations, registrations, pause = 0, 0, false
local policies = {}
Config = {medical = {enabled = true, persistentDeath = true, temporarySpawnEnabled = true}, hospitals = {}}
MedicalGameplay = {}
MedicalLifecycle = {ValidateConfig = function() return true end}
MedicalMigration = {Run = function() end}
MedicalHospitals = {Validate = function() return true end, HasEnabled = function() return false end}
MedicalOutbox = {event = 'medical.condition.changed.v1', Validate = function() return true end}
DB = {awaitReady = function() if pause then coroutine.yield() end end}
exports = setmetatable({['feather-core'] = {
    DeclareEvent = function() declarations = declarations + 1; return {ok = true} end,
    RegisterRpc = function(_, name, callback, policy) policies[name] = policy; registrations = registrations + 1; return {ok = true} end
}}, {__call = function(_, name, fn) callbacks[name] = fn end})
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
RegisterCommand = function() end
AddEventHandler = function(name, fn) handlers[name] = fn end
dofile('server/main.lua')
local function tick(i) local ok, err = coroutine.resume(threads[i]); assert(ok, err) end
tick(1)
assert(callbacks.GetHealth().state == 'ready' and registrations == 5 and declarations == 1, 'initial contract registration')
assert(policies['medical.observation.lethal.v1'].validatePayload({expectedRevision = 0})
    and not policies['medical.observation.lethal.v1'].validatePayload({expectedRevision = 0, characterId = 'forged'}), 'observation accepts revision but rejects identity claims')
assert(not policies['medical.recovery.ack.v1'].validatePayload({operationId = string.rep('a',36)})
    and policies['medical.recovery.ack.v1'].validatePayload({operationId = string.rep('a',36), deliveryToken = string.rep('b',36)}), 'ack requires delivery token')
assert(not policies['medical.recovery.doctor.request.v1'].validatePayload({position = {x = 0}}), 'client coordinates rejected')
handlers.onResourceStop('feather-core')
assert(not MedicalGameplay.Ready() and callbacks.GetHealth().phase == 'core_stopped', 'Core stop makes gameplay unavailable')
handlers.onResourceStart('feather-core'); tick(4)
assert(MedicalGameplay.Ready() and registrations == 10 and declarations == 2, 'Core restart redeclares event and all routes')
handlers.onResourceStop('feather-core'); pause = true
handlers.onResourceStart('feather-core'); tick(5)
handlers.onResourceStop('feather-core'); pause = false
tick(5)
assert(not MedicalGameplay.Ready() and registrations == 10, 'superseded startup cannot restore stale readiness/contracts')
print('PASS 7 Core lifecycle/route harness checks')
