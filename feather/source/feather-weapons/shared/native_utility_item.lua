-- Pure, staged utility identity projection. No native calls or ownership grant.
WeaponNativeUtilityItem={}
local U=WeaponNativeUtilityItem
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
local function keys(v,allowed)
    if type(v)~='table' or getmetatable(v)~=nil then return false end
    for k in pairs(v) do if not allowed[k] then return false end end; return true
end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
local function number(v,min,max) return type(v)=='number' and v>=min and v<=max end
local function integer(v,min) return number(v,min,math.huge-1) and v<math.huge and v%1==0 end
local function identity(v)
    if not keys(v,{characterId=true,sessionId=true,epoch=true}) then return false end
    return text(v.characterId) and text(v.sessionId) and text(v.epoch)
end
function U.Validate(metadata,def)
    if not WeaponNativeUtilityCatalog.Resolve(def) then return nil,'unsupported_native_utility_definition' end
    if not keys(metadata,{schemaVersion=true,weaponDefinitionId=true,serialNumber=true,condition=true,
        quality=true,flags=true,attachments=true,cosmetics=true,provenance=true})
        or metadata.schemaVersion~=WeaponConstants.MetadataSchemaVersion
        or metadata.weaponDefinitionId~=def.id or not text(metadata.serialNumber)
        or not number(metadata.condition,0,100) or not number(metadata.quality,0,100)
        or not keys(metadata.flags,{stolen=true,evidence=true,disabled=true})
        or not keys(metadata.attachments,{}) or not keys(metadata.cosmetics,{})
        or not keys(metadata.provenance,{type=true,resource=true,reference=true,sourceReference=true,
            createdAt=true,issuedToCharacterId=true,issuedByCharacterId=true}) then
        return nil,'invalid_native_utility_metadata'
    end
    for _,k in ipairs({'stolen','evidence','disabled'}) do
        if type(metadata.flags[k])~='boolean' then return nil,'invalid_native_utility_flags' end
    end
    for k,v in pairs(metadata.provenance) do
        if (k=='createdAt' and not integer(v,0)) or (k~='createdAt' and not text(v)) then
            return nil,'invalid_native_utility_provenance'
        end
    end
    return copy(metadata)
end
function U.Build(def,options)
    if not keys(options,{serialNumber=true,condition=true,quality=true,flags=true,provenance=true}) then
        return nil,'invalid_native_utility_options'
    end
    return U.Validate({schemaVersion=WeaponConstants.MetadataSchemaVersion,weaponDefinitionId=def.id,
        serialNumber=options.serialNumber,condition=options.condition==nil and 100 or options.condition,
        quality=options.quality==nil and 100 or options.quality,
        flags=options.flags or {stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},
        provenance=options.provenance or {}},def)
end
function U.Project(row,def,bound)
    local profile=WeaponNativeUtilityCatalog.Resolve(def)
    if not profile or not identity(bound) then return nil,'utility_identity_required' end
    if not keys(row,{id=true,revision=true,itemName=true,metadata=true})
        or not integer(row.id,1) or not integer(row.revision,0) or row.itemName~=profile.itemName then
        return nil,'utility_row_required'
    end
    local metadata,why=U.Validate(row.metadata,def)
    if not metadata then return nil,why end
    if metadata.condition<1 or metadata.flags.disabled or metadata.flags.evidence then
        return nil,'utility_not_equippable'
    end
    return {identity=copy(bound),itemInstanceId=row.id,itemRevision=row.revision,
        definitionId=def.id,itemName=profile.itemName,nativeWeaponName=profile.nativeWeaponName,
        slot=profile.slot,serialNumber=metadata.serialNumber,condition=metadata.condition,quality=metadata.quality}
