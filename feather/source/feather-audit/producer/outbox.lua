FeatherAuditProducerOutbox = {}

local function required(adapter, name)
    if type(adapter[name]) ~= 'function' then error(('outbox adapter missing %s'):format(name), 3) end
end

function FeatherAuditProducerOutbox.Create(options)
    local repository = assert(options.repository, 'repository is required')
    local transport = assert(options.transport, 'transport is required')
    for _, name in ipairs({ 'insert', 'lease', 'markDelivered', 'markRetry', 'markQuarantined' }) do
        required(repository, name)
    end
    required(transport, 'ingest')

    local clock = options.clock or os.time
    local random = options.random or math.random
    local initialDelay = options.initialRetrySeconds or 1
    local maximumDelay = options.maximumRetrySeconds or 300
    local batchSize = options.batchSize or 50
    local leaseSeconds = options.leaseSeconds or 30

    local instance = {}

    function instance.Enqueue(transaction, event, validation)
        validation = validation or FeatherAuditValidator.Validate(event, { nowEpoch = clock() })
        if not validation.ok then return nil, validation end
        return repository.insert(transaction, {
            eventId = event.eventId,
            contractVersion = event.contractVersion,
            payload = validation.canonical,
            event = event,
            state = 'pending',
            attemptCount = 0,
            createdAt = clock()
        })
    end

    local function retryDelay(attempt)
        local ceiling = math.min(maximumDelay, initialDelay * (2 ^ math.max(0, attempt - 1)))
        return math.floor(random() * (ceiling + 1))
    end

    function instance.PublishOnce(owner)
        local now = clock()
        local rows = repository.lease(batchSize, owner, now + leaseSeconds, now) or {}
        local summary = { leased = #rows, delivered = 0, retried = 0, quarantined = 0 }
        for _, row in ipairs(rows) do
            local ok, response = pcall(transport.ingest, row.event, row.payload)
            if not ok or type(response) ~= 'table' then
                local attempt = (row.attemptCount or 0) + 1
                repository.markRetry(row, now + retryDelay(attempt), 'transport_failure', attempt)
                summary.retried = summary.retried + 1
            elseif response.result == FeatherAuditConstants.results.accepted
                or response.result == FeatherAuditConstants.results.duplicate then
                repository.markDelivered(row, response.auditEventId, response.result, now)
                summary.delivered = summary.delivered + 1
            elseif response.result == FeatherAuditConstants.results.quarantined then
                repository.markQuarantined(row, response.code or 'quarantined', now)
                summary.quarantined = summary.quarantined + 1
            else
                local attempt = (row.attemptCount or 0) + 1
                repository.markRetry(row, now + retryDelay(attempt), response.code or 'retryable_rejection', attempt)
                summary.retried = summary.retried + 1
            end
        end
        return summary
    end

    return instance
end
