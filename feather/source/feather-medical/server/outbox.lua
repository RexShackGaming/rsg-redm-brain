MedicalOutbox = {}
local O = MedicalOutbox
O.event = 'medical.condition.changed.v1'

function O.Validate(payload)
    if type(payload) ~= 'table' then return false end
    local allowed = {eventId = true, characterId = true, episodeId = true, revision = true,
        lifeState = true, reason = true, occurredAt = true}
    for key in pairs(payload) do if not allowed[key] then return false end end
    if payload.episodeId ~= nil and (type(payload.episodeId) ~= 'string' or #payload.episodeId ~= 36) then return false end
    return type(payload.eventId) == 'string' and #payload.eventId == 36
        and type(payload.characterId) == 'string' and #payload.characterId > 0 and #payload.characterId <= 64
        and type(payload.revision) == 'number' and payload.revision >= 1 and payload.revision % 1 == 0
        and (payload.lifeState == 'alive' or payload.lifeState == 'incapacitated' or payload.lifeState == 'dead')
        and type(payload.reason) == 'string' and #payload.reason <= 64
        and type(payload.occurredAt) == 'number' and payload.occurredAt >= 0 and payload.occurredAt % 1 == 0
end

function O.Tick(repository, publish, decode, now)
    local rows = repository.PendingEvents() or {}
    local blocked, delivered, failures = {}, 0, 0
    for _, row in ipairs(rows) do
        if not blocked[row.character_id] then
            local ok, published = pcall(function()
                local payload = decode(row.payload)
                assert(O.Validate(payload) and payload.eventId == row.event_id
                    and payload.characterId == row.character_id and payload.revision == tonumber(row.revision), 'Invalid outbox fact')
                local result = publish(O.event, payload)
                if type(result) ~= 'table' or not result.ok or type(result.value) ~= 'table'
                    or result.value.failed ~= 0 then return false end
                repository.MarkPublished(row.event_id, now)
                return true
            end)
            if ok and published then delivered = delivered + 1
            else blocked[row.character_id] = true; failures = failures + 1 end
        end
    end
    -- Publication is at least once: failures after delivery/before the stored
    -- acknowledgement can replay. Consumers must deduplicate stable eventId.
    return {scanned = #rows, published = delivered, failures = failures}
end
return O
