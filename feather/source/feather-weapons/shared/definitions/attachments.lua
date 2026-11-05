WeaponDefinitionCatalog = WeaponDefinitionCatalog or {}

-- Each attachment defines: id, itemName, label, slot,
-- nativeComponentName, conflicts, prerequisites, removable, and optional tags.
WeaponDefinitionCatalog.attachments = {
    cattleman_long_barrel = {
        id = "cattleman_long_barrel",
        kind = "attachment",
        itemName = "cattleman_long_barrel",
        label = "Cattleman Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "cattleman" }
    },
    cattleman_wide_sight = {
        id = "cattleman_wide_sight",
        kind = "attachment",
        itemName = "cattleman_wide_sight",
        label = "Cattleman Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REVOLVER_CATTLEMAN_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "cattleman" }
    },
    schofield_short_barrel = {
        id = "schofield_short_barrel",
        kind = "attachment",
        itemName = "schofield_short_barrel",
        label = "Schofield Short Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_REVOLVER_SCHOFIELD_BARREL_SHORT",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "schofield" }
    },
    schofield_wide_sight = {
        id = "schofield_wide_sight",
        kind = "attachment",
        itemName = "schofield_wide_sight",
        label = "Schofield Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REVOLVER_SCHOFIELD_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "schofield" }
    },
    lemat_long_barrel = {
        id = "lemat_long_barrel",
        kind = "attachment",
        itemName = "lemat_long_barrel",
        label = "LeMat Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_REVOLVER_LEMAT_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "lemat" }
    },
    lemat_wide_sight = {
        id = "lemat_wide_sight",
        kind = "attachment",
        itemName = "lemat_wide_sight",
        label = "LeMat Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REVOLVER_LEMAT_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "lemat" }
    },
    navy_long_barrel = {
        id = "navy_long_barrel",
        kind = "attachment",
        itemName = "navy_long_barrel",
        label = "Navy Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_REVOLVER_NAVY_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "navy" }
    },
    navy_wide_sight = {
        id = "navy_wide_sight",
        kind = "attachment",
        itemName = "navy_wide_sight",
        label = "Navy Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REVOLVER_NAVY_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "navy" }
    },
    doubleaction_long_barrel = {
        id = "doubleaction_long_barrel",
        kind = "attachment",
        itemName = "doubleaction_long_barrel",
        label = "Double-Action Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_REVOLVER_DOUBLEACTION_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "doubleaction" }
    },
    doubleaction_wide_sight = {
        id = "doubleaction_wide_sight",
        kind = "attachment",
        itemName = "doubleaction_wide_sight",
        label = "Double-Action Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "doubleaction" }
    },
    m1899_long_barrel = {
        id = "m1899_long_barrel",
        kind = "attachment",
        itemName = "m1899_long_barrel",
        label = "M1899 Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_PISTOL_M1899_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "m1899" }
    },
    m1899_wide_sight = {
        id = "m1899_wide_sight",
        kind = "attachment",
        itemName = "m1899_wide_sight",
        label = "M1899 Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_PISTOL_M1899_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "m1899" }
    },
    volcanic_long_barrel = {
        id = "volcanic_long_barrel",
        kind = "attachment",
        itemName = "volcanic_long_barrel",
        label = "Volcanic Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_PISTOL_VOLCANIC_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "volcanic" }
    },
    volcanic_wide_sight = {
        id = "volcanic_wide_sight",
        kind = "attachment",
        itemName = "volcanic_wide_sight",
        label = "Volcanic Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_PISTOL_VOLCANIC_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "volcanic" }
    },
    semiauto_long_barrel = {
        id = "semiauto_long_barrel",
        kind = "attachment",
        itemName = "semiauto_long_barrel",
        label = "Semi-Automatic Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_PISTOL_SEMIAUTO_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "semiauto" }
    },
    semiauto_wide_sight = {
        id = "semiauto_wide_sight",
        kind = "attachment",
        itemName = "semiauto_wide_sight",
        label = "Semi-Automatic Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_PISTOL_SEMIAUTO_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "semiauto" }
    },
    mauser_long_barrel = {
        id = "mauser_long_barrel",
        kind = "attachment",
        itemName = "mauser_long_barrel",
        label = "Mauser Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_PISTOL_MAUSER_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "mauser" }
    },
    mauser_wide_sight = {
        id = "mauser_wide_sight",
        kind = "attachment",
        itemName = "mauser_wide_sight",
        label = "Mauser Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_PISTOL_MAUSER_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "mauser" }
    },
    carbine_wide_sight = {
        id = "carbine_wide_sight",
        kind = "attachment",
        itemName = "carbine_wide_sight",
        label = "Carbine Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REPEATER_CARBINE_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "carbine" }
    },
    lancaster_wide_sight = {
        id = "lancaster_wide_sight",
        kind = "attachment",
        itemName = "lancaster_wide_sight",
        label = "Lancaster Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REPEATER_WINCHESTER_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "lancaster" }
    },
    litchfield_wide_sight = {
        id = "litchfield_wide_sight",
        kind = "attachment",
        itemName = "litchfield_wide_sight",
        label = "Litchfield Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REPEATER_HENRY_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "litchfield" }
    },
    evans_wide_sight = {
        id = "evans_wide_sight",
        kind = "attachment",
        itemName = "evans_wide_sight",
        label = "Evans Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REPEATER_EVANS_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "evans" }
    },
    springfield_wide_sight = {
        id = "springfield_wide_sight",
        kind = "attachment",
        itemName = "springfield_wide_sight",
        label = "Springfield Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_RIFLE_SPRINGFIELD_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "springfield" }
    },
    boltaction_wide_sight = {
        id = "boltaction_wide_sight",
        kind = "attachment",
        itemName = "boltaction_wide_sight",
        label = "Bolt Action Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_RIFLE_BOLTACTION_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "boltaction" }
    },
    varmint_wide_sight = {
        id = "varmint_wide_sight",
        kind = "attachment",
        itemName = "varmint_wide_sight",
        label = "Varmint Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_REPEATER_PUMPACTION_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "varmint" }
    },
    elephant_long_barrel = {
        id = "elephant_long_barrel",
        kind = "attachment",
        itemName = "elephant_long_barrel",
        label = "Elephant Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_RIFLE_ELEPHANT_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "elephant" }
    },
    elephant_wide_sight = {
        id = "elephant_wide_sight",
        kind = "attachment",
        itemName = "elephant_wide_sight",
        label = "Elephant Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_RIFLE_ELEPHANT_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "elephant" }
    },
    rollingblock_wide_sight = {
        id = "rollingblock_wide_sight",
        kind = "attachment",
        itemName = "rollingblock_wide_sight",
        label = "Rolling Block Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "rollingblock" }
    },
    carcano_wide_sight = {
        id = "carcano_wide_sight",
        kind = "attachment",
        itemName = "carcano_wide_sight",
        label = "Carcano Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_RIFLE_CARCANO_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "carcano" }
    },
    repeating_shotgun_long_barrel = {
        id = "repeating_shotgun_long_barrel",
        kind = "attachment",
        itemName = "repeating_shotgun_long_barrel",
        label = "Repeating Shotgun Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_SHOTGUN_REPEATING_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "repeating_shotgun" }
    },
    repeating_shotgun_wide_sight = {
        id = "repeating_shotgun_wide_sight",
        kind = "attachment",
        itemName = "repeating_shotgun_wide_sight",
        label = "Repeating Shotgun Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_SHOTGUN_REPEATING_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "repeating_shotgun" }
    },
    pump_shotgun_long_barrel = {
        id = "pump_shotgun_long_barrel",
        kind = "attachment",
        itemName = "pump_shotgun_long_barrel",
        label = "Pump-Action Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_SHOTGUN_PUMP_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "pump_shotgun" }
    },
    pump_shotgun_wide_sight = {
        id = "pump_shotgun_wide_sight",
        kind = "attachment",
        itemName = "pump_shotgun_wide_sight",
        label = "Pump-Action Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_SHOTGUN_PUMP_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "pump_shotgun" }
    },
    semiauto_shotgun_long_barrel = {
        id = "semiauto_shotgun_long_barrel",
        kind = "attachment",
        itemName = "semiauto_shotgun_long_barrel",
        label = "Semi-Auto Shotgun Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_SHOTGUN_SEMIAUTO_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "semiauto_shotgun" }
    },
    semiauto_shotgun_wide_sight = {
        id = "semiauto_shotgun_wide_sight",
        kind = "attachment",
        itemName = "semiauto_shotgun_wide_sight",
        label = "Semi-Auto Shotgun Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "semiauto_shotgun" }
    },
    doublebarrel_long_barrel = {
        id = "doublebarrel_long_barrel",
        kind = "attachment",
        itemName = "doublebarrel_long_barrel",
        label = "Double-Barreled Long Barrel",
        slot = "barrel",
        nativeComponentName = "COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_LONG",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "doublebarrel" }
    },
    doublebarrel_wide_sight = {
        id = "doublebarrel_wide_sight",
        kind = "attachment",
        itemName = "doublebarrel_wide_sight",
        label = "Double-Barreled Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "doublebarrel" }
    },
    sawedoff_wide_sight = {
        id = "sawedoff_wide_sight",
        kind = "attachment",
        itemName = "sawedoff_wide_sight",
        label = "Sawed-Off Wide Sight",
        slot = "sight",
        nativeComponentName = "COMPONENT_SHOTGUN_SAWED_SIGHT_WIDE",
        conflicts = {},
        prerequisites = {},
        removable = true,
        tags = { "functional", "sawedoff" }
    }
}

