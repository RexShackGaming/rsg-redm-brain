AssetRecords = {}
local Ok, Err = Assets.Ok, Assets.Err

-- An asset row with its current (active) owner interest, if any.
local selectAsset = [[
    SELECT r.`asset_id`,r.`asset_type`,r.`model_key`,r.`status`,r.`manager_resource`,
        r.`provenance_type`,r.`provenance_id`,r.`metadata_version`,r.`metadata_json`,r.`revision`,
        r.`delegation_epoch`,
        FLOOR(UNIX_TIMESTAMP(r.`created_at`))*1000 AS created_at_ms,
        FLOOR(UNIX_TIMESTAMP(r.`updated_at`))*1000 AS updated_at_ms,
        FLOOR(UNIX_TIMESTAMP(r.`retired_at`))*1000 AS retired_at_ms,
        i.`interest_id`,i.`holder_type`,i.`holder_id`,i.`revision` AS interest_revision,
        FLOOR(UNIX_TIMESTAMP(i.`valid_from`))*1000 AS valid_from_ms
    FROM `feather_asset_records` r
    LEFT JOIN `feather_asset_interests` i
        ON i.`asset_id`=r.`asset_id` AND i.`interest_type`='owner' AND i.`status`='active']]
AssetRecords.Select = selectAsset

-- Snapshots and shared helpers -------------------------------------------------

function AssetRecords.Snapshot(row, includeMetadata)
    if not row then
        return Err('asset_not_found', 'Asset not found.')
    end
    local statusValid = Assets.Statuses[row.status] or row.status == 'retired'
    if not Assets.Uuid(row.asset_id) or not Assets.Key(row.asset_type, 32) or not statusValid
        or not Assets.Integer(tonumber(row.revision), 1, Assets.MaxRevision + 1)
        or not Assets.Integer(tonumber(row.delegation_epoch), 1, Assets.MaxRevision + 1)
        or (row.status ~= 'retired' and not Assets.Uuid(row.interest_id)) then
        return Err('invalid_persistence', 'Persisted asset is invalid.')
    end
    local snapshot = {
        assetId = row.asset_id,
        assetType = row.asset_type,
        modelKey = row.model_key,
        status = row.status,
        managerResource = row.manager_resource,
        provenanceType = row.provenance_type,
        provenanceId = row.provenance_id,
        metadataVersion = tonumber(row.metadata_version),
        revision = tonumber(row.revision),
        delegationEpoch = tonumber(row.delegation_epoch),
        createdAt = tonumber(row.created_at_ms),
        updatedAt = tonumber(row.updated_at_ms),
        retiredAt = row.retired_at_ms and tonumber(row.retired_at_ms) or nil
    }
    if row.interest_id then
        snapshot.owner = {
            interestId = row.interest_id,
            holderType = row.holder_type,
            holderId = row.holder_id,
            revision = tonumber(row.interest_revision),
            validFrom = tonumber(row.valid_from_ms)
        }
    end
    if includeMetadata then
        local metadata = {}
        if row.metadata_json then
            local decoded, value = pcall(json.decode, row.metadata_json)
            if not decoded or type(value) ~= 'table' then
                return Err('invalid_persistence', 'Persisted asset metadata is invalid.')
            end
            metadata = value
        end
        snapshot.metadata = metadata
    end
    return Ok(snapshot)
end

function AssetRecords.Read(tx, assetId)
    local row = (tx.query(selectAsset .. ' WHERE r.`asset_id`=?', assetId) or {})[1]
    return AssetRecords.Snapshot(row, true)
end

-- Locks the asset row. Lock order across all asset mutations is:
-- receipt -> asset record -> interests.
function AssetRecords.Lock(tx, assetId)
    return (tx.query([[
        SELECT `asset_id`,`asset_type`,`model_key`,`status`,`manager_resource`,`metadata_version`,`revision`,
            `delegation_epoch`
        FROM `feather_asset_records`
        WHERE `asset_id`=? FOR UPDATE]], assetId) or {})[1]
end

