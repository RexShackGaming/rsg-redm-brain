ContractsFoundation = {}

local resourceName = GetCurrentResourceName()
local resourceVersion = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0'
local logger = ContractsLogging.Create('foundation')
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

ContractsFoundation.Events = {
    ready = 'contracts.ready.v1',
    issued = 'contracts.obligation.issued.v1',
    accepted = 'contracts.obligation.accepted.v1',
    due = 'contracts.obligation.due.v1',
    settled = 'contracts.obligation.settled.v1',
    cancelled = 'contracts.obligation.cancelled.v1',
    disputed = 'contracts.obligation.disputed.v1',
    dispute_resolved = 'contracts.obligation.dispute_resolved.v1',
    defaulted = 'contracts.obligation.defaulted.v1',
    settlement_failed = 'contracts.settlement.failed.v1'
}

local function Copy(value)
    if type(value) ~= 'table' then return value end
    local output = {}
    for key, child in pairs(value) do output[key] = Copy(child) end
    return output
end
ContractsFoundation.Copy = Copy

local function SetState(state, phase, failure)
    health.state = state
    health.phase = phase or state
    health.failure = failure and Copy(failure) or nil
    if state == 'ready' then health.readyAt = os.time() end
    logger.Info('lifecycle.changed', { state = state, phase = health.phase })
end

local function Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= minimum and value <= maximum
end

local function ValidateConfig()
    if tonumber(Config and Config.Contract) ~= 1 then
        return ContractsResults.Err('invalid_config', 'Config.Contract must equal 1.')
    end
    if tonumber(Config.RequiredCoreContract) ~= 1 or tonumber(Config.RequiredEconomyContract) ~= 1 then
        return ContractsResults.Err('invalid_config',
            'Config.RequiredCoreContract and Config.RequiredEconomyContract must equal 1.')
    end
    if type(Config.DevMode) ~= 'boolean' then
        return ContractsResults.Err('invalid_config', 'Config.DevMode must be a boolean.')
    end
    local limits = Config.Limits
    if type(limits) ~= 'table'
        or not Integer(limits.readinessTimeoutMs, 0, 60000)
        or not Integer(limits.maximumAmount, 1, 9000000000000000)
        or not Integer(limits.maximumPageSize, 1, 100)
        or not Integer(limits.maximumMemoLength, 1, 255)
        or not Integer(limits.maximumReferenceLength, 1, 128)
        or not Integer(limits.maximumRequestIdLength, 16, 128)
        or not Integer(limits.maximumClientRequestIdLength, 16, 64)
        or not Integer(limits.maximumDueSeconds, 60, 315360000)
        or not Integer(limits.maximumTypes, 1, 1024) then
        return ContractsResults.Err('invalid_config', 'Config.Limits is invalid.')
    end
    local access = Config.Access
    if type(access) ~= 'table' or type(access.trustedIssuers) ~= 'table'
        or type(access.trustedReaders) ~= 'table' or type(access.trustedReconcilers) ~= 'table' then
        return ContractsResults.Err('invalid_config', 'Config.Access is invalid.')
    end
    if not Config.DevMode and access.trustedIssuers[resourceName] == true then
        return ContractsResults.Err('invalid_config',
            'feather-contracts may only trust itself as an issuer in DevMode.')
    end
    local authorization = Config.Authorization
    if type(authorization) ~= 'table' or type(authorization.enabled) ~= 'boolean' then
        return ContractsResults.Err('invalid_config', 'Config.Authorization is invalid.')
    end
    for _, field in ipairs({ 'issueAction', 'cancelAction', 'defaultAction' }) do
        local action = authorization[field]
        if type(action) ~= 'string' or not action:match('^[a-z][a-z0-9_.:-]*$') then
            return ContractsResults.Err('invalid_config', 'Config.Authorization actions are invalid.')
        end
    end
    local settlement = Config.Settlement
    if type(settlement) ~= 'table'
        or type(settlement.reasonCode) ~= 'string' or #settlement.reasonCode > 64
        or not settlement.reasonCode:match('^[a-z][a-z0-9._:-]*$')
        or type(settlement.referenceType) ~= 'string' or #settlement.referenceType > 48
        or type(settlement.creditorTypes) ~= 'table'
        or not Integer(settlement.retryDelaySeconds, 1, 3600)
        or not Integer(settlement.maximumAttempts, 1, 1000)
        or not Integer(settlement.verifyBatchSize, 1, 1000) then
        return ContractsResults.Err('invalid_config', 'Config.Settlement is invalid.')
    end
    for key, enabled in pairs(settlement.creditorTypes) do
        if (key ~= 'character' and key ~= 'system' and key ~= 'organization')
            or type(enabled) ~= 'boolean' then
            return ContractsResults.Err('invalid_config', 'Config.Settlement.creditorTypes is invalid.')
        end
    end
    if type(settlement.debtorTypes) ~= 'table' or settlement.debtorTypes.character ~= true then
        return ContractsResults.Err('invalid_config', 'Config.Settlement.debtorTypes must enable character.')
    end
    for key, enabled in pairs(settlement.debtorTypes) do
        if (key ~= 'character' and key ~= 'organization') or type(enabled) ~= 'boolean' then
            return ContractsResults.Err('invalid_config', 'Config.Settlement.debtorTypes is invalid.')
        end
    end
    local scheduler = Config.Scheduler
    if type(scheduler) ~= 'table' or not Integer(scheduler.intervalMs, 1000, 600000)
        or not Integer(scheduler.batchSize, 1, 200) then
        return ContractsResults.Err('invalid_config', 'Config.Scheduler is invalid.')
    end
    local outbox = Config.Outbox
    if type(outbox) ~= 'table' or not Integer(outbox.pollIntervalMs, 250, 60000)
        or not Integer(outbox.retryDelaySeconds, 1, 3600)
        or not Integer(outbox.batchSize, 1, 100) then
        return ContractsResults.Err('invalid_config', 'Config.Outbox is invalid.')
    end
    if type(Config.ClientRoutes) ~= 'table' or type(Config.ClientRoutes.enabled) ~= 'boolean' then
        return ContractsResults.Err('invalid_config', 'Config.ClientRoutes is invalid.')
    end
    health.checks.configuration = { ok = true, checkedAt = os.time() }
    return ContractsResults.Ok(true)
