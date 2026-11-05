local Assert = _G.TestAssert
local commands, messages, writes = {}, {}, 0
local originalPrint = print
GetCurrentResourceName = function() return 'feather-audit-smoke-producer' end
RegisterCommand = function(name, callback) commands[name] = callback end
CreateThread = function(callback) callback() end
print = function(message) messages[#messages + 1] = message end
SmokeConfig = { sourceInstance = 'test-1' }
json = { decode = function() return { eventId = 'fixture-event' } end }
local result = { result = 'duplicate', auditEventId = 'original-id' }
exports = { ['feather-audit'] = { Ingest = function() return result end } }
DB = {
    awaitReady = function() end,
    exec = function() writes = writes + 1 end,
    one = function() return { payloadJson = '{}', auditEventId = 'original-id', eventId = 'fixture-event' } end
}
dofile('../feather-audit-smoke-producer/server.lua')
local setupWrites = writes
commands.AuditProducerReplaySmokeTest(0)
Assert.truthy(messages[#messages]:find('PASS', 1, true))
Assert.equal(setupWrites, writes, 'replay must not change an outbox row or select another pending event')
result = { result = 'accepted', auditEventId = 'original-id' }
commands.AuditProducerReplaySmokeTest(0)
Assert.truthy(messages[#messages]:find('FAIL', 1, true), 'replay must specifically require duplicate')
result = { result = 'duplicate', auditEventId = 'different-id' }
commands.AuditProducerReplaySmokeTest(0)
Assert.truthy(messages[#messages]:find('FAIL', 1, true), 'changed receiver identity must fail')
result = { result = 'accepted', auditEventId = 'original-id' }
commands.AuditProducerLostAckSmokeTest(0)
Assert.truthy(messages[#messages]:find('PASS', 1, true))
Assert.equal(setupWrites, writes, 'lost acknowledgement must leave durable outbox untouched')
commands.AuditProducerLostAckSmokeTest(1)
Assert.truthy(messages[#messages]:find('server console only', 1, true))
exports['feather-audit'].Ingest = function() error('fixture export unavailable') end
commands.AuditProducerPublishSmokeTest(0)
Assert.truthy(messages[#messages]:find('transport_failure:', 1, true))
Assert.truthy(messages[#messages]:find('fixture export unavailable', 1, true))
print = originalPrint
