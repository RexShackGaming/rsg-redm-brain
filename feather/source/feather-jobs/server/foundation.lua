Jobs = {}
local health = { state = 'starting', phase = 'not_started', contract = 1 }

Jobs.MaxRevision = 9007199254740990
Jobs.DutyStates = { off_duty = true, on_duty = true, suspended = true }

function Jobs.RegisterDevCommand(name, handler, restricted)
    if Config.DevMode then RegisterCommand(name, handler, restricted == true) end
end

function Jobs.Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Jobs.Copy(child) end
    return result
end

function Jobs.Ok(value) return { ok = true, value = value } end
function Jobs.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end
local Ok, Err = Jobs.Ok, Jobs.Err

function Jobs.Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value
        and value >= minimum and value <= maximum and value % 1 == 0
end
function Jobs.Uuid(value)
    return type(value) == 'string' and #value == 36
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end
function Jobs.Key(value, maximum)
    return type(value) == 'string' and #value >= 1 and #value <= maximum
        and value:match('^[a-z][a-z0-9_]*$') ~= nil
end
function Jobs.Text(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum
        and not value:find('%c') and value:find('%S') ~= nil
end
function Jobs.Token(value, maximum)
    return type(value) == 'string' and #value >= 1 and #value <= maximum
        and value:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end
function Jobs.Reason(value)
    return type(value) == 'string' and #value >= 1 and #value <= 64
        and value:match('^[a-z][a-z0-9._:%-]*$') ~= nil
end

-- Rejects unknown fields so callers cannot smuggle identity or state.
function Jobs.Fields(request, allowed)
    if type(request) ~= 'table' then return Err('invalid_input', 'Request table required.') end
    for field in pairs(request) do
        if not allowed[field] then
            return Err('invalid_input', 'Unexpected request field.', { field = tostring(field) })
        end
    end
    return Ok(true)
end

-- Shared validation for the optional actor/correlation fields every mutation accepts.
function Jobs.ValidateCommon(request)
    if not Jobs.Token(request.requestId, 128) or not Jobs.Reason(request.reasonCode) then
        return Err('invalid_input', 'Stable request ID and reason code required.')
    end
    if request.actorSource ~= nil and not Jobs.Integer(request.actorSource, 1, 65535) then
        return Err('invalid_input', 'Actor source must be a connected server ID.')
    end
    if request.correlationId ~= nil and not Jobs.Token(request.correlationId, 128) then
        return Err('invalid_input', 'Correlation ID is invalid.')
    end
    -- Optional link to the consumer record behind the change (a membership, an order).
    if (request.referenceType == nil) ~= (request.referenceId == nil)
        or (request.referenceType ~= nil and not Jobs.Key(request.referenceType, 48))
        or (request.referenceId ~= nil and not Jobs.Token(request.referenceId, 128)) then
        return Err('invalid_input', 'Reference type and ID must be given together and be stable keys.')
    end
    return Ok(true)
end

-- Fields every mutation accepts besides its own.
Jobs.CommonFields = {
    requestId = true, reasonCode = true, actorSource = true, correlationId = true,
    referenceType = true, referenceId = true
}
function Jobs.Allowed(extra)
    local result = {}
    for field in pairs(Jobs.CommonFields) do result[field] = true end
    for _, field in ipairs(extra) do result[field] = true end
    return result
end

-- Length-prefixed so labels containing delimiters cannot collide. The optional
-- reference is appended only when given, so receipts stored before references
-- existed keep their fingerprints and still replay.
function Jobs.Fingerprint(operation, request, fields)
    local parts = { operation }
    local function Push(value)
        if value == nil then parts[#parts + 1] = '~'
        else
            value = tostring(value)
            parts[#parts + 1] = tostring(#value) .. ':' .. value
        end
    end
    for _, field in ipairs(fields) do Push(request[field]) end
    if request.referenceType ~= nil then
        Push(request.referenceType)
        Push(request.referenceId)
    end
    return table.concat(parts, '|')
end

function Jobs.SetState(state, phase, failure)
    health.state, health.phase = state, phase
    health.failure = Jobs.Copy(failure)
    print(('[feather-jobs] event=lifecycle.changed state=%s phase=%s'):format(state, phase))
end
function Jobs.Fail(result)
    Jobs.SetState('failed', 'startup_failed', result)
    print(('[feather-jobs] event=startup.failed code=%s message=%s'):format(
        tostring(result.code), tostring(result.message)))
    return result
end
function Jobs.IsReady() return health.state == 'ready' end
function Jobs.GetHealth() return Ok(Jobs.Copy(health)) end
function Jobs.GetCapabilities()
    return Ok({ resource = GetCurrentResourceName(), contract = 1,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        state = health.state, features = {
            lifecycle = 1, health = 1, migrations = 1,
            definitions = 1, grades = 1, assignments = 1,
            multipleAssignments = 1, activeAssignment = Config.ActiveAssignment.enabled and 1 or 0,
            duty = 1, revisions = 1, idempotency = 1, operationLookup = 1,
            outbox = 1, eventPublication = 1, auditHistory = 1,
            employerValidation = 1, clientSnapshot = 1, references = 1,
            societyAdapter = 0, legacyMigration = 0
        } })
end
function Jobs.AwaitReady(timeoutMs)
    if timeoutMs == nil then timeoutMs = Config.ReadinessTimeoutMs end
    if not Jobs.Integer(timeoutMs, 0, 60000) then
        return Err('invalid_input', 'Timeout must be an integer from 0 to 60000 ms.')
    end
    local started = GetGameTimer()
    while health.state ~= 'ready' and health.state ~= 'failed'
        and GetGameTimer() - started < timeoutMs do Wait(50) end
    if health.state == 'ready' then return Jobs.GetHealth() end
    if health.state == 'failed' then
        return Err('startup_failed', 'Jobs failed to start.', { health = Jobs.Copy(health) })
    end
    return Err('not_ready', 'Jobs is not ready.')
end

function Jobs.CheckAccess(group, resource)
    if Config.Access[group][resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not trusted for this operation.', { group = group })
    end
    if health.state ~= 'ready' then return Err('not_ready', 'Jobs is not ready.') end
    if GetResourceState('feather-core') ~= 'started' then
        return Err('dependency_unavailable', 'Core is unavailable.')
    end
    return Ok(true)
end
function Jobs.CheckRead(resource) return Jobs.CheckAccess('trustedReaders', resource) end

-- Service-level policy: fails closed when the provider is missing or indeterminate.
function Jobs.Authorize(action, resource, requestId, subject)
    if not Config.Authorization.enabled then return Ok(true) end
    subject = Jobs.Copy(subject or {})
    subject.resource = resource
    local called, decision = pcall(function()
        return exports['feather-core']:Authorize(action, { correlationId = requestId, subject = subject })
    end)
    if not called or type(decision) ~= 'table' or not decision.ok or type(decision.value) ~= 'table' then
        return Err('policy_unavailable', 'Jobs policy could not be evaluated.', {
            action = action,
            policyCode = type(decision) == 'table' and decision.code or nil
        })
    end
    if decision.value.allowed ~= true then
        -- Provider code/reason say why (e.g. service_forbidden = no grant in the service policy).
        return Err('authorization_denied', 'Jobs policy denied.', {
            action = action,
            policyCode = decision.value.code,
            policyReason = decision.value.reason,
            provider = decision.value.provider
        })
    end
    return Ok(true)
end

-- Actor identity is always derived from Core session context, never supplied.
function Jobs.Actor(request)
    local actor = { correlationId = request.correlationId or request.requestId }
    if request.actorSource == nil then return Ok(actor) end
    local called, session = pcall(function()
        return exports['feather-core']:GetSessionContext(request.actorSource)
    end)
    if not called or type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
        or not Jobs.Uuid(session.value.accountId) or not Jobs.Uuid(session.value.characterId) then
        return Err('actor_unavailable', 'Actor source has no active character session.')
    end
    actor.accountId, actor.characterId = session.value.accountId, session.value.characterId
    return Ok(actor)
end

local function IsCallable(value)
    return type(value) == 'function' or (type(value) == 'table'
        and type(rawget(value, '__cfx_functionReference')) == 'string')
end

-- Character UUIDs must resolve through the Character provider; works offline.
function Jobs.ResolveCharacter(characterId)
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    local implementation = type(provider) == 'table' and provider.ok and provider.value.implementation or nil
    if type(implementation) ~= 'table' or not IsCallable(implementation.GetIdentity) then
        return Err('character_provider_unavailable', 'Character identity provider is unavailable.')
    end
    local identity = implementation.GetIdentity(characterId)
    if type(identity) ~= 'table' or not identity.ok or type(identity.value) ~= 'table'
        or type(identity.value.characterId) ~= 'string' or identity.value.characterId:lower() ~= characterId then
        return Err('character_not_found', 'Character was not found.')
    end
    if identity.value.status ~= 'active' then return Err('character_inactive', 'Character is not active.') end
    return Ok(identity.value)
end

function Jobs.ValidateEmployer(employerType, employerId)
    if employerType == nil and employerId == nil then return Ok(true) end
    local definition = Config.EmployerTypes[employerType or '']
    if not definition or not Jobs.Uuid(employerId) then
        return Err('invalid_input', 'Employer type must be configured and employer ID must be a UUID.')
    end
    if definition.validator ~= 'organizations' then return Ok(true) end
    if GetResourceState('feather-organizations') ~= 'started' then
        return Err('employer_provider_unavailable', 'Organizations is unavailable.')
    end
    local called, result = pcall(function()
        return exports['feather-organizations']:GetOrganization({ organizationId = employerId })
    end)
    if not called or type(result) ~= 'table' then
        return Err('employer_provider_unavailable', 'Organization lookup failed.')
    end
    if not result.ok then
        if result.code == 'organization_not_found' then
            return Err('employer_not_found', 'Employer organization not found.')
        end
        return Err('employer_provider_unavailable', 'Organization lookup failed.', { code = result.code })
    end
    if type(result.value) ~= 'table' or type(result.value.organizationId) ~= 'string'
        or result.value.organizationId:lower() ~= employerId:lower()
        or (result.value.status ~= 'active' and result.value.status ~= 'pending'
            and result.value.status ~= 'suspended' and result.value.status ~= 'dissolving'
            and result.value.status ~= 'dissolved') then
        return Err('employer_provider_unavailable', 'Organization lookup returned invalid identity or status.')
    end
    if result.value.status ~= 'active' then return Err('employer_inactive', 'Employer organization is not active.') end
    return Ok(true)
end

-- Returns a stored result for a completed request, or nil when it must execute.
local function Replay(spec)
    local row = DB.one([[SELECT `operation`,`request_fingerprint`,`result_json` FROM `feather_job_receipts`
        WHERE `source_resource`=? AND `request_id`=?]], spec.resource, spec.requestId)
    if not row or not row.result_json then return nil end
    if row.operation ~= spec.operation or row.request_fingerprint ~= spec.fingerprint then
        return Err('idempotency_conflict', 'Request ID is bound to a different operation or payload.')
    end
    local decoded, value = pcall(json.decode, row.result_json)
    if not decoded or type(value) ~= 'table' then return Err('invalid_persistence', 'Stored receipt is invalid.') end
    value.replayed = true
    return Ok(value)
end

-- Idempotent transactional mutation. precheck runs outside the transaction (provider
-- lookups) and is skipped for completed replays; body runs inside it and must return
-- an envelope whose value is a table. Receipt, state, and audit rows commit together.
function Jobs.Mutate(spec)
    local replayed = Replay(spec)
    if replayed then return replayed end
    local context = {}
    if spec.precheck then
        local checked = spec.precheck()
        if not checked.ok then return checked end
        context = checked.value
    end
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            local inserted = tx.exec([[INSERT IGNORE INTO `feather_job_receipts`
                (`source_resource`,`request_id`,`operation`,`request_fingerprint`) VALUES (?,?,?,?)]],
                spec.resource, spec.requestId, spec.operation, spec.fingerprint)
            -- (perf) A fresh insert is ours and already row-locked by this
            -- transaction, so only an existing receipt needs reading back.
            local receipt
            if tonumber(inserted) == 1 then
                receipt = { operation = spec.operation, request_fingerprint = spec.fingerprint }
            else
                receipt = (tx.query([[SELECT `operation`,`request_fingerprint`,`result_json` FROM `feather_job_receipts`
                    WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], spec.resource, spec.requestId) or {})[1]
            end
            if not receipt then return Err('internal_error', 'Receipt could not be reserved.') end
            if receipt.operation ~= spec.operation or receipt.request_fingerprint ~= spec.fingerprint then
                return Err('idempotency_conflict', 'Request ID is bound to a different operation or payload.')
            end
            if receipt.result_json then
                local decoded, value = pcall(json.decode, receipt.result_json)
                if not decoded or type(value) ~= 'table' then
                    return Err('invalid_persistence', 'Stored receipt is invalid.')
                end
                value.replayed = true
                return Ok(value)
            end
            local outcome = spec.body(tx, context)
            if type(outcome) ~= 'table' or (outcome.ok and type(outcome.value) ~= 'table') then
                error('Jobs mutation body returned an invalid envelope.')
            end
            if outcome.ok then
                outcome.value.replayed = false
                tx.exec([[UPDATE `feather_job_receipts` SET `result_json`=?
                    WHERE `source_resource`=? AND `request_id`=?]],
                    json.encode(outcome.value), spec.resource, spec.requestId)
            end
            return outcome
        end, debug.traceback)
        if not executed then
            print(('[feather-jobs] event=transaction.failed operation=%s reason=%s'):format(
                spec.operation, tostring(outcome)))
            result = Err('internal_error', 'Jobs transaction failed.')
            return false
        end
        result = outcome
        return outcome.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        return Err('transaction_failed', 'Commit was not confirmed. Retry the same request ID.')
    end
    return result or Err('transaction_failed', 'Operation did not complete. Retry the same request ID.')
end

-- (perf) Several server-generated UUIDs (MariaDB UUID()) in one round trip,
-- optionally with the database's current Unix time in seconds, so a row's
-- timestamp and the snapshot returned for it can share one value.
function Jobs.NewIds(tx, count, withNow)
    local columns = {}
    for index = 1, count do columns[#columns + 1] = ('UUID() AS `id%d`'):format(index) end
    if withNow then columns[#columns + 1] = 'UNIX_TIMESTAMP() AS `now_s`' end
    local row = (tx.query('SELECT ' .. table.concat(columns, ',')) or {})[1]
    if not row then error('Could not generate job UUIDs.') end
    local ids = {}
    for index = 1, count do
        local id = row['id' .. index]
        if not Jobs.Uuid(id) then error('Could not generate job UUIDs.') end
        ids[index] = id
    end
    return ids, withNow and math.floor(tonumber(row.now_s) or 0) or nil
end

-- Lets a consumer recover after a timeout: query by its own request ID before retrying.
function Jobs.FindOperation(request, resource)
    local allowed = Jobs.CheckRead(resource)
    if not allowed.ok then return allowed end
    local fields = Jobs.Fields(request, { requestId = true })
    if not fields.ok then return fields end
    if not Jobs.Token(request.requestId, 128) then return Err('invalid_input', 'Request ID required.') end
    local row = DB.one([[SELECT `operation`,`result_json` FROM `feather_job_receipts`
        WHERE `source_resource`=? AND `request_id`=?]], resource, request.requestId)
    if not row or not row.result_json then return Ok({ found = false }) end
    local decoded, value = pcall(json.decode, row.result_json)
    if not decoded or type(value) ~= 'table' then return Err('invalid_persistence', 'Stored receipt is invalid.') end
    value.replayed = true
    return Ok({ found = true, operation = row.operation, result = value })
end

function Jobs.ValidateConfig()
    local self = GetCurrentResourceName()
    if Config.Contract ~= 1 or Config.RequiredCoreContract ~= 1
        or not Jobs.Integer(Config.ReadinessTimeoutMs, 0, 60000)
        or type(Config.DevMode) ~= 'boolean' or type(Config.Access) ~= 'table'
        or type(Config.Authorization) ~= 'table' or type(Config.Authorization.enabled) ~= 'boolean'
        or not Jobs.Reason(Config.Authorization.definitionAction)
        or not Jobs.Reason(Config.Authorization.assignmentAction) then
        return Err('invalid_config', 'Jobs contract, readiness, or authorization configuration is invalid.')
    end
    if type(Config.Outbox) ~= 'table' or not Jobs.Integer(Config.Outbox.pollIntervalMs, 250, 60000)
        or not Jobs.Integer(Config.Outbox.retryDelaySeconds, 1, 3600)
        or not Jobs.Integer(Config.Outbox.batchSize, 1, 100) then
        return Err('invalid_config', 'Outbox configuration is invalid.')
    end
    if type(Config.Assignments) ~= 'table' or not Jobs.Integer(Config.Assignments.maxOpenPerCharacter, 1, 32)
        or type(Config.Assignments.allowForeignJobs) ~= 'boolean'
        or type(Config.ActiveAssignment) ~= 'table' or type(Config.ActiveAssignment.enabled) ~= 'boolean'
        or type(Config.ActiveAssignment.autoSelectFirst) ~= 'boolean'
        or type(Config.Limits) ~= 'table' or not Jobs.Integer(Config.Limits.maxGradesPerJob, 1, 100)
        or not Jobs.Integer(Config.Limits.maxListLimit, 1, 100) then
        return Err('invalid_config', 'Assignment, active selection, or limit configuration is invalid.')
    end
    if type(Config.EmployerTypes) ~= 'table' then return Err('invalid_config', 'Employer types are required.') end
    for key, definition in pairs(Config.EmployerTypes) do
        if not Jobs.Key(key, 32) or type(definition) ~= 'table'
            or (definition.validator ~= false and definition.validator ~= 'organizations') then
            return Err('invalid_config', 'Employer type configuration is invalid.', { employerType = tostring(key) })
        end
    end
    -- Each privileged group requires the matching trusted group.
    local pairsOf = {
        trustedReaders = false,
        trustedRegistrars = false,
        privilegedRegistrars = 'trustedRegistrars',
        trustedAssigners = false,
        privilegedAssigners = 'trustedAssigners',
        trustedAuditors = false,
        privilegedAuditors = 'trustedAuditors'
    }
    for group, parent in pairs(pairsOf) do
        local members = Config.Access[group]
        if type(members) ~= 'table' then return Err('invalid_config', 'Access group missing.', { group = group }) end
        for resource, enabled in pairs(members) do
            if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean'
                or (enabled and parent and Config.Access[parent][resource] ~= true) then
                return Err('invalid_config', 'Access configuration is invalid.', { group = group })
            end
        end
    end
    for _, group in ipairs({ 'trustedReaders', 'trustedRegistrars', 'trustedAssigners', 'trustedAuditors' }) do
        if Config.Access[group][self] ~= true then
            return Err('invalid_config', 'Jobs must trust itself.', { group = group })
        end
    end
    return Ok(true)
end

-- Wraps a public export: derives the caller and converts exceptions to envelopes.
function Jobs.Export(name, operation)
    exports(name, function(request)
        local resource = GetInvokingResource()
        local called, result = xpcall(function() return operation(request, resource) end, debug.traceback)
        if not called then
            print(('[feather-jobs] event=api.failed export=%s reason=%s'):format(name, tostring(result)))
            return Err('internal_error', 'Jobs operation failed.')
        end
        return result
    end)
end

exports('GetHealth', Jobs.GetHealth)
exports('GetCapabilities', Jobs.GetCapabilities)
exports('AwaitReady', Jobs.AwaitReady)
Jobs.Export('FindOperation', Jobs.FindOperation)
