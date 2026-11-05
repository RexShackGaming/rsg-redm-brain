ContractsSettlement = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local V = ContractsValidation
local Repo = ContractsObligationRepository
local logger = ContractsLogging.Create('settlement')

-- Settlement workflow (system of record per step):
--   1. Contracts: one transaction reserves the request receipt, locks the
--      obligation, inserts a pending settlement with a fixed Economy key, and
--      marks the obligation settlement_state='pending'.
--   2. Economy: Transfer with that key. Economy owns the money movement and
--      replays the stored result for a repeated key.
--   3. Contracts: a committed transfer finalizes the obligation as settled in
--      one transaction. A definitive rejection marks the settlement failed. An
--      unknown outcome leaves it pending; the scheduler replays the same key.
-- An unknown outcome is never marked failed: doing so would allow a second
-- settlement while the first transfer may have posted.

local function ViewFor(channel)
    return channel == 'client' and Repo.ClientView or function(value) return value end
end

local function SettlementRow(settlementId)
    return DB.one('SELECT * FROM `contract_settlements` WHERE `settlement_id`=?', settlementId)
end

local function SettlementContext(settlement)
    return {
        resource = settlement.source_resource,
        actorAccountId = settlement.actor_account_id,
        actorCharacterId = settlement.actor_character_id,
        correlationId = settlement.correlation_id,
        requestId = settlement.request_id,
        reasonCode = Config.Settlement.reasonCode
    }
end

local function Finalize(settlementId, transactionId)
    local initial = SettlementRow(settlementId)
    if not initial then return Err('settlement_not_found', 'Settlement was not found.') end
    local view = ViewFor(initial.channel)
    return V.Transaction('settlement.finalize', function(tx)
        -- Lock order matches settlement start: obligation, then settlement.
        local row = Repo.Snapshot(Repo.Lock(tx, initial.obligation_id))
        if not row.ok then return row end
        row = row.value
        local settlement = tx.one('SELECT * FROM `contract_settlements` WHERE `settlement_id`=? FOR UPDATE', settlementId)
        if not settlement then return Err('settlement_not_found', 'Settlement was not found.') end
        if settlement.status == 'committed' then
            local value = view(row)
            value.replayed = true
            return Ok(value)
        end
        if settlement.status ~= 'pending' then
            logger.Error('finalize.state_conflict', { settlementId = settlementId, status = settlement.status,
                transactionId = transactionId })
            return Err('internal_error', 'Settlement state conflicts with a committed Economy transfer.')
        end
        tx.exec([[UPDATE `contract_settlements` SET `status`='committed',`economy_transaction_id`=?,
            `completed_at`=CURRENT_TIMESTAMP,`last_error_code`=NULL WHERE `settlement_id`=?]],
            transactionId, settlementId)
        tx.exec([[UPDATE `contract_obligations` SET `status`='settled',`settled_at`=CURRENT_TIMESTAMP,
            `settlement_transaction_id`=?,`settlement_state`='none',`revision`=`revision`+1
            WHERE `obligation_id`=? AND `revision`=?]], transactionId, row.obligationId, row.revision)
        local updated = Repo.Snapshot(Repo.Lock(tx, row.obligationId))
        if not updated.ok then return updated end
        updated = updated.value
        if updated.status ~= 'settled' or updated.revision ~= row.revision + 1 then
            return Err('transaction_conflict', 'The obligation could not be marked settled.')
        end
        local context = SettlementContext(settlement)
        Repo.RecordAction(tx, updated.obligationId, 'settled', row.status, 'settled', updated.revision,
            context, transactionId)
        ContractsOutbox.Record(tx, 'settled', updated.obligationId,
            ContractsObligations.EventPayload(updated, row.status, context, {
                settlementId = settlementId, economyTransactionId = transactionId,
                initiatedBy = settlement.initiated_by
            }))
        local value = view(updated)
        value.replayed = false
        ContractsReceipts.Complete(tx, settlement.source_resource, 'settle', settlement.request_id, value)
        return Ok(value)
    end)
end

