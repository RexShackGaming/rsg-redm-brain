local Assert = _G.TestAssert
local event = {
    sourceResource = 'test', sourceInstance = 'test-1', eventId = 'event-1',
    eventType = 'audit.smoke.ingested', eventVersion = 1, contractVersion = 1,
    occurredAt = '2026-10-08T00:00:00Z', actor = { type = 'system', id = 'test' },
    result = 'success', reasonCode = 'smoke_test', summary = 'Safe fixture',
    sensitivityClass = 'internal', retentionClass = 'operational',
    targets = { { type = 'resource', id = 'test', role = 'subject' } },
    references = { { resource = 'test', type = 'operation', id = 'operation-1' } }
}
local found, failure, calls = nil, nil, {}
DB = {
    one = function() return found end,
    value = function() return 'audit-id-1' end,
    transaction = function(callback)
        if failure == 'error' then error('database unavailable') end
        if failure == 'rejected' then return false end
        if failure == 'race' then
            found = { canonicalPayload = 'canonical', auditEventId = 'race-id' }
            return false
        end
        return callback({ raw = function(query, ...)
            local parameters = table.pack(...)
            local _, placeholders = query:gsub('%?', '')
            Assert.equal(placeholders, parameters.n, 'all SQL placeholders must receive parameters including nil')
            calls[#calls + 1] = parameters
        end })
    end
}
dofile('server/repositories/events.lua')
local outcome, id = FeatherAuditEventRepository.Accept(event, 'canonical', '{}')
Assert.equal('accepted', outcome)
Assert.equal('audit-id-1', id)
Assert.equal(3, #calls)
Assert.equal(25, calls[1].n)
Assert.equal(nil, calls[1][9])
Assert.equal('canonical', calls[1][25])
Assert.equal(7, calls[2].n)
Assert.equal(nil, calls[2][7])
Assert.equal(5, calls[3].n)
failure = 'rejected'
local _, _, code = FeatherAuditEventRepository.Accept(event, 'canonical', '{}')
Assert.equal('transaction_rejected', code)
failure = 'error'
_, _, code = FeatherAuditEventRepository.Accept(event, 'canonical', '{}')
Assert.equal('database_error', code)
failure = 'race'
outcome, id = FeatherAuditEventRepository.Accept(event, 'canonical', '{}')
Assert.equal('duplicate', outcome)
Assert.equal('race-id', id)
outcome = FeatherAuditEventRepository.Accept(event, 'changed', '{}')
Assert.equal('identity_conflict', outcome)
