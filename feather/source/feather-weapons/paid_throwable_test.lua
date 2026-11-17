-- Explicit dev-server overlay. Ordinary configuration remains default-off.
local quantities=type(GetConvar)=='function' and GetConvar('feather_throwable_quantities','0')=='1'
if GetConvarInt('feather_native_paid_throwables',0)==1 then
 assert(Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
  and Config.CharacterAmmoTransportEnabled==true and Config.NativeAlphaLifecycleWearEnabled==true,
  'Paid throwable test requires the native runtime and lifecycle wear')
 Config.NativeThrowableUnitsEnabled=true
 Config.NativeThrowablePickupContract=1
 Config.NativeThrowablePickupPriorPolicy=Config.NativeThrowablePickupPriorPolicy or {w_melee_tomahawk01=true,w_melee_tomahawk02=true}
end
if GetConvarInt('feather_native_paid_collection',0)==1 and not quantities then
 assert(Config.NativeThrowableUnitsEnabled==true,'Native collection test requires feather_native_paid_throwables=1')
 Config.NativeThrowableNativeCollectionContract=1
end
if quantities then
 assert(Config.NativeAlphaRuntime==true and Config.CharacterAmmunitionEnabled==true
  and Config.CharacterAmmoTransportEnabled==true and Config.NativeAlphaLifecycleWearEnabled==true,
  'Quantity Tomahawks require the native ammunition runtime and lifecycle wear')
 Config.NativeThrowableQuantityContract=1
 Config.NativeThrowablePickupPriorPolicy=Config.NativeThrowablePickupPriorPolicy or {w_melee_tomahawk01=true,w_melee_tomahawk02=true}
 Config.NativeThrowableUnitsEnabled=false
 Config.NativeThrowablePickupContract=0
 Config.NativeThrowableNativeCollectionContract=0
end
