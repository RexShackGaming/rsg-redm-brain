PropertyInterests = {}
local Ok, Err = Property.Ok, Property.Err

-- Interest rules shared by every mutation (all run under the property row lock):
-- * one holder holds at most one active interest of each type per property
--   (enforced by the active_slot unique key);
-- * the number of effective owners and tenants stays within the property's caps;
-- * only an 'active' property gains interests or changes owner; a 'suspended'
--   one keeps its interests; a 'retired' one has none.
-- Expired tenancies (valid_until passed) do not count towards caps; the expiry
-- sweep ends them and records the fact.

local function Slot(propertyId, interestType, holderType, holderId)
    return ('%s|%s|%s|%s'):format(propertyId, interestType, holderType, holderId)
end

-- Server time (Unix seconds) for validUntil checks inside a transaction.
local function Now(tx)
    return math.floor(tonumber((tx.query('SELECT UNIX_TIMESTAMP() AS now_s') or {})[1].now_s) or 0)
end

local function EndRows(tx, interestIds, nowSeconds)
    for _, interestId in ipairs(interestIds) do
        tx.exec([[
            UPDATE `feather_property_interests`
            SET `status`='ended',`active_slot`=NULL,`ended_at`=FROM_UNIXTIME(?),`revision`=`revision`+1
            WHERE `interest_id`=? AND `status`='active']], nowSeconds, interestId)
    end
end

local function BumpProperty(tx, propertyId, revision, ownersChanged)
    tx.exec([[
        UPDATE `feather_properties` SET `revision`=`revision`+1,
            `delegation_epoch`=`delegation_epoch`+?
        WHERE `property_id`=? AND `revision`=?]], ownersChanged and 1 or 0, propertyId, revision)
end

-- GrantInterest ----------------------------------------------------------------
-- Adds an owner (co-ownership) or a tenant. validUntil (Unix ms) bounds a
-- tenancy; omit it for an open-ended interest.

local grantFields = Property.Allowed({
    'propertyId',
    'expectedRevision',
    'holderType',
    'holderId',
    'interestType',
    'validUntil'
})

