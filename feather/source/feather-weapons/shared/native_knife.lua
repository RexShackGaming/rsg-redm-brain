-- Basic knife contract. Gameplay admission remains explicit/default-off.
-- No ammunition document, native attach point, transport or gameplay grant.
WeaponNativeKnife={}
function WeaponNativeKnife.Enabled()
    return Config and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
        and Config.NativeAlphaLifecycleWearEnabled==true and type(GetConvarInt)=='function'
        and GetConvarInt('feather_native_knife',0)==1 or false
end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function integer(v,min) return finite(v) and v%1==0 and v>=min end
local function text(v,max) return type(v)=='string' and #v>0 and #v<=max and not v:find('%c') end
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local function keys(value,allowed)
    if type(value)~='table' or getmetatable(value)~=nil then return false end
    for k in pairs(value) do if not allowed[k] then return false end end
    return true
end
local function definition(def)
    if WeaponNativeMeleeCatalog then return WeaponNativeMeleeCatalog.Resolve(def)~=nil end
    return type(def)=='table' and def.id=='melee_knife' and def.itemName=='weapon_melee_knife'
        and def.nativeWeaponName=='WEAPON_MELEE_KNIFE' and def.family=='knife'
        and def.slot=='melee' and def.usesAmmunition==false and def.capacity==0
        and type(def.ammunitionTypes)=='table' and next(def.ammunitionTypes)==nil
        and def.ammunitionType==nil and type(def.condition)=='table'
        and def.condition.minimum==0 and def.condition.maximum==100 and def.condition.equipMinimum==1
end
function WeaponNativeKnife.Validate(metadata,def)
    if not definition(def) then return nil,'unsupported_native_knife_definition' end
    if not keys(metadata,{schemaVersion=true,weaponDefinitionId=true,serialNumber=true,condition=true,
        quality=true,flags=true,attachments=true,cosmetics=true,provenance=true})
        or metadata.schemaVersion~=WeaponConstants.MetadataSchemaVersion
        or metadata.weaponDefinitionId~=def.id or not text(metadata.serialNumber,128)
        or not finite(metadata.condition) or metadata.condition<0 or metadata.condition>100
        or not finite(metadata.quality) or metadata.quality<0 or metadata.quality>100 then return nil,'invalid_native_knife_metadata' end
    if not keys(metadata.flags,{stolen=true,evidence=true,disabled=true}) then return nil,'invalid_native_knife_flags' end
    for _,key in ipairs({'stolen','evidence','disabled'}) do
        if type(metadata.flags[key])~='boolean' then return nil,'invalid_native_knife_flags' end
    end
    for _,key in ipairs({'attachments','cosmetics'}) do
        if not keys(metadata[key],{}) then return nil,'native_knife_customization_not_supported' end
    end
    if not keys(metadata.provenance,{type=true,resource=true,reference=true,sourceReference=true,createdAt=true,
        issuedToCharacterId=true,issuedByCharacterId=true}) then
        return nil,'invalid_native_knife_provenance'
    end
    for key,value in pairs(metadata.provenance) do
        if key=='createdAt' then
            if not integer(value,0) then return nil,'invalid_native_knife_provenance' end
        elseif not text(value,128) then return nil,'invalid_native_knife_provenance' end
    end
    return copy(metadata)
end
function WeaponNativeKnife.Build(def,options)
    if not definition(def) then return nil,'unsupported_native_knife_definition' end
    if not keys(options,{serialNumber=true,condition=true,quality=true,flags=true,provenance=true}) then
        return nil,'invalid_native_knife_options'
    end
    return WeaponNativeKnife.Validate({schemaVersion=WeaponConstants.MetadataSchemaVersion,weaponDefinitionId=def.id,
        serialNumber=options.serialNumber,condition=options.condition==nil and 100 or options.condition,
        quality=options.quality==nil and 100 or options.quality,
        flags=options.flags or {stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},
        provenance=options.provenance or {}},def)