local function MarkFailed(settlementId, code)
    local initial = SettlementRow(settlementId)
    if not initial then return Err('settlement_not_found', 'Settlement was not found.') end
    return V.Transaction('settlement.fail', function(tx)
        local row = Repo.Snapshot(Repo.Lock(tx, initial.obligation_id))
        if not row.ok then return row end
        row = row.value
        local settlement = tx.one('SELECT * FROM `contract_settlements` WHERE `settlement_id`=? FOR UPDATE', settlementId)
        if not settlement or settlement.status ~= 'pending' then return Ok(false) end
        tx.exec([[UPDATE `contract_settlements` SET `status`='failed',`last_error_code`=?,
            `completed_at`=CURRENT_TIMESTAMP WHERE `settlement_id`=?]], code, settlementId)
        tx.exec([[UPDATE `contract_obligations` SET `settlement_state`='none'
            WHERE `obligation_id`=? AND `settlement_state`='pending']], row.obligationId)
        local context = SettlementContext(settlement)
        context.reasonCode = 'contracts.settlement.rejected'
        Repo.RecordAction(tx, row.obligationId, 'settlement_failed', row.status, row.status, row.revision, context)
        ContractsOutbox.Record(tx, 'settlement_failed', row.obligationId,
            ContractsObligations.EventPayload(row, row.status, context, {
                settlementId = settlementId, code = code, initiatedBy = settlement.initiated_by
            }))
        return Ok(true)
    end)
end

local function RejectionResult(settlement)
    local code = settlement.last_error_code or 'settlement_failed'
    return Err(code, 'Economy rejected the settlement. Use a new requestId to try again.', {
        settlementId = settlement.settlement_id
    })
end

-- Advances one settlement. Safe to call concurrently and repeatedly: Economy
-- deduplicates the transfer by key and finalization is guarded by row locks.
function ContractsSettlement.Drive(settlementId)
    local settlement = SettlementRow(settlementId)
    if not settlement then return Err('settlement_not_found', 'Settlement was not found.') end
    if settlement.status == 'committed' then
        local current = Repo.Get(settlement.obligation_id)
        if not current.ok then return current end
        local value = ViewFor(settlement.channel)(current.value)
        value.replayed = true
        return Ok(value)
    end
    if settlement.status == 'failed' then return RejectionResult(settlement) end

    local attempts = (tonumber(settlement.attempts) or 0) + 1
    DB.exec([[UPDATE `contract_settlements` SET `attempts`=`attempts`+1,
        `next_attempt_at`=DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND)
        WHERE `settlement_id`=? AND `status`='pending']],
        Config.Settlement.retryDelaySeconds * math.min(attempts, 8), settlementId)

    local outcome = ContractsEconomy.Settle(settlement)
    outcome = outcome.ok and outcome.value or { outcome = 'unknown', code = outcome.code }
    if outcome.outcome == 'committed' then
        local finalized = Finalize(settlementId, outcome.transactionId)
        if finalized.ok then
            logger.Info('settlement.committed', { settlementId = settlementId,
                obligationId = settlement.obligation_id, transactionId = outcome.transactionId,
                attempts = attempts, replayed = outcome.replayed })
            return finalized
        end
        -- The money moved but the local commit did not confirm. The settlement
        -- stays pending; the next replay returns the same Economy receipt.
        logger.Error('settlement.finalize_failed', { settlementId = settlementId, code = finalized.code })
        return Err('settlement_pending', 'Settlement is being recorded and will complete automatically.', {
            settlementId = settlementId
        })
    end
    if outcome.outcome == 'rejected' then
        local failed = MarkFailed(settlementId, outcome.code)
        if not failed.ok then
            logger.Error('settlement.fail_record_failed', { settlementId = settlementId, code = failed.code })
            return Err('settlement_pending', 'Settlement outcome is being recorded.', { settlementId = settlementId })
        end
        logger.Info('settlement.rejected', { settlementId = settlementId, code = outcome.code })
        return RejectionResult({ settlement_id = settlementId, last_error_code = outcome.code })
    end
    DB.exec([[UPDATE `contract_settlements` SET `last_error_code`=?
        WHERE `settlement_id`=? AND `status`='pending']], tostring(outcome.code or 'unknown'):sub(1, 64), settlementId)
    if attempts >= Config.Settlement.maximumAttempts then
        logger.Error('settlement.stuck', { settlementId = settlementId, attempts = attempts, code = outcome.code })
    else
        logger.Warn('settlement.deferred', { settlementId = settlementId, attempts = attempts, code = outcome.code })
    end
    return Err('settlement_pending', 'Settlement outcome is unknown; it will be retried automatically.', {
        settlementId = settlementId
    })
end

