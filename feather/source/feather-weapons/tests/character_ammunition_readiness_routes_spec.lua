dofile('shared/character_ammunition_transport.lua')
dofile('shared/character_ammunition_readiness.lua')
Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
local events,handlers,threads,replies,sends={},{},{},{},{}
local now,opens,provider=0,0,false
GetGameTimer=function() return now end
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=function(name,fn) handlers[name]=fn end
SetTimeout=function() end
GetCurrentResourceName=function() return 'feather-weapons' end
TriggerClientEvent=function(name,target,...) replies[#replies+1]={name,target,...} end
TriggerServerEvent=function(name,...) sends[#sends+1]={name,...} end
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
WeaponCharacterAmmoDispatcher={}
WeaponCharacterAmmoInventoryProvider={Status=function() return provider and 'ready' or 'dormant' end}
WeaponCharacterAmmoActivationOwner={Ready=function(target,identity)
    assert(target==2 and identity.characterId=='Jane' and identity.pools==nil)
    opens=opens+1; source=999; return {ok=true}
end}
dofile('server/services/character_ammunition_routes.lua')
local hint={characterId='Jane',sessionId='current'}
source=2; events['feather-weapons:server:character-ammo-ready'](1,hint); assert(opens==0)
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
events['feather-weapons:server:character-ammo-ready'](1,hint); assert(opens==0)
provider=true; source=2
events['feather-weapons:server:character-ammo-ready'](1,hint)
assert(opens==1 and replies[1][2]==2,'reply remains bound to captured CFX source across yield')
source=2; events['feather-weapons:server:character-ammo-ready'](2,hint); assert(opens==1)
handlers.playerDropped(); events['feather-weapons:server:character-ammo-ready'](2,hint); assert(opens==2)
dofile('client/character_ammunition_routes.lua')
local owner={Readiness=function() return hint end}
Config.CharacterAmmoTransportEnabled=false
assert(not WeaponCharacterAmmoClientBindings.Readiness(owner) and #threads==0)
Config.CharacterAmmoTransportEnabled=true
assert(WeaponCharacterAmmoClientBindings.Readiness(owner))
assert(not WeaponCharacterAmmoClientBindings.Readiness(owner) and #threads==1)
assert(coroutine.resume(threads[1])); assert(#sends==1)
source=0; events['feather-weapons:client:character-ammo-ready'](1,hint,true)
now=12000; assert(coroutine.resume(threads[1])); now=13000
assert(coroutine.resume(threads[1])); assert(#sends==2,'local success event cannot stop retries')
source=65535; events['feather-weapons:client:character-ammo-ready'](2,hint,true)
assert(coroutine.resume(threads[1]) and #sends==2)
handlers.onResourceStop('feather-weapons')
assert(coroutine.resume(threads[1]) and coroutine.status(threads[1])=='dead')
assert(not WeaponCharacterAmmoClientBindings.Readiness(owner))
print('character_ammunition_readiness_routes_spec PASS (actual route gates, CFX source capture, origin, stop)')
