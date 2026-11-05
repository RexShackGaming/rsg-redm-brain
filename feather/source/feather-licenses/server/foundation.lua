Licenses = {}
local health = { state = 'starting', phase = 'not_started', contract = 1 }

Licenses.MaxRevision = 9007199254740990

-- Stored statuses. 'expired' is never stored: it is computed from expiresAt at
-- read time, so validity never waits for a sweep. 'revoked' is terminal.
Licenses.Statuses = {
    active = true,
    suspended = true,
    revoked = true
}

Licenses.IssuerTypes = {
    system = true,
    character = true,
    organization = true
}

function Licenses.RegisterDevCommand(name, handler, restricted)
    if Config.DevMode then
        RegisterCommand(name, handler, restricted == true)
    end
end

function Licenses.Copy(value)
    if type(value) ~= 'table' then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = Licenses.Copy(child)
    end
    return result
end

function Licenses.Ok(value)
    return { ok = true, value = value }
end

function Licenses.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end

local Ok, Err = Licenses.Ok, Licenses.Err

-- Validators -------------------------------------------------------------------

function Licenses.Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value
        and value >= minimum and value <= maximum and value % 1 == 0
end

function Licenses.Uuid(value)
    return type(value) == 'string' and #value == 36
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

function Licenses.Key(value, maximum)
    return type(value) == 'string' and #value >= 1 and #value <= maximum
        and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

function Licenses.Label(value)
    return type(value) == 'string' and #value > 0 and #value <= 100
        and not value:find('%c') and value:find('%S') ~= nil
end

function Licenses.Token(value, maximum)
    return type(value) == 'string' and #value >= 1 and #value <= maximum
        and value:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end

function Licenses.Reason(value)
    return type(value) == 'string' and #value >= 1 and #value <= 64
        and value:match('^[a-z][a-z0-9._:%-]*$') ~= nil
end

-- Rejects unknown fields so callers cannot smuggle identity or state.
function Licenses.Fields(request, allowed)
    if type(request) ~= 'table' then
        return Err('invalid_input', 'Request table required.')
    end
    for field in pairs(request) do
        if not allowed[field] then
            return Err('invalid_input', 'Unexpected request field.', { field = tostring(field) })
        end
    end
    return Ok(true)
end

local common = {
    requestId = true,
    reasonCode = true,
    actorSource = true,
    correlationId = true,
    referenceType = true,
    referenceId = true
}

-- Allowed-field set for a mutation: the common fields plus its own.
function Licenses.Allowed(extra)
    local result = {}
    for field in pairs(common) do
        result[field] = true
    end
    for _, field in ipairs(extra) do
        result[field] = true
    end
    return result
end

-- Shared validation for the actor, correlation and reference fields every mutation accepts.
function Licenses.ValidateCommon(request)
    if not Licenses.Token(request.requestId, 128) or not Licenses.Reason(request.reasonCode) then
        return Err('invalid_input', 'Stable request ID and reason code required.')
    end
    if request.actorSource ~= nil and not Licenses.Integer(request.actorSource, 1, 65535) then
        return Err('invalid_input', 'Actor source must be a connected server ID.')
    end
    if request.correlationId ~= nil and not Licenses.Token(request.correlationId, 128) then
        return Err('invalid_input', 'Correlation ID is invalid.')
    end
    -- Optional link to the consumer record behind the change (an order, a document).
    if (request.referenceType == nil) ~= (request.referenceId == nil)
        or (request.referenceType ~= nil and not Licenses.Key(request.referenceType, 48))
        or (request.referenceId ~= nil and not Licenses.Token(request.referenceId, 128)) then
        return Err('invalid_input', 'Reference type and ID must be given together and be stable keys.')
    end
    return Ok(true)
end

