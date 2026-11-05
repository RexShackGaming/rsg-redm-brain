local G = Access.Grants
local mutationFields = { requestId = true, reasonCode = true, actorSource = true }
local function Fields(extra)
    local fields = Access.Copy(mutationFields)
    for _, key in ipairs(extra) do fields[key] = true end
    return fields
end
local grantKeys = { 'targetType', 'targetId', 'expectedEpoch', 'granteeType', 'granteeId', 'capability',
    'roleIds', 'validFrom', 'validUntil', 'provenanceType', 'provenanceId' }
local grantFields = Fields(grantKeys)
local function MutationInput(request, fields)
    return Access.OnlyFields(request, fields) and G.Token(request.requestId, 128) and Access.Key(request.reasonCode)
        and (request.actorSource == nil or Access.Integer(request.actorSource, 1, 65535))
end
local function CatalogMatches(catalog, roles)
    if catalog.status ~= 'active' then return false end
    local known = {}
    for _, role in ipairs(catalog.roleIds) do known[role] = true end
    for _, role in ipairs(roles) do if not known[role] then return false end end
    return true
end

function G.Grant(request, caller)
    if not MutationInput(request, grantFields) or not Access.Key(request.targetType) or not Access.Uuid(request.targetId)
        or not Access.Integer(request.expectedEpoch, 1, 9007199254740991)
        or (request.granteeType ~= 'character' and request.granteeType ~= 'organization')
        or not Access.Uuid(request.granteeId) or not Access.Key(request.capability)
        or not Access.Integer(request.validFrom, 0, 9007199254740991)
        or not Access.Integer(request.validUntil, 1, 9007199254740991)
        or request.validUntil <= request.validFrom
        or request.validUntil - request.validFrom > Config.Grants.MaxValidityMs
        or not Access.Key(request.provenanceType) or not Access.Uuid(request.provenanceId) then
        return Access.Err('invalid_input', 'Exact grant terms, finite validity, provenance and request identity are required.')
    end
    local roles
    if request.granteeType == 'organization' then
        roles = Access.Providers.RoleIds(request.roleIds)
        if not roles then return Access.Err('invalid_input', 'Organization grants require explicit unique role IDs.') end
    elseif request.roleIds ~= nil then return Access.Err('invalid_input', 'Character grants cannot contain role selectors.') end
    request = Access.Copy(request); request.roleIds = roles
    request.targetId, request.granteeId, request.provenanceId = request.targetId:lower(), request.granteeId:lower(), request.provenanceId:lower()
    local begun = G.Begin(request, caller, 'Managers')
    if not begun.ok then return begun end
    local actor = begun.value
    local fingerprintKeys = Access.Copy(grantKeys); fingerprintKeys[#fingerprintKeys + 1] = 'reasonCode'
    local fingerprint = G.Fingerprint('grant', request, actor, fingerprintKeys)
    local replay = G.Replay(caller, request.requestId, 'grant', fingerprint)
    if replay then return replay end
    local context = G.Context(request.targetType, request.targetId)
    if not context.ok then return context end
    if context.value.status ~= 'active' then return Access.Err('target_unavailable', 'Only active targets accept grants.') end
    if context.value.epoch ~= request.expectedEpoch then return Access.Err('epoch_conflict', 'Target ownership context changed.') end
    if not G.Capability(context.value, request.capability) then return Access.Err('capability_unsupported', 'Target does not support that capability.') end
    local authority = Access.Providers.Authorize(context.value, actor, 'grant', request.capability)
    if not authority.ok then return authority end
    local holder
    if request.granteeType == 'character' then holder = G.Character(request.granteeId)
    else
        holder = Access.Providers.Catalog(request.granteeId)
        if holder.ok and not CatalogMatches(holder.value, request.roleIds) then
            return Access.Err('role_unavailable', 'Organization must be active and every selected role must exist.')
        end
    end
    if not holder.ok then return holder end
    local fresh = G.Context(request.targetType, request.targetId)
    if not fresh.ok then return fresh end
    if fresh.value.status ~= 'active' or fresh.value.epoch ~= request.expectedEpoch
        or fresh.value.provider.generation ~= context.value.provider.generation then
        return Access.Err('epoch_conflict', 'Target context changed while validating the grant.')
    end
    local current = G.Current(actor)
    if not current.ok then return current end
    return G.Mutate(caller, request.requestId, 'grant', fingerprint, actor, function(tx)
        local clock = G.Clock(tx)
        if request.validUntil <= clock.now_ms then return Access.Err('grant_expired', 'Validity has already ended.') end
        if request.validFrom > clock.now_ms + Config.Grants.MaxValidityMs then
            return Access.Err('invalid_input', 'Grant start is too far in the future.')
        end
        tx.exec([[INSERT INTO `feather_access_grants`
            (`grant_id`,`target_type`,`target_id`,`target_epoch`,`grantee_type`,`grantee_id`,`capability`,`roles_json`,
             `valid_from`,`valid_until`,`status`,`revision`,`source_resource`,`provenance_type`,`provenance_id`,`actor_json`)
            VALUES (?,?,?,?,?,?,?,?,?,?,'active',1,?,?,?,?)]],
            clock.grant_id, request.targetType, request.targetId, request.expectedEpoch, request.granteeType,
            request.granteeId, request.capability, json.encode(request.roleIds or {}), request.validFrom,
            request.validUntil, caller, request.provenanceType, request.provenanceId, json.encode(actor))
        local grant = G.Snapshot(tx.one('SELECT * FROM `feather_access_grants` WHERE `grant_id`=?', clock.grant_id))
        G.Record(tx, clock.event_id, 'access.grant.created.v1', grant, actor, request)
        return Access.Ok(grant)
    end)
end

function G.Revoke(request, caller)
    if not MutationInput(request, Fields({ 'grantId', 'expectedRevision' })) or not Access.Uuid(request.grantId)
        or not Access.Integer(request.expectedRevision, 1, 9007199254740990) then
        return Access.Err('invalid_input', 'Grant UUID, expected revision and request identity are required.')
    end
    request = Access.Copy(request); request.grantId = request.grantId:lower()
    local begun = G.Begin(request, caller, 'Managers')
    if not begun.ok then return begun end
    local actor = begun.value
    local fingerprint = G.Fingerprint('revoke', request, actor, { 'grantId', 'expectedRevision', 'reasonCode' })
    local replay = G.Replay(caller, request.requestId, 'revoke', fingerprint)
    if replay then return replay end
    local row = DB.one('SELECT * FROM `feather_access_grants` WHERE `grant_id`=?', request.grantId)
    if not row then return Access.Err('grant_not_found', 'Grant not found.') end
    local context = G.Context(row.target_type, row.target_id)
    if not context.ok then return context end
    local authority = Access.Providers.Authorize(context.value, actor, 'revoke', row.capability)
    if not authority.ok then return authority end
    local fresh = G.Context(row.target_type, row.target_id)
    if not fresh.ok then return fresh end
    if fresh.value.epoch ~= context.value.epoch or fresh.value.provider.generation ~= context.value.provider.generation then
        return Access.Err('epoch_conflict', 'Target authority changed while validating revocation.')
    end
    local current = G.Current(actor)
    if not current.ok then return current end
    return G.Mutate(caller, request.requestId, 'revoke', fingerprint, actor, function(tx)
        local locked = tx.one('SELECT * FROM `feather_access_grants` WHERE `grant_id`=? FOR UPDATE', request.grantId)
        if not locked then return Access.Err('grant_not_found', 'Grant not found.') end
        if tonumber(locked.revision) ~= request.expectedRevision then return Access.Err('revision_conflict', 'Grant revision changed.') end
        if locked.status == 'revoked' then return Access.Err('grant_revoked', 'Grant already revoked.') end
        tx.exec([[UPDATE `feather_access_grants` SET `status`='revoked',`revision`=`revision`+1 WHERE `grant_id`=?]], request.grantId)
        locked.status, locked.revision = 'revoked', request.expectedRevision + 1
        local grant = G.Snapshot(locked)
        G.Record(tx, G.Clock(tx).event_id, 'access.grant.revoked.v1', grant, actor, request)
        return Access.Ok(grant)
    end)
end

function G.Check(request, caller)
    local started = GetGameTimer()
    if not Access.OnlyFields(request, { targetType = true, targetId = true, capability = true, actorSource = true, characterId = true })
        or not Access.Key(request.targetType) or not Access.Uuid(request.targetId) or not Access.Key(request.capability)
        or (request.actorSource == nil) == (request.characterId == nil)
        or (request.actorSource ~= nil and not Access.Integer(request.actorSource, 1, 65535))
        or (request.characterId ~= nil and not Access.Uuid(request.characterId)) then
        return Access.Err('invalid_input', 'Exact target/capability and one actor source or trusted offline character UUID required.')
    end
    request = Access.Copy(request); request.targetId = request.targetId:lower()
    local begun = G.Begin(request, caller, 'Readers')
    if not begun.ok then return begun end
    local actor = begun.value
    local characterId = actor.characterId or request.characterId:lower()
    local identity = G.Character(characterId)
    if not identity.ok then return identity end
    local context = G.Context(request.targetType, request.targetId)
    if not context.ok then return context end
    local denied = Access.Ok({ allowed = false })
    if context.value.status ~= 'active' or not G.Capability(context.value, request.capability) then return denied end
    local rows = DB.query([[SELECT * FROM `feather_access_grants`
        WHERE `target_type`=? AND `target_id`=? AND `target_epoch`=? AND `capability`=? AND `status`='active'
        AND `valid_from`<=FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000)
        AND `valid_until`>FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000)
        AND ((`grantee_type`='character' AND `grantee_id`=?) OR `grantee_type`='organization')
        ORDER BY `grant_id` LIMIT 257]], request.targetType, request.targetId, context.value.epoch, request.capability, characterId)
    if #rows > 256 then return Access.Err('limit_exceeded', 'Too many candidate grants; reconcile overlapping grants.') end
    local matched, organizations, hasCharacter = {}, {}, false
    for _, row in ipairs(rows) do if row.grantee_type == 'character' then hasCharacter = true end end
    for _, row in ipairs(rows) do
        if GetGameTimer() - started >= Config.Grants.CheckTimeoutMs then
            return Access.Err('operation_timeout', 'Capability check exceeded its context budget.')
        end
        local qualifies = row.grantee_type == 'character'
        if not qualifies and not hasCharacter then
            local org = organizations[row.grantee_id]
            if not org then
                local catalog = Access.Providers.Catalog(row.grantee_id)
                if not catalog.ok then return catalog end
                local membership = Access.Providers.ResolveMembership({ organizationId = row.grantee_id, characterId = characterId }, GetCurrentResourceName())
                if not membership.ok then return membership end
                org = { roles = {}, active = catalog.value.status == 'active' and membership.value.status == 'active'
                    and catalog.value.provider.generation == membership.value.provider.generation }
                local known = {}; for _, role in ipairs(catalog.value.roleIds) do known[role] = true end
                for _, role in ipairs(membership.value.roleIds) do if known[role] then org.roles[role] = true end end
                organizations[row.grantee_id] = org
            end
            for _, role in ipairs(G.Snapshot(row).roleIds) do qualifies = qualifies or (org.active and org.roles[role] == true) end
        end
        if qualifies then matched[#matched + 1] = row.grant_id end
    end
    if #matched == 0 then return denied end
    local fresh = G.Context(request.targetType, request.targetId)
    if not fresh.ok then return fresh end
    if fresh.value.status ~= 'active' or fresh.value.epoch ~= context.value.epoch
        or fresh.value.provider.generation ~= context.value.provider.generation
        or not G.Capability(fresh.value, request.capability) then return denied end
    local placeholders = {}; for _ in ipairs(matched) do placeholders[#placeholders + 1] = '?' end
    local row = DB.one([[SELECT `grant_id`,`valid_until`,FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000) AS now_ms
        FROM `feather_access_grants` WHERE `grant_id` IN (]] .. table.concat(placeholders, ',') .. [[)
        AND `status`='active' AND `valid_from`<=FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000)
        AND `valid_until`>FLOOR(UNIX_TIMESTAMP(CURRENT_TIMESTAMP(3))*1000) ORDER BY `grant_id` LIMIT 1]], table.unpack(matched))
    local current = G.Current(actor)
    if not current.ok then return current end
    if GetGameTimer() - started >= Config.Grants.CheckTimeoutMs then
        return Access.Err('operation_timeout', 'Capability check exceeded its context budget.')
    end
    return Access.Ok({ allowed = row ~= nil, grantId = row and row.grant_id or nil,
        validForMs = row and math.max(0, tonumber(row.valid_until) - tonumber(row.now_ms)) or nil })
