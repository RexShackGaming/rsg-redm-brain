IssuanceService = {}

local serialCounter = 0
local reservedSerials = {}
local nativeTickets={}
local nativeRequests={}
local nativeSequence=0
local function knifeAdmissionStatus()
    local loaded=type(WeaponNativeKnife)=='table' and type(WeaponNativeKnife.Enabled)=='function'
    local gates={DevMode=Config.DevMode==true,NativeAlphaRuntime=Config.NativeAlphaRuntime==true,
        CharacterAmmunitionEnabled=Config.CharacterAmmunitionEnabled==true,
        CharacterAmmoTransportEnabled=Config.CharacterAmmoTransportEnabled==true,
        NativeAlphaLifecycleWearEnabled=Config.NativeAlphaLifecycleWearEnabled==true}
    local convar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_knife',0) or 0
    local missing={}
    if not loaded then missing[#missing+1]='shared/native_knife.lua not loaded (check deployed manifest/refresh)' end
    for _,key in ipairs({'DevMode','NativeAlphaRuntime','CharacterAmmunitionEnabled','CharacterAmmoTransportEnabled','NativeAlphaLifecycleWearEnabled'}) do
        if not gates[key] then missing[#missing+1]=key..' must be true' end
    end
    if convar~=1 then missing[#missing+1]='feather_native_knife must be 1' end
    return {loaded=loaded,enabled=loaded and WeaponNativeKnife.Enabled()==true or false,
        gates=gates,convar=convar,missing=missing,noWrites=true}
end
local function clone(value)
    if type(value)~='table' then return value end
    local out={}; for k,v in pairs(value) do out[k]=clone(v) end; return out
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function IssuanceService.NativeAvailable()
    local enabled=Config.DevMode==true and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
        and type(GetConvarInt)=='function' and GetConvarInt('feather_native_issuance',0)==1
        and GetResourceState('feather-weapons-native-proof')=='stopped'
        and WeaponNativeEnrollment.Validate(Config)~=nil
        and WeaponCharacterAmmoInventoryProvider.Status()=='ready' and WeaponProvenanceService.IsReady()==true
    if not enabled then return false end
    local called,contract=pcall(function() return exports['feather-inventory']:GetNativeIssuanceContract() end)
    return called and type(contract)=='table' and contract.contractVersion==1 and contract.ready==true
end
local function nativeCurrent(context)
    if not IssuanceService.NativeAvailable() or not WeaponNativeEnrollment.Allows(Config,context.characterId)
        or not CoreAdapter.IsSessionCurrent(context.targetSource,context.sessionId,context.characterId)
        or (WeaponNativeEquipmentBindings and WeaponNativeEquipmentBindings.IsStopping(context.targetSource)) then return false end
    local state=WeaponCharacterAmmoDispatcher.Status(context.targetSource)
    return state and state.phase=='active' and not state.busy and state.identity
        and state.identity.characterId==context.characterId and state.identity.sessionId==context.sessionId
        and state.identity.epoch==context.epoch or false
end
if type(exports)=='table' or type(exports)=='function' then
    exports('ValidateNativeIssuance',function(context,spec)
        if GetInvokingResource()~='feather-inventory' or type(context)~='table' then return false end
        local ticket=nativeTickets[context.ticket]
        return ticket~=nil and equal(ticket.context,context) and equal(ticket.spec,spec) and nativeCurrent(context)==true
            and ((WeaponDefinitionCatalog.weapons[ticket.spec.definitionId] or {}).slot~='throwable'
                or (ticket.spec.definitionId=='throwable_tomahawk' and WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled()))
            and ((WeaponDefinitionCatalog.weapons[ticket.spec.definitionId] or {}).slot~='melee'
                or (ticket.spec.definitionId=='melee_knife' and WeaponNativeKnife and WeaponNativeKnife.Enabled())
                or (WeaponNativeMeleeCatalog and WeaponNativeMeleeCatalog.Enabled()
                    and WeaponNativeMeleeCatalog.Resolve(WeaponDefinitionCatalog.weapons[ticket.spec.definitionId])~=nil))
            and ((WeaponDefinitionCatalog.weapons[ticket.spec.definitionId] or {}).slot~='utility'
                or (WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Enabled()
                    and WeaponNativeUtilityCatalog.Resolve(WeaponDefinitionCatalog.weapons[ticket.spec.definitionId])~=nil))
    end)
end

local function CleanText(value, maximum)
    if value == nil then return nil end
    value = tostring(value)
    if value == "" then return nil end
    return value:sub(1, maximum)
end

local function ValidateRequestId(value)
    if type(value) ~= "string" or #value < 1 or #value > 128 then return nil end
    if not value:match("^[A-Za-z0-9][A-Za-z0-9._:%-]*$") then return nil end
    return value
end

local function NextSerial(definition)
    local family = tostring(definition.family or "weapon"):upper():gsub("[^A-Z0-9]", ""):sub(1, 4)
    if family == "" then family = "WPN" end
    for _ = 1, 16 do
        serialCounter = (serialCounter + 1) % 0x10000
        local serial = ("FW-%s-%08X-%06X-%04X"):format(
            family, os.time(), math.random(0, 0xFFFFFF), serialCounter)
        if not reservedSerials[serial] then
            reservedSerials[serial] = true
            return serial
        end
    end
    return nil
end

-- Normal commerce admission is independent of the developer grant switch.
-- These helpers only prepare canonical data; they never deliver or charge.
function IssuanceService.PurchaseAvailable()
    local proof=GetResourceState('feather-weapons-native-proof')
    return (proof=='stopped' or proof=='missing') and Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
        and Config.CharacterAmmoTransportEnabled==true
        and WeaponCharacterAmmoInventoryProvider.Status()=='ready'
        and WeaponProvenanceService.IsReady()==true
end
function IssuanceService.PurchaseDefinition(itemName)
    if not IssuanceService.PurchaseAvailable() or type(itemName)~='string' then return nil end
    local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
    for id,definition in pairs(WeaponDefinitionCatalog.weapons) do
        if definition.itemName==itemName and registry and registry.weapons[id]
            and (definition.slot=='sidearm' or definition.slot=='longgun') then return definition end
    end
end
function IssuanceService.PreparePurchase(context,request)
    local function refused(message)
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,message)
    end
    if type(context)~='table' or type(request)~='table'
        or type(context.targetSource)~='number' or context.targetSource<1 or context.targetSource%1~=0
        or type(context.sessionId)~='string' or context.sessionId==''
        or type(context.epoch)~='string' or context.epoch==''
        or not ValidateRequestId(request.orderId) or #request.orderId~=36
        or not request.orderId:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$')
        or type(request.currency)~='string' or #request.currency>32 or not request.currency:match('^[a-z][a-z0-9_]*$')
        or type(request.total)~='number' or request.total<1 or request.total%1~=0 or request.total>1000000000000 then
        return refused('Canonical purchase identity required.')
    end
    for key in pairs(request) do
        if key~='orderId' and key~='itemName' and key~='currency' and key~='total' then
            return refused('Purchase preparation accepts only canonical order fields.')
        end
    end
    local definition=IssuanceService.PurchaseDefinition(request.itemName)
    local character=CoreAdapter.NormalizeCharacterId(context.characterId)
    if not definition or not character or not CoreAdapter.IsSessionCurrent(context.targetSource,context.sessionId,character)
        or (WeaponNativeEquipmentBindings and WeaponNativeEquipmentBindings.IsStopping(context.targetSource)) then
        return refused('Current native buyer and admitted weapon required.')
    end
    local state=WeaponCharacterAmmoDispatcher.Status(context.targetSource)
    if not state or state.phase~='active' or state.busy or not state.identity
        or state.identity.characterId~=character or state.identity.sessionId~=context.sessionId
        or state.identity.epoch~=context.epoch then return refused('Current native buyer epoch required.') end
    local serial=NextSerial(definition)
    if not serial then return refused('Weapon serial allocation failed.') end
    local built=WeaponMetadata.Build(definition,{serialNumber=serial,condition=100,quality=100,
        provenance={type='purchase',reference=request.orderId,resource='feather-shops',
            issuedToCharacterId=character,createdAt=os.time()}})
    if not built.ok then return built end
    local checked=WeaponMetadata.Validate(built.value,definition)
    if not checked.ok then return checked end
    return WeaponResult.Ok({resource='feather-shops',requestId=request.orderId,
        definitionId=definition.id,itemName=definition.itemName,metadata=checked.value,
        fingerprint=table.concat({'native-purchase-v1',character,request.orderId,definition.id,
            request.currency,tostring(request.total)},'|')})
end

local function Authorize(context, definitionId, purpose)
    local settings = Config.Issuance or {}
    if (settings.trustedResources or {})[context.resource] ~= true then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Calling resource is not trusted for weapon issuance", nil, context.correlationId)
    end
    if (settings.allowedPurposes or {})[purpose] ~= true then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Weapon issuance purpose is not allowed", { purpose = purpose }, context.correlationId)
    end
    local authorization = settings.authorization or {}
    if authorization.enabled ~= true then return WeaponResult.Ok(true, context.correlationId) end
    if not context.actorSource or type(authorization.action) ~= "string" or authorization.action == "" then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "Weapon issuance authorization is not configured", nil, context.correlationId)
    end
    local called, decision = pcall(function()
        return exports["feather-core"]:Authorize(authorization.action, {
            source = context.actorSource, correlationId = context.correlationId,
            subject = { operation = "issue", purpose = purpose,
                definitionId = definitionId, characterId = context.characterId }
        })
    end)
    if not called or type(decision) ~= "table" or not decision.ok
        or type(decision.value) ~= "table" or decision.value.allowed ~= true then
        return WeaponResult.Error(WeaponErrors.AUTHORIZATION_INVALID,
            "This character is not authorized to issue weapons", nil, context.correlationId)
    end
    return WeaponResult.Ok(true, context.correlationId)
end

local function RecordIssuance(value, context, recovered)
    local existing = WeaponProvenanceService.FindIssuanceEvent(
        value.itemInstanceId, context.correlationId)
    if not existing.ok then return existing end -- unknown read is not evidence of no prior event
    if existing.ok and existing.value.eventId then
        value.provenanceEventId = existing.value.eventId
        return existing
    end
    local recorded = WeaponProvenanceService.Record({
        operation = 'issue', transitionType = 'issuance', outcome = 'committed',
        itemInstanceId = value.itemInstanceId, definitionId = value.definitionId,
        serialNumber = value.serialNumber, revision = value.revision,
        toInventoryId = value.inventoryId, toCharacterId = value.characterId,
        actorSource = context.actorSource, actorCharacterId = context.actorCharacterId,
        reason = context.reason, resource = context.resource,
        correlationId = context.correlationId, occurredAt = os.time(),
        metadata = value.metadata, recovered = recovered == true
    })
    value.provenanceEventId = recorded.ok and recorded.value.eventId or nil
    return recorded
end

local function IssueNative(context,request,definition,requestId)
    local function refused(message) return WeaponResult.Error(WeaponErrors.ITEM_INVALID,message,nil,context.correlationId) end
    if not requestId then return refused('Native issuance requires a stable requestId for every purpose.') end
    if not IssuanceService.NativeAvailable() then return refused('Scoped native issuance is disabled or unavailable.') end
    -- Pristine admitted weapons only, with no item-owned ammo or customization.
    if (request.condition~=nil and request.condition~=100) or (request.quality~=nil and request.quality~=100)
        or request.loadedAmmo~=nil or request.reserveAmmo~=nil or request.ammo~=nil or request.chambered~=nil
        or request.attachments~=nil or request.cosmetics~=nil then return refused('Native issuance currently requires a pristine, uncustomized weapon without ammunition.') end
    if request.provenance~=nil and type(request.provenance)~='table' then return refused('Native provenance must be a table.') end
    local supplied=request.provenance or {}
    for key in pairs(supplied) do if key~='type' and key~='reference' then return refused('Unsupported native provenance field.') end end
    local provenanceType=CleanText(supplied.type or context.reason,48)
    local provenanceReference=CleanText(supplied.reference,128)
    local registry=WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)
    local knife=definition.id=='melee_knife' and WeaponNativeKnife and WeaponNativeKnife.Enabled()
    local melee=WeaponNativeMeleeCatalog and WeaponNativeMeleeCatalog.Enabled() and WeaponNativeMeleeCatalog.Resolve(definition)~=nil
    local throwable=definition.id=='throwable_tomahawk' and WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled()
    local utility=WeaponNativeUtilityCatalog and WeaponNativeUtilityCatalog.Enabled() and WeaponNativeUtilityCatalog.Resolve(definition)~=nil
    if definition.slot=='utility' and not utility then return refused('Native utility support is disabled or unsupported.') end
    if definition.slot=='throwable' and not throwable then return refused('Native throwable support is disabled or unsupported.') end
    if definition.id=='melee_knife' and not knife and not melee then
        local status=knifeAdmissionStatus()
        return refused('Native knife admission refused: '..table.concat(status.missing,'; '))
    end
    if not knife and not melee and not utility and (not registry or not registry.weapons[definition.id]) then return refused('Weapon is not admitted by the native policy.') end
    local target,bound
    for _,raw in ipairs(GetPlayers()) do
        local source=tonumber(raw)
        local session=CoreAdapter.ResolveSession(source)
        if session and session.ok and session.value.characterId==context.characterId then
            if target then return refused('Target character session is ambiguous.') end
            target=source
            local state=WeaponCharacterAmmoDispatcher.Status(source)
            bound=state and state.identity
        end
    end
    local authority={targetSource=target,characterId=context.characterId,sessionId=bound and bound.sessionId,
        epoch=bound and bound.epoch}
    if not target or not nativeCurrent(authority) then return refused('A current active enrolled native target is required.') end
    local serial=NextSerial(definition)
    if not serial then return refused('Weapon serial allocation failed.') end
    local built=WeaponMetadata.Build(definition,{serialNumber=serial,condition=100,quality=100,
        provenance={type=provenanceType,reference=requestId,sourceReference=provenanceReference,resource=context.resource,
            issuedByCharacterId=CoreAdapter.NormalizeCharacterId(context.actorCharacterId),
            issuedToCharacterId=context.characterId,createdAt=os.time()}})
    if not built.ok then return built end
    local valid=WeaponMetadata.Validate(built.value,definition,context.correlationId)
    if not valid.ok then return valid end
    -- Canonical payload only: serial/time/session are outcomes, not replay keys.
    local fingerprint=json.encode({utility and 'native-utility-v1' or throwable and 'native-throwable-v1' or definition.id=='melee_knife' and 'native-knife-v1' or melee and 'native-melee-v1' or 'native-firearm-v1',context.characterId,definition.id,context.reason,
        CoreAdapter.NormalizeCharacterId(context.actorCharacterId) or '',100,100,provenanceType,provenanceReference or ''})
    if #fingerprint>300 then return refused('Native issuance identity exceeds receipt bounds.') end
    nativeSequence=nativeSequence+1
    authority.ticket=('native-issue:%s:%s'):format(GetGameTimer(),nativeSequence)
    local spec={resource=context.resource,requestId=requestId,fingerprint=fingerprint,definitionId=definition.id,
        itemName=definition.itemName,metadata=valid.value}
    nativeTickets[authority.ticket]={context=clone(authority),spec=clone(spec)}
    local called,created=pcall(function() return exports['feather-inventory']:IssueNativeFirearmOnce(authority,spec) end)
    nativeTickets[authority.ticket]=nil
    if not called then return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        'Native issuance outcome uncertain; retain the requestId and inspect before retrying.',nil,context.correlationId) end
    if not created or not created.ok then return created or refused('Native issuance returned no confirmed result.') end
    local value=created.value
    if type(value)~='table' or value.characterId~=context.characterId or value.definitionId~=definition.id then
        return refused('Native issuance result mismatch; do not grant a replacement.')
    end
    local checked=WeaponMetadata.Validate(value.metadata,definition)
    if not checked or not checked.ok then return refused('Committed native issuance metadata is invalid; inspect receipt, do not replace.') end
    if value.replayed then reservedSerials[serial]=nil end
    local recorded=RecordIssuance(value,context,value.replayed==true)
    if not recorded.ok then return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        'Weapon delivery committed; provenance incomplete. Retain requestId; do not issue a replacement.',
        {itemInstanceId=value.itemInstanceId},context.correlationId) end
    return WeaponResult.Ok(value,context.correlationId)
