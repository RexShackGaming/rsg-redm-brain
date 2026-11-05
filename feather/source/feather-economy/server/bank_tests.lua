-- The gate and contract tests are read-only and stay available in the production
-- profile; only the live movement test needs Config.DevMode.

local function Counter(name)
    local passed, total = 0, 0
    return function(label, condition)
        total = total + 1
        if condition then passed = passed + 1 end
        print(('[%s] %s %s'):format(name, label, condition and 'PASS' or 'FAIL'))
    end, function() return passed, total end
end

-- Runs `body` with two test-only operators trusted and their reasons registered,
-- then restores the configuration and releases the registrations.
local OPERATOR, OTHER = 'economy-gate-operator', 'economy-gate-other'
local function WithTestOperators(body)
    local groups = { 'trustedBankTransactors', 'trustedTreasuryOperators', 'trustedTransactors' }
    local saved = {}
    for _, group in ipairs(groups) do
        Config.Access[group] = Config.Access[group] or {}
        saved[group] = { Config.Access[group][OPERATOR], Config.Access[group][OTHER] }
        Config.Access[group][OPERATOR] = true
    end
    Config.Access.trustedTreasuryOperators[OTHER] = true
    Config.OperatorSupply = Config.OperatorSupply or {}
    local savedSupply = Config.OperatorSupply[OPERATOR]
    Config.OperatorSupply[OPERATOR] = { ['gate.import'] = true, ['gate.funding'] = true }
    local called, failure = pcall(body)
    EconomyOperators.Unregister(OPERATOR)
    EconomyOperators.Unregister(OTHER)
    Config.OperatorSupply[OPERATOR] = savedSupply
    for _, group in ipairs(groups) do
        Config.Access[group][OPERATOR], Config.Access[group][OTHER] = saved[group][1], saved[group][2]
    end
    if not called then error(failure, 0) end
end

