PropertyLinks = {}
local Ok, Err = Property.Ok, Property.Err

-- Property links attach an external thing (a storage container, a door, ...) to
-- a property. The owning resource chooses the external ID; Property only records
-- which property it belongs to. One external thing belongs to at most one
-- property, so a door or storage resource can ask whose it is. Adding or removing
-- a link changes the property revision like any other mutation.

local function ValidLink(linkType, externalId)
    return type(linkType) == 'string' and Config.LinkTypes[linkType] ~= nil and Property.Token(externalId, 128)
end

local function BumpRevision(tx, propertyId, revision)
    tx.exec([[UPDATE `feather_properties` SET `revision`=`revision`+1
        WHERE `property_id`=? AND `revision`=?]], propertyId, revision)
end

-- AddPropertyLink ---------------------------------------------------------------

local addFields = Property.Allowed({ 'propertyId', 'expectedRevision', 'linkType', 'externalId' })

function PropertyLinks.Add(request, resource)
    local begun = Property.Begin(request, resource, addFields)
    if not begun.ok then
        return begun
    end
    if not Property.Uuid(request.propertyId) or not Property.Integer(request.expectedRevision, 1, Property.MaxRevision)
        or not ValidLink(request.linkType, request.externalId) then
        return Err('invalid_input', 'Property UUID, expected revision, a configured link type and an external ID required.')
    end
    request = Property.Copy(request)
    request.propertyId = request.propertyId:lower()
    local actor = Property.Policy(Config.Authorization.manageAction, request, resource, {
        propertyId = request.propertyId,
        linkType = request.linkType
    })
    if not actor.ok then
        return actor
    end

    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'property.link.add',
        fingerprint = Property.Fingerprint('property.link.add', request, {
            'propertyId',
            'expectedRevision',
            'linkType',
            'externalId',
            'reasonCode'
        }),
        body = function(tx)
            local row = PropertyRecords.Lock(tx, request.propertyId)
            local checked = PropertyRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            local count = tonumber((tx.query('SELECT COUNT(*) AS n FROM `feather_property_links` WHERE `property_id`=?',
                request.propertyId) or {})[1].n) or 0
            if count >= Config.Limits.maxLinksPerProperty then
                return Err('link_limit', 'The property has reached its link limit.',
                    { maxLinks = Config.Limits.maxLinksPerProperty })
            end
            local ids = Property.NewIds(tx, 2)
            -- The (link_type, external_id) unique index decides who holds the thing.
            local inserted = tx.exec([[
                INSERT IGNORE INTO `feather_property_links` (`link_id`,`property_id`,`link_type`,`external_id`)
                VALUES (?,?,?,?)]], ids[1], request.propertyId, request.linkType, request.externalId)
            if tonumber(inserted) ~= 1 then
                local existing = (tx.query([[SELECT `link_id`,`property_id` FROM `feather_property_links`
                    WHERE `link_type`=? AND `external_id`=?]], request.linkType, request.externalId) or {})[1]
                if existing and existing.property_id == request.propertyId then
                    return Err('link_exists', 'The property already has this link.', { linkId = existing.link_id })
                end
                return Err('link_in_use', 'This external thing is linked to another property.', {
                    propertyId = existing and existing.property_id
                })
            end
            BumpRevision(tx, request.propertyId, revision)
            PropertyEvents.Record(tx, 'link.added', {
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
                    linkId = ids[1],
                    linkType = request.linkType,
                    externalId = request.externalId
                }
            }, ids[2])
            return PropertyRecords.Read(tx, request.propertyId)
        end
    })
end

-- RemovePropertyLink ------------------------------------------------------------

local removeFields = Property.Allowed({ 'propertyId', 'expectedRevision', 'linkId' })

