local characterId = 'smoke:recovery:v1'
local busy = false
local function cleanup()
    DB.transaction(function(tx)
        for _, name in ipairs({'fm_transition_outbox','fm_recovery_operations','fm_episodes','fm_condition'}) do
            tx.exec('DELETE FROM ' .. name .. ' WHERE character_id = ?', characterId)
        end
        return true
    end)
end

RegisterCommand('MedicalRecoverySmokeTest', function(source, args)
    if source ~= 0 or busy then return end
    local action = args and args[1]
    if action ~= 'seed' and action ~= 'check' and action ~= 'cleanup' then
        print('[MedicalRecoverySmokeTest] usage: seed | check | cleanup'); return
    end
    if not MedicalGameplay.Ready() then print('[MedicalRecoverySmokeTest] FAIL Medical not ready'); return end
    busy = true
    CreateThread(function()
        local ok, failure = pcall(function()
            if action == 'cleanup' then cleanup(); print('[MedicalRecoverySmokeTest] cleanup=ok'); return end
            local function uuid() return DB.value('SELECT UUID()') end
            if action == 'seed' then
                assert(not MedicalRepository.Get(characterId), 'Prior test retained; run check or cleanup')
                local destination = exports['feather-character']:GetMedicalRecoveryDestination()
                assert(type(destination) == 'table' and destination.ok, 'Character temporary destination unavailable')
                local now = os.time()
                MedicalRepository.Initialize(characterId, now)
                assert(MedicalRepository.ObserveLethal(characterId, {lethalMode = 'dead', bleedOutSeconds = 0, doctorDelaySeconds = 0},
                    now, uuid(), uuid(), function() return true end).ok)
                assert(MedicalRepository.BeginRecovery(characterId, 'console:smoke', now, uuid(),
                    function() return true end, 'doctor', destination.value).ok)
                print('[MedicalRecoverySmokeTest] seed=ok; restart feather-medical, then MedicalRecoverySmokeTest check; no player needed')
                return
            end
            local count = 0
            local function check(label, good) assert(good, label); count = count + 1; print('[MedicalRecoverySmokeTest] PASS ' .. label) end
            local operation = MedicalRepository.PendingRecovery(characterId)
            check('pending operation survives restart', operation and operation.status == 'pending')
            local captured = json.decode(operation.destination_snapshot)
            check('destination snapshot survives restart', type(captured) == 'table' and type(captured.x) == 'number' and type(captured.id) == 'string')
            local repeated = MedicalRepository.BeginRecovery(characterId, 'console:smoke', os.time(), uuid(),
                function() return true end, 'doctor', {id = 'replacement-test', x = 0, y = 0, z = 0, heading = 0})
            check('retry keeps original operation and destination', repeated.ok and repeated.value.operationId == operation.operation_id
                and MedicalRepository.PendingRecovery(characterId).destination_snapshot == operation.destination_snapshot)
            local stale = MedicalRepository.CompleteStaffRecovery(characterId, operation.operation_id, os.time(), uuid(), function() return false end)
            check('stale completion leaves character dead', stale.code == 'stale_session' and MedicalRepository.Get(characterId).lifeState == 'dead')
            local completed = MedicalRepository.CompleteStaffRecovery(characterId, operation.operation_id, os.time(), uuid(), function() return true end)
            check('current completion commits recovery', completed.ok and completed.value.lifeState == 'alive' and MedicalRepository.PendingRecovery(characterId) == nil)
            local duplicate = MedicalRepository.CompleteStaffRecovery(characterId, operation.operation_id, os.time(), uuid(), function() return true end)
            check('duplicate completion creates no extra transition', duplicate.ok and MedicalRepository.Get(characterId).revision == 2
                and tonumber(DB.value('SELECT COUNT(*) FROM fm_transition_outbox WHERE character_id = ?', characterId)) == 2)
            cleanup()
            print(('[MedicalRecoverySmokeTest] done %d/6 passed; cleanup=ok'):format(count))
        end)
        busy = false
        if not ok then print('[MedicalRecoverySmokeTest] FAIL ' .. tostring(failure) .. '; test retained, retry check or cleanup') end
    end)
end, true)
