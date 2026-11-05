EconomyOutbox = {}

local running = false
local logger = EconomyLogging.Create('outbox')

local function DeliverBatch()
    local rows = DB.query([[
        SELECT `event_id`,`event_type`,`aggregate_id`,`payload_json`,`attempts`
        FROM `economy_outbox`
        WHERE `status`='pending' AND `available_at` <= CURRENT_TIMESTAMP
        ORDER BY `created_at`,`event_id` LIMIT ?
    ]], Config.Outbox.batchSize) or {}
    for _, row in ipairs(rows) do
        local decoded, payload = pcall(json.decode, row.payload_json)
        local published = decoded and type(payload) == 'table'
            and exports['feather-core']:PublishEvent(row.event_type, payload) or nil
        if type(published) == 'table' and published.ok == true then
            DB.exec([[
                UPDATE `economy_outbox` SET `status`='published',
                    `published_at`=CURRENT_TIMESTAMP,`attempts`=`attempts`+1
                WHERE `event_id`=? AND `status`='pending'
            ]], row.event_id)
        else
            DB.exec([[
                UPDATE `economy_outbox` SET `attempts`=`attempts`+1,
                    `available_at`=DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND)
                WHERE `event_id`=? AND `status`='pending'
            ]], Config.Outbox.retryDelaySeconds, row.event_id)
            logger.Warn('delivery.failed', {
                eventId = row.event_id, eventType = row.event_type,
                code = type(published) == 'table' and published.code or 'invalid_payload'
            })
        end
    end
    return #rows
end

function EconomyOutbox.Start()
    if running then return EconomyResults.Err('conflict', 'Economy outbox is already running.') end
    running = true
    CreateThread(function()
        while running do
            local ok, failure = pcall(DeliverBatch)
            if not ok then logger.Error('delivery.crashed', { reason = tostring(failure) }) end
            Wait(Config.Outbox.pollIntervalMs)
        end
    end)
    return EconomyResults.Ok(true)
end

function EconomyOutbox.Stop() running = false end

function EconomyOutbox.GetState()
    local pending = tonumber(DB.value(
        "SELECT COUNT(*) FROM `economy_outbox` WHERE `status`='pending'")) or 0
    local published = tonumber(DB.value(
        "SELECT COUNT(*) FROM `economy_outbox` WHERE `status`='published'")) or 0
    return EconomyResults.Ok({ running = running, pending = pending, published = published })
end
