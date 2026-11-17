-- Temporary test price: one paid physical unit, no separate ammunition.
if Config and Config.NativeThrowableQuantityContract==1 and GetConvarInt('feather_throwable_quantities',0)==1 then
    WeaponStoreConfig.weapons.throwable_tomahawk=false
    WeaponStoreConfig.ammunition.ammo_tomahawk_regular={price=1.50,rounds=1}
elseif GetConvarInt('feather_native_paid_throwables',0)==1 then
    WeaponStoreConfig.weapons.throwable_tomahawk=1.50
end
