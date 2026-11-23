-- Default-off first throwable policy: no grant, slot mutation,
-- native setter, pickup credit, item escrow or alternate ammunition ledger.
WeaponNativeThrowablePolicy={}
function WeaponNativeThrowablePolicy.KnivesEnabled()
    return WeaponNativeThrowablePolicy.QuantityEnabled() and type(GetConvarInt)=='function'
        and GetConvarInt('feather_throwing_knife_quantities',0)==1 or false
end
function WeaponNativeThrowablePolicy.QuantityProfile(catalog,id)
    if id==nil or id=='throwable_tomahawk' then return WeaponNativeThrowablePolicy.Resolve(catalog) end
    if id~='throwable_throwing_knives' or not WeaponNativeThrowablePolicy.KnivesEnabled() then return nil,'knife_quantities_disabled' end
    local w=catalog and catalog.weapons and catalog.weapons[id]
    local a=catalog and catalog.ammunition and catalog.ammunition.ammo_throwing_knives_regular
    if not w or w.id~=id or w.itemName~='weapon_thrown_throwing_knives' or w.nativeWeaponName~='WEAPON_THROWN_THROWING_KNIVES'
        or w.family~='throwing_knife' or w.slot~='throwable' or w.ammunitionType~='ammo_throwing_knives_regular'
        or not a or a.id~='ammo_throwing_knives_regular' or a.itemName~=a.id or a.nativeAmmoName~='AMMO_THROWING_KNIVES'
        or a.maxTotal~=8 then return nil,'unsupported_quantity_knife_profile' end
    return {definition=w,ammunition=a}
end
function WeaponNativeThrowablePolicy.QuantityEnabled()
    return Config and Config.NativeThrowableQuantityContract==1 and Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
        and Config.CharacterAmmoTransportEnabled==true and Config.NativeAlphaLifecycleWearEnabled==true
        and type(GetConvarInt)=='function' and GetConvarInt('feather_throwable_quantities',0)==1 or false
end
-- Staged normal-unit admission. Not shipped enabled until commerce, lifecycle,
-- UI and recovery/retirement integration are complete.
function WeaponNativeThrowablePolicy.UnitsEnabled()
    if Config and Config.NativeThrowableQuantityOnly==true then return false end
    if WeaponNativeThrowablePolicy.QuantityEnabled() then return false end
    return Config and Config.NativeThrowableUnitsEnabled==true and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
        and Config.NativeAlphaLifecycleWearEnabled==true or false
end
function WeaponNativeThrowablePolicy.Enabled()
    if Config and Config.NativeThrowableQuantityOnly==true then return false end
    return Config and Config.NativeAlphaRuntime==true
        and Config.CharacterAmmunitionEnabled==true and Config.CharacterAmmoTransportEnabled==true
        and Config.NativeAlphaLifecycleWearEnabled==true and type(GetConvarInt)=='function'
        and GetConvarInt('feather_native_throwable',0)==1 or false
end
local function copy(v)
    if type(v)~='table' then return v end
    local result={}; for k,x in pairs(v) do result[k]=copy(x) end; return result
end
local function regularOnly(types)
    if type(types)~='table' or types[1]~='ammo_tomahawk_regular' then return false end
    for key in pairs(types) do if key~=1 then return false end end
    return true
end
function WeaponNativeThrowablePolicy.Resolve(catalog)
    local def=type(catalog)=='table' and type(catalog.weapons)=='table' and catalog.weapons.throwable_tomahawk
    local ammo=type(catalog)=='table' and type(catalog.ammunition)=='table' and catalog.ammunition.ammo_tomahawk_regular
    if type(def)~='table' or def.id~='throwable_tomahawk' or def.itemName~='weapon_thrown_tomahawk'
        or def.nativeWeaponName~='WEAPON_THROWN_TOMAHAWK' or def.family~='tomahawk' or def.slot~='throwable'
        or def.usesAmmunition==false or def.capacity~=1 or def.ammunitionType~='ammo_tomahawk_regular'
        or not regularOnly(def.ammunitionTypes) then return nil,'unsupported_native_throwable_definition' end
    if type(ammo)~='table' or ammo.id~='ammo_tomahawk_regular' or ammo.itemName~='ammo_tomahawk_regular'
        or ammo.nativeAmmoName~='AMMO_TOMAHAWK' or ammo.maxTotal~=3 then return nil,'unsupported_native_throwable_ammunition' end
    return {definition=copy(def),ammunition=copy(ammo)}
end
function WeaponNativeThrowablePolicy.Preview(catalog,firearmRegistry)
    local resolved,why=WeaponNativeThrowablePolicy.Resolve(catalog)
    if not resolved then return nil,why end
    local def,ammo=resolved.definition,resolved.ammunition
    if type(firearmRegistry)~='table' or type(firearmRegistry.names)~='table' or type(firearmRegistry.limits)~='table'
        or type(firearmRegistry.weapons)~='table' then return nil,'firearm_registry_required' end
    for id,name in pairs(firearmRegistry.names) do
        if id==ammo.id or name==ammo.nativeAmmoName then return nil,'throwable_ammunition_alias' end
    end
    if firearmRegistry.limits[ammo.id]~=nil or firearmRegistry.weapons[def.id]~=nil then return nil,'throwable_already_registered' end
    local registry=copy(firearmRegistry)
    -- One funded unit is a deliberate first-test ceiling, not an engine maximum.
    registry.names[ammo.id]=ammo.nativeAmmoName; registry.limits[ammo.id]=1
    registry.weapons[def.id]={nativeWeaponName=def.nativeWeaponName,family=def.family,
        compatible={[ammo.id]=true},defaultType=ammo.id}
    if registry.excluded then registry.excluded[def.id]=nil end
    return {definitionId=def.id,itemName=def.itemName,ammunitionItemName=ammo.itemName,
        registry=registry,testCeiling=1,pickupCredits=false,requiresFundedQuantity=true,
        metadataAmmoOwnership='character',slot='weapon_throwable'}
end
function WeaponNativeThrowablePolicy.RegistryFromLimits(catalog,limits)
    if type(limits)~='table' or (limits.ammo_tomahawk_regular~=1 and limits.ammo_tomahawk_regular~=3) then return nil,'throwable_funding_policy_required' end
    local firearms=copy(limits); firearms.ammo_tomahawk_regular=nil
    local registry,why=WeaponCharacterAmmoCatalog.Build(catalog,firearms)
    if not registry then return nil,why end
    local candidate
    candidate,why=WeaponNativeThrowablePolicy.Preview(catalog,registry)
    if candidate and limits.ammo_tomahawk_regular==3 then
        candidate.registry.limits.ammo_tomahawk_regular=3
        if WeaponNativeThrowablePolicy.QuantityEnabled() then candidate.registry.throwableQuantityContract=1
        else candidate.registry.throwableUnitContract=2 end
    end
    return candidate and candidate.registry or nil,why
end
