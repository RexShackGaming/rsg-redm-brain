Access.Grants = {}
local G = Access.Grants
local fences = {}
local function Bump(source)
    if Access.Integer(source, 1, 65535) then fences[source] = (fences[source] or 0) + 1 end
end
for _, name in ipairs({ 'core.session.ready.v1', 'core.session.leaving.v1', 'core.session.left.v1' }) do
    AddEventHandler(name, function(session) if type(session) == 'table' then Bump(session.source) end end)
end
AddEventHandler('playerDropped', function() Bump(tonumber(source)) end)

function G.Fence(actor)
    if not Access.LocalReady() or GetResourceState('feather-core') ~= 'started'
        or GetResourceState('feather-mysql') ~= 'started' then return false end
    return actor.system == true or actor.fence == (fences[actor.source] or 0)
end

function G.ValidateConfig()
    if type(Config.Grants) ~= 'table' or not Access.Integer(Config.Grants.MaxValidityMs, 1000, 31622400000)
        or not Access.Integer(Config.Grants.CheckTimeoutMs, 100, 30000) then
        return Access.Err('invalid_config', 'Grant limits are invalid.')
    end
    if Config.Providers.TrustedReaders[GetCurrentResourceName()] ~= true then
        return Access.Err('invalid_config', 'Access must trust itself for internal provider reads.')
    end
    for _, key in ipairs({ 'Managers', 'Readers', 'Auditors' }) do
        if type(Config.Grants[key]) ~= 'table' then return Access.Err('invalid_config', 'Grant trust maps required.') end
        for resource, enabled in pairs(Config.Grants[key]) do
            if type(resource) ~= 'string' or #resource > 100 or not resource:match('^[%w_-]+$')
                or type(enabled) ~= 'boolean' then return Access.Err('invalid_config', 'Invalid grant principal.') end
        end
    end
    return Access.Ok(true)
end

function G.Token(value, maximum)
    return type(value) == 'string' and #value > 0 and #value <= maximum and not value:find('[%c%s]')
end

function G.Begin(request, caller, group)
    local ready = Access.Ready()
    if not ready.ok then return ready end
    if type(caller) ~= 'string' or Config.Grants[group][caller] ~= true then
        return Access.Err('authorization_denied', 'Caller is not a trusted grant principal.',
            { stage = 'access_trust', caller = type(caller) == 'string' and caller or 'missing', group = group })
    end
    local actor = { resource = caller, system = true }
    if request.actorSource ~= nil then
        if not Access.Integer(request.actorSource, 1, 65535) then return Access.Err('invalid_input', 'Invalid actor source.') end
        local fence = fences[request.actorSource] or 0
        local called, session = pcall(function() return exports['feather-core']:GetSessionContext(request.actorSource) end)
        local value = called and type(session) == 'table' and session.ok and session.value
        if type(value) ~= 'table' or not Access.Uuid(value.accountId) or not Access.Uuid(value.characterId)
            or not Access.Uuid(value.sessionId) or not Access.Integer(value.generation, 1, 9007199254740991) then
            return Access.Err('actor_unavailable', 'An active Core character session is required.')
        end
        if fence ~= (fences[request.actorSource] or 0) then return Access.Err('stale_session', 'Session changed during identity lookup.') end
        actor = { resource = caller, source = request.actorSource, fence = fence, accountId = value.accountId:lower(),
            characterId = value.characterId:lower(), sessionId = value.sessionId, generation = value.generation }
    end
    local action = group == 'Managers' and 'access.grant.manage' or 'access.grant.read'
    local called, result = pcall(function()
        return exports['feather-core']:Authorize(action, { source = 0,
            correlationId = request.requestId, subject = { resource = caller } })
    end)
    if not called or type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table' then
        return Access.Err('policy_unavailable', 'Core policy is unavailable.',
            { stage = 'core_policy', action = action, caller = caller,
                policyCode = type(result) == 'table' and result.code or 'invalid_response' })
    end
    if result.value.allowed ~= true then
        local details = type(result.value.details) == 'table' and result.value.details or {}
        return Access.Err('authorization_denied', 'Core policy denied the service action.', {
            stage = 'core_policy', action = action, caller = caller, policyCode = result.value.code,
            provider = result.value.provider, serviceCaller = details.serviceCaller,
            servicePrincipal = details.servicePrincipal,
        })
    end
    return Access.Ok(actor)
end

function G.Current(actor)
    local ready = Access.Ready()
    if not ready.ok then return ready end
    if not G.Fence(actor) then return Access.Err('stale_session', 'Actor or dependency context changed.') end
    if actor.system then return Access.Ok(true) end
    local called, result = pcall(function() return exports['feather-core']:GetSessionContext(actor.source) end)
    local value = called and type(result) == 'table' and result.ok and result.value
    if type(value) ~= 'table' or value.sessionId ~= actor.sessionId or value.generation ~= actor.generation
        or value.characterId ~= actor.characterId or value.accountId ~= actor.accountId then
        return Access.Err('stale_session', 'Actor session changed during the operation.')
    end
    return Access.Ok(true)
end

function G.Character(characterId)
    local called, result = pcall(function()
        local provider = exports['feather-core']:GetProvider('character-profile', nil, 1)
        if type(provider) ~= 'table' or provider.ok ~= true or type(provider.value) ~= 'table'
            or type(provider.value.implementation) ~= 'table' then return nil end
        return provider.value.implementation.GetIdentity(characterId)
    end)
    if not called or type(result) ~= 'table' or result.ok ~= true or type(result.value) ~= 'table'
        or result.value.characterId ~= characterId or result.value.status ~= 'active' then
        return Access.Err('character_unavailable', 'An active persisted Character identity is required.')
    end
    return Access.Ok(true)
