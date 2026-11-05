-- Reuse the five previously accepted melee models/slots. Pure policy;
-- manifest loading alone never grants gameplay admission.
WeaponNativeMeleeCatalog={}
function WeaponNativeMeleeCatalog.Enabled()
    return Config and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
        and Config.NativeAlphaLifecycleWearEnabled==true and type(GetConvarInt)=='function'
        and GetConvarInt('feather_native_melee',0)==1 or false
end
local profiles={
    melee_knife={itemName='weapon_melee_knife',nativeWeaponName='WEAPON_MELEE_KNIFE',family='knife',nativeGrantAmount=0},
    melee_machete={itemName='weapon_melee_machete',nativeWeaponName='WEAPON_MELEE_MACHETE',family='machete',nativeGrantAmount=0},
    melee_hammer={itemName='weapon_melee_hammer',nativeWeaponName='WEAPON_MELEE_HAMMER',family='hammer',nativeGrantAmount=0},
    melee_cleaver={itemName='weapon_melee_cleaver',nativeWeaponName='WEAPON_MELEE_CLEAVER',family='cleaver',nativeGrantAmount=1},
    melee_hatchet={itemName='weapon_melee_hatchet',nativeWeaponName='WEAPON_MELEE_HATCHET',family='hatchet',nativeGrantAmount=1},
}
local order={'melee','melee_secondary','melee_tertiary','melee_quaternary','melee_quinary'}
local function copy(v)
    if type(v)~='table' then return v end
    local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r
end
function WeaponNativeMeleeCatalog.Resolve(def)
    local expected=type(def)=='table' and profiles[def.id]
    if not expected or def.itemName~=expected.itemName or def.nativeWeaponName~=expected.nativeWeaponName
        or def.family~=expected.family or def.slot~='melee' or def.usesAmmunition~=false or def.capacity~=0
        or type(def.ammunitionTypes)~='table' or next(def.ammunitionTypes)~=nil or def.ammunitionType~=nil
        or (def.nativeGrantAmount~=nil and def.nativeGrantAmount~=expected.nativeGrantAmount)
        or (def.nativeGrantAmount or 0)~=expected.nativeGrantAmount
        or type(def.condition)~='table' or def.condition.minimum~=0 or def.condition.maximum~=100
        or def.condition.equipMinimum~=1 then return nil,'unsupported_native_melee_definition' end
    local result=copy(expected); result.id=def.id; return result
end
function WeaponNativeMeleeCatalog.Slots()
    local result={}; for _,slot in ipairs(order) do result[slot]='weapon_'..slot end; return result
