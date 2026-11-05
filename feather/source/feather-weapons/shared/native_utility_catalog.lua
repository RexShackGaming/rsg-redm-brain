-- Explicit utility profiles. Manifest loading alone does not enable admission.
-- Catalog presence is not permission to grant, equip or adopt a native copy.
WeaponNativeUtilityCatalog={}
function WeaponNativeUtilityCatalog.Enabled()
    return Config and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
        and Config.NativeAlphaLifecycleWearEnabled==true and type(GetConvarInt)=='function'
        and GetConvarInt('feather_native_utility',0)==1 or false
end
function WeaponNativeUtilityCatalog.Resolve(def)
    if type(def)=='table' and def.id=='utility_fishing_rod' then
        if not WeaponNativeUtilityCatalog.FishingRodEnabled() then return nil,'native_fishing_rod_disabled' end
        return WeaponNativeFishingRodPolicy.Resolve(def)
    end
    if type(def)=='table' and def.id=='utility_metal_detector' then
        if not WeaponNativeUtilityCatalog.MetalDetectorEnabled() then return nil,'native_metal_detector_disabled' end
        return WeaponNativeMetalDetectorPolicy.Resolve(def)
    end
    if type(def)=='table' and def.id=='utility_binoculars_improved' then
        if not WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() then return nil,'native_improved_binoculars_disabled' end
        return WeaponNativeImprovedBinocularsPolicy.Resolve(def)
    end
    if type(def)=='table' and def.id=='utility_camera_advanced' then
        if not WeaponNativeUtilityCatalog.AdvancedCameraEnabled() then return nil,'native_advanced_camera_disabled' end
        return WeaponNativeAdvancedCameraPolicy.Resolve(def)
    end
    if type(def)=='table' and def.id=='utility_camera' then
        if not WeaponNativeUtilityCatalog.CameraEnabled() then return nil,'native_camera_disabled' end
        return WeaponNativeCameraPolicy.Resolve(def)
    end
    if type(def)=='table' and def.id=='utility_binoculars' then
        if not WeaponNativeUtilityCatalog.BinocularsEnabled() then return nil,'native_binoculars_disabled' end
        return WeaponNativeBinocularsPolicy.Resolve(def)
    end
    if type(def)=='table' and def.id=='utility_davy_lantern' then
        if not WeaponNativeUtilityCatalog.DavyEnabled() then return nil,'native_davy_lantern_disabled' end
        return WeaponNativeDavyLanternPolicy.Resolve(def)
    end
    if type(def)=='table' and def.id=='utility_lasso_reinforced' then
        if not WeaponNativeLassoPolicy or not WeaponNativeUtilityCatalog.Enabled()
            or GetConvarInt('feather_native_lasso_reinforced',0)~=1 then return nil,'native_reinforced_lasso_disabled' end
        local profile,why=WeaponNativeLassoPolicy.Resolve(def)
        if not profile then return nil,why end
        profile.family='lasso'; profile.slot='utility'; profile.equipmentSlot='weapon_utility_secondary'
        return profile
    end
    if type(def)~='table' or def.id~='utility_lasso' or def.kind~='weapon'
        or def.itemName~='weapon_lasso' or def.nativeWeaponName~='WEAPON_LASSO'
        or def.family~='lasso' or def.slot~='utility' or def.usesAmmunition~=false
        or def.capacity~=0 or def.ammunitionType~=nil or def.multiTypeAmmunition==true
        or type(def.ammunitionTypes)~='table' or next(def.ammunitionTypes)~=nil
        or (def.nativeGrantAmount~=nil and def.nativeGrantAmount~=0)
        or type(def.condition)~='table' or def.condition.minimum~=0
        or def.condition.maximum~=100 or def.condition.equipMinimum~=1
        or type(def.attachmentSlots)~='table' or next(def.attachmentSlots)~=nil
        or type(def.attachmentDefaults)~='table' or next(def.attachmentDefaults)~=nil
        or type(def.policies)~='table' or def.policies.serialRequired~=true then
        return nil,'unsupported_native_utility_definition'
    end
    return {id='utility_lasso',itemName='weapon_lasso',nativeWeaponName='WEAPON_LASSO',
        family='lasso',slot='utility',equipmentSlot='weapon_utility',usesAmmunition=false,
        nativeGrantAmount=0}
end
function WeaponNativeUtilityCatalog.ReinforcedEnabled()
    return WeaponNativeLassoPolicy~=nil and WeaponNativeUtilityCatalog.Enabled()
        and GetConvarInt('feather_native_lasso_reinforced',0)==1 or false
end
function WeaponNativeUtilityCatalog.Slots()
    local slots={weapon_utility='utility'}
    if WeaponNativeUtilityCatalog.ReinforcedEnabled() or WeaponNativeUtilityCatalog.DavyEnabled() then slots.weapon_utility_secondary='utility_secondary' end
    if WeaponNativeUtilityCatalog.BinocularsEnabled() then slots.weapon_utility_tertiary='utility_tertiary' end
    if WeaponNativeUtilityCatalog.CameraEnabled() then slots.weapon_utility_quaternary='utility_quaternary' end
    if WeaponNativeUtilityCatalog.AdvancedCameraEnabled() then slots.weapon_utility_quinary='utility_quinary' end
    if WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled() then slots.weapon_utility_senary='utility_senary' end
    if WeaponNativeUtilityCatalog.MetalDetectorEnabled() then slots.weapon_utility_septenary='utility_septenary' end
    if WeaponNativeUtilityCatalog.FishingRodEnabled() then slots.weapon_utility_octonary='utility_octonary' end
    return slots
end
function WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled()
    return WeaponNativeImprovedBinocularsPolicy~=nil and WeaponNativeUtilityCatalog.AdvancedCameraEnabled()
        and GetConvarInt('feather_native_binoculars_improved',0)==1 or false
end
function WeaponNativeUtilityCatalog.AdvancedCameraEnabled()
    return WeaponNativeAdvancedCameraPolicy~=nil and WeaponNativeUtilityCatalog.CameraEnabled()
        and GetConvarInt('feather_native_camera_advanced',0)==1 or false
end
function WeaponNativeUtilityCatalog.CameraEnabled()
    return WeaponNativeCameraPolicy~=nil and WeaponNativeUtilityCatalog.BinocularsEnabled()
        and GetConvarInt('feather_native_camera',0)==1 or false
end
function WeaponNativeUtilityCatalog.BinocularsEnabled()
    return WeaponNativeBinocularsPolicy~=nil and WeaponNativeUtilityCatalog.DavyEnabled()
        and GetConvarInt('feather_native_binoculars',0)==1 or false
end
function WeaponNativeUtilityCatalog.DavyEnabled()
    return WeaponNativeDavyLanternPolicy~=nil and WeaponNativeUtilityCatalog.Enabled()
        and GetConvarInt('feather_native_davy_lantern',0)==1 or false
end

function WeaponNativeUtilityCatalog.MetalDetectorEnabled()
    return WeaponNativeMetalDetectorPolicy~=nil and WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled()
        and GetConvarInt('feather_native_metal_detector',0)==1 or false
end

function WeaponNativeUtilityCatalog.FishingRodEnabled()
    return WeaponNativeFishingRodPolicy~=nil and WeaponNativeUtilityCatalog.ImprovedBinocularsEnabled()
        and GetConvarInt('feather_native_fishing_rod',0)==1 or false
end