function PropertyInterests.Grant(request, resource)
    local begun = Property.Begin(request, resource, grantFields)
    if not begun.ok then
        return begun
    end
    if not Property.Uuid(request.propertyId) or not Property.Integer(request.expectedRevision, 1, Property.MaxRevision)
        or not Config.HolderTypes[request.holderType or ''] or not Property.Uuid(request.holderId)
        or not Property.InterestTypes[request.interestType or '']
        or (request.validUntil ~= nil and not Property.Integer(request.validUntil, 1, 32503680000000)) then
        return Err('invalid_input',
            'Property UUID, expected revision, holder, interest type (owner, tenant), and optional validUntil (Unix ms) required.')
    end
    request = Property.Copy(request)
    request.propertyId = request.propertyId:lower()
    request.holderId = request.holderId:lower()
    local actor = Property.Policy(Config.Authorization.interestAction, request, resource, {
        propertyId = request.propertyId,
        interestType = request.interestType,
        holderType = request.holderType,
        holderId = request.holderId
    })
    if not actor.ok then
        return actor
    end

    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'interest.grant',
        fingerprint = Property.Fingerprint('interest.grant', request, {
            'propertyId',
            'expectedRevision',
            'holderType',
            'holderId',
            'interestType',
            'validUntil',
            'reasonCode'
        }),
        precheck = function()
            -- property_type never changes, so an unlocked read is enough to
            -- validate the holder against it before the transaction.
            local row = DB.one('SELECT `property_type` FROM `feather_properties` WHERE `property_id`=?', request.propertyId)
            if not row then
                return Err('property_not_found', 'Property not found.')
            end
            local holder = Property.ValidateHolder(row.property_type, request.holderType, request.holderId)
            if not holder.ok then
                return holder
            end
            return Ok({})
        end,
        body = function(tx)
            local row = PropertyRecords.Lock(tx, request.propertyId)
            local checked = PropertyRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            if row.status ~= 'active' then
                return Err('property_unavailable', 'Only an active property can gain interests.', { status = row.status })
            end
            local ids, nowSeconds = Property.NewIds(tx, 2, true)
            if request.validUntil and math.floor(request.validUntil / 1000) <= nowSeconds then
                return Err('invalid_input', 'validUntil must be in the future.')
            end
            local count, expired, expiredRows = 0, {}, {}
            for _, interest in ipairs(PropertyRecords.LockInterests(tx, request.propertyId)) do
                if tonumber(interest.expired) == 1 then
                    expired[#expired + 1] = interest.interest_id
                    expiredRows[#expiredRows + 1] = interest
                elseif interest.interest_type == request.interestType then
                    if interest.holder_type == request.holderType and interest.holder_id == request.holderId then
                        return Err('interest_exists', 'Holder already has that interest.', {
                            interestId = interest.interest_id
                        })
                    end
                    count = count + 1
                end
            end
            local cap = tonumber(request.interestType == 'owner' and row.max_owners or row.max_tenants)
            if count >= cap then
                return Err('interest_limit', 'The property has no free place for that interest.', {
                    interestType = request.interestType,
                    limit = cap
                })
            end
            -- Expired tenancies free their slot before the new one is written.
            EndRows(tx, expired, nowSeconds)
            local interestId = ids[1]
            -- An open-ended interest stores valid_until = valid_from + 0 seconds
            -- turned into NULL by NULLIF, so both cases bind the same parameters.
            local untilSeconds = request.validUntil and math.floor(request.validUntil / 1000) or nowSeconds
            tx.exec([[
                INSERT INTO `feather_property_interests`
                    (`interest_id`,`property_id`,`holder_type`,`holder_id`,`interest_type`,`active_slot`,
                     `valid_from`,`valid_until`)
                VALUES (?,?,?,?,?,?,FROM_UNIXTIME(?),FROM_UNIXTIME(NULLIF(?,?)))]],
                interestId, request.propertyId, request.holderType, request.holderId, request.interestType,
                Slot(request.propertyId, request.interestType, request.holderType, request.holderId), nowSeconds,
                untilSeconds, nowSeconds)
            local ownersChanged = request.interestType == 'owner'
            for _, expiredInterest in ipairs(expiredRows) do
                if expiredInterest.interest_type == 'owner' then ownersChanged = true end
            end
            BumpProperty(tx, request.propertyId, revision, ownersChanged)

            -- Expired tenancies closed here are recorded like the sweep records them.
            local entries = {}
            for _, interest in ipairs(expiredRows) do
                entries[#entries + 1] = {
                    eventType = 'interest.ended',
                    spec = {
                        propertyId = request.propertyId,
                        propertyType = row.property_type,
                        holderType = interest.holder_type,
                        holderId = interest.holder_id,
                        resource = resource,
                        requestId = request.requestId,
                        reasonCode = 'property.tenancy_expired',
                        revision = revision + 1,
                        actor = actor.value,
                        details = {
                            interestId = interest.interest_id,
                            interestType = interest.interest_type
                        }
                    }
                }
            end
            entries[#entries + 1] = {
                eventType = 'interest.granted',
                eventId = ids[2],
                spec = {
                    propertyId = request.propertyId,
                    propertyType = row.property_type,
                    holderType = request.holderType,
                    holderId = request.holderId,
                    resource = resource,
                    requestId = request.requestId,
                    reasonCode = request.reasonCode,
                    referenceType = request.referenceType,
                    referenceId = request.referenceId,
                    revision = revision + 1,
                    actor = actor.value,
                    details = {
                        interestId = interestId,
                        interestType = request.interestType,
                        validUntil = request.validUntil
                    }
                }
            }
            PropertyEvents.RecordMany(tx, entries)
            return PropertyRecords.Read(tx, request.propertyId)
        end
    })
end

-- EndInterest ------------------------------------------------------------------
-- Ends one interest (a tenant moves out, a co-owner leaves). Ending the last
-- owner is allowed: the property then has no owner (back on the market).

local endFields = Property.Allowed({ 'propertyId', 'expectedRevision', 'interestId' })

