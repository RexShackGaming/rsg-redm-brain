local Assert = _G.TestAssert

local event, validation = FeatherAuditProducerEvent.Build({
    eventType = 'economy.transfer.completed',
    sourceResource = 'feather-economy',
    sourceInstance = 'test-1',
    actor = { type = 'system', id = 'fixture' },
    targets = {
        { type = 'account', id = 'one', role = 'debit' },
        { type = 'account', id = 'two', role = 'credit' }
    },
    result = 'success',
    reasonCode = 'fixture',
    context = { amount = 1, currency = 'dollars' },
    sensitivityClass = 'internal',
    retentionClass = 'financial'
}, {
    generateEventId = function() return 'fixed-event-id' end,
    nowEpoch = function() return 1788377071 end,
    validationNowEpoch = function() return 1788377071 end
})

Assert.truthy(event)
Assert.truthy(validation.ok)
Assert.equal('fixed-event-id', event.eventId)
Assert.equal('2026-09-02T19:24:31Z', event.occurredAt)