end

local function AwaitDependency(name, contract, features)
    local called, ready = pcall(function()
        return exports[name]:AwaitReady(Config.Limits.readinessTimeoutMs)
    end)
    if not called or type(ready) ~= 'table' or ready.ok ~= true then
        return ContractsResults.Err('dependency_unavailable', ('%s did not become ready.'):format(name), {
            dependency = name,
            code = called and type(ready) == 'table' and ready.code or 'invalid_result'
        })
    end
    local capabilitiesCalled, capabilities = pcall(function()
        return exports[name]:GetCapabilities()
    end)
    local value = capabilitiesCalled and type(capabilities) == 'table' and capabilities.ok == true
        and type(capabilities.value) == 'table' and capabilities.value or nil
    if not value or (tonumber(value.contract) or 0) < contract then
        return ContractsResults.Err('dependency_unavailable',
            ('%s Contract %d is required.'):format(name, contract), { dependency = name })
    end
    for _, feature in ipairs(features or {}) do
        if type(value.features) ~= 'table' or (tonumber(value.features[feature]) or 0) < 1 then
            return ContractsResults.Err('dependency_unavailable',
                ('%s does not provide a required capability.'):format(name), {
                    dependency = name, feature = feature
                })
        end
    end
    health.checks[name] = { ok = true, checkedAt = os.time(), contract = tonumber(value.contract) }
    return ContractsResults.Ok(true)
end

