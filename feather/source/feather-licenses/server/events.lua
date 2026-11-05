LicenseEvents = {}
local Ok, Err = Licenses.Ok, Licenses.Err
local running = false

-- Committed facts.
local names = {
    ['definition.registered'] = 'licenses.definition.registered.v1',
    ['definition.updated'] = 'licenses.definition.updated.v1',
    ['license.issued'] = 'licenses.license.issued.v1',
    ['license.renewed'] = 'licenses.license.renewed.v1',
    ['license.suspended'] = 'licenses.license.suspended.v1',
    ['license.reinstated'] = 'licenses.license.reinstated.v1',
    ['license.revoked'] = 'licenses.license.revoked.v1',
    ['license.expired'] = 'licenses.license.expired.v1'
}
LicenseEvents.Names = names

-- Scope bodies are never copied into events (payloads are bounded); only the
-- scope version travels with the fact.
local detailFields = {
    'label',
    'ownerResource',
    'status',
    'previousStatus',
    'defaultDurationSeconds',
    'maxDurationSeconds',
    'renewable',
    'issuerType',
    'issuerId',
    'issuerResource',
    'expiresAt',
    'previousExpiresAt',
    'scopeVersion'
}

-- Writes audit facts and their outbox rows inside the caller's transaction:
-- one multi-row INSERT into the events table and one into the outbox. Each entry
-- is { eventType = ..., spec = ..., eventId = optional pre-generated UUID }.
function LicenseEvents.RecordMany(tx, entries)
    local missing = 0
    for _, entry in ipairs(entries) do
        if not names[entry.eventType] then
            error('Invalid license event type.')
        end
        if entry.eventId == nil then
            missing = missing + 1
        end
    end
    if missing > 0 then
        local ids = Licenses.NewIds(tx, missing)
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
        if not Licenses.Uuid(eventId) then
            error('Invalid license event identity.')
        end
        local actor = spec.actor or {}
        local details = {}
        for _, field in ipairs(detailFields) do
            if spec.details and spec.details[field] ~= nil then
                details[field] = spec.details[field]
            end
        end
        local payload = {
            eventId = eventId,
            aggregateType = spec.aggregateType,
            aggregateId = spec.aggregateId,
            licenseKey = spec.licenseKey,
            licenseId = spec.licenseId,
            holderType = spec.holderType,
            holderId = spec.holderId,
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
        for field, value in pairs(details) do
            payload[field] = value
        end

        eventRows[#eventRows + 1] = '(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
        Push(eventId)
        Push(entry.eventType)
        Push(spec.aggregateType)
        Push(spec.aggregateId)
        Push(spec.licenseKey)
        Push(spec.holderType)
        Push(spec.holderId)
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
        INSERT INTO `feather_license_events`
            (`event_id`,`event_type`,`aggregate_type`,`aggregate_id`,`license_key`,`holder_type`,`holder_id`,
             `source_resource`,`request_id`,`reason_code`,`reference_type`,`reference_id`,`revision`,
             `actor_account_id`,`actor_character_id`,`correlation_id`,`details_json`)
        VALUES ]] .. table.concat(eventRows, ','), table.unpack(eventParams, 1, eventParams.n))
    tx.exec([[
        INSERT INTO `feather_license_outbox` (`event_id`,`event_type`,`payload_json`)
        VALUES ]] .. table.concat(outboxRows, ','), table.unpack(outboxParams))
    return entries
end

-- Single-event form used by every mutation.
function LicenseEvents.Record(tx, eventType, spec, eventId)
    return LicenseEvents.RecordMany(tx, {
        {
            eventType = eventType,
            spec = spec,
            eventId = eventId
        }
    })[1].eventId
end

local function Deliver()
    local rows = DB.query([[
        SELECT `event_id`,`event_type`,`payload_json`
        FROM `feather_license_outbox`
        WHERE `status`='pending' AND `available_at`<=CURRENT_TIMESTAMP
        ORDER BY `created_at`,`event_id` LIMIT ?]], Config.Outbox.batchSize) or {}
    for _, row in ipairs(rows) do
        if not running then
            return
        end
        local decoded, payload = pcall(json.decode, row.payload_json)
        local called, published = false, nil
        if decoded and type(payload) == 'table' and payload.eventId == row.event_id then
            called, published = pcall(function()
                return exports['feather-core']:PublishEvent(row.event_type, payload)
            end)
        end
        if called and type(published) == 'table' and published.ok then
            DB.exec([[
                UPDATE `feather_license_outbox`
                SET `status`='published',`published_at`=CURRENT_TIMESTAMP,`attempts`=`attempts`+1
                WHERE `event_id`=? AND `status`='pending']], row.event_id)
        else
            DB.exec([[
                UPDATE `feather_license_outbox`
                SET `attempts`=`attempts`+1,`available_at`=DATE_ADD(CURRENT_TIMESTAMP,INTERVAL ? SECOND)
                WHERE `event_id`=? AND `status`='pending']],
                Config.Outbox.retryDelaySeconds, row.event_id)
            print(('[feather-licenses] event=outbox.failed id=%s code=%s'):format(row.event_id,
                type(published) == 'table' and tostring(published.code) or 'publication_unavailable'))
        end
    end
