Access.Audit = {}
local A = Access.Audit
local running, paused, busy, engine, enqueueEngine, owner, transport = false, false, false, nil, nil, nil, nil
local lostAckEvent, lastSummary, lastError
local fixtureFilter
local names = { ['access.grant.created.v1'] = 'access.grant.created', ['access.grant.revoked.v1'] = 'access.grant.revoked',
    ['access.grant.preserved.v1']='access.grant.preserved' }

function A.ValidateConfig()
    local cfg = Config.Audit
    if type(cfg) ~= 'table' or type(cfg.Enabled) ~= 'boolean'
        or type(cfg.SourceInstance) ~= 'string' or #cfg.SourceInstance > 128
        or not cfg.SourceInstance:match('^[A-Za-z0-9][A-Za-z0-9%._:%-]*$')
        or not Access.Integer(cfg.PollIntervalMs, 100, 60000) or not Access.Integer(cfg.BatchSize, 1, 100)
        or not Access.Integer(cfg.LeaseSeconds, 30, 600) or not Access.Integer(cfg.InitialRetrySeconds, 1, 60)
        or not Access.Integer(cfg.MaximumRetrySeconds, cfg.InitialRetrySeconds, 3600)
        or not Access.Integer(cfg.TransportTimeoutMs, 100, 10000) then
        return Access.Err('invalid_config', 'Audit source identity and publisher limits are invalid.')
    end
    return Access.Ok(true)
end

function A.Build(fact, occurredEpoch)
    if type(fact) ~= 'table' or not names[fact.eventType] or not Access.Uuid(fact.eventId)
        or type(fact.grant) ~= 'table' or type(fact.actor) ~= 'table' then return nil, 'local_fact_invalid' end
    local grant, actor = fact.grant, fact.actor
    if not Access.Uuid(grant.grantId) or (grant.granteeType ~= 'character' and grant.granteeType ~= 'organization')
        or ((fact.eventType == 'access.grant.created.v1' or fact.eventType=='access.grant.preserved.v1') and grant.status ~= 'active')
        or (fact.eventType == 'access.grant.revoked.v1' and grant.status ~= 'revoked') then return nil, 'local_fact_invalid' end
    local identity = actor.characterId and { type = 'character', id = actor.characterId,
        accountId = actor.accountId, characterId = actor.characterId, resource = 'feather-access' }
        or { type = 'system', id = 'service:' .. tostring(actor.resource), resource = 'feather-access' }
    local event, validation = FeatherAuditProducerEvent.Build({
        eventId = fact.eventId, eventType = names[fact.eventType], eventVersion = 1,
        occurredAt = os.date('!%Y-%m-%dT%H:%M:%SZ', occurredEpoch or os.time()),
        sourceResource = 'feather-access', sourceInstance = Config.Audit.SourceInstance,
        correlationId = grant.grantId, causationId = grant.provenanceId,
        actor = identity,
        targets = {
            { type = 'access_grant', id = grant.grantId, role = 'subject' },
            { type = 'access_target', id = grant.targetId, role = 'object' },
            { type = grant.granteeType, id = grant.granteeId, role = 'grantee' },
        },
        references = { { resource = 'feather-access', type = 'grant_provenance', id = grant.provenanceId } },
        result = 'success', reasonCode = fact.eventType=='access.grant.preserved.v1' and 'grant_preserved' or grant.status == 'active' and 'grant_created' or 'grant_revoked',
        summary = fact.eventType=='access.grant.preserved.v1' and 'Delegated capability adopted by new owner' or grant.status == 'active' and 'Delegated capability granted' or 'Delegated capability revoked',
        context = { target_type = grant.targetType, capability = grant.capability, status = grant.status,
            revision = grant.revision, target_epoch = grant.epoch, grantee_type = grant.granteeType,
            valid_from = grant.validFrom, valid_until = grant.validUntil, role_ids = grant.roleIds,
            requestor_resource = actor.resource, reason_code = fact.reasonCode, provenance_type = grant.provenanceType,
            manifest_id=fact.preservation and fact.preservation.manifestId,
            source_epoch=fact.preservation and fact.preservation.sourceEpoch,
            transfer_resource=fact.preservation and fact.preservation.transferResource,
            transfer_request_id=fact.preservation and fact.preservation.transferRequestId },
        sensitivityClass = 'restricted', retentionClass = 'security',
    })
    if not event then return nil, type(validation) == 'table' and validation.code or 'envelope_invalid' end
    return event, validation