-- Live native itemdatabase slot discovery: 38 catalog pairs / 24 models.
-- Compatibility evidence is NOT permission to reconstruct an unproved child.
WeaponNativeAttachmentMappings={}
local observed={
    m1899_long_barrel={'pistol_m1899',1402841185},m1899_wide_sight={'pistol_m1899',-363896735},
    mauser_long_barrel={'pistol_mauser',-468790222},mauser_wide_sight={'pistol_mauser',1755095401},
    semiauto_long_barrel={'pistol_semiauto',835771095},semiauto_wide_sight={'pistol_semiauto',1299075397},
    volcanic_long_barrel={'pistol_volcanic',-1509094230},volcanic_wide_sight={'pistol_volcanic',288484254},
    carbine_wide_sight={'repeater_carbine',468034421},evans_wide_sight={'repeater_evans',1219701681},
    litchfield_wide_sight={'repeater_henry',907446160},lancaster_wide_sight={'repeater_lancaster',-1177461517},
    cattleman_long_barrel={'revolver_cattleman',1024262875},cattleman_wide_sight={'revolver_cattleman',361381308},
    doubleaction_long_barrel={'revolver_doubleaction',-1264898804},doubleaction_wide_sight={'revolver_doubleaction',-948489286},
    lemat_long_barrel={'revolver_lemat',-1959697839},lemat_wide_sight={'revolver_lemat',-1410062763},
    navy_long_barrel={'revolver_navy',-1628873469},navy_wide_sight={'revolver_navy',1713542477},
    schofield_short_barrel={'revolver_schofield',1985390213},schofield_wide_sight={'revolver_schofield',1880805647},
    boltaction_wide_sight={'rifle_boltaction',196214097},carcano_wide_sight={'rifle_carcano',-201958220},
    elephant_long_barrel={'rifle_elephant',244353594},elephant_wide_sight={'rifle_elephant',257892944},
    rollingblock_wide_sight={'rifle_rollingblock',1400281261},springfield_wide_sight={'rifle_springfield',-940704970},
    varmint_wide_sight={'rifle_varmint',1261891225},doublebarrel_long_barrel={'shotgun_doublebarrel',-1794417972},
    doublebarrel_wide_sight={'shotgun_doublebarrel',860052020},pump_shotgun_long_barrel={'shotgun_pump',1670843243},
    pump_shotgun_wide_sight={'shotgun_pump',899615863},repeating_shotgun_long_barrel={'shotgun_repeating',-298901850},
    repeating_shotgun_wide_sight={'shotgun_repeating',-817206030},sawedoff_wide_sight={'shotgun_sawedoff',-247466821},
    semiauto_shotgun_long_barrel={'shotgun_semiauto',-722462870},semiauto_shotgun_wide_sight={'shotgun_semiauto',-339438116},
}
-- Freeze the trusted component fields corresponding to the observed slot list.
for id,row in pairs(observed) do
    local definition=WeaponDefinitionCatalog.attachments[id]
    row.component=definition.nativeComponentName; row.slot=definition.slot; row.itemName=definition.itemName
