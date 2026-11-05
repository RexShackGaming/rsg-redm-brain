-- Release gates (master plan section 12). EconomyHealthReport and
-- EconomyReleaseGateSmokeTest are read-only and stay available in the
-- production profile. The tests after the DevMode guard change data.

local function Encode(value)
    local ok, encoded = pcall(json.encode, value)
    return ok and encoded or tostring(value)
end

RegisterCommand('EconomyHealthReport', function(source)
    if source ~= 0 then return end
    local health = EconomyFoundation.GetHealth()
    print(('[EconomyHealthReport] state=%s phase=%s version=%s'):format(
        tostring(health.state), tostring(health.phase), tostring(health.version)))
    if health.failure then
        print(('[EconomyHealthReport] failure code=%s message=%s'):format(
            tostring(health.failure.code), tostring(health.failure.message)))
        print('[EconomyHealthReport] failure details=' .. Encode(health.failure.details or {}))
    end
    if health.checks.migrations then
        print('[EconomyHealthReport] migrations=' .. Encode(health.checks.migrations.details or {}))
    end
end, true)

RegisterCommand('EconomyReleaseGateSmokeTest', function(source)
    if source ~= 0 then return end
    local Check, Result = EconomyTests.Counter('EconomyReleaseGateSmokeTest')
    local called, failure = xpcall(function()
        Check('service ready', EconomyFoundation.GetHealth().state == 'ready')

        -- Migrations: a rerun applies nothing, and every recorded checksum matches.
        local rerun = EconomyMigrationRunner.Run()
        Check('migration rerun applies nothing', rerun.ok and rerun.value.applied == 0
            and rerun.value.total == #EconomyMigrationDefinitions)
        Check('no unknown recorded migrations', rerun.ok and #rerun.value.unknown == 0)
        local recorded = {}
        for _, row in ipairs(DB.query('SELECT `id`,`checksum` FROM `economy_schema_migrations`') or {}) do
            recorded[row.id] = row.checksum
        end
        local matching = true
        for _, migration in ipairs(EconomyMigrationDefinitions) do
            matching = matching and recorded[migration.id] == EconomyMigrationRunner.Checksum(migration)
        end
        Check('recorded checksums match', matching)
        -- An altered copy of an applied migration. Every migration is applied, so
        -- the runner has nothing it could run.
        local altered = {}
        for index, migration in ipairs(EconomyMigrationDefinitions) do altered[index] = migration end
        local last = altered[#altered]
        local statements = {}
        for index, statement in ipairs(last.statements) do statements[index] = statement end
        statements[1] = statements[1] .. ' '
        altered[#altered] = { id = last.id, statements = statements }
        local mismatch = matching and EconomyMigrationRunner.Run(altered) or nil
        Check('checksum mismatch stops the runner', mismatch ~= nil and not mismatch.ok
            and mismatch.code == 'migration_checksum_mismatch'
            and mismatch.details.migrationId == last.id)

        -- History pagination limits. The account id is a UUID with no account.
        local function History(accountId, limit, offset)
            return EconomyAPI.ListAccountEntries({ accountId = accountId, limit = limit, offset = offset },
                'feather-economy')
        end
        local rejected = true
        for _, case in ipairs({ { 0, 0 }, { Config.Limits.maximumPageSize + 1, 0 }, { 1.5, 0 },
            { 'abc', 0 }, { 1, -1 }, { 1, 1.5 }, { 1, 100001 } }) do
            local page = History(Config.SystemOwnerId, case[1], case[2])
            rejected = rejected and not page.ok and page.code == 'invalid_input'
        end
        Check('history rejects bad limits and offsets', rejected)
        local defaults = History(Config.SystemOwnerId)
        Check('history defaults accepted', defaults.ok and #defaults.value == 0)
        local both = EconomyAPI.ListAccountEntries({ accountId = Config.SystemOwnerId, before = 1, offset = 0 },
            'feather-economy')
        Check('history rejects before with offset', not both.ok and both.code == 'invalid_input')
        local foreign = EconomyAPI.ListAccountEntries({ accountId = Config.SystemOwnerId, before = 1 }, 'feather-economy')
        Check('history rejects a cursor of another account', not foreign.ok and foreign.code == 'invalid_cursor')

        -- Ordering and paging on the account with the most entries.
        local busiest = DB.one([[SELECT `account_id`, COUNT(*) AS `entries` FROM `economy_entries`
            GROUP BY `account_id` ORDER BY `entries` DESC LIMIT 1]])
        local total = busiest and tonumber(busiest.entries) or 0
        if total < 2 then
            print('[EconomyReleaseGateSmokeTest] fewer than two entries on any account; paging checks skipped')
        else
            local accountId = busiest.account_id
            local count = math.min(total, Config.Limits.maximumPageSize)
            local whole = History(accountId, count, 0)
            local paged = {}
            for offset = 0, count - 1, 3 do
                local page = History(accountId, 3, offset)
                for _, entry in ipairs(page.ok and page.value or {}) do paged[#paged + 1] = entry end
            end
            local same = whole.ok and #whole.value == count and #paged >= count
            for index = 1, same and count or 0 do
                same = same and paged[index].entryId == whole.value[index].entryId
            end
            Check('pages of 3 match one page', same)
            local chained = whole.ok and #whole.value == count
            for index = 2, chained and count or 0 do
                local newer, older = whole.value[index - 1], whole.value[index]
                chained = chained and newer.resultingBalance - newer.amount == older.resultingBalance
            end
            Check('newest first in posting order', chained)
            local account = EconomyAccounts.Get(accountId)
            Check('newest entry equals balance', whole.ok and account.ok
                and whole.value[1].resultingBalance == account.value.balance)
            if total <= 100000 then
                local beyond = History(accountId, 1, total)
                Check('offset past the end is empty', beyond.ok and #beyond.value == 0)
            end
        end

        -- Journal integrity across every account.
        local mismatched = tonumber(DB.value([[SELECT COUNT(*) FROM `economy_balances` b
            LEFT JOIN (SELECT `account_id`, SUM(`amount`) AS `total` FROM `economy_entries`
                GROUP BY `account_id`) e ON e.`account_id`=b.`account_id`
            WHERE b.`posted_amount` <> COALESCE(e.`total`, 0)]])) or -1
        Check('balances equal their entries', mismatched == 0)
        local broken = tonumber(DB.value([[SELECT COUNT(*) FROM (
            SELECT e.`amount`, e.`resulting_balance`,
                   LAG(e.`resulting_balance`) OVER (PARTITION BY e.`account_id`
                       ORDER BY t.`posted_at`, e.`entry_sequence`) AS `earlier_balance`
            FROM `economy_entries` e
            INNER JOIN `economy_transactions` t ON t.`transaction_id`=e.`transaction_id`
            WHERE t.`status`='committed') h
            WHERE h.`earlier_balance` IS NOT NULL
              AND h.`earlier_balance` + h.`amount` <> h.`resulting_balance`]])) or -1
        Check('history order matches balances', broken == 0)
        local stale = tonumber(DB.value([[SELECT COUNT(*) FROM `economy_outbox`
            WHERE `status`='pending' AND `created_at` < CURRENT_TIMESTAMP - INTERVAL 5 MINUTE]])) or -1
        Check('outbox has no stale pending events', stale == 0)

        -- Supply policy fails closed. Stand-in decisions run through the same gate
        -- as Core's; the account does not exist, so a request that passes the gate
        -- still fails in the journal and nothing is posted.
        local runId = ('%d-%d'):format(os.time(), GetGameTimer())
        local function Attempt(operation, authorize, resource, suffix)
            return EconomyAPI.Supply(operation, {
                accountId = '00000000-0000-4000-8000-0000000000ee', currency = 'dollars', amount = 1,
                reasonCode = 'gate.policy_probe', referenceType = 'gate', referenceId = runId,
                idempotencyKey = ('policy-probe:%s:%s:%s'):format(runId, operation, suffix)
            }, { correlationId = 'policy-probe:' .. runId }, resource or 'feather-economy', authorize)
        end
        local function Denied(suffix, authorize, policyCode)
            for _, operation in ipairs({ 'issue', 'destroy' }) do
                local result = Attempt(operation, authorize, nil, suffix)
                if result.ok or result.code ~= 'authorization_denied'
                    or (policyCode and (type(result.details) ~= 'table'
                        or result.details.policyCode ~= policyCode)) then
                    return false
                end
            end
            return true
        end
        Check('policy authorization enabled', Config.Authorization.enabled == true)
        Check('missing provider denies supply', Denied('missing', function()
            return { ok = false, code = 'provider_unavailable', message = 'No policy provider.' }
        end, 'provider_unavailable'))
        Check('denying provider denies supply', Denied('denied', function()
            return { ok = true, value = { allowed = false, code = 'service_forbidden' } }
        end, 'service_forbidden'))
        Check('failing policy call denies supply', Denied('raised', function()
            error('policy call failed')
        end, 'policy_error'))
        Check('invalid decisions deny supply', Denied('nil', function() return nil end)
            and Denied('ok-only', function() return { ok = true } end)
            and Denied('not-boolean', function() return { ok = true, value = { allowed = 'yes' } } end))
        local function Allow() return { ok = true, value = { allowed = true } } end
        local passedIssue, passedDestroy = Attempt('issue', Allow, nil, 'allow'), Attempt('destroy', Allow, nil, 'allow')
        Check('allowed request reaches the journal', passedIssue.code == 'account_not_found'
            and passedDestroy.code == 'account_not_found')
        local untrusted = Attempt('issue', Allow, 'economy-gate-untrusted', 'untrusted')
        Check('untrusted supplier denied after policy', untrusted.code == 'authorization_denied')
        local coreIssue, coreDestroy = Attempt('issue', nil, nil, 'core'), Attempt('destroy', nil, nil, 'core')
        Check('Core grants Economy itself no supply', coreIssue.code == 'authorization_denied'
            and coreDestroy.code == 'authorization_denied')
        print(('[EconomyReleaseGateSmokeTest] Core policy answered %s / %s'):format(
            tostring(coreIssue.details and coreIssue.details.policyCode),
            tostring(coreDestroy.details and coreDestroy.details.policyCode)))
        local posted = tonumber(DB.value([[SELECT COUNT(*) FROM `economy_transactions`
            WHERE `idempotency_key` LIKE ?]], 'policy-probe:' .. runId .. ':%')) or -1
        Check('policy probes posted nothing', posted == 0)
    end, debug.traceback)
    if not called then print('[EconomyReleaseGateSmokeTest] FAIL ' .. tostring(failure)) end
    local passed, total = Result()
    print(('[EconomyReleaseGateSmokeTest] done %d/%d passed (read-only)'):format(passed, total))
end, true)

if not Config.DevMode then return end

-- Usage: EconomyHistoryPaginationTest <character UUID|server id> <fresh requestId>
-- Issues 1..7 cents to the character's dollars wallet, pages the history (by
-- offset and by cursor, posting an 8th cent between two cursor pages), then
-- destroys the 36 cents so the wallet finishes at its original balance.
RegisterCommand('EconomyHistoryPaginationTest', function(source, args)
    if source ~= 0 then return end
    local Check, Result = EconomyTests.Counter('EconomyHistoryPaginationTest')
    local wallet, context, requestId, issued = nil, nil, args[2], 0
    local called, failure = xpcall(function()
        local characterId, reason = EconomyTests.Character(args[1])
        assert(characterId and EconomyTests.RequestId(requestId),
            'usage: EconomyHistoryPaginationTest <character UUID|server id> <fresh requestId> ' .. tostring(reason or ''))
        wallet = assert(EconomyTests.Wallet(characterId, 'dollars'), 'dollars wallet unavailable')
        context = { resource = 'feather-economy', actorCharacterId = characterId,
            correlationId = 'pagination:' .. requestId }
        local posted = {}
        for index = 1, 7 do
            local result = EconomyJournal.Issue({ accountId = wallet.accountId, currency = 'dollars',
                amount = index, reasonCode = 'smoke.pagination', referenceType = 'smoke',
                referenceId = requestId, idempotencyKey = ('%s:issue:%d'):format(requestId, index) }, context)
            assert(result.ok and not result.value.replayed,
                'issue failed or requestId reused: ' .. tostring(result.code))
            issued = issued + index
            posted[index] = result.value.transactionId
        end
        local function Page(limit, offset)
            local page = EconomyAPI.ListAccountEntries({ accountId = wallet.accountId, limit = limit,
                offset = offset }, 'feather-economy')
            assert(page.ok, 'history read failed: ' .. tostring(page.code))
            return page.value
        end
        local whole = Page(7, 0)
        local newestFirst = #whole == 7
        for index = 1, newestFirst and 7 or 0 do
            newestFirst = newestFirst and whole[index].transactionId == posted[8 - index]
                and whole[index].amount == 8 - index
        end
        Check('newest first in posting order', newestFirst)
        local paged = {}
        for _, offset in ipairs({ 0, 3, 6 }) do
            for _, entry in ipairs(Page(3, offset)) do paged[#paged + 1] = entry end
        end
        local same = #paged >= 7
        for index = 1, same and 7 or 0 do same = same and paged[index].entryId == whole[index].entryId end
        Check('pages of 3 match one page of 7', same)
        local distinct, seen = true, {}
        for _, entry in ipairs(paged) do
            distinct = distinct and not seen[entry.entryId]
            seen[entry.entryId] = true
        end
        Check('no entry repeated across pages', distinct)
        local descending = #whole == 7
        for index = 2, descending and 7 or 0 do
            descending = descending and whole[index].sequence < whole[index - 1].sequence
        end
        Check('sequence strictly descending', descending)
        local chained = true
        for index = 2, #paged do
            chained = chained and paged[index - 1].resultingBalance - paged[index - 1].amount
                == paged[index].resultingBalance
        end
        Check('resulting balances chain', chained)
        Check('newest entry equals balance',
            whole[1].resultingBalance == EconomyAccounts.Get(wallet.accountId).value.balance)
        local sixth = Page(1, 5)
        Check('limit and offset honoured', #Page(2, 0) == 2 and #sixth == 1
            and sixth[1].entryId == whole[6].entryId)
        local total = tonumber(DB.value('SELECT COUNT(*) FROM `economy_entries` WHERE `account_id`=?',
            wallet.accountId)) or 0
        Check('last page is partial', #Page(5, total - 2) == 2)
        Check('offset past the end is empty', #Page(5, total) == 0)

        -- Cursor paging stays stable while a new entry is posted between pages.
        local function Cursor(limit, before)
            local page = EconomyAPI.ListAccountEntries({ accountId = wallet.accountId, limit = limit,
                before = before }, 'feather-economy')
            assert(page.ok, 'cursor read failed: ' .. tostring(page.code))
            return page
        end
        local first = Cursor(3)
        Check('cursor names the next page', first.meta ~= nil and first.meta.nextBefore == whole[3].sequence)
        local late = EconomyJournal.Issue({ accountId = wallet.accountId, currency = 'dollars',
            amount = 8, reasonCode = 'smoke.pagination', referenceType = 'smoke',
            referenceId = requestId, idempotencyKey = ('%s:issue:8'):format(requestId) }, context)
        assert(late.ok and not late.value.replayed, 'issue failed or requestId reused: ' .. tostring(late.code))
        issued = issued + 8
        local second = Cursor(3, first.meta and first.meta.nextBefore)
        local third = Cursor(3, second.meta and second.meta.nextBefore)
        local walked = {}
        for _, page in ipairs({ first, second, third }) do
            for _, entry in ipairs(page.value) do walked[#walked + 1] = entry end
        end
        local stable = #walked >= 7
        for index = 1, stable and 7 or 0 do stable = stable and walked[index].entryId == whole[index].entryId end
        Check('cursor pages stable while a new entry posts', stable)
        Check('new entry listed first', Cursor(1).value[1].amount == 8)
    end, debug.traceback)
    if not called then print('[EconomyHistoryPaginationTest] FAIL ' .. tostring(failure)) end
    if issued > 0 then
        local before = wallet.balance
        local destroyed = EconomyJournal.Destroy({ accountId = wallet.accountId, currency = 'dollars',
            amount = issued, reasonCode = 'smoke.pagination', referenceType = 'smoke',
            referenceId = requestId, idempotencyKey = requestId .. ':destroy' }, context)
        local after = EconomyAccounts.Get(wallet.accountId)
        Check('test funds removed', destroyed.ok and after.ok and after.value.balance == before)
    end
    local passed, total = Result()
    print(('[EconomyHistoryPaginationTest] done %d/%d passed'):format(passed, total))
end, true)

-- Usage: EconomyMigrationFaultTest
-- Runs the migration runner in place with injected faults. A probe table and
-- ledger row are created only by the successful-probe step and removed again.
RegisterCommand('EconomyMigrationFaultTest', function(source)
    if source ~= 0 then return end
    local Check, Result = EconomyTests.Counter('EconomyMigrationFaultTest')
    local Run, Fault = EconomyMigrationRunner.Run, EconomyMigrationRunner.FaultDefinitions
    local probe, probeId = EconomyMigrationRunner.ProbeTable, EconomyMigrationRunner.ProbeId
    local function State()
        local tables = tonumber(DB.value([[SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN (?,?)]], probe, probe .. '_broken')) or -1
        local recorded = tonumber(DB.value('SELECT COUNT(*) FROM `economy_schema_migrations` WHERE `id`=?',
            probeId)) or -1
        return tables, recorded
    end
    local function Clean()
        DB.exec(('DROP TABLE IF EXISTS `%s`'):format(probe))
        DB.exec(('DROP TABLE IF EXISTS `%s_broken`'):format(probe))
        DB.exec('DELETE FROM `economy_schema_migrations` WHERE `id`=?', probeId)
    end
    local called, failure = xpcall(function()
        Clean()
        local invalid = Run(Fault('invalid'))
        local tables, recorded = State()
        Check('mixed statements rejected before running', not invalid.ok
            and invalid.code == 'invalid_migration' and invalid.details.migrationId == probeId
            and tables == 0 and recorded == 0)

        local mismatch = Run(Fault('checksum'))
        tables, recorded = State()
        Check('checksum mismatch applies nothing', not mismatch.ok
            and mismatch.code == 'migration_checksum_mismatch'
            and mismatch.details.migrationId == EconomyMigrationDefinitions[1].id
            and tables == 0 and recorded == 0)

        local failed = Run(Fault('failure'))
        tables, recorded = State()
        Check('failing migration names migration and statement', not failed.ok
            and failed.code == 'migration_failed' and failed.details.migrationId == probeId
            and failed.details.statement == 2 and failed.details.statements == 2
            and type(failed.details.reason) == 'string')
        Check('failing migration leaves nothing', tables == 0 and recorded == 0
            and type(failed.details.keptTables) == 'table' and #failed.details.keptTables == 0)
        print('[EconomyMigrationFaultTest] reported: ' .. tostring(failed.message))
        print(('[EconomyMigrationFaultTest] database said: %s (%s)'):format(
            tostring(failed.details and failed.details.reason),
            tostring(failed.details and failed.details.driverCode)))

        local applied = Run(Fault('probe'))
        tables, recorded = State()
        Check('pending migration applied and recorded', applied.ok and applied.value.applied == 1
            and tables == 1 and recorded == 1)
        local rerun = Run(Fault('probe'))
        Check('rerun applies nothing', rerun.ok and rerun.value.applied == 0)
    end, debug.traceback)
    if not called then print('[EconomyMigrationFaultTest] FAIL ' .. tostring(failure)) end
    local cleaned = pcall(Clean)
    local stateRead, tables, recorded = pcall(State)
    Check('probe removed', cleaned and stateRead and tables == 0 and recorded == 0)
    local real = Run()
    Check('real migrations unchanged', real.ok and real.value.applied == 0 and #real.value.unknown == 0)
    local passed, total = Result()
    print(('[EconomyMigrationFaultTest] done %d/%d passed'):format(passed, total))
end, true)

-- Usage: EconomyRestartTest prepare <character UUID|server id> <fresh requestId>
--        (restart the server)
--        EconomyRestartTest verify <same character> <same requestId>
-- prepare pauses the outbox, issues 3.00 to the dollars wallet and transfers 1.00
-- to the system sink, so both events are still pending at restart. verify checks
-- balance, journal, outbox delivery and replay after the restart, then destroys
-- the remaining 2.00 so the wallet finishes at its original balance.
RegisterCommand('EconomyRestartTest', function(source, args)
    if source ~= 0 then return end
    local phase, requestId = args[1], args[3]
    local characterId, reason = EconomyTests.Character(args[2])
    if (phase ~= 'prepare' and phase ~= 'verify') or not characterId or not EconomyTests.RequestId(requestId) then
        print('[EconomyRestartTest] usage: EconomyRestartTest prepare|verify <character UUID|server id> <fresh requestId> '
            .. tostring(reason or ''))
        return
    end
    local key = 'restart-test:' .. requestId
    local context = { resource = 'feather-economy', actorCharacterId = characterId,
        correlationId = 'restart:' .. requestId }
    local function Requests(wallet, sink)
        return {
            issue = { accountId = wallet, currency = 'dollars', amount = 300, reasonCode = 'smoke.restart',
                referenceType = 'smoke', referenceId = requestId, idempotencyKey = requestId .. ':issue' },
            transfer = { fromAccountId = wallet, toAccountId = sink, currency = 'dollars', amount = 100,
                reasonCode = 'smoke.restart', referenceType = 'smoke', referenceId = requestId,
                idempotencyKey = requestId .. ':transfer' }
        }
    end
    local function Events(issueId, transferId, status)
        return tonumber(DB.value([[SELECT COUNT(*) FROM `economy_outbox`
            WHERE `aggregate_id` IN (?,?) AND `status`=?]], issueId, transferId, status)) or -1
    end

    if phase == 'prepare' then
        local paused = false
        local called, failure = xpcall(function()
            assert(GetResourceKvpString(key) == nil, 'requestId already prepared; use a fresh one')
            local wallet = assert(EconomyTests.Wallet(characterId, 'dollars'), 'dollars wallet unavailable')
            local sink = EconomyAPI.GetSystemAccount({ currency = 'dollars', accountType = 'system_sink' },
                'feather-economy')
            assert(sink.ok, 'system sink unavailable')
            -- Let the delivery loop finish its current pass before posting.
            EconomyOutbox.Stop()
            paused = true
            Wait(Config.Outbox.pollIntervalMs * 2 + 500)
            local requests = Requests(wallet.accountId, sink.value.accountId)
            local issued = EconomyJournal.Issue(requests.issue, context)
            assert(issued.ok and not issued.value.replayed, 'issue failed or requestId reused: ' .. tostring(issued.code))
            local transferred = EconomyJournal.Transfer(requests.transfer, context)
            assert(transferred.ok, 'transfer failed: ' .. tostring(transferred.code))
            local after = EconomyAccounts.Get(wallet.accountId)
            local entries = tonumber(DB.value('SELECT COUNT(*) FROM `economy_entries` WHERE `account_id`=?',
                wallet.accountId))
            local pending = Events(issued.value.transactionId, transferred.value.transactionId, 'pending')
            assert(after.ok and after.value.balance == wallet.balance + 200, 'balance after posting is wrong')
            assert(pending == 2, 'expected 2 pending events, found ' .. tostring(pending))
            SetResourceKvp(key, json.encode({
                characterId = characterId, walletId = wallet.accountId, sinkId = sink.value.accountId,
                before = wallet.balance, balance = after.value.balance, entries = entries,
                issueId = issued.value.transactionId, transferId = transferred.value.transactionId,
                preparedAt = os.time()
            }))
            if type(FlushResourceKvp) == 'function' then FlushResourceKvp() end
            print(('[EconomyRestartTest] PREPARED wallet=%s balance=%d entries=%d pendingEvents=2'):format(
                wallet.accountId, after.value.balance, entries))
            print(('[EconomyRestartTest] outbox paused. Restart the server, then run: EconomyRestartTest verify %s %s')
                :format(characterId, requestId))
        end, debug.traceback)
        if not called then
            if paused then EconomyOutbox.Start() end
            print('[EconomyRestartTest] FAIL ' .. tostring(failure))
        end
        return
    end

    local Check, Result = EconomyTests.Counter('EconomyRestartTest')
    local called, failure = xpcall(function()
        -- Run without a restart, the outbox would otherwise stay paused.
        local outbox = EconomyOutbox.GetState()
        if outbox.ok and not outbox.value.running then EconomyOutbox.Start() end
        local stored = GetResourceKvpString(key)
        assert(stored, 'nothing prepared for this requestId')
        local snapshot = json.decode(stored)
        assert(snapshot.characterId == characterId, 'prepared for another character')
        Check('restarted since prepare', EconomyFoundation.GetHealth().startedAt > snapshot.preparedAt)
        local wallet = EconomyAccounts.Get(snapshot.walletId)
        Check('balance preserved', wallet.ok and wallet.value.balance == snapshot.balance)
        local entries = tonumber(DB.value('SELECT COUNT(*) FROM `economy_entries` WHERE `account_id`=?',
            snapshot.walletId))
        Check('journal entries preserved', entries == snapshot.entries)
        local issue = EconomyJournal.GetTransaction(snapshot.issueId)
        local transfer = EconomyJournal.GetTransaction(snapshot.transferId)
        Check('transactions committed', issue ~= nil and issue.status == 'committed' and issue.amount == 300
            and transfer ~= nil and transfer.status == 'committed' and transfer.amount == 100)
        local delivered = false
        for _ = 1, 20 do
            delivered = Events(snapshot.issueId, snapshot.transferId, 'published') == 2
            if delivered then break end
            Wait(500)
        end
        Check('pending events delivered after restart', delivered)
        local requests = Requests(snapshot.walletId, snapshot.sinkId)
        local issueReplay = EconomyJournal.Issue(requests.issue, context)
        local transferReplay = EconomyJournal.Transfer(requests.transfer, context)
        Check('issue replays original', issueReplay.ok and issueReplay.value.replayed == true
            and issueReplay.value.transactionId == snapshot.issueId)
        Check('transfer replays original', transferReplay.ok and transferReplay.value.replayed == true
            and transferReplay.value.transactionId == snapshot.transferId)
        requests.issue.amount = 301
        local conflict = EconomyJournal.Issue(requests.issue, context)
        Check('changed payload rejected', not conflict.ok and conflict.code == 'idempotency_conflict')
        local replayed = EconomyAccounts.Get(snapshot.walletId)
        Check('replays moved nothing', replayed.ok and replayed.value.balance == snapshot.balance)
        local destroyed = EconomyJournal.Destroy({ accountId = snapshot.walletId, currency = 'dollars',
            amount = 200, reasonCode = 'smoke.restart', referenceType = 'smoke', referenceId = requestId,
            idempotencyKey = requestId .. ':destroy' }, context)
        local final = EconomyAccounts.Get(snapshot.walletId)
        Check('test funds removed', destroyed.ok and final.ok and final.value.balance == snapshot.before)
        DeleteResourceKvp(key)
    end, debug.traceback)
    if not called then print('[EconomyRestartTest] FAIL ' .. tostring(failure)) end
    local passed, total = Result()
    print(('[EconomyRestartTest] done %d/%d passed'):format(passed, total))
end, true)