function PropertyInterests.End(request, resource)
    local begun = Property.Begin(request, resource, endFields)
    if not begun.ok then
        return begun
    end
    if not Property.Uuid(request.propertyId) or not Property.Integer(request.expectedRevision, 1, Property.MaxRevision)
        or not Property.Uuid(request.interestId) then
        return Err('invalid_input', 'Property UUID, expected revision, and interest UUID required.')
    end
    request = Property.Copy(request)
    request.propertyId = request.propertyId:lower()
    request.interestId = request.interestId:lower()
    local actor = Property.Policy(Config.Authorization.interestAction, request, resource, {
        propertyId = request.propertyId,
        interestId = request.interestId
    })
    if not actor.ok then
        return actor
    end

    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'interest.end',
        fingerprint = Property.Fingerprint('interest.end', request, {
            'propertyId',
            'expectedRevision',
            'interestId',
            'reasonCode'
        }),
        body = function(tx)
            local row = PropertyRecords.Lock(tx, request.propertyId)
            local checked = PropertyRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            local target
            for _, interest in ipairs(PropertyRecords.LockInterests(tx, request.propertyId)) do
                if interest.interest_id == request.interestId then
                    target = interest
                end
            end
            if not target then
                return Err('interest_not_found', 'No active interest with that ID on this property.')
            end
            EndRows(tx, { target.interest_id }, Now(tx))
            BumpProperty(tx, request.propertyId, revision, target.interest_type == 'owner')

            PropertyEvents.Record(tx, 'interest.ended', {
                propertyId = request.propertyId,
                propertyType = row.property_type,
                holderType = target.holder_type,
                holderId = target.holder_id,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = {
                    interestId = target.interest_id,
                    interestType = target.interest_type
                }
            })
            return PropertyRecords.Read(tx, request.propertyId)
        end
    })
end

-- TransferOwnership ------------------------------------------------------------
-- Ends every current owner interest and grants one owner interest to the new
-- holder, in one commit. Tenancies are kept (a sold house keeps its tenant). The
-- property row lock plus expectedRevision means two concurrent sales cannot both
-- succeed: the second sees revision_conflict. fromHolderType/fromHolderId, when
-- given, must be one of the current owners, so a stale view of the seller is
-- rejected (holder_mismatch) instead of silently overwritten.

local transferFields = Property.Allowed({
    'propertyId',
    'expectedRevision',
    'toHolderType',
    'toHolderId',
    'fromHolderType',
    'fromHolderId',
    'preservationManifestId'
})

