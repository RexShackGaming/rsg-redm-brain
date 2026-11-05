AssetEvents = {}
local Ok, Err = Assets.Ok, Assets.Err
local running = false

-- Committed facts, as listed in the master plan.
local names = {
    ['asset.registered'] = 'assets.asset.registered.v1',
    ['ownership.transferred'] = 'assets.ownership.transferred.v1',
    ['status.changed'] = 'assets.status.changed.v1',
    ['metadata.revised'] = 'assets.metadata.revised.v1',
    ['asset.retired'] = 'assets.asset.retired.v1'
}
AssetEvents.Names = names

-- Metadata bodies are never copied into events (payloads are bounded); only
-- the metadata version travels with the fact.
local detailFields = {
    'modelKey',
    'status',
    'previousStatus',
    'interestId',
    'previousInterestId',
    'previousHolderType',
    'previousHolderId',
    'provenanceType',
    'provenanceId',
    'managerResource',
    'metadataVersion',
    'previousMetadataVersion',
    'delegationEpoch'
}

-- Writes audit facts and their outbox rows inside the caller's transaction:
-- one multi-row INSERT into the events table and one into the outbox. Each entry
-- is { eventType = ..., spec = ..., eventId = optional pre-generated UUID }.
function AssetEvents.RecordMany(tx, entries)
    local missing = 0
    for _, entry in ipairs(entries) do
        if not names[entry.eventType] then
            error('Invalid asset event type.')
        end
        if entry.eventId == nil then
            missing = missing + 1
        end
    end
    if missing > 0 then
        local ids = Assets.NewIds(tx, missing)
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
        if not Assets.Uuid(eventId) then
            error('Invalid asset event identity.')
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
            assetId = spec.assetId,
            assetType = spec.assetType,
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

        eventRows[#eventRows + 1] = '(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
        Push(eventId)
        Push(entry.eventType)
        Push(spec.assetId)
        Push(spec.assetType)
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
        INSERT INTO `feather_asset_events`
            (`event_id`,`event_type`,`asset_id`,`asset_type`,`holder_type`,`holder_id`,
             `source_resource`,`request_id`,`reason_code`,`reference_type`,`reference_id`,`revision`,
             `actor_account_id`,`actor_character_id`,`correlation_id`,`details_json`)
        VALUES ]] .. table.concat(eventRows, ','), table.unpack(eventParams, 1, eventParams.n))
    tx.exec([[
        INSERT INTO `feather_asset_outbox` (`event_id`,`event_type`,`payload_json`)
        VALUES ]] .. table.concat(outboxRows, ','), table.unpack(outboxParams))
    return entries
end

-- Single-event form used by every mutation.
function AssetEvents.Record(tx, eventType, spec, eventId)
    return AssetEvents.RecordMany(tx, {
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
        FROM `feather_asset_outbox`
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
                UPDATE `feather_asset_outbox`
                SET `status`='published',`published_at`=CURRENT_TIMESTAMP,`attempts`=`attempts`+1
                WHERE `event_id`=? AND `status`='pending']], row.event_id)
        else
            DB.exec([[
                UPDATE `feather_asset_outbox`
                SET `attempts`=`attempts`+1,`available_at`=DATE_ADD(CURRENT_TIMESTAMP,INTERVAL ? SECOND)
                WHERE `event_id`=? AND `status`='pending']],
                Config.Outbox.retryDelaySeconds, row.event_id)
            print(('[feather-assets] event=outbox.failed id=%s code=%s'):format(row.event_id,
                type(published) == 'table' and tostring(published.code) or 'publication_unavailable'))
        end
    end
end

function AssetEvents.Start()
    if running then
        return Err('conflict', 'Assets publisher is already running.')
    end
    for _, name in pairs(names) do
        local declared = exports['feather-core']:DeclareEvent(name, {
            contract = 1,
            maxPayloadBytes = 4096,
            maxDepth = 3,
            maxNodes = 64
        })
        if type(declared) ~= 'table' or not declared.ok then
            return Err('dependency_unavailable', 'Could not declare assets event.', { eventType = name })
        end
    end
    running = true
    CreateThread(function()
        while running do
            local called, reason = pcall(Deliver)
            if not called then
                print('[feather-assets] event=outbox.error ' .. tostring(reason))
            end
            Wait(Config.Outbox.pollIntervalMs)
        end
    end)
    return Ok(true)
end

function AssetEvents.Stop()
    running = false
end

function AssetEvents.State()
    local rows = DB.query('SELECT `status`,COUNT(*) AS total FROM `feather_asset_outbox` GROUP BY `status`') or {}
    local state = { running = running, pending = 0, published = 0 }
    for _, row in ipairs(rows) do
        state[row.status] = tonumber(row.total)
    end
    return Ok(state)
end

-- InspectAssetHistory ----------------------------------------------------------
-- The managing resource reads its own assets; privileged auditors read any asset.

function AssetEvents.History(request, resource)
    local allowed = Assets.CheckAccess('trustedAuditors', resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Assets.Fields(request, { assetId = true, limit = true, cursor = true })
    if not fields.ok then
        return fields
    end
    local limit = request.limit == nil and 20 or request.limit
    if not Assets.Uuid(request.assetId) or not Assets.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.cursor ~= nil and not Assets.Uuid(request.cursor)) then
        return Err('invalid_input', 'Asset UUID, bounded limit, and optional event UUID cursor required.')
    end
    local assetId = request.assetId:lower()
    if Config.Access.privilegedAuditors[resource] ~= true then
        local row = DB.one('SELECT `manager_resource` FROM `feather_asset_records` WHERE `asset_id`=?', assetId)
        if not row then
            return Err('asset_not_found', 'Asset not found.')
        end
        if row.manager_resource ~= resource then
            return Err('authorization_denied', 'Caller cannot inspect this history.')
        end
    end

    local sql = [[
        SELECT `event_id`,`event_type`,`asset_id`,`asset_type`,`holder_type`,`holder_id`,
            `source_resource`,`request_id`,`reason_code`,`reference_type`,`reference_id`,`revision`,
            `actor_account_id`,`actor_character_id`,`correlation_id`,`details_json`,
            FLOOR(UNIX_TIMESTAMP(`created_at`))*1000 AS created_at_ms
        FROM `feather_asset_events`
        WHERE `asset_id`=?]]
    local params = { assetId }
    if request.cursor then
        local cursor = DB.one([[
            SELECT DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_asset_events` WHERE `event_id`=? AND `asset_id`=?]], request.cursor:lower(), assetId)
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
            assetId = row.asset_id,
            assetType = row.asset_type,
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

Assets.Export('InspectAssetHistory', AssetEvents.History)
