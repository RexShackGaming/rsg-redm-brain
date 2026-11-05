local count = 0
local function check(label, good) assert(good, label); count = count + 1; print('PASS ' .. label) end
local function clone(t)
    if not t then return nil end
    local value = {}; for k, v in pairs(t) do value[k] = v end; return value
end
local row, operation, outbox, closed, failOutbox
local loseCommitReply = false
local function reset()
    row = {character_id = 'character', life_state = 'dead', active_episode_id = 'episode',
        opened_at = 1000, doctor_available_at = 1120, revision = 1, updated_at = 1000}
    operation, outbox, closed, failOutbox = nil, 0, false, false
end
reset()
json = {encode = function(value) return value.reason or 'destination-json' end}
local tx = {}
function tx.one(sql, id)
    if sql:find('fm_condition', 1, true) then return clone(row) end
    if sql:find('fm_recovery_operations', 1, true) then
        if operation and (id == operation.operation_id or id == operation.episode_id) then return clone(operation) end
    end
end
function tx.insert(sql, id, episode, character, kind, actor, now)
    if sql:find('fm_recovery_operations', 1, true) then
        operation = {operation_id = id, episode_id = episode, character_id = character,
            recovery_kind = kind, requested_by = actor, created_at = now, status = 'pending'}
    elseif sql:find('fm_transition_outbox', 1, true) then
        if failOutbox then error('outbox failure') end
        outbox = outbox + 1
    end
end
function tx.exec(sql, ...)
    local args = {...}
    if sql:find('UPDATE fm_condition', 1, true) then
        row.life_state, row.active_episode_id, row.opened_at, row.bleed_out_at = args[1], args[2], args[3], args[4]
        row.doctor_available_at, row.revision, row.updated_at = args[5], args[6], args[7]
    elseif sql:find('destination_snapshot', 1, true) then operation.destination_snapshot = args[1]
    elseif sql:find('fm_episodes', 1, true) then closed = true
    elseif sql:find("status = 'completed'", 1, true) then operation.status = 'completed'
    elseif sql:find("status = 'cancelled'", 1, true) and operation then operation.status = 'cancelled' end
end
DB = {}
function DB.transaction(callback)
    local before, beforeOp, beforeOutbox, beforeClosed = clone(row), clone(operation), outbox, closed
    local ok, commit = pcall(callback, tx)
    if not ok or commit ~= true then row, operation, outbox, closed = before, beforeOp, beforeOutbox, beforeClosed end
    if not ok then error(commit) end
    if loseCommitReply and commit == true then loseCommitReply = false; error('unknown outcome after committed transaction') end
    return commit == true
end
dofile('server/repository.lua')
local R = MedicalRepository
local current = function() return true end
local early = R.BeginRecovery('character', 'character', 1119, 'op', current, 'doctor', {x = 1})
check('doctor rejected before server deadline', early.code == 'doctor_not_available' and not operation)
local created = R.BeginRecovery('character', 'character', 1120, 'op', current, 'doctor', {x = 1})
check('doctor operation captures destination after deadline', created.ok and operation.recovery_kind == 'doctor' and operation.destination_snapshot == 'destination-json' and row.life_state == 'dead')
local repeatOp = R.BeginRecovery('character', 'character', 1121, 'other-op', current, 'doctor', {x = 9})
check('duplicate recovery retains operation destination', repeatOp.value.operationId == 'op' and operation.destination_snapshot == 'destination-json')
local stale = R.CompleteStaffRecovery('character', 'op', 1122, 'event', function() return false end)
check('stale acknowledgement cannot revive', stale.code == 'stale_session' and row.life_state == 'dead')
failOutbox = true
check('failed recovery fact rolls back all state', not pcall(R.CompleteStaffRecovery, 'character', 'op', 1122, 'event', current)
    and row.life_state == 'dead' and operation.status == 'pending' and not closed)
failOutbox = false
local recovered = R.CompleteStaffRecovery('character', 'op', 1122, 'event', current)
check('recovery atomically closes episode and operation', recovered.ok and row.life_state == 'alive' and operation.status == 'completed' and closed and outbox == 1)
local again = R.CompleteStaffRecovery('character', 'op', 1123, 'new-event', current)
check('duplicate ack produces no additional transition', again.ok and outbox == 1 and row.revision == 2)
reset()
R.BeginStaffRecovery('character', 'staff-character', 1010, 'staff-op', current)
local guardCalls = 0
local changed = R.CompleteStaffRecovery('character', 'staff-op', 1011, 'event', function() guardCalls = guardCalls + 1; return guardCalls == 1 end)
check('session change during writes rolls back recovery', changed.code == 'stale_session' and row.life_state == 'dead' and operation.status == 'pending' and outbox == 0)
R.ResetOnActivation('character', 1020, 'reset-event')
check('nonpersistent activation closes episode and cancels delivery', row.life_state == 'alive' and operation.status == 'cancelled' and outbox == 1)
R.ResetOnActivation('character', 1021, 'other-event')
check('repeat activation reset produces no extra transition', outbox == 1 and row.revision == 2)
reset()
loseCommitReply = true
check('lost begin reply raises while keeping committed operation', not pcall(R.BeginStaffRecovery, 'character', 'staff', 1010, 'stable-op', current) and operation.operation_id == 'stable-op')
local resumed = R.BeginStaffRecovery('character', 'staff', 1011, 'different-op', current)
check('begin retry reconciles existing operation', resumed.ok and resumed.value.operationId == 'stable-op')
loseCommitReply = true
check('lost completion reply retains committed alive state', not pcall(R.CompleteStaffRecovery, 'character', 'stable-op', 1012, 'stable-event', current)
    and row.life_state == 'alive' and operation.status == 'completed')
local reconciled = R.CompleteStaffRecovery('character', 'stable-op', 1013, 'new-event', current)
check('completion retry cannot duplicate fact', reconciled.ok and outbox == 1)
row.life_state, row.active_episode_id, row.opened_at, row.doctor_available_at = 'dead', 'new-episode', 2000, 2120
check('completed old operation cannot complete a new episode', R.CompleteStaffRecovery('character', 'stable-op', 2001, 'new-event', current).code == 'stale_episode' and row.life_state == 'dead')
print(('PASS %d recovery harness checks'):format(count))
