PropertyRecords = {}
local Ok, Err = Property.Ok, Property.Err

local selectProperty = [[
    SELECT `property_id`,`property_key`,`property_type`,`label`,`status`,`manager_resource`,
        `max_owners`,`max_tenants`,`metadata_version`,`metadata_json`,`revision`,`delegation_epoch`,
        FLOOR(UNIX_TIMESTAMP(`created_at`))*1000 AS created_at_ms,
        FLOOR(UNIX_TIMESTAMP(`updated_at`))*1000 AS updated_at_ms,
        FLOOR(UNIX_TIMESTAMP(`retired_at`))*1000 AS retired_at_ms
    FROM `feather_properties`]]

-- Active interests that are in effect now: an expired tenancy stops counting at
-- once, even before the expiry sweep ends it.
local selectInterests = [[
    SELECT `interest_id`,`property_id`,`holder_type`,`holder_id`,`interest_type`,`revision`,
        FLOOR(UNIX_TIMESTAMP(`valid_from`))*1000 AS valid_from_ms,
        FLOOR(UNIX_TIMESTAMP(`valid_until`))*1000 AS valid_until_ms
    FROM `feather_property_interests`
    WHERE `status`='active' AND (`valid_until` IS NULL OR `valid_until`>CURRENT_TIMESTAMP)]]
PropertyRecords.EffectiveInterests = selectInterests

local function InterestSnapshot(row)
    return {
        interestId = row.interest_id,
        holderType = row.holder_type,
        holderId = row.holder_id,
        interestType = row.interest_type,
        revision = tonumber(row.revision),
        validFrom = tonumber(row.valid_from_ms),
        validUntil = row.valid_until_ms and tonumber(row.valid_until_ms) or nil
    }
end

-- Snapshots and shared helpers -------------------------------------------------

