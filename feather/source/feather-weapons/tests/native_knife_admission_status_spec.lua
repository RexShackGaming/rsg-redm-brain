local commands,encoded={},nil
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,NativeAlphaLifecycleWearEnabled=true}
local flag=1
GetConvarInt=function() return flag end
RegisterCommand=function(n,fn) commands[n]=fn end
json={encode=function(v) encoded=v; return 'read-only-status' end}
exports=function() end
dofile('server/services/issuance.lua')
commands.WeaponNativeKnifeStatus(0)
assert(encoded.loaded==false and encoded.enabled==false and #encoded.missing==1 and encoded.noWrites)
dofile('shared/native_knife.lua')
commands.WeaponNativeKnifeStatus(0)
assert(encoded.loaded and encoded.enabled and #encoded.missing==0)
Config.NativeAlphaLifecycleWearEnabled=false
commands.WeaponNativeKnifeStatus(0)
assert(not encoded.enabled and #encoded.missing==1 and encoded.missing[1]=='NativeAlphaLifecycleWearEnabled must be true')
Config.NativeAlphaLifecycleWearEnabled=true; flag=0
commands.WeaponNativeKnifeStatus(0)
assert(not encoded.enabled and #encoded.missing==1 and encoded.convar==0)
local saved=encoded; commands.WeaponNativeKnifeStatus(3); assert(encoded==saved,'console-only diagnostic')
print('knife admission diagnostic PASS (missing module/config/convar, complete admission, read-only console scope)')
