Assets = {}
local health = { state = 'starting', phase = 'not_started', contract = 1 }

Assets.MaxRevision = 9007199254740990

-- Statuses a consumer may set. 'retired' is terminal and only RetireAsset sets it.
Assets.Statuses = {
    active = true,
    held = true,
    missing = true
}

-- Interest types this release supports. Liens, custody and insurance wait for a
-- real consumer (see README); delegated use belongs to feather-access.
Assets.InterestTypes = {
    owner = true
}

function Assets.RegisterDevCommand(name, handler, restricted)
    if Config.DevMode then
        RegisterCommand(name, handler, restricted == true)
    end
end

function Assets.Copy(value)
    if type(value) ~= 'table' then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = Assets.Copy(child)
    end
    return result
end

function Assets.Ok(value)
    return { ok = true, value = value }
end

function Assets.Err(code, message, details)
    return { ok = false, code = code, message = message, details = details }
end

local Ok, Err = Assets.Ok, Assets.Err

-- Validators -------------------------------------------------------------------

function Assets.Integer(value, minimum, maximum)
    return type(value) == 'number' and value == value
        and value >= minimum and value <= maximum and value % 1 == 0
end

function Assets.Uuid(value)
    return type(value) == 'string' and #value == 36
        and value:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$') ~= nil
end

function Assets.Key(value, maximum)
    return type(value) == 'string' and #value >= 1 and #value <= maximum
        and value:match('^[a-z][a-z0-9_]*$') ~= nil
end

-- Game model names are mixed case (A_C_Horse_Arabian_White, wagon02x).
function Assets.ModelKey(value)
    return type(value) == 'string' and #value >= 1 and #value <= 100
        and value:match('^[A-Za-z0-9][A-Za-z0-9_]*$') ~= nil
end

function Assets.Token(value, maximum)
    return type(value) == 'string' and #value >= 1 and #value <= maximum
        and value:match('^[A-Za-z0-9][A-Za-z0-9._:%-]*$') ~= nil
end

function Assets.Reason(value)
    return type(value) == 'string' and #value >= 1 and #value <= 64
        and value:match('^[a-z][a-z0-9._:%-]*$') ~= nil
end

-- Rejects unknown fields so callers cannot smuggle identity or state.
function Assets.Fields(request, allowed)
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
function Assets.Allowed(extra)
    local result = {}
    for field in pairs(common) do
        result[field] = true
    end
    for _, field in ipairs(extra) do
        result[field] = true
    end
    return result
end

-- Shared validation for the optional actor/correlation fields every mutation accepts.
function Assets.ValidateCommon(request)
    if not Assets.Token(request.requestId, 128) or not Assets.Reason(request.reasonCode) then
        return Err('invalid_input', 'Stable request ID and reason code required.')
    end
    if request.actorSource ~= nil and not Assets.Integer(request.actorSource, 1, 65535) then
        return Err('invalid_input', 'Actor source must be a connected server ID.')
    end
    if request.correlationId ~= nil and not Assets.Token(request.correlationId, 128) then
        return Err('invalid_input', 'Correlation ID is invalid.')
    end
    -- Optional link to the consumer record behind the change (an order, a sale).
    if (request.referenceType == nil) ~= (request.referenceId == nil)
        or (request.referenceType ~= nil and not Assets.Key(request.referenceType, 48))
        or (request.referenceId ~= nil and not Assets.Token(request.referenceId, 128)) then
        return Err('invalid_input', 'Reference type and ID must be given together and be stable keys.')
    end
    return Ok(true)
end