function PropertyRecords.Snapshot(row, interestRows, includeMetadata, linkRows)
    if not row then
        return Err('property_not_found', 'Property not found.')
    end
    if not Property.Uuid(row.property_id) or not Property.Key(row.property_type, 32)
        or not Property.Statuses[row.status]
        or not Property.Integer(tonumber(row.revision), 1, Property.MaxRevision + 1)
        or not Property.Integer(tonumber(row.delegation_epoch), 1, Property.MaxRevision + 1) then
        return Err('invalid_persistence', 'Persisted property is invalid.')
    end
    local snapshot = {
        propertyId = row.property_id,
        propertyKey = row.property_key,
        propertyType = row.property_type,
        label = row.label,
        status = row.status,
        managerResource = row.manager_resource,
        maxOwners = tonumber(row.max_owners),
        maxTenants = tonumber(row.max_tenants),
        metadataVersion = tonumber(row.metadata_version),
        revision = tonumber(row.revision),
        delegationEpoch = tonumber(row.delegation_epoch),
        createdAt = tonumber(row.created_at_ms),
        updatedAt = tonumber(row.updated_at_ms),
        retiredAt = row.retired_at_ms and tonumber(row.retired_at_ms) or nil,
        owners = {},
        tenants = {},
        links = {}
    }
    for _, interest in ipairs(interestRows or {}) do
        local list = interest.interest_type == 'owner' and snapshot.owners or snapshot.tenants
        list[#list + 1] = InterestSnapshot(interest)
    end
    for _, link in ipairs(linkRows or {}) do
        snapshot.links[#snapshot.links + 1] = {
            linkId = link.link_id,
            linkType = link.link_type,
            externalId = link.external_id
        }
    end
    if includeMetadata then
        local metadata = {}
        if row.metadata_json then
            local decoded, value = pcall(json.decode, row.metadata_json)
            if not decoded or type(value) ~= 'table' then
                return Err('invalid_persistence', 'Persisted property metadata is invalid.')
            end
            metadata = value
        end
        snapshot.metadata = metadata
    end
    return Ok(snapshot)
end

-- Reads one property with its effective interests through `db` (a transaction
-- handle or DB). `where` is 'property_id' or 'property_key'.
local function ReadBy(db, where, value, includeMetadata)
    local row = (db.query(selectProperty .. ' WHERE `' .. where .. '`=?', value) or {})[1]
    if not row then
        return Err('property_not_found', 'Property not found.')
    end
    local interests = db.query(selectInterests .. ' AND `property_id`=? ORDER BY `valid_from`,`interest_id`',
        row.property_id) or {}
    local links = db.query([[SELECT `link_id`,`link_type`,`external_id` FROM `feather_property_links`
        WHERE `property_id`=? ORDER BY `link_type`,`external_id`]], row.property_id) or {}
    return PropertyRecords.Snapshot(row, interests, includeMetadata, links)
end

function PropertyRecords.Read(tx, propertyId)
    return ReadBy(tx, 'property_id', propertyId, true)
end

-- Locks the property row. Lock order across all property mutations is:
-- receipt -> property row -> interests.
function PropertyRecords.Lock(tx, propertyId)
    return (tx.query([[
        SELECT `property_id`,`property_key`,`property_type`,`status`,`manager_resource`,
            `max_owners`,`max_tenants`,`metadata_version`,`revision`,`delegation_epoch`
        FROM `feather_properties`
        WHERE `property_id`=? FOR UPDATE]], propertyId) or {})[1]
end

-- Common checks on a locked row before any change to an existing property.
function PropertyRecords.CheckMutable(row, resource, expectedRevision)
    if not row then
        return Err('property_not_found', 'Property not found.')
    end
    if not Property.CanMutate(row.manager_resource, resource) then
        return Err('authorization_denied', 'Caller does not manage this property.')
    end
    if row.status == 'retired' then
        return Err('property_retired', 'Property has been retired.')
    end
    local revision = tonumber(row.revision)
    if revision ~= expectedRevision then
        return Err('revision_conflict', 'Property revision changed.', { revision = revision })
    end
    return Ok(revision)
end

-- All active interest rows of a locked property (including expired tenancies the
-- sweep has not ended yet), locked in turn.
function PropertyRecords.LockInterests(tx, propertyId)
    return tx.query([[
        SELECT `interest_id`,`holder_type`,`holder_id`,`interest_type`,`revision`,
            (`valid_until` IS NOT NULL AND `valid_until`<=CURRENT_TIMESTAMP) AS expired
        FROM `feather_property_interests`
        WHERE `property_id`=? AND `status`='active' FOR UPDATE]], propertyId) or {}
end

-- RegisterProperty -------------------------------------------------------------
-- The caller becomes the managing resource. property_key is unique, so the same
-- house can never be registered twice; replays of the same request ID return the
-- stored result. A property starts with no interests: owners and tenants are
-- granted afterwards (a house for sale has none).

local registerFields = Property.Allowed({
    'propertyKey',
    'propertyType',
    'label',
    'maxOwners',
    'maxTenants',
    'metadataVersion',
    'metadata'
})

function PropertyRecords.Register(request, resource)
    local begun = Property.Begin(request, resource, registerFields)
    if not begun.ok then
        return begun
    end
    local typeConfig = Config.PropertyTypes[request.propertyType or '']
    if not typeConfig or not Property.PropertyKey(request.propertyKey) or not Property.Label(request.label)
        or (request.maxOwners ~= nil and not Property.Integer(request.maxOwners, 0, typeConfig.maxOwners))
        or (request.maxTenants ~= nil and not Property.Integer(request.maxTenants, 0, typeConfig.maxTenants))
        or (request.metadataVersion ~= nil and not Property.Integer(request.metadataVersion, 1, 65535)) then
        return Err('invalid_input',
            'Configured property type, namespaced property key, label, optional caps within the type, and optional metadata version required.')
    end
    local maxOwners = request.maxOwners or typeConfig.maxOwners
    local maxTenants = request.maxTenants or typeConfig.maxTenants
    if maxOwners + maxTenants < 1 then
        return Err('invalid_input', 'A property must allow at least one owner or tenant.')
    end
    local encoded
    if request.metadata ~= nil then
        local metadata = Property.ValidateMetadata(request.metadata)
        if not metadata.ok then
            return metadata
        end
        encoded = metadata.value
    end
    request = Property.Copy(request)
    request.metadataCanonical = request.metadata ~= nil and Property.Canonical(request.metadata) or nil
    local actor = Property.Policy(Config.Authorization.manageAction, request, resource, {
        propertyType = request.propertyType,
        propertyKey = request.propertyKey
    })
    if not actor.ok then
        return actor
    end

    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'property.register',
        fingerprint = Property.Fingerprint('property.register', request, {
            'propertyKey',
            'propertyType',
            'label',
            'maxOwners',
            'maxTenants',
            'metadataVersion',
            'metadataCanonical',
            'reasonCode'
        }),
        body = function(tx)
            local ids, nowSeconds = Property.NewIds(tx, 2, true)
            local propertyId = ids[1]
            local metadataVersion = request.metadataVersion or 1
            -- The key's unique index decides duplicates; INSERT IGNORE avoids gap locks.
            local inserted = tx.exec([[
                INSERT IGNORE INTO `feather_properties`
                    (`property_id`,`property_key`,`property_type`,`label`,`manager_resource`,
                     `max_owners`,`max_tenants`,`metadata_version`,`metadata_json`,`created_at`,`updated_at`)
                VALUES (?,?,?,?,?,?,?,?,?,FROM_UNIXTIME(?),FROM_UNIXTIME(?))]],
                propertyId, request.propertyKey, request.propertyType, request.label, resource,
                maxOwners, maxTenants, metadataVersion, encoded, nowSeconds, nowSeconds)
            if tonumber(inserted) ~= 1 then
                local existing = (tx.query('SELECT `property_id` FROM `feather_properties` WHERE `property_key`=?',
                    request.propertyKey) or {})[1]
                return Err('property_exists', 'This property key is already registered.', {
                    propertyId = existing and existing.property_id
                })
            end
            PropertyEvents.Record(tx, 'property.registered', {
                propertyId = propertyId,
                propertyType = request.propertyType,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = 1,
                actor = actor.value,
                details = {
                    propertyKey = request.propertyKey,
                    status = 'active',
                    managerResource = resource,
                    metadataVersion = metadataVersion
                }
            }, ids[2])
            return PropertyRecords.Read(tx, propertyId)
        end
    })