RegisterCommand('EconomyBankAccountGateSmokeTest', function(source)
    if source ~= 0 then return end
    local Check, Result = Counter('EconomyBankAccountGateSmokeTest')
    WithTestOperators(function()
        local owner = '11111111-1111-1111-1111-111111111111'
        local other = '22222222-2222-2222-2222-222222222222'
        local boundOrg = '33333333-3333-3333-3333-333333333333'
        local otherOrg = '44444444-4444-4444-4444-444444444444'
        local wallet = { account_type = 'wallet', owner_type = 'character', owner_id = owner }
        local bank = { account_type = 'bank', owner_type = 'character', owner_id = owner }
        local otherWallet = { account_type = 'wallet', owner_type = 'character', owner_id = other }
        local otherBank = { account_type = 'bank', owner_type = 'character', owner_id = other }
        local sink = { account_type = 'system_sink', owner_type = 'system' }
        local source = { account_type = 'system_source', owner_type = 'system' }
        local treasury = { account_type = 'treasury', owner_type = 'organization', owner_id = boundOrg }
        local otherTreasury = { account_type = 'treasury', owner_type = 'organization', owner_id = otherOrg }
        local unbound = { account_type = 'treasury', owner_type = 'organization', owner_id = owner }
        -- Stand-in for the binding table: boundOrg is operated by OPERATOR, otherOrg by OTHER.
        local bindings = { [boundOrg] = OPERATOR, [otherOrg] = OTHER }
        local database = { value = function(_, organizationId) return bindings[organizationId] end }
        local asOwner, asOther = { actorCharacterId = owner }, { actorCharacterId = other }
        local function allowed(operation, from, to, reason, resource, context)
            return EconomyJournal.AccountTypesAllowed(operation, from, to, { reasonCode = reason },
                resource or OPERATOR, context, database) == true
        end

        local registered = EconomyAPI.RegisterOperatedReasons({ reasons = {
            ['gate.deposit'] = 'actor_wallet_to_bank',
            ['gate.withdraw'] = 'bank_to_actor_wallet',
            ['gate.transfer'] = 'bank_to_bank',
            ['gate.fee'] = 'bank_to_sink',
            ['gate.pay_in'] = { 'actor_wallet_to_operated', 'bank_to_operated' },
            ['gate.pay_out'] = { 'operated_to_wallet', 'operated_to_bank' },
            ['gate.take'] = 'operated_to_actor_wallet',
            ['gate.tax'] = 'operated_to_sink',
            ['gate.import'] = 'issue_to_bank',
            ['gate.funding'] = 'issue_to_operated'
        } }, OPERATOR)
        Check('operator registers its reasons', registered.ok and registered.value.registered == 10)
        local replaced = EconomyAPI.RegisterOperatedReasons({ reasons = {
            ['gate.deposit'] = 'actor_wallet_to_bank', ['gate.withdraw'] = 'bank_to_actor_wallet',
            ['gate.transfer'] = 'bank_to_bank', ['gate.fee'] = 'bank_to_sink',
            ['gate.pay_in'] = { 'actor_wallet_to_operated', 'bank_to_operated' },
            ['gate.pay_out'] = { 'operated_to_wallet', 'operated_to_bank' },
            ['gate.take'] = 'operated_to_actor_wallet', ['gate.tax'] = 'operated_to_sink',
            ['gate.import'] = 'issue_to_bank', ['gate.funding'] = 'issue_to_operated'
        } }, OPERATOR)
        Check('re-registering replaces', replaced.ok and replaced.value.registered == 10)
        local conflict = EconomyAPI.RegisterOperatedReasons({ reasons = { ['gate.deposit'] = 'operated_to_sink' } }, OTHER)
        Check('another operator cannot take a code', not conflict.ok and conflict.code == 'reason_conflict')
        local otherOk = EconomyAPI.RegisterOperatedReasons({ reasons = { ['other.tax'] = 'operated_to_sink',
            ['other.pay_in'] = 'actor_wallet_to_operated', ['other.mint'] = 'issue_to_operated' } }, OTHER)
        Check('second operator registers own codes', otherOk.ok)
        local bankShape = EconomyAPI.RegisterOperatedReasons({ reasons = { ['other.fee'] = 'bank_to_sink' } }, OTHER)
        Check('treasury operator cannot use bank shapes', not bankShape.ok and bankShape.code == 'authorization_denied')
        Check('reserved prefix rejected', not EconomyAPI.RegisterOperatedReasons({ reasons = {
            ['shop.purchase'] = 'actor_wallet_to_operated' } }, OTHER).ok)
        Check('unknown shape rejected', not EconomyAPI.RegisterOperatedReasons({ reasons = {
            ['other.x'] = 'anything' } }, OTHER).ok)
        Check('untrusted resource cannot register', not EconomyAPI.RegisterOperatedReasons({ reasons = {
            ['x.y'] = 'operated_to_sink' } }, 'untrusted-resource').ok)
        Check('failed registration kept earlier codes', EconomyOperators.Registered(OTHER)['other.tax'] ~= nil)

        Check('deposit own wallet to own bank', allowed('transfer', wallet, bank, 'gate.deposit', nil, asOwner))
        Check('withdraw own bank to own wallet', allowed('transfer', bank, wallet, 'gate.withdraw', nil, asOwner))
        Check('joint holder deposits from own wallet', allowed('transfer', otherWallet, bank, 'gate.deposit', nil, asOther))
        Check('deposit without actor uses same-owner rule', allowed('transfer', wallet, bank, 'gate.deposit'))
        Check('deposit from another wallet rejected', not allowed('transfer', otherWallet, bank, 'gate.deposit', nil, asOwner))
        Check('withdraw to another wallet rejected', not allowed('transfer', bank, otherWallet, 'gate.withdraw', nil, asOwner))
        Check('joint without actor rejected', not allowed('transfer', otherWallet, bank, 'gate.deposit'))
        Check('bank to bank transfer', allowed('transfer', bank, otherBank, 'gate.transfer'))
        Check('bank transfer cannot reach a wallet', not allowed('transfer', bank, otherWallet, 'gate.transfer'))
        Check('fee to system sink', allowed('transfer', bank, sink, 'gate.fee'))
        Check('fee cannot target a wallet', not allowed('transfer', bank, wallet, 'gate.fee'))
        Check('wrong reason for the shape rejected', not allowed('transfer', wallet, bank, 'gate.withdraw', nil, asOwner))
        Check('unregistered reason rejected', not allowed('transfer', wallet, bank, 'gate.unknown', nil, asOwner))
        Check('another resource cannot use the codes', not allowed('transfer', wallet, bank, 'gate.deposit', OTHER, asOwner))

        Check('pay in from actor wallet', allowed('transfer', wallet, treasury, 'gate.pay_in', nil, asOwner))
        Check('pay in from a bank account', allowed('transfer', bank, treasury, 'gate.pay_in'))
        Check('pay in from another wallet rejected', not allowed('transfer', otherWallet, treasury, 'gate.pay_in', nil, asOwner))
        Check('pay out to any wallet', allowed('transfer', treasury, otherWallet, 'gate.pay_out'))
        Check('pay out to a bank account', allowed('transfer', treasury, otherBank, 'gate.pay_out'))
        Check('take only to actor wallet', allowed('transfer', treasury, wallet, 'gate.take', nil, asOwner)
            and not allowed('transfer', treasury, otherWallet, 'gate.take', nil, asOwner))
        Check('tax to system sink', allowed('transfer', treasury, sink, 'gate.tax'))
        Check('unbound treasury rejected', not allowed('transfer', wallet, unbound, 'gate.pay_in', nil, asOwner)
            and not allowed('transfer', unbound, wallet, 'gate.pay_out'))
        Check('cannot move a treasury another resource operates',
            not allowed('transfer', otherTreasury, otherWallet, 'gate.pay_out')
            and not allowed('transfer', otherTreasury, sink, 'gate.tax'))
        Check('other operator moves only its own treasury',
            allowed('transfer', otherTreasury, sink, 'other.tax', OTHER)
            and not allowed('transfer', treasury, sink, 'other.tax', OTHER))
        Check('shop.purchase still needs a shop order', not allowed('transfer', wallet, treasury, 'shop.purchase', nil, asOwner))

        Check('listed supply to a bank account', allowed('issue', source, bank, 'gate.import'))
        Check('listed supply to own treasury', allowed('issue', source, treasury, 'gate.funding'))
        Check('supply to another treasury rejected', not allowed('issue', source, otherTreasury, 'gate.funding'))
        Check('registered supply not in OperatorSupply rejected',
            not allowed('issue', source, otherTreasury, 'other.mint', OTHER)
            and not EconomyOperators.SupplyAllowed(OTHER, 'other.mint'))
        Check('transfer reason cannot issue', not allowed('issue', source, bank, 'gate.deposit'))
        Check('supply reason cannot transfer', not allowed('transfer', wallet, bank, 'gate.import', nil, asOwner))
        Check('nothing destroys from a bank account', not allowed('destroy', bank, sink, 'gate.fee'))
        Check('supply lookup', EconomyOperators.SupplyAllowed(OPERATOR, 'gate.funding')
            and not EconomyOperators.SupplyAllowed(OPERATOR, 'gate.deposit')
            and not EconomyOperators.SupplyAllowed(OTHER, 'gate.funding')
            and not EconomyOperators.SupplyAllowed(nil, nil))
        Config.OperatorSupply[OPERATOR] = {}
        Check('supply stops when delisted', not allowed('issue', source, bank, 'gate.import')
            and not EconomyOperators.SupplyAllowed(OPERATOR, 'gate.import'))

        EconomyOperators.Unregister(OPERATOR)
        Check('released codes stop working', not allowed('transfer', bank, sink, 'gate.fee'))
        Check('v1 wallet transfer unchanged', allowed('transfer', wallet, otherWallet, 'any.reason'))
    end)
    local passed, total = Result()
    print(('[EconomyBankAccountGateSmokeTest] done %d/%d passed (test operators only; no funds moved)'):format(passed, total))
end, true)

