-- Pure profile: loading alone is not permission or native creation.
-- Preserve original combined viewing/wheel evidence and separate carrier identity.
WeaponNativeMetalDetectorPolicy={}
function WeaponNativeMetalDetectorPolicy.Resolve(def)
    if type(def)~='table' or def.id~='utility_metal_detector' or def.kind~='weapon'
        or def.itemName~='weapon_kit_metal_detector'
        or def.nativeWeaponName~='WEAPON_KIT_METAL_DETECTOR'
        or def.family~='metal_detector' or def.slot~='utility' or def.usesAmmunition~=false
        or def.capacity~=0 or def.ammunitionType~=nil or def.multiTypeAmmunition==true
        or type(def.ammunitionTypes)~='table' or next(def.ammunitionTypes)~=nil
        or (def.nativeGrantAmount~=nil and def.nativeGrantAmount~=0)
        or type(def.condition)~='table' or def.condition.minimum~=0
        or def.condition.maximum~=100 or def.condition.equipMinimum~=1
        or type(def.policies)~='table' or def.policies.serialRequired~=true
        or type(def.attachmentSlots)~='table' or next(def.attachmentSlots)~=nil
        or type(def.attachmentDefaults)~='table' or next(def.attachmentDefaults)~=nil then
        return nil,'unsupported_native_metal_detector_definition'
    end
    return {id=def.id,itemName=def.itemName,nativeWeaponName=def.nativeWeaponName,
        family='metal_detector',ownershipGroup='metal_detector',slot='utility',
        equipmentSlot='weapon_utility_septenary',usesAmmunition=false,nativeGrantAmount=0}
end

