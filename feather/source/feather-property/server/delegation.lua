-- Property owns target facts. Access owns grants; gameplay owns actual retrieval.
PropertyDelegation = {registered = false}
local D = PropertyDelegation
local function Call(operation, request)
    if not Config.Delegation.enabled or not Property.IsReady() or GetResourceState('feather-access') ~= 'started' then
        return Property.Err('provider_unavailable', 'Property delegation is unavailable.')
    end
    local ok, result = pcall(function() return exports['feather-access'][operation](nil, request) end)
    return ok and type(result) == 'table' and result or Property.Err('provider_unavailable', 'Access call failed.')
end
local function Read(id)
    if not Property.IsReady() then return Property.Err('not_ready', 'Property is not ready.') end
    return PropertyRecords.Get({propertyId = id}, GetCurrentResourceName())
end
function D.Resolve(request)
    local result = Read(request.targetId)
    if not result.ok then return result end
    local value = result.value
    -- Owner expiry must invalidate authorization before the asynchronous sweep
    -- advances the stored epoch. Deny until pending owner cleanup is committed.
    local expiredOwner = DB.one([[SELECT `interest_id` FROM `feather_property_interests`
        WHERE `property_id`=? AND `interest_type`='owner' AND `status`='active'
        AND `valid_until`<=CURRENT_TIMESTAMP LIMIT 1]], value.propertyId)
    return Property.Ok({targetType = 'property.property', targetId = value.propertyId,
        epoch = value.delegationEpoch, status = value.status == 'active' and not expiredOwner and 'active'
            or value.status == 'retired' and 'retired' or 'unavailable', capabilities = {'property.enter'}})
end
function D.Authorize(request)
    local result = Read(request.target.targetId)
    local actor = request.actor
    local owns = false
    for _, owner in ipairs(result.ok and result.value.owners or {}) do
        if owner.holderType == 'character' and owner.holderId == actor.characterId then owns = true end
    end
    -- Organization ownership needs a separately authenticated controlling actor;
    -- organization membership alone does not confer delegation authority.
    local permitted = (request.action == 'grant' or request.action == 'preserve.prepare') and result.ok and result.value.status == 'active'
        or (request.action == 'revoke' or request.action == 'list') and result.ok and result.value.status ~= 'retired'
    return Property.Ok({allowed = permitted == true
        and actor.resource == 'feather-property' and owns and result.value.delegationEpoch == request.target.epoch})
end
function D.Register()
    D.registered = false
    if not Config.Delegation.enabled or not Property.IsReady() or GetResourceState('feather-access') ~= 'started' then return end
    local ready = exports['feather-access']:AwaitReady(Config.ReadinessTimeoutMs)
    if not ready.ok then return end
    Call('UnregisterTargetProvider', {targetType = 'property.property'})
    local result = Call('RegisterTargetProvider', {targetType = 'property.property', contract = 1,
        resolve = D.Resolve, authorize = D.Authorize, transfer = D.Transfer})
    D.registered = result.ok == true
    print('[PropertyDelegation] provider=' .. (result.ok and 'ready' or tostring(result.code)))
end
local function Actor(request, resource, group)
    local trust = Property.CheckAccess(group, resource)
    if not trust.ok then return trust end
    if type(request) ~= 'table' or not Property.Integer(request.actorSource, 1, 65535) then
        return Property.Err('invalid_input', 'Current actor source required.')
    end
    return Property.Actor(request)
end
function D.Grant(request, resource)
    local actor = Actor(request, resource, 'trustedManagers')
    if not actor.ok then return actor end
    local fields = Property.Fields(request, {propertyId=true, actorSource=true, requestId=true, reasonCode=true,
        granteeType=true, granteeId=true, roleIds=true, validFrom=true, validUntil=true})
    if not fields.ok then return fields end
    local target = Read(request.propertyId)
    if not target.ok then return target end
    local payload = Property.Copy(request); payload.propertyId = nil
    payload.targetType, payload.targetId, payload.expectedEpoch = 'property.property', target.value.propertyId, target.value.delegationEpoch
    payload.capability = 'property.enter'
    payload.provenanceType, payload.provenanceId = 'property.delegation', target.value.propertyId
    return Call('GrantCapability', payload)
