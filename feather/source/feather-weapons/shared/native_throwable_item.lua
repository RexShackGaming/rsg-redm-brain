-- Data-only native carrier. Counts belong solely to the character ledger.
-- Public metadata/issuance/equipment routes require the explicit throwable gate.
WeaponNativeThrowableItem={}
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function keys(value,allowed)
    if type(value)~='table' or getmetatable(value)~=nil then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
local function integer(v,min) return type(v)=='number' and v>=min and v%1==0 and v<math.huge end
local function unit(v) return type(v)=='number' and v==v and v>=0 and v<=100 end
-- Equipment-only reservation. Funding is independently read on activation;
-- this preflight cannot mint or move character-ammo credit.
function WeaponNativeThrowableItem.Prepare(snapshot,catalog,identity,intent)
    if not keys(identity,{characterId=true,sessionId=true,epoch=true}) then return nil,'throwable_identity_required' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do if not text(identity[key]) then return nil,'throwable_identity_required' end end
    if type(snapshot)~='table' or snapshot.characterId~=identity.characterId or type(snapshot.expected)~='table'
        or type(snapshot.equipment)~='table' or type(snapshot.throwableEquipment)~='table' or type(intent)~='table'
        or intent.slot~='weapon_throwable' or (intent.action~='equip' and intent.action~='unequip') then return nil,'throwable_transition_snapshot_required' end
    local child=snapshot.throwableEquipment
    if child.characterId~=identity.characterId or type(child.expected)~='table' or type(child.equipment)~='table' then return nil,'throwable_snapshot_required' end
    local function equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end; return true
    end
    if not equal(snapshot.expected,child.expected) then return nil,'throwable_full_snapshot_changed' end
    local ids={}
    for slot,value in pairs(snapshot.expected) do
        if type(slot)~='string' or not keys(value,{itemId=true,revision=true}) or not integer(value.itemId,1)
            or not integer(value.revision,0) or ids[value.itemId] then return nil,'throwable_invalid_equipment_snapshot' end
        ids[value.itemId]=true
    end
    local row=intent.action=='equip' and snapshot.candidate or child.equipment.throwable
    if not keys(row,{id=true,revision=true,itemName=true,metadata=true}) or not integer(row.id,1)
        or not integer(row.revision,0) or row.itemName~='weapon_thrown_tomahawk' then return nil,'throwable_owned_candidate_required' end
    local metadata,why=WeaponNativeThrowableItem.Validate(row.metadata,catalog)
    if not metadata then return nil,why end
    if intent.action=='equip' then
        if intent.itemId~=row.id or ids[row.id] then return nil,'throwable_candidate_changed_or_assigned' end
        if metadata.condition<1 or metadata.flags.disabled or metadata.flags.evidence then return nil,'native_throwable_not_equippable' end
    else
        local expected=snapshot.expected.weapon_throwable
        if not expected or expected.itemId~=row.id or expected.revision~=row.revision or intent.itemId~=nil
            or (intent.selectedItemId~=nil and intent.selectedItemId~=row.id) then return nil,'throwable_selected_assignment_changed' end
    end
    return {characterId=identity.characterId,action=intent.action,slot='weapon_throwable',throwable=true,
        throwableId=row.id,throwableRevision=row.revision,before=copy(metadata),expected=copy(snapshot.expected),
        lifecycleSnapshot=copy(snapshot.equipment),brokenEquipmentContract=snapshot.brokenEquipmentContract,
        brokenPromotionContract=snapshot.brokenPromotionContract}
