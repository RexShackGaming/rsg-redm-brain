-- Data-only native creation plan. Execution/Inventory authorization are separate.
WeaponCharacterAmmoMaterialization={}
-- Attachment preflight; Validate admits only explicit scoped saved-attachment support.
-- Canonical metadata names definitions; native names/slots come only from the
-- local catalog and the live-proved reconstruction allowlist.
WeaponNativeAttachmentProjection={}
local function attachmentProjection(item,catalog,identity,requireProof)
    if type(item)~='table' or type(catalog)~='table' or type(catalog.weapons)~='table'
        or type(catalog.attachments)~='table' or type(identity)~='table' then return nil,'invalid_attachment_projection' end
    for _,field in ipairs({'characterId','sessionId','epoch'}) do
        if type(identity[field])~='string' or identity[field]=='' then return nil,'attachment_projection_identity_required' end
    end
    if type(item.itemInstanceId)~='number' or item.itemInstanceId<1 or item.itemInstanceId%1~=0 or item.itemInstanceId==math.huge
        or type(item.itemRevision)~='number' or item.itemRevision<0 or item.itemRevision%1~=0 or item.itemRevision==math.huge
        or type(item.serialNumber)~='string' or item.serialNumber=='' then return nil,'attachment_projection_copy_required' end
    local weapon=catalog.weapons[item.definitionId]
    if not weapon or weapon.nativeWeaponName~=item.nativeWeaponName then return nil,'attachment_projection_weapon_mismatch' end
    if type(item.attachments)~='table' or type(item.cosmetics)~='table' or next(item.cosmetics) then
        return nil,'attachment_projection_customization_unsupported'
    end
    local count=0
    for key in pairs(item.attachments) do
        if type(key)~='number' or key<1 or key>4 or key%1~=0 then return nil,'attachment_projection_slots_invalid' end
        count=count+1
    end
    local plan={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,
        itemInstanceId=item.itemInstanceId,itemRevision=item.itemRevision,serialNumber=item.serialNumber,
        nativeWeaponName=item.nativeWeaponName,components={}}
    if count==0 then return plan end
    local setValid,setReason=WeaponNativeAttachmentMappings.ValidateSet(weapon,item.attachments,requireProof)
    if not setValid then return nil,setReason end
    local slots,nativeSlots={},{}
    for index=1,count do
    local saved=item.attachments[index]
    if type(saved)~='table' then return nil,'attachment_projection_unproved_component' end
    for key in pairs(saved) do
        if key~='definitionId' and key~='slot' then return nil,'attachment_projection_untrusted_instruction' end
    end
    local def=catalog.attachments[saved.definitionId]
    if not def or def.id~=saved.definitionId or def.slot~=saved.slot then return nil,'attachment_projection_definition_mismatch' end
    local compatible=false
    for _,id in ipairs(weapon.attachmentSlots and weapon.attachmentSlots[def.slot] or {}) do
        if id==saved.definitionId then compatible=true end
    end
    if not compatible then return nil,'attachment_projection_incompatible' end
    local mapping=WeaponNativeAttachmentMappings.Resolve(weapon,def,requireProof)
    if not mapping then return nil,'attachment_projection_unproved_component' end
    if slots[def.slot] or nativeSlots[mapping.nativeSlot] then return nil,'attachment_projection_duplicate_slot' end
    slots[def.slot]=true; nativeSlots[mapping.nativeSlot]=true
    plan.components[index]={definitionId=def.id,slot=def.slot,nativeComponentName=mapping.nativeComponentName,
        nativeSlot=mapping.nativeSlot,stockComponentName=mapping.stockComponentName}
    end
    table.sort(plan.components,function(a,b) return a.slot<b.slot end)
    return plan
end
function WeaponNativeAttachmentProjection.Build(item,catalog,identity)
    return attachmentProjection(item,catalog,identity,true)
end
function WeaponNativeAttachmentProjection.BuildCatalog(item,catalog,identity)
    return attachmentProjection(item,catalog,identity,false)
