local function printChecks(command, checks)
    local passed = 0
    for _, check in ipairs(checks) do
        if check[2] then passed = passed + 1 end
        print(('[%s] %s %s'):format(command, check[2] and 'PASS' or 'FAIL', check[1]))
    end
    print(('[%s] done %d/%d passed'):format(command, passed, #checks))
end

local function enabled(source, command)
    if source ~= 0 then return false end
    if Config.Development.smokeCommands then return true end
    print(('[%s] disabled; set Config.Development.smokeCommands = true on a test server'):format(command))
    return false
end

local function smokeEvent(eventId, sequence, summary)
    return {
        contractVersion = 1,
        eventId = eventId,
        eventType = 'audit.smoke.ingested',
        eventVersion = 1,
        occurredAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance,
        actor = { type = 'system', id = 'console-smoke' },
        targets = {
            { type = 'resource', id = 'feather-audit', role = 'subject' }
        },
        references = {},
        result = 'success',
        reasonCode = 'smoke_test',
        summary = summary or 'Audit ingestion smoke event',
        context = { sequence = sequence, message = 'Safe test fixture' },
        sensitivityClass = 'internal',
        retentionClass = 'operational'
    }
end

RegisterCommand('AuditFailureBoundarySmokeTest', function(source)
    local command = 'AuditFailureBoundarySmokeTest'
    if not enabled(source, command) then return end
    -- No yielding calls while the invalid configuration is installed.
    local originalInstance = Config.SourceInstance
    Config.SourceInstance = ''
    local executed, valid, problem = pcall(FeatherAuditConfig.Validate)
    Config.SourceInstance = originalInstance
    local restored, restoredProblem = FeatherAuditConfig.Validate()
    local bucket = 'failure-smoke:' .. tostring(GetGameTimer())
    local first = FeatherAuditRateLimit.Allow(bucket, 1, 120)
    local limited = FeatherAuditRateLimit.Allow(bucket, 1, 120)
    local nextMinute = FeatherAuditRateLimit.Allow(bucket, 1, 180)
    printChecks(command, {
        { 'empty source instance rejected by configuration validator', executed and valid == false and problem == 'invalid_source_instance' },
        { 'original configuration restored and valid', restored == true and restoredProblem == nil },
        { 'first request allowed', first == true },
        { 'excess request denied', limited == false },
        { 'next minute restores capacity', nextMinute == true }
    })
end, true)
RegisterCommand('AuditProjectionSmokeTest', function(source)
    local command = 'AuditProjectionSmokeTest'
    if not enabled(source, command) then return end
    if not FeatherAudit.GetHealth().ready then return print('[' .. command .. '] FAIL Audit not ready') end
    local workflow = 'projection:' .. tostring(DB.value('SELECT UUID()'))
    local event = smokeEvent(workflow, 7)
    event.context.padding_a = 'unapproved projection field'
    local stored = FeatherAuditIngestion.Ingest(event, 'feather-audit-smoke')
    if stored.result ~= 'accepted' then return print('[' .. command .. '] FAIL fixture: ' .. tostring(stored.code)) end
    local now = os.time()
    local ordinary = { allowed = true, type = 'system', id = workflow, sensitive = false }
    local elevated = { allowed = true, type = 'system', id = workflow, sensitive = true }
    local query = { fromEpoch = now - 60, toEpoch = now + 60, eventId = stored.auditEventId }
    local standard = FeatherAuditSearch.Read(query, ordinary, 'audit.event.get.v1')
    local sensitive = FeatherAuditSearch.Read(query, elevated, 'audit.event.get.v1')
    local listing = FeatherAuditSearch.Read(query, elevated)
    local regular = standard.ok and standard.value.event and standard.value.event.content
    local protected = sensitive.ok and sensitive.value.event and sensitive.value.event.content
    local row = listing.ok and listing.value.events[1]
    local accesses = tonumber(DB.value([[SELECT COUNT(*) FROM feather_audit_access_events
        WHERE requester_type = 'system' AND requester_id = ?]], workflow))
    printChecks(command, {
        { 'standard detail includes approved sequence only', regular and regular.context.sequence == 7 and regular.context.message == nil },
        { 'sensitive detail includes approved message', protected and protected.context.message == event.context.message },
        { 'unapproved context and raw payload omitted', protected and protected.context.padding_a == nil
            and sensitive.value.event.projectedContext == nil and sensitive.value.event.canonicalPayload == nil },
        { 'listing remains metadata only', row and row.content == nil and row.projectedContext == nil },
        { 'one access record per read', accesses == 3 }
    })
end, true)

RegisterCommand('AuditContractSmokeTest', function(source)
    local command = 'AuditContractSmokeTest'
    if not enabled(source, command) then return end

    local schema = FeatherAuditSchemaRegistry.Get('audit.smoke.ingested', 1)
    local canonicalA = FeatherAuditCanonical.Encode({ zebra = 2, alpha = 1 }, { type = 'object' })
    local canonicalB = FeatherAuditCanonical.Encode({ alpha = 1, zebra = 2 }, { type = 'object' })
    local valid = FeatherAuditValidator.Validate(smokeEvent('smoke:contract-valid', 1), {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })
    local mismatch = FeatherAuditValidator.Validate(smokeEvent('smoke:contract-source', 2), {
        nowEpoch = os.time(),
        sourceResource = 'different-resource',
        sourceInstance = Config.SourceInstance
    })
    local prohibitedEvent = smokeEvent('smoke:contract-secret', 3)
    prohibitedEvent.summary = 'https://discord.com/api/webhooks/123/not-a-real-secret'
    local prohibited = FeatherAuditValidator.Validate(prohibitedEvent, {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })
    local sparseEvent = smokeEvent('smoke:contract-sparse', 4)
    sparseEvent.targets[3] = { type = 'resource', id = 'gap', role = 'subject' }
    local sparse = FeatherAuditValidator.Validate(sparseEvent, {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })
    local futureEvent = smokeEvent('smoke:contract-future', 5)
    futureEvent.occurredAt = '2099-01-01T00:00:00Z'
    local future = FeatherAuditValidator.Validate(futureEvent, {
        nowEpoch = os.time(),
        sourceResource = 'feather-audit-smoke',
        sourceInstance = Config.SourceInstance
    })

    printChecks(command, {
        { 'smoke event schema registered', schema ~= nil },
        { 'canonical object ordering is deterministic', canonicalA ~= nil and canonicalA == canonicalB },
        { 'valid registered event accepted by contract', valid.ok == true },
        { 'source mismatch rejected', mismatch.ok == false and mismatch.code == FeatherAuditResults.sourceMismatch },
        { 'prohibited webhook content rejected', prohibited.ok == false and prohibited.code == FeatherAuditResults.prohibitedContent },
        { 'sparse target array rejected', sparse.ok == false and sparse.code == FeatherAuditResults.fieldInvalid },
        { 'event beyond clock-skew limit rejected', future.ok == false and future.code == FeatherAuditResults.occurredAtFuture }
    })
end, true)

RegisterCommand('AuditDependencySmokeTest', function(source)
    local command = 'AuditDependencySmokeTest'
    if not enabled(source, command) then return end

    local databaseCallOk, databaseValue = pcall(function()
        return DB.value('SELECT 1')
    end)
    local currentResource = GetCurrentResourceName()
    printChecks(command, {
        { 'feather-mysql resource started', GetResourceState('feather-mysql') == 'started' },
        { 'feather-core resource started', GetResourceState('feather-core') == 'started' },
        { 'feather-audit resource started', GetResourceState(currentResource) == 'started' },
        { 'database responds to SELECT 1', databaseCallOk and tonumber(databaseValue) == 1 }
    })
end, true)

RegisterCommand('AuditMigrationSmokeTest', function(source)
    local command = 'AuditMigrationSmokeTest'
    if not enabled(source, command) then return end
    local requiredTables = {
        'feather_audit_schema_migrations', 'feather_audit_events',
        'feather_audit_targets', 'feather_audit_references',
        'feather_audit_quarantine', 'feather_audit_access_events'
    }
    local checks = {}
    for _, tableName in ipairs(requiredTables) do
        local count = tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?]], tableName)) or 0
        checks[#checks + 1] = { tableName .. ' exists', count == 1 }
    end
    local ledger = tonumber(DB.value(
        'SELECT COUNT(*) FROM feather_audit_schema_migrations')) or 0
    checks[#checks + 1] = { 'migration ledger has one row', ledger == 1 }
    printChecks(command, checks)
end, true)

RegisterCommand('AuditIngestionSmokeTest', function(source)
    local command = 'AuditIngestionSmokeTest'
    if not enabled(source, command) then return end
    if not FeatherAudit.GetHealth().ready then
        return print(('[%s] FAIL Audit is not ready'):format(command))
    end

    local uuid = tostring(DB.value('SELECT UUID()'))
    local eventId = 'smoke:' .. uuid
    local original = smokeEvent(eventId, 1)
    local accepted = FeatherAuditIngestion.Ingest(original, 'feather-audit-smoke')
    local duplicate = FeatherAuditIngestion.Ingest(original, 'feather-audit-smoke')
    local conflictEvent = smokeEvent(eventId, 1, 'Changed content under reused identity')
    local conflict = FeatherAuditIngestion.Ingest(conflictEvent, 'feather-audit-smoke')
    local invalidEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 2)
    invalidEvent.context.unknown_field = true
    local invalid = FeatherAuditIngestion.Ingest(invalidEvent, 'feather-audit-smoke')
    local unknownVersionEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 3)
    unknownVersionEvent.eventVersion = 2
    local unknownVersion = FeatherAuditIngestion.Ingest(unknownVersionEvent, 'feather-audit-smoke')
    local prohibitedEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 4)
    prohibitedEvent.summary = 'https://discord.com/api/webhooks/123/not-a-real-secret'
    local prohibited = FeatherAuditIngestion.Ingest(prohibitedEvent, 'feather-audit-smoke')
    local oversizedEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 5)
    oversizedEvent.context.padding_a = string.rep('a', 9000)
    oversizedEvent.context.padding_b = string.rep('b', 9000)
    local oversized = FeatherAuditIngestion.Ingest(oversizedEvent, 'feather-audit-smoke')
    local oldEvent = smokeEvent('smoke:' .. tostring(DB.value('SELECT UUID()')), 6)
    oldEvent.occurredAt = '2020-01-01T00:00:00Z'
    local oldAccepted = FeatherAuditIngestion.Ingest(oldEvent, 'feather-audit-smoke')

    local row = accepted.auditEventId and DB.one([[SELECT canonical_payload AS canonicalPayload,
        integrity_hash AS integrityHash FROM feather_audit_events
        WHERE audit_event_id = ? LIMIT 1]], accepted.auditEventId) or nil
    local matchingHash = row and DB.value('SELECT SHA2(?, 256)', row.canonicalPayload)
    local eventCount = tonumber(DB.value([[SELECT COUNT(*) FROM feather_audit_events
        WHERE source_resource = ? AND source_instance = ? AND producer_event_id = ?]],
        'feather-audit-smoke', Config.SourceInstance, eventId)) or 0

    printChecks(command, {
        { 'new event accepted', accepted.result == 'accepted' and type(accepted.auditEventId) == 'string' },
        { 'identical retry is duplicate', duplicate.result == 'duplicate'
            and duplicate.auditEventId == accepted.auditEventId },
        { 'same identity with changed content quarantined', conflict.result == 'quarantined'
            and conflict.code == FeatherAuditResults.eventIdentityConflict },
        { 'unknown context field quarantined', invalid.result == 'quarantined'
            and invalid.code == FeatherAuditResults.contextUnknownField },
        { 'unsupported event version quarantined', unknownVersion.result == 'quarantined'
            and unknownVersion.code == FeatherAuditResults.eventVersionUnsupported },
        { 'prohibited content quarantined', prohibited.result == 'quarantined'
            and prohibited.code == FeatherAuditResults.prohibitedContent },
        { 'oversized context quarantined', oversized.result == 'quarantined'
            and oversized.code == FeatherAuditResults.payloadTooLarge },
        { 'old out-of-order event accepted', oldAccepted.result == 'accepted' },
        { 'one durable event for producer identity', eventCount == 1 },
        { 'stored SHA-256 matches canonical payload', row and row.integrityHash == matchingHash },
        { 'quarantine contains open records', FeatherAuditQuarantineRepository.CountOpen() >= 5 }
    })
