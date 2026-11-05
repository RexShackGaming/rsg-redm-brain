-- Helpers for the server-console tests. Tests run with nobody online: a target
-- is a character UUID, or the server id of a connected player whose active
-- character is used.
--
-- Development tests that need funds post supply through EconomyJournal as
-- feather-economy, below the Core policy gate: no server grants Economy itself
-- a supply policy. EconomyReleaseGateSmokeTest covers the policy gate.

EconomyTests = {}

local UUID = '^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'

function EconomyTests.IsUuid(value)
    return type(value) == 'string' and value:match(UUID) ~= nil
end

-- A request id the journal accepts as part of an idempotency key.
function EconomyTests.RequestId(value)
    return type(value) == 'string' and #value <= 96
        and value:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end

-- Returns characterId, source (nil for a UUID), or nil and the reason. Economy
-- cannot look characters up, so a UUID must already own Economy accounts:
-- Character provisions wallets when a character is first activated. This keeps
-- a mistyped or foreign UUID from getting wallets.
function EconomyTests.Character(argument)
    if EconomyTests.IsUuid(argument) then
        local characterId = argument:lower()
        local accounts = EconomyAccounts.FindByOwner('character', characterId)
        if not accounts.ok or #accounts.value == 0 then
            return nil, 'no Economy accounts for that UUID; pass a character that has been played'
        end
        return characterId, nil
    end
    local source = tonumber(argument)
    if not source or source < 1 or source % 1 ~= 0 then
        return nil, 'expected a character UUID or a server id'
    end
    local session = exports['feather-core']:GetSessionContext(source)
    if type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
        or not EconomyTests.IsUuid(session.value.characterId) then
        return nil, ('server id %d has no active character'):format(source)
    end
    return session.value.characterId:lower(), source
end

-- The character's wallet in one currency, provisioned if missing.
function EconomyTests.Wallet(characterId, currency)
    local wallets = EconomyAccounts.EnsureCharacterWallets(characterId)
    for _, account in ipairs(wallets.ok and wallets.value or {}) do
        if account.currency == (currency or 'dollars') then return account end
    end
end

function EconomyTests.Counter(name)
    local passed, total = 0, 0
    return function(label, condition)
        total = total + 1
        if condition then passed = passed + 1 end
        print(('[%s] %s %s'):format(name, label, condition and 'PASS' or 'FAIL'))
    end, function() return passed, total end
end
