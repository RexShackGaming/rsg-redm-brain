MedicalRepository = {}
local R = MedicalRepository

local function decode(row)
    if not row then return nil end
    local record = {characterId = row.character_id, lifeState = row.life_state,
        episodeId = row.active_episode_id, openedAt = tonumber(row.opened_at),
        bleedOutAt = tonumber(row.bleed_out_at), doctorAvailableAt = tonumber(row.doctor_available_at),
        revision = tonumber(row.revision), updatedAt = tonumber(row.updated_at)}
    assert(record.revision and record.updatedAt, 'Corrupt Medical condition')
    assert(record.lifeState == 'alive' or record.lifeState == 'incapacitated' or record.lifeState == 'dead', 'Invalid Medical life state')
    if record.lifeState == 'alive' then
        assert(not record.episodeId and not record.bleedOutAt and not record.doctorAvailableAt, 'Alive condition contains an episode')
    else
        assert(record.episodeId and record.openedAt and record.doctorAvailableAt, 'Medical episode metadata missing')
        assert(record.lifeState ~= 'incapacitated' or record.bleedOutAt, 'Bleedout deadline missing')
    end
    return record
end

function R.Get(characterId)
    return decode(DB.one('SELECT * FROM fm_condition WHERE character_id = ?', characterId))
end

function R.HasHistory(characterId)
    return DB.one('SELECT episode_id FROM fm_episodes WHERE character_id = ? LIMIT 1', characterId) ~= nil
        or DB.one('SELECT operation_id FROM fm_recovery_operations WHERE character_id = ? LIMIT 1', characterId) ~= nil
        or DB.one('SELECT event_id FROM fm_transition_outbox WHERE character_id = ? LIMIT 1', characterId) ~= nil
end

function R.PendingRecovery(characterId)
    return DB.one([[SELECT r.* FROM fm_recovery_operations r JOIN fm_condition c
        ON c.character_id = r.character_id AND c.active_episode_id = r.episode_id
        WHERE r.character_id = ? AND r.status = 'pending' LIMIT 1]], characterId)
end

function R.BeginRecovery(characterId, requestedBy, now, operationId, isCurrent, kind, destination)
    kind = kind or 'staff'
    assert(kind == 'staff' or kind == 'doctor', 'Invalid recovery kind')
    local result
    DB.transaction(function(tx)
        result = nil
        local record = decode(tx.one('SELECT * FROM fm_condition WHERE character_id = ? FOR UPDATE', characterId))
        if not record then result = {ok = false, code = 'condition_missing'}; return false end
        if not isCurrent() then result = {ok = false, code = 'stale_session'}; return false end
        if record.lifeState == 'alive' then result = {ok = false, code = 'player_not_dead'}; return false end
        if kind == 'doctor' and not MedicalLifecycle.CanRequestDoctor(record, now) then result = {ok = false, code = 'doctor_not_available'}; return false end
        local existing = tx.one('SELECT * FROM fm_recovery_operations WHERE episode_id = ?', record.episodeId)
        if existing then
            if existing.status ~= 'pending' then result = {ok = false, code = 'recovery_conflict'}; return false end
            result = {ok = true, value = {operationId = existing.operation_id, episodeId = record.episodeId}}
        else
            tx.insert([[INSERT INTO fm_recovery_operations
                (operation_id, episode_id, character_id, recovery_kind, status, requested_by, created_at)
                VALUES (?, ?, ?, ?, 'pending', ?, ?)]], operationId, record.episodeId, characterId, kind, requestedBy, now)
            if destination then tx.exec('UPDATE fm_recovery_operations SET destination_snapshot = ? WHERE operation_id = ?', json.encode(destination), operationId) end
            result = {ok = true, value = {operationId = operationId, episodeId = record.episodeId}}
        end
        if not isCurrent() then result = {ok = false, code = 'stale_session'}; return false end
        return true
    end)
    return result
end
R.BeginStaffRecovery = R.BeginRecovery

-- Only Character provisioning may initialize. Reads never invent an alive row.
function R.Initialize(characterId, now)
    DB.exec([[INSERT IGNORE INTO fm_condition (character_id, life_state, revision, updated_at)
        VALUES (?, 'alive', 0, ?)]], characterId, now)
    return R.Get(characterId)
end

local function persist(tx, record, eventId, reason, now, previousEpisodeId)
    local episodeId = record.episodeId or previousEpisodeId
    tx.exec([[UPDATE fm_condition SET life_state = ?, active_episode_id = ?, opened_at = ?,
        bleed_out_at = ?, doctor_available_at = ?, revision = ?, updated_at = ? WHERE character_id = ?]],
        record.lifeState, record.episodeId, record.openedAt, record.bleedOutAt,
        record.doctorAvailableAt, record.revision, record.updatedAt, record.characterId)
    tx.insert([[INSERT INTO fm_transition_outbox
        (event_id, character_id, episode_id, revision, payload, created_at) VALUES (?, ?, ?, ?, ?, ?)]],
        eventId, record.characterId, episodeId, record.revision,
        json.encode({eventId = eventId, characterId = record.characterId, episodeId = episodeId,
            lifeState = record.lifeState, revision = record.revision, reason = reason, occurredAt = now}), now)
end

