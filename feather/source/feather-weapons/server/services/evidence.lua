WeaponEvidenceService = {}

local function Trusted(resource)
    return type(resource) == 'string'
        and ((Config.Ownership or {}).trustedResources or {})[resource] == true
end

function WeaponEvidenceService.SetHold(context, request, invokingResource, held)
    context = type(context) == 'table' and context or {}
    request = type(request) == 'table' and request or {}
    if not Trusted(invokingResource) then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            'Calling resource is not trusted for evidence operations', nil, context.correlationId)
    end
    local characterId = CoreAdapter.NormalizeCharacterId(request.characterId or context.characterId)
    local itemId, serial = tonumber(request.itemInstanceId), tostring(request.serialNumber or '')
    if not characterId or not itemId or itemId<1 or itemId%1~=0 or itemId==math.huge or serial == '' then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            'Character, item instance, and expected serial are required', nil, context.correlationId)
    end
    if WeaponEvidenceService.NativeChange then
        local result=WeaponEvidenceService.NativeChange(context,request,invokingResource,held)
        result.correlationId=context.correlationId
        return result
    end
    return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        'Evidence mutation is not available on the native host; no change was requested',
        {reason='native_evidence_not_implemented',operation=held and 'hold' or 'release'},context.correlationId)
end

-- Native path has its own reservations, never the legacy mutation provider.
local nativeReservations={}
local nativeSequence=0
local function Clone(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=Clone(x) end; return out
end
local function Same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not Same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function NativeEnabled()
    return Config.DevMode==true and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
        and type(GetConvarInt)=='function' and GetConvarInt('feather_native_evidence_transactions',0)==1
end
function WeaponEvidenceService.NativeAvailable() return NativeEnabled() end
local function NativeDenied(reason)
    return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,'Native evidence change refused; inspect before retry.',{reason=reason})
end
local function NativeCurrent(reservation)
    local context=reservation.context
    return NativeEnabled() and nativeReservations[reservation.spec.itemId]==reservation
        and CoreAdapter.IsSessionCurrent(context.actorSource,context.sessionId,context.characterId)==true
        and not WeaponCharacterAmmoService.IsNativeItemBound(reservation.spec.itemId)
end
local function NativePermission(context,spec)
    local settings=(Config.Ownership or {}).authorization or {}
    local action=spec.held and settings.holdAction or settings.releaseAction
    -- Native administrative changes always require affirmative Core permission,
    -- even when legacy optional authorization is disabled in server config.
    if type(action)~='string' or action=='' then return false,{code='action_not_configured'} end
    local ok,result=pcall(function() return exports['feather-core']:Authorize(action,{
        source=context.actorSource,correlationId=context.correlationId,
        subject={operation=spec.held and 'hold' or 'release',itemInstanceId=spec.itemId,
            serialNumber=spec.serialNumber,characterId=spec.characterId}}) end)
    local value=ok and type(result)=='table' and type(result.value)=='table' and result.value or {}
    local allowed=ok and type(result)=='table' and result.ok==true and value.allowed==true or false
    local function text(v) return type(v)=='string' and v:sub(1,160) or nil end
    return allowed,{action=action,code=not ok and 'policy_call_failed' or text(value.code)
        or text(type(result)=='table' and result.code) or (allowed and 'allowed' or 'policy_denied'),
        provider=text(value.provider),reason=text(value.reason)}
end
local function NativeAuthorize(reservation)
    return NativeCurrent(reservation) and NativePermission(reservation.context,reservation.spec)
        and NativeCurrent(reservation)
end
function WeaponEvidenceService.ValidateNativeCommit(context,spec)
    if GetInvokingResource()~='feather-inventory' or type(context)~='table' or type(spec)~='table' then return false end
    local reservation=nativeReservations[spec.itemId]
    return reservation~=nil and reservation.phase=='committing'
        and Same(context,reservation.context) and Same(spec,reservation.spec) and NativeAuthorize(reservation)
end
if type(GetInvokingResource)=='function' then
    exports('ValidateNativeEvidenceCommit',WeaponEvidenceService.ValidateNativeCommit)
