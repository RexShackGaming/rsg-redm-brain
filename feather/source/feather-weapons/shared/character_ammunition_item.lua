-- Strict new firearm item contract. No legacy import, ammo repair or credits.
WeaponCharacterAmmoItem={}
local function clone(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=clone(x) end; return out
end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function WeaponCharacterAmmoItem.Validate(metadata,definition)
    local families={pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true}
    if type(definition)~='table' or not families[definition.family]
        or definition.nativeWeaponName=='WEAPON_REVOLVER_LEMAT' then return nil,'unsupported_native_firearm' end
    if type(metadata)~='table' or type(metadata.ammo)~='table'
        or metadata.ammo.ownership~='character' then return nil,'character_ammo_ownership_required' end
    for key in pairs(metadata.ammo) do
        if key~='ownership' and key~='type' then return nil,'item_ammunition_quantity_forbidden' end
    end
    if type(metadata.ammo.type)~='string' or not WeaponValidation.AcceptsAmmunition(definition,metadata.ammo.type) then
        return nil,'incompatible_ammunition_type'
    end
    if not finite(metadata.condition) or type(metadata.maintenance)~='table' then return nil,'invalid_condition' end
    for _,key in ipairs({'degradation','permanentDegradation','damage','dirt','soot'}) do
        if not finite(metadata.maintenance[key]) then return nil,'invalid_maintenance' end
    end
    -- Reuse identity/condition/attachment-shape/cosmetic/flag validation on a
    -- private zero-ammo view. No fabricated projection is saved or transmitted.
    local view=clone(metadata)
    view.ammo={type=metadata.ammo.type,loaded=0,reserve=0,chambered=false}
    local valid,errors=WeaponValidation.Metadata(view,definition)
    if not valid then return nil,'invalid_weapon_metadata',errors end
    return clone(metadata)
end
function WeaponCharacterAmmoItem.Loadout(rows,catalog,registry)
    if type(rows)~='table' or type(catalog)~='table' or type(registry)~='table' then return nil,'invalid_loadout' end
    local points={primary=2,offhand=3,shoulder=10,back=9}
    local order={'primary','offhand','shoulder','back'}
    local seen,hashes,out={},{},{slots={},dual=false,sameModel=false}
    for key in pairs(rows) do if not points[key] then return nil,'unsupported_firearm_slot' end end
    for _,slot in ipairs(order) do
        local row=rows[slot]
        if row then
            if type(row)~='table' or type(row.id)~='number' or row.id<1 or row.id%1~=0 or row.id==math.huge
                or type(row.revision)~='number' or row.revision<0 or row.revision%1~=0 or row.revision==math.huge
                or seen[row.id] then return nil,'invalid_or_duplicate_item' end
            local id=type(row.metadata)=='table' and row.metadata.weaponDefinitionId
            local definition=id and catalog.weapons and catalog.weapons[id]
            local registered=id and registry.weapons and registry.weapons[id]
            if not registered or not definition or row.itemName~=definition.itemName then return nil,'unregistered_firearm' end
            if (slot=='primary' or slot=='offhand')~=(definition.slot=='sidearm') then return nil,'invalid_slot_category' end
            local metadata,reason=WeaponCharacterAmmoItem.Validate(row.metadata,definition)
            if not metadata then return nil,reason end
            if metadata.flags.disabled or metadata.flags.evidence or metadata.condition<definition.condition.equipMinimum then
                return nil,'weapon_not_equippable'
            end
            local other=hashes[definition.nativeWeaponName]
            if other and not (other=='primary' and slot=='offhand') then return nil,'unsupported_same_model_pair' end
            if other then out.sameModel=true end
            seen[row.id]=true; hashes[definition.nativeWeaponName]=slot
            out.slots[slot]={itemInstanceId=row.id,itemRevision=row.revision,definitionId=id,
                nativeWeaponName=definition.nativeWeaponName,point=points[slot],serialNumber=metadata.serialNumber,
                condition=metadata.condition,maintenance=metadata.maintenance,attachments=metadata.attachments,
                cosmetics=metadata.cosmetics,preferredAmmoType=metadata.ammo.type}
        end
    end
    out.dual=out.slots.offhand~=nil
    if out.dual and not out.slots.primary then return nil,'primary_required_for_offhand' end
    return out
end