RegisterCommand('EconomyBankContractSmokeTest', function(source)
    if source ~= 0 then return end
    local Check, Result = Counter('EconomyBankContractSmokeTest')
    local features = EconomyAPI.GetCapabilities().value.features
    Check('operated account capabilities', features.bankAccounts == 1 and features.operatedTreasuries == 1
        and features.accountHistory == 1)
    local denied = EconomyAPI.EnsureCharacterBankAccounts({ characterId = Config.SystemOwnerId }, 'untrusted-resource')
    Check('untrusted provision rejected', not denied.ok and denied.code == 'authorization_denied')
    local invalid = EconomyAPI.EnsureCharacterBankAccounts({}, 'feather-economy')
    Check('missing identity rejected', not invalid.ok and invalid.code == 'invalid_input')
    invalid = EconomyAPI.EnsureCharacterBankAccounts({ characterId = Config.SystemOwnerId }, 'feather-economy')
    Check('missing account reference rejected', not invalid.ok and invalid.code == 'invalid_input')
    invalid = EconomyAPI.EnsureCharacterBankAccounts({ characterId = Config.SystemOwnerId, accountRef = 'bad ref!' }, 'feather-economy')
    Check('malformed account reference rejected', not invalid.ok and invalid.code == 'invalid_input')
    invalid = EconomyAPI.EnsureCharacterBankAccounts({ characterId = 'bad', accountRef = 'a' }, 'feather-economy')
    Check('malformed UUID rejected', not invalid.ok and invalid.code == 'invalid_input')
    invalid = EconomyAPI.EnsureCharacterBankAccounts({ characterId = Config.SystemOwnerId, balance = 100 }, 'feather-economy')
    Check('balance injection rejected', not invalid.ok and invalid.code == 'invalid_input')
    invalid = EconomyAPI.EnsureCharacterBankAccounts({ characterId = Config.SystemOwnerId, accountType = 'wallet' }, 'feather-economy')
    Check('account type injection rejected', not invalid.ok and invalid.code == 'invalid_input')
    local unreadable = EconomyAPI.ListAccountEntries({ accountId = Config.SystemOwnerId }, 'untrusted-resource')
    Check('untrusted history rejected', not unreadable.ok and unreadable.code == 'authorization_denied')
    local foreign = EconomyAPI.ListAccountEntries({ accountId = Config.SystemOwnerId }, 'feather-hud')
    Check('foreign history rejected', not foreign.ok and foreign.code == 'authorization_denied')
    local malformed = EconomyAPI.ListAccountEntries({ accountId = 'bad' }, 'feather-economy')
    Check('history malformed account rejected', not malformed.ok and malformed.code == 'invalid_input')
    local oversized = EconomyAPI.ListAccountEntries({ accountId = Config.SystemOwnerId,
        limit = Config.Limits.maximumPageSize + 1 }, 'feather-economy')
    Check('history oversized page rejected', not oversized.ok and oversized.code == 'invalid_input')
    local rows = DB.query([[SELECT `account_id` FROM `economy_accounts`
        WHERE (`account_type`='bank' AND (`owner_type`<>'character' OR `account_ref`=''))
           OR (`account_type`<>'bank' AND `account_ref`<>'')
           OR (`owner_type`='character' AND `account_type` NOT IN ('wallet','bank'))]]) or {}
    Check('bank owner type integrity', #rows == 0)
    local constraint = DB.value([[SELECT COUNT(*) FROM `economy_schema_migrations`
        WHERE `id`='005_character_bank_accounts']])
    Check('bank migration applied', tonumber(constraint) == 1)
    local passed, total = Result()
    print(('[EconomyBankContractSmokeTest] done %d/%d passed (no accounts created or funds moved)'):format(passed, total))
end, true)

if not Config.DevMode then return end

-- Live movement test. Usage: EconomyBankLiveTest <character UUID|server id> <fresh requestId>
-- Uses $6.00 of the character's own wallet (creates no currency, so it needs no
-- policy grant): deposits, replays the deposit, rejects an overdraw, withdraws,
-- charges a $0.50 fee, checks the history, then returns the rest. The bank account
-- finishes at its original balance and the wallet $0.50 lower (the fee).
-- Each run needs a new requestId.
RegisterCommand('EconomyBankLiveTest', function(source, args)
    if source ~= 0 then return end
    local called, failure = xpcall(function()
        local characterId, reason = EconomyTests.Character(args[1])
        local requestId = args[2]
        assert(characterId and EconomyTests.RequestId(requestId),
            'usage: EconomyBankLiveTest <character UUID|server id> <requestId> ' .. tostring(reason or ''))
        local wallets = EconomyAPI.EnsureCharacterWallets({ characterId = characterId }, 'feather-economy')
        local banks = EconomyAPI.EnsureCharacterBankAccounts({ characterId = characterId, accountRef = 'live-test-1' }, 'feather-economy')
        local second = EconomyAPI.EnsureCharacterBankAccounts({ characterId = characterId, accountRef = 'live-test-2' }, 'feather-economy')
        assert(wallets.ok and banks.ok and second.ok, 'provisioning failed')
        local replayBanks = EconomyAPI.EnsureCharacterBankAccounts({ characterId = characterId, accountRef = 'live-test-1' }, 'feather-economy')
        assert(replayBanks.ok and replayBanks.value[1].accountId == banks.value[1].accountId
            and second.value[1].accountId ~= banks.value[1].accountId, 'multi-account identity failed')
        local function Find(list, currency)
            for _, account in ipairs(list) do if account.currency == currency then return account end end
        end
        local wallet, bank = Find(wallets.value, 'dollars'), Find(banks.value, 'dollars')
        local walletStart, bankStart = wallet.balance, bank.balance
        assert(walletStart >= 600, 'the character needs at least $6.00 in their wallet')
        local sink = EconomyAPI.GetSystemAccount({ currency = 'dollars', accountType = 'system_sink' }, 'feather-economy')
        assert(sink.ok, 'system sink unavailable')
        local registered = EconomyAPI.RegisterOperatedReasons({ reasons = {
            ['test.deposit'] = 'actor_wallet_to_bank', ['test.withdraw'] = 'bank_to_actor_wallet',
            ['test.fee'] = 'bank_to_sink' } }, 'feather-economy')
        assert(registered.ok, 'reason registration failed: ' .. tostring(registered.code))
        local function Move(from, to, amount, reason, key, resource)
            return EconomyAPI.Transfer({ fromAccountId = from.accountId, toAccountId = to.accountId,
                currency = 'dollars', amount = amount, reasonCode = reason, idempotencyKey = requestId .. ':' .. key
            }, { actorCharacterId = characterId }, resource or 'feather-economy')
        end
        local deposit = Move(wallet, bank, 600, 'test.deposit', 'deposit')
        assert(deposit.ok, 'deposit failed: ' .. tostring(deposit.code))
        local replay = Move(wallet, bank, 600, 'test.deposit', 'deposit')
        assert(replay.ok and replay.value.replayed == true and replay.value.transactionId == deposit.value.transactionId, 'deposit replay failed')
        local overdraw = Move(bank, wallet, bankStart + 601, 'test.withdraw', 'overdraw')
        assert(not overdraw.ok and overdraw.code == 'insufficient_funds', 'overdraw was not rejected')
        local withdraw = Move(bank, wallet, 100, 'test.withdraw', 'withdraw')
        assert(withdraw.ok, 'withdraw failed: ' .. tostring(withdraw.code))
        local fee = Move(bank, sink.value, 50, 'test.fee', 'fee')
        assert(fee.ok, 'fee failed: ' .. tostring(fee.code))
        local history = EconomyAPI.ListAccountEntries({ accountId = bank.accountId, limit = 10 }, 'feather-economy')
        assert(history.ok and #history.value >= 3 and history.value[1].reasonCode == 'test.fee'
            and history.value[1].amount == -50, 'history did not list the fee first')
        -- Return the rest: 600 - 100 - 50 = 450 back to the wallet.
        local back = Move(bank, wallet, 450, 'test.withdraw', 'return')
        assert(back.ok, 'return failed: ' .. tostring(back.code))
        local walletEnd = EconomyAccounts.Get(wallet.accountId).value.balance
        local bankEnd = EconomyAccounts.Get(bank.accountId).value.balance
        assert(walletEnd == walletStart - 50 and bankEnd == bankStart, ('balances wrong: wallet %d->%d bank %d->%d')
            :format(walletStart, walletEnd, bankStart, bankEnd))
        print(('[EconomyBankLiveTest] PASS deposit/withdraw/fee/replay/overdraw/history verified; bank=%d restored, wallet %d->%d (fee 50)')
            :format(bankEnd, walletStart, walletEnd))
    end, debug.traceback)
    EconomyOperators.Unregister('feather-economy')
    if not called then print('[EconomyBankLiveTest] FAIL ' .. tostring(failure)) end
end, true)