-- Shared prologue: trusted manager and field/shape validation.
function Assets.Begin(request, resource, allowedFields)
    local allowed = Assets.CheckAccess('trustedManagers', resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Assets.Fields(request, allowedFields)
    if not fields.ok then
        return fields
    end
    return Assets.ValidateCommon(request)
end

-- Metadata ---------------------------------------------------------------------
-- Customization is generic, versioned consumer metadata: an object of identifier
-- keys whose values are strings, finite numbers, booleans, arrays or objects.

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

local function WalkMetadata(value, depth, budget)
    local kind = type(value)
    if kind == 'string' then
        return #value <= Config.Limits.maxMetadataString
    elseif kind == 'number' then
        return value == value and value ~= math.huge and value ~= -math.huge
    elseif kind == 'boolean' then
        return true
    elseif kind ~= 'table' or depth > Config.Limits.maxMetadataDepth then
        return false
    end
    local array = IsArray(value)
    for key, child in pairs(value) do
        budget.nodes = budget.nodes + 1
        if budget.nodes > Config.Limits.maxMetadataNodes then
            return false
        end
        if not array and (type(key) ~= 'string' or #key > 64
            or key:match('^[A-Za-z_][A-Za-z0-9_]*$') == nil) then
            return false
        end
        if not WalkMetadata(child, depth + 1, budget) then
            return false
        end
    end
    return true
end

function Assets.ValidateMetadata(metadata)
    if type(metadata) ~= 'table' or (next(metadata) ~= nil and IsArray(metadata)) then
        return Err('invalid_metadata', 'Metadata must be an object.')
    end
    if not WalkMetadata(metadata, 1, { nodes = 0 }) then
        return Err('invalid_metadata', 'Metadata exceeds depth, size or type limits.', {
            maxDepth = Config.Limits.maxMetadataDepth,
            maxNodes = Config.Limits.maxMetadataNodes
        })
    end
    local encoded = next(metadata) == nil and '{}' or json.encode(metadata)
    if type(encoded) ~= 'string' or #encoded > Config.Limits.maxMetadataBytes then
        return Err('invalid_metadata', 'Metadata is too large.', {
            maxBytes = Config.Limits.maxMetadataBytes
        })
    end
    return Ok(encoded)
end

-- Deterministic serialization, so the same metadata always yields the same
-- idempotency fingerprint regardless of table iteration order.
function Assets.Canonical(value)
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
        parts[#parts + 1] = #name .. ':' .. name .. '=' .. Assets.Canonical(value[key])
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

-- Length-prefixed so values containing delimiters cannot collide. The optional
-- reference is appended only when given, so receipts stored before references
-- existed keep their fingerprints and still replay.
function Assets.Fingerprint(operation, request, fields)
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

function Assets.SetState(state, phase, failure)
    health.state = state
    health.phase = phase
    health.failure = Assets.Copy(failure)
    print(('[feather-assets] event=lifecycle.changed state=%s phase=%s'):format(state, phase))
end

function Assets.Fail(result)
    Assets.SetState('failed', 'startup_failed', result)
    print(('[feather-assets] event=startup.failed code=%s message=%s'):format(
        tostring(result.code), tostring(result.message)))
    return result
end

function Assets.IsReady()
    return health.state == 'ready'
end

function Assets.GetHealth()
    return Ok(Assets.Copy(health))
end

function Assets.GetCapabilities()
    local assetTypes = {}
    for key in pairs(Config.AssetTypes) do
        assetTypes[#assetTypes + 1] = key
    end
    table.sort(assetTypes)
    return Ok({
        resource = GetCurrentResourceName(),
        contract = 1,
        version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0),
        state = health.state,
        assetTypes = assetTypes,
        interestTypes = { 'owner' },
        features = {
            lifecycle = 1,
            health = 1,
            migrations = 1,
            registration = 1,
            ownership = 1,
            transfer = 1,
            status = 1,
            metadata = 1,
            retirement = 1,
            interestCheck = 1,
            revisions = 1,
            idempotency = 1,
            operationLookup = 1,
            outbox = 1,
            eventPublication = 1,
            auditHistory = 1,
            references = 1,
            holderValidation = 1,
            clientSnapshot = 1,
            delegationEpoch = 1,
            accessProvider = 1,
            liens = 0,
            custody = 0,
            legacyMigration = 0
        }
    })
end

function Assets.AwaitReady(timeoutMs)
    if timeoutMs == nil then
        timeoutMs = Config.ReadinessTimeoutMs
    end
    if not Assets.Integer(timeoutMs, 0, 60000) then
        return Err('invalid_input', 'Timeout must be an integer from 0 to 60000 ms.')
    end
    local started = GetGameTimer()
    while health.state ~= 'ready' and health.state ~= 'failed'
        and GetGameTimer() - started < timeoutMs do
        Wait(50)
    end
    if health.state == 'ready' then
        return Assets.GetHealth()
    end
    if health.state == 'failed' then
        return Err('startup_failed', 'Assets failed to start.', { health = Assets.Copy(health) })
    end
    return Err('not_ready', 'Assets is not ready.')
end

-- Access and policy ------------------------------------------------------------

function Assets.CheckAccess(group, resource)
    if Config.Access[group][resource or ''] ~= true then
        return Err('authorization_denied', 'Calling resource is not trusted for this operation.', { group = group })
    end
    if health.state ~= 'ready' then
        return Err('not_ready', 'Assets is not ready.')
    end
    if GetResourceState('feather-core') ~= 'started' then
        return Err('dependency_unavailable', 'Core is unavailable.')
    end
    return Ok(true)
end

function Assets.CheckRead(resource)
    return Assets.CheckAccess('trustedReaders', resource)
end

function Assets.CanMutate(managerResource, resource)
    return managerResource == resource or Config.Access.privilegedManagers[resource] == true
end

-- Service-level policy: fails closed when the provider is missing or indeterminate.
function Assets.Authorize(action, resource, requestId, subject)
    if not Config.Authorization.enabled then
        return Ok(true)
    end
    subject = Assets.Copy(subject or {})
    subject.resource = resource
    local called, decision = pcall(function()
        return exports['feather-core']:Authorize(action, { correlationId = requestId, subject = subject })
    end)
    if not called or type(decision) ~= 'table' or not decision.ok or type(decision.value) ~= 'table' then
        return Err('policy_unavailable', 'Assets policy could not be evaluated.', {
            action = action,
            policyCode = type(decision) == 'table' and decision.code or nil
        })
    end
    if decision.value.allowed ~= true then
        -- Provider code/reason say why (e.g. service_forbidden = no grant in the service policy).
        return Err('authorization_denied', 'Assets policy denied.', {
            action = action,
            policyCode = decision.value.code,
            policyReason = decision.value.reason,
            provider = decision.value.provider
        })
    end
    return Ok(true)
end

-- Actor identity is always derived from Core session context, never supplied.
function Assets.Actor(request)
    local actor = { correlationId = request.correlationId or request.requestId }
    if request.actorSource == nil then
        return Ok(actor)
    end
    local called, session = pcall(function()
        return exports['feather-core']:GetSessionContext(request.actorSource)
    end)
    if not called or type(session) ~= 'table' or not session.ok or type(session.value) ~= 'table'
        or not Assets.Uuid(session.value.accountId) or not Assets.Uuid(session.value.characterId) then
        return Err('actor_unavailable', 'Actor source has no active character session.')
    end
    actor.accountId = session.value.accountId
    actor.characterId = session.value.characterId
    return Ok(actor)
end

-- Service policy, then the server-derived actor recorded on audit facts.
function Assets.Policy(action, request, resource, subject)
    local policy = Assets.Authorize(action, resource, request.requestId, subject)
    if not policy.ok then
        return policy
    end
    return Assets.Actor(request)
end

-- Holders ----------------------------------------------------------------------

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

local function ResolveOrganization(organizationId)
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

-- The holder type must be configured and accepted by the asset type, and the
-- holder must exist and be active. Runs outside transactions (provider calls).
function Assets.ValidateHolder(assetType, holderType, holderId)
    local definition = Config.HolderTypes[holderType or '']
    local typeConfig = Config.AssetTypes[assetType or '']
    if not definition or not typeConfig or not Assets.Uuid(holderId) then
        return Err('invalid_input', 'Holder type must be configured and holder ID must be a UUID.')
    end
    if not typeConfig.holderSet[holderType] then
        return Err('holder_type_not_allowed', 'This asset type cannot be held by that holder type.', {
            assetType = assetType,
            holderType = holderType
        })
    end
    if definition.validator == 'character' then
        return ResolveCharacter(holderId)
    elseif definition.validator == 'organizations' then
        return ResolveOrganization(holderId)
    end
    return Ok(true)
end

-- Idempotent mutation ----------------------------------------------------------

-- Returns a stored result for a completed request, or nil when it must execute.
local function Replay(spec)
    local row = DB.one([[
        SELECT `operation`,`request_fingerprint`,`result_json`
        FROM `feather_asset_receipts`
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
function Assets.Mutate(spec)
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
                INSERT IGNORE INTO `feather_asset_receipts`
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
                    FROM `feather_asset_receipts`
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
                error('Assets mutation body returned an invalid envelope.')
            end
            if outcome.ok then
                outcome.value.replayed = false
                tx.exec([[
                    UPDATE `feather_asset_receipts` SET `result_json`=?
                    WHERE `source_resource`=? AND `request_id`=?]],
                    json.encode(outcome.value), spec.resource, spec.requestId)
            end
            return outcome
        end, debug.traceback)
        if not executed then
            print(('[feather-assets] event=transaction.failed operation=%s reason=%s'):format(
                spec.operation, tostring(outcome)))
            result = Err('internal_error', 'Assets transaction failed.')
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
-- with the database's current Unix time in seconds, so a row's timestamp and the
-- event recorded for it share one value.
function Assets.NewIds(tx, count, withNow)
    local columns = {}
    for index = 1, count do
        columns[#columns + 1] = ('UUID() AS `id%d`'):format(index)
    end
    if withNow then
        columns[#columns + 1] = 'UNIX_TIMESTAMP() AS `now_s`'
    end
    local row = (tx.query('SELECT ' .. table.concat(columns, ',')) or {})[1]
    if not row then
        error('Could not generate asset UUIDs.')
    end
    local ids = {}
    for index = 1, count do
        local id = row['id' .. index]
        if not Assets.Uuid(id) then
            error('Could not generate asset UUIDs.')
        end
        ids[index] = id
    end
    return ids, withNow and math.floor(tonumber(row.now_s) or 0) or nil
end

-- Lets a consumer recover after a timeout: query by its own request ID before retrying.
function Assets.FindOperation(request, resource)
    local allowed = Assets.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Assets.Fields(request, { requestId = true })
    if not fields.ok then
        return fields
    end
    if not Assets.Token(request.requestId, 128) then
        return Err('invalid_input', 'Request ID required.')
    end
    local row = DB.one([[
        SELECT `operation`,`result_json` FROM `feather_asset_receipts`
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
        trustedManagers = false,
        privilegedManagers = 'trustedManagers',
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
    for _, group in ipairs({ 'trustedReaders', 'trustedManagers', 'trustedAuditors' }) do
        if Config.Access[group][self] ~= true then
            return Err('invalid_config', 'Assets must trust itself.', { group = group })
        end
    end
    return Ok(true)
end

local function ValidateTypes()
    if type(Config.HolderTypes) ~= 'table' or next(Config.HolderTypes) == nil then
        return Err('invalid_config', 'Holder types are required.')
    end
    for key, definition in pairs(Config.HolderTypes) do
        if not Assets.Key(key, 32) or type(definition) ~= 'table'
            or (definition.validator ~= false and definition.validator ~= 'character'
                and definition.validator ~= 'organizations') then
            return Err('invalid_config', 'Holder type configuration is invalid.', { holderType = tostring(key) })
        end
    end
    if type(Config.AssetTypes) ~= 'table' or next(Config.AssetTypes) == nil then
        return Err('invalid_config', 'At least one asset type is required.')
    end
    for key, definition in pairs(Config.AssetTypes) do
        if not Assets.Key(key, 32) or type(definition) ~= 'table' or type(definition.label) ~= 'string'
            or type(definition.holderTypes) ~= 'table' or #definition.holderTypes == 0 then
            return Err('invalid_config', 'Asset type configuration is invalid.', { assetType = tostring(key) })
        end
        -- Precomputed lookup used by ValidateHolder.
        definition.holderSet = {}
        for _, holderType in ipairs(definition.holderTypes) do
            if not Config.HolderTypes[holderType] then
                return Err('invalid_config', 'Asset type names an unknown holder type.', {
                    assetType = key,
                    holderType = tostring(holderType)
                })
            end
            definition.holderSet[holderType] = true
        end
    end
    return Ok(true)
end

function Assets.ValidateConfig()
    if Config.Contract ~= 1 or Config.RequiredCoreContract ~= 1
        or not Assets.Integer(Config.ReadinessTimeoutMs, 0, 60000)
        or type(Config.DevMode) ~= 'boolean' or type(Config.Access) ~= 'table'
        or type(Config.Delegation) ~= 'table' or type(Config.Delegation.enabled) ~= 'boolean'
        or type(Config.Authorization) ~= 'table' or type(Config.Authorization.enabled) ~= 'boolean'
        or not Assets.Reason(Config.Authorization.manageAction)
        or not Assets.Reason(Config.Authorization.transferAction) then
        return Err('invalid_config', 'Assets contract, readiness, or authorization configuration is invalid.')
    end
    if type(Config.Outbox) ~= 'table' or not Assets.Integer(Config.Outbox.pollIntervalMs, 250, 60000)
        or not Assets.Integer(Config.Outbox.retryDelaySeconds, 1, 3600)
        or not Assets.Integer(Config.Outbox.batchSize, 1, 100) then
        return Err('invalid_config', 'Outbox configuration is invalid.')
    end
    local limits = Config.Limits
    if type(limits) ~= 'table' or not Assets.Integer(limits.maxListLimit, 1, 100)
        or not Assets.Integer(limits.maxClientAssets, 1, 200)
        or not Assets.Integer(limits.maxMetadataBytes, 256, 60000)
        or not Assets.Integer(limits.maxMetadataDepth, 1, 8)
        or not Assets.Integer(limits.maxMetadataNodes, 1, 2048)
        or not Assets.Integer(limits.maxMetadataString, 1, 8192) then
        return Err('invalid_config', 'Limit configuration is invalid.')
    end
    local types = ValidateTypes()
    if not types.ok then
        return types
    end
    return ValidateAccess()
end

-- Wraps a public export: derives the caller and converts exceptions to envelopes.
function Assets.Export(name, operation)
    exports(name, function(request)
        local resource = GetInvokingResource()
        local called, result = xpcall(function()
            return operation(request, resource)
        end, debug.traceback)
        if not called then
            print(('[feather-assets] event=api.failed export=%s reason=%s'):format(name, tostring(result)))
            return Err('internal_error', 'Assets operation failed.')
        end
        return result
    end)
end

exports('GetHealth', Assets.GetHealth)
exports('GetCapabilities', Assets.GetCapabilities)
exports('AwaitReady', Assets.AwaitReady)
Assets.Export('FindOperation', Assets.FindOperation)