end
function WeaponEvidenceService.NativeChange(context,request,resource,held)
    if not NativeEnabled() then return NativeDenied('native_evidence_not_implemented') end
    local itemId=tonumber(request.itemInstanceId)
    local characterId=CoreAdapter.NormalizeCharacterId(request.characterId or context.characterId)
    if not Trusted(resource) or not itemId or itemId<1 or itemId%1~=0 or itemId==math.huge
        or not WeaponNativeEnrollment.Allows(Config,characterId) or type(held)~='boolean'
        or nativeReservations[itemId] then return NativeDenied('native_evidence_scope_or_overlap') end
    local session=CoreAdapter.ResolveSession(context.actorSource)
    if not session or not session.ok or session.value.characterId~=characterId
        or context.sessionId~=session.value.sessionId then return NativeDenied('native_evidence_current_actor_required') end
    nativeSequence=nativeSequence+1
    local reservation={phase='preparing',context={actorSource=context.actorSource,characterId=characterId,
        sessionId=session.value.sessionId,resource=resource,correlationId=context.correlationId,
        ticket='native-evidence:'..nativeSequence},spec={itemId=itemId}}
    nativeReservations[itemId]=reservation
    local function refuse(reason) if nativeReservations[itemId]==reservation then nativeReservations[itemId]=nil end; return NativeDenied(reason) end
    local ok,result=pcall(function()
        local itemResult=WeaponNativeOwnershipReader.GetInstance({},itemId)
        local inventory=WeaponNativeOwnershipReader.GetCharacterInventory({},characterId)
        local item=itemResult and itemResult.ok and itemResult.value
        if not item or not inventory or not inventory.ok or tonumber(item.inventoryId)~=tonumber(inventory.value.id)
            or item.metadata.serialNumber~=request.serialNumber then return refuse('native_evidence_owned_serial_required') end
        if request.expectedRevision~=nil and (type(request.expectedRevision)~='number'
            or request.expectedRevision%1~=0 or request.expectedRevision<0
            or request.expectedRevision~=item.metadataRevision) then return refuse('native_evidence_stale_preview') end
        local definition=WeaponDefinitionCatalog.weapons[item.metadata.weaponDefinitionId]
        local metadata=definition and WeaponCharacterAmmoItem.Validate(item.metadata,definition)
        if not metadata or metadata.flags.evidence==held then return refuse('native_evidence_invalid_or_duplicate_state') end
        reservation.spec={characterId=characterId,itemId=itemId,itemRevision=item.metadataRevision,
            itemName=definition.itemName,weaponDefinitionId=definition.id,serialNumber=metadata.serialNumber,
            held=held,before=Clone(metadata)}
        if not NativeAuthorize(reservation) then return refuse('native_evidence_authorization_denied') end
        reservation.phase='committing'
        local committed=exports['feather-inventory']:CommitNativeEvidenceTransition(Clone(reservation.context),Clone(reservation.spec))
        -- After dispatch, unknown/error acknowledgements remain blocked. Never
        -- turn a potentially committed mutation into an automatically retryable one.
        if not committed or committed.ok~=true then reservation.phase='unresolved'; return NativeDenied('native_evidence_commit_unresolved_no_retry') end
        reservation.phase='confirmed'; nativeReservations[itemId]=nil
        local value=committed.value
        local fact={operation=held and 'evidence_hold' or 'evidence_release',transitionType=held and 'evidence_hold' or 'evidence_release',
            reason=held and 'evidence_hold' or 'evidence_release',
            outcome='committed',itemInstanceId=itemId,definitionId=definition.id,serialNumber=metadata.serialNumber,
            revision=value.revision,fromInventoryId=value.inventoryId,toInventoryId=value.inventoryId,
            fromCharacterId=characterId,toCharacterId=characterId,actorSource=context.actorSource,
            actorCharacterId=characterId,resource=resource,correlationId=context.correlationId,occurredAt=os.time()}
        local recordedOk,recorded=pcall(WeaponProvenanceService.Record,fact)
        fact.provenancePersisted=recordedOk and recorded and recorded.ok==true or false
        fact.eventId=fact.provenancePersisted and recorded.value.eventId or nil
        pcall(TriggerEvent,'Feather:Weapons:EvidenceStateCommitted',fact)
        return WeaponResult.Ok(fact)
    end)
    if ok then return result end
    if reservation.phase=='preparing' then return refuse('native_evidence_preflight_unavailable') end
    reservation.phase='unresolved'
    return NativeDenied('native_evidence_commit_unresolved_no_retry')
end
if type(GetInvokingResource)=='function' then
    exports('ReadNativeEvidenceStatus',function(target,itemId)
        if GetInvokingResource()~='feather-admin' or not Trusted('feather-admin') then return NativeDenied('native_evidence_reader_caller') end
        return WeaponEvidenceService.NativeStatus(target,itemId)
    end)
end

