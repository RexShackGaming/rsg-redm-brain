local Assert = _G.TestAssert
dofile('schemas/admin/action_recorded_v1.lua')
local oldPrint = print
print = function() end
local rows, objects, writes, transactions = {}, {}, 0, 0
local state, failure, transportMode = 'started', false, 'accepted'
Config.audit = { sourceInstance = 'default', batchSize = 25, pollMilliseconds = 5000 }
AdminDatabase = { ready = true }
FeatherAdmin = { Identity = { Resolve = function() return { accountId = 'account-1', characterId = 'character-1', characterName = 'Test Actor' } end } }
CreateThread = function() end
RegisterCommand = function() end
GetGameTimer = function() return 0 end
GetPlayerName = function() return 'Player' end
GetResourceState = function() return state end
json = { encode = function(event)
    local key = 'payload-' .. tostring(#objects + 1); objects[#objects + 1] = event; objects[key] = event; return key
end, decode = function(payload) assert(objects[payload]); return objects[payload] end }
local counter = 0
DB = {
    value = function() counter = counter + 1; return ('00000000-0000-0000-0000-%012d'):format(counter) end,
    insert = function(sql, id, payload)
        if failure then error('database outage') end
        writes = writes + 1
        rows[#rows + 1] = { eventId = id, payload = payload, state = 'pending', attemptCount = 0 }
    end,
    transaction = function(callback)
        transactions = transactions + 1
        return callback({ query = function() local leased = {}; for _, row in ipairs(rows) do
            if row.state == 'pending' or row.state == 'leased' then leased[#leased + 1] = row end end; return leased end,
            exec = function(_, owner, expires, id) for _, row in ipairs(rows) do if row.eventId == id then row.state = 'leased'; row.owner = owner end end end })
    end,
    exec = function(sql, ...)
        local args = table.pack(...)
        for _, row in ipairs(rows) do
            if sql:find("state='delivered'", 1, true) and row.eventId == args[3] and row.owner == args[4] then row.state = 'delivered'
            elseif sql:find("state='pending'", 1, true) and row.eventId == args[3] then row.state = 'pending'
            elseif sql:find("state='quarantined'", 1, true) and row.eventId == args[2] then row.state = 'quarantined' end
        end
    end
}
exports = { ['feather-audit'] = { Ingest = function(_, event)
    if transportMode == 'throw' then error('stopped during publish') end
    Assert.truthy(FeatherAuditValidator.Validate(event).ok, 'actual event contract accepts producer')
    return { result = transportMode, auditEventId = '00000000-0000-0000-0000-000000000001', code = 'test_quarantine' }
end } }
dofile('../feather-admin/server/services/audit_log.lua')
local target = { accountId = 'target-account', characterId = 'target-character', characterName = 'Test Target' }
local id = AdminAudit.RecordTarget(1, 'staff.role.assign', target, 'license:secret https://discord.com/api/webhooks/secret')
Assert.truthy(id)
local event = objects[rows[1].payload]
Assert.equal(2, #event.targets)
Assert.equal('character-1', event.actor.id)
Assert.falsy(event.context.details:find('secret', 1, true))
Assert.equal('admin-account:target-account', event.correlationId)
Assert.equal('denied', AdminAudit.BuildEvent('id', {}, 'staff.role.assign.blocked', nil, '').result)
Assert.equal('failed', AdminAudit.BuildEvent('id', {}, 'inventory.remove.failed', nil, '').result)
state = 'stopped'
AdminAudit.PublishOnce()
Assert.equal(0, transactions, 'Audit stopped leaves durable queue untouched')
state, transportMode = 'started', 'throw'
AdminAudit.PublishOnce()
Assert.equal('pending', rows[1].state, 'transport failure retried')
Assert.equal(id, rows[1].eventId)
transportMode = 'duplicate'
AdminAudit.PublishOnce()
Assert.equal('delivered', rows[1].state, 'duplicate ack closes same durable record')
failure = true
Assert.equal(nil, AdminAudit.RecordTarget(0, 'test.action', nil, 'safe'))
Assert.equal(1, writes, 'queue failure cannot claim durable success')
failure = false
AdminAudit.RecordTarget(0, 'test.action', nil, 'safe')
transportMode = 'quarantined'
AdminAudit.PublishOnce()
Assert.equal('quarantined', rows[2].state)
print = oldPrint
