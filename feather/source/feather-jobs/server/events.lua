JobEvents = {}
local Ok, Err = Jobs.Ok, Jobs.Err
local running = false

-- Committed facts. definition.updated and grade.defined extend the plan's list so
-- definition and grade changes carry the same audit trail as assignments.
local names = {
    ['definition.registered'] = 'jobs.definition.registered.v1',
    ['definition.updated'] = 'jobs.definition.updated.v1',
    ['grade.defined'] = 'jobs.grade.defined.v1',
    ['assignment.created'] = 'jobs.assignment.created.v1',
    ['assignment.grade_changed'] = 'jobs.assignment.grade_changed.v1',
    ['assignment.duty_changed'] = 'jobs.assignment.duty_changed.v1',
    ['assignment.activated'] = 'jobs.assignment.activated.v1',
    ['assignment.ended'] = 'jobs.assignment.ended.v1'
}
JobEvents.Names = names

local detailFields = { 'jobKey', 'label', 'status', 'previousStatus', 'gradeId', 'gradeKey', 'ordinal',
    'previousGradeId', 'previousGradeKey', 'dutyState', 'previousDutyState', 'employerType', 'employerId',
    'provenanceType', 'provenanceId', 'ownerResource', 'activeAssignmentId', 'previousActiveAssignmentId',
    'activeCleared', 'metadataVersion' }