end

-- ChangePropertyStatus ---------------------------------------------------------
-- active, suspended (overdue tax, seizure under review) or retired. Retiring is
-- terminal: it ends every active interest and removes every link in the same
-- commit, so the linked storage and doors are free for another property.

local statusFields = Property.Allowed({ 'propertyId', 'expectedRevision', 'status' })

function PropertyRecords.ChangeStatus(request, resource)
    local begun = Property.Begin(request, resource, statusFields)
    if not begun.ok then
        return begun
    end
    if not Property.Uuid(request.propertyId) or not Property.Integer(request.expectedRevision, 1, Property.MaxRevision)
        or not Property.Statuses[request.status or ''] then
        return Err('invalid_input', 'Property UUID, expected revision, and status (active, suspended, retired) required.')
    end
    request = Property.Copy(request)
    request.propertyId = request.propertyId:lower()
    local actor = Property.Policy(Config.Authorization.manageAction, request, resource, {
        propertyId = request.propertyId,
        status = request.status
    })
    if not actor.ok then
        return actor
    end

    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'property.status',
        fingerprint = Property.Fingerprint('property.status', request, {
            'propertyId',
            'expectedRevision',
            'status',
            'reasonCode'
        }),
        body = function(tx)
            local row = PropertyRecords.Lock(tx, request.propertyId)
            local checked = PropertyRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            if row.status == request.status then
                return Err('no_change', 'Property already has that status.')
            end
            local entries = {}
            local endedIds, removedLinkIds = {}, {}
            if request.status == 'retired' then
                for _, interest in ipairs(PropertyRecords.LockInterests(tx, request.propertyId)) do
                    endedIds[#endedIds + 1] = interest.interest_id
                    entries[#entries + 1] = {
                        eventType = 'interest.ended',
                        spec = {
                            propertyId = request.propertyId,
                            propertyType = row.property_type,
                            holderType = interest.holder_type,
                            holderId = interest.holder_id,
                            resource = resource,
                            requestId = request.requestId,
                            reasonCode = request.reasonCode,
                            referenceType = request.referenceType,
                            referenceId = request.referenceId,
                            revision = revision + 1,
                            actor = actor.value,
                            details = {
                                interestId = interest.interest_id,
                                interestType = interest.interest_type
                            }
                        }
                    }
                end
                if #endedIds > 0 then
                    tx.exec([[
                        UPDATE `feather_property_interests`
                        SET `status`='ended',`active_slot`=NULL,`ended_at`=CURRENT_TIMESTAMP,`revision`=`revision`+1
                        WHERE `property_id`=? AND `status`='active']], request.propertyId)
                end
                for _, link in ipairs(tx.query([[SELECT `link_id` FROM `feather_property_links`
                    WHERE `property_id`=? FOR UPDATE]], request.propertyId) or {}) do
                    removedLinkIds[#removedLinkIds + 1] = link.link_id
                end
                if #removedLinkIds > 0 then
                    tx.exec('DELETE FROM `feather_property_links` WHERE `property_id`=?', request.propertyId)
                end
                tx.exec([[
                    UPDATE `feather_properties`
                    SET `status`='retired',`retired_at`=CURRENT_TIMESTAMP,`revision`=`revision`+1,
                        `delegation_epoch`=`delegation_epoch`+1
                    WHERE `property_id`=? AND `revision`=?]], request.propertyId, revision)
            else
                tx.exec([[
                    UPDATE `feather_properties` SET `status`=?,`revision`=`revision`+1
                    WHERE `property_id`=? AND `revision`=?]], request.status, request.propertyId, revision)
            end
            entries[#entries + 1] = {
                eventType = 'status.changed',
                spec = {
                    propertyId = request.propertyId,
                    propertyType = row.property_type,
                    resource = resource,
                    requestId = request.requestId,
                    reasonCode = request.reasonCode,
                    referenceType = request.referenceType,
                    referenceId = request.referenceId,
                    revision = revision + 1,
                    actor = actor.value,
                    details = {
                        status = request.status,
                        previousStatus = row.status,
                        endedInterestIds = #endedIds > 0 and endedIds or nil,
                        removedLinkIds = #removedLinkIds > 0 and removedLinkIds or nil
                    }
                }
            }
            PropertyEvents.RecordMany(tx, entries)
            return PropertyRecords.Read(tx, request.propertyId)
        end
    })