end

function G.Context(targetType, targetId)
    return Access.Providers.ResolveTarget({ targetType = targetType, targetId = targetId }, GetCurrentResourceName())
end

function G.Capability(context, capability)
    for _, key in ipairs(context.capabilities) do if key == capability then return true end end
    return false
end

function G.Fingerprint(operation, request, actor, fields)
    local values = { operation, actor.resource, actor.accountId or '', actor.characterId or '' }
    for _, key in ipairs(fields) do values[#values + 1] = { key, request[key] == nil and '' or request[key] } end
    return json.encode(values)
end

function G.Replay(caller, requestId, operation, fingerprint, query)
    local row = (query or DB.one)([[SELECT `operation`,`request_fingerprint`,`result_json`
        FROM `feather_access_receipts` WHERE `source_resource`=? AND `request_id`=?]], caller, requestId)
    if not row then return nil end
    if row.operation ~= operation or row.request_fingerprint ~= fingerprint then
        return Access.Err('idempotency_conflict', 'Request ID is bound to a different operation, actor or payload.')
    end
    if row.result_json == '' then return Access.Err('receipt_incomplete', 'Stored receipt is incomplete.') end
    local decoded, result = pcall(json.decode, row.result_json)
    if not decoded or type(result) ~= 'table' then return Access.Err('invalid_persistence', 'Invalid stored receipt.') end
    result.replayed = true
    return Access.Ok(result)
end

function G.Mutate(caller, requestId, operation, fingerprint, actor, body)
    local result
    local called, committed = pcall(DB.transaction, function(tx)
        tx.exec([[INSERT IGNORE INTO `feather_access_receipts`
            (`source_resource`,`request_id`,`operation`,`request_fingerprint`,`result_json`) VALUES (?,?,?,?,'')]],
            caller, requestId, operation, fingerprint)
        local receipt = tx.one([[SELECT `operation`,`request_fingerprint`,`result_json` FROM `feather_access_receipts`
            WHERE `source_resource`=? AND `request_id`=? FOR UPDATE]], caller, requestId)
        if not receipt then error('Receipt reservation missing') end
        if receipt.operation ~= operation or receipt.request_fingerprint ~= fingerprint then
            result = Access.Err('idempotency_conflict', 'Request ID already used with a different operation or payload.')
        elseif receipt.result_json ~= '' then
            local decoded, value = pcall(json.decode, receipt.result_json)
            if not decoded or type(value) ~= 'table' then error('Invalid persisted receipt') end
            value.replayed = true
            result = Access.Ok(value)
        else
            result = body(tx)
            if result.ok then
                result.value.replayed = false
                tx.exec([[UPDATE `feather_access_receipts` SET `result_json`=? WHERE `source_resource`=? AND `request_id`=?]],
                    json.encode(result.value), caller, requestId)
            end
        end
        if result.ok and not G.Fence(actor) then result = Access.Err('stale_session', 'Session/dependency changed before commit.') end
        return result.ok == true
    end)
    if not called or (result and result.ok and committed ~= true) then
        print(('[feather-access] event=mutation.unconfirmed operation=%s'):format(operation))
        return Access.Err('transaction_failed', 'Commit was not confirmed. Retry with the same request ID.')
    end
    return result or Access.Err('transaction_failed', 'Operation did not complete. Retry the same request ID.')
end

function G.Clock(tx)
    local row = tx.one('SELECT UUID() AS grant_id, UUID() AS event_id, FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000) AS now_ms')
    if not row or not Access.Uuid(row.grant_id) or not Access.Uuid(row.event_id)
        or not tonumber(row.now_ms) then error('Database clock or identity generation failed') end
    row.now_ms = tonumber(row.now_ms)
    return row
end

function G.Snapshot(row)
    local decoded, roles = pcall(json.decode, row.roles_json)
    if not decoded or type(roles) ~= 'table' then error('Invalid persisted roles') end
    return { grantId = row.grant_id, targetType = row.target_type, targetId = row.target_id,
        epoch = tonumber(row.target_epoch), granteeType = row.grantee_type, granteeId = row.grantee_id,
        capability = row.capability, roleIds = roles, status = row.status, revision = tonumber(row.revision),
        validFrom = tonumber(row.valid_from), validUntil = tonumber(row.valid_until),
        sourceResource = row.source_resource, provenanceType = row.provenance_type, provenanceId = row.provenance_id }
end

function G.Record(tx, eventId, eventType, grant, actor, request)
    local payload = { eventId = eventId, eventType = eventType, grant = grant,
        actor = actor, reasonCode = request.reasonCode, requestId = request.requestId, preservation = request._preservation }
    local encoded = json.encode(payload)
    tx.exec([[INSERT INTO `feather_access_events` (`event_id`,`grant_id`,`event_type`,`payload_json`) VALUES (?,?,?,?)]],
        eventId, grant.grantId, eventType, encoded)
    tx.exec([[INSERT INTO `feather_access_outbox` (`event_id`,`event_type`,`payload_json`) VALUES (?,?,?)]],
        eventId, eventType, encoded)
    Access.Audit.Enqueue(tx, payload)
end
