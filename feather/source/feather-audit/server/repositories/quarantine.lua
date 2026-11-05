FeatherAuditQuarantineRepository = {}

local function bounded(value, maximum)
    if value == nil then return nil end
    return tostring(value):gsub('[%c]', ''):sub(1, maximum)
end

function FeatherAuditQuarantineRepository.Record(sourceResource, event, rejection)
    local sourceInstance = type(event) == 'table' and bounded(event.sourceInstance, 128) or nil
    local eventId = type(event) == 'table' and bounded(event.eventId, 128) or nil
    local eventType = type(event) == 'table' and bounded(event.eventType, 128) or nil
    local code = bounded(rejection.code or 'invalid_event', 128)
    local path = bounded(rejection.path, 256)
    DB.exec([[INSERT INTO feather_audit_quarantine
        (fingerprint, source_resource, source_instance, producer_event_id,
         event_type, rejection_code, rejection_path)
        VALUES (SHA2(CONCAT_WS('|', ?, ?, ?, ?, ?, ?), 256), ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE last_seen_at = CURRENT_TIMESTAMP(3),
            occurrence_count = occurrence_count + 1]],
        sourceResource, sourceInstance or '', eventId or '', eventType or '', code, path or '',
        sourceResource, sourceInstance, eventId, eventType, code, path
    )
end

function FeatherAuditQuarantineRepository.CountOpen()
    return tonumber(DB.value(
        "SELECT COUNT(*) FROM feather_audit_quarantine WHERE state = 'open'")) or 0
end