-- context is prebuilt by the API layer. Client routes set channel='client',
-- receiptResource and receiptRequestId (scoped to the character).
function ContractsSettlement.SettleObligation(request, context, resource, viaClient)
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local fields = V.Fields(request, { requestId = true, obligationId = true }, 'settle')
    if not fields.ok then return fields end
    if not V.RequestId(request.requestId, Config.Limits.maximumRequestIdLength) or not V.Uuid(request.obligationId) then
        return Err('invalid_input', 'Stable requestId and obligation UUID are required.')
    end
    local obligationId = request.obligationId:lower()
    local receiptResource = context.receiptResource or resource
    local receiptRequestId = context.receiptRequestId or request.requestId
    local channel = viaClient and 'client' or 'server'

    local existing = DB.one([[SELECT `settlement_id`,`obligation_id` FROM `contract_settlements`
        WHERE `source_resource`=? AND `request_id`=?]], receiptResource, receiptRequestId)
    if existing then
        if existing.obligation_id ~= obligationId then
            return Err('idempotency_conflict', 'Request ID was already used to settle a different obligation.')
        end
        return ContractsSettlement.Drive(existing.settlement_id)
    end

    local current = Repo.Get(obligationId)
    if not current.ok then return current end
    current = current.value
    local initiatedBy
    if current.debtor.type == 'organization' then
        -- Only the resource operating the debtor's treasury pays from it; Economy
        -- enforces the same binding on the transfer.
        if viaClient then return Err('obligation_not_found', 'Obligation was not found.') end
        if ContractsEconomy.TreasuryOperator(current.debtor.id, current.currency) ~= resource then
            return Err('settlement_not_allowed',
                'Only the resource operating the debtor treasury may pay this obligation.')
        end
        if not current.debtorMaySettle then
            return Err('settlement_not_allowed', 'This obligation cannot be paid directly by the debtor.')
        end
        initiatedBy = 'debtor'
    elseif viaClient then
        if context.actorCharacterId ~= current.debtor.id then
            return Err('obligation_not_found', 'Obligation was not found.')
        end
        if not current.debtorMaySettle then
            return Err('settlement_not_allowed', 'This obligation cannot be paid directly by the debtor.')
        end
        initiatedBy = 'debtor'
    else
        if ContractsTypes.Owner(current.obligationType) ~= resource then
            return Err('authorization_denied', 'Only the owning resource may settle this obligation.')
        end
        if context.actorCharacterId ~= nil and context.actorCharacterId == current.debtor.id
            and current.debtorMaySettle then
            initiatedBy = 'debtor'
        elseif current.issuerMaySettle then
            initiatedBy = 'issuer'
        else
            return Err('settlement_not_allowed',
                'Settlement requires the debtor as actor, or an obligation type that allows issuer settlement.')
        end
    end
    local wallet = ContractsEconomy.ResolveDebtorAccount(current.debtor, current.currency)
    if not wallet.ok then
        return Err('debtor_account_unavailable', 'The debtor has no open account in that currency.', {
            code = wallet.code
        })
    end
    local fingerprint = V.Fingerprint({ obligationId, initiatedBy })

    local started = V.Transaction('settlement.begin', function(tx)
        local reserved = ContractsReceipts.Reserve(tx, receiptResource, 'settle', receiptRequestId, fingerprint)
        if not reserved.ok then return reserved end
        if reserved.value.replay then return Ok({ replay = reserved.value.replay }) end
        local raced = tx.one([[SELECT `settlement_id`,`obligation_id` FROM `contract_settlements`
            WHERE `source_resource`=? AND `request_id`=?]], receiptResource, receiptRequestId)
        if raced then
            if raced.obligation_id ~= obligationId then
                return Err('idempotency_conflict', 'Request ID was already used to settle a different obligation.')
            end
            return Ok({ settlementId = raced.settlement_id })
        end

        local row = Repo.Snapshot(Repo.Lock(tx, obligationId))
        if not row.ok then return row end
        row = row.value
        if not ContractsTypes.Allows(row.transitions, 'settle', row.status) then
            return Err('invalid_state', 'The obligation cannot be settled from its current status.', {
                status = row.status
            })
        end
        if row.settlementState == 'pending' then
            return Err('settlement_pending', 'A settlement for this obligation is already in progress.')
        end
        if not V.Uuid(row.creditorAccountId) or wallet.value.accountId == row.creditorAccountId then
            return Err('invalid_persistence', 'The obligation has no valid frozen creditor account.')
        end
        local settlementId = V.NewUuid(tx)
        tx.exec([[INSERT INTO `contract_settlements`
            (`settlement_id`,`obligation_id`,`status`,`initiated_by`,`channel`,`payer_account_id`,
             `payee_account_id`,`amount`,`currency`,`economy_idempotency_key`,`source_resource`,
             `actor_account_id`,`actor_character_id`,`correlation_id`,`request_id`)
            VALUES (?,?,'pending',?,?,?,?,?,?,?,?,?,?,?,?)]],
            settlementId, obligationId, initiatedBy, channel, wallet.value.accountId, row.creditorAccountId,
            row.amount, row.currency, 'contracts:settle:' .. settlementId, receiptResource,
            context.actorAccountId, context.actorCharacterId,
            context.correlationId or ('contracts:settle:' .. settlementId), receiptRequestId)
        tx.exec([[UPDATE `contract_obligations` SET `settlement_state`='pending' WHERE `obligation_id`=?]], obligationId)
        local audit = {
            resource = receiptResource, actorAccountId = context.actorAccountId,
            actorCharacterId = context.actorCharacterId, correlationId = context.correlationId,
            requestId = receiptRequestId, reasonCode = 'contracts.settlement.started'
        }
        Repo.RecordAction(tx, obligationId, 'settlement_started', row.status, row.status, row.revision, audit)
        return Ok({ settlementId = settlementId })
    end)
    if not started.ok then return started end
    if started.value.replay then return Ok(started.value.replay) end
    return ContractsSettlement.Drive(started.value.settlementId)