end

local function SafeCode(code)
    return type(code) == 'string' and #code <= 64 and code:match('^[a-z0-9_]+$') and code or 'delivery_error'
end

local function Ingest(event)
    if GetResourceState('feather-audit') ~= 'started' then return { result = 'retryable_rejection', code = 'audit_unavailable' } end
    if transport then return { result = 'retryable_rejection', code = 'transport_busy' } end
    local job, pending = {}, promise.new()
    transport = job
    local function Finish(result)
        if not job.settled then job.settled = true; pending:resolve(result) end
    end
    job.cancel = function() Finish({ result = 'retryable_rejection', code = 'audit_unavailable' }) end
    SetTimeout(Config.Audit.TransportTimeoutMs, function()
        Finish({ result = 'retryable_rejection', code = 'transport_timeout' })
    end)
    local started = GetGameTimer()
    CreateThread(function()
        local called, result = pcall(function() return exports['feather-audit']:Ingest(event) end)
        if transport == job then transport = nil end
        if not called or type(result) ~= 'table' then
            Finish({ result = 'retryable_rejection', code = 'transport_failure' })
        elseif GetGameTimer() - started >= Config.Audit.TransportTimeoutMs then
            Finish({ result = 'retryable_rejection', code = 'transport_timeout' })
        elseif result.result == 'accepted' or result.result == 'duplicate' then
            if not Access.Uuid(result.auditEventId) then
                Finish({ result = 'retryable_rejection', code = 'invalid_acknowledgement' })
            elseif lostAckEvent == event.eventId then
                lostAckEvent = nil
                Finish({ result = 'retryable_rejection', code = 'fixture_lost_ack' })
            else Finish(result) end
        elseif result.result == 'quarantined' then
            Finish({ result = 'quarantined', code = SafeCode(result.code) })
        else Finish({ result = 'retryable_rejection', code = SafeCode(result.code) }) end
    end)
    return Citizen.Await(pending)
end

local repository = {}
function repository.insert(tx, row)
    local changed = tx.exec([[UPDATE `feather_access_outbox` SET `audit_payload`=?,`audit_canonical`=?
        WHERE `event_id`=? AND `audit_payload` IS NULL]], json.encode(row.event), row.payload, row.eventId)
    if tonumber(changed) ~= 1 then error('Access Audit envelope was not reserved exactly once') end
    return row.eventId
end

local function Persist(tx, row, leaseOwner, expiresAt)
    tx.exec([[UPDATE `feather_access_outbox` SET `status`='leased',`lease_owner`=?,`lease_until`=? WHERE `event_id`=?]],
        leaseOwner, expiresAt, row.event_id)
    local decoded, event
    if row.audit_payload == nil then
        local parsed, fact = pcall(json.decode, row.payload_json)
        local built, validation
        if parsed and type(fact) == 'table' and fact.eventId == row.event_id and fact.eventType == row.event_type then
            built, validation = A.Build(fact, tonumber(row.occurred_epoch))
        end
        if built then
            repository.insert(tx, { event = built, payload = validation.canonical, eventId = row.event_id })
            event, row.audit_canonical, decoded = built, validation.canonical, true
        end
    else decoded, event = pcall(json.decode, row.audit_payload) end
    local validation = decoded and type(event) == 'table' and FeatherAuditValidator.Validate(event, { sourceResource = 'feather-access' })
    if not validation or not validation.ok or validation.canonical ~= row.audit_canonical
        or event.eventId ~= row.event_id or event.eventType ~= names[row.event_type] then
        tx.exec([[UPDATE `feather_access_outbox` SET `status`='quarantined',`last_result`='envelope_invalid',
            `lease_owner`=NULL,`lease_until`=0 WHERE `event_id`=?]], row.event_id)
        return nil
    end
    return { eventId = row.event_id, event = event, payload = row.audit_canonical,
        attemptCount = tonumber(row.attempt_count) or 0, leaseOwner = leaseOwner }
end

