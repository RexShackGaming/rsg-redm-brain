local Assert = _G.TestAssert
local Fixtures = _G.TestFixtures
local now = 1788377071
local rows, nextId = {}, 1

local repository = {}

function repository.insert(_, row)
    row.outboxId = nextId
    nextId = nextId + 1
    rows[#rows + 1] = row
    return row.outboxId
end

function repository.lease(_, owner, expiresAt, currentTime)
    local leased = {}
    for _, row in ipairs(rows) do
        if row.state == 'pending' and (not row.nextAttemptAt or row.nextAttemptAt <= currentTime) then
            row.state, row.leaseOwner, row.leaseExpiresAt = 'leased', owner, expiresAt
            leased[#leased + 1] = row
        elseif row.state == 'leased' and row.leaseExpiresAt <= currentTime then
            row.leaseOwner, row.leaseExpiresAt = owner, expiresAt
            leased[#leased + 1] = row
        end
    end
    return leased
end

function repository.markDelivered(row, auditEventId)
    row.state, row.auditEventId = 'delivered', auditEventId
end

function repository.markRetry(row, nextAttemptAt, code, attempt)
    row.state, row.nextAttemptAt, row.lastResultCode, row.attemptCount = 'pending', nextAttemptAt, code, attempt
end

function repository.markQuarantined(row, code)
    row.state, row.lastResultCode = 'quarantined', code
end

local accepted = {}
local loseFirstAcknowledgement = true
local transport = {}

function transport.ingest(event)
    if not accepted[event.eventId] then accepted[event.eventId] = 'audit-1' end
    if loseFirstAcknowledgement then
        loseFirstAcknowledgement = false
        error('simulated crash after receiver commit and before acknowledgement')
    end
    return { result = FeatherAuditConstants.results.duplicate, auditEventId = accepted[event.eventId] }
end

local outbox = FeatherAuditProducerOutbox.Create({
    repository = repository,
    transport = transport,
    clock = function() return now end,
    random = function() return 0 end
})

local event = Fixtures.validTransfer()
local validation = FeatherAuditValidator.Validate(event, { nowEpoch = now })
Assert.truthy(validation.ok)
Assert.equal(1, outbox.Enqueue({}, event, validation))

local first = outbox.PublishOnce('publisher-a')
Assert.equal(1, first.retried)
Assert.equal('pending', rows[1].state)

now = now + 1
local second = outbox.PublishOnce('publisher-b')
Assert.equal(1, second.delivered)
Assert.equal('delivered', rows[1].state)
Assert.equal('audit-1', rows[1].auditEventId)
Assert.equal(1, (function() local count = 0 for _ in pairs(accepted) do count = count + 1 end return count end)())