function R.ResetOnActivation(characterId, now, eventId, isCurrent)
    local result
    DB.transaction(function(tx)
        local record = decode(tx.one('SELECT * FROM fm_condition WHERE character_id = ? FOR UPDATE', characterId))
        assert(record, 'Medical condition missing')
        if isCurrent then assert(isCurrent(), 'Stale activation') end
        result = record
        if record.lifeState ~= 'alive' then
            result = assert(MedicalLifecycle.CompleteRecovery(record, record.episodeId, now))
            tx.exec("UPDATE fm_episodes SET state = 'closed', closed_at = ?, revision = revision + 1 WHERE episode_id = ?", now, record.episodeId)
            tx.exec("UPDATE fm_recovery_operations SET status = 'cancelled', revision = revision + 1 WHERE episode_id = ? AND status = 'pending'", record.episodeId)
            persist(tx, result, eventId, 'nonpersistent_activation_reset', now, record.episodeId)
        end
        if isCurrent then assert(isCurrent(), 'Stale activation') end
        return true
    end)
    return result
end

function R.CompleteStaffRecovery(characterId, operationId, now, eventId, isCurrent)
    local result
    DB.transaction(function(tx)
        result = nil
        local record = decode(tx.one('SELECT * FROM fm_condition WHERE character_id = ? FOR UPDATE', characterId))
        if not record then result = {ok = false, code = 'condition_missing'}; return false end
        if not isCurrent() then result = {ok = false, code = 'stale_session'}; return false end
        local operation = tx.one('SELECT * FROM fm_recovery_operations WHERE operation_id = ? AND character_id = ? FOR UPDATE', operationId, characterId)
        if not operation then result = {ok = false, code = 'operation_missing'}; return false end
        if operation.status == 'completed' then
            if record.lifeState ~= 'alive' then result = {ok = false, code = 'stale_episode'}; return false end
            result = {ok = true, value = record}; return true
        end
        if operation.status ~= 'pending' then result = {ok = false, code = 'recovery_conflict'}; return false end
        local nextRecord, reason = MedicalLifecycle.CompleteRecovery(record, operation.episode_id, now)
        if not nextRecord then result = {ok = false, code = reason}; return false end
        tx.exec("UPDATE fm_episodes SET state = 'closed', closed_at = ?, revision = revision + 1 WHERE episode_id = ?", now, record.episodeId)
        tx.exec("UPDATE fm_recovery_operations SET status = 'completed', completed_at = ?, revision = revision + 1 WHERE operation_id = ?", now, operationId)
        persist(tx, nextRecord, eventId, operation.recovery_kind == 'doctor' and 'doctor_recovered' or 'staff_recovered', now, record.episodeId)
        result = {ok = true, value = nextRecord}
        if not isCurrent() then result = {ok = false, code = 'stale_session'}; return false end
        return true
    end)
    return result
end

-- IDs and time are generated once outside the retryable transaction. All writes
-- use tx.*; no network/event side effects occur before commit. Repeated reports
-- of the same active episode do not reset its deadline or append transitions.
function R.ObserveLethal(characterId, config, now, episodeId, eventId, isCurrent, expectedRevision)
    local result
    DB.transaction(function(tx)
        result = nil
        local record = decode(tx.one('SELECT * FROM fm_condition WHERE character_id = ? FOR UPDATE', characterId))
        if not record then result = {ok = false, code = 'condition_missing'}; return false end
        if not isCurrent() then result = {ok = false, code = 'stale_session'}; return false end
        if expectedRevision ~= nil and record.revision ~= expectedRevision then result = {ok = false, code = 'revision_conflict'}; return false end
        local nextRecord, reason = MedicalLifecycle.ObserveLethal(record, config, now, episodeId)
        if not nextRecord then result = {ok = false, code = reason}; return false end
        if reason == 'transitioned' then
            tx.insert([[INSERT INTO fm_episodes
                (episode_id, character_id, state, provenance, opened_at, revision)
                VALUES (?, ?, ?, 'client_observation', ?, 0)]], episodeId, characterId, nextRecord.lifeState, now)
            persist(tx, nextRecord, eventId, reason, now)
        end
        result = {ok = true, value = nextRecord}
        if not isCurrent() then result = {ok = false, code = 'stale_session'}; return false end
        return true
    end)
    return result
end

function R.Advance(characterId, now, eventId)
    local result
    DB.transaction(function(tx)
        result = nil
        local record = decode(tx.one('SELECT * FROM fm_condition WHERE character_id = ? FOR UPDATE', characterId))
        if not record then return false end
        local nextRecord, reason = MedicalLifecycle.Advance(record, now)
        if reason == 'bled_out' then
            tx.exec("UPDATE fm_episodes SET state = 'dead', revision = revision + 1 WHERE episode_id = ? AND state = 'incapacitated'", record.episodeId)
            persist(tx, nextRecord, eventId, reason, now)
        end
        result = nextRecord
        return true
    end)
    return result
end

function R.Due(now)
    return DB.query([[SELECT character_id FROM fm_condition
        WHERE life_state = 'incapacitated' AND bleed_out_at <= ? ORDER BY bleed_out_at LIMIT 100]], now)
end

function R.PendingEvents()
    -- Only the oldest unpublished revision per character is eligible. This
    -- preserves order even after a UTC clock correction and stops one character's
    -- failing backlog from filling every slot in the bounded batch.
    return DB.query([[SELECT e.event_id, e.character_id, e.revision, e.payload
        FROM fm_transition_outbox e WHERE e.published_at IS NULL AND NOT EXISTS (
            SELECT 1 FROM fm_transition_outbox older WHERE older.character_id = e.character_id
                AND older.revision < e.revision AND older.published_at IS NULL
        ) ORDER BY e.created_at, e.character_id, e.revision LIMIT 100]])
end

function R.MarkPublished(eventId, now)
    DB.exec('UPDATE fm_transition_outbox SET published_at = ? WHERE event_id = ? AND published_at IS NULL', now, eventId)
end
