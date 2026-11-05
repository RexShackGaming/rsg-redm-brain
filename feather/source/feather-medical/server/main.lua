local health = {state = 'starting', phase = 'database', contract = 1, playableLifecycle = false}
MedicalGameplay.Ready = function() return health.state == 'ready' end

exports('GetHealth', function()
    return {state = health.state, phase = health.phase, contract = 1, enabled = Config.medical.enabled, playableLifecycle = health.state == 'ready' and Config.medical.enabled,
        stagingIntegration = Config.medical.enabled, persistentDeath = Config.medical.persistentDeath}
end)

local startupGeneration = 0
local function start()
    startupGeneration = startupGeneration + 1
    local generation = startupGeneration
    health.state, health.phase = 'starting', 'database'
    CreateThread(function()
    local ok, err = pcall(function()
        DB.awaitReady()
        assert(generation == startupGeneration, 'Core lifecycle changed while waiting for database')
        if Config.medical.enabled then
            local valid, reason = MedicalLifecycle.ValidateConfig(Config.medical)
            assert(valid, reason)
        end
        health.phase = 'migration'
        MedicalMigration.Run()
        local validHospitals, hospitalError = MedicalHospitals.Validate(Config.hospitals)
        assert(validHospitals, hospitalError)
        if Config.medical.enabled and not MedicalHospitals.HasEnabled(Config.hospitals) then
            print(Config.medical.temporarySpawnEnabled and '[feather-medical] no hospitals enabled; using temporary Character spawn'
                or '[feather-medical] no hospitals enabled; player respawn unavailable until configured')
        end
        assert(generation == startupGeneration, 'Core lifecycle changed during startup')
        health.phase = 'routes'
        local declared = exports['feather-core']:DeclareEvent(MedicalOutbox.event, {
            contract = 1, maxPayloadBytes = 2048, maxDepth = 4, maxNodes = 32,
            validatePayload = function(payload) return MedicalOutbox.Validate(payload), 'Invalid Medical transition.' end
        })
        assert(type(declared) == 'table' and declared.ok, 'Medical event declaration failed')
        local registered = exports['feather-core']:RegisterRpc('medical.condition.get.v1', function(_, source, context)
            if health.state ~= 'ready' then return {ok = false, code = 'unavailable'} end
            if type(context) ~= 'table' or type(context.characterId) ~= 'string' or type(context.sessionId) ~= 'string' then
                return {ok = false, code = 'session_required'}
            end
            local called, record = pcall(MedicalRepository.Get, context.characterId)
            if not called then return {ok = false, code = 'storage_unavailable'} end
            if exports['feather-core']:IsSessionCurrent(source, context.sessionId, context.characterId) ~= true then
                return {ok = false, code = 'stale_session'}
            end
            if not record then return {ok = false, code = 'condition_missing'} end
            if Config.medical.enabled and not MedicalGameplay.IsCurrent(source, context) then return {ok = false, code = 'not_ready'} end
            return {ok = true, value = MedicalGameplay.Snapshot(record, context)}
        end, {contract = 1, direction = 'client_to_server', requireCharacter = true,
            windowMs = 5000, maxCalls = 8, maxPayloadBytes = 64, maxDepth = 2, maxNodes = 4,
            validatePayload = function(payload)
                return type(payload) == 'table' and next(payload) == nil, 'No payload fields accepted.'
            end})
        assert(type(registered) == 'table' and registered.ok == true, 'Medical snapshot registration failed')
        local function route(name, fn, validator)
            local result = exports['feather-core']:RegisterRpc(name, function(payload, source, context)
                if health.state ~= 'ready' or not Config.medical.enabled then return {ok = false, code = 'medical_unavailable'} end
                local ok, value = pcall(fn, source, context, payload)
                return ok and value or {ok = false, code = 'storage_unavailable'}
            end, {contract = 1, direction = 'client_to_server', requireCharacter = true,
                windowMs = 5000, maxCalls = 8, maxPayloadBytes = 256, maxDepth = 2, maxNodes = 8,
                validatePayload = validator})
            assert(type(result) == 'table' and result.ok, 'Medical route registration failed: ' .. name)
        end
        local function empty(payload) return type(payload) == 'table' and next(payload) == nil, 'Empty payload required.' end
        route('medical.observation.lethal.v1', function(source, context, payload)
            return MedicalGameplay.Observe(source, context, payload.expectedRevision)
        end, function(payload)
            if type(payload) ~= 'table' or type(payload.expectedRevision) ~= 'number'
                or payload.expectedRevision < 0 or payload.expectedRevision % 1 ~= 0 then return false, 'Expected revision required.' end
            for key in pairs(payload) do if key ~= 'expectedRevision' then return false, 'Only expectedRevision accepted.' end end
            return true
        end)
        route('medical.recovery.pending.v1', function(source, context) return MedicalGameplay.Pending(source, context) end, empty)
        route('medical.recovery.doctor.request.v1', function(source, context) return MedicalGameplay.RequestDoctor(source, context) end, empty)
        route('medical.recovery.ack.v1', function(source, context, payload)
            return MedicalGameplay.Acknowledge(source, context, payload.operationId, payload.deliveryToken)
        end, function(payload)
            if type(payload) ~= 'table' or type(payload.operationId) ~= 'string' or #payload.operationId ~= 36 then return false, 'Operation UUID required.' end
            if type(payload.deliveryToken) ~= 'string' or #payload.deliveryToken ~= 36 then return false, 'Delivery token required.' end
            for key in pairs(payload) do if key ~= 'operationId' and key ~= 'deliveryToken' then return false, 'Only operationId and deliveryToken accepted.' end end
            return true
        end)
        assert(generation == startupGeneration, 'Core lifecycle changed during registration')
        health.state, health.phase = 'ready', 'lifecycle'
        print(Config.medical.enabled and '[feather-medical] storage ready; gameplay staging enabled (live acceptance pending)'
            or '[feather-medical] storage foundation ready; gameplay integration disabled')
    end)
    if not ok and generation == startupGeneration then
        health.state = 'failed'
        print('[feather-medical] startup failed: ' .. tostring(err))
    end
    end)