-- Common checks on a locked row before any change to an existing asset.
function AssetRecords.CheckMutable(row, resource, expectedRevision)
    if not row then
        return Err('asset_not_found', 'Asset not found.')
    end
    if not Assets.CanMutate(row.manager_resource, resource) then
        return Err('authorization_denied', 'Caller does not manage this asset.')
    end
    if row.status == 'retired' then
        return Err('asset_retired', 'Asset has been retired.')
    end
    local revision = tonumber(row.revision)
    if revision ~= expectedRevision then
        return Err('revision_conflict', 'Asset revision changed.', { revision = revision })
    end
    return Ok(revision)
end

-- Current owner interest of a locked asset, locked in turn.
function AssetRecords.LockOwner(tx, assetId)
    return (tx.query([[
        SELECT `interest_id`,`holder_type`,`holder_id`,`revision`
        FROM `feather_asset_interests`
        WHERE `asset_id`=? AND `interest_type`='owner' AND `status`='active' FOR UPDATE]], assetId) or {})[1]
end

-- RegisterAsset ----------------------------------------------------------------
-- The caller becomes the managing resource. Provenance (purchase, capture, legacy
-- row) is unique per manager, so a duplicated registration cannot create a
-- second asset; replays of the same request ID return the stored result.

local registerFields = Assets.Allowed({
    'assetType',
    'modelKey',
    'holderType',
    'holderId',
    'provenanceType',
    'provenanceId',
    'metadataVersion',
    'metadata'
})

function AssetRecords.Register(request, resource)
    local begun = Assets.Begin(request, resource, registerFields)
    if not begun.ok then
        return begun
    end
    if not Config.AssetTypes[request.assetType or ''] or not Assets.ModelKey(request.modelKey)
        or not Config.HolderTypes[request.holderType or ''] or not Assets.Uuid(request.holderId)
        or not Assets.Key(request.provenanceType, 48) or not Assets.Token(request.provenanceId, 128)
        or (request.metadataVersion ~= nil and not Assets.Integer(request.metadataVersion, 1, 65535)) then
        return Err('invalid_input',
            'Configured asset type, model key, holder, provenance, and optional metadata version required.')
    end
    local encoded
    if request.metadata ~= nil then
        local metadata = Assets.ValidateMetadata(request.metadata)
        if not metadata.ok then
            return metadata
        end
        encoded = metadata.value
    end
    request = Assets.Copy(request)
    request.holderId = request.holderId:lower()
    request.metadataCanonical = request.metadata ~= nil and Assets.Canonical(request.metadata) or nil
    local actor = Assets.Policy(Config.Authorization.manageAction, request, resource, {
        assetType = request.assetType,
        holderType = request.holderType,
        holderId = request.holderId
    })
    if not actor.ok then
        return actor
    end

    return Assets.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'asset.register',
        fingerprint = Assets.Fingerprint('asset.register', request, {
            'assetType',
            'modelKey',
            'holderType',
            'holderId',
            'provenanceType',
            'provenanceId',
            'metadataVersion',
            'metadataCanonical',
            'reasonCode'
        }),
        precheck = function()
            local holder = Assets.ValidateHolder(request.assetType, request.holderType, request.holderId)
            if not holder.ok then
                return holder
            end
            return Ok({})
        end,
        body = function(tx)
            -- Asset, owner interest and event IDs plus one shared timestamp.
            local ids, nowSeconds = Assets.NewIds(tx, 3, true)
            local assetId, interestId = ids[1], ids[2]
            local metadataVersion = request.metadataVersion or 1

            -- The provenance unique key decides duplicates. INSERT IGNORE avoids the
            -- gap locks a SELECT ... FOR UPDATE on a missing row would take, which
            -- deadlock concurrent registrations of different provenances.
            local inserted = tx.exec([[
                INSERT IGNORE INTO `feather_asset_records`
                    (`asset_id`,`asset_type`,`model_key`,`manager_resource`,`provenance_type`,
                     `provenance_id`,`metadata_version`,`metadata_json`,`created_at`,`updated_at`)
                VALUES (?,?,?,?,?,?,?,?,FROM_UNIXTIME(?),FROM_UNIXTIME(?))]],
                assetId, request.assetType, request.modelKey, resource, request.provenanceType,
                request.provenanceId, metadataVersion, encoded, nowSeconds, nowSeconds)
            if tonumber(inserted) ~= 1 then
                local existing = (tx.query([[
                    SELECT `asset_id` FROM `feather_asset_records`
                    WHERE `manager_resource`=? AND `provenance_type`=? AND `provenance_id`=?]],
                    resource, request.provenanceType, request.provenanceId) or {})[1]
                return Err('asset_exists', 'This provenance is already registered.', {
                    assetId = existing and existing.asset_id
                })
            end
            tx.exec([[
                INSERT INTO `feather_asset_interests`
                    (`interest_id`,`asset_id`,`holder_type`,`holder_id`,`interest_type`,`active_slot`,`valid_from`)
                VALUES (?,?,?,?,'owner',?,FROM_UNIXTIME(?))]],
                interestId, assetId, request.holderType, request.holderId, assetId .. '|owner', nowSeconds)

            AssetEvents.Record(tx, 'asset.registered', {
                assetId = assetId,
                assetType = request.assetType,
                holderType = request.holderType,
                holderId = request.holderId,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = 1,
                actor = actor.value,
                details = {
                    modelKey = request.modelKey,
                    status = 'active',
                    interestId = interestId,
                    provenanceType = request.provenanceType,
                    provenanceId = request.provenanceId,
                    managerResource = resource,
                    metadataVersion = metadataVersion,
                    delegationEpoch = 1
                }
            }, ids[3])
            return AssetRecords.Read(tx, assetId)
        end
    })
