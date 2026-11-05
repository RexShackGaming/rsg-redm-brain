-- Staged family policy only; NOT manifest-loaded or runtime admission.
-- Original tested wheel behavior requires explicit unequip before switching.
WeaponNativeLassoPolicy={}
local P=WeaponNativeLassoPolicy
local profiles={
    utility_lasso={itemName='weapon_lasso',nativeWeaponName='WEAPON_LASSO'},
    utility_lasso_reinforced={itemName='weapon_lasso_reinforced',nativeWeaponName='WEAPON_LASSO_REINFORCED'},
}
local order={'utility','utility_secondary','utility_tertiary','utility_quaternary',
    'utility_quinary','utility_senary','utility_septenary','utility_octonary'}
function P.Resolve(def)
    local p=type(def)=='table' and profiles[def.id]
    if not p or def.kind~='weapon' or def.itemName~=p.itemName or def.nativeWeaponName~=p.nativeWeaponName
        or def.family~='lasso' or def.slot~='utility' or def.usesAmmunition~=false or def.capacity~=0
        or def.multiTypeAmmunition==true
        or def.ammunitionType~=nil or type(def.ammunitionTypes)~='table' or next(def.ammunitionTypes)~=nil
        or (def.nativeGrantAmount~=nil and def.nativeGrantAmount~=0)
        or type(def.condition)~='table' or def.condition.minimum~=0 or def.condition.maximum~=100
        or def.condition.equipMinimum~=1 or type(def.policies)~='table' or def.policies.serialRequired~=true
        or type(def.attachmentSlots)~='table' or next(def.attachmentSlots)~=nil
        or type(def.attachmentDefaults)~='table' or next(def.attachmentDefaults)~=nil then
        return nil,'unsupported_native_lasso_definition'
    end
    return {id=def.id,itemName=p.itemName,nativeWeaponName=p.nativeWeaponName,usesAmmunition=false,nativeGrantAmount=0}
end
-- Caller supplies a trusted owned snapshot; this checks family coexistence only,
-- not metadata/session/Inventory ownership or permission to create a native copy.
function P.ValidateAssignments(equipment,catalog)
    if type(equipment)~='table' or type(catalog)~='table' or type(catalog.weapons)~='table' then
        return nil,'lasso_assignments_required'
    end
    local selected,seen=nil,{}
    for _,slot in ipairs(order) do
        seen[slot]=true
        local row=equipment[slot]
        if row~=nil then
            local def=type(row)=='table' and type(row.metadata)=='table' and catalog.weapons[row.metadata.weaponDefinitionId]
            if not def then return nil,'utility_definition_required' end
            if def.family=='lasso' then
                local profile,why=P.Resolve(def)
                if not profile or row.itemName~=profile.itemName then return nil,why or 'lasso_item_mismatch' end
                if selected then return nil,'one_equipped_lasso_required' end
                selected={slot=slot,equipmentSlot='weapon_'..slot,definitionId=profile.id}
            end
        end
    end
    for slot in pairs(equipment) do if not seen[slot] then return nil,'unsupported_utility_slot' end end
    return selected or false -- no reconciliation/deletion of conflicting items
end