end

-- UpdatePropertyMetadata -------------------------------------------------------
-- Replaces the label and/or the whole metadata document (consumer schema version
-- metadataVersion); metadata = false clears it.

local metadataFields = Property.Allowed({ 'propertyId', 'expectedRevision', 'label', 'metadataVersion', 'metadata' })

function PropertyRecords.UpdateMetadata(request, resource)
    local begun = Property.Begin(request, resource, metadataFields)
    if not begun.ok then
        return begun
    end
    if not Property.Uuid(request.propertyId) or not Property.Integer(request.expectedRevision, 1, Property.MaxRevision)
        or (request.label ~= nil and not Property.Label(request.label))
        or (request.metadata ~= nil and request.metadata ~= false and type(request.metadata) ~= 'table')
        or ((request.metadata ~= nil) ~= (request.metadataVersion ~= nil))
        or (request.metadataVersion ~= nil and not Property.Integer(request.metadataVersion, 1, 65535))
        or (request.label == nil and request.metadata == nil) then
        return Err('invalid_input',
            'Property UUID, expected revision, and a new label and/or metadata with its version (or false) required.')
    end
    local encoded
    if type(request.metadata) == 'table' then
        local metadata = Property.ValidateMetadata(request.metadata)
        if not metadata.ok then
            return metadata
        end
        encoded = metadata.value
    end
    request = Property.Copy(request)
    request.propertyId = request.propertyId:lower()
    request.metadataCanonical = request.metadata == nil and nil
        or (request.metadata == false and 'cleared' or Property.Canonical(request.metadata))
    request.metadata = nil
    local actor = Property.Policy(Config.Authorization.manageAction, request, resource, {
        propertyId = request.propertyId
    })
    if not actor.ok then
        return actor
    end

    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'property.metadata',
        fingerprint = Property.Fingerprint('property.metadata', request, {
            'propertyId',
            'expectedRevision',
            'label',
            'metadataVersion',
            'metadataCanonical',
            'reasonCode'
        }),
        body = function(tx)
            local row = PropertyRecords.Lock(tx, request.propertyId)
            local checked = PropertyRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            local sets, params = { '`revision`=`revision`+1' }, {}
            if request.label then
                sets[#sets + 1] = '`label`=?'
                params[#params + 1] = request.label
            end
            local metadataVersion = tonumber(row.metadata_version)
            if request.metadataVersion then
                sets[#sets + 1] = '`metadata_version`=?'
                params[#params + 1] = request.metadataVersion
                if encoded then
                    sets[#sets + 1] = '`metadata_json`=?'
                    params[#params + 1] = encoded
                else
                    sets[#sets + 1] = '`metadata_json`=NULL'
                end
                metadataVersion = request.metadataVersion
            end
            params[#params + 1] = request.propertyId
            params[#params + 1] = revision
            tx.exec('UPDATE `feather_properties` SET ' .. table.concat(sets, ',')
                .. ' WHERE `property_id`=? AND `revision`=?', table.unpack(params))

            PropertyEvents.Record(tx, 'metadata.revised', {
                propertyId = request.propertyId,
                propertyType = row.property_type,
                resource = resource,
                requestId = request.requestId,
                reasonCode = request.reasonCode,
                referenceType = request.referenceType,
                referenceId = request.referenceId,
                revision = revision + 1,
                actor = actor.value,
                details = {
                    metadataVersion = metadataVersion,
                    previousMetadataVersion = tonumber(row.metadata_version)
                }
            })
            return PropertyRecords.Read(tx, request.propertyId)
        end
    })
end

-- Reads ------------------------------------------------------------------------

function PropertyRecords.Get(request, resource)
    local allowed = Property.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Property.Fields(request, { propertyId = true })
    if not fields.ok then
        return fields
    end
    if not Property.Uuid(request.propertyId) then
        return Err('invalid_input', 'Property UUID required.')
    end
    return ReadBy(DB, 'property_id', request.propertyId:lower(), true)
end

function PropertyRecords.FindByKey(request, resource)
    local allowed = Property.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Property.Fields(request, { propertyKey = true })
    if not fields.ok then
        return fields
    end
    if not Property.PropertyKey(request.propertyKey) then
        return Err('invalid_input', 'Namespaced property key required.')
    end
    return ReadBy(DB, 'property_key', request.propertyKey, true)
end

-- Properties in which one holder has an effective interest, newest interest
-- first. Bounded and paged by the interest UUID.
function PropertyRecords.QueryByHolder(holderType, holderId, options)
    local sql = [[
        SELECT i.`interest_id`,i.`property_id`
        FROM `feather_property_interests` i
        JOIN `feather_properties` p ON p.`property_id`=i.`property_id`
        WHERE i.`holder_type`=? AND i.`holder_id`=? AND i.`status`='active'
            AND (i.`valid_until` IS NULL OR i.`valid_until`>CURRENT_TIMESTAMP)]]
    local params = { holderType, holderId }
    if options.interestType then
        sql = sql .. ' AND i.`interest_type`=?'
        params[#params + 1] = options.interestType
    end
    if options.propertyType then
        sql = sql .. ' AND p.`property_type`=?'
        params[#params + 1] = options.propertyType
    end
    if options.cursor then
        local cursor = DB.one([[
            SELECT DATE_FORMAT(`valid_from`,'%Y-%m-%d %H:%i:%s') AS cursor_time
            FROM `feather_property_interests` WHERE `interest_id`=?]], options.cursor)
        if not cursor then
            return Err('invalid_cursor', 'Interest cursor was not found.')
        end
        sql = sql .. ' AND (i.`valid_from`<? OR (i.`valid_from`=? AND i.`interest_id`<?))'
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = cursor.cursor_time
        params[#params + 1] = options.cursor
    end
    sql = sql .. ' ORDER BY i.`valid_from` DESC,i.`interest_id` DESC LIMIT ?'
    params[#params + 1] = options.limit + 1

    local rows = DB.query(sql, table.unpack(params)) or {}
    local items, seen = {}, {}
    for index = 1, math.min(#rows, options.limit) do
        local propertyId = rows[index].property_id
        if not seen[propertyId] then
            seen[propertyId] = true
            local snapshot = ReadBy(DB, 'property_id', propertyId, options.includeMetadata)
            if not snapshot.ok then
                return snapshot
            end
            items[#items + 1] = snapshot.value
        end
    end
    return Ok({
        items = items,
        nextCursor = #rows > options.limit and rows[options.limit].interest_id or nil
    })
end

local listFields = {
    holderType = true,
    holderId = true,
    interestType = true,
    propertyType = true,
    includeMetadata = true,
    limit = true,
    cursor = true
}

function PropertyRecords.ListByHolder(request, resource)
    local allowed = Property.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Property.Fields(request, listFields)
    if not fields.ok then
        return fields
    end
    local limit = request.limit == nil and 20 or request.limit
    if not Config.HolderTypes[request.holderType or ''] or not Property.Uuid(request.holderId)
        or (request.interestType ~= nil and not Property.InterestTypes[request.interestType])
        or (request.propertyType ~= nil and not Config.PropertyTypes[request.propertyType])
        or (request.includeMetadata ~= nil and type(request.includeMetadata) ~= 'boolean')
        or not Property.Integer(limit, 1, Config.Limits.maxListLimit)
        or (request.cursor ~= nil and not Property.Uuid(request.cursor)) then
        return Err('invalid_input',
            'Holder type and UUID, optional interest and property type, bounded limit, and interest UUID cursor required.')
    end
    return PropertyRecords.QueryByHolder(request.holderType, request.holderId:lower(), {
        interestType = request.interestType,
        propertyType = request.propertyType,
        includeMetadata = request.includeMetadata == true,
        limit = limit,
        cursor = request.cursor and request.cursor:lower() or nil
    })
end

Property.Export('RegisterProperty', PropertyRecords.Register)
Property.Export('ChangePropertyStatus', PropertyRecords.ChangeStatus)
Property.Export('UpdatePropertyMetadata', PropertyRecords.UpdateMetadata)
Property.Export('GetProperty', PropertyRecords.Get)
Property.Export('FindPropertyByKey', PropertyRecords.FindByKey)
Property.Export('ListPropertiesByHolder', PropertyRecords.ListByHolder)