end

-- ChangeAssetStatus ------------------------------------------------------------
-- active, held (impounded, collateral) or missing. Retirement is RetireAsset.

local statusFields = Assets.Allowed({ 'assetId', 'expectedRevision', 'status' })

function AssetRecords.ChangeStatus(request, resource)
    local begun = Assets.Begin(request, resource, statusFields)
    if not begun.ok then
        return begun
    end
    if not Assets.Uuid(request.assetId) or not Assets.Integer(request.expectedRevision, 1, Assets.MaxRevision)
        or not Assets.Statuses[request.status or ''] then
        return Err('invalid_input', 'Asset UUID, expected revision, and status (active, held, missing) required.')
    end
    request = Assets.Copy(request)
    request.assetId = request.assetId:lower()
    local actor = Assets.Policy(Config.Authorization.manageAction, request, resource, {
        assetId = request.assetId,
        status = request.status
    })
    if not actor.ok then
        return actor
    end

    return Assets.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'asset.status',
        fingerprint = Assets.Fingerprint('asset.status', request, {
            'assetId',
            'expectedRevision',
            'status',
            'reasonCode'
        }),
        body = function(tx)
            local row = AssetRecords.Lock(tx, request.assetId)
            local checked = AssetRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            if row.status == request.status then
                return Err('no_change', 'Asset already has that status.')
            end
            local owner = AssetRecords.LockOwner(tx, request.assetId)
            tx.exec([[
                UPDATE `feather_asset_records` SET `status`=?,`revision`=`revision`+1
                WHERE `asset_id`=? AND `revision`=?]], request.status, request.assetId, revision)

            AssetEvents.Record(tx, 'status.changed', {
                assetId = request.assetId,
                assetType = row.asset_type,
                holderType = owner and owner.holder_type,
                holderId = owner and owner.holder_id,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = {
                    status = request.status,
                    previousStatus = row.status
                }
            })
            return AssetRecords.Read(tx, request.assetId)
        end
    })
end

-- UpdateAssetMetadata ----------------------------------------------------------
-- Replaces the whole metadata document. metadataVersion is the consumer's schema
-- version for it; metadata = false clears the document.

local metadataFields = Assets.Allowed({ 'assetId', 'expectedRevision', 'metadataVersion', 'metadata' })