-- Writes audit facts and their outbox rows inside the caller's transaction.
-- (perf) Any number of events costs at most three round trips: one for the
-- event IDs (skipped when the caller passes them), one multi-row INSERT into
-- the events table and one into the outbox. Each entry is
-- { eventType = ..., spec = ..., eventId = optional pre-generated UUID }.
function JobEvents.RecordMany(tx, entries)
    local missing = 0
    for _, entry in ipairs(entries) do
        if not names[entry.eventType] then error('Invalid job event type.') end
        if entry.eventId == nil then missing = missing + 1 end
    end
    if missing > 0 then
        local ids = Jobs.NewIds(tx, missing)
        local used = 0
        for _, entry in ipairs(entries) do
            if entry.eventId == nil then
                used = used + 1
                entry.eventId = ids[used]
            end
        end
    end

    -- eventParams may hold nil (SQL NULL) values, so its length is tracked in
    -- `n` explicitly; `#` is undefined on a table with holes.
    local eventRows, eventParams, outboxRows, outboxParams = {}, { n = 0 }, {}, {}
    local function Push(value)
        eventParams.n = eventParams.n + 1
        eventParams[eventParams.n] = value
    end
    for _, entry in ipairs(entries) do
        local spec, eventId = entry.spec, entry.eventId
        if not Jobs.Uuid(eventId) then error('Invalid job event identity.') end
        local actor = spec.actor or {}
        local details = {}
        for _, field in ipairs(detailFields) do
            if spec.details and spec.details[field] ~= nil then details[field] = spec.details[field] end
        end
        local payload = {
            eventId = eventId,
            aggregateType = spec.aggregateType,
            aggregateId = spec.aggregateId,
            jobId = spec.jobId,
            characterId = spec.characterId,
            assignmentId = spec.assignmentId,
            revision = spec.revision,
            sourceResource = spec.resource,
            requestId = spec.requestId,
            reasonCode = spec.reasonCode,
            referenceType = spec.referenceType,
            referenceId = spec.referenceId,
            actorAccountId = actor.accountId,
            actorCharacterId = actor.characterId,
            correlationId = actor.correlationId
        }
        for field, value in pairs(details) do payload[field] = value end

        eventRows[#eventRows + 1] = '(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
        Push(eventId)
        Push(entry.eventType)
        Push(spec.aggregateType)
        Push(spec.aggregateId)
        Push(spec.jobId)
        Push(spec.characterId)
        Push(spec.resource)
        Push(spec.requestId)
        Push(spec.reasonCode)
        Push(spec.referenceType)
        Push(spec.referenceId)
        Push(spec.revision)
        Push(actor.accountId)
        Push(actor.characterId)
        Push(actor.correlationId)
        Push(next(details) and json.encode(details) or nil)

        outboxRows[#outboxRows + 1] = '(?,?,?)'
        outboxParams[#outboxParams + 1] = eventId
        outboxParams[#outboxParams + 1] = names[entry.eventType]
        outboxParams[#outboxParams + 1] = json.encode(payload)
    end

    tx.exec([[
        INSERT INTO `feather_job_events`
            (`event_id`,`event_type`,`aggregate_type`,`aggregate_id`,`job_id`,`character_id`,
             `source_resource`,`request_id`,`reason_code`,`reference_type`,`reference_id`,`revision`,
             `actor_account_id`,`actor_character_id`,`correlation_id`,`details_json`)
        VALUES ]] .. table.concat(eventRows, ','), table.unpack(eventParams, 1, eventParams.n))
    tx.exec('INSERT INTO `feather_job_outbox` (`event_id`,`event_type`,`payload_json`) VALUES ' ..
        table.concat(outboxRows, ','), table.unpack(outboxParams))
    return entries
end

-- Single-event form used by most mutations.
function JobEvents.Record(tx, eventType, spec, eventId)
    return JobEvents.RecordMany(tx, { { eventType = eventType, spec = spec, eventId = eventId } })[1].eventId
end

local function Deliver()
    local rows = DB.query([[SELECT `event_id`,`event_type`,`payload_json`
        FROM `feather_job_outbox` WHERE `status`='pending' AND `available_at`<=CURRENT_TIMESTAMP
        ORDER BY `created_at`,`event_id` LIMIT ?]], Config.Outbox.batchSize) or {}
    for _, row in ipairs(rows) do
        if not running then return end
        local decoded, payload = pcall(json.decode, row.payload_json)
        local called, published = false, nil
        if decoded and type(payload) == 'table' and payload.eventId == row.event_id then
            called, published = pcall(function()
                return exports['feather-core']:PublishEvent(row.event_type, payload)
            end)
        end
        if called and type(published) == 'table' and published.ok then
            DB.exec([[UPDATE `feather_job_outbox` SET `status`='published',
                `published_at`=CURRENT_TIMESTAMP,`attempts`=`attempts`+1
                WHERE `event_id`=? AND `status`='pending']], row.event_id)
        else
            DB.exec([[UPDATE `feather_job_outbox` SET `attempts`=`attempts`+1,
                `available_at`=DATE_ADD(CURRENT_TIMESTAMP,INTERVAL ? SECOND)
                WHERE `event_id`=? AND `status`='pending']],
                Config.Outbox.retryDelaySeconds, row.event_id)
            print(('[feather-jobs] event=outbox.failed id=%s code=%s'):format(row.event_id,
                type(published) == 'table' and tostring(published.code) or 'publication_unavailable'))
        end
    end
end

function JobEvents.Start()
    if running then return Err('conflict', 'Jobs publisher is already running.') end
    for _, name in pairs(names) do
        local declared = exports['feather-core']:DeclareEvent(name, {
            contract = 1, maxPayloadBytes = 4096, maxDepth = 3, maxNodes = 64
        })
        if type(declared) ~= 'table' or not declared.ok then
            return Err('dependency_unavailable', 'Could not declare jobs event.', { eventType = name })
        end
    end
    running = true
    CreateThread(function()
        while running do
            local called, reason = pcall(Deliver)
            if not called then print('[feather-jobs] event=outbox.error ' .. tostring(reason)) end
            Wait(Config.Outbox.pollIntervalMs)
        end
    end)
    return Ok(true)
end
function JobEvents.Stop() running = false end
function JobEvents.State()
    local rows = DB.query('SELECT `status`,COUNT(*) AS total FROM `feather_job_outbox` GROUP BY `status`') or {}
    local state = { running = running, pending = 0, published = 0 }
    for _, row in ipairs(rows) do state[row.status] = tonumber(row.total) end
    return Ok(state)
end

-- Owners read their own aggregates; privileged auditors read anything, including
-- the full per-character trail.
local function OwnerOf(aggregateType, aggregateId)
    if aggregateType == 'definition' then
        local row = DB.one('SELECT `owner_resource` FROM `feather_job_definitions` WHERE `job_id`=?', aggregateId)
        return row and row.owner_resource
    elseif aggregateType == 'grade' then
        local row = DB.one([[SELECT d.`owner_resource` FROM `feather_job_grades` g
            JOIN `feather_job_definitions` d ON d.`job_id`=g.`job_id` WHERE g.`grade_id`=?]], aggregateId)
        return row and row.owner_resource
    elseif aggregateType == 'assignment' then
        local row = DB.one('SELECT `owner_resource` FROM `feather_job_assignments` WHERE `assignment_id`=?',
            aggregateId)
        return row and row.owner_resource
    end
    return nil
end

function JobEvents.History(request, resource)
    local allowed = Jobs.CheckAccess('trustedAuditors', resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, { aggregateType = true, aggregateId = true, limit = true, cursor = true })
    if not fields.ok then return fields end
    local limit = request.limit == nil and 20 or request.limit
    if (request.aggregateType ~= 'definition' and request.aggregateType ~= 'grade'
        and request.aggregateType ~= 'assignment' and request.aggregateType ~= 'character')
        or not Jobs.Uuid(request.aggregateId) or not Jobs.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.cursor ~= nil and not Jobs.Uuid(request.cursor)) then
        return Err('invalid_input', 'Aggregate type, UUID, bounded limit, and event UUID cursor required.')
    end
    local aggregateId = request.aggregateId:lower()
    if Config.Access.privilegedAuditors[resource] ~= true then
        local owner = request.aggregateType ~= 'character' and OwnerOf(request.aggregateType, aggregateId) or nil
        if owner == nil and request.aggregateType ~= 'character' then
            return Err('not_found', 'Aggregate not found.')
        end
        if owner ~= resource then return Err('authorization_denied', 'Caller cannot inspect this history.') end
    end
    local column = request.aggregateType == 'character' and '`character_id`=?'
        or '`aggregate_type`=? AND `aggregate_id`=?'
    local sql = [[
        SELECT `event_id`,`event_type`,`aggregate_type`,`aggregate_id`,`job_id`,`character_id`,
            `source_resource`,`request_id`,`reason_code`,`reference_type`,`reference_id`,`revision`,
            `actor_account_id`,`actor_character_id`,`correlation_id`,`details_json`,
            FLOOR(UNIX_TIMESTAMP(`created_at`))*1000 AS created_at_ms
        FROM `feather_job_events` WHERE ]] .. column
    local params = request.aggregateType == 'character' and { aggregateId } or { request.aggregateType, aggregateId }
    if request.cursor then
        local cursor = DB.one([[
            SELECT DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_job_events` WHERE `event_id`=?]], request.cursor:lower())
        if not cursor then return Err('invalid_cursor', 'History cursor was not found.') end
        sql = sql .. ' AND (`created_at`<? OR (`created_at`=? AND `event_id`<?))'
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = request.cursor:lower()
    end
    sql = sql .. ' ORDER BY `created_at` DESC,`event_id` DESC LIMIT ?'
    params[#params + 1] = limit + 1
    local rows = DB.query(sql, table.unpack(params)) or {}
    local items = {}
    for index = 1, math.min(#rows, limit) do
        local row = rows[index]
        local decoded, details = false, nil
        if row.details_json then decoded, details = pcall(json.decode, row.details_json) end
        items[#items + 1] = {
            eventId = row.event_id,
            eventType = row.event_type,
            aggregateType = row.aggregate_type,
            aggregateId = row.aggregate_id,
            jobId = row.job_id,
            characterId = row.character_id,
            sourceResource = row.source_resource,
            requestId = row.request_id,
            reasonCode = row.reason_code,
            referenceType = row.reference_type,
            referenceId = row.reference_id,
            revision = tonumber(row.revision),
            actorAccountId = row.actor_account_id,
            actorCharacterId = row.actor_character_id,
            correlationId = row.correlation_id,
            details = decoded and details or nil,
            createdAt = tonumber(row.created_at_ms)
        }
    end
    return Ok({ items = items, nextCursor = #rows > limit and items[#items].eventId or nil })
end

Jobs.Export('InspectJobHistory', JobEvents.History)