end
local function scopedFlag(name)
    return Config and Config.DevMode==true and Config.NativeAlphaRuntime==true
        and WeaponNativeEnrollment.Validate(Config)~=nil
        and type(GetConvarInt)=='function' and GetConvarInt(name,0)==1
end
local function representativeEnabled() return scopedFlag('feather_native_representative_attachments') end
local modelOverrides={repeater_lancaster='WEAPON_REPEATER_WINCHESTER',
    rifle_rollingblock='WEAPON_SNIPERRIFLE_ROLLINGBLOCK',rifle_carcano='WEAPON_SNIPERRIFLE_CARCANO'}
local function observedModel(id) return modelOverrides[id] or ('WEAPON_'..id:upper()) end
local rolloutExcluded={revolver_lemat=true} -- dual-ammo remains a separate policy
function WeaponNativeAttachmentMappings.CaptureModel(name)
    if name=='WEAPON_REPEATER_CARBINE' or (representativeEnabled() and name=='WEAPON_REVOLVER_SCHOFIELD') then return true end
    if scopedFlag('feather_native_catalog_attachments') then
        for _,row in pairs(observed) do
            if not rolloutExcluded[row[1]] and name==observedModel(row[1]) then return true end
        end
    end
    return false
end
function WeaponNativeAttachmentMappings.Resolve(weapon,attachment,requireReconstruction)
    if type(weapon)~='table' or type(attachment)~='table' then return nil,'native_attachment_mapping_invalid' end
    local row=observed[attachment.id]
    if not row or row[1]~=weapon.id then return nil,'native_attachment_mapping_unknown' end
    if weapon.nativeWeaponName~=observedModel(row[1]) or attachment.nativeComponentName~=row.component
        or attachment.slot~=row.slot or attachment.itemName~=row.itemName then return nil,'native_attachment_mapping_changed' end
    local compatible=false
    for _,id in ipairs(weapon.attachmentSlots and weapon.attachmentSlots[attachment.slot] or {}) do
        if id==attachment.id then compatible=true end
    end
    if not compatible then return nil,'attachment_incompatible' end
    local proved=weapon.id=='repeater_carbine' and weapon.nativeWeaponName=='WEAPON_REPEATER_CARBINE'
        and attachment.id=='carbine_wide_sight' and attachment.itemName=='carbine_wide_sight'
        and attachment.slot=='sight' and attachment.nativeComponentName=='COMPONENT_REPEATER_CARBINE_SIGHT_WIDE'
    local representative=representativeEnabled() and weapon.id=='revolver_schofield'
        and weapon.nativeWeaponName=='WEAPON_REVOLVER_SCHOFIELD' and attachment.itemName==attachment.id
        and ((attachment.id=='schofield_wide_sight' and attachment.slot=='sight'
            and attachment.nativeComponentName=='COMPONENT_REVOLVER_SCHOFIELD_SIGHT_WIDE')
        or (attachment.id=='schofield_short_barrel' and attachment.slot=='barrel'
            and attachment.nativeComponentName=='COMPONENT_REVOLVER_SCHOFIELD_BARREL_SHORT'))
    local rollout=scopedFlag('feather_native_catalog_attachments') and not rolloutExcluded[weapon.id]
    if requireReconstruction and not proved and not representative and not rollout then return nil,'native_attachment_not_proved' end
    return {weaponId=weapon.id,attachmentId=attachment.id,nativeSlot=row[2],slot=attachment.slot,
        nativeWeaponName=weapon.nativeWeaponName,nativeComponentName=attachment.nativeComponentName,
        reconstructionProved=proved,representative=representative==true,catalogRollout=rollout==true,
        stockComponentName=proved and 'COMPONENT_REPEATER_CARBINE_SIGHT_NARROW' or nil}
