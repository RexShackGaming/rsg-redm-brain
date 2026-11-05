ContractsScheduler = {}

local Ok, Err = ContractsResults.Ok, ContractsResults.Err
local V = ContractsValidation
local Repo = ContractsObligationRepository
local logger = ContractsLogging.Create('scheduler')
local running = false

-- Every predicate is evaluated by the database clock against persisted
-- timestamps, so a restart neither skips nor repeats a transition.
local duePredicate = [[`settlement_state`='none' AND `due_at` IS NOT NULL AND `due_at` <= CURRENT_TIMESTAMP
    AND ((`status`='issued' AND `requires_acceptance`=0) OR (`status`='accepted' AND `requires_acceptance`=1))]]
local defaultPredicate = [[`settlement_state`='none' AND `status`='due' AND `default_after_seconds` IS NOT NULL
    AND DATE_ADD(`due_at`, INTERVAL `default_after_seconds` SECOND) <= CURRENT_TIMESTAMP]]

local transitions = {
    due = { predicate = duePredicate, status = 'due', eventKey = 'due', actionType = 'due',
        reasonCode = 'contracts.obligation.due', assignments = '' },
    default = { predicate = defaultPredicate, status = 'defaulted', eventKey = 'defaulted',
        actionType = 'defaulted', reasonCode = 'contracts.obligation.overdue_default',
        assignments = ',`defaulted_at`=CURRENT_TIMESTAMP' }
}

local function Apply(obligationId, spec)
    return V.Transaction('scheduler.' .. spec.actionType, function(tx)
        local locked = tx.one('SELECT `obligation_id` FROM `contract_obligations` WHERE `obligation_id`=? AND '
            .. spec.predicate .. ' FOR UPDATE', obligationId)
        if not locked then return Ok(false) end
        local current = Repo.Snapshot(Repo.Lock(tx, obligationId))
        if not current.ok then return current end
        current = current.value
        tx.exec('UPDATE `contract_obligations` SET `status`=?,`revision`=`revision`+1' .. spec.assignments
            .. ' WHERE `obligation_id`=? AND `revision`=?', spec.status, obligationId, current.revision)
        local updated = Repo.Snapshot(Repo.Lock(tx, obligationId))
        if not updated.ok then return updated end
        updated = updated.value
        if updated.status ~= spec.status then
            return Err('transaction_conflict', 'Scheduled transition did not apply.')
        end
        local context = { resource = GetCurrentResourceName(), reasonCode = spec.reasonCode,
            correlationId = ('contracts:scheduler:%s:%s'):format(spec.actionType, obligationId) }
        Repo.RecordAction(tx, obligationId, spec.actionType, current.status, updated.status, updated.revision, context)
        ContractsOutbox.Record(tx, spec.eventKey, obligationId,
            ContractsObligations.EventPayload(updated, current.status, context))
        return Ok(true)
    end)
end

local function ProcessTransition(spec)
    local rows = DB.query('SELECT `obligation_id` FROM `contract_obligations` WHERE ' .. spec.predicate
        .. ' ORDER BY `due_at`,`obligation_id` LIMIT ?', Config.Scheduler.batchSize) or {}
    local applied = 0
    for _, row in ipairs(rows) do
        local result = Apply(row.obligation_id, spec)
        if result.ok and result.value == true then
            applied = applied + 1
        elseif not result.ok then
            logger.Warn('transition.failed', { obligationId = row.obligation_id,
                transition = spec.actionType, code = result.code })
        end
    end
    return applied
end

function ContractsScheduler.RunOnce()
    local due = ProcessTransition(transitions.due)
    local defaulted = ProcessTransition(transitions.default)
    local settlements = ContractsSettlement.ProcessPending(Config.Scheduler.batchSize, false)
    if due > 0 or defaulted > 0 or settlements.processed > 0 then
        logger.Info('pass.completed', { due = due, defaulted = defaulted, settlements = settlements })
    end
    return { due = due, defaulted = defaulted, settlements = settlements }
end

function ContractsScheduler.Start()
    if running then return Err('conflict', 'Contracts scheduler is already running.') end
    running = true
    CreateThread(function()
        while running do
            local ok, failure = pcall(ContractsScheduler.RunOnce)
            if not ok then logger.Error('pass.crashed', { reason = tostring(failure) }) end
            Wait(Config.Scheduler.intervalMs)
        end
    end)
    return Ok(true)
end

function ContractsScheduler.Stop() running = false end

function ContractsScheduler.IsRunning() return running end