function PropertyLinks.Remove(request, resource)
    local begun = Property.Begin(request, resource, removeFields)
    if not begun.ok then
        return begun
    end
    if not Property.Uuid(request.propertyId) or not Property.Integer(request.expectedRevision, 1, Property.MaxRevision)
        or not Property.Uuid(request.linkId) then
        return Err('invalid_input', 'Property UUID, expected revision and link UUID required.')
    end
    request = Property.Copy(request)
    request.propertyId = request.propertyId:lower()
    request.linkId = request.linkId:lower()
    local actor = Property.Policy(Config.Authorization.manageAction, request, resource, {
        propertyId = request.propertyId
    })
    if not actor.ok then
        return actor
    end

    return Property.Mutate({
        resource = resource,
        requestId = request.requestId,
        operation = 'property.link.remove',
        fingerprint = Property.Fingerprint('property.link.remove', request, {
            'propertyId',
            'expectedRevision',
            'linkId',
            'reasonCode'
        }),
        body = function(tx)
            local row = PropertyRecords.Lock(tx, request.propertyId)
            local checked = PropertyRecords.CheckMutable(row, resource, request.expectedRevision)
            if not checked.ok then
                return checked
            end
            local revision = checked.value
            local link = (tx.query([[SELECT `link_type`,`external_id` FROM `feather_property_links`
                WHERE `link_id`=? AND `property_id`=? FOR UPDATE]], request.linkId, request.propertyId) or {})[1]
            if not link then
                return Err('link_not_found', 'The property has no such link.')
            end
            tx.exec('DELETE FROM `feather_property_links` WHERE `link_id`=?', request.linkId)
            BumpRevision(tx, request.propertyId, revision)
            PropertyEvents.Record(tx, 'link.removed', {
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
                    linkId = request.linkId,
                    linkType = link.link_type,
                    externalId = link.external_id
                }
            })
            return PropertyRecords.Read(tx, request.propertyId)
        end
    })
end

-- FindPropertyByLink ------------------------------------------------------------
-- The property an external thing belongs to, for example before a door or a
-- storage container is opened.

function PropertyLinks.FindByLink(request, resource)
    local allowed = Property.CheckRead(resource)
    if not allowed.ok then
        return allowed
    end
    local fields = Property.Fields(request, { linkType = true, externalId = true })
    if not fields.ok then
        return fields
    end
    if not ValidLink(request.linkType, request.externalId) then
        return Err('invalid_input', 'A configured link type and an external ID required.')
    end
    local link = DB.one([[SELECT `property_id` FROM `feather_property_links`
        WHERE `link_type`=? AND `external_id`=?]], request.linkType, request.externalId)
    if not link then
        return Err('link_not_found', 'No property has this link.')
    end
    return PropertyRecords.Get({ propertyId = link.property_id }, resource)
end

Property.Export('AddPropertyLink', PropertyLinks.Add)
Property.Export('RemovePropertyLink', PropertyLinks.Remove)
Property.Export('FindPropertyByLink', PropertyLinks.FindByLink)

-- One read snapshot for external authority consumers. A link UUID distinguishes
-- unlink/relink ABA even when the same property owns the external thing again.
function PropertyLinks.Context(request,resource)
    local allowed=Property.CheckRead(resource)
    if not allowed.ok then return allowed end
    if not Property.Fields(request,{linkType=true,externalId=true}).ok
        or not ValidLink(request.linkType,request.externalId) then return Err('invalid_input','Exact link type/external ID required.') end
    local row=DB.one([[SELECT l.`link_id`,l.`property_id`,p.`status`,p.`delegation_epoch`,
        EXISTS(SELECT 1 FROM `feather_property_interests` i WHERE i.`property_id`=p.`property_id`
            AND i.`interest_type`='owner' AND i.`status`='active' AND i.`valid_until`<=CURRENT_TIMESTAMP) AS expired_owner
        FROM `feather_property_links` l JOIN `feather_properties` p ON p.`property_id`=l.`property_id`
        WHERE l.`link_type`=? AND l.`external_id`=?]],request.linkType,request.externalId)
    if not row then return Err('link_not_found','No canonical link exists.') end
    local epoch=tonumber(row.delegation_epoch)
    if not Property.Uuid(row.link_id) or not Property.Uuid(row.property_id)
        or not Property.Integer(epoch,1,Property.MaxRevision+1)
        or (row.status~='active' and row.status~='suspended' and row.status~='retired')
        or (tonumber(row.expired_owner)~=0 and tonumber(row.expired_owner)~=1) then
        return Err('invalid_persistence','Invalid property link context.')
    end
    return Ok({linkId=row.link_id,propertyId=row.property_id,epoch=epoch,
        status=tonumber(row.expired_owner)==1 and 'unavailable' or row.status})
end
Property.Export('GetPropertyLinkContext',PropertyLinks.Context)
