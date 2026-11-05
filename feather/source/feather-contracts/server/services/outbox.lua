ContractsOutbox = {}

local running = false
local logger = ContractsLogging.Create('outbox')

-- Records a committed fact inside the caller's transaction. Delivery happens
-- after commit, so subscribers never observe a rolled-back change.
function ContractsOutbox.Record(tx, eventKey, aggregateId, payload)
    local eventType = ContractsFoundation.Events[eventKey]
    if not eventType then error(('Unknown Contracts event %s.'):format(tostring(eventKey))) end
    local eventId = ContractsValidation.NewUuid(tx)
    payload = ContractsFoundation.Copy(payload or {})
    payload.eventId = eventId
    payload.contract = 1
    tx.exec([[INSERT INTO `contract_outbox` (`event_id`,`event_type`,`aggregate_id`,`payload_json`)
        VALUES (?,?,?,?)]], eventId, eventType, aggregateId, json.encode(payload))
    return eventId
end

local function DeliverBatch()
    local rows = DB.query([[
        SELECT `event_id`,`event_type`,`payload_json` FROM `contract_outbox`
        WHERE `status`='pending' AND `available_at` <= CURRENT_TIMESTAMP
        ORDER BY `created_at`,`event_id` LIMIT ?
    ]], Config.Outbox.batchSize) or {}
    for _, row in ipairs(rows) do
        if not running then return end
        local decoded, payload = pcall(json.decode, row.payload_json)
        local called, published = false, nil
        if decoded and type(payload) == 'table' and payload.eventId == row.event_id then
            called, published = pcall(function()
                return exports['feather-core']:PublishEvent(row.event_type, payload)
            end)
        end
        if called and type(published) == 'table' and published.ok == true then
            DB.exec([[UPDATE `contract_outbox` SET `status`='published',
                `published_at`=CURRENT_TIMESTAMP,`attempts`=`attempts`+1
                WHERE `event_id`=? AND `status`='pending']], row.event_id)
        else
            DB.exec([[UPDATE `contract_outbox` SET `attempts`=`attempts`+1,
                `available_at`=DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND)
                WHERE `event_id`=? AND `status`='pending']], Config.Outbox.retryDelaySeconds, row.event_id)
            logger.Warn('delivery.failed', {
                eventId = row.event_id, eventType = row.event_type,
                code = called and type(published) == 'table' and published.code or 'publication_unavailable'
            })
        end
    end
end

function ContractsOutbox.Start()
    if running then return ContractsResults.Err('conflict', 'Contracts outbox is already running.') end
    running = true
    CreateThread(function()
        while running do
            local ok, failure = pcall(DeliverBatch)
            if not ok then logger.Error('delivery.crashed', { reason = tostring(failure) }) end
            Wait(Config.Outbox.pollIntervalMs)
        end
    end)
    return ContractsResults.Ok(true)
end

function ContractsOutbox.Stop() running = false end

function ContractsOutbox.GetState()
    local rows = DB.query('SELECT `status`,COUNT(*) AS total FROM `contract_outbox` GROUP BY `status`') or {}
    local state = { running = running, pending = 0, published = 0 }
    for _, row in ipairs(rows) do state[row.status] = tonumber(row.total) end
    return ContractsResults.Ok(state)
end