function AssetRecords.UpdateMetadata(request, resource)
    local begun = Assets.Begin(request, resource, metadataFields)
    if not begun.ok then
        return begun
    end
    if not Assets.Uuid(request.assetId) or not Assets.Integer(request.expectedRevision, 1, Assets.MaxRevision)
        or not Assets.Integer(request.metadataVersion, 1, 65535)
        or (request.metadata ~= false and type(request.metadata) ~= 'table') then
        return Err('invalid_input', 'Asset UUID, expected revision, metadata version, and metadata or false required.')
    end
    local encoded
    if request.metadata ~= false then
        local metadata = Assets.ValidateMetadata(request.metadata)
        if not metadata.ok then
            return metadata
        end
        encoded = metadata.value
    end
    request = Assets.Copy(request)
    request.assetId = request.assetId:lower()
    request.metadataCanonical = request.metadata ~= false and Assets.Canonical(request.metadata) or 'cleared'
    request.metadata = nil
    local actor = Assets.Policy(Config.Authorization.manageAction, request, resource, {
        assetId = request.assetId
    })
    if not actor.ok then
        return actor
    end

    return Assets.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'asset.metadata',
        fingerprint = Assets.Fingerprint('asset.metadata', request, {
            'assetId',
            'expectedRevision',
            'metadataVersion',
            'metadataCanonical',
            'reasonCode'
        }),
        body = function(tx)
            local row = AssetRecords.Lock(tx, request.assetId)
            local checked = AssetRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            local owner = AssetRecords.LockOwner(tx, request.assetId)
            tx.exec([[
                UPDATE `feather_asset_records`
                SET `metadata_version`=?,`metadata_json`=?,`revision`=`revision`+1
                WHERE `asset_id`=? AND `revision`=?]],
                request.metadataVersion, encoded, request.assetId, revision)

            AssetEvents.Record(tx, 'metadata.revised', {
                assetId = request.assetId,
                assetType = row.asset_type,
                holderType = owner and owner.holder_type,
                holderId = owner and owner.holder_id,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = {
                    metadataVersion = request.metadataVersion,
                    previousMetadataVersion = tonumber(row.metadata_version)
                }
            })
            return AssetRecords.Read(tx, request.assetId)
        end
    })
end

-- RetireAsset ------------------------------------------------------------------
-- Terminal: the asset (a dead horse, a destroyed wagon) keeps its record and
-- history, and its owner interest ends in the same commit. The delegation epoch
-- rises too, so no grant made under the last owner can apply again.

local retireFields = Assets.Allowed({ 'assetId', 'expectedRevision' })

function AssetRecords.Retire(request, resource)
    local begun = Assets.Begin(request, resource, retireFields)
    if not begun.ok then
        return begun
    end
    if not Assets.Uuid(request.assetId) or not Assets.Integer(request.expectedRevision, 1, Assets.MaxRevision) then
        return Err('invalid_input', 'Asset UUID and expected revision required.')
    end
    request = Assets.Copy(request)
    request.assetId = request.assetId:lower()
    local actor = Assets.Policy(Config.Authorization.manageAction, request, resource, {
        assetId = request.assetId,
        status = 'retired'
    })
    if not actor.ok then
        return actor
    end

    return Assets.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'asset.retire',
        fingerprint = Assets.Fingerprint('asset.retire', request, {
            'assetId',
            'expectedRevision',
            'reasonCode'
        }),
        body = function(tx)
            local row = AssetRecords.Lock(tx, request.assetId)
            local checked = AssetRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            local owner = AssetRecords.LockOwner(tx, request.assetId)
            if owner then
                tx.exec([[
                    UPDATE `feather_asset_interests`
                    SET `status`='ended',`active_slot`=NULL,`valid_until`=CURRENT_TIMESTAMP,
                        `revision`=`revision`+1
                    WHERE `interest_id`=?]], owner.interest_id)
            end
            tx.exec([[
                UPDATE `feather_asset_records`
                SET `status`='retired',`retired_at`=CURRENT_TIMESTAMP,`revision`=`revision`+1,
                    `delegation_epoch`=`delegation_epoch`+1
                WHERE `asset_id`=? AND `revision`=?]], request.assetId, revision)

            AssetEvents.Record(tx, 'asset.retired', {
                assetId = request.assetId,
                assetType = row.asset_type,
                holderType = owner and owner.holder_type,
                holderId = owner and owner.holder_id,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = {
                    status = 'retired',
                    previousStatus = row.status,
                    previousInterestId = owner and owner.interest_id,
                    delegationEpoch = tonumber(row.delegation_epoch) + 1
                }
            })
            return AssetRecords.Read(tx, request.assetId)
        end
    })