end
-- A trusted durable row projection, NOT permission to create or assign a knife.
-- No arbitrary hash/point instructions, firearm row acceptance or ammo fields.
function WeaponNativeKnife.Project(row,def,identity)
    if not definition(def) then return nil,'unsupported_native_knife_definition' end
    if not keys(identity,{characterId=true,sessionId=true,epoch=true}) then return nil,'invalid_native_knife_identity' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if not text(identity[key],128) then return nil,'invalid_native_knife_identity' end
    end
    if not keys(row,{id=true,revision=true,itemName=true,metadata=true}) or not integer(row.id,1) or not integer(row.revision,0)
        or row.itemName~=def.itemName then return nil,'invalid_native_knife_row' end
    local metadata,why=WeaponNativeKnife.Validate(row.metadata,def)
    if not metadata then return nil,why end
    if metadata.condition<1 or metadata.flags.disabled or metadata.flags.evidence then return nil,'native_knife_not_equippable' end
    return {identity=copy(identity),itemInstanceId=row.id,itemRevision=row.revision,definitionId=def.id,
        itemName=def.itemName,nativeWeaponName=def.nativeWeaponName,slot='melee',
        serialNumber=metadata.serialNumber,condition=metadata.condition,quality=metadata.quality}
end
-- Read-only server projection of an ALREADY assigned, owned Inventory snapshot.
-- The transaction reader must establish ownership; this does not write a slot,
-- approve a client candidate, or replace session/Inventory guard authorization.
function WeaponNativeKnife.Assigned(snapshot,def,identity)
    if type(snapshot)~='table' or type(identity)~='table' or snapshot.characterId~=identity.characterId
        or type(snapshot.expected)~='table' or type(snapshot.equipment)~='table' then return nil,'knife_snapshot_required' end
    local row=snapshot.equipment.melee
    local expected=snapshot.expected.weapon_melee
    if row==nil and expected==nil then return false end -- no knife is a valid empty companion
    if type(row)~='table' or not keys(expected,{itemId=true,revision=true})
        or expected.itemId~=row.id or expected.revision~=row.revision then return nil,'knife_assignment_changed' end
    for slot,value in pairs(snapshot.expected) do
        if slot~='weapon_melee' and type(value)=='table' and value.itemId==row.id then return nil,'knife_duplicate_assignment' end
    end
    local projected,why=WeaponNativeKnife.Project(row,def,identity)
    if not projected then return nil,why end
    return {identity=copy(projected.identity),equipmentSlot='weapon_melee',row=copy(row)}
end
function WeaponNativeKnife.ValidateApproval(approval,def,identity)
    if not keys(approval,{identity=true,equipmentSlot=true,row=true}) or approval.equipmentSlot~='weapon_melee'
        or not keys(approval.identity,{characterId=true,sessionId=true,epoch=true})
        or type(identity)~='table' then return nil,'knife_approval_required' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if approval.identity[key]~=identity[key] then return nil,'knife_approval_world_changed' end
    end
    local projected,why=WeaponNativeKnife.Project(approval.row,def,approval.identity)
    if not projected then return nil,why end
    return copy(approval)
end
function WeaponNativeKnife.Prepare(snapshot,def,identity,intent)
    if type(snapshot)~='table' or type(intent)~='table' or intent.slot~='weapon_melee'
        or (intent.action~='equip' and intent.action~='unequip') or type(identity)~='table'
        or snapshot.characterId~=identity.characterId or type(snapshot.expected)~='table'
        or type(snapshot.equipment)~='table' or type(snapshot.knifeEquipment)~='table' then return nil,'knife_transition_snapshot_required' end
    local assigned,why=WeaponNativeKnife.Assigned(snapshot.knifeEquipment,def,identity)
    if assigned==nil then return nil,why end
    local row=intent.action=='equip' and snapshot.candidate or assigned and assigned.row
    if type(row)~='table' then return nil,'knife_owned_candidate_required' end
    if intent.action=='equip' then
        if intent.itemId~=row.id then return nil,'knife_candidate_changed' end
        local valid,reason=WeaponNativeKnife.Project(row,def,identity)
        if not valid then return nil,reason end
        for _,entry in pairs(snapshot.expected) do if entry.itemId==row.id then return nil,'knife_already_equipped' end end
    elseif intent.itemId~=nil or (intent.selectedItemId~=nil and intent.selectedItemId~=row.id) then
        return nil,'knife_selected_assignment_changed'
    end
    return {characterId=identity.characterId,action=intent.action,slot='weapon_melee',knifeId=row.id,
        knifeRevision=row.revision,before=copy(row.metadata),expected=copy(snapshot.expected),
        lifecycleSnapshot=copy(snapshot.equipment),brokenEquipmentContract=snapshot.brokenEquipmentContract,
        brokenPromotionContract=snapshot.brokenPromotionContract}
end