function PropertyInterests.Transfer(request, resource)
    local begun = Property.Begin(request, resource, transferFields)
    if not begun.ok then
        return begun
    end
    if not Property.Uuid(request.propertyId) or not Property.Integer(request.expectedRevision, 1, Property.MaxRevision)
        or not Config.HolderTypes[request.toHolderType or ''] or not Property.Uuid(request.toHolderId)
        or (request.fromHolderType == nil) ~= (request.fromHolderId == nil)
        or (request.fromHolderType ~= nil and not Config.HolderTypes[request.fromHolderType])
        or (request.fromHolderId ~= nil and not Property.Uuid(request.fromHolderId))
        or (request.preservationManifestId~=nil and not Property.Uuid(request.preservationManifestId)) then
        return Err('invalid_input',
            'Property UUID, expected revision, new holder, and optional expected current owner required.')
    end
    request = Property.Copy(request)
    request.propertyId = request.propertyId:lower()
    request.toHolderId = request.toHolderId:lower()
    if request.preservationManifestId then request.preservationManifestId=request.preservationManifestId:lower()end
    if request.fromHolderId then
        request.fromHolderId = request.fromHolderId:lower()
    end
    local actor = Property.Policy(Config.Authorization.interestAction, request, resource, {
        propertyId = request.propertyId,
        interestType = 'owner',
        holderType = request.toHolderType,
        holderId = request.toHolderId
    })
    if not actor.ok then
        return actor
    end

    local handoff
    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'ownership.transfer',
        fingerprint = Property.Fingerprint('ownership.transfer', request, {
            'propertyId',
            'expectedRevision',
            'toHolderType',
            'toHolderId',
            'preservationManifestId',
            'fromHolderType',
            'fromHolderId',
            'reasonCode'
        }),
        precheck = function()
            local row = DB.one('SELECT `property_type` FROM `feather_properties` WHERE `property_id`=?', request.propertyId)
            if not row then
                return Err('property_not_found', 'Property not found.')
            end
            local holder = Property.ValidateHolder(row.property_type, request.toHolderType, request.toHolderId)
            if not holder.ok then
                return holder
            end
            if request.preservationManifestId then
                local resolved=PropertyDelegation.ResolveManifest(request.preservationManifestId,request.propertyId)
                if not resolved.ok then return resolved end
                handoff=resolved.value
            end
            return Ok({})
        end,
        body = function(tx)
            local row = PropertyRecords.Lock(tx, request.propertyId)
            local checked = PropertyRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            if handoff and tonumber(row.delegation_epoch)~=handoff.sourceEpoch then return Err('epoch_conflict','Preservation manifest ownership context changed.')end
            if row.status ~= 'active' then
                return Err('property_unavailable', 'Only an active property can change owner.', { status = row.status })
            end
            if tonumber(row.max_owners) < 1 then
                return Err('interest_limit', 'This property cannot have owners.', { interestType = 'owner', limit = 0 })
            end
            local owners, fromFound = {}, request.fromHolderType == nil
            for _, interest in ipairs(PropertyRecords.LockInterests(tx, request.propertyId)) do
                if interest.interest_type == 'owner' then
                    owners[#owners + 1] = interest
                    if interest.holder_type == request.fromHolderType and interest.holder_id == request.fromHolderId then
                        fromFound = true
                    end
                end
            end
            if not fromFound then
                return Err('holder_mismatch', 'The property is not owned by the expected holder.')
            end
            if #owners == 1 and owners[1].holder_type == request.toHolderType
                and owners[1].holder_id == request.toHolderId then
                return Err('no_change', 'The property is already owned by that holder alone.')
            end

            local ids, nowSeconds = Property.NewIds(tx, 2, true)
            local interestId = ids[1]
            local endedIds, entries = {}, {}
            for _, owner in ipairs(owners) do
                endedIds[#endedIds + 1] = owner.interest_id
            end
            -- End first: the unique active slot only frees once the old rows are NULL.
            EndRows(tx, endedIds, nowSeconds)
            tx.exec([[
                INSERT INTO `feather_property_interests`
                    (`interest_id`,`property_id`,`holder_type`,`holder_id`,`interest_type`,`active_slot`,`valid_from`)
                VALUES (?,?,?,?,'owner',?,FROM_UNIXTIME(?))]],
                interestId, request.propertyId, request.toHolderType, request.toHolderId,
                Slot(request.propertyId, 'owner', request.toHolderType, request.toHolderId), nowSeconds)
            BumpProperty(tx, request.propertyId, revision, true)

            local previous = owners[1]
            entries[1] = {
                eventType = 'ownership.transferred',
                eventId = ids[2],
                spec = {
                    propertyId = request.propertyId,
                    propertyType = row.property_type,
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
                        propertyKey = row.property_key,
                        interestId = interestId,
                        interestType = 'owner',
                        endedInterestIds = #endedIds > 0 and endedIds or nil,
                        previousHolderType = previous and previous.holder_type,
                        previousHolderId = previous and previous.holder_id
                    }
                }
            }
            PropertyEvents.RecordMany(tx, entries)
            local result=PropertyRecords.Read(tx, request.propertyId)
            if result.ok and handoff then result.value.delegationHandoff={manifestId=handoff.manifestId,
                targetId=request.propertyId,sourceEpoch=handoff.sourceEpoch,targetEpoch=handoff.sourceEpoch+1,
                newOwnerType=request.toHolderType,newOwnerId=request.toHolderId}end
            return result
        end
    })
end

-- CheckInterest ----------------------------------------------------------------
-- Facts only: whether the holder has an effective interest of that type (or of
-- any type), and the property's status. The consumer decides what they permit
-- (a suspended house is still owned, but a door may stay locked).

local checkFields = {
    propertyId = true,
    propertyKey = true,
    holderType = true,
    holderId = true,
    interestType = true
}

