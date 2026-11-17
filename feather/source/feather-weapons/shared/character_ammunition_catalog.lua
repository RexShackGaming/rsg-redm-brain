-- Server-selected policy only. Client/native readback never defines credit limits.
WeaponCharacterAmmoCatalog={}
-- Previously validated native model/types; opt-in current character-ledger port.
-- The bow remains an owned weapon. Recovering ammunition never issues a bow.
WeaponRegularArrowPolicy={}
function WeaponRegularArrowPolicy.Enabled()
    return Config and Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
        and Config.CharacterAmmoTransportEnabled==true and Config.NativeAlphaLifecycleWearEnabled==true
        and type(GetConvarInt)=='function' and GetConvarInt('feather_regular_arrows',0)==1 or false
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
                types={'ammo_arrow_regular'} -- specialty routes stay outside this admission
            end
            for _,ammoId in ipairs(types) do
                local ammo=catalog.ammunition[ammoId]; local cap=policy[ammoId]
                if weapon.family=='bow' and (not ammo or ammo.itemName~='ammo_arrow_regular'
                    or ammo.nativeAmmoName~='AMMO_ARROW' or cap~=40) then return nil,'unsupported_regular_arrow_policy' end
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
    for id in pairs(policy) do if result.limits[id]==nil then return nil,'unknown_policy_type' end end
    return result
end
