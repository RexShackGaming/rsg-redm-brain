-- Lets the client ask "do I currently have an active character?" on resource
-- start. Without this, a feather-hud restart mid-session has no way to catch
-- up: Feather:Character:Spawned only fires once, at the moment of spawning,
-- so a fresh Lua VM waiting on that event alone would stay hidden/stale
-- until the player actually respawns. `requireCharacter = true` below makes
-- Core's RPC layer itself reject the call with `character_required` before
-- our handler ever runs when there's no active session -- so simply being
-- allowed to answer is already the proof; no character data needs reading.
local installed, subscription = false, nil

CreateThread(function()
    local ready = exports['feather-core']:AwaitReady(30000)
    if type(ready) ~= 'table' or not ready.ok or installed then return end
    local economy = exports['feather-economy']:AwaitReady(30000)
    if type(economy) ~= 'table' or not economy.ok then print('[feather-hud] Economy readiness failed.'); return end
    local registered = exports['feather-core']:RegisterRpc('hud.state.get.v1', function(_, source, context)
        local session = exports['feather-core']:GetSessionContext(source)
        if not session.ok or not context or context.sessionId ~= session.value.sessionId then
            return { ok = false, code = 'session_expired', message = 'Active character required.' }
        end
        local found = exports['feather-economy']:FindAccountsByOwner({ ownerType = 'character', ownerId = session.value.characterId })
        if type(found) ~= 'table' or not found.ok then
            return { ok = false, code = 'economy_unavailable', message = 'Wallets unavailable.' }
        end
        local balances, minor, precision = {}, {}, {}
        for _, account in ipairs(found.value) do
            if account.accountType == 'wallet' and account.status == 'open'
                and (account.currency == 'dollars' or account.currency == 'gold') then
                local currency = exports['feather-economy']:GetCurrency(account.currency)
                if not currency.ok or type(account.balance) ~= 'number' then
                    return { ok = false, code = 'economy_unavailable', message = 'Currency unavailable.' }
                end
                balances[account.currency] = account.balance / (10 ^ currency.value.precision)
                minor[account.currency], precision[account.currency] = account.balance, currency.value.precision
            end
        end
        if not exports['feather-core']:IsSessionCurrent(source, session.value.sessionId, session.value.characterId) then
            return { ok = false, code = 'session_expired', message = 'Character changed.' }
        end
        if balances.dollars == nil or balances.gold == nil then
            return { ok = false, code = 'wallet_unavailable', message = 'Character wallets must exist.' }
        end
        return { ok = true, value = { cash = balances.dollars, gold = balances.gold,
            cashMinor = minor.dollars, goldMinor = minor.gold,
            cashPrecision = precision.dollars, goldPrecision = precision.gold } }
    end, {
        contract = 1,
        direction = 'client_to_server',
        requireCharacter = true,
        windowMs = 5000,
        maxCalls = 5,
        maxPayloadBytes = 64,
        maxDepth = 1,
        maxNodes = 1,
        validatePayload = function(payload) return type(payload) == 'table' and next(payload) == nil end
    })
    if type(registered) ~= 'table' or not registered.ok then print('[feather-hud] Route registration failed.'); return end
    local subscribed = exports['feather-core']:SubscribeEvent('economy.transaction.posted.v1', function()
        -- No ledger data is broadcast: clients refresh only their own wallets.
        TriggerClientEvent('feather-hud:wallets:invalidate', -1)
    end)
    if type(subscribed) == 'table' and subscribed.ok then subscription = subscribed.value.token
    else print('[feather-hud] Subscription unavailable; periodic refresh remains active.') end
    installed = true
end)

RegisterCommand('HudEconomyContractSmokeTest', function(source)
    if source ~= 0 then return end
    print(('[HudEconomyContractSmokeTest] snapshot route %s'):format(installed and 'PASS' or 'FAIL'))
    print(('[HudEconomyContractSmokeTest] transaction subscription %s'):format(subscription and 'PASS' or 'FAIL'))
    print(('[HudEconomyContractSmokeTest] done %d/2 passed (no funds moved)'):format((installed and 1 or 0) + (subscription and 1 or 0)))
end, true)
