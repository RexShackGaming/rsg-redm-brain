-- Pure profile: manifest loading does not grant permission or create a copy.
-- Preserve the originally accepted Davy identity; Standard Lantern stays retired.
WeaponNativeDavyLanternPolicy={}
function WeaponNativeDavyLanternPolicy.Resolve(def)
    if type(def)~='table' or def.id~='utility_davy_lantern' or def.kind~='weapon'
        or def.itemName~='weapon_melee_davy_lantern'
        or def.nativeWeaponName~='WEAPON_MELEE_DAVY_LANTERN'
        or def.family~='lantern' or def.slot~='utility' or def.usesAmmunition~=false
        or def.capacity~=0 or def.ammunitionType~=nil or def.multiTypeAmmunition==true
        or type(def.ammunitionTypes)~='table' or next(def.ammunitionTypes)~=nil
        or (def.nativeGrantAmount~=nil and def.nativeGrantAmount~=0)
        or type(def.condition)~='table' or def.condition.minimum~=0
        or def.condition.maximum~=100 or def.condition.equipMinimum~=1
        or type(def.policies)~='table' or def.policies.serialRequired~=true
        or type(def.attachmentSlots)~='table' or next(def.attachmentSlots)~=nil
        or type(def.attachmentDefaults)~='table' or next(def.attachmentDefaults)~=nil then
        return nil,'unsupported_native_davy_lantern_definition'
    end
    return {id=def.id,itemName=def.itemName,nativeWeaponName=def.nativeWeaponName,
        family='lantern',slot='utility',usesAmmunition=false,nativeGrantAmount=0}
end