end

local function List(request, caller, target)
    local fields = target and { targetType = true, targetId = true, limit = true, cursor = true, actorSource = true }
        or { granteeType = true, granteeId = true, limit = true, cursor = true, actorSource = true }
    if not Access.OnlyFields(request, fields) or (request.limit ~= nil and not Access.Integer(request.limit, 1, 50))
        or (request.cursor ~= nil and not Access.Uuid(request.cursor)) then return Access.Err('invalid_input', 'Invalid list bounds or cursor.') end
    if target then
        if not Access.Key(request.targetType) or not Access.Uuid(request.targetId) then return Access.Err('invalid_input', 'Target identity required.') end
    elseif (request.granteeType ~= 'character' and request.granteeType ~= 'organization') or not Access.Uuid(request.granteeId) then
        return Access.Err('invalid_input', 'Grantee identity required.')
    end
    local begun = G.Begin(request, caller, target and 'Managers' or 'Auditors')
    if not begun.ok then return begun end
    local targetContext
    if target then
        local context = G.Context(request.targetType, request.targetId:lower())
        if not context.ok then return context end
        targetContext = context.value
        local authorized = Access.Providers.Authorize(context.value, begun.value, 'list')
        if not authorized.ok then return authorized end
    end
    local limit = request.limit or 25
    local where = target and '`target_type`=? AND `target_id`=?' or '`grantee_type`=? AND `grantee_id`=?'
    local rows = DB.query('SELECT * FROM `feather_access_grants` WHERE ' .. where .. ' AND `grant_id`>? ORDER BY `grant_id` LIMIT ?',
        target and request.targetType or request.granteeType, (target and request.targetId or request.granteeId):lower(),
        request.cursor and request.cursor:lower() or '', limit + 1)
    local items = {}; for index = 1, math.min(#rows, limit) do items[index] = G.Snapshot(rows[index]) end
    if targetContext then
        local fresh = G.Context(targetContext.targetType, targetContext.targetId)
        if not fresh.ok then return fresh end
        if fresh.value.epoch ~= targetContext.epoch or fresh.value.provider.generation ~= targetContext.provider.generation
            or fresh.value.status ~= targetContext.status then
            return Access.Err('epoch_conflict', 'Target authority changed during listing.')
        end
    end
    local current = G.Current(begun.value)
    if not current.ok then return current end
    return Access.Ok({ items = items, nextCursor = #rows > limit and items[#items].grantId or nil })
end
function G.ListTarget(request, caller) return List(request, caller, true) end
function G.ListGrantee(request, caller) return List(request, caller, false) end

function G.Find(request, caller)
    if not Access.OnlyFields(request, { requestId = true }) or not G.Token(request.requestId, 128) then
        return Access.Err('invalid_input', 'Request ID required.')
    end
    local begun = G.Begin(request, caller, 'Readers')
    if not begun.ok then return begun end
    local row = DB.one([[SELECT `operation`,`result_json` FROM `feather_access_receipts`
        WHERE `source_resource`=? AND `request_id`=?]], caller, request.requestId)
    if not row then return Access.Ok({ found = false }) end
    local decoded, value = pcall(json.decode, row.result_json)
    if not decoded or type(value) ~= 'table' then return Access.Err('invalid_persistence', 'Invalid stored receipt.') end
    return Access.Ok({ found = true, operation = row.operation, result = value })
end