end

-- Reads ------------------------------------------------------------------------

function AssetRecords.Get(request, resource)
    local allowed = Assets.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Assets.Fields(request, { assetId = true })
    if not fields.ok then
        return fields
    end
    if not Assets.Uuid(request.assetId) then
        return Err('invalid_input', 'Asset UUID required.')
    end
    local row = DB.one(selectAsset .. ' WHERE r.`asset_id`=?', request.assetId:lower())
    return AssetRecords.Snapshot(row, true)
end

-- Assets currently owned by one holder, newest first. Bounded and paged.
function AssetRecords.QueryByHolder(holderType, holderId, options)
    local sql = selectAsset .. ' WHERE i.`holder_type`=? AND i.`holder_id`=?'
    local params = { holderType, holderId }
    if options.assetType then
        sql = sql .. ' AND r.`asset_type`=?'
        params[#params + 1] = options.assetType
    end
    if options.status then
        sql = sql .. ' AND r.`status`=?'
        params[#params + 1] = options.status
    end
    if options.cursor then
        local cursor = DB.one([[
            SELECT DATE_FORMAT(`created_at`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_asset_records` WHERE `asset_id`=?]], options.cursor)
        if not cursor then
            return Err('invalid_cursor', 'Asset cursor was not found.')
        end
        sql = sql .. ' AND (r.`created_at`<? OR (r.`created_at`=? AND r.`asset_id`<?))'
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = options.cursor
    end
    sql = sql .. ' ORDER BY r.`created_at` DESC,r.`asset_id` DESC LIMIT ?'
    params[#params + 1] = options.limit + 1

    local rows = DB.query(sql, table.unpack(params)) or {}
    local items = {}
    for index = 1, math.min(#rows, options.limit) do
        local snapshot = AssetRecords.Snapshot(rows[index], options.includeMetadata)
        if not snapshot.ok then
            return snapshot
        end
        items[#items + 1] = snapshot.value
    end
    return Ok({
        items = items,
        nextCursor = #rows > options.limit and items[#items].assetId or nil
    })
end

local listFields = {
    holderType = true,
    holderId = true,
    assetType = true,
    status = true,
    includeMetadata = true,
    limit = true,
    cursor = true
}

function AssetRecords.ListByHolder(request, resource)
    local allowed = Assets.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Assets.Fields(request, listFields)
    if not fields.ok then
        return fields
    end
    local limit = request.limit == nil and 20 or request.limit
    if not Config.HolderTypes[request.holderType or ''] or not Assets.Uuid(request.holderId)
        or (request.assetType ~= nil and not Config.AssetTypes[request.assetType])
        or (request.status ~= nil and not Assets.Statuses[request.status])
        or (request.includeMetadata ~= nil and type(request.includeMetadata) ~= 'boolean')
        or not Assets.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.cursor ~= nil and not Assets.Uuid(request.cursor)) then
        return Err('invalid_input',
            'Holder type and UUID, optional asset type and status, bounded limit, and asset UUID cursor required.')
    end
    return AssetRecords.QueryByHolder(request.holderType, request.holderId:lower(), {
        assetType = request.assetType,
        status = request.status,
        includeMetadata = request.includeMetadata == true,
        limit = limit,
        cursor = request.cursor and request.cursor:lower() or nil
    })
end

Assets.Export('RegisterAsset', AssetRecords.Register)
Assets.Export('ChangeAssetStatus', AssetRecords.ChangeStatus)
Assets.Export('UpdateAssetMetadata', AssetRecords.UpdateMetadata)
Assets.Export('RetireAsset', AssetRecords.Retire)
Assets.Export('GetAsset', AssetRecords.Get)
Assets.Export('ListAssetsByHolder', AssetRecords.ListByHolder)
