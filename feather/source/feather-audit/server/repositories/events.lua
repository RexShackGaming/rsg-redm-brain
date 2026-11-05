FeatherAuditEventRepository = {}

local function existing(sourceResource, sourceInstance, eventId)
    return DB.one([[SELECT audit_event_id AS auditEventId,
        canonical_payload AS canonicalPayload, integrity_hash AS integrityHash
        FROM feather_audit_events
        WHERE source_resource = ? AND source_instance = ? AND producer_event_id = ? LIMIT 1]],
        sourceResource, sourceInstance, eventId)
end

local function databaseTimestamp(value)
    local normalized = value:sub(1, -2):gsub('T', ' ')
    return normalized
end

local function statementsFor(auditEventId, event, canonical, contextJson)
    local statements = {
        {
            query = [[INSERT INTO feather_audit_events
                (audit_event_id, source_resource, source_instance, producer_event_id,
                 event_type, event_version, contract_version, occurred_at,
                 invoking_resource, correlation_id, causation_id,
                 actor_type, actor_id, actor_account_id, actor_character_id,
                 actor_resource, actor_display_name, result, reason_code, summary,
                 context_json, canonical_payload, sensitivity_class, retention_class, integrity_hash)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                        ?, ?, ?, ?, SHA2(?, 256))]],
            values = table.pack(
                auditEventId, event.sourceResource, event.sourceInstance, event.eventId,
                event.eventType, event.eventVersion, event.contractVersion, databaseTimestamp(event.occurredAt),
                event.invokingResource, event.correlationId, event.causationId,
                event.actor.type, event.actor.id, event.actor.accountId, event.actor.characterId,
                event.actor.resource, event.actor.displayName, event.result, event.reasonCode, event.summary,
                contextJson, canonical, event.sensitivityClass, event.retentionClass, canonical
            )
        }
    }
    for index, target in ipairs(event.targets) do
        statements[#statements + 1] = {
            query = [[INSERT INTO feather_audit_targets
                (audit_event_id, ordinal, target_type, target_id, target_role, target_resource, target_display_name)
                VALUES (?, ?, ?, ?, ?, ?, ?)]],
            values = table.pack(auditEventId, index, target.type, target.id, target.role, target.resource, target.displayName)
        }
    end
    for index, reference in ipairs(event.references) do
        statements[#statements + 1] = {
            query = [[INSERT INTO feather_audit_references
                (audit_event_id, ordinal, reference_resource, reference_type, reference_id)
                VALUES (?, ?, ?, ?, ?)]],
            values = table.pack(auditEventId, index, reference.resource, reference.type, reference.id)
        }
    end
    return statements
end

function FeatherAuditEventRepository.Accept(event, canonical, contextJson)
    local found = existing(event.sourceResource, event.sourceInstance, event.eventId)
    if found then
        return found.canonicalPayload == canonical and 'duplicate' or 'identity_conflict', found.auditEventId
    end

    local auditEventId = DB.value('SELECT UUID()')
    -- Kept as its own pcall (rather than letting a transaction failure raise past this point) so
    -- the diagnostic reason below still distinguishes "the transaction itself was rejected" from
    -- a genuine database/connection error, matching this function's documented outcomes.
    local transacted, transactionResult = pcall(DB.transaction, function(tx)
        for _, statement in ipairs(statementsFor(auditEventId, event, canonical, contextJson)) do
            tx.raw(statement.query, table.unpack(statement.values, 1, statement.values.n))
        end
        return true
    end)
    if transacted and transactionResult == true then return 'accepted', auditEventId end

    found = existing(event.sourceResource, event.sourceInstance, event.eventId)
    if found then
        return found.canonicalPayload == canonical and 'duplicate' or 'identity_conflict', found.auditEventId
    end
    return 'retryable_rejection', nil, transacted and 'transaction_rejected' or 'database_error'
end

function FeatherAuditEventRepository.FindByProducerIdentity(sourceResource, sourceInstance, eventId)
    return existing(sourceResource, sourceInstance, eventId)
end
