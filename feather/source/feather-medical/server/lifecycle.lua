-- Pure server domain. Callers supply server time and server-generated IDs.
MedicalLifecycle = {}
local M = MedicalLifecycle

local function copy(record)
    local result = {}
    for key, value in pairs(record) do result[key] = value end
    return result
end

function M.ValidateConfig(config)
    if type(config) ~= 'table' or (config.lethalMode ~= 'dead' and config.lethalMode ~= 'incapacitated') then
        return false, 'invalid_lethal_mode'
    end
    for _, key in ipairs({'bleedOutSeconds', 'doctorDelaySeconds'}) do
        local value = config[key]
        if type(value) ~= 'number' or value ~= value or value < 0 or value > 604800 or value % 1 ~= 0 then
            return false, 'invalid_' .. key
        end
    end
    if config.lethalMode == 'incapacitated' and config.bleedOutSeconds == 0 then
        return false, 'invalid_bleedOutSeconds'
    end
    return true
end

function M.New(characterId, now)
    assert(type(characterId) == 'string' and #characterId > 0, 'character ID required')
    return {characterId = characterId, lifeState = 'alive', revision = 0, updatedAt = now}
end

function M.ObserveLethal(record, config, now, episodeId)
    local valid, reason = M.ValidateConfig(config)
    if not valid then return nil, reason end
    if record.lifeState ~= 'alive' then return copy(record), 'already_in_episode' end
    assert(type(episodeId) == 'string' and #episodeId > 0, 'server episode ID required')
    local nextRecord = copy(record)
    nextRecord.lifeState = config.lethalMode
    nextRecord.episodeId = episodeId
    nextRecord.openedAt = now
    nextRecord.doctorAvailableAt = now + config.doctorDelaySeconds
    nextRecord.bleedOutAt = config.lethalMode == 'incapacitated' and now + config.bleedOutSeconds or nil
    nextRecord.revision = record.revision + 1
    nextRecord.updatedAt = now
    return nextRecord, 'transitioned'
end

function M.Advance(record, now)
    local nextRecord = copy(record)
    if record.lifeState == 'incapacitated' and record.bleedOutAt and now >= record.bleedOutAt then
        nextRecord.lifeState = 'dead'
        nextRecord.bleedOutAt = nil
        nextRecord.revision = record.revision + 1
        nextRecord.updatedAt = now
        return nextRecord, 'bled_out'
    end
    return nextRecord, 'unchanged'
end

-- Eligibility only: neither this function nor a client alive report revives anyone.
function M.CanRequestDoctor(record, now)
    return (record.lifeState == 'dead' or record.lifeState == 'incapacitated')
        and record.doctorAvailableAt ~= nil and now >= record.doctorAvailableAt
end

-- Only a committed, authorized recovery operation may reach this function.
-- The repository must lock/check revision and persist both records atomically.
function M.CompleteRecovery(record, episodeId, now)
    if record.lifeState == 'alive' or record.episodeId ~= episodeId then
        return nil, 'stale_episode'
    end
    return {characterId = record.characterId, lifeState = 'alive', revision = record.revision + 1,
        updatedAt = now}, 'recovered'
end

return M
