local commands,encoded={},nil
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,NativeAlphaLifecycleWearEnabled=true}
local flag=0
GetConvarInt=function() return flag end
RegisterCommand=function(n,f) commands[n]=f end
exports=function() end
json={encode=function(v) encoded=v; return 'read-only' end}
dofile('server/services/issuance.lua')
commands.WeaponNativeThrowableStatus(0)
assert(not encoded.loaded and not encoded.enabled and encoded.noWrites and #encoded.missing==2)
for _,p in ipairs({'shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua'}) do dofile(p) end
commands.WeaponNativeThrowableStatus(0)
assert(encoded.loaded and not encoded.enabled and #encoded.missing==1 and encoded.fundedCeiling==1
 and encoded.pickupCredits==false and encoded.fundingRequiresRebuild)
flag=1; commands.WeaponNativeThrowableStatus(0)
assert(encoded.enabled and #encoded.missing==0)
assert(not encoded.pickupCredits and not encoded.pickupComponentsLoaded and encoded.pickupRequiresCommittedSpend)
WeaponNativeThrowableRecovery={}; WeaponCharacterAmmoService={NativePickup=function() end}
commands.WeaponNativeThrowableStatus(0)
assert(encoded.pickupCredits and encoded.pickupComponentsLoaded and encoded.pickupConvar==1
 and encoded.pickupPolicy=='same_session_native_spend_credit_v1' and not encoded.originConfirmed)
Config.CharacterAmmoTransportEnabled=false; commands.WeaponNativeThrowableStatus(0)
assert(not encoded.enabled and #encoded.missing==1)
Config.CharacterAmmoTransportEnabled=true
WeaponDefinitionCatalog.ammunition.ammo_tomahawk_regular.nativeAmmoName='AMMO_REVOLVER'
commands.WeaponNativeThrowableStatus(0)
assert(not encoded.enabled and #encoded.missing==1)
local before=encoded; commands.WeaponNativeThrowableStatus(7); assert(encoded==before)
print('throwable admission diagnostic PASS: console-only/module/config/convar/exact catalog, no writes')