end
-- Ownership must already have been established by the trusted Inventory reader.
function U.Assigned(snapshot,def,bound)
    if not identity(bound) or type(snapshot)~='table' or snapshot.characterId~=bound.characterId
        or type(snapshot.expected)~='table' or type(snapshot.equipment)~='table' then return nil,'utility_snapshot_required' end
    local row,expected=snapshot.equipment.utility,snapshot.expected.weapon_utility
    if row==nil and expected==nil then return false end
    if type(row)~='table' or not keys(expected,{itemId=true,revision=true})
        or expected.itemId~=row.id or expected.revision~=row.revision then return nil,'utility_assignment_changed' end
    for slot,entry in pairs(snapshot.expected) do
        if slot~='weapon_utility' and type(entry)=='table' and entry.itemId==row.id then
            return nil,'utility_duplicate_assignment'
        end
    end
    local projected,why=U.Project(row,def,bound)
    if not projected then return nil,why end
    return {identity=copy(bound),equipmentSlot='weapon_utility',row=copy(row)}
end
function U.ValidateApproval(approval,def,bound)
    if type(def)~='table' or not identity(bound) or not keys(approval,{identity=true,equipmentSlot=true,row=true})
        or not identity(approval.identity) or not WeaponNativeUtilityCatalog.Slots()[approval.equipmentSlot] then return nil,'utility_approval_required' end
    if (approval.equipmentSlot=='weapon_utility_tertiary')~=(def.id=='utility_binoculars') then return nil,'utility_profile_slot_mismatch' end
    if (approval.equipmentSlot=='weapon_utility_quaternary')~=(def.id=='utility_camera') then return nil,'utility_profile_slot_mismatch' end
    if (approval.equipmentSlot=='weapon_utility_quinary')~=(def.id=='utility_camera_advanced') then return nil,'utility_profile_slot_mismatch' end
    if (approval.equipmentSlot=='weapon_utility_senary')~=(def.id=='utility_binoculars_improved') then return nil,'utility_profile_slot_mismatch' end
    if (approval.equipmentSlot=='weapon_utility_octonary')~=(def.id=='utility_fishing_rod') then return nil,'utility_profile_slot_mismatch' end
    if (approval.equipmentSlot=='weapon_utility_septenary')~=(def.id=='utility_metal_detector') then return nil,'utility_profile_slot_mismatch' end
    for _,k in ipairs({'characterId','sessionId','epoch'}) do
        if approval.identity[k]~=bound[k] then return nil,'utility_approval_world_changed' end
    end
    local projected,why=U.Project(approval.row,def,bound)
    if not projected then return nil,why end
    return copy(approval)
end
-- Staged two-lasso projection. Runtime callers still use Assigned until the
-- Inventory two-slot reader and parent lifecycle are wired together.
function U.LassoAssigned(snapshot,catalog,bound)
    if not WeaponNativeLassoPolicy or not identity(bound) or type(snapshot)~='table'
        or snapshot.characterId~=bound.characterId or type(snapshot.expected)~='table'
        or type(snapshot.equipment)~='table' then return nil,'lasso_snapshot_required' end
    local selected,why=WeaponNativeLassoPolicy.ValidateAssignments(snapshot.equipment,catalog)
    if selected==nil then return nil,why end
    -- Only the two original lasso slots are admitted by this staged projection.
    for _,slot in ipairs({'utility','utility_secondary'}) do
        local row,expected=snapshot.equipment[slot],snapshot.expected['weapon_'..slot]
        if (row~=nil or expected~=nil) and (type(row)~='table'
            or not keys(expected,{itemId=true,revision=true}) or expected.itemId~=row.id or expected.revision~=row.revision) then
            return nil,'lasso_assignment_changed'
        end
    end
    if selected==false then return false end
    if selected.slot~='utility' and selected.slot~='utility_secondary' then return nil,'lasso_slot_not_admitted' end
    local row=snapshot.equipment[selected.slot]
    local def=catalog.weapons[selected.definitionId]
    local projected,reason=U.Project(row,def,bound)
    if not projected then return nil,reason end
    for slot,entry in pairs(snapshot.expected) do
        if slot~=selected.equipmentSlot and type(entry)=='table' and entry.itemId==row.id then return nil,'utility_duplicate_assignment' end
    end
    return {identity=copy(bound),equipmentSlot=selected.equipmentSlot,row=copy(row)}