end
-- Shared catalog policy for a complete saved set, not just one chosen delta.
function WeaponNativeAttachmentMappings.ValidateSet(weapon,saved,requireReconstruction)
    if type(saved)~='table' then return nil,'attachment_set_invalid' end
    local count,present,slots=0,{},{}
    for index,entry in pairs(saved) do
        if type(index)~='number' or index%1~=0 or index<1 or index>4 or type(entry)~='table'
            or type(entry.definitionId)~='string' or type(entry.slot)~='string'
            or present[entry.definitionId] or slots[entry.slot] then return nil,'attachment_set_invalid' end
        for key in pairs(entry) do if key~='definitionId' and key~='slot' then return nil,'attachment_saved_instruction_invalid' end end
        local definition=WeaponDefinitionCatalog.attachments[entry.definitionId]
        if not definition or entry.slot~=definition.slot or not WeaponNativeAttachmentMappings.Resolve(weapon,definition,requireReconstruction) then
            return nil,'attachment_set_incompatible'
        end
        present[entry.definitionId]=true; slots[entry.slot]=true; count=count+1
    end
    for index=1,count do if not saved[index] then return nil,'attachment_set_sparse' end end
    for id in pairs(present) do
        local definition=WeaponDefinitionCatalog.attachments[id]
        if type(definition.conflicts)~='table' or type(definition.prerequisites)~='table' then return nil,'attachment_policy_invalid' end
        for _,conflict in ipairs(definition.conflicts) do
            if present[conflict] then return nil,'attachment_conflict' end
        end
        for _,prerequisite in ipairs(definition.prerequisites) do
            if not present[prerequisite] then return nil,'attachment_prerequisite_missing' end
        end
    end
    return true
end
