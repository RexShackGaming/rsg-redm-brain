local checks = 0
local function check(label, good)
    assert(good, label)
    checks = checks + 1
    print('PASS ' .. label)
end
dofile('server/schema.lua')
dofile('server/migrate.lua')
local installed, executions, ledgerWrites = nil, 0, 0
DB = {
    value = function() return string.rep('a', 64) end,
    one = function() return installed end,
    exec = function() executions = executions + 1 end,
    insert = function(_, version, checksum) installed = {checksum = checksum}; ledgerWrites = ledgerWrites + 1 end
}
check('migration first run', MedicalMigration.Run() == true and executions == #MedicalSchema.statements + 1 and ledgerWrites == 1)
check('migration rerun skips DDL', MedicalMigration.Run() == false and executions == #MedicalSchema.statements + 2 and ledgerWrites == 1)
installed.checksum = string.rep('b', 64)
check('checksum drift rejected', not pcall(MedicalMigration.Run))
installed = nil
DB.exec = function() error('injected DDL failure') end
check('DDL failure does not record version', not pcall(MedicalMigration.Run) and installed == nil and ledgerWrites == 1)

dofile('server/repository.lua')
json = {encode = function() return '{}' end}
local row = {character_id = 'test', life_state = 'alive', revision = 0, updated_at = 1000}
local episodes, events = 0, 0
local failOutbox = false
local function clone(value)
    local result = {}; for key, item in pairs(value) do result[key] = item end; return result
end
local tx = {}
function tx.one() return clone(row) end
function tx.insert(sql)
    if sql:find('fm_episodes', 1, true) then episodes = episodes + 1
    elseif sql:find('fm_transition_outbox', 1, true) then
        if failOutbox then error('injected outbox failure') end
        events = events + 1
    end
end
function tx.exec(sql, state, episode, opened, bleed, doctor, revision, updated)
    if sql:find('UPDATE fm_condition', 1, true) then
        row = {character_id = 'test', life_state = state, active_episode_id = episode,
            opened_at = opened, bleed_out_at = bleed, doctor_available_at = doctor,
            revision = revision, updated_at = updated}
    end
end
DB = {one = function() return clone(row) end}
function DB.transaction(callback)
    local before, oldEpisodes, oldEvents = clone(row), episodes, events
    local ok, commit = pcall(callback, tx)
    if not ok or commit ~= true then row, episodes, events = before, oldEpisodes, oldEvents end
    if not ok then error(commit) end
    return commit == true
end
local config = {lethalMode = 'incapacitated', bleedOutSeconds = 60, doctorDelaySeconds = 120}
local stale = MedicalRepository.ObserveLethal('test', config, 1001, 'episode', 'event', function() return false end)
check('stale session produces no writes', stale.code == 'stale_session' and episodes == 0 and events == 0)
local late = MedicalRepository.ObserveLethal('test', config, 1001, 'episode', 'event', function() return true end, 99)
check('stale observation revision produces no writes', late.code == 'revision_conflict' and episodes == 0 and events == 0)
failOutbox = true
check('outbox failure rolls back condition and episode', not pcall(MedicalRepository.ObserveLethal,
    'test', config, 1001, 'episode', 'event', function() return true end) and row.life_state == 'alive' and episodes == 0)
failOutbox = false
local result = MedicalRepository.ObserveLethal('test', config, 1001, 'episode', 'event', function() return true end)
check('transaction stores condition episode and outbox', result.ok and row.life_state == 'incapacitated' and episodes == 1 and events == 1)
local duplicate = MedicalRepository.ObserveLethal('test', config, 1050, 'other', 'other', function() return true end)
check('duplicate produces no extra facts', duplicate.ok and episodes == 1 and events == 1 and row.bleed_out_at == 1061)
row.active_episode_id = nil
check('corrupt nonalive record fails closed', not pcall(MedicalRepository.Get, 'test'))
print(('PASS %d storage harness checks (mock database)'):format(checks))
