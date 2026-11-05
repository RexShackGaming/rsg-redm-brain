local logger = EconomyLogging.Create('main')

local function Fail(result)
    local failure = type(result) == 'table' and result
        or EconomyResults.Err('internal_error', 'Economy startup returned an invalid result.')
    logger.Error('startup.aborted', {
        code = failure.code,
        message = failure.message,
        details = failure.details
    })
    error(failure.message or 'Feather Economy startup failed.')
end

CreateThread(function()
    local started = EconomyFoundation.BeginStartup()
    if not started.ok then return Fail(started) end

    -- Development only: `set economy_dev_migration_fault checksum|failure|invalid`
    -- injects a migration fault so a restart shows startup failing closed.
    local fault = Config.DevMode and GetConvar('economy_dev_migration_fault', '') or ''
    local definitions = (fault == 'checksum' or fault == 'failure' or fault == 'invalid')
        and EconomyMigrationRunner.FaultDefinitions(fault) or nil
    if fault ~= '' then
        logger.Warn('migration.fault_injected', { fault = fault, injected = definitions ~= nil })
    end
    local migrations = EconomyMigrationRunner.Run(definitions)
    if not migrations.ok then
        return Fail(EconomyFoundation.MarkFailed(
            migrations.code, migrations.message, migrations.details))
    end
    EconomyFoundation.MarkMigrationsComplete(migrations.value)

    local currencies = EconomyCurrencies.Start()
    if not currencies.ok then
        return Fail(EconomyFoundation.MarkFailed(
            currencies.code, currencies.message, currencies.details))
    end
    EconomyFoundation.MarkCatalogReady(currencies.value)

    local accounts = EconomyAccounts.Start()
    if not accounts.ok then
        return Fail(EconomyFoundation.MarkFailed(
            accounts.code, accounts.message, accounts.details))
    end
    EconomyFoundation.MarkAccountsReady(accounts.value)

    local outbox = EconomyOutbox.Start()
    if not outbox.ok then
        return Fail(EconomyFoundation.MarkFailed(
            outbox.code, outbox.message, outbox.details))
    end

    local ready = EconomyFoundation.MarkReady()
    logger.Info('startup.ready', {
        contract = 1,
        currencies = EconomyCurrencies.Count(),
        systemAccounts = accounts.value.systemAccounts,
        migrationsApplied = migrations.value.applied
    })
    local published = exports['feather-core']:PublishEvent('economy.ready.v1', {
        contract = 1,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0',
        currencies = EconomyCurrencies.Count()
    })
    if type(published) ~= 'table' or published.ok ~= true then
        logger.Warn('readiness.publish_failed', {
            code = type(published) == 'table' and published.code or 'invalid_result'
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        EconomyOutbox.Stop()
        logger.Info('lifecycle.stopped')
    end
end)

RegisterCommand('EconomyFoundationSmokeTest', function(source)
    if source ~= 0 then return end
    local capabilities = EconomyFoundation.GetCapabilities()
    local health = EconomyFoundation.GetHealth()
    local currencies = EconomyCurrencies.List()
    local dollars = EconomyCurrencies.Get('dollars')
    local gold = EconomyCurrencies.Get('gold')
    local unknown = EconomyCurrencies.Get('unknown')
    local tests = {
        { 'capabilities', capabilities.ok and capabilities.value.contract == 1
            and capabilities.value.features.currencyCatalog == 1 },
        { 'health', health.state == 'ready' and health.checks.core.ok
            and health.checks.events.ok
            and health.checks.migrations.ok and health.checks.currencies.ok
            and health.checks.accounts.ok },
        { 'currency catalog', currencies.ok and #currencies.value == 2 },
        { 'dollars definition', dollars.ok and dollars.value.precision == 2
            and dollars.value.enabled == true },
        { 'gold definition', gold.ok and gold.value.precision == 2
            and gold.value.enabled == true },
        { 'unknown rejected', not unknown.ok and unknown.code == 'currency_not_found' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[EconomyFoundationSmokeTest] %-22s %s')
            :format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[EconomyFoundationSmokeTest] done %d/%d passed'):format(passed, #tests))
end, true)

RegisterCommand('EconomyAccountContractSmokeTest', function(source)
    if source ~= 0 then return end
    local system = EconomyAccounts.FindByOwner('system', Config.SystemOwnerId)
    local invalidOwner = EconomyAccounts.FindByOwner('character', 'invalid')
    local missing = EconomyAccounts.Get('00000000-0000-0000-0000-000000000099')
    local unauthorizedRead = EconomyAPI.FindAccountsByOwner({
        ownerType = 'system', ownerId = Config.SystemOwnerId
    }, 'untrusted-smoke-resource')
    local unauthorizedProvision = EconomyAPI.EnsureCharacterWallets({
        characterId = Config.SystemOwnerId
    }, 'untrusted-smoke-resource')
    local distinct = {}
    for _, account in ipairs(system.ok and system.value or {}) do
        distinct[account.accountId] = true
    end
    local tests = {
        { 'system accounts', system.ok and #system.value == 4 },
        { 'unique identities', system.ok and (function()
            local count = 0
            for _ in pairs(distinct) do count = count + 1 end
            return count == 4
        end)() },
        -- Supply moves value out of the source and into the sink; nothing moves
        -- value into the source or out of the sink except a payment reversal.
        { 'system balance signs', system.ok and (function()
            for _, account in ipairs(system.value) do
                if account.accountType == 'system_source' and account.balance > 0 then return false end
                if account.accountType == 'system_sink' and account.balance < 0 then return false end
            end
            return true
        end)() },
        { 'invalid owner rejected', not invalidOwner.ok and invalidOwner.code == 'invalid_input' },
        { 'missing account rejected', not missing.ok and missing.code == 'account_not_found' },
        { 'untrusted read rejected', not unauthorizedRead.ok
            and unauthorizedRead.code == 'authorization_denied' },
        { 'untrusted provision rejected', not unauthorizedProvision.ok
            and unauthorizedProvision.code == 'authorization_denied' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[EconomyAccountContractSmokeTest] %-28s %s')
            :format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[EconomyAccountContractSmokeTest] done %d/%d passed (read-only)')
        :format(passed, #tests))
end, true)

RegisterCommand('EconomyJournalAuditSmokeTest', function(source)
    if source ~= 0 then return end
    local state = EconomyOutbox.GetState()
    local unbalanced = tonumber(DB.value([[
        SELECT COUNT(*) FROM (
            SELECT `transaction_id` FROM `economy_entries`
            GROUP BY `transaction_id` HAVING SUM(`amount`) <> 0
        ) audit
    ]])) or -1
    local orphaned = tonumber(DB.value([[
        SELECT COUNT(*) FROM (
            SELECT t.`transaction_id` FROM `economy_transactions` t
            LEFT JOIN `economy_entries` e ON e.`transaction_id`=t.`transaction_id`
            WHERE t.`status`='committed' GROUP BY t.`transaction_id`
            HAVING COUNT(e.`entry_id`) < 2
        ) audit
    ]])) or 0
    local invalidOutbox = tonumber(DB.value([[
        SELECT COUNT(*) FROM `economy_outbox`
        WHERE `status` NOT IN ('pending','published')
    ]])) or -1
    local tests = {
        { 'outbox running', state.ok and state.value.running == true },
        { 'journal balanced', unbalanced == 0 },
        { 'entries complete', orphaned == 0 },
        { 'outbox states valid', invalidOutbox == 0 },
        { 'delivery capability', EconomyFoundation.GetCapabilities().value.features.outboxDelivery == 1 }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[EconomyJournalAuditSmokeTest] %-22s %s')
            :format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[EconomyJournalAuditSmokeTest] done %d/%d passed pending=%s published=%s (read-only)')
        :format(passed, #tests, tostring(state.ok and state.value.pending),
            tostring(state.ok and state.value.published)))
end, true)

RegisterCommand('EconomyReleaseContractSmokeTest',function(source)
    if source~=0 then return end
    local forbidden={
        EconomyWalletProvisionTest=true,EconomyTransferContractSmokeTest=true,
        EconomySupplyTest=true,EconomyTransferLiveTest=true,EconomyConcurrencyTest=true,
        EconomyConcurrencyCleanup=true,EconomyShopFundingTest=true,
        EconomyPaymentReversalContractSmokeTest=true,
        EconomyTreasurySettlementContractSmokeTest=true,EconomyTreasuryContractSmokeTest=true,
        EconomyTreasuryProvisionTest=true,EconomyBankLiveTest=true,
        EconomyHistoryPaginationTest=true,EconomyMigrationFaultTest=true,EconomyRestartTest=true
    }
    local registered={}
    local callable=type(GetRegisteredCommands)=='function'
    if callable then
        for _,command in ipairs(GetRegisteredCommands() or {}) do
            local name=type(command)=='table' and command.name or nil
            if type(name)=='string' then registered[name]=true end
        end
    end
    local forbiddenAbsent=callable
    if callable then for name in pairs(forbidden) do if registered[name] then forbiddenAbsent=false;break end end end
    local capabilities=EconomyFoundation.GetCapabilities()
    local tests={
        {'service ready',EconomyFoundation.GetHealth().state=='ready'},
        {'server development disabled',Config.DevMode==false},
        {'supply authorization enabled',Config.Authorization.enabled==true},
        {'development commands absent',forbiddenAbsent},
        {'journal audit available',registered.EconomyJournalAuditSmokeTest==true},
        {'capability treasury settlement',capabilities.ok and capabilities.value.features.treasurySettlement==1},
        {'shops not trusted supplier',Config.Access.trustedSuppliers['feather-shops']~=true}
    }
    local passed=0
    for _,test in ipairs(tests) do
        if test[2] then passed=passed+1 end
        print(('[EconomyReleaseContractSmokeTest] %-30s %s'):format(test[1],test[2] and 'PASS' or 'FAIL'))
    end
    print(('[EconomyReleaseContractSmokeTest] done %d/%d passed (read-only)'):format(passed,#tests))
end,true)

if Config.DevMode then
    RegisterCommand('EconomyWalletProvisionTest', function(source, args)
        if source ~= 0 then return end
        local characterId = EconomyTests.Character(args and args[1])
        if not characterId then
            print('[EconomyWalletProvisionTest] usage: EconomyWalletProvisionTest <character UUID|server id>')
            return
        end
        local first = EconomyAccounts.EnsureCharacterWallets(characterId)
        local second = EconomyAccounts.EnsureCharacterWallets(characterId)
        local same = first.ok and second.ok and #first.value == 2 and #second.value == 2
        if same then
            for index = 1, #first.value do
                same = same and first.value[index].accountId == second.value[index].accountId
                    and first.value[index].balance == 0 and second.value[index].balance == 0
            end
        end
        print(('[EconomyWalletProvisionTest] %s character=%s wallets=%s idempotent=%s'):format(
            same and 'PASS' or 'FAIL', tostring(characterId),
            tostring(first.ok and #first.value or 0), tostring(same)))
    end, true)

    RegisterCommand('EconomyTransferContractSmokeTest', function(source, args)
        if source ~= 0 then return end
        local characterId = EconomyTests.Character(args and args[1])
        if not characterId then
            print('[EconomyTransferContractSmokeTest] usage: EconomyTransferContractSmokeTest <character UUID|server id>')
            return
        end
        local wallets = EconomyAccounts.EnsureCharacterWallets(characterId)
        local system = EconomyAccounts.FindByOwner('system', Config.SystemOwnerId)
        local from, sink
        for _, account in ipairs(wallets.ok and wallets.value or {}) do
            if account.currency == 'dollars' then from = account end
        end
        for _, account in ipairs(system.ok and system.value or {}) do
            if account.currency == 'dollars' and account.accountType == 'system_sink' then sink = account end
        end
        local base = from and sink and {
            fromAccountId = from.accountId, toAccountId = sink.accountId,
            currency = 'dollars', amount = 1, reasonCode = 'smoke.transfer',
            referenceType = 'smoke', referenceId = 'transfer-contract',
            idempotencyKey = 'transfer-contract-insufficient'
        } or {}
        local untrusted = EconomyJournal.Transfer(base, { resource = 'untrusted-smoke-resource' })
        local insufficient = EconomyJournal.Transfer(base, { resource = 'feather-economy' })
        local invalid = EconomyJournal.Transfer({}, { resource = 'feather-economy' })
        local sameRequest = {}
        for key, value in pairs(base) do sameRequest[key] = value end
        sameRequest.toAccountId = sameRequest.fromAccountId
        sameRequest.idempotencyKey = 'transfer-contract-same-account'
        local same = EconomyJournal.Transfer(sameRequest, { resource = 'feather-economy' })
        local transactionCount = tonumber(DB.value([[
            SELECT COUNT(*) FROM `economy_transactions`
            WHERE `source_resource`='feather-economy'
              AND `idempotency_key` LIKE 'transfer-contract-%'
        ]])) or -1
        local capabilities = EconomyFoundation.GetCapabilities()
        local tests = {
            { 'wallets available', from ~= nil and sink ~= nil },
            { 'transfer capability', capabilities.ok
                and capabilities.value.features.transfers == 1
                and capabilities.value.features.journal == 1 },
            { 'untrusted rejected', not untrusted.ok
                and untrusted.code == 'authorization_denied' },
            { 'invalid rejected', not invalid.ok and invalid.code == 'invalid_input' },
            { 'same account rejected', not same.ok and same.code == 'invalid_input' },
            { 'insufficient rejected', not insufficient.ok
                and insufficient.code == 'insufficient_funds' },
            { 'rejections rolled back', transactionCount == 0 }
        }
        local passed = 0
        for _, test in ipairs(tests) do
            if test[2] then passed = passed + 1 end
            print(('[EconomyTransferContractSmokeTest] %-24s %s')
                :format(test[1], test[2] and 'PASS' or 'FAIL'))
        end
        print(('[EconomyTransferContractSmokeTest] done %d/%d passed (no funds moved)')
            :format(passed, #tests))
    end, true)

    RegisterCommand('EconomySupplyTest', function(source, args)
        if source ~= 0 then return end
        local characterId, target = EconomyTests.Character(args and args[1])
        local requestId = args and args[2]
        if not characterId or not EconomyTests.RequestId(requestId) then
            print('[EconomySupplyTest] usage: EconomySupplyTest <character UUID|server id> <fresh requestId>')
            return
        end
        local wallets = EconomyAccounts.EnsureCharacterWallets(characterId)
        local wallet
        for _, account in ipairs(wallets.ok and wallets.value or {}) do
            if account.currency == 'dollars' then wallet = account end
        end
        if not wallet then print('[EconomySupplyTest] FAIL dollars wallet unavailable'); return end
        local before = wallet.balance
        local request = { accountId = wallet.accountId, currency = 'dollars', amount = 10000,
            reasonCode = 'smoke.issue', referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId }
        local context = { resource = 'feather-economy', actorSource = target,
            actorCharacterId = characterId, correlationId = 'supply:' .. requestId }
        local issued = EconomyJournal.Issue(request, context)
        local replayed = EconomyJournal.Issue(request, context)
        local mismatchRequest = {}
        for key, value in pairs(request) do mismatchRequest[key] = value end
        mismatchRequest.amount = request.amount + 1
        local mismatch = EconomyJournal.Issue(mismatchRequest, context)
        local destroyed = issued.ok and EconomyJournal.Destroy({
            accountId = wallet.accountId, currency = 'dollars', amount = request.amount,
            reasonCode = 'smoke.destroy', referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId .. '-destroy'
        }, context) or issued
        local after = EconomyAccounts.Get(wallet.accountId)
        local entrySum = issued.ok and tonumber(DB.value([[
            SELECT COALESCE(SUM(`amount`),0) FROM `economy_entries`
            WHERE `transaction_id`=?
        ]], issued.value.transactionId)) or nil
        local passed = issued.ok and replayed.ok and replayed.value.replayed == true
            and replayed.value.transactionId == issued.value.transactionId
            and not mismatch.ok and mismatch.code == 'idempotency_conflict'
            and destroyed.ok and after.ok and after.value.balance == before and entrySum == 0
        print(('[EconomySupplyTest] %s wallet=%s before=%s issued=%s final=%s replayed=%s mismatchRejected=%s balanced=%s'):format(
            passed and 'PASS' or 'FAIL', tostring(wallet.accountId), tostring(before),
            tostring(issued.ok and request.amount), tostring(after.ok and after.value.balance),
            tostring(replayed.ok and replayed.value.replayed),
            tostring(not mismatch.ok and mismatch.code == 'idempotency_conflict'),
            tostring(entrySum == 0)))
    end, true)

    RegisterCommand('EconomyTransferLiveTest', function(source, args)
        if source ~= 0 then return end
        local senderId, senderSource = EconomyTests.Character(args and args[1])
        local recipientId = EconomyTests.Character(args and args[2])
        local requestId = args and args[3]
        if not senderId or not recipientId or senderId == recipientId
            or not EconomyTests.RequestId(requestId) then
            print('[EconomyTransferLiveTest] usage: EconomyTransferLiveTest <sender UUID|server id> <recipient UUID|server id> <fresh requestId>')
            return
        end
        local function Dollars(characterId)
            local wallets = EconomyAccounts.EnsureCharacterWallets(characterId)
            for _, account in ipairs(wallets.ok and wallets.value or {}) do
                if account.currency == 'dollars' then return account end
            end
        end
        local from, to = Dollars(senderId), Dollars(recipientId)
        if not from or not to then print('[EconomyTransferLiveTest] FAIL wallets unavailable'); return end
        local fromBefore, toBefore = from.balance, to.balance
        local context = { resource = 'feather-economy', actorSource = senderSource,
            actorCharacterId = senderId, correlationId = 'transfer-live:' .. requestId }
        local issued = EconomyJournal.Issue({ accountId = from.accountId, currency = 'dollars',
            amount = 10000, reasonCode = 'smoke.issue', referenceType = 'smoke',
            referenceId = requestId, idempotencyKey = requestId .. '-issue' },
            context)
        local transferRequest = { fromAccountId = from.accountId, toAccountId = to.accountId,
            currency = 'dollars', amount = 4000, reasonCode = 'smoke.transfer',
            referenceType = 'smoke', referenceId = requestId, idempotencyKey = requestId }
        local transferred = issued.ok and EconomyJournal.Transfer(transferRequest, context) or issued
        local replayed = transferred.ok and EconomyJournal.Transfer(transferRequest, context) or transferred
        local destroyedFrom = transferred.ok and EconomyJournal.Destroy({ accountId = from.accountId,
            currency = 'dollars', amount = 6000, reasonCode = 'smoke.destroy',
            referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId .. '-destroy-sender' },
            context) or transferred
        local destroyedTo = destroyedFrom.ok and EconomyJournal.Destroy({ accountId = to.accountId,
            currency = 'dollars', amount = 4000, reasonCode = 'smoke.destroy',
            referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId .. '-destroy-recipient' },
            context) or destroyedFrom
        local fromAfter, toAfter = EconomyAccounts.Get(from.accountId), EconomyAccounts.Get(to.accountId)
        local passed = issued.ok and transferred.ok and replayed.ok and replayed.value.replayed == true
            and replayed.value.transactionId == transferred.value.transactionId
            and destroyedFrom.ok and destroyedTo.ok and fromAfter.ok and toAfter.ok
            and fromAfter.value.balance == fromBefore and toAfter.value.balance == toBefore
        print(('[EconomyTransferLiveTest] %s transaction=%s amount=4000 replayed=%s senderFinal=%s recipientFinal=%s restored=%s'):format(
            passed and 'PASS' or 'FAIL', tostring(transferred.ok and transferred.value.transactionId),
            tostring(replayed.ok and replayed.value.replayed),
            tostring(fromAfter.ok and fromAfter.value.balance),
            tostring(toAfter.ok and toAfter.value.balance), tostring(passed)))
    end, true)

    RegisterCommand('EconomyConcurrencyTest', function(source, args)
        if source ~= 0 then return end
        local senderId, senderSource = EconomyTests.Character(args and args[1])
        local recipientId = EconomyTests.Character(args and args[2])
        local requestId = args and args[3]
        if not senderId or not recipientId or senderId == recipientId
            or not EconomyTests.RequestId(requestId) then
            print('[EconomyConcurrencyTest] usage: EconomyConcurrencyTest <sender UUID|server id> <recipient UUID|server id> <fresh requestId>')
            return
        end
        local function Dollars(characterId)
            local wallets = EconomyAccounts.EnsureCharacterWallets(characterId)
            for _, account in ipairs(wallets.ok and wallets.value or {}) do
                if account.currency == 'dollars' then return account end
            end
        end
        local from, to = Dollars(senderId), Dollars(recipientId)
        if not from or not to then print('[EconomyConcurrencyTest] FAIL wallets unavailable'); return end
        local fromBefore, toBefore = from.balance, to.balance
        local context = { resource = 'feather-economy', actorSource = senderSource,
            actorCharacterId = senderId, correlationId = 'concurrency:' .. requestId }
        local issued = EconomyJournal.Issue({ accountId = from.accountId, currency = 'dollars',
            amount = 10000, reasonCode = 'smoke.issue', referenceType = 'smoke',
            referenceId = requestId, idempotencyKey = requestId .. '-issue' },
            context)
        if not issued.ok then
            print(('[EconomyConcurrencyTest] FAIL funding code=%s'):format(tostring(issued.code)))
            return
        end
        local injectedContext = { resource = 'feather-economy', actorSource = senderSource,
            actorCharacterId = senderId, correlationId = 'injected:' .. requestId,
            failureInjection = 'after_balance_update' }
        local injected = EconomyJournal.Transfer({ fromAccountId = from.accountId,
            toAccountId = to.accountId, currency = 'dollars', amount = 1,
            reasonCode = 'smoke.injected', referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId .. '-injected' }, injectedContext)
        local afterInjectedFrom, afterInjectedTo = EconomyAccounts.Get(from.accountId), EconomyAccounts.Get(to.accountId)
        local injectedReservationCount = tonumber(DB.value([[
            SELECT COUNT(*) FROM `economy_transactions`
            WHERE `source_resource`='feather-economy' AND `operation_type`='transfer'
              AND `idempotency_key`=?
        ]], requestId .. '-injected')) or -1
        local injectionRolledBack = not injected.ok and injected.code == 'transaction_conflict'
            and afterInjectedFrom.ok and afterInjectedTo.ok
            and afterInjectedFrom.value.balance == fromBefore + 10000
            and afterInjectedTo.value.balance == toBefore and injectedReservationCount == 0

        local outcomes, completed = {}, promise.new()
        local function Spend(suffix)
            CreateThread(function()
                local outcome = EconomyJournal.Transfer({
                    fromAccountId = from.accountId, toAccountId = to.accountId,
                    currency = 'dollars', amount = 7500, reasonCode = 'smoke.concurrent',
                    referenceType = 'smoke', referenceId = requestId,
                    idempotencyKey = requestId .. '-' .. suffix
                }, context)
                outcomes[#outcomes + 1] = outcome
                if #outcomes == 2 then completed:resolve(true) end
            end)
        end
        Spend('a')
        Spend('b')
        Citizen.Await(completed)
        local successes, insufficient = 0, 0
        for _, outcome in ipairs(outcomes) do
            if outcome.ok then successes = successes + 1
            elseif outcome.code == 'insufficient_funds' then insufficient = insufficient + 1 end
        end
        local senderNow, recipientNow = EconomyAccounts.Get(from.accountId), EconomyAccounts.Get(to.accountId)
        local conserved = senderNow.ok and recipientNow.ok
            and senderNow.value.balance == fromBefore + 2500
            and recipientNow.value.balance == toBefore + 7500
        local destroyedSender = conserved and EconomyJournal.Destroy({ accountId = from.accountId,
            currency = 'dollars', amount = 2500, reasonCode = 'smoke.destroy',
            referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId .. '-destroy-sender' }, context) or nil
        local destroyedRecipient = destroyedSender and destroyedSender.ok and EconomyJournal.Destroy({
            accountId = to.accountId, currency = 'dollars', amount = 7500,
            reasonCode = 'smoke.destroy', referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId .. '-destroy-recipient' }, context) or nil
        local fromAfter, toAfter = EconomyAccounts.Get(from.accountId), EconomyAccounts.Get(to.accountId)
        local restored = destroyedSender and destroyedSender.ok and destroyedRecipient
            and destroyedRecipient.ok and fromAfter.ok and toAfter.ok
            and fromAfter.value.balance == fromBefore and toAfter.value.balance == toBefore
        local passed = injectionRolledBack and successes == 1 and insufficient == 1
            and conserved and restored
        print(('[EconomyConcurrencyTest] %s injectedRollback=%s committed=%d insufficient=%d conserved=%s restored=%s'):format(
            passed and 'PASS' or 'FAIL', tostring(injectionRolledBack), successes,
            insufficient, tostring(conserved), tostring(restored)))
    end, true)
end

RegisterCommand('EconomyStablesReversalContractSmokeTest', function(source)
    if source ~= 0 then return end
    if EconomyFoundation.GetHealth().state ~= 'ready' then
        print('[EconomyStablesReversalContractSmokeTest] not ready; wait for Economy startup.')
        return
    end
    local uuid = '00000000-0000-4000-8000-000000000001'
    local untrusted = EconomyAPI.ReversePayment({ transactionId = uuid }, {}, 'untrusted-test')
    local tampered = EconomyAPI.ReversePayment({ transactionId = uuid, amount = 1 }, {}, 'bcc-stables')
    local missing = EconomyAPI.ReversePayment({ transactionId = uuid }, {}, 'bcc-stables')
    local scopes = Config.ReversiblePayments and Config.ReversiblePayments['bcc-stables'] or {}
    local tests = {
        { 'Stables reverser admitted', Config.Access.trustedReversers['bcc-stables'] == true },
        { 'horse scope configured', scopes['stables.horse_purchase'] and scopes['stables.horse_purchase'].referenceType == 'stables_order' },
        { 'tack scope configured', scopes['stables.tack_purchase'] and scopes['stables.tack_purchase'].referenceType == 'stables_order' },
        { 'capability advertised', EconomyAPI.GetCapabilities().value.features.scopedPaymentReversals == 1 },
        { 'untrusted caller refused', not untrusted.ok and untrusted.code == 'authorization_denied' },
        { 'amount tampering refused', not tampered.ok and tampered.code == 'invalid_input' },
        { 'missing original refused', not missing.ok and missing.code == 'reversal_not_allowed' },
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[EconomyStablesReversalContractSmokeTest] %s %s'):format(test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[EconomyStablesReversalContractSmokeTest] %d/%d; no funds moved'):format(passed, #tests))
end, true)
