EconomyFoundation = {}

local resourceName = GetCurrentResourceName()
local resourceVersion = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0'
local logger = EconomyLogging.Create('foundation')
local health = {
    state = 'stopped',
    phase = 'not_started',
    contract = 1,
    version = resourceVersion,
    startedAt = os.time(),
    readyAt = nil,
    failure = nil,
    checks = {}
}

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local output = {}
    for key, child in pairs(value) do output[key] = Copy(child) end
    return output
end

local function SetState(state, phase, failure)
    health.state = state
    health.phase = phase or state
    health.failure = failure and Copy(failure) or nil
    if state == 'ready' then health.readyAt = os.time() end
    logger.Info('lifecycle.changed', { state = state, phase = health.phase })
end

local function ValidateConfig()
    if tonumber(Config and Config.Contract) ~= 1 then
        return EconomyResults.Err('invalid_config', 'Config.Contract must equal 1.')
    end
    if tonumber(Config.RequiredCoreContract) ~= 1 then
        return EconomyResults.Err('invalid_config',
            'Config.RequiredCoreContract must equal 1.')
    end
    local limits = Config.Limits
    if type(limits) ~= 'table'
        or type(limits.readinessTimeoutMs) ~= 'number'
        or limits.readinessTimeoutMs < 0 or limits.readinessTimeoutMs > 60000
        or type(limits.maximumPageSize) ~= 'number'
        or limits.maximumPageSize < 1 or limits.maximumPageSize > 500
        or limits.maximumPageSize ~= math.floor(limits.maximumPageSize)
        or type(limits.maximumReasonLength) ~= 'number'
        or limits.maximumReasonLength < 1 or limits.maximumReasonLength > 128
        or type(limits.maximumReferenceLength) ~= 'number'
        or limits.maximumReferenceLength < 1 or limits.maximumReferenceLength > 256
        or type(limits.maximumIdempotencyKeyLength) ~= 'number'
        or limits.maximumIdempotencyKeyLength < 16
        or limits.maximumIdempotencyKeyLength > 256
        or type(limits.maximumTransferAmount) ~= 'number'
        or limits.maximumTransferAmount < 1
        or limits.maximumTransferAmount > 9000000000000000
        or type(limits.maximumBalance) ~= 'number'
        or limits.maximumBalance < limits.maximumTransferAmount
        or limits.maximumBalance > 9000000000000000 then
        return EconomyResults.Err('invalid_config', 'Config.Limits is invalid.')
    end
    local access = Config.Access
    if Config.ReversiblePayments ~= nil then
        if type(Config.ReversiblePayments) ~= 'table' then
            return EconomyResults.Err('invalid_config', 'ReversiblePayments must be a table.')
        end
        for resource, scopes in pairs(Config.ReversiblePayments) do
            if type(resource) ~= 'string' or resource == '' or type(scopes) ~= 'table' then
                return EconomyResults.Err('invalid_config', 'Invalid reversal resource scope.')
            end
            for reason, scope in pairs(scopes) do
                if type(reason) ~= 'string' or #reason > limits.maximumReasonLength or not reason:match('^[a-z][a-z0-9_]*%.[a-z0-9_.]+$')
                    or type(scope) ~= 'table' or type(scope.referenceType) ~= 'string'
                    or #scope.referenceType < 1 or #scope.referenceType > 48
                    or type(scope.reversalReason) ~= 'string' or #scope.reversalReason > limits.maximumReasonLength
                    or not scope.reversalReason:match('^[a-z][a-z0-9_]*%.[a-z0-9_.]+$') then
                    return EconomyResults.Err('invalid_config', 'Invalid reversible payment reason/reference.')
                end
            end
        end
    end
    if type(access) ~= 'table' or type(access.trustedReaders) ~= 'table'
        or type(access.trustedTreasuryProvisioners) ~= 'table'
        or type(access.trustedProvisioners) ~= 'table'
        or type(access.trustedTransactors) ~= 'table'
        or type(access.trustedReversers) ~= 'table'
        or type(access.trustedSuppliers) ~= 'table'
        or access.trustedReaders['feather-economy'] ~= true
        or access.trustedProvisioners['feather-economy'] ~= true
        or access.trustedTransactors['feather-economy'] ~= true
        or access.trustedSuppliers['feather-economy'] ~= true then
        return EconomyResults.Err('invalid_config', 'Config.Access is invalid.')
    end
    if Config.IssueReasons ~= nil and type(Config.IssueReasons) ~= 'table' then
        return EconomyResults.Err('invalid_config', 'Config.IssueReasons is invalid.')
    end
    for resource, reasons in pairs(Config.IssueReasons or {}) do
        if type(resource) ~= 'string' or type(reasons) ~= 'table' then
            return EconomyResults.Err('invalid_config', 'Config.IssueReasons is invalid.', { resource = tostring(resource) })
        end
        for code, allowed in pairs(reasons) do
            if type(code) ~= 'string' or not code:match('^[a-z][a-z0-9_]*%.[a-z0-9_.]+$') or allowed ~= true then
                return EconomyResults.Err('invalid_config', 'Config.IssueReasons lists an invalid reason code.',
                    { resource = resource, reasonCode = tostring(code) })
            end
        end
    end
    local settlement = Config.Settlement
    if (access.trustedSettlers ~= nil and type(access.trustedSettlers) ~= 'table')
        or type(settlement) ~= 'table'
        or type(settlement.reasonCode) ~= 'string' or not settlement.reasonCode:match('^[a-z][a-z0-9_]*%.[a-z0-9_.]+$')
        or type(settlement.referenceType) ~= 'string' or settlement.referenceType == '' then
        return EconomyResults.Err('invalid_config', 'Config.Settlement is invalid.')
    end
    local authorization = Config.Authorization
    if type(authorization) ~= 'table' or type(authorization.enabled) ~= 'boolean'
        or type(authorization.issueAction) ~= 'string' or authorization.issueAction == ''
        or type(authorization.destroyAction) ~= 'string' or authorization.destroyAction == '' then
        return EconomyResults.Err('invalid_config', 'Config.Authorization is invalid.')
    end
    local outbox = Config.Outbox
    if type(outbox) ~= 'table' or type(outbox.pollIntervalMs) ~= 'number'
        or outbox.pollIntervalMs < 250 or outbox.pollIntervalMs > 60000
        or type(outbox.retryDelaySeconds) ~= 'number' or outbox.retryDelaySeconds < 1
        or type(outbox.batchSize) ~= 'number' or outbox.batchSize < 1
        or outbox.batchSize > 100 or outbox.batchSize ~= math.floor(outbox.batchSize) then
        return EconomyResults.Err('invalid_config', 'Config.Outbox is invalid.')
    end
    health.checks.configuration = { ok = true, checkedAt = os.time() }
    return EconomyResults.Ok(true)
