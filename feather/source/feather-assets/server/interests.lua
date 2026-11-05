AssetInterests = {}
local Ok, Err = Assets.Ok, Assets.Err

-- TransferOwnership ------------------------------------------------------------
-- Ends the current owner interest and opens the new one in one commit. The asset
-- row lock plus expectedRevision means two concurrent sales of the same asset
-- cannot both succeed: the second sees revision_conflict. A consumer that has
-- just checked the seller passes fromHolderType/fromHolderId so a stale view of
-- the owner is rejected (holder_mismatch) instead of silently overwritten.
-- Only an 'active' asset can change hands; held and missing assets cannot.
-- The delegation epoch rises in the same commit, so grants made under the
-- previous owner stop applying at once, even on a later return to that owner.

local transferFields = Assets.Allowed({
    'assetId',
    'expectedRevision',
    'toHolderType',
    'toHolderId',
    'fromHolderType',
    'fromHolderId',
    'preservationManifestId'
})

function AssetInterests.Transfer(request, resource)
    local begun = Assets.Begin(request, resource, transferFields)
    if not begun.ok then
        return begun
    end
    if not Assets.Uuid(request.assetId) or not Assets.Integer(request.expectedRevision, 1, Assets.MaxRevision)
        or not Config.HolderTypes[request.toHolderType or ''] or not Assets.Uuid(request.toHolderId)
        or (request.fromHolderType == nil) ~= (request.fromHolderId == nil)
        or (request.fromHolderType ~= nil and not Config.HolderTypes[request.fromHolderType])
        or (request.fromHolderId ~= nil and not Assets.Uuid(request.fromHolderId))
        or (request.preservationManifestId~=nil and not Assets.Uuid(request.preservationManifestId)) then
        return Err('invalid_input',
            'Asset UUID, expected revision, new holder, and optional expected current holder required.')
    end
    request = Assets.Copy(request)
    request.assetId = request.assetId:lower()
    if request.preservationManifestId then request.preservationManifestId=request.preservationManifestId:lower()end
    request.toHolderId = request.toHolderId:lower()
    if request.fromHolderId then
        request.fromHolderId = request.fromHolderId:lower()
    end
    local actor = Assets.Policy(Config.Authorization.transferAction, request, resource, {
        assetId = request.assetId,
        holderType = request.toHolderType,
        holderId = request.toHolderId
    })
    if not actor.ok then
        return actor
    end

    local handoff
    return Assets.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'ownership.transfer',
        fingerprint = Assets.Fingerprint('ownership.transfer', request, {
            'assetId',
            'expectedRevision',
            'toHolderType',
            'toHolderId',
            'preservationManifestId',
            'fromHolderType',
            'fromHolderId',
            'reasonCode'
        }),
        precheck = function()
            -- asset_type never changes, so an unlocked read is enough to validate
            -- the new holder against it before the transaction.
            local row = DB.one('SELECT `asset_type` FROM `feather_asset_records` WHERE `asset_id`=?', request.assetId)
            if not row then
                return Err('asset_not_found', 'Asset not found.')
            end
            local holder = Assets.ValidateHolder(row.asset_type, request.toHolderType, request.toHolderId)
            if not holder.ok then
                return holder
            end
            if request.preservationManifestId then
                local resolved=AssetDelegation.ResolveManifest(request.preservationManifestId,request.assetId)
                if not resolved.ok then return resolved end
                handoff=resolved.value
            end
            return Ok({})
        end,
        body = function(tx)
            local row = AssetRecords.Lock(tx, request.assetId)
            local checked = AssetRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            if handoff and tonumber(row.delegation_epoch)~=handoff.sourceEpoch then return Err('epoch_conflict','Preservation manifest ownership context changed.')end
            if row.status ~= 'active' then
                return Err('asset_unavailable', 'Only an active asset can change owner.', { status = row.status })
            end
            local owner = AssetRecords.LockOwner(tx, request.assetId)
            if not owner then
                return Err('invalid_persistence', 'Active asset has no owner interest.')
            end
            if request.fromHolderType and (owner.holder_type ~= request.fromHolderType
                or owner.holder_id ~= request.fromHolderId) then
                return Err('holder_mismatch', 'Asset is not held by the expected holder.')
            end
            if owner.holder_type == request.toHolderType and owner.holder_id == request.toHolderId then
                return Err('no_change', 'Asset is already owned by that holder.')
            end

            local ids, nowSeconds = Assets.NewIds(tx, 2, true)
            local interestId = ids[1]
            -- End first: the unique active slot only frees once the old row is NULL.
            tx.exec([[
                UPDATE `feather_asset_interests`
                SET `status`='ended',`active_slot`=NULL,`valid_until`=FROM_UNIXTIME(?),
                    `revision`=`revision`+1
                WHERE `interest_id`=?]], nowSeconds, owner.interest_id)
            tx.exec([[
                INSERT INTO `feather_asset_interests`
                    (`interest_id`,`asset_id`,`holder_type`,`holder_id`,`interest_type`,`active_slot`,`valid_from`)
                VALUES (?,?,?,?,'owner',?,FROM_UNIXTIME(?))]],
                interestId, request.assetId, request.toHolderType, request.toHolderId,
                request.assetId .. '|owner', nowSeconds)
            tx.exec([[
                UPDATE `feather_asset_records`
                SET `revision`=`revision`+1,`delegation_epoch`=`delegation_epoch`+1
                WHERE `asset_id`=? AND `revision`=?]], request.assetId, revision)

            AssetEvents.Record(tx, 'ownership.transferred', {
                assetId = request.assetId,
                assetType = row.asset_type,
                holderType = request.toHolderType,
                holderId = request.toHolderId,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = {
                    modelKey = row.model_key,
                    interestId = interestId,
                    previousInterestId = owner.interest_id,
                    previousHolderType = owner.holder_type,
                    previousHolderId = owner.holder_id,
                    delegationEpoch = tonumber(row.delegation_epoch) + 1
                }
            }, ids[2])
            local result=AssetRecords.Read(tx, request.assetId)
            if result.ok and handoff then result.value.delegationHandoff={manifestId=handoff.manifestId,
                targetId=request.assetId,sourceEpoch=handoff.sourceEpoch,targetEpoch=handoff.sourceEpoch+1,
                newOwnerType=request.toHolderType,newOwnerId=request.toHolderId}end
            return result
        end
    })
