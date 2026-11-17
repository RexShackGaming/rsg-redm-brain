-- Supported regular Tomahawk mode. Historical exact-item hosts are offline research.
Config.NativeThrowableQuantityOnly=true
Config.NativeThrowableUnitsEnabled=false
Config.NativeThrowablePickupContract=0
Config.NativeThrowableNativeCollectionContract=0
Config.NativeThrowableQuantityContract=0
if type(GetConvarInt)=='function' then
    for _,name in ipairs({'feather_native_paid_throwables','feather_native_paid_collection',
        'feather_native_throwable','feather_native_throwable_pickup'}) do
        assert(GetConvarInt(name,0)==0,'Retired throwable mode requested: '..name..'; set it to 0 and use feather_throwable_quantities')
    end
end
if type(GetConvar)=='function' and GetConvar('feather_throwable_quantities','0')=='1' then
    assert(Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
        and Config.CharacterAmmoTransportEnabled==true and Config.NativeAlphaLifecycleWearEnabled==true,
        'Quantity Tomahawks require the native ammunition runtime and lifecycle wear')
    Config.NativeThrowableQuantityContract=1
    Config.NativeThrowablePickupPriorPolicy=Config.NativeThrowablePickupPriorPolicy
        or {w_melee_tomahawk01=true,w_melee_tomahawk02=true}
end