function ContractsFoundation.BeginStartup()
    SetState('booting', 'validating_configuration')
    local configured = ValidateConfig()
    if not configured.ok then return ContractsFoundation.MarkFailed(
        configured.code, configured.message, configured.details) end

    SetState('waiting', 'waiting_for_core')
    local core = AwaitDependency('feather-core', Config.RequiredCoreContract)
    if not core.ok then return ContractsFoundation.MarkFailed(core.code, core.message, core.details) end

    SetState('waiting', 'waiting_for_economy')
    local economyFeatures = { 'currencyCatalog', 'accounts', 'transfers', 'idempotency' }
    if Config.Settlement.creditorTypes.organization == true or Config.Settlement.debtorTypes.organization == true then
        economyFeatures[#economyFeatures + 1] = 'organizationSettlement'
    end
    local economy = AwaitDependency('feather-economy', Config.RequiredEconomyContract, economyFeatures)
    if not economy.ok then return ContractsFoundation.MarkFailed(economy.code, economy.message, economy.details) end

    for key, name in pairs(ContractsFoundation.Events) do
        local declared = exports['feather-core']:DeclareEvent(name, {
            contract = 1,
            maxPayloadBytes = key == 'ready' and 2048 or 8192,
            maxDepth = 4,
            maxNodes = 64
        })
        if type(declared) ~= 'table' or declared.ok ~= true then
            return ContractsFoundation.MarkFailed('dependency_unavailable',
                'Contracts could not declare its events.', {
                    dependency = 'feather-core', event = name,
                    code = type(declared) == 'table' and declared.code or 'invalid_result'
                })
        end
    end
    health.checks.events = { ok = true, checkedAt = os.time() }
    SetState('migrating', 'database_migrations')
    return ContractsResults.Ok(true)
end

function ContractsFoundation.MarkCheck(name, details)
    health.checks[name] = { ok = true, checkedAt = os.time(), details = Copy(details or {}) }
end

function ContractsFoundation.MarkStarting(phase)
    SetState('starting', phase)
end

function ContractsFoundation.MarkReady()
    SetState('ready', 'ready')
    return ContractsResults.Ok(ContractsFoundation.GetHealth())
end

function ContractsFoundation.MarkFailed(code, message, details)
    local result = ContractsResults.Err(code, message, details)
    SetState('failed', 'startup_failed', result)
    logger.Error('startup.failed', result)
    return result
end

function ContractsFoundation.MarkStopping()
    SetState('stopping', 'stopping')
end

function ContractsFoundation.IsReady() return health.state == 'ready' end

function ContractsFoundation.RequireReady()
    if health.state ~= 'ready' then
        return ContractsResults.Err('not_ready', 'Feather Contracts is not ready.')
    end
    return ContractsResults.Ok(true)
end

function ContractsFoundation.GetHealth() return Copy(health) end

function ContractsFoundation.GetCapabilities()
    return ContractsResults.Ok({
        resource = resourceName,
        contract = 1,
        version = resourceVersion,
        state = health.state,
        features = {
            lifecycle = 1,
            health = 1,
            migrations = 1,
            results = 1,
            obligationTypes = 1,
            drafts = 1,
            issuance = 1,
            acceptance = 1,
            queries = 1,
            settlement = 1,
            settlementRecovery = 1,
            reconciliation = 1,
            economyReconciliation = 1,
            cancellation = 1,
            disputes = 1,
            dueProcessing = 1,
            defaults = 1,
            idempotency = 1,
            auditActions = 1,
            outbox = 1,
            clientRoutes = Config.ClientRoutes.enabled and 1 or 0,
            amendments = 0,
            organizationCreditors = Config.Settlement.creditorTypes.organization == true and 1 or 0,
            organizationDebtors = Config.Settlement.debtorTypes.organization == true and 1 or 0
        }
    })
end

function ContractsFoundation.AwaitReady(timeoutMs)
    if timeoutMs == nil then timeoutMs = 10000 end
    if not Integer(timeoutMs, 0, 60000) then
        return ContractsResults.Err('invalid_input',
            'timeoutMs must be an integer between 0 and 60000.')
    end
    local deadline = GetGameTimer() + timeoutMs
    while health.state ~= 'ready' and health.state ~= 'failed'
        and GetGameTimer() < deadline do Wait(50) end
    if health.state == 'ready' then
        return ContractsResults.Ok(ContractsFoundation.GetHealth())
    end
    if health.state == 'failed' then
        return ContractsResults.Err('not_ready', 'Feather Contracts failed to start.', {
            health = ContractsFoundation.GetHealth()
        })
    end
    return ContractsResults.Err('timeout',
        'Timed out waiting for Feather Contracts readiness.')
end