end, true)

RegisterCommand('AuditHealthSmokeTest', function(source)
    local command = 'AuditHealthSmokeTest'
    if not enabled(source, command) then return end
    local health, capabilities = FeatherAudit.GetHealth(), FeatherAudit.GetCapabilities()
    printChecks(command, {
        { 'resource ready', health.ready == true and health.status == 'ready' },
        { 'database ready', health.database and health.database.ready == true },
        { 'ingestion advertised', capabilities.ingestion == true },
        { 'search not advertised before A3', capabilities.search == false }
    })
end, true)

RegisterCommand('AuditSearchFoundationSmokeTest', function(source)
    local command = 'AuditSearchFoundationSmokeTest'
    if not enabled(source, command) then return end
    if not FeatherAudit.GetHealth().ready then
        return print(('[%s] FAIL Audit not ready'):format(command))
    end
    local fixtureId = tostring(DB.value('SELECT UUID()'))
    local event = smokeEvent('search-smoke:' .. fixtureId, 1)
    local stored = FeatherAuditIngestion.Ingest(event, 'feather-audit-smoke')
    if stored.result ~= 'accepted' then
        return print(('[%s] FAIL fixture ingestion: %s'):format(command, tostring(stored.code)))
    end
    local now = os.time()
    local request = { fromEpoch = now - 60, toEpoch = now + 60,
        eventId = stored.auditEventId, limit = 5 }
    local denied = FeatherAuditSearch.Read(request, { allowed = false })
    local malformed = FeatherAuditSearch.Read({ fromEpoch = 0, toEpoch = 8 * 86400 },
        { allowed = true, type = 'system', id = fixtureId })
    -- Console-only test identity exercises repository behavior, not Authority grants.
    local read = FeatherAuditSearch.Read(request,
        { allowed = true, type = 'system', id = fixtureId, sensitive = false })
    local rows = read.ok and read.value.events or {}
    local row = rows[1]
    local accesses = tonumber(DB.value([[SELECT COUNT(*) FROM feather_audit_access_events
        WHERE requester_type = 'system' AND requester_id = ? AND operation = 'audit.search.v1']], fixtureId))
    printChecks(command, {
        { 'denied identity rejected before query', not denied.ok and denied.code == 'forbidden' },
        { 'overwide time range rejected', not malformed.ok and malformed.code == 'invalid_request' },
        { 'stored fixture found through bounded query', read.ok and #rows == 1 and row.eventId == stored.auditEventId },
        { 'payload and identifying content omitted', row and row.context == nil and row.canonicalPayload == nil
            and row.summary == nil and row.actorId == nil and row.displayName == nil },
        { 'exactly one attributable access record', accesses == 1 }
    })
end, true)
RegisterCommand('AuditPaginationSmokeTest', function(source)
    local command = 'AuditPaginationSmokeTest'
    if not enabled(source, command) then return end
    if not FeatherAudit.GetHealth().ready then return print(('[%s] FAIL Audit not ready'):format(command)) end
    local workflow = 'pagination:' .. tostring(DB.value('SELECT UUID()'))
    for sequence = 1, 3 do
        local event = smokeEvent(workflow .. ':' .. sequence, sequence)
        event.correlationId = workflow
        local result = FeatherAuditIngestion.Ingest(event, 'feather-audit-smoke')
        if result.result ~= 'accepted' then return print(('[%s] FAIL fixture: %s'):format(command, tostring(result.code))) end
    end
    local now = os.time()
    local request = { fromEpoch = now - 60, toEpoch = now + 60, limit = 1, correlationId = workflow }
    local identity = { allowed = true, type = 'system', id = workflow, sensitive = false }
    local ids, pages, cursor, successful = {}, 0, nil, true
    repeat
        request.cursor = cursor
        local result = FeatherAuditSearch.Read(request, identity)
        if not result.ok then successful = false; break end
        pages = pages + 1
        for _, row in ipairs(result.value.events) do
            if ids[row.eventId] then successful = false end
            ids[row.eventId] = true
        end
        cursor = result.value.nextCursor
    until not cursor or pages >= 4
    local total = 0
    for _ in pairs(ids) do total = total + 1 end
    local oneId = next(ids)
    local detail = FeatherAuditSearch.Read({ fromEpoch = now - 60, toEpoch = now + 60,
        eventId = oneId }, identity, 'audit.event.get.v1')
    local correlation = FeatherAuditSearch.Read({ fromEpoch = now - 60, toEpoch = now + 60,
        correlationId = workflow, limit = 5 }, identity, 'audit.correlation.get.v1')
    local accesses = tonumber(DB.value([[SELECT COUNT(*) FROM feather_audit_access_events
        WHERE requester_type = 'system' AND requester_id = ?]], workflow))
    printChecks(command, {
        { 'three pages without duplicates', successful and pages == 3 and total == 3 and cursor == nil },
        { 'exact event metadata returned', detail.ok and detail.value.event and detail.value.event.eventId == oneId },
        { 'correlation returns the three related events', correlation.ok and #correlation.value.events == 3 },
        { 'one access record per page/detail/correlation read', accesses == 5 }
    })
end, true)
RegisterCommand('AuditVisibilitySmokeTest', function(source)
    local command = 'AuditVisibilitySmokeTest'
    if not enabled(source, command) then return end
    if not FeatherAudit.GetHealth().ready then return print(('[%s] FAIL Audit not ready'):format(command)) end
    local workflow = 'visibility:' .. tostring(DB.value('SELECT UUID()'))
    local ids = {}
    for sequence, class in ipairs({ 'internal', 'restricted', 'sealed' }) do
        local event = smokeEvent(workflow .. ':' .. class, sequence)
        event.correlationId, event.sensitivityClass = workflow, class
        local result = FeatherAuditIngestion.Ingest(event, 'feather-audit-smoke')
        if result.result ~= 'accepted' then return print(('[%s] FAIL fixture: %s'):format(command, tostring(result.code))) end
        ids[class] = result.auditEventId
    end
    local now = os.time()
    FeatherAuditVisibilityFixture = { correlationId = workflow, fromEpoch = now - 60, toEpoch = now + 60,
        internalId = ids.internal, restrictedId = ids.restricted, sealedId = ids.sealed }
    local standard = { allowed = true, type = 'system', id = workflow, sensitive = false }
    local sensitive = { allowed = true, type = 'system', id = workflow, sensitive = true }
    local request = { fromEpoch = now - 60, toEpoch = now + 60, correlationId = workflow, limit = 5 }
    local ordinary = FeatherAuditSearch.Read(request, standard)
    local elevated = FeatherAuditSearch.Read(request, sensitive)
    local function detail(id, identity)
        return FeatherAuditSearch.Read({ fromEpoch = now - 60, toEpoch = now + 60, eventId = id }, identity, 'audit.event.get.v1')
    end
    local hiddenRestricted = detail(ids.restricted, standard)
    local hiddenSealed = detail(ids.sealed, sensitive)
    local missing = detail(tostring(DB.value('SELECT UUID()')), sensitive)
    local ordinaryCorrelation = FeatherAuditSearch.Read(request, standard, 'audit.correlation.get.v1')
    local elevatedCorrelation = FeatherAuditSearch.Read(request, sensitive, 'audit.correlation.get.v1')
    local allowedRows = elevated.ok and elevated.value.events or {}
    local noSealed, noContent = true, true
    for _, row in ipairs(allowedRows) do
        if row.sensitivityClass == 'sealed' then noSealed = false end
        if row.summary or row.context or row.actorId or row.canonicalPayload then noContent = false end
    end
    local accesses = tonumber(DB.value([[SELECT COUNT(*) FROM feather_audit_access_events
        WHERE requester_type = 'system' AND requester_id = ?]], workflow))
    printChecks(command, {
        { 'standard search sees only internal event', ordinary.ok and #ordinary.value.events == 1 and ordinary.value.events[1].eventId == ids.internal },
        { 'sensitive search includes restricted but excludes sealed', elevated.ok and #allowedRows == 2 and noSealed },
        { 'restricted detail hidden from standard reader', hiddenRestricted.ok and hiddenRestricted.value.event == nil },
        { 'sealed and absent detail indistinguishable', hiddenSealed.ok and missing.ok and next(hiddenSealed.value) == nil and next(missing.value) == nil },
        { 'correlation applies the same visibility rules', ordinaryCorrelation.ok and #ordinaryCorrelation.value.events == 1
            and elevatedCorrelation.ok and #elevatedCorrelation.value.events == 2 },
        { 'protected content omitted', noContent },
        { 'one access record per permitted operation', accesses == 7 }
    })
end, true)