function PropertyInterests.Check(request, resource)
    local allowed = Property.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Property.Fields(request, checkFields)
    if not fields.ok then
        return fields
    end
    if (request.propertyId == nil) == (request.propertyKey == nil)
        or (request.propertyId ~= nil and not Property.Uuid(request.propertyId))
        or (request.propertyKey ~= nil and not Property.PropertyKey(request.propertyKey))
        or not Config.HolderTypes[request.holderType or ''] or not Property.Uuid(request.holderId)
        or (request.interestType ~= nil and not Property.InterestTypes[request.interestType]) then
        return Err('invalid_input',
            'Property UUID or key (one of them), holder type and UUID, and optional interest type required.')
    end
    local property = request.propertyId
        and DB.one('SELECT `property_id`,`property_type`,`status` FROM `feather_properties` WHERE `property_id`=?',
            request.propertyId:lower())
        or DB.one('SELECT `property_id`,`property_type`,`status` FROM `feather_properties` WHERE `property_key`=?',
            request.propertyKey)
    if not property then
        return Err('property_not_found', 'Property not found.')
    end
    local sql = PropertyRecords.EffectiveInterests .. ' AND `property_id`=? AND `holder_type`=? AND `holder_id`=?'
    local params = { property.property_id, request.holderType, request.holderId:lower() }
    if request.interestType then
        sql = sql .. ' AND `interest_type`=?'
        params[#params + 1] = request.interestType
    end
    local rows = DB.query(sql .. ' ORDER BY `interest_type`', table.unpack(params)) or {}
    local interests = {}
    for _, row in ipairs(rows) do
        interests[#interests + 1] = {
            interestId = row.interest_id,
            interestType = row.interest_type,
            validUntil = row.valid_until_ms and tonumber(row.valid_until_ms) or nil
        }
    end
    return Ok({
        matched = #interests > 0,
        interests = interests,
        propertyId = property.property_id,
        propertyType = property.property_type,
        propertyStatus = property.status
    })
end

-- Tenancy expiry ---------------------------------------------------------------
-- Ends interests whose valid_until has passed and records the fact, attributed
-- to feather-property with reason property.tenancy_expired. Each interest is
-- ended in its own short transaction under the property lock.

local function ExpireOne(interestId)
    DB.transaction(function(tx)
        local interest = (tx.query([[
            SELECT `interest_id`,`property_id`,`holder_type`,`holder_id`,`interest_type`
            FROM `feather_property_interests`
            WHERE `interest_id`=? AND `status`='active' AND `valid_until`<=CURRENT_TIMESTAMP]], interestId) or {})[1]
        if not interest then
            return false
        end
        local row = PropertyRecords.Lock(tx, interest.property_id)
        local still = (tx.query([[
            SELECT `interest_id` FROM `feather_property_interests`
            WHERE `interest_id`=? AND `status`='active' AND `valid_until`<=CURRENT_TIMESTAMP FOR UPDATE]],
            interestId) or {})[1]
        if not row or not still then
            return false
        end
        local revision = tonumber(row.revision)
        EndRows(tx, { interestId }, Now(tx))
        BumpProperty(tx, interest.property_id, revision, interest.interest_type == 'owner')
        PropertyEvents.Record(tx, 'interest.ended', {
            propertyId = interest.property_id,
            propertyType = row.property_type,
            holderType = interest.holder_type,
            holderId = interest.holder_id,
            resource = GetCurrentResourceName(),
            requestId = 'expire:' .. interestId,
            reasonCode = 'property.tenancy_expired',
            revision = revision + 1,
            actor = { correlationId = 'expire:' .. interestId },
            details = {
                interestId = interestId,
                interestType = interest.interest_type
            }
        })
        return true
    end)
end

function PropertyInterests.SweepExpired()
    local rows = DB.query([[
        SELECT `interest_id` FROM `feather_property_interests`
        WHERE `status`='active' AND `valid_until` IS NOT NULL AND `valid_until`<=CURRENT_TIMESTAMP
        ORDER BY `valid_until` LIMIT 50]]) or {}
    local ended = 0
    for _, row in ipairs(rows) do
        local called, result = pcall(ExpireOne, row.interest_id)
        if called and result == true then
            ended = ended + 1
        elseif not called then
            print(('[feather-property] event=expiry.failed interest=%s reason=%s'):format(
                row.interest_id, tostring(result)))
        end
    end
    return ended
end

Property.Export('GrantInterest', PropertyInterests.Grant)
Property.Export('EndInterest', PropertyInterests.End)
Property.Export('TransferOwnership', PropertyInterests.Transfer)
Property.Export('CheckInterest', PropertyInterests.Check)
