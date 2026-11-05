FeatherAuditSearchRepository = {}

function FeatherAuditSearchRepository.Read(request, identity)
    local where = { 'occurred_at >= ?', 'occurred_at <= ?', "redaction_state = 'active'" }
    local parameters = { os.date('!%Y-%m-%d %H:%M:%S', request.fromEpoch),
        os.date('!%Y-%m-%d %H:%M:%S', request.toEpoch) }
    if identity.sensitive == true then
        where[#where + 1] = "sensitivity_class IN ('public', 'internal', 'restricted')"
    else
        where[#where + 1] = "sensitivity_class IN ('public', 'internal')"
    end
    for _, filter in ipairs({ { 'sourceResource', 'source_resource' },
        { 'eventType', 'event_type' }, { 'correlationId', 'correlation_id' },
        { 'eventId', 'audit_event_id' } }) do
        if request[filter[1]] then
            where[#where + 1] = filter[2] .. ' = ?'
            parameters[#parameters + 1] = request[filter[1]]
        end
    end
    if request.positionTime then
        where[#where + 1] = '(occurred_at < ? OR (occurred_at = ? AND audit_event_id < ?))'
        parameters[#parameters + 1] = request.positionTime
        parameters[#parameters + 1] = request.positionTime
        parameters[#parameters + 1] = request.positionId
    end
    if request.targetAccountId then
        where[#where + 1] = [[EXISTS (SELECT 1 FROM feather_audit_targets t
            WHERE t.audit_event_id = feather_audit_events.audit_event_id
              AND t.target_type = 'account' AND t.target_id = ?)]]
        parameters[#parameters + 1] = request.targetAccountId
    end
    if request.targetCharacterId then
        where[#where + 1] = [[EXISTS (SELECT 1 FROM feather_audit_targets t
            WHERE t.audit_event_id = feather_audit_events.audit_event_id
              AND t.target_type = 'character' AND t.target_id = ?)]]
        parameters[#parameters + 1] = request.targetCharacterId
    end
    if request.adminAction then
        where[#where + 1] = [[source_resource = 'feather-admin' AND event_type = 'admin.action.recorded'
            AND event_version = 1 AND JSON_UNQUOTE(JSON_EXTRACT(context_json, '$.action')) = ?]]
        parameters[#parameters + 1] = request.adminAction
    end
    parameters[#parameters + 1] = request.limit + 1
    local detail = request.operation == 'audit.event.get.v1'
    local contentColumns = detail and ', event_version AS eventVersion, context_json AS projectedContext' or ''
    local sql = [[SELECT audit_event_id AS eventId, event_type AS eventType,
        source_resource AS sourceResource, correlation_id AS correlationId,
        DATE_FORMAT(occurred_at, '%Y-%m-%dT%H:%i:%s.%fZ') AS occurredAt,
        DATE_FORMAT(occurred_at, '%Y-%m-%d %H:%i:%s.%f') AS positionTime,
        result, reason_code AS reasonCode, sensitivity_class AS sensitivityClass,
        retention_class AS retentionClass]] .. contentColumns
        .. ' FROM feather_audit_events WHERE ' .. table.concat(where, ' AND ')
        .. ' ORDER BY occurred_at DESC, audit_event_id DESC LIMIT ?'
    local rows
    local committed = DB.transaction(function(tx)
        rows = tx.query(sql, table.unpack(parameters)) or {}
        for _, row in ipairs(rows) do
            if detail then
                row.content = FeatherAuditProjection.Context(row.eventType, row.eventVersion,
                    row.projectedContext, identity.sensitive)
            end
            row.projectedContext = nil
        end
        tx.exec([[INSERT INTO feather_audit_access_events
            (access_event_id, requester_type, requester_id, operation,
             query_fingerprint, sensitivity_reached, reason_code, result)
            VALUES (UUID(), ?, ?, ?, SHA2(?, 256), ?, ?, 'success')]],
            identity.type, identity.id, request.operation or 'audit.search.v1',
            FeatherAuditCanonical.Encode(request, { type = 'object' }),
            identity.sensitive and 'restricted' or 'internal', 'audit_read')
        return true
    end)
    if committed ~= true then error('audit access transaction rejected') end
    return { events = rows, limit = request.limit }
end
