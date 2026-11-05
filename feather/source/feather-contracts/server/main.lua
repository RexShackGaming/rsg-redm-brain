local logger = ContractsLogging.Create('main')

local function Fail(result)
    local failure = type(result) == 'table' and result
        or ContractsResults.Err('internal_error', 'Contracts startup returned an invalid result.')
    logger.Error('startup.aborted', {
        code = failure.code,
        message = failure.message,
        details = failure.details
    })
    error(failure.message or 'Feather Contracts startup failed.')
end

local function Step(result, phase)
    if not result.ok then
        return false, ContractsFoundation.MarkFailed(result.code, result.message, result.details)
    end
    if phase then ContractsFoundation.MarkCheck(phase, result.value) end
    return true
end

CreateThread(function()
    local started = ContractsFoundation.BeginStartup()
    if not started.ok then return Fail(started) end

    local ok, failure = Step(ContractsMigrationRunner.Run(), 'migrations')
    if not ok then return Fail(failure) end

    ContractsFoundation.MarkStarting('loading_obligation_types')
    ok, failure = Step(ContractsTypes.Load(), 'types')
    if not ok then return Fail(failure) end

    ok, failure = Step(ContractsOutbox.Start(), 'outbox')
    if not ok then return Fail(failure) end

    ok, failure = Step(ContractsRoutes.Register(), 'routes')
    if not ok then return Fail(failure) end

    ContractsFoundation.MarkReady()
    -- The scheduler starts after readiness so it can resume pending settlements
    -- and overdue transitions left by a previous run.
    ok, failure = Step(ContractsScheduler.Start(), 'scheduler')
    if not ok then return Fail(failure) end

    local total, active = ContractsTypes.Count()
    logger.Info('startup.ready', { contract = 1, types = total, activeTypes = active,
        clientRoutes = Config.ClientRoutes.enabled, devMode = Config.DevMode })
    local published = exports['feather-core']:PublishEvent(ContractsFoundation.Events.ready, {
        contract = 1,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'
    })
    if type(published) ~= 'table' or published.ok ~= true then
        logger.Warn('readiness.publish_failed', {
            code = type(published) == 'table' and published.code or 'invalid_result'
        })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        ContractsFoundation.MarkStopping()
        ContractsScheduler.Stop()
        ContractsOutbox.Stop()
        logger.Info('lifecycle.stopped')
    end
end)

RegisterCommand('ContractsReconcile', function(source)
    if source ~= 0 then return end
    local result = ContractsSettlement.Reconcile(GetCurrentResourceName())
    if not result.ok then
        print(('[ContractsReconcile] FAIL code=%s'):format(tostring(result.code)))
        return
    end
    local processed, audit = result.value.processed, result.value.audit
    print(('[ContractsReconcile] settlements processed=%d committed=%d rejected=%d stillPending=%d')
        :format(processed.processed, processed.committed, processed.rejected, processed.pending))
    local journal = result.value.journal
    if journal.available then
        print(('[ContractsReconcile] economy journal checked=%d verified=%d mismatch=%d missing=%d deferred=%d')
            :format(journal.checked, journal.verified, journal.mismatch, journal.missing, journal.deferred))
    else
        print('[ContractsReconcile] economy journal unavailable (feather-economy has no transactionRead)')
    end
    local keys = {}
    for key in pairs(audit) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        print(('[ContractsReconcile] %-36s %s'):format(key, tostring(audit[key])))
    end
    print(('[ContractsReconcile] %s'):format(result.value.healthy and 'HEALTHY'
        or 'ATTENTION: integrity counts above must be zero; review before further settlement'))
end, true)
