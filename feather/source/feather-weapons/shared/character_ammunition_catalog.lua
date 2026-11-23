-- Server-selected policy only. Client/native readback never defines credit limits.
WeaponCharacterAmmoCatalog={}
-- Previously validated native model/types; opt-in current character-ledger port.
-- The bow remains an owned weapon. Recovering ammunition never issues a bow.
WeaponRegularArrowPolicy={}
-- Historical native compatibility is separate from pickup conversion evidence.
-- Callers must opt in to the current ledger integration; Improved is excluded.
WeaponSpecialAmmunitionPolicy={}
local specialTypes={
    ammo_arrow_small_game={native='AMMO_ARROW_SMALL_GAME',capacity=40,family='bow'},
    ammo_arrow_poison={native='AMMO_ARROW_POISON',capacity=8,family='bow'},
    ammo_arrow_fire={native='AMMO_ARROW_FIRE',capacity=8,family='bow'},
    ammo_arrow_dynamite={native='AMMO_ARROW_DYNAMITE',capacity=8,family='bow'},
    ammo_throwing_knives_poison={native='AMMO_THROWING_KNIVES_POISON',capacity=8,family='throwing_knife',recoveryType='ammo_throwing_knives_regular'},
}
function WeaponSpecialAmmunitionPolicy.Profile(catalog,id)
    local p=specialTypes[id]
    if not p then return nil,'unsupported_special_ammunition' end
    local a=catalog and catalog.ammunition and catalog.ammunition[id]
    if type(a)~='table' or a.id~=id or a.itemName~=id or a.nativeAmmoName~=p.native
        or a.maxTotal~=p.capacity then return nil,'special_ammunition_definition_changed' end
    return {id=id,nativeAmmoName=p.native,capacity=p.capacity,family=p.family,recoveryType=p.recoveryType}
end
function WeaponSpecialAmmunitionPolicy.Profiles(catalog)
    local result={}
    for id in pairs(specialTypes) do
        local profile,why=WeaponSpecialAmmunitionPolicy.Profile(catalog,id)
        if not profile then return nil,why end
        result[id]=profile
    end
    return result
end
function WeaponRegularArrowPolicy.Enabled()
    return Config and Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
        and Config.CharacterAmmoTransportEnabled==true and Config.NativeAlphaLifecycleWearEnabled==true
        and type(GetConvarInt)=='function' and GetConvarInt('feather_regular_arrows',0)==1 or false
end
function WeaponSpecialAmmunitionPolicy.Enabled(family)
    if type(GetConvarInt)~='function' then return false end
    if family=='bow' then return WeaponRegularArrowPolicy.Enabled() and GetConvarInt('feather_special_arrows',0)==1 end
    return family=='throwing_knife' and WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.KnivesEnabled()
        and GetConvarInt('feather_poison_knives',0)==1 or false
end
function WeaponCharacterAmmoCatalog.Build(catalog,policy)
    if type(catalog)~='table' or type(catalog.weapons)~='table' or type(catalog.ammunition)~='table'
        or type(policy)~='table' then return nil,'invalid_catalog' end
    local families={pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true}
    families.bow=WeaponRegularArrowPolicy.Enabled() or nil
    local result={names={},limits={},weapons={},blocked={},excluded={}}
    local nativeOwners={}
    for id,weapon in pairs(catalog.weapons) do
        if families[weapon.family] and weapon.usesAmmunition~=false then
            if weapon.id~=id or type(weapon.nativeWeaponName)~='string'
                or not weapon.nativeWeaponName:match('^WEAPON_[A-Z0-9_]+$')
                or type(weapon.ammunitionTypes)~='table' or #weapon.ammunitionTypes==0 then
                return nil,'invalid_firearm_definition'
            end
            local compatible={}
            local types=weapon.ammunitionTypes
            if weapon.family=='bow' then
                if id~='bow' or weapon.itemName~='weapon_bow' or weapon.nativeWeaponName~='WEAPON_BOW'
                    or weapon.slot~='longgun' or weapon.ammunitionType~='ammo_arrow_regular' then return nil,'unsupported_bow_definition' end
                types={'ammo_arrow_regular'}
                if WeaponSpecialAmmunitionPolicy.Enabled('bow') then
                    for _,id in ipairs({'ammo_arrow_small_game','ammo_arrow_poison','ammo_arrow_fire','ammo_arrow_dynamite'}) do types[#types+1]=id end
                end
            end
            for _,ammoId in ipairs(types) do
                local ammo=catalog.ammunition[ammoId]; local cap=policy[ammoId]
                if weapon.family=='bow' then
                    if ammoId=='ammo_arrow_regular' then
                        if not ammo or ammo.itemName~=ammoId or ammo.nativeAmmoName~='AMMO_ARROW' or cap~=40 then return nil,'unsupported_regular_arrow_policy' end
                    else
                        local p=WeaponSpecialAmmunitionPolicy.Profile(catalog,ammoId)
                        if not p or p.family~='bow' or cap~=p.capacity then return nil,'unsupported_special_arrow_policy' end
                    end
                end
                if type(ammo)~='table' or ammo.id~=ammoId or type(ammo.nativeAmmoName)~='string'
                    or not ammo.nativeAmmoName:match('^AMMO_[A-Z0-9_]+$') then return nil,'invalid_ammunition_definition' end
                if type(cap)~='number' or cap<=0 or cap%1~=0 or cap==math.huge then return nil,'missing_or_invalid_policy_limit' end
                if ammo.maxTotal and cap>ammo.maxTotal then return nil,'policy_exceeds_definition_limit' end
                if compatible[ammoId] then return nil,'duplicate_compatible_type' end
                local owner=nativeOwners[ammo.nativeAmmoName]
                if owner and owner~=ammoId then return nil,'native_ammunition_alias' end
                nativeOwners[ammo.nativeAmmoName]=ammoId
                compatible[ammoId]=true; result.names[ammoId]=ammo.nativeAmmoName; result.limits[ammoId]=cap
            end
            if not compatible[weapon.ammunitionType] then return nil,'invalid_default_type' end
            result.weapons[id]={nativeWeaponName=weapon.nativeWeaponName,family=weapon.family,
                compatible=compatible,defaultType=weapon.ammunitionType}
        else result.excluded[id]=true end
    end
    if next(result.limits)==nil then return nil,'no_firearm_pools' end
    if policy.ammo_throwing_knives_regular~=nil then
        local p=WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.QuantityProfile(catalog,'throwable_throwing_knives')
        if not p or policy.ammo_throwing_knives_regular~=8 then return nil,'unsupported_knife_quantity_policy' end
        if nativeOwners.AMMO_THROWING_KNIVES then return nil,'native_ammunition_alias' end
        result.names.ammo_throwing_knives_regular='AMMO_THROWING_KNIVES';result.limits.ammo_throwing_knives_regular=8
        result.quantityKnifeContract=1
    end
    if policy.ammo_throwing_knives_poison~=nil then
        local p=WeaponSpecialAmmunitionPolicy.Profile(catalog,'ammo_throwing_knives_poison')
        if not p or not WeaponSpecialAmmunitionPolicy.Enabled('throwing_knife') or not result.quantityKnifeContract
            or policy[p.id]~=p.capacity or nativeOwners[p.nativeAmmoName] then return nil,'unsupported_poison_knife_policy' end
        result.names[p.id]=p.nativeAmmoName;result.limits[p.id]=p.capacity
    end
    for id in pairs(policy) do if result.limits[id]==nil then return nil,'unknown_policy_type' end end
    return result
end