function WeaponEvidenceService.NativeStatus(target,itemId)
    if Config.DevMode~=true or Config.NativeAlphaRuntime~=true or Config.CharacterAmmunitionEnabled~=true
        or Config.CharacterAmmoTransportEnabled~=true or type(target)~='number' or target<1 or target%1~=0 or target==math.huge
        or type(itemId)~='number' or itemId<1 or itemId%1~=0 or itemId==math.huge then return NativeDenied('native_evidence_status_scope') end
    local session=CoreAdapter.ResolveSession(target)
    if not session or not session.ok or not WeaponNativeEnrollment.Allows(Config,session.value.characterId) then
        return NativeDenied('native_evidence_status_current_actor_required')
    end
    local context={actorSource=target,characterId=session.value.characterId,sessionId=session.value.sessionId}
    local function current()
        return Config.DevMode==true and Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
            and Config.CharacterAmmoTransportEnabled==true and WeaponNativeEnrollment.Allows(Config,context.characterId)
            and CoreAdapter.IsSessionCurrent(target,context.sessionId,context.characterId)==true
    end
    if not current() then return NativeDenied('native_evidence_status_session_changed') end
    local snapshot=exports['feather-inventory']:ReadNativeEquipmentTransition(context,itemId)
    local item=snapshot and snapshot.ok and snapshot.value.candidate
    local definition=item and item.metadata and WeaponDefinitionCatalog.weapons[item.metadata.weaponDefinitionId]
    if not definition or item.id~=itemId or item.itemName~=definition.itemName then return NativeDenied('native_evidence_status_owned_item_required') end
    local metadata=WeaponCharacterAmmoItem.Validate(item.metadata,definition)
    if not metadata or not current() then return NativeDenied('native_evidence_status_invalid_metadata') end
    local spec={itemId=itemId,serialNumber=metadata.serialNumber,characterId=context.characterId,held=true}
    local canHold,holdDecision=NativePermission(context,spec)
    spec.held=false
    local canRelease,releaseDecision=NativePermission(context,spec)
    if not current() then return NativeDenied('native_evidence_status_session_changed') end
    local equipped=false
    for _,entry in pairs(snapshot.value.expected or {}) do if entry.itemId==itemId then equipped=true end end
    local reservation=nativeReservations[itemId]
    return WeaponResult.Ok({identity=context,itemId=itemId,itemRevision=item.revision,serialNumber=metadata.serialNumber,
        evidence=metadata.flags.evidence,disabled=metadata.flags.disabled,maintenance=Clone(metadata.maintenance),
        enabled=NativeEnabled(),equipped=equipped,nativeBound=WeaponCharacterAmmoService.IsNativeItemBound(itemId)==true,
        permissions={hold=canHold,release=canRelease},permissionDetails={hold=holdDecision,release=releaseDecision},
        reservation=reservation and reservation.phase or 'none',
        noItemWrites=true,noAmmoOrMaterialWrites=true})
end
if type(RegisterCommand)=='function' then
    RegisterCommand('WeaponNativeEvidenceStatus',function(source,args)
        if source~=0 then return end
        if not args or #args~=2 then return print('[WeaponNativeEvidenceStatus] REFUSED usage: current-server-id owned-item-id') end
        local ok,result=pcall(WeaponEvidenceService.NativeStatus,tonumber(args[1]),tonumber(args[2]))
        print('[WeaponNativeEvidenceStatus] '..(ok and result and result.ok and json.encode(result.value)
            or ('REFUSED '..tostring(ok and result and result.error and result.error.details and result.error.details.reason or 'status_unavailable'))))
    end,true)
    RegisterCommand('WeaponNativeEvidenceChange',function(source,args)
        if source~=0 or not NativeEnabled() then return end
        local target,itemId=tonumber(args and args[1]),tonumber(args and args[3])
        local operation=args and args[2]
        if not args or #args~=4 or not target or target<1 or target%1~=0 or target==math.huge
            or (operation~='hold' and operation~='release') or type(args[4])~='string' or #args[4]<1 or #args[4]>128 then
            return print('[WeaponNativeEvidenceChange] REFUSED usage: current-server-id hold|release owned-item-id expected-serial')
        end
        local session=CoreAdapter.ResolveSession(target)
        if not session or not session.ok then return print('[WeaponNativeEvidenceChange] REFUSED current actor required') end
        local result=WeaponEvidenceService.SetHold({actorSource=target,sessionId=session.value.sessionId,
            correlationId='native-evidence-console:'..tostring(os.time())},
            {characterId=session.value.characterId,itemInstanceId=itemId,serialNumber=args[4]},'feather-weapons',operation=='hold')
        print('[WeaponNativeEvidenceChange] '..(result.ok and ('COMMITTED '..json.encode(result.value))
            or ('REFUSED '..tostring(result.error and result.error.details and result.error.details.reason or result.error and result.error.code))))
    end,true)
end

function WeaponEvidenceService.Hold(context, request, resource)
    return WeaponEvidenceService.SetHold(context, request, resource, true)
end

function WeaponEvidenceService.Release(context, request, resource)
    return WeaponEvidenceService.SetHold(context, request, resource, false)
end

function WeaponEvidenceService.CheckContract()
    local untrusted = WeaponEvidenceService.Hold({}, {}, 'untrusted-smoke-resource')
    local incomplete = WeaponEvidenceService.Hold({}, {}, 'feather-weapons')
    local authorization = (Config.Ownership or {}).authorization or {}
    return {
        serviceAvailable = type(WeaponEvidenceService.Hold) == 'function'
            and type(WeaponEvidenceService.Release) == 'function',
        trustedCallerConfigured = ((Config.Ownership or {}).trustedResources or {})['feather-weapons'] == true,
        authorizationConfigured = authorization.enabled ~= true
            or (type(authorization.holdAction) == 'string' and authorization.holdAction ~= ''
                and type(authorization.releaseAction) == 'string' and authorization.releaseAction ~= ''),
        untrustedRejected = not untrusted.ok and untrusted.error
            and untrusted.error.code == WeaponErrors.AUTHORIZATION_INVALID,
        incompleteRejected = not incomplete.ok and incomplete.error
            and incomplete.error.code == WeaponErrors.ITEM_INVALID
    }
end