end
function WeaponNativeThrowableItem.Validate(metadata,catalog)
    local profile,why=WeaponNativeThrowablePolicy.Resolve(catalog)
    if not profile then return nil,why end
    if not keys(metadata,{schemaVersion=true,weaponDefinitionId=true,serialNumber=true,condition=true,
        quality=true,flags=true,attachments=true,cosmetics=true,provenance=true,ammo=true})
        or metadata.schemaVersion~=WeaponConstants.MetadataSchemaVersion
        or metadata.weaponDefinitionId~=profile.definition.id or not text(metadata.serialNumber)
        or not unit(metadata.condition) or not unit(metadata.quality) then return nil,'invalid_native_throwable_metadata' end
    if not keys(metadata.ammo,{ownership=true,type=true}) or metadata.ammo.ownership~='character'
        or metadata.ammo.type~=profile.ammunition.id then return nil,'native_throwable_character_ammo_required' end
    if not keys(metadata.flags,{disabled=true,evidence=true,stolen=true}) then return nil,'invalid_native_throwable_flags' end
    for _,key in ipairs({'disabled','evidence','stolen'}) do
        if type(metadata.flags[key])~='boolean' then return nil,'invalid_native_throwable_flags' end
    end
    if not keys(metadata.attachments,{}) or not keys(metadata.cosmetics,{}) then return nil,'native_throwable_customization_forbidden' end
    if not keys(metadata.provenance,{type=true,resource=true,reference=true,sourceReference=true,createdAt=true,
        issuedToCharacterId=true,issuedByCharacterId=true}) then return nil,'invalid_native_throwable_provenance' end
    for key,value in pairs(metadata.provenance) do
        if key=='createdAt' then
            if not integer(value,0) then return nil,'invalid_native_throwable_provenance' end
        elseif not text(value) then return nil,'invalid_native_throwable_provenance' end
    end
    return copy(metadata)
end
function WeaponNativeThrowableItem.Build(catalog,options)
    if not keys(options,{serialNumber=true,condition=true,quality=true,flags=true,provenance=true}) then return nil,'invalid_native_throwable_options' end
    return WeaponNativeThrowableItem.Validate({schemaVersion=WeaponConstants.MetadataSchemaVersion,
        weaponDefinitionId='throwable_tomahawk',serialNumber=options.serialNumber,
        condition=options.condition==nil and 100 or options.condition,quality=options.quality==nil and 100 or options.quality,
        flags=options.flags or {disabled=false,evidence=false,stolen=false},attachments={},cosmetics={},
        provenance=options.provenance or {},ammo={ownership='character',type='ammo_tomahawk_regular'}},catalog)
end
-- Input is an authoritative same-transaction ledger + all-equipment snapshot.
-- The projection binds data; it never spends or creates a native quantity.
function WeaponNativeThrowableItem.Assigned(snapshot,catalog,identity,limits)
    if not keys(identity,{characterId=true,sessionId=true,epoch=true}) then return nil,'throwable_identity_required' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do if not text(identity[key]) then return nil,'throwable_identity_required' end end
    if type(snapshot)~='table' or snapshot.characterId~=identity.characterId or not integer(snapshot.revision,0)
        or type(snapshot.equipment)~='table' or type(snapshot.expected)~='table' then return nil,'throwable_snapshot_required' end
    local pools,why=WeaponCharacterAmmunition.Validate(snapshot.pools,limits)
    if not pools then return nil,why end
    local count=pools.ammo_tomahawk_regular
    if limits.ammo_tomahawk_regular~=1 or not integer(count,0) or count>1 then return nil,'throwable_funding_policy_required' end
    local ids={}
    for slot,value in pairs(snapshot.expected) do
        if type(slot)~='string' or not keys(value,{itemId=true,revision=true}) or not integer(value.itemId,1)
            or not integer(value.revision,0) or ids[value.itemId] then return nil,'throwable_invalid_equipment_snapshot' end
        ids[value.itemId]=true
    end
    local row,expected=snapshot.equipment.throwable,snapshot.expected.weapon_throwable
    if row==nil and expected==nil then return false end
    if not keys(row,{id=true,revision=true,itemName=true,metadata=true}) or not integer(row.id,1)
        or not integer(row.revision,0) or row.itemName~='weapon_thrown_tomahawk'
        or not keys(expected,{itemId=true,revision=true}) or expected.itemId~=row.id or expected.revision~=row.revision then
        return nil,'throwable_assignment_changed'
    end
    for slot,value in pairs(snapshot.expected) do
        if slot~='weapon_throwable' and type(value)=='table' and value.itemId==row.id then return nil,'throwable_duplicate_assignment' end
    end
    local metadata
    metadata,why=WeaponNativeThrowableItem.Validate(row.metadata,catalog)
    if not metadata then return nil,why end
    if metadata.condition<1 or metadata.flags.disabled or metadata.flags.evidence then return nil,'native_throwable_not_equippable' end
    return {identity=copy(identity),equipmentSlot='weapon_throwable',row=copy(row),ledgerRevision=snapshot.revision,
        ammunitionId='ammo_tomahawk_regular',fundedQuantity=count,nativeRequired=count>0,pickupCredits=false}
end
