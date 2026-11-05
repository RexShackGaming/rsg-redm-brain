-- Client adapter for persisted medical.condition.get.v1 / recovery.ack.v1
-- snapshots. Medical remains the sole condition authority.
MedicalClientLifecycle = {}
local condition
local function context()
    if GetResourceState('feather-character') ~= 'started' then return nil end
    return exports['feather-character']:GetMedicalContext()
end
local function copy(value)
    return {characterId = value.characterId, sessionId = value.sessionId,
        lifeState = value.lifeState, revision = value.revision, episodeId = value.episodeId}
end
function MedicalClientLifecycle.Publish(snapshot, expected)
    local current = context()
    if not current or not expected or current.sessionId ~= expected.sessionId
        or current.characterId ~= expected.characterId then return {ok = false, code = 'stale_session'} end
    if type(snapshot) ~= 'table' or snapshot.characterId ~= current.characterId
        or snapshot.sessionId ~= current.sessionId or type(snapshot.revision) ~= 'number'
        or snapshot.revision < 0 or snapshot.revision % 1 ~= 0
        or (snapshot.lifeState ~= 'alive' and snapshot.lifeState ~= 'dead'
            and snapshot.lifeState ~= 'incapacitated') then return {ok = false, code = 'invalid_condition'} end
    if condition and condition.sessionId == current.sessionId and snapshot.revision < condition.revision then
        return {ok = false, code = 'stale_condition'}
    end
    local changed = not condition or condition.sessionId ~= current.sessionId
        or condition.lifeState ~= snapshot.lifeState or condition.revision ~= snapshot.revision
    condition = copy(snapshot)
    if changed then TriggerEvent('feather-medical:client:condition-changed.v1', copy(condition)) end
    return {ok = true}
end
exports('GetLifeState', function()
    local current = context()
    if not current then return {ok = false, code = 'no_character'} end
    if not condition or condition.sessionId ~= current.sessionId or condition.characterId ~= current.characterId then
        return {ok = false, code = 'condition_unavailable'}
    end
    return {ok = true, value = copy(condition)}
end)
