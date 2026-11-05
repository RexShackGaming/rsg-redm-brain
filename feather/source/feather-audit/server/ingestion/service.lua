FeatherAuditIngestion = {}

local function response(result, auditEventId, code, path, warnings)
    return { result = result, auditEventId = auditEventId, code = code, path = path, warnings = warnings or {} }
end

local function prefixAllowed(eventType, prefixes)
    for _, prefix in ipairs(prefixes or {}) do
        if eventType:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function registrationFor(sourceResource)
    if sourceResource == 'feather-audit-smoke' and Config.Development.smokeCommands then
        return {
            enabled = true,
            sourceInstance = Config.SourceInstance,
            eventPrefixes = { 'audit.smoke.' },
            versions = { [1] = true },
            maxPerMinute = 120
        }
    end
    return Config.Producers[sourceResource]
end

local function quarantine(sourceResource, event, rejection, auditEventId)
    local ok = pcall(FeatherAuditQuarantineRepository.Record, sourceResource, event, rejection)
    if not ok then
        FeatherAudit.IncrementMetric('retryableRejections')
        return response(FeatherAuditConstants.results.retryableRejection, nil, 'quarantine_unavailable')
    end
    FeatherAudit.IncrementMetric('quarantined')
    return response(FeatherAuditConstants.results.quarantined, auditEventId, rejection.code, rejection.path)
end

function FeatherAuditIngestion.Ingest(event, verifiedSource)
    FeatherAudit.IncrementMetric('requests')
    if not FeatherAudit.GetHealth().ready then
        FeatherAudit.IncrementMetric('retryableRejections')
        return response(FeatherAuditConstants.results.retryableRejection, nil, 'audit_not_ready')
    end

    local sourceResource = verifiedSource or GetInvokingResource()
    local registration = type(sourceResource) == 'string' and registrationFor(sourceResource) or nil
    if not registration or registration.enabled ~= true then
        FeatherAudit.IncrementMetric('quarantined')
        return response(FeatherAuditConstants.results.quarantined, nil, FeatherAuditResults.producerNotAllowed)
    end

    local maximum = registration.maxPerMinute or Config.Ingestion.defaultMaxPerMinute
    if not FeatherAuditRateLimit.Allow(sourceResource, maximum) then
        FeatherAudit.IncrementMetric('rateLimited')
        FeatherAudit.IncrementMetric('retryableRejections')
        return response(FeatherAuditConstants.results.retryableRejection, nil, 'producer_rate_limited')
    end

    if type(event) ~= 'table' or type(event.eventType) ~= 'string'
        or not prefixAllowed(event.eventType, registration.eventPrefixes) then
        local rejection = { code = FeatherAuditResults.eventSchemaUnknown, path = '$.eventType' }
        return quarantine(sourceResource, event, rejection)
    end
    if not registration.versions[event.eventVersion] then
        local rejection = { code = FeatherAuditResults.eventVersionUnsupported, path = '$.eventVersion' }
        return quarantine(sourceResource, event, rejection)
    end

    local validation = FeatherAuditValidator.Validate(event, {
        sourceResource = sourceResource,
        sourceInstance = registration.sourceInstance or Config.SourceInstance
    })
    if not validation.ok then
        return quarantine(sourceResource, event, validation)
    end

    local contextJson, contextError = FeatherAuditCanonical.Encode(event.context, validation.schema.context)
    if not contextJson then
        local rejection = { code = FeatherAuditResults.fieldInvalid, path = '$.context', detail = contextError }
        return quarantine(sourceResource, event, rejection)
    end

    local executed, outcome, auditEventId, code = pcall(FeatherAuditEventRepository.Accept,
        event, validation.canonical, contextJson)
    if not executed then
        FeatherAudit.IncrementMetric('retryableRejections')
        return response(FeatherAuditConstants.results.retryableRejection, nil, 'database_error')
    end
    if outcome == 'accepted' then
        FeatherAudit.IncrementMetric('accepted')
        return response(FeatherAuditConstants.results.accepted, auditEventId, nil, nil, validation.warnings)
    end
    if outcome == 'duplicate' then
        FeatherAudit.IncrementMetric('duplicates')
        return response(FeatherAuditConstants.results.duplicate, auditEventId, nil, nil, validation.warnings)
    end
    if outcome == 'identity_conflict' then
        local rejection = { code = FeatherAuditResults.eventIdentityConflict, path = '$.eventId' }
        FeatherAudit.IncrementMetric('identityConflicts')
        return quarantine(sourceResource, event, rejection, auditEventId)
    end
    FeatherAudit.IncrementMetric('retryableRejections')
    return response(FeatherAuditConstants.results.retryableRejection, nil, code or 'database_error')
end