end
start()

RegisterCommand('MedicalHealth', function(source)
    if source ~= 0 then return end
    CreateThread(function()
        local result = {state = health.state, phase = health.phase, enabled = Config.medical.enabled,
            persistentDeath = Config.medical.persistentDeath, lethalMode = Config.medical.lethalMode,
            hospitalCount = #Config.hospitals, temporarySpawnEnabled = Config.medical.temporarySpawnEnabled}
        local ok, pending = pcall(DB.value, 'SELECT COUNT(*) FROM fm_transition_outbox WHERE published_at IS NULL')
        result.pendingTransitions = ok and tonumber(pending) or 'storage_unavailable'
        print('[MedicalHealth] ' .. json.encode(result))
    end)
end, true)

AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-core' then
        startupGeneration = startupGeneration + 1
        health.state, health.phase = 'waiting', 'core_stopped'
    end
end)
AddEventHandler('onResourceStart', function(resource)
    if resource == 'feather-core' then start() end
end)

CreateThread(function()
    local lastWarning = 0
    while true do
        if health.state == 'ready' then
            local ok, result = pcall(MedicalOutbox.Tick, MedicalRepository, function(name, payload)
                return exports['feather-core']:PublishEvent(name, payload)
            end, json.decode, os.time())
            if (not ok or result.failures > 0) and os.time() - lastWarning >= 30 then
                lastWarning = os.time()
                print('[feather-medical] transition publication pending; retrying durable event IDs')
            end
        end
        Wait(1000)
    end
end)

-- Server-console-only acceptance check against disposable Medical-owned rows.
CreateThread(function()
    local lastWarning = 0
    while true do
        if health.state == 'ready' then
            local ok, result = pcall(MedicalWorker.Tick, os.time(), MedicalRepository,
                function() return DB.value('SELECT UUID()') end)
            if (not ok or result.failures > 0) and os.time() - lastWarning >= 30 then
                lastWarning = os.time()
                print('[feather-medical] bleedout worker unavailable or a condition failed validation; retrying from stored state')
            end
        end
        Wait(1000)
    end
end)