end

-- CheckInterest ----------------------------------------------------------------
-- Returns facts only: whether the holder currently holds that interest, and the
-- asset's status. The consuming resource still decides what those facts permit
-- (a held horse is still owned, but a stable may refuse to release it).

local checkFields = {
    assetId = true,
    holderType = true,
    holderId = true,
    interestType = true
}

function AssetInterests.Check(request, resource)
    local allowed = Assets.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Assets.Fields(request, checkFields)
    if not fields.ok then
        return fields
    end
    local interestType = request.interestType or 'owner'
    if not Assets.Uuid(request.assetId) or not Config.HolderTypes[request.holderType or '']
        or not Assets.Uuid(request.holderId) or not Assets.InterestTypes[interestType] then
        return Err('invalid_input', 'Asset UUID, holder type and UUID, and supported interest type required.')
    end
    local row = DB.one([[
        SELECT r.`asset_type`,r.`status`,r.`delegation_epoch`,i.`interest_id`
        FROM `feather_asset_records` r
        LEFT JOIN `feather_asset_interests` i
            ON i.`asset_id`=r.`asset_id` AND i.`interest_type`=? AND i.`status`='active'
            AND i.`holder_type`=? AND i.`holder_id`=?
        WHERE r.`asset_id`=?]],
        interestType, request.holderType, request.holderId:lower(), request.assetId:lower())
    if not row then
        return Err('asset_not_found', 'Asset not found.')
    end
    return Ok({
        matched = row.interest_id ~= nil,
        interestType = interestType,
        interestId = row.interest_id,
        assetType = row.asset_type,
        assetStatus = row.status,
        delegationEpoch = tonumber(row.delegation_epoch)
    })
end

Assets.Export('TransferOwnership', AssetInterests.Transfer)
Assets.Export('CheckInterest', AssetInterests.Check)