end
function WeaponNativeMeleeCatalog.Project(snapshot,catalog,identity)
    if type(snapshot)~='table' or type(catalog)~='table' or type(catalog.weapons)~='table'
        or type(identity)~='table' or snapshot.characterId~=identity.characterId
        or type(snapshot.expected)~='table' or type(snapshot.equipment)~='table' then return nil,'melee_snapshot_required' end
    local bound={}
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        local v=identity[key]
        if type(v)~='string' or #v<1 or #v>128 or v:find('%c') then return nil,'melee_identity_required' end
        bound[key]=v
    end
    local ids={}
    for _,entry in pairs(snapshot.expected) do
        if type(entry)~='table' or type(entry.itemId)~='number' or entry.itemId<1 or entry.itemId%1~=0
            or entry.itemId==math.huge or ids[entry.itemId] then return nil,'melee_duplicate_or_invalid_assignment' end
        ids[entry.itemId]=true
    end
    local out={identity=bound,items={}}
    local models={}
    for _,slot in ipairs(order) do
        local dbSlot='weapon_'..slot
        local row,expected=snapshot.equipment[slot],snapshot.expected[dbSlot]
        if row~=nil or expected~=nil then
            if type(row)~='table' or type(expected)~='table' or row.id~=expected.itemId
                or row.revision~=expected.revision then return nil,'melee_assignment_changed' end
            local def=type(row.metadata)=='table' and catalog.weapons[row.metadata.weaponDefinitionId]
            local profile=WeaponNativeMeleeCatalog.Resolve(def)
            if not profile then return nil,'unsupported_native_melee_definition' end
            local projected,why=WeaponNativeKnife.Project(row,def,bound)
            if not projected then return nil,why end
            if models[profile.nativeWeaponName] then return nil,'same_model_melee_not_supported' end
            models[profile.nativeWeaponName]=true
            out.items[#out.items+1]={slot=slot,equipmentSlot=dbSlot,row=copy(row),projection=projected}
        end
    end
    return out -- data only; no native grants/points/ammunition instruction
end
-- Rebuild rather than trusting serialized projections or caller-selected hashes.
function WeaponNativeMeleeCatalog.ValidateApproval(approval,catalog,identity)
    if type(approval)~='table' or getmetatable(approval)~=nil or type(approval.items)~='table'
        or getmetatable(approval.items)~=nil or type(approval.identity)~='table' then return nil,'melee_approval_required' end
    for key in pairs(approval) do
        if key~='identity' and key~='items' then return nil,'melee_approval_required' end
    end
    for key in pairs(approval.identity) do
        if key~='characterId' and key~='sessionId' and key~='epoch' then return nil,'melee_identity_required' end
    end
    for _,key in ipairs({'characterId','sessionId','epoch'}) do
        if type(identity)~='table' or approval.identity[key]~=identity[key] then return nil,'melee_approval_world_changed' end
    end
    local snapshot={characterId=identity.characterId,expected={},equipment={}}
    local count=0
    for key,entry in pairs(approval.items) do
        if type(key)~='number' or key%1~=0 or key<1 or key>5 or type(entry)~='table'
            or getmetatable(entry)~=nil then return nil,'melee_approval_items_required' end
        for field in pairs(entry) do
            if field~='slot' and field~='equipmentSlot' and field~='row' and field~='projection' then return nil,'melee_approval_items_required' end
        end
        if type(entry.slot)~='string' or not WeaponNativeMeleeCatalog.Slots()[entry.slot]
            or WeaponNativeMeleeCatalog.Slots()[entry.slot]~=entry.equipmentSlot or snapshot.equipment[entry.slot]
            or type(entry.row)~='table' then return nil,'melee_approval_assignment_changed' end
        snapshot.equipment[entry.slot]=entry.row
        snapshot.expected[entry.equipmentSlot]={itemId=entry.row.id,revision=entry.row.revision}
        count=count+1
    end
    if count~=#approval.items then return nil,'melee_approval_items_required' end
    local rebuilt,why=WeaponNativeMeleeCatalog.Project(snapshot,catalog,approval.identity)
    if not rebuilt then return nil,why end
    local function equal(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        if getmetatable(a) or getmetatable(b) then return false end
        for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    if not equal(rebuilt,approval) then return nil,'melee_approval_content_changed' end
    return rebuilt
end
function WeaponNativeMeleeCatalog.Prepare(snapshot,catalog,identity,intent)
    local slots=WeaponNativeMeleeCatalog.Slots()
    local logical
    if type(intent)=='table' then for key,db in pairs(slots) do if db==intent.slot then logical=key end end end
    if not logical or (intent.action~='equip' and intent.action~='unequip')
        or type(snapshot)~='table' or type(identity)~='table' or snapshot.characterId~=identity.characterId
        or type(snapshot.expected)~='table' or type(snapshot.equipment)~='table'
        or type(snapshot.meleeEquipment)~='table' then return nil,'melee_transition_snapshot_required' end
    local approval,why=WeaponNativeMeleeCatalog.Project(snapshot.meleeEquipment,catalog,identity)
    if not approval then return nil,why end
    local function same(a,b)
        if type(a)~=type(b) then return false end
        if type(a)~='table' then return a==b end
        for k,v in pairs(a) do if not same(v,b[k]) then return false end end
        for k in pairs(b) do if a[k]==nil then return false end end
        return true
    end
    if not same(snapshot.expected,snapshot.meleeEquipment.expected) then return nil,'melee_full_snapshot_changed' end
    local row
    if intent.action=='equip' then
        row=snapshot.candidate
        if type(row)~='table' or intent.itemId~=row.id then return nil,'melee_owned_candidate_required' end
        local def=type(row.metadata)=='table' and catalog.weapons[row.metadata.weaponDefinitionId]
        local projected,reason=WeaponNativeKnife.Project(row,def,approval.identity)
        if not projected then return nil,reason end
        for _,entry in pairs(snapshot.expected) do
            if entry.itemId==row.id then return nil,'melee_already_equipped' end
        end
        for _,entry in ipairs(approval.items) do
            if entry.slot~=logical and entry.projection.nativeWeaponName==projected.nativeWeaponName then
                return nil,'same_model_melee_not_supported'
            end
        end
    else
        for _,entry in ipairs(approval.items) do if entry.slot==logical then row=entry.row end end
        if not row or intent.itemId~=nil or (intent.selectedItemId~=nil and intent.selectedItemId~=row.id) then
            return nil,'melee_selected_assignment_changed'
        end
    end
    return {characterId=identity.characterId,action=intent.action,slot=intent.slot,melee=true,
        knifeId=row.id,knifeRevision=row.revision,before=copy(row.metadata),expected=copy(snapshot.expected),
        lifecycleSnapshot=copy(snapshot.equipment),brokenEquipmentContract=snapshot.brokenEquipmentContract,
        brokenPromotionContract=snapshot.brokenPromotionContract}
end