-- Does not touch player characters, existing episodes, Core or Character state.
RegisterCommand('MedicalStorageSmokeTest', function(source)
    if source ~= 0 then return end
    if health.state ~= 'ready' then print('[MedicalStorageSmokeTest] FAIL Medical is not ready'); return end
    CreateThread(function()
        local characterId
        local passed = 0
        local function check(label, condition)
            assert(condition, label)
            passed = passed + 1
            print('[MedicalStorageSmokeTest] PASS ' .. label)
        end
        local ok, err = pcall(function()
            characterId = 'smoke:' .. DB.value('SELECT UUID()')
            local episodeId = DB.value('SELECT UUID()')
            local now = os.time()
            local config = {lethalMode = 'incapacitated', bleedOutSeconds = 60, doctorDelaySeconds = 120}
            check('provision alive', MedicalRepository.Initialize(characterId, now).lifeState == 'alive')
            check('missing condition is not alive', MedicalRepository.Get('missing:' .. characterId) == nil)
            local stale = MedicalRepository.ObserveLethal(characterId, config, now, episodeId,
                DB.value('SELECT UUID()'), function() return false end)
            check('stale session rejected', stale.code == 'stale_session' and MedicalRepository.Get(characterId).revision == 0)
            local result = MedicalRepository.ObserveLethal(characterId, config, now, episodeId,
                DB.value('SELECT UUID()'), function() return true end)
            check('episode committed', result.ok and MedicalRepository.Get(characterId).episodeId == episodeId)
            local repeatResult = MedicalRepository.ObserveLethal(characterId, config, now + 10,
                DB.value('SELECT UUID()'), DB.value('SELECT UUID()'), function() return true end)
            check('duplicate preserves deadline', repeatResult.ok and repeatResult.value.bleedOutAt == now + 60 and repeatResult.value.revision == 1)
            check('episode/outbox atomic facts', tonumber(DB.value('SELECT COUNT(*) FROM fm_episodes WHERE character_id = ?', characterId)) == 1
                and tonumber(DB.value('SELECT COUNT(*) FROM fm_transition_outbox WHERE character_id = ?', characterId)) == 1)
            DB.transaction(function(tx)
                tx.exec("UPDATE fm_condition SET life_state = 'dead' WHERE character_id = ?", characterId)
                return false
            end)
            check('explicit rollback preserved condition', MedicalRepository.Get(characterId).lifeState == 'incapacitated')
            local dead = MedicalRepository.Advance(characterId, now + 61, DB.value('SELECT UUID()'))
            check('elapsed deadline persisted', dead.lifeState == 'dead' and MedicalRepository.Get(characterId).revision == 2)
            check('bleedout outbox written', tonumber(DB.value('SELECT COUNT(*) FROM fm_transition_outbox WHERE character_id = ?', characterId)) == 2)
            check('doctor unlock never auto-revives', MedicalLifecycle.CanRequestDoctor(dead, now + 121)
                and MedicalRepository.Advance(characterId, now + 121, DB.value('SELECT UUID()')).lifeState == 'dead')
        end)
        local cleaned, cleanupError = pcall(function()
            if not characterId then return end
            DB.transaction(function(tx)
                for _, name in ipairs({'fm_transition_outbox', 'fm_recovery_operations', 'fm_episodes', 'fm_condition'}) do
                    tx.exec('DELETE FROM ' .. name .. ' WHERE character_id = ?', characterId)
                end
                return true
            end)
        end)
        if not cleaned then print('[MedicalStorageSmokeTest] CLEANUP FAILED ' .. tostring(cleanupError) .. ' character=' .. tostring(characterId)) end
        if not ok then print('[MedicalStorageSmokeTest] FAIL ' .. tostring(err)) end
        print(('[MedicalStorageSmokeTest] done %d/10 passed; cleanup=%s'):format(passed, cleaned and 'ok' or 'failed'))
    end)
end, true)
