-- Data-only native carrier. Counts belong solely to the character ledger.
-- Public metadata/issuance/equipment routes require the explicit throwable gate.
WeaponNativeThrowableItem={}
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~='table' then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
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
    if WeaponNativeThrowablePolicy.QuantityEnabled and WeaponNativeThrowablePolicy.QuantityEnabled() then
        return nil,'quantity_mode_uses_ammunition'
    end
    if type(snapshot)=='table' and type(snapshot.throwableEquipment)=='table' and snapshot.throwableEquipment.contract==2 then
        return WeaponNativeThrowableItem.PrepareUnits(snapshot,catalog,identity,intent)
    end
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
    if type(snapshot)=='table' and snapshot.contract==3 then
        return WeaponNativeThrowableItem.AssignedQuantity(snapshot,catalog,identity,limits)
    end
    if type(snapshot)=='table' and snapshot.contract==2 then
        return WeaponNativeThrowableItem.AssignedUnits(snapshot,catalog,identity,limits)
    end
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

-- Actual paid units in Inventory's private carrying collection. This is an
-- ownership projection, never an issuance/pickup grant. No equipment/carrier row
-- is fabricated. The first stable item ID anchors the single native GUID while
-- the lease binds every unit, including secondary rows.
function WeaponNativeThrowableItem.AssignedUnits(snapshot,catalog,identity,limits)
    if not keys(identity,{characterId=true,sessionId=true,epoch=true}) then return nil,'throwable_identity_required' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do if not text(identity[key]) then return nil,'throwable_identity_required' end end
    if not keys(snapshot,{contract=true,kind=true,characterId=true,identity=true,revision=true,pools=true,units=true})
        or snapshot.contract~=2 or snapshot.kind~='physical_throwable_units'
        or snapshot.characterId~=identity.characterId or not keys(snapshot.identity,{characterId=true,sessionId=true,epoch=true})
        or not integer(snapshot.revision,0) or type(snapshot.units)~='table' or #snapshot.units>3
        or type(limits)~='table' or limits.ammo_tomahawk_regular~=3 then return nil,'throwable_units_snapshot_required' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if snapshot.identity[key]~=identity[key] then return nil,'throwable_units_identity_changed' end
    end
    local pools,why=WeaponCharacterAmmunition.Validate(snapshot.pools,limits)
    if not pools then return nil,why end
    if pools.ammo_tomahawk_regular~=#snapshot.units then return nil,'throwable_units_quantity_changed' end
    local units,serials,previous={},{},0
    for key,row in pairs(snapshot.units) do
        if not integer(key,1) or key>#snapshot.units then return nil,'throwable_units_array_required' end
    end
    for _,row in ipairs(snapshot.units) do
        if not keys(row,{id=true,revision=true,itemName=true,metadata=true}) or not integer(row.id,1)
            or row.id<=previous or not integer(row.revision,0) or row.itemName~='weapon_thrown_tomahawk' then
            return nil,'throwable_unit_identity_changed'
        end
        local document;document,why=WeaponNativeThrowableItem.Validate(row.metadata,catalog)
        if not document then return nil,why end
        if document.condition<1 or document.flags.disabled or document.flags.evidence or serials[document.serialNumber] then
            return nil,'throwable_unit_not_equippable'
        end
        serials[document.serialNumber]=true;previous=row.id;units[#units+1]=copy(row)
    end
    if #units==0 then return false end
    return {contract=2,identity=copy(identity),equipmentSlot='weapon_throwable',row=copy(units[1]),units=units,
        ledgerRevision=snapshot.revision,ammunitionId='ammo_tomahawk_regular',fundedQuantity=#units,
        nativeRequired=true,pickupCredits=false}
end

function WeaponNativeThrowableItem.AssignedQuantity(snapshot,catalog,identity,limits)
    if not WeaponNativeThrowablePolicy.QuantityEnabled() or not WeaponNativeThrowablePolicy.Resolve(catalog)
        or not keys(snapshot,{contract=true,kind=true,characterId=true,identity=true,revision=true,pools=true})
        or snapshot.contract~=3 or snapshot.kind~='throwable_quantity' or not integer(snapshot.revision,0)
        or not keys(identity,{characterId=true,sessionId=true,epoch=true}) or snapshot.characterId~=identity.characterId
        or not equal(snapshot.identity,identity) or type(limits)~='table' or limits.ammo_tomahawk_regular~=3 then return nil,'quantity_snapshot_required' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do if not text(identity[key]) then return nil,'quantity_identity_required' end end
    local pools,why=WeaponCharacterAmmunition.Validate(snapshot.pools,limits)
    if not pools then return nil,why end
    return {contract=3,identity=copy(identity),ledgerRevision=snapshot.revision,
        ammunitionId='ammo_tomahawk_regular',fundedQuantity=pools.ammo_tomahawk_regular,units={},pickupCredits=true}
end

function WeaponNativeThrowableItem.PrepareUnits(snapshot,catalog,identity,intent)
    if type(snapshot)~='table' or type(snapshot.expected)~='table' or type(snapshot.equipment)~='table'
        or type(intent)~='table' or intent.slot~='weapon_throwable'
        or (intent.action~='equip' and intent.action~='unequip') then return nil,'throwable_units_intent_required' end
    local approval,why=WeaponNativeThrowableItem.AssignedUnits(snapshot.throwableEquipment,catalog,identity,snapshot.throwableLimits)
    if approval==nil then return nil,why end
    if snapshot.characterId~=identity.characterId then return nil,'throwable_units_identity_changed' end
    local row=snapshot.candidate
    if not keys(row,{id=true,revision=true,itemName=true,metadata=true}) or not integer(row.id,1)
        or not integer(row.revision,0) or row.itemName~='weapon_thrown_tomahawk' then return nil,'throwable_owned_unit_required' end
    local document;document,why=WeaponNativeThrowableItem.Validate(row.metadata,catalog)
    if not document then return nil,why end
    for _,assigned in pairs(snapshot.expected) do
        if type(assigned)~='table' or not integer(assigned.itemId,1) or not integer(assigned.revision,0)
            or assigned.itemId==row.id then return nil,'throwable_unit_assignment_conflict' end
    end
    if intent.action=='equip' then
        if snapshot.candidateCustody~='inventory' or intent.itemId~=row.id
            or #snapshot.throwableEquipment.units>=3 or document.condition<1
            or document.flags.disabled or document.flags.evidence then return nil,'throwable_unit_not_available' end
    else
        if snapshot.candidateCustody~='carried' or intent.itemId~=nil or intent.selectedItemId~=row.id then
            return nil,'throwable_carried_selection_changed'
        end
        local found=false
        local function same(a,b)
            if type(a)~=type(b) then return false end;if type(a)~='table' then return a==b end
            for k,v in pairs(a) do if not same(v,b[k]) then return false end end
            for k in pairs(b) do if a[k]==nil then return false end end;return true
        end
        for _,unit in ipairs(snapshot.throwableEquipment.units) do
            if same(unit,row) then found=true end
        end
        if not found then return nil,'throwable_carried_selection_changed' end
    end
    local revision=snapshot.throwableEquipment.revision
    return {characterId=identity.characterId,action=intent.action,slot='weapon_throwable',throwable=true,throwableUnits=true,
        unitItemId=row.id,limits=copy(snapshot.throwableLimits),expected=copy(snapshot.expected),
        lifecycleSnapshot=copy(snapshot.equipment),brokenEquipmentContract=snapshot.brokenEquipmentContract,
        brokenPromotionContract=snapshot.brokenPromotionContract,
        unitStorage={version=1,action=intent.action=='equip' and 'carry' or 'return',operationId='eq:'..revision..':'..intent.action,
            expectedRevision=revision,expectedPools=copy(snapshot.throwableEquipment.pools),limits=copy(snapshot.throwableLimits),
            items={{id=row.id,revision=row.revision,metadata=copy(document)}}}}
end

-- Validate the collector side of an already committed physical claim. This is
-- receipt validation, not permission to claim a world object. Callers must hold
-- the server reservation (or accept its matching response) independently.
function WeaponNativeThrowableItem.Recovered(before,after,receipt,catalog,identity,limits)
    local prior,why=WeaponNativeThrowableItem.AssignedUnits(before,catalog,identity,limits)
    if prior==nil then return nil,why end
    local nextApproval;nextApproval,why=WeaponNativeThrowableItem.AssignedUnits(after,catalog,identity,limits)
    if not nextApproval then return nil,why or 'throwable_recovered_unit_required' end
    if type(receipt)~='table' or not integer(receipt.itemId,1) or not integer(receipt.itemRevision,1)
        or receipt.characterId~=identity.characterId or not equal(receipt.collector,identity)
        or not keys(receipt.origin,{characterId=true,sessionId=true,epoch=true})
        or not text(receipt.origin.characterId) or not text(receipt.origin.sessionId) or not text(receipt.origin.epoch)
        or not text(receipt.projectileInstanceId) or receipt.nativeAmmoDelta~=0 or receipt.looseInventoryDelta~=0
        or receipt.revision~=after.revision or not equal(receipt.pools,after.pools)
        or not equal(receipt.throwableUnitsSnapshot,after) or after.revision~=before.revision+1
        or #after.units~=#before.units+1 then return nil,'throwable_claim_receipt_changed' end
    for id in pairs(limits) do
        local value=before.pools[id]
        if not integer(value,0) or after.pools[id]~=value+(id=='ammo_tomahawk_regular' and 1 or 0) then
            return nil,'throwable_claim_other_pool_changed'
        end
    end
    local previous={}
    for _,row in ipairs(before.units) do previous[row.id]=row end
    local gained
    for _,row in ipairs(after.units) do
        if previous[row.id] then
            if not equal(previous[row.id],row) then return nil,'throwable_existing_unit_changed' end
            previous[row.id]=nil
        elseif gained or row.id~=receipt.itemId or row.revision~=receipt.itemRevision then
            return nil,'throwable_claim_unit_changed'
        else gained=copy(row) end
    end
    if not gained or next(previous)~=nil then return nil,'throwable_claim_unit_changed' end
    return {approval=nextApproval,unit=gained,before=copy(before),after=copy(after)}
end