end

function LicenseEvents.Start()
    if running then
        return Err('conflict', 'Licenses publisher is already running.')
    end
    for _, name in pairs(names) do
        local declared = exports['feather-core']:DeclareEvent(name, {
            contract = 1,
            maxPayloadBytes = 4096,
            maxDepth = 3,
            maxNodes = 64
        })
        if type(declared) ~= 'table' or not declared.ok then
            return Err('dependency_unavailable', 'Could not declare licenses event.', { eventType = name })
        end
    end
    running = true
    CreateThread(function()
        while running do
            local called, reason = pcall(Deliver)
            if not called then
                print('[feather-licenses] event=outbox.error ' .. tostring(reason))
            end
            Wait(Config.Outbox.pollIntervalMs)
        end
    end)
    return Ok(true)
end

function LicenseEvents.Stop()
    running = false
end

function LicenseEvents.State()
    local rows = DB.query('SELECT `status`,COUNT(*) AS total FROM `feather_license_outbox` GROUP BY `status`') or {}
    local state = { running = running, pending = 0, published = 0 }
    for _, row in ipairs(rows) do
        state[row.status] = tonumber(row.total)
    end
    return Ok(state)
end

-- InspectLicenseHistory ----------------------------------------------------------
-- The definition owner reads its definitions and their licenses; privileged
-- auditors read anything.

local function OwnerOf(aggregateType, aggregateId)
    if aggregateType == 'definition' then
        local row = DB.one('SELECT `owner_resource` FROM `feather_license_definitions` WHERE `license_key`=?',
            aggregateId)
        return row and row.owner_resource
    end
    local row = DB.one([[
        SELECT d.`owner_resource` FROM `feather_licenses` l
        JOIN `feather_license_definitions` d ON d.`license_key`=l.`license_key`
        WHERE l.`license_id`=?]], aggregateId)
    return row and row.owner_resource
end

function LicenseEvents.History(request, resource)
    local allowed = Licenses.CheckAccess('trustedAuditors', resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Licenses.Fields(request, { aggregateType = true, aggregateId = true, limit = true, cursor = true })
    if not fields.ok then
        return fields
    end
    local limit = request.limit == nil and 20 or request.limit
    local aggregateType = request.aggregateType
    local validId = (aggregateType == 'definition' and Licenses.Key(request.aggregateId, 48))
        or (aggregateType == 'license' and Licenses.Uuid(request.aggregateId))
    if not validId or not Licenses.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.cursor ~= nil and not Licenses.Uuid(request.cursor)) then
        return Err('invalid_input',
            'Aggregate type (definition or license), its key or UUID, bounded limit, and event UUID cursor required.')
    end
    local aggregateId = aggregateType == 'license' and request.aggregateId:lower() or request.aggregateId
    if Config.Access.privilegedAuditors[resource] ~= true then
        local owner = OwnerOf(aggregateType, aggregateId)
        if owner == nil then
            return Err(aggregateType == 'definition' and 'definition_not_found' or 'license_not_found',
                'Aggregate not found.')
        end
        if owner ~= resource then
            return Err('authorization_denied', 'Caller cannot inspect this history.')
        end
    end

    local sql = [[
        SELECT `event_id`,`event_type`,`aggregate_type`,`aggregate_id`,`license_key`,`holder_type`,`holder_id`,
            `source_resource`,`request_id`,`reason_code`,`reference_type`,`reference_id`,`revision`,
            `actor_account_id`,`actor_character_id`,`correlation_id`,`details_json`,
            FLOOR(UNIX_TIMESTAMP(`created_at`))*1000 AS created_at_ms
        FROM `feather_license_events`
        WHERE `aggregate_type`=? AND `aggregate_id`=?]]
    local params = { aggregateType, aggregateId }
    if request.cursor then
        local cursor = DB.one([[
            SELECT DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_license_events` WHERE `event_id`=? AND `aggregate_id`=?]],
            request.cursor:lower(), aggregateId)
        if not cursor then
            return Err('invalid_cursor', 'History cursor was not found.')
        end
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
        if row.details_json then
            decoded, details = pcall(json.decode, row.details_json)
        end
        items[#items + 1] = {
            eventId = row.event_id,
            eventType = row.event_type,
            aggregateType = row.aggregate_type,
            aggregateId = row.aggregate_id,
            licenseKey = row.license_key,
            holderType = row.holder_type,
            holderId = row.holder_id,
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
    return Ok({
        items = items,
        nextCursor = #rows > limit and items[#items].eventId or nil
    })
end

Licenses.Export('InspectLicenseHistory', LicenseEvents.History)
