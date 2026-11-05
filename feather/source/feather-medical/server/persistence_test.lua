-- Reserved non-UUID character key; never refers to a real Core character.
local characterId = 'smoke:persistence:v1'
local busy = false

local function cleanup()
    DB.transaction(function(tx)
        for _, name in ipairs({'fm_transition_outbox', 'fm_recovery_operations', 'fm_episodes', 'fm_condition'}) do
            tx.exec('DELETE FROM ' .. name .. ' WHERE character_id = ?', characterId)
        end
        return true
    end)
end

RegisterCommand('MedicalPersistenceSmokeTest', function(source, args)
    if source ~= 0 then return end
    local action = args and args[1]
    if action ~= 'seed' and action ~= 'check' and action ~= 'cleanup' then
        print('[MedicalPersistenceSmokeTest] usage: seed | check | cleanup'); return
    end
    if busy then print('[MedicalPersistenceSmokeTest] already running'); return end
    busy = true
    CreateThread(function()
        local ok, err = pcall(function()
            local status = exports[GetCurrentResourceName()]:GetHealth()
            assert(status.state == 'ready', 'Medical is not ready')
            if action == 'cleanup' then cleanup(); print('[MedicalPersistenceSmokeTest] cleanup=ok'); return end
            if action == 'seed' then
                assert(MedicalRepository.Get(characterId) == nil, 'Existing test retained; run check or cleanup first')
                local now = os.time()
                MedicalRepository.Initialize(characterId, now)
                local episodeId = DB.value('SELECT UUID()')
                local result = MedicalRepository.ObserveLethal(characterId,
                    {lethalMode = 'incapacitated', bleedOutSeconds = 15, doctorDelaySeconds = 15},
                    now, episodeId, DB.value('SELECT UUID()'), function() return true end)
                assert(result.ok and result.value.lifeState == 'incapacitated', 'Test seed failed')
                print('[MedicalPersistenceSmokeTest] seed=ok; stop Medical now, wait at least 20 seconds, ensure Medical, then run MedicalPersistenceSmokeTest check')
                return
            end
            local passed = 0
            local function check(label, condition)
                assert(condition, label)
                passed = passed + 1
                print('[MedicalPersistenceSmokeTest] PASS ' .. label)
            end
            local record = MedicalRepository.Get(characterId)
            check('condition survived resource stop', record ~= nil)
            check('saved deadline elapsed', os.time() >= record.openedAt + 15)
            -- Never call Advance: background worker must persist this transition.
            check('worker persisted offline bleedout', record.lifeState == 'dead' and record.bleedOutAt == nil and record.revision == 2)
            check('doctor deadline preserved', record.doctorAvailableAt == record.openedAt + 15)
            local episode = DB.one('SELECT * FROM fm_episodes WHERE episode_id = ? AND character_id = ?', record.episodeId, characterId)
            check('original episode retained', episode ~= nil and tonumber(episode.opened_at) == record.openedAt and episode.state == 'dead')
            check('one lethal and one bleedout fact', tonumber(DB.value('SELECT COUNT(*) FROM fm_transition_outbox WHERE character_id = ?', characterId)) == 2)
            check('doctor eligibility never auto-revives', MedicalLifecycle.CanRequestDoctor(record, os.time()) and MedicalRepository.Get(characterId).lifeState == 'dead')
            cleanup()
            print(('[MedicalPersistenceSmokeTest] done %d/7 passed; cleanup=ok'):format(passed))
        end)
        busy = false
        if not ok then
            print('[MedicalPersistenceSmokeTest] FAIL ' .. tostring(err) .. '; test rows retained, retry check or run cleanup')
        end
    end)
end, true)
