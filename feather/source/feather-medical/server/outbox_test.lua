local busy = false
RegisterCommand('MedicalOutboxSmokeTest', function(source)
    if source ~= 0 or busy then return end
    if not MedicalGameplay.Ready() then print('[MedicalOutboxSmokeTest] FAIL Medical not ready'); return end
    busy = true
    CreateThread(function()
        local token, eventId
        local count, calls = 0, 0
        local ok, failure = pcall(function()
            eventId = DB.value('SELECT UUID()')
            local characterId = 'smoke:outbox:' .. eventId
            local subscribed = exports['feather-core']:SubscribeEvent(MedicalOutbox.event, function(payload)
                if payload.eventId ~= eventId then return end
                calls = calls + 1
                if calls == 1 then error('MedicalOutboxSmokeTest intentional first-delivery failure') end
            end)
            assert(type(subscribed) == 'table' and subscribed.ok, 'Subscribe failed')
            token = subscribed.value.token
            DB.insert([[INSERT INTO fm_transition_outbox
                (event_id, character_id, revision, payload, created_at) VALUES (?, ?, 1, ?, ?)]],
                eventId, characterId, json.encode({eventId = eventId, characterId = characterId,
                    revision = 1, lifeState = 'dead', reason = 'smoke_test', occurredAt = os.time()}), os.time())
            local timeout = GetGameTimer() + 12000
            local published
            repeat
                published = DB.one('SELECT published_at FROM fm_transition_outbox WHERE event_id = ?', eventId)
                if published and published.published_at then break end
                Wait(250)
            until GetGameTimer() >= timeout
            assert(calls >= 2, 'Worker did not retry failed listener')
            count = count + 1; print('[MedicalOutboxSmokeTest] PASS stable event ID replayed after listener failure')
            assert(published and published.published_at, 'Event publication not stored')
            count = count + 1; print('[MedicalOutboxSmokeTest] PASS successful publication acknowledged in storage')
        end)
        local cleaned, cleanupError = pcall(function()
            if token then
                local result = exports['feather-core']:UnsubscribeEvent(token)
                assert(type(result) == 'table' and result.ok, 'Unsubscribe failed')
            end
            if eventId then DB.exec('DELETE FROM fm_transition_outbox WHERE event_id = ?', eventId) end
        end)
        busy = false
        if not ok then print('[MedicalOutboxSmokeTest] FAIL ' .. tostring(failure)) end
        if not cleaned then print('[MedicalOutboxSmokeTest] CLEANUP FAILED ' .. tostring(cleanupError) .. ' event=' .. tostring(eventId)) end
        print(('[MedicalOutboxSmokeTest] done %d/2 passed; cleanup=%s'):format(count, cleaned and 'ok' or 'failed'))
    end)
end, true)