end
function U.ValidateLassoApproval(approval,catalog,bound)
    if not identity(bound) or not keys(approval,{identity=true,equipmentSlot=true,row=true})
        or not identity(approval.identity) or (approval.equipmentSlot~='weapon_utility'
            and approval.equipmentSlot~='weapon_utility_secondary') then return nil,'lasso_approval_required' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if approval.identity[key]~=bound[key] then return nil,'utility_approval_world_changed' end
    end
    local slot=approval.equipmentSlot=='weapon_utility' and 'utility' or 'utility_secondary'
    local row=approval.row
    if type(row)~='table' then return nil,'utility_row_required' end
    return U.LassoAssigned({characterId=bound.characterId,expected={[approval.equipmentSlot]={itemId=row.id,revision=row.revision}},
        equipment={[slot]=copy(row)}},catalog,bound)
end
function U.AssignedSnapshot(snapshot,catalog,bound)
    if WeaponNativeLassoPolicy and type(GetConvarInt)=='function' and GetConvarInt('feather_native_lasso_reinforced',0)==1 then
        return U.LassoAssigned(snapshot,catalog,bound)
    end
    return U.Assigned(snapshot,catalog.weapons.utility_lasso,bound)
end
-- Pure intent construction for a future released-owner coordinator. It does not
-- issue a reservation or authorize SQL; Inventory must re-read under its TX.
function U.Prepare(snapshot,def,bound,intent)
    local family=WeaponNativeUtilityCatalog.ReinforcedEnabled()
    if not identity(bound) or type(snapshot)~='table' or snapshot.characterId~=bound.characterId
        or not keys(intent,{action=true,slot=true,itemId=true,selectedItemId=true})
        or not WeaponNativeUtilityCatalog.Slots()[intent.slot] or (intent.action~='equip' and intent.action~='unequip')
        or type(snapshot.expected)~='table' or type(snapshot.equipment)~='table'
        or type(snapshot.utilityEquipment)~='table' then return nil,'utility_transition_snapshot_required' end
    local assigned,why
    if family then assigned,why=U.LassoAssigned(snapshot.utilityEquipment,WeaponDefinitionCatalog,bound)
    else assigned,why=U.Assigned(snapshot.utilityEquipment,def,bound) end
    if assigned==nil then return nil,why end
    -- Both projections must describe one full equipment revision set, not
    -- individually valid snapshots sampled on opposite sides of a mutation.
    local inner=snapshot.utilityEquipment.expected
    for slot,entry in pairs(snapshot.expected) do
        local other=inner[slot]
        if type(slot)~='string' or not keys(entry,{itemId=true,revision=true})
            or not integer(entry.itemId,1) or not integer(entry.revision,0)
            or type(other)~='table' or entry.itemId~=other.itemId or entry.revision~=other.revision then
            return nil,'utility_transition_snapshot_changed'
        end
    end
    for slot in pairs(inner) do if snapshot.expected[slot]==nil then return nil,'utility_transition_snapshot_changed' end end
    local row=intent.action=='equip' and snapshot.candidate or assigned and assigned.row
    if type(row)~='table' then return nil,'utility_owned_candidate_required' end
    if intent.action=='equip' then
        if family and assigned then return nil,'one_equipped_lasso_required' end
        if intent.itemId~=row.id or (intent.selectedItemId~=nil and intent.selectedItemId~=row.id) then return nil,'utility_candidate_changed' end
        local projected,reason=U.Project(row,def,bound)
        if not projected then return nil,reason end
        for _,entry in pairs(snapshot.expected) do if entry.itemId==row.id then return nil,'utility_already_equipped' end end
    elseif assigned.equipmentSlot~=intent.slot or intent.itemId~=nil or (intent.selectedItemId~=nil and intent.selectedItemId~=row.id) then
        return nil,'utility_selected_assignment_changed'
    end
    return {characterId=bound.characterId,action=intent.action,slot=intent.slot,utility=true,lassoFamily=family or nil,
        utilityId=row.id,utilityRevision=row.revision,before=copy(row.metadata),expected=copy(snapshot.expected),
        lifecycleSnapshot=copy(snapshot.equipment),brokenEquipmentContract=snapshot.brokenEquipmentContract,
        brokenPromotionContract=snapshot.brokenPromotionContract}
end