end

if type(RegisterCommand)=='function' then
RegisterCommand('WeaponNativeUtilityStatus',function(source)
    if source~=0 or Config.DevMode~=true then return end
    local loaded=WeaponNativeUtilityCatalog~=nil and WeaponNativeUtilityItem~=nil
    local convar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_utility',0) or 0
    local missing={}
    for _,name in ipairs({'DevMode','NativeAlphaRuntime','CharacterAmmunitionEnabled','CharacterAmmoTransportEnabled','NativeAlphaLifecycleWearEnabled'}) do
        if Config[name]~=true then missing[#missing+1]=name..' must be true' end
    end
    if not loaded then missing[#missing+1]='utility modules not loaded' end
    if convar~=1 then missing[#missing+1]='feather_native_utility must be 1' end
    local reinforcedConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_lasso_reinforced',0) or 0
    local reinforcedLoaded=WeaponNativeLassoPolicy~=nil
    local davyConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_davy_lantern',0) or 0
    -- The collection native owner is client-side; shared policy/item methods
    -- establish server readiness, not a claim of live engine acceptance.
    local davyLoaded=WeaponNativeDavyLanternPolicy~=nil and loaded and type(WeaponNativeUtilityItem.ValidateCollection)=='function'
    if davyConvar==1 and not davyLoaded then missing[#missing+1]='Davy collection policy not loaded' end
    local binocularsConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_binoculars',0) or 0
    local binocularsLoaded=WeaponNativeBinocularsPolicy~=nil and davyLoaded
    if binocularsConvar==1 and not binocularsLoaded then missing[#missing+1]='Binoculars policy not loaded' end
    if binocularsConvar==1 and not WeaponNativeUtilityCatalog.DavyEnabled() then missing[#missing+1]='Binoculars requires Davy collection admission' end
    local cameraConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_camera',0) or 0
    local cameraLoaded=WeaponNativeCameraPolicy~=nil and binocularsLoaded
    if cameraConvar==1 and not cameraLoaded then missing[#missing+1]='Camera policy not loaded' end
    if cameraConvar==1 and not WeaponNativeUtilityCatalog.BinocularsEnabled() then missing[#missing+1]='Camera requires Binoculars collection admission' end
    local advancedCameraConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_camera_advanced',0) or 0
    local advancedCameraLoaded=WeaponNativeAdvancedCameraPolicy~=nil and cameraLoaded
    if advancedCameraConvar==1 and not advancedCameraLoaded then missing[#missing+1]='Advanced Camera policy not loaded' end
    if advancedCameraConvar==1 and not WeaponNativeUtilityCatalog.CameraEnabled() then missing[#missing+1]='Advanced Camera requires Standard Camera collection admission' end
    local improvedBinocularsConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_binoculars_improved',0) or 0
    local improvedBinocularsLoaded=WeaponNativeImprovedBinocularsPolicy~=nil and advancedCameraLoaded
    if improvedBinocularsConvar==1 and not improvedBinocularsLoaded then missing[#missing+1]='Improved Binoculars policy not loaded' end
    if improvedBinocularsConvar==1 and not WeaponNativeUtilityCatalog.AdvancedCameraEnabled() then missing[#missing+1]='Improved Binoculars requires Advanced Camera collection admission' end
    local fishingRodConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_fishing_rod',0) or 0
    local fishingRodLoaded=WeaponNativeFishingRodPolicy~=nil and advancedCameraLoaded
    if fishingRodConvar==1 and not fishingRodLoaded then missing[#missing+1]='Fishing Rod policy not loaded' end
    if fishingRodConvar==1 and not WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() then missing[#missing+1]='Fishing Rod requires Improved Binoculars collection admission' end
    local metalDetectorConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_metal_detector',0) or 0
    local metalDetectorLoaded=WeaponNativeMetalDetectorPolicy~=nil and advancedCameraLoaded
    if metalDetectorConvar==1 and not metalDetectorLoaded then missing[#missing+1]='Metal Detector policy not loaded' end
    if metalDetectorConvar==1 and not WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() then missing[#missing+1]='Metal Detector requires Improved Binoculars collection admission' end
    if reinforcedConvar==1 and not reinforcedLoaded then missing[#missing+1]='lasso family policy not loaded' end
    print('[WeaponNativeUtilityStatus] '..json.encode({loaded=loaded,enabled=loaded and WeaponNativeUtilityCatalog.Enabled() or false,
        convar=convar,missing=missing,definitionId='utility_lasso',itemName='weapon_lasso',equipmentSlot='weapon_utility',
        reinforcedLoaded=reinforcedLoaded,reinforcedConvar=reinforcedConvar,
        reinforcedEnabled=loaded and reinforcedLoaded and WeaponNativeUtilityCatalog.ReinforcedEnabled() or false,
        davyLoaded=davyLoaded,davyConvar=davyConvar,
        davyEnabled=davyLoaded and WeaponNativeUtilityCatalog.DavyEnabled() or false,
        binocularsLoaded=binocularsLoaded,binocularsConvar=binocularsConvar,
        binocularsEnabled=binocularsLoaded and WeaponNativeUtilityCatalog.BinocularsEnabled() or false,
        cameraLoaded=cameraLoaded,cameraConvar=cameraConvar,
        cameraEnabled=cameraLoaded and WeaponNativeUtilityCatalog.CameraEnabled() or false,
        advancedCameraLoaded=advancedCameraLoaded,advancedCameraConvar=advancedCameraConvar,
        advancedCameraEnabled=advancedCameraLoaded and WeaponNativeUtilityCatalog.AdvancedCameraEnabled() or false,
        improvedBinocularsLoaded=improvedBinocularsLoaded,improvedBinocularsConvar=improvedBinocularsConvar,
        fishingRodLoaded=fishingRodLoaded,fishingRodConvar=fishingRodConvar,
        metalDetectorLoaded=metalDetectorLoaded,metalDetectorConvar=metalDetectorConvar,
        improvedBinocularsEnabled=improvedBinocularsLoaded and WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() or false,
        fishingRodEnabled=fishingRodLoaded and WeaponNativeUtilityCatalog.FishingRodEnabled() or false,
        metalDetectorEnabled=metalDetectorLoaded and WeaponNativeUtilityCatalog.MetalDetectorEnabled() or false,
        noWrites=true,usesAmmunition=false,liveNativeAccepted=false}))
end)
RegisterCommand('WeaponNativeKnifeStatus',function(source)
    if source~=0 then return end
    print('[WeaponNativeKnifeStatus] '..json.encode(knifeAdmissionStatus()))
end,true)
RegisterCommand('WeaponNativeThrowableStatus',function(source)
    if source~=0 then return end
    local loaded=WeaponNativeThrowablePolicy~=nil and WeaponNativeThrowableItem~=nil
    local missing={}
    local gates={DevMode=Config.DevMode==true,NativeAlphaRuntime=Config.NativeAlphaRuntime==true,
        CharacterAmmunitionEnabled=Config.CharacterAmmunitionEnabled==true,
        CharacterAmmoTransportEnabled=Config.CharacterAmmoTransportEnabled==true,
        NativeAlphaLifecycleWearEnabled=Config.NativeAlphaLifecycleWearEnabled==true}
    for _,key in ipairs({'DevMode','NativeAlphaRuntime','CharacterAmmunitionEnabled','CharacterAmmoTransportEnabled','NativeAlphaLifecycleWearEnabled'}) do
        if not gates[key] then missing[#missing+1]=key..' must be true' end
    end
    local convar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_throwable',0) or 0
    if not loaded then missing[#missing+1]='throwable shared modules not loaded; check manifest/refresh' end
    if convar~=1 then missing[#missing+1]='feather_native_throwable must be 1' end
    local profile,why
    if loaded then profile,why=WeaponNativeThrowablePolicy.Resolve(WeaponDefinitionCatalog) end
    if loaded and not profile then missing[#missing+1]=why end
    local pickupConvar=type(GetConvarInt)=='function' and GetConvarInt('feather_native_throwable_pickup',0) or 0
    local pickupReady=WeaponNativeThrowableRecovery~=nil and type(WeaponCharacterAmmoService)=='table'
        and type(WeaponCharacterAmmoService.NativePickup)=='function'
    local pickupEnabled=pickupReady and pickupConvar==1 and loaded and profile~=nil and WeaponNativeThrowablePolicy.Enabled() or false
    print('[WeaponNativeThrowableStatus] '..json.encode({loaded=loaded,gates=gates,convar=convar,missing=missing,
        enabled=loaded and profile~=nil and WeaponNativeThrowablePolicy.Enabled() or false,
        definitionId='throwable_tomahawk',ammunitionId='ammo_tomahawk_regular',fundedCeiling=1,
        fundingRequiresRebuild=true,pickupCredits=pickupEnabled,pickupConvar=pickupConvar,
        pickupComponentsLoaded=pickupReady,pickupRequiresCommittedSpend=true,
        pickupPolicy='same_session_native_spend_credit_v1',originConfirmed=false,noWrites=true}))
end,true)
RegisterCommand('WeaponNativeIssuanceStatus',function(source)
    if source~=0 then return end
    print('[WeaponNativeIssuanceStatus] '..json.encode({available=IssuanceService.NativeAvailable(),
        pristineOnly=true,stableRequestIdRequired=true,noGrants=true,knife=knifeAdmissionStatus()}))
end,true)
RegisterCommand('WeaponNativeIssue',function(source,args)
    if source~=0 or not IssuanceService.NativeAvailable() then return end
    local target=tonumber(args and args[1])
    if not args or #args~=3 or not target or target<1 or target%1~=0 then
        return print('[WeaponNativeIssue] REFUSED current-server-id definition-id stable-request-id required')
    end
    local session=CoreAdapter.ResolveSession(target)
    if not session or not session.ok then return print('[WeaponNativeIssue] REFUSED current target required') end
    local result=IssuanceService.Issue({characterId=session.value.characterId,resource='feather-weapons',
        reason='development_grant',correlationId=args[3]},
        {characterId=session.value.characterId,definitionId=args[2],requestId=args[3],purpose='development_grant'},'feather-weapons')
    print('[WeaponNativeIssue] '..(result and result.ok and 'PASS ' or 'REFUSED ')..json.encode(result)
        ..'; no equip/ammo/material grant requested; retain requestId')
end,true) end

function IssuanceService.Issue(context, request, invokingResource)
    context = type(context) == "table" and context or {}
    request = type(request) == "table" and request or {}
    local characterId = CoreAdapter.NormalizeCharacterId(request.characterId or context.characterId)
    local definitionId = CleanText(request.definitionId, 64)
    local purpose = CleanText(request.purpose or context.reason or "issued", 48)
    if not characterId or not definitionId then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            "A target character and weapon definition are required", nil, context.correlationId)
    end

    local definitionResult = DefinitionRegistry.Get("weapon", definitionId)
    if not definitionResult.ok then return definitionResult end
    local definition = definitionResult.value
    context.characterId = characterId
    context.reason = purpose
    context.resource = CleanText(invokingResource or context.resource, 64)
    local authorized = Authorize(context, definitionId, purpose)
    if not authorized.ok then return authorized end
    local requestId = ValidateRequestId(request.requestId)
    if request.requestId ~= nil and not requestId then
        return WeaponResult.Error(WeaponErrors.ITEM_INVALID,
            "requestId must be 1-128 characters using letters, numbers, dot, underscore, colon, or hyphen",
            nil, context.correlationId)
    end
    local key=tostring(context.resource)..'\0'..tostring(requestId)
    if nativeRequests[key] then return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        'Native issuance request is already in progress; do not submit a new requestId.',nil,context.correlationId) end
    nativeRequests[key]=true
    local called,result=pcall(IssueNative,clone(context),clone(request),definition,requestId)
    nativeRequests[key]=nil
    if not called then return WeaponResult.Error(WeaponErrors.OPERATION_CONFLICT,
        'Native issuance outcome is unconfirmed; retain requestId and inspect before retrying.',nil,context.correlationId) end
    return result
end

function IssuanceService.CheckContract()
    local untrusted = IssuanceService.Issue({ reason = "development_grant" }, {
        characterId = "00000000-0000-0000-0000-000000000001",
        definitionId = "revolver_cattleman", purpose = "development_grant"
    }, "untrusted-smoke-resource")
    local incomplete = IssuanceService.Issue({ reason = "development_grant" }, {}, "feather-weapons")
    local missingRequestId = IssuanceService.Issue({ reason = "purchase" }, {
        characterId = "00000000-0000-0000-0000-000000000001",
        definitionId = "revolver_cattleman", purpose = "purchase"
    }, "feather-weapons")
    local oversizedRequestId = IssuanceService.Issue({ reason = "purchase" }, {
        characterId = "00000000-0000-0000-0000-000000000001",
        definitionId = "revolver_cattleman", purpose = "purchase",
        requestId = string.rep("a", 129)
    }, "feather-weapons")
    local malformedRequestId = IssuanceService.Issue({ reason = "purchase" }, {
        characterId = "00000000-0000-0000-0000-000000000001",
        definitionId = "revolver_cattleman", purpose = "purchase",
        requestId = "invalid request id"
    }, "feather-weapons")
    local settings, authorization = Config.Issuance or {}, (Config.Issuance or {}).authorization or {}
    return {
        serviceAvailable = type(IssuanceService.Issue) == "function",
        trustedCallerConfigured = (settings.trustedResources or {})["feather-weapons"] == true,
        purposeConfigured = (settings.allowedPurposes or {}).development_grant == true,
        authorizationConfigured = authorization.enabled ~= true
            or (type(authorization.action) == "string" and authorization.action ~= ""),
        untrustedRejected = not untrusted.ok and untrusted.error
            and untrusted.error.code == WeaponErrors.AUTHORIZATION_INVALID,
        incompleteRejected = not incomplete.ok and incomplete.error
            and incomplete.error.code == WeaponErrors.ITEM_INVALID,
        requestIdRequired = not missingRequestId.ok and missingRequestId.error
            and missingRequestId.error.code == WeaponErrors.ITEM_INVALID,
        oversizedRequestIdRejected = not oversizedRequestId.ok and oversizedRequestId.error
            and oversizedRequestId.error.code == WeaponErrors.ITEM_INVALID,
        malformedRequestIdRejected = not malformedRequestId.ok and malformedRequestId.error
            and malformedRequestId.error.code == WeaponErrors.ITEM_INVALID
    }
end