end

function EconomyFoundation.BeginStartup()
    SetState('booting', 'validating_configuration')
    local configured = ValidateConfig()
    if not configured.ok then return EconomyFoundation.MarkFailed(
        configured.code, configured.message, configured.details) end

    SetState('waiting', 'waiting_for_core')
    local ready = exports['feather-core']:AwaitReady(Config.Limits.readinessTimeoutMs)
    if type(ready) ~= 'table' or ready.ok ~= true then
        return EconomyFoundation.MarkFailed('dependency_unavailable',
            'Feather Core did not become ready.', {
                dependency = 'feather-core',
                code = type(ready) == 'table' and ready.code or 'invalid_result'
            })
    end
    local capabilities = exports['feather-core']:GetCapabilities()
    local coreContract = type(capabilities) == 'table' and capabilities.ok == true
        and tonumber(capabilities.value and capabilities.value.contract) or 0
    if coreContract < tonumber(Config.RequiredCoreContract) then
        return EconomyFoundation.MarkFailed('dependency_unavailable',
            'Feather Core Contract 1 is required.')
    end
    health.checks.core = { ok = true, checkedAt = os.time(),
        contract = coreContract }
    local declared = exports['feather-core']:DeclareEvent('economy.ready.v1', {
        contract = 1, maxPayloadBytes = 2048, maxDepth = 5, maxNodes = 64
    })
    if type(declared) ~= 'table' or declared.ok ~= true then
        return EconomyFoundation.MarkFailed('dependency_unavailable',
            'Economy could not declare its readiness event.', {
                dependency = 'feather-core',
                code = type(declared) == 'table' and declared.code or 'invalid_result'
            })
    end
    local posted = exports['feather-core']:DeclareEvent('economy.transaction.posted.v1', {
        contract = 1, maxPayloadBytes = 8192, maxDepth = 6, maxNodes = 96
    })
    if type(posted) ~= 'table' or posted.ok ~= true then
        return EconomyFoundation.MarkFailed('dependency_unavailable',
            'Economy could not declare its transaction event.', {
                dependency = 'feather-core',
                code = type(posted) == 'table' and posted.code or 'invalid_result'
            })
    end
    health.checks.events = { ok = true, checkedAt = os.time() }
    SetState('migrating', 'database_migrations')
    return EconomyResults.Ok(true)
