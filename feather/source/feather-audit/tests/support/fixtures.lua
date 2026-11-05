local Fixtures = {}

function Fixtures.validTransfer(overrides)
    local event = {
        contractVersion = 1,
        eventId = '01JTESTEVENT00000000000000',
        eventType = 'economy.transfer.completed',
        eventVersion = 1,
        occurredAt = '2026-09-02T18:24:31.123Z',
        sourceResource = 'feather-economy',
        sourceInstance = 'test-1',
        invokingResource = 'bcc-shops',
        correlationId = 'order-221',
        causationId = 'request-220',
        actor = { type = 'character', id = 'character-123', displayName = 'James' },
        targets = {
            { type = 'account', id = 'account-player-123', role = 'debit' },
            { type = 'account', id = 'account-saloon', role = 'credit' }
        },
        references = {
            { resource = 'bcc-shops', type = 'shop_order', id = 'order-221' }
        },
        result = 'success',
        reasonCode = 'shop_purchase',
        summary = 'Transfer completed',
        context = { amount = 50001029912, currency = 'dollars' },
        sensitivityClass = 'internal',
        retentionClass = 'financial'
    }
    for key, value in pairs(overrides or {}) do event[key] = value end
    return event
end

return Fixtures