-- Shared prologue: trusted group and field/shape validation.
function Licenses.Begin(request, resource, group, allowedFields)
    local allowed = Licenses.CheckAccess(group, resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Licenses.Fields(request, allowedFields)
    if not fields.ok then
        return fields
    end
    return Licenses.ValidateCommon(request)
end

-- Scope ------------------------------------------------------------------------
-- What a license covers (weapon classes, regions) is generic consumer JSON: an
-- object of identifier keys whose values are strings, finite numbers, booleans,
-- arrays or objects.

local function IsArray(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then
            return false
        end
        count = count + 1
    end
    for index = 1, count do
        if value[index] == nil then
            return false
        end
    end
    return true
end

local function WalkScope(value, depth, budget)
    local kind = type(value)
    if kind == 'string' then
        return #value <= Config.Limits.maxScopeString
    elseif kind == 'number' then
        return value == value and value ~= math.huge and value ~= -math.huge
    elseif kind == 'boolean' then
        return true
    elseif kind ~= 'table' or depth > Config.Limits.maxScopeDepth then
        return false
    end
    local array = IsArray(value)
    for key, child in pairs(value) do
        budget.nodes = budget.nodes + 1
        if budget.nodes > Config.Limits.maxScopeNodes then
            return false
        end
        if not array and (type(key) ~= 'string' or #key > 64
            or key:match('^[A-Za-z_][A-Za-z0-9_]*$') == nil) then
            return false
        end
        if not WalkScope(child, depth + 1, budget) then
            return false
        end
    end
    return true
end

function Licenses.ValidateScope(scope)
    if type(scope) ~= 'table' or (next(scope) ~= nil and IsArray(scope)) then
        return Err('invalid_scope', 'Scope must be an object.')
    end
    if not WalkScope(scope, 1, { nodes = 0 }) then
        return Err('invalid_scope', 'Scope exceeds depth, size or type limits.', {
            maxDepth = Config.Limits.maxScopeDepth,
            maxNodes = Config.Limits.maxScopeNodes
        })
    end
    local encoded = next(scope) == nil and '{}' or json.encode(scope)
    if type(encoded) ~= 'string' or #encoded > Config.Limits.maxScopeBytes then
        return Err('invalid_scope', 'Scope is too large.', { maxBytes = Config.Limits.maxScopeBytes })
    end
    return Ok(encoded)
end

-- Deterministic serialization, so the same scope always yields the same
-- idempotency fingerprint regardless of table iteration order.
function Licenses.Canonical(value)
    local kind = type(value)
    if kind ~= 'table' then
        return kind:sub(1, 1) .. ':' .. tostring(value)
    end
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    local parts = {}
    for _, key in ipairs(keys) do
        local name = tostring(key)
        parts[#parts + 1] = #name .. ':' .. name .. '=' .. Licenses.Canonical(value[key])
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

-- Length-prefixed so values containing delimiters cannot collide. The optional
-- reference is appended only when given.
function Licenses.Fingerprint(operation, request, fields)
    local parts = { operation }
    local function Push(value)
        if value == nil then
            parts[#parts + 1] = '~'
        else
            value = tostring(value)
            parts[#parts + 1] = tostring(#value) .. ':' .. value
        end
    end
    for _, field in ipairs(fields) do
        Push(request[field])
    end
    if request.referenceType ~= nil then
        Push(request.referenceType)
        Push(request.referenceId)
    end
    return table.concat(parts, '|')
end

-- Lifecycle --------------------------------------------------------------------

function Licenses.SetState(state, phase, failure)
    health.state = state
    health.phase = phase
    health.failure = Licenses.Copy(failure)
    print(('[feather-licenses] event=lifecycle.changed state=%s phase=%s'):format(state, phase))
end

function Licenses.Fail(result)
    Licenses.SetState('failed', 'startup_failed', result)
    print(('[feather-licenses] event=startup.failed code=%s message=%s'):format(
        tostring(result.code), tostring(result.message)))
    return result
end

function Licenses.IsReady()
    return health.state == 'ready'
end

function Licenses.GetHealth()
    return Ok(Licenses.Copy(health))
end

function Licenses.GetCapabilities()
    local holderTypes = {}
    for key in pairs(Config.HolderTypes) do
        holderTypes[#holderTypes + 1] = key
    end
    table.sort(holderTypes)
    return Ok({
        resource = GetCurrentResourceName(),
        contract = 1,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        state = health.state,
        holderTypes = holderTypes,
        issuerTypes = { 'character', 'organization', 'system' },
        features = {
            lifecycle = 1,
            health = 1,
            migrations = 1,
            definitions = 1,
            issuance = 1,
            check = 1,
            renewal = 1,
            suspension = 1,
            revocation = 1,
            expiry = 1,
            expiryEvents = 1,
            scope = 1,
            revisions = 1,
            idempotency = 1,
            operationLookup = 1,
            outbox = 1,
            eventPublication = 1,
            auditHistory = 1,
            references = 1,
            holderValidation = 1,
            clientSnapshot = 1
        }
    })
end

function Licenses.AwaitReady(timeoutMs)
    if timeoutMs == nil then
        timeoutMs = Config.ReadinessTimeoutMs
    end
    if not Licenses.Integer(timeoutMs, 0, 60000) then
        return Err('invalid_input', 'Timeout must be an integer from 0 to 60000 ms.')
    end
    local started = GetGameTimer()
    while health.state ~= 'ready' and health.state ~= 'failed'
        and GetGameTimer() - started < timeoutMs do
        Wait(50)
    end
    if health.state == 'ready' then
        return Licenses.GetHealth()
    end
    if health.state == 'failed' then
        return Err('startup_failed', 'Licenses failed to start.', { health = Licenses.Copy(health) })
    end
    return Err('not_ready', 'Licenses is not ready.')
end

-- Access and policy ------------------------------------------------------------

function Licenses.CheckAccess(group, resource)
    if Config.Access[group][resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not trusted for this operation.', { group = group })
    end
    if health.state ~= 'ready' then
        return Err('not_ready', 'Licenses is not ready.')
    end
    if GetResourceState('feather-core') ~= 'started' then
        return Err('dependency_unavailable', 'Core is unavailable.')
    end
    return Ok(true)
end

function Licenses.CheckRead(resource)
    return Licenses.CheckAccess('trustedReaders', resource)
end

-- Service-level policy: fails closed when the provider is missing or indeterminate.
function Licenses.Authorize(action, resource, requestId, subject)
    if not Config.Authorization.enabled then
        return Ok(true)
    end
    subject = Licenses.Copy(subject or {})
    subject.resource = resource
    local called, decision = pcall(function()
        return exports['feather-core']:Authorize(action, { correlationId = requestId, subject = subject })
    end)
    if not called or type(decision) ~= 'table' or not decision.ok or type(decision.value) ~= 'table' then
        return Err('policy_unavailable', 'Licenses policy could not be evaluated.', {
            action = action,
            policyCode = type(decision) == 'table' and decision.code or nil
        })
    end
    if decision.value.allowed ~= true then
        -- Provider code/reason say why (e.g. service_forbidden = no grant in the service policy).
        return Err('authorization_denied', 'Licenses policy denied.', {
            action = action,
            policyCode = decision.value.code,
            policyReason = decision.value.reason,
            provider = decision.value.provider
        })
    end
    return Ok(true)
end

-- Actor identity is always derived from Core session context, never supplied.
function Licenses.Actor(request)
    local actor = { correlationId = request.correlationId or request.requestId }
    if request.actorSource == nil then
        return Ok(actor)
    end
    local called, session = pcall(function()
        return exports['feather-core']:GetSessionContext(request.actorSource)
    end)
    if not called or type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
        or not Licenses.Uuid(session.value.accountId) or not Licenses.Uuid(session.value.characterId) then
        return Err('actor_unavailable', 'Actor source has no active character session.')
    end
    actor.accountId = session.value.accountId
    actor.characterId = session.value.characterId:lower()
    return Ok(actor)
end

-- Service policy, then the server-derived actor recorded on audit facts.
function Licenses.Policy(action, request, resource, subject)
    local policy = Licenses.Authorize(action, resource, request.requestId, subject)
    if not policy.ok then
        return policy
    end
    return Licenses.Actor(request)
end

-- Holders and issuers ----------------------------------------------------------

local function IsCallable(value)
    return type(value) == 'function' or (type(value) == 'table'
        and type(rawget(value, '__cfx_functionReference')) == 'string')
end

-- Character UUIDs must resolve through the Character provider; works offline.
local function ResolveCharacter(characterId)
    local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
    local implementation = type(provider) == 'table' and provider.ok and provider.value.implementation or nil
    if type(implementation) ~= 'table' or not IsCallable(implementation.GetIdentity) then
        return Err('holder_provider_unavailable', 'Character identity provider is unavailable.')
    end
    local identity = implementation.GetIdentity(characterId)
    if type(identity) ~= 'table' or not identity.ok or type(identity.value) ~= 'table'
        or type(identity.value.characterId) ~= 'string' or identity.value.characterId:lower() ~= characterId then
        return Err('holder_not_found', 'Character was not found.')
    end
    if identity.value.status ~= 'active' then
        return Err('holder_inactive', 'Character is not active.')
    end
    return Ok(true)
end

function Licenses.ResolveOrganization(organizationId)
    if GetResourceState('feather-organizations') ~= 'started' then
        return Err('holder_provider_unavailable', 'Organizations is unavailable.')
    end
    local called, result = pcall(function()
        return exports['feather-organizations']:GetOrganization({ organizationId = organizationId })
    end)
    if not called or type(result) ~= 'table' then
        return Err('holder_provider_unavailable', 'Organization lookup failed.')
    end
    if not result.ok then
        if result.code == 'organization_not_found' then
            return Err('holder_not_found', 'Organization was not found.')
        end
        return Err('holder_provider_unavailable', 'Organization lookup failed.', { code = result.code })
    end
    if result.value.status ~= 'active' then
        return Err('holder_inactive', 'Organization is not active.')
    end
    return Ok(true)
end

-- The holder type must be configured and accepted by the definition, and the
-- holder must exist and be active. Runs outside transactions (provider calls).
function Licenses.ValidateHolder(holderTypes, holderType, holderId)
    local definition = Config.HolderTypes[holderType or '']
    if not definition or not Licenses.Uuid(holderId) then
        return Err('invalid_input', 'Holder type must be configured and holder ID must be a UUID.')
    end
    local allowed = false
    for _, value in ipairs(holderTypes or {}) do
        if value == holderType then
            allowed = true
        end
    end
    if not allowed then
        return Err('holder_type_not_allowed', 'This license cannot be held by that holder type.', {
            holderType = holderType
        })
    end
    if definition.validator == 'character' then
        return ResolveCharacter(holderId)
    elseif definition.validator == 'organizations' then
        return Licenses.ResolveOrganization(holderId)
    end
    return Ok(true)
end

-- Idempotent mutation ----------------------------------------------------------

-- Returns a stored result for a completed request, or nil when it must execute.
local function Replay(spec)
    local row = DB.one([[
        SELECT `operation`,`request_fingerprint`,`result_json`
        FROM `feather_license_receipts`
        WHERE `source_resource`=? AND `request_id`=?]], spec.resource, spec.requestId)
    if not row or not row.result_json then
        return nil
    end
    if row.operation ~= spec.operation or row.request_fingerprint ~= spec.fingerprint then
        return Err('idempotency_conflict', 'Request ID is bound to a different operation or payload.')
    end
    local decoded, value = pcall(json.decode, row.result_json)
    if not decoded or type(value) ~= 'table' then
        return Err('invalid_persistence', 'Stored receipt is invalid.')
    end
    value.replayed = true
    return Ok(value)
end

-- Idempotent transactional mutation. precheck runs outside the transaction (provider
-- lookups) and is skipped for completed replays; body runs inside it and must return
-- an envelope whose value is a table. Receipt, state, and audit rows commit together.
function Licenses.Mutate(spec)
    local replayed = Replay(spec)
    if replayed then
        return replayed
    end
    local context = {}
    if spec.precheck then
        local checked = spec.precheck()
        if not checked.ok then
            return checked
        end
        context = checked.value
    end
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        local executed, outcome = xpcall(function()
            local inserted = tx.exec([[
                INSERT IGNORE INTO `feather_license_receipts`
                    (`source_resource`,`request_id`,`operation`,`request_fingerprint`)
                VALUES (?,?,?,?)]],
                spec.resource, spec.requestId, spec.operation, spec.fingerprint)
            -- A fresh insert is ours and already row-locked by this transaction,
            -- so only an existing receipt needs reading back.
            local receipt
            if tonumber(inserted) == 1 then
                receipt = { operation = spec.operation, request_fingerprint = spec.fingerprint }
            else
                receipt = (tx.query([[
                    SELECT `operation`,`request_fingerprint`,`result_json`
                    FROM `feather_license_receipts`
                    WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]],
                    spec.resource, spec.requestId) or {})[1]
            end
            if not receipt then
                return Err('internal_error', 'Receipt could not be reserved.')
            end
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
                error('Licenses mutation body returned an invalid envelope.')
            end
            if outcome.ok then
                outcome.value.replayed = false
                tx.exec([[
                    UPDATE `feather_license_receipts` SET `result_json`=?
                    WHERE `source_resource`=? AND `request_id`=?]],
                    json.encode(outcome.value), spec.resource, spec.requestId)
            end
            return outcome
        end, debug.traceback)
        if not executed then
            print(('[feather-licenses] event=transaction.failed operation=%s reason=%s'):format(
                spec.operation, tostring(outcome)))
            result = Err('internal_error', 'Licenses transaction failed.')
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

-- Several server-generated UUIDs (MariaDB UUID()) in one round trip, optionally
-- with the database's current Unix time in seconds, so a row's timestamps and
-- the event recorded for it share one clock.
function Licenses.NewIds(tx, count, withNow)
    local columns = {}
    for index = 1, count do
        columns[#columns + 1] = ('UUID() AS `id%d`'):format(index)
    end
    if withNow then
        columns[#columns + 1] = 'UNIX_TIMESTAMP() AS `now_s`'
    end
    local row = (tx.query('SELECT ' .. table.concat(columns, ',')) or {})[1]
    if not row then
        error('Could not generate license UUIDs.')
    end
    local ids = {}
    for index = 1, count do
        local id = row['id' .. index]
        if not Licenses.Uuid(id) then
            error('Could not generate license UUIDs.')
        end
        ids[index] = id
    end
    return ids, withNow and math.floor(tonumber(row.now_s) or 0) or nil
end

-- Lets a consumer recover after a timeout: query by its own request ID before retrying.
function Licenses.FindOperation(request, resource)
    local allowed = Licenses.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Licenses.Fields(request, { requestId = true })
    if not fields.ok then
        return fields
    end
    if not Licenses.Token(request.requestId, 128) then
        return Err('invalid_input', 'Request ID required.')
    end
    local row = DB.one([[
        SELECT `operation`,`result_json` FROM `feather_license_receipts`
        WHERE `source_resource`=? AND `request_id`=?]], resource, request.requestId)
    if not row or not row.result_json then
        return Ok({ found = false })
    end
    local decoded, value = pcall(json.decode, row.result_json)
    if not decoded or type(value) ~= 'table' then
        return Err('invalid_persistence', 'Stored receipt is invalid.')
    end
    value.replayed = true
    return Ok({ found = true, operation = row.operation, result = value })
end

-- Configuration ----------------------------------------------------------------

local function ValidateAccess()
    local self = GetCurrentResourceName()
    -- Each privileged group requires the matching trusted group.
    local parents = {
        trustedReaders = false,
        trustedRegistrars = false,
        privilegedRegistrars = 'trustedRegistrars',
        trustedIssuers = false,
        privilegedIssuers = 'trustedIssuers',
        trustedAuditors = false,
        privilegedAuditors = 'trustedAuditors'
    }
    for group, parent in pairs(parents) do
        local members = Config.Access[group]
        if type(members) ~= 'table' then
            return Err('invalid_config', 'Access group missing.', { group = group })
        end
        for resource, enabled in pairs(members) do
            if type(resource) ~= 'string' or #resource < 1 or #resource > 100 or type(enabled) ~= 'boolean'
                or (enabled and parent and Config.Access[parent][resource] ~= true) then
                return Err('invalid_config', 'Access configuration is invalid.', { group = group })
            end
        end
    end
    for _, group in ipairs({ 'trustedReaders', 'trustedRegistrars', 'trustedIssuers', 'trustedAuditors' }) do
        if Config.Access[group][self] ~= true then
            return Err('invalid_config', 'Licenses must trust itself.', { group = group })
        end
    end
    return Ok(true)
end

function Licenses.ValidateConfig()
    if Config.Contract ~= 1 or Config.RequiredCoreContract ~= 1
        or not Licenses.Integer(Config.ReadinessTimeoutMs, 0, 60000)
        or type(Config.DevMode) ~= 'boolean' or type(Config.Access) ~= 'table'
        or type(Config.Authorization) ~= 'table' or type(Config.Authorization.enabled) ~= 'boolean'
        or not Licenses.Reason(Config.Authorization.definitionAction)
        or not Licenses.Reason(Config.Authorization.issueAction)
        or not Licenses.Reason(Config.Authorization.revokeAction) then
        return Err('invalid_config', 'Licenses contract, readiness, or authorization configuration is invalid.')
    end
    if type(Config.Outbox) ~= 'table' or not Licenses.Integer(Config.Outbox.pollIntervalMs, 250, 60000)
        or not Licenses.Integer(Config.Outbox.retryDelaySeconds, 1, 3600)
        or not Licenses.Integer(Config.Outbox.batchSize, 1, 100) then
        return Err('invalid_config', 'Outbox configuration is invalid.')
    end
    if type(Config.Expiry) ~= 'table' or not Licenses.Integer(Config.Expiry.sweepIntervalMs, 1000, 3600000)
        or not Licenses.Integer(Config.Expiry.batchSize, 1, 500) then
        return Err('invalid_config', 'Expiry configuration is invalid.')
    end
    local limits = Config.Limits
    if type(limits) ~= 'table' or not Licenses.Integer(limits.maxListLimit, 1, 100)
        or not Licenses.Integer(limits.maxClientLicenses, 1, 200)
        or not Licenses.Integer(limits.maxDurationSeconds, 60, 3153600000)
        or not Licenses.Integer(limits.maxScopeBytes, 64, 60000)
        or not Licenses.Integer(limits.maxScopeDepth, 1, 8)
        or not Licenses.Integer(limits.maxScopeNodes, 1, 2048)
        or not Licenses.Integer(limits.maxScopeString, 1, 8192) then
        return Err('invalid_config', 'Limit configuration is invalid.')
    end
    if type(Config.HolderTypes) ~= 'table' or next(Config.HolderTypes) == nil then
        return Err('invalid_config', 'Holder types are required.')
    end
    for key, definition in pairs(Config.HolderTypes) do
        if not Licenses.Key(key, 32) or type(definition) ~= 'table'
            or (definition.validator ~= false and definition.validator ~= 'character'
                and definition.validator ~= 'organizations') then
            return Err('invalid_config', 'Holder type configuration is invalid.', { holderType = tostring(key) })
        end
    end
    return ValidateAccess()
end

-- Wraps a public export: derives the caller and converts exceptions to envelopes.
function Licenses.Export(name, operation)
    exports(name, function(request)
        local resource = GetInvokingResource()
        local called, result = xpcall(function()
            return operation(request, resource)
        end, debug.traceback)
        if not called then
            print(('[feather-licenses] event=api.failed export=%s reason=%s'):format(name, tostring(result)))
            return Err('internal_error', 'Licenses operation failed.')
        end
        return result
    end)
end

exports('GetHealth', Licenses.GetHealth)
exports('GetCapabilities', Licenses.GetCapabilities)
exports('AwaitReady', Licenses.AwaitReady)
Licenses.Export('FindOperation', Licenses.FindOperation)