end

function ContractsSettlement.ProcessPending(limit, force)
    local sql = [[SELECT `settlement_id` FROM `contract_settlements` WHERE `status`='pending']]
    if not force then sql = sql .. ' AND `next_attempt_at` <= CURRENT_TIMESTAMP' end
    sql = sql .. ' ORDER BY `next_attempt_at`,`settlement_id` LIMIT ?'
    local rows = DB.query(sql, limit) or {}
    local summary = { processed = 0, committed = 0, rejected = 0, pending = 0 }
    for _, row in ipairs(rows) do
        local result = ContractsSettlement.Drive(row.settlement_id)
        summary.processed = summary.processed + 1
        if result.ok then summary.committed = summary.committed + 1
        elseif result.code == 'settlement_pending' then summary.pending = summary.pending + 1
        else summary.rejected = summary.rejected + 1 end
    end
    return summary
end

local function Count(sql)
    return tonumber(DB.value(sql)) or -1
end

-- Integrity report between obligations and their settlement records. These
-- invariants are written together in single transactions, so any non-zero
-- count indicates manual database edits or a defect and needs operator review.
function ContractsSettlement.Audit()
    return {
        settledWithoutCommittedSettlement = Count([[
            SELECT COUNT(*) FROM `contract_obligations` o
            LEFT JOIN `contract_settlements` s ON s.`obligation_id`=o.`obligation_id`
              AND s.`status`='committed' AND s.`economy_transaction_id`=o.`settlement_transaction_id`
            WHERE o.`status`='settled' AND s.`settlement_id` IS NULL]]),
        committedSettlementNotSettled = Count([[
            SELECT COUNT(*) FROM `contract_settlements` s
            JOIN `contract_obligations` o ON o.`obligation_id`=s.`obligation_id`
            WHERE s.`status`='committed' AND o.`status`<>'settled']]),
        pendingFlagWithoutSettlement = Count([[
            SELECT COUNT(*) FROM `contract_obligations` o
            WHERE o.`settlement_state`='pending' AND NOT EXISTS (
              SELECT 1 FROM `contract_settlements` s
              WHERE s.`obligation_id`=o.`obligation_id` AND s.`status`='pending')]]),
        pendingSettlementWithoutFlag = Count([[
            SELECT COUNT(*) FROM `contract_settlements` s
            JOIN `contract_obligations` o ON o.`obligation_id`=s.`obligation_id`
            WHERE s.`status`='pending' AND o.`settlement_state`<>'pending']]),
        multipleCommitted = Count([[
            SELECT COUNT(*) FROM (SELECT `obligation_id` FROM `contract_settlements`
              WHERE `status`='committed' GROUP BY `obligation_id` HAVING COUNT(*) > 1) duplicates]]),
        amountMismatch = Count([[
            SELECT COUNT(*) FROM `contract_settlements` s
            JOIN `contract_obligations` o ON o.`obligation_id`=s.`obligation_id`
            WHERE s.`amount`<>o.`amount` OR s.`currency`<>o.`currency`
               OR s.`payee_account_id`<>o.`creditor_account_id`]]),
        economyMismatch = Count([[SELECT COUNT(*) FROM `contract_settlements`
            WHERE `status`='committed' AND `economy_check` IN ('mismatch','missing')]]),
        economyUnverified = Count([[SELECT COUNT(*) FROM `contract_settlements`
            WHERE `status`='committed' AND `economy_check` IS NULL]]),
        pendingSettlements = Count("SELECT COUNT(*) FROM `contract_settlements` WHERE `status`='pending'"),
        stuckSettlements = Count(([[SELECT COUNT(*) FROM `contract_settlements`
            WHERE `status`='pending' AND `attempts` >= %d]]):format(Config.Settlement.maximumAttempts))
    }
