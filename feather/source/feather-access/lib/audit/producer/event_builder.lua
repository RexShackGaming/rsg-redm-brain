FeatherAuditProducerEvent = {}

local function utcTimestamp(epoch)
    return os.date('!%Y-%m-%dT%H:%M:%SZ', epoch)
end

function FeatherAuditProducerEvent.Build(values, options)
    options = options or {}
    local event = {
        contractVersion = FeatherAuditConstants.contractVersion,
        eventId = values.eventId or (options.generateEventId or FeatherAuditProducerId.Generate)(),
        eventType = values.eventType,
        eventVersion = values.eventVersion or 1,
        occurredAt = values.occurredAt or utcTimestamp((options.nowEpoch or os.time)()),
        sourceResource = values.sourceResource,
        sourceInstance = values.sourceInstance,
        invokingResource = values.invokingResource,
        correlationId = values.correlationId,
        causationId = values.causationId,
        actor = values.actor,
        targets = values.targets or {},
        references = values.references or {},
        result = values.result,
        reasonCode = values.reasonCode,
        summary = values.summary or '',
        context = values.context or {},
        sensitivityClass = values.sensitivityClass,
        retentionClass = values.retentionClass
    }
    local validation = FeatherAuditValidator.Validate(event, {
        nowEpoch = (options.validationNowEpoch or os.time)(),
        sourceResource = values.sourceResource,
        sourceInstance = values.sourceInstance
    })
    if not validation.ok then return nil, validation end
    return event, validation
end
