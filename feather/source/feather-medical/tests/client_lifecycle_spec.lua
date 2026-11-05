local reader, events = nil, {}
local current = {characterId = 'character', sessionId = 'session'}
GetResourceState = function() return 'started' end
exports = setmetatable({}, {__call = function(_, name, fn) reader = fn end})
exports['feather-character'] = {GetMedicalContext = function() return current end}
TriggerEvent = function(name, value)
    assert(name == 'feather-medical:client:condition-changed.v1')
    events[#events + 1] = value
end
dofile('client/lifecycle.lua')
assert(reader().code == 'condition_unavailable')
local snapshot = {characterId = 'character', sessionId = 'session', lifeState = 'dead', revision = 2}
assert(MedicalClientLifecycle.Publish(snapshot, current).ok)
assert(reader().value.lifeState == 'dead' and #events == 1)
events[1].lifeState = 'alive'
assert(reader().value.lifeState == 'dead', 'notification cannot mutate cache')
assert(MedicalClientLifecycle.Publish(snapshot, current).ok and #events == 1)
snapshot.revision = 1
assert(MedicalClientLifecycle.Publish(snapshot, current).code == 'stale_condition')
snapshot.revision, snapshot.lifeState = 3, 'alive'
assert(MedicalClientLifecycle.Publish(snapshot, current).ok and #events == 2)
local read = reader().value
read.lifeState = 'dead'
assert(reader().value.lifeState == 'alive', 'reader cannot mutate cache')
local previous = current
current = {characterId = 'character', sessionId = 'replacement'}
assert(reader().code == 'condition_unavailable')
assert(MedicalClientLifecycle.Publish(snapshot, previous).code == 'stale_session')
assert(MedicalClientLifecycle.Publish(snapshot, current).code == 'invalid_condition')
current = nil
assert(reader().code == 'no_character')
print('PASS Medical client lifecycle cache: identity, revision, deduplication, copy isolation')
