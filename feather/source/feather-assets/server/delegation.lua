-- Assets owns target facts. Access owns grants; gameplay owns actual retrieval.
AssetDelegation = {registered = false}
local D = AssetDelegation
local function Call(operation, request)
    if not Config.Delegation.enabled or not Assets.IsReady() or GetResourceState('feather-access') ~= 'started' then
        return Assets.Err('provider_unavailable', 'Asset delegation is unavailable.')
    end
    local ok, result = pcall(function() return exports['feather-access'][operation](nil, request) end)
    return ok and type(result) == 'table' and result or Assets.Err('provider_unavailable', 'Access call failed.')
end
local function Read(id)
    if not Assets.IsReady() then return Assets.Err('not_ready', 'Assets is not ready.') end
    return AssetRecords.Get({assetId = id}, GetCurrentResourceName())
end
function D.Resolve(request)
    local result = Read(request.targetId)
    if not result.ok then return result end
    local value = result.value
    return Assets.Ok({targetType = 'assets.asset', targetId = value.assetId,
        epoch = value.delegationEpoch, status = value.status == 'active' and 'active'
            or value.status == 'retired' and 'retired' or 'unavailable', capabilities = {'asset.retrieve'}})
end
function D.Authorize(request)
    local result = Read(request.target.targetId)
    local actor = request.actor
    local owner = result.ok and result.value.owner
    -- Organization ownership needs a separately authenticated controlling actor;
    -- organization membership alone does not confer delegation authority.
    local permitted = (request.action == 'grant' or request.action == 'preserve.prepare') and result.ok and result.value.status == 'active'
        or (request.action == 'revoke' or request.action == 'list') and result.ok and result.value.status ~= 'retired'
    return Assets.Ok({allowed = permitted == true
        and actor.resource == 'feather-assets' and owner ~= nil and owner.holderType == 'character'
        and actor.characterId == owner.holderId and result.value.delegationEpoch == request.target.epoch})
end
function D.Register()
    D.registered = false
    if not Config.Delegation.enabled or not Assets.IsReady() or GetResourceState('feather-access') ~= 'started' then return end
    local ready = exports['feather-access']:AwaitReady(Config.ReadinessTimeoutMs)
    if not ready.ok then return end
    Call('UnregisterTargetProvider', {targetType = 'assets.asset'})
    local result = Call('RegisterTargetProvider', {targetType = 'assets.asset', contract = 1,
        resolve = D.Resolve, authorize = D.Authorize, transfer = D.Transfer})
    D.registered = result.ok == true
    print('[AssetDelegation] provider=' .. (result.ok and 'ready' or tostring(result.code)))
end
local function Actor(request, resource, group)
    local trust = Assets.CheckAccess(group, resource)
    if not trust.ok then return trust end
    if type(request) ~= 'table' or not Assets.Integer(request.actorSource, 1, 65535) then
        return Assets.Err('invalid_input', 'Current actor source required.')
    end
    return Assets.Actor(request)
end
function D.Grant(request, resource)
    local actor = Actor(request, resource, 'trustedManagers')
    if not actor.ok then return actor end
    local fields = Assets.Fields(request, {assetId=true, actorSource=true, requestId=true, reasonCode=true,
        granteeType=true, granteeId=true, roleIds=true, validFrom=true, validUntil=true})
    if not fields.ok then return fields end
    local target = Read(request.assetId)
    if not target.ok then return target end
    local payload = Assets.Copy(request); payload.assetId = nil
    payload.targetType, payload.targetId, payload.expectedEpoch = 'assets.asset', target.value.assetId, target.value.delegationEpoch
    payload.capability = 'asset.retrieve'
    payload.provenanceType, payload.provenanceId = 'asset.delegation', target.value.assetId
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
    local fields = Assets.Fields(request, {assetId=true, actorSource=true})
    if not fields.ok then return fields end
    local target = Read(request.assetId)
    if not target.ok then return target end
    return Call('CheckCapability', {targetType='assets.asset', targetId=target.value.assetId,
        capability='asset.retrieve', actorSource=request.actorSource})
end
function D.ResolveManifest(manifestId,targetId)
    return Call('ResolvePreservationManifest',{manifestId=manifestId,targetType='assets.asset',targetId=targetId})
end
function D.Prepare(request,resource)
    local actor=Actor(request,resource,'trustedManagers');if not actor.ok then return actor end
    local fields=Assets.Fields(request,{assetId=true,actorSource=true,requestId=true,reasonCode=true,grants=true})
    if not fields.ok then return fields end
    local target=Read(request.assetId);if not target.ok then return target end
    local payload=Assets.Copy(request);payload.assetId=nil
    payload.targetType,payload.targetId,payload.expectedEpoch='assets.asset',target.value.assetId,target.value.delegationEpoch
    return Call('PreparePreservation',payload)
end
function D.Adopt(request,resource)
    local actor=Actor(request,resource,'trustedManagers');if not actor.ok then return actor end
    return Call('AdoptPreservation',request)
end
function D.Transfer(request)
    local current=Read(request.target.targetId)
    if not current.ok or request.actor.resource~='feather-assets' then return Assets.Ok({allowed=false})end
    local receipt=DB.one('SELECT `operation`,`result_json` FROM `feather_asset_receipts` WHERE `source_resource`=? AND `request_id`=?',
        request.transferResource,request.transferRequestId)
    local decoded,result=pcall(json.decode,receipt and receipt.result_json or '')
    local proof=decoded and type(result)=='table' and result.delegationHandoff
    local owns=false
    owns=current.value.owner~=nil and current.value.owner.holderType=='character' and current.value.owner.holderId==request.actor.characterId
    return Assets.Ok({allowed=owns and receipt~=nil and receipt.operation=='ownership.transfer'
        and type(proof)=='table' and proof.manifestId==request.manifestId and proof.targetId==request.target.targetId
        and proof.sourceEpoch==request.sourceEpoch and proof.targetEpoch==request.target.epoch
        and proof.targetEpoch==current.value.delegationEpoch and proof.targetEpoch==proof.sourceEpoch+1
        and proof.newOwnerType=='character' and proof.newOwnerId==request.actor.characterId})
end
function D.FindDelegationOperation(request,resource)
    local trust=Assets.CheckRead(resource);if not trust.ok then return trust end
    return Call('FindOperation',request)
end
Assets.Export('FindDelegationOperation',D.FindDelegationOperation)
Assets.Export('PrepareDelegationPreservation',D.Prepare)
Assets.Export('AdoptDelegationPreservation',D.Adopt)
Assets.Export('GrantRetrievalCapability', D.Grant)
Assets.Export('RevokeRetrievalGrant', D.Revoke)
Assets.Export('CheckDelegatedRetrieval', D.Check)
CreateThread(function()
    local result = Assets.AwaitReady(Config.ReadinessTimeoutMs)
    if result.ok then D.Register() end
end)
AddEventHandler('onResourceStart', function(resource)
    if resource == 'feather-access' then CreateThread(D.Register) end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == 'feather-access' then D.registered = false end
end)
RegisterCommand('AssetsAccessStatus', function(source)
    if source == 0 then print(('[AssetsAccessStatus] enabled=%s provider=%s'):format(
        tostring(Config.Delegation.enabled), tostring(D.registered))) end
end, true)
