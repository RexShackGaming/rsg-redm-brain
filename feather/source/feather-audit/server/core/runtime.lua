FeatherAudit = FeatherAudit or {}

local state = {
    status = FeatherAuditConstants.lifecycle.starting,
    ready = false,
    reason = 'database_starting',
    startedAt = os.time(),
    database = { ready = false, migrations = 0 },
    metrics = {
        requests = 0,
        accepted = 0,
        duplicates = 0,
        retryableRejections = 0,
        quarantined = 0,
        identityConflicts = 0,
        rateLimited = 0
    }
}

function FeatherAudit.SetState(status, ready, reason)
    state.status, state.ready, state.reason = status, ready == true, reason
end

function FeatherAudit.SetDatabaseState(ready, migrations, reason)
    state.database = { ready = ready == true, migrations = migrations or 0, reason = reason }
end

function FeatherAudit.IncrementMetric(name)
    if state.metrics[name] ~= nil then state.metrics[name] = state.metrics[name] + 1 end
end

function FeatherAudit.GetHealth()
    return {
        resource = FeatherAuditConstants.resourceName,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        contractVersion = FeatherAuditConstants.contractVersion,
        status = state.status,
        ready = state.ready,
        reason = state.reason,
        startedAt = state.startedAt,
        database = {
            ready = state.database.ready,
            migrations = state.database.migrations,
            reason = state.database.reason
        },
        metrics = {
            requests = state.metrics.requests,
            accepted = state.metrics.accepted,
            duplicates = state.metrics.duplicates,
            retryableRejections = state.metrics.retryableRejections,
            quarantined = state.metrics.quarantined,
            identityConflicts = state.metrics.identityConflicts,
            rateLimited = state.metrics.rateLimited
        }
    }
end

function FeatherAudit.GetCapabilities()
    return {
        contractVersion = FeatherAuditConstants.contractVersion,
        scaffold = false,
        contractValidation = true,
        canonicalization = true,
        producerKitVersion = 1,
        ingestion = true,
        search = false,
        correlation = false,
        retention = false,
        redaction = false,
        integrityHash = true,
        integrity = false,
        notifications = false,
        exports = false
    }
end