end
function D.Revoke(request, resource)
    local actor = Actor(request, resource, 'trustedManagers')
    if not actor.ok then return actor end
    -- Access resolves the actual grant target and revalidates current ownership.
    return Call('RevokeGrant', request)
end
function D.Check(request, resource)
    local actor = Actor(request, resource, 'trustedReaders')
    if not actor.ok then return actor end
    local fields = Property.Fields(request, {propertyId=true, actorSource=true})
    if not fields.ok then return fields end
    local target = Read(request.propertyId)
    if not target.ok then return target end
    return Call('CheckCapability', {targetType='property.property', targetId=target.value.propertyId,
        capability='property.enter', actorSource=request.actorSource})
end
function D.ResolveManifest(manifestId,targetId)
    return Call('ResolvePreservationManifest',{manifestId=manifestId,targetType='property.property',targetId=targetId})
end
function D.Prepare(request,resource)
    local actor=Actor(request,resource,'trustedManagers');if not actor.ok then return actor end
    local fields=Property.Fields(request,{propertyId=true,actorSource=true,requestId=true,reasonCode=true,grants=true})
    if not fields.ok then return fields end
    local target=Read(request.propertyId);if not target.ok then return target end
    local payload=Property.Copy(request);payload.propertyId=nil
    payload.targetType,payload.targetId,payload.expectedEpoch='property.property',target.value.propertyId,target.value.delegationEpoch
    return Call('PreparePreservation',payload)
end
function D.Adopt(request,resource)
    local actor=Actor(request,resource,'trustedManagers');if not actor.ok then return actor end
    return Call('AdoptPreservation',request)
end
function D.Transfer(request)
    local current=Read(request.target.targetId)
    if not current.ok or request.actor.resource~='feather-property' then return Property.Ok({allowed=false})end
    local receipt=DB.one('SELECT `operation`,`result_json` FROM `feather_property_receipts` WHERE `source_resource`=? AND `request_id`=?',
        request.transferResource,request.transferRequestId)
    local decoded,result=pcall(json.decode,receipt and receipt.result_json or '')
    local proof=decoded and type(result)=='table' and result.delegationHandoff
    local owns=false
    for _,owner in ipairs(current.value.owners or {})do if owner.holderType=='character' and owner.holderId==request.actor.characterId then owns=true end end
    return Property.Ok({allowed=owns and receipt~=nil and receipt.operation=='ownership.transfer'
        and type(proof)=='table' and proof.manifestId==request.manifestId and proof.targetId==request.target.targetId
        and proof.sourceEpoch==request.sourceEpoch and proof.targetEpoch==request.target.epoch
        and proof.targetEpoch==current.value.delegationEpoch and proof.targetEpoch==proof.sourceEpoch+1
        and proof.newOwnerType=='character' and proof.newOwnerId==request.actor.characterId})
end
function D.FindDelegationOperation(request,resource)
    local trust=Property.CheckRead(resource);if not trust.ok then return trust end
    return Call('FindOperation',request)
end
Property.Export('FindDelegationOperation',D.FindDelegationOperation)
Property.Export('PrepareDelegationPreservation',D.Prepare)
Property.Export('AdoptDelegationPreservation',D.Adopt)
Property.Export('GrantEntryCapability', D.Grant)
Property.Export('RevokeEntryGrant', D.Revoke)
Property.Export('CheckDelegatedEntry', D.Check)
CreateThread(function()
    local result = Property.AwaitReady(Config.ReadinessTimeoutMs)
    if result.ok then D.Register() end
end)
AddEventHandler('onResourceStart', function(resource)
    if resource == 'feather-access' then CreateThread(D.Register) end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-access' then D.registered = false end
end)
RegisterCommand('PropertyAccessStatus', function(source)
    if source == 0 then print(('[PropertyAccessStatus] enabled=%s provider=%s'):format(
        tostring(Config.Delegation.enabled), tostring(D.registered))) end
end, true)