end

function EconomyFoundation.MarkMigrationsComplete(details)
    health.checks.migrations = { ok = true, checkedAt = os.time(), details = Copy(details or {}) }
    SetState('starting', 'loading_currency_catalog')
end

function EconomyFoundation.MarkCatalogReady(details)
    health.checks.currencies = { ok = true, checkedAt = os.time(), details = Copy(details or {}) }
end

function EconomyFoundation.MarkAccountsReady(details)
    health.checks.accounts = { ok = true, checkedAt = os.time(), details = Copy(details or {}) }
end

function EconomyFoundation.MarkReady()
    SetState('ready', 'ready')
    return EconomyResults.Ok(EconomyFoundation.GetHealth())
end

function EconomyFoundation.MarkFailed(code, message, details)
    local result = EconomyResults.Err(code, message, details)
    SetState('failed', 'startup_failed', result)
    logger.Error('startup.failed', result)
    return result
end

function EconomyFoundation.GetHealth() return Copy(health) end

function EconomyFoundation.GetCapabilities()
    return EconomyResults.Ok({
        resource = resourceName,
        contract = 1,
        version = resourceVersion,
        state = health.state,
        features = {
            lifecycle = 1,
            health = 1,
            migrations = 1,
            results = 1,
            currencyCatalog = 1,
            accounts = 1,
            organizationTreasuries = 1,
            treasurySettlement = 1,
            organizationSettlement = 1,
            scopedIssue = 1,
            bankAccounts = 1,
            operatedTreasuries = 1,
            accountHistory = 1,
            transactionRead = 1,
            scopedPaymentReversals = 1,
            transfers = 1,
            journal = 1,
            idempotency = 1,
            outbox = 1,
            outboxDelivery = 1,
            supplyOperations = 1
        }
    })
end

function EconomyFoundation.AwaitReady(timeoutMs)
    timeoutMs = tonumber(timeoutMs) or 10000
    if timeoutMs < 0 or timeoutMs > 60000 then
        return EconomyResults.Err('invalid_input',
            'timeoutMs must be between 0 and 60000.')
    end
    local deadline = GetGameTimer() + timeoutMs
    while health.state ~= 'ready' and health.state ~= 'failed'
        and GetGameTimer() < deadline do Wait(0) end
    if health.state == 'ready' then
        return EconomyResults.Ok(EconomyFoundation.GetHealth())
    end
    if health.state == 'failed' then
        return EconomyResults.Err('not_ready', 'Feather Economy failed to start.', {
            health = EconomyFoundation.GetHealth()
        })
    end
    return EconomyResults.Err('timeout',
        'Timed out waiting for Feather Economy readiness.')
end