function repository.lease(batchSize, leaseOwner, expiresAt, now)
    local leased, quarantined = {}, {}
    local committed = DB.transaction(function(tx)
        leased, quarantined = {}, {}
        local sql = [[SELECT *,UNIX_TIMESTAMP(`created_at`) AS occurred_epoch FROM `feather_access_outbox`
            WHERE ((`status`='pending' AND `available_at`<=?) OR (`status`='leased' AND `lease_until`<=?))]]
        local parameters = { now, now }
        if fixtureFilter then sql = sql .. ' AND `event_id`=?'; parameters[#parameters + 1] = fixtureFilter end
        sql = sql .. ' ORDER BY `created_at`,`event_id` LIMIT ? FOR UPDATE'
        parameters[#parameters + 1] = batchSize
        local rows = tx.query(sql, table.unpack(parameters))
        for _, row in ipairs(rows) do
            local entry = Persist(tx, row, leaseOwner, expiresAt)
            if entry then leased[#leased + 1] = entry else quarantined[#quarantined + 1] = row.event_id end
        end
        return true
    end)
    if committed ~= true then error('Access outbox lease commit not confirmed') end
    for _, id in ipairs(quarantined) do print('[feather-access] event=audit.quarantined eventId=' .. id .. ' code=envelope_invalid') end
    return leased
end

local function Changed(sql, ...)
    if tonumber(DB.exec(sql, ...)) ~= 1 then error('Access outbox lease changed before acknowledgement') end
end
function repository.markDelivered(row, auditEventId, result)
    Changed([[UPDATE `feather_access_outbox` SET `status`='delivered',`audit_event_id`=?,`last_result`=?,
        `attempt_count`=`attempt_count`+1,`delivered_at`=CURRENT_TIMESTAMP,`lease_owner`=NULL,`lease_until`=0
        WHERE `event_id`=? AND `status`='leased' AND `lease_owner`=?]], auditEventId, result, row.eventId, row.leaseOwner)
end
function repository.markRetry(row, nextAttemptAt, resultCode, attemptCount)
    Changed([[UPDATE `feather_access_outbox` SET `status`='pending',`available_at`=?,`last_result`=?,`attempt_count`=?,
        `lease_owner`=NULL,`lease_until`=0 WHERE `event_id`=? AND `status`='leased' AND `lease_owner`=?]],
        nextAttemptAt, SafeCode(resultCode), attemptCount, row.eventId, row.leaseOwner)
end
function repository.markQuarantined(row, resultCode)
    Changed([[UPDATE `feather_access_outbox` SET `status`='quarantined',`last_result`=?,
        `attempt_count`=`attempt_count`+1,`lease_owner`=NULL,`lease_until`=0
        WHERE `event_id`=? AND `status`='leased' AND `lease_owner`=?]], SafeCode(resultCode), row.eventId, row.leaseOwner)
    print('[feather-access] event=audit.quarantined eventId=' .. row.eventId .. ' code=' .. SafeCode(resultCode))
end

local function Engine(enqueue)
    local instance
    if enqueue then instance = enqueueEngine else instance = engine end
    if not instance then
        instance = FeatherAuditProducerOutbox.Create({ repository = repository, transport = { ingest = Ingest },
            -- Enqueue runs in a domain transaction: its metadata clock is pure Lua.
            -- Publisher leasing uses DB time outside that transaction.
            clock = enqueue and os.time or function() return tonumber(DB.value('SELECT UNIX_TIMESTAMP()')) end,
            batchSize = Config.Audit.BatchSize, leaseSeconds = Config.Audit.LeaseSeconds,
            initialRetrySeconds = Config.Audit.InitialRetrySeconds, maximumRetrySeconds = Config.Audit.MaximumRetrySeconds })
        if enqueue then enqueueEngine = instance else engine = instance end
    end
    return instance
end

function A.Enqueue(tx, fact)
    local event, validation = A.Build(fact)
    if not event then error('Access Audit envelope invalid: ' .. tostring(validation)) end
    return Engine(true).Enqueue(tx, event, validation)
end

function A.Step(force, eventId)
    if not running or not Access.LocalReady() or busy or (paused and not force) then
        return Access.Err('publisher_unavailable', 'Publisher is stopped, busy or paused.')
    end
    busy = true
    fixtureFilter = eventId
    local called, result = pcall(function() return Engine().PublishOnce(owner) end)
    fixtureFilter = nil
    busy = false
    if not called then
        lastError = 'publisher_error'
        print('[feather-access] event=audit.publisher_error (rows remain recoverable by lease)')
        return Access.Err('publisher_error', 'Audit delivery attempt failed; inspect outbox state.')
    end
    lastSummary, lastError = result, nil
    return Access.Ok(Access.Copy(result))
end

function A.Start()
    if not Config.Audit.Enabled then return Access.Ok(false) end
    owner = DB.value('SELECT UUID()')
    if not Access.Uuid(owner) then return Access.Err('publisher_error', 'Could not generate publisher owner identity.') end
    running = true
    CreateThread(function()
        while running do
            Wait(Config.Audit.PollIntervalMs)
            if running and not paused then A.Step() end
        end
    end)
    return Access.Ok(true)
end

function A.Stop()
    running = false
    if transport then transport.cancel(); transport = nil end
end
function A.AuditStopped()
    if transport then transport.cancel(); transport = nil end
end
function A.FixtureStopped()
    paused, lostAckEvent = false, nil
end
function A.State()
    return { enabled = Config.Audit.Enabled, running = running, paused = paused, busy = busy,
        transportActive = transport ~= nil, auditAvailable = GetResourceState('feather-audit') == 'started',
        lastSummary = Access.Copy(lastSummary), lastError = lastError }
end
function A.Counts()
    local counts = { pending = 0, leased = 0, delivered = 0, quarantined = 0 }
    for _, row in ipairs(DB.query('SELECT `status`,COUNT(*) AS total FROM `feather_access_outbox` GROUP BY `status`')) do
        counts[row.status] = tonumber(row.total)
    end
    return counts
end

function A.RetryQuarantine(eventId)
    if not Access.Uuid(eventId) then return Access.Err('invalid_input', 'Event UUID required.') end
    eventId = eventId:lower()
    local row = DB.one('SELECT * FROM `feather_access_outbox` WHERE `event_id`=?', eventId)
    if not row or row.status ~= 'quarantined' then return Access.Err('no_change', 'Only quarantined events can be retried.') end
    local decoded, event = pcall(json.decode, row.audit_payload)
    local validation = decoded and type(event) == 'table' and FeatherAuditValidator.Validate(event, { sourceResource = 'feather-access' })
    if not validation or not validation.ok or validation.canonical ~= row.audit_canonical or event.eventId ~= eventId then
        return Access.Err('invalid_envelope', 'Restore a valid committed envelope; retry cannot rewrite it.')
    end
    local changed = DB.exec([[UPDATE `feather_access_outbox` SET `status`='pending',`available_at`=0,
        `last_result`='operator_retry',`lease_owner`=NULL,`lease_until`=0 WHERE `event_id`=? AND `status`='quarantined']], eventId)
    if tonumber(changed) ~= 1 then return Access.Err('no_change', 'Event state changed before retry.') end
    print('[feather-access] event=audit.operator_retry eventId=' .. eventId)
    return Access.Ok(true)
end

function A.Fixture(request, caller)
    if not Config.DevMode or caller ~= 'feather-access-tests' then return Access.Err('authorization_denied', 'Audit fixture is not authorized.') end
    if not Access.OnlyFields(request, { operation = true, eventId = true }) then return Access.Err('invalid_input', 'Invalid fixture control.') end
    if request.eventId ~= nil then
        if not Access.Uuid(request.eventId) then return Access.Err('invalid_input', 'Invalid fixture event UUID.') end
        request = Access.Copy(request); request.eventId = request.eventId:lower()
        local row = DB.one('SELECT `payload_json` FROM `feather_access_events` WHERE `event_id`=?', request.eventId)
        local decoded, payload = false, nil
        if row then decoded, payload = pcall(json.decode, row.payload_json) end
        if not decoded or type(payload) ~= 'table' or type(payload.actor) ~= 'table'
            or payload.actor.resource ~= caller then return Access.Err('authorization_denied', 'Fixture must own its event.') end
    end
    if request.operation == 'pause' then
        paused = true
        local started = GetGameTimer()
        while busy and GetGameTimer() - started < 30000 do Wait(25) end
        if busy then return Access.Err('publisher_busy', 'Publisher has not finished its current batch.') end
    elseif request.operation == 'resume' then paused = false
    elseif request.operation == 'lose_ack' and Access.Uuid(request.eventId) then lostAckEvent = request.eventId:lower()
    elseif request.operation == 'step' then return A.Step(true, request.eventId)
    else return Access.Err('invalid_input', 'Unknown fixture control.') end
    return Access.Ok(A.State())
end