end

-- Compares one committed settlement with the Economy transaction it recorded.
local function CheckAgainstJournal(settlement)
    local found = ContractsEconomy.GetTransaction(settlement.economy_transaction_id)
    if not found.ok then
        if found.code == 'transaction_not_found' then return 'missing' end
        return nil, found.code
    end
    local tx = found.value
    local paid, received = false, false
    for _, entry in ipairs(type(tx.entries) == 'table' and tx.entries or {}) do
        local amount = tonumber(entry.amount)
        if entry.accountId == settlement.payer_account_id and amount == -tonumber(settlement.amount) then paid = true end
        if entry.accountId == settlement.payee_account_id and amount == tonumber(settlement.amount) then received = true end
    end
    local matches = tx.status == 'committed' and tx.operation == 'transfer'
        and tx.reasonCode == Config.Settlement.reasonCode and tx.referenceType == Config.Settlement.referenceType
        and tx.referenceId == settlement.obligation_id and tx.currency == settlement.currency
        and tonumber(tx.amount) == tonumber(settlement.amount)
        and type(tx.entries) == 'table' and #tx.entries == 2 and paid and received
    return matches and 'verified' or 'mismatch'
end

-- Checks committed settlements not yet compared with Economy's journal. Each
-- result is stored, so every settlement is fetched from Economy once.
function ContractsSettlement.VerifyWithEconomy(limit)
    if not ContractsEconomy.CanReadTransactions() then
        return { available = false, checked = 0, verified = 0, mismatch = 0, missing = 0 }
    end
    local summary = { available = true, checked = 0, verified = 0, mismatch = 0, missing = 0, deferred = 0 }
    local rows = DB.query([[SELECT `settlement_id`,`obligation_id`,`payer_account_id`,`payee_account_id`,`amount`,
            `currency`,`economy_transaction_id` FROM `contract_settlements`
        WHERE `status`='committed' AND `economy_check` IS NULL ORDER BY `completed_at`,`settlement_id` LIMIT ?]],
        limit) or {}
    for _, row in ipairs(rows) do
        local outcome, code = CheckAgainstJournal(row)
        if outcome then
            DB.exec([[UPDATE `contract_settlements` SET `economy_check`=?,`economy_checked_at`=CURRENT_TIMESTAMP
                WHERE `settlement_id`=? AND `economy_check` IS NULL]], outcome, row.settlement_id)
            summary.checked = summary.checked + 1
            summary[outcome] = summary[outcome] + 1
            if outcome ~= 'verified' then
                logger.Error('settlement.journal_' .. outcome, { settlementId = row.settlement_id,
                    obligationId = row.obligation_id, transactionId = row.economy_transaction_id })
            end
        else
            summary.deferred = summary.deferred + 1
            logger.Warn('settlement.journal_unavailable', { settlementId = row.settlement_id, code = code })
        end
    end
    return summary
end

function ContractsSettlement.Reconcile(resource)
    if resource ~= GetCurrentResourceName() and Config.Access.trustedReconcilers[resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not a trusted reconciler.')
    end
    local ready = ContractsFoundation.RequireReady()
    if not ready.ok then return ready end
    local processed = ContractsSettlement.ProcessPending(Config.Scheduler.batchSize, true)
    local journal = ContractsSettlement.VerifyWithEconomy(Config.Settlement.verifyBatchSize)
    local audit = ContractsSettlement.Audit()
    local healthy = true
    for key, value in pairs(audit) do
        if key ~= 'pendingSettlements' and key ~= 'stuckSettlements' and key ~= 'economyUnverified'
            and value ~= 0 then healthy = false end
    end
    return Ok({ processed = processed, journal = journal, audit = audit, healthy = healthy })
end