end
-- Client preflight against its trusted definition registry. A server bundle is
-- not permission to invoke arbitrary weapon hashes/points or fabricate ammo.
function WeaponCharacterAmmoMaterialization.Validate(plan,registry,baseline)
    if type(plan)~='table' or type(plan.identity)~='table' or type(plan.items)~='table'
        or type(registry)~='table' or type(registry.weapons)~='table' or type(baseline)~='table' then return nil,'invalid_creation_bundle' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if plan.identity[key]~=baseline[key] then return nil,'creation_identity_mismatch' end
    end
    local slots={primary=2,offhand=3,shoulder=10,back=9}
    local seen,ids,models={},{},{}
    local count=0
    for key,item in pairs(plan.items) do
        count=count+1
        if type(key)~='number' or key<1 or key%1~=0 or key>4 or type(item)~='table'
            or not slots[item.slot] or seen[item.slot] or slots[item.slot]~=item.point then return nil,'invalid_creation_slot' end
        local definition=registry.weapons[item.definitionId]
        if not definition or definition.nativeWeaponName~=item.nativeWeaponName
            or not definition.compatible[item.preferredAmmoType] then return nil,'untrusted_creation_definition' end
        -- Sawed-off is a catalog sidearm using shotgun ammo; family alone is
        -- not its carry category. Keep the exception exact, not all shotguns.
        local sidearm=definition.family=='pistol' or definition.family=='revolver'
            or (item.definitionId=='shotgun_sawedoff' and definition.family=='shotgun'
                and definition.nativeWeaponName=='WEAPON_SHOTGUN_SAWEDOFF')
        if sidearm~=(item.slot=='primary' or item.slot=='offhand') then return nil,'invalid_creation_category' end
        for _,field in ipairs({'itemInstanceId','itemRevision'}) do
            local value=item[field]
            if type(value)~='number' or value<0 or value%1~=0 or value==math.huge then return nil,'invalid_creation_item' end
        end
        if item.itemInstanceId==0 or ids[item.itemInstanceId] then return nil,'duplicate_creation_item' end
        if item.copyKey~=('%s:%s:%s'):format(item.slot,item.itemInstanceId,item.itemRevision) then return nil,'invalid_copy_key' end
        if type(item.attachments)~='table' or type(item.cosmetics)~='table' or next(item.cosmetics) then
            return nil,'creation_customization_not_implemented'
        end
        if next(item.attachments) then
            if not Config or Config.NativeAlphaRuntime~=true
                or not WeaponNativeEnrollment.Allows(Config,plan.identity.characterId) or type(GetConvarInt)~='function'
                or GetConvarInt('feather_native_saved_attachments',0)~=1 or GetConvarInt('feather_native_guid_ownership',1)~=1 then
                return nil,'creation_customization_not_implemented'
            end
            local projected,why=WeaponNativeAttachmentProjection.Build(item,WeaponDefinitionCatalog,plan.identity)
            if not projected then return nil,why end
        end
        seen[item.slot]=item; ids[item.itemInstanceId]=true
        models[item.nativeWeaponName]=(models[item.nativeWeaponName] or 0)+1
    end
    for index=1,count do if not plan.items[index] then return nil,'sparse_creation_items' end end
    if seen.offhand and not seen.primary then return nil,'primary_required_for_offhand' end
    local same=seen.primary and seen.offhand and seen.primary.nativeWeaponName==seen.offhand.nativeWeaponName or false
    if plan.dual~=(seen.offhand~=nil) or plan.sameModel~=same then return nil,'creation_pair_flags_mismatch' end
    for _,item in ipairs(plan.items) do
        local pair=same and (item.slot=='primary' or item.slot=='offhand')
        if pair and item.maintenance and item.maintenance.permanentDegradation~=0 then
            if not Config or Config.NativeAlphaRuntime~=true or type(GetConvarInt)~='function'
                or GetConvarInt('feather_native_guid_ownership',1)~=1 then return nil,'pair_permanent_guid_ownership_required' end
        end
        if models[item.nativeWeaponName]>1 and not pair then return nil,'unsupported_creation_duplicates' end
        if item.creation~=(pair and 'inventory_guid_pair' or 'native_zero_ammo_grant') then return nil,'invalid_creation_strategy' end
    end
    return true
end
local function clone(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=clone(x) end; return out
end
function WeaponCharacterAmmoMaterialization.Build(rows,catalog,registry,identity)
    if type(identity)~='table' then return nil,'invalid_materialization_identity' end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(identity[key])~='string' or #identity[key]<1 or #identity[key]>128 then
            return nil,'invalid_materialization_identity'
        end
    end
    local loadout,reason=WeaponCharacterAmmoItem.Loadout(rows,catalog,registry)
    if not loadout then return nil,reason end
    local plan={identity={characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch},
        dual=loadout.dual,sameModel=loadout.sameModel,items={}}
    for _,slot in ipairs({'primary','offhand','shoulder','back'}) do
        local item=loadout.slots[slot]
        if item then
            local entry=clone(item)
            entry.slot=slot
            -- Never use the model hash as copy identity. Native GUID/entity
            -- creation must return a distinct handle for each entry at execution.
            entry.copyKey=('%s:%s:%s'):format(slot,item.itemInstanceId,item.itemRevision)
            entry.creation=loadout.sameModel and (slot=='primary' or slot=='offhand')
                and 'inventory_guid_pair' or 'native_zero_ammo_grant'
            plan.items[#plan.items+1]=entry
        end
    end
    -- No ammo totals, clips, selected-type writes, give-ammo amounts or handles.
    -- preferredAmmoType is retained as data, not a native creation instruction.
    return plan
end
