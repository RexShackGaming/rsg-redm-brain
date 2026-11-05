dofile('shared/character_ammunition_transport.lua')
local events,receives,replies={},0,0
Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
RegisterNetEvent=function(name,fn) assert(not events[name]); events[name]=fn end
local hooks={}
AddEventHandler=function(name,fn) hooks[name]=fn end
SetTimeout=function() end
TriggerServerEvent=function() end
GetCurrentResourceName=function() return 'feather-weapons' end
dofile('client/character_ammunition_routes.lua')
local runtime={Receive=function(_,origin) assert(origin==true); receives=receives+1 end,
    Suspend=function(reason) assert(reason=='loadout_ingress_failed') end}
assert(not WeaponCharacterAmmoClientIngress.Install(runtime))
assert(not events['feather-weapons:client:character-ammo-loadout'],'disabled factory cannot register ingress')
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
assert(WeaponCharacterAmmoClientIngress.Install(runtime))
assert(not WeaponCharacterAmmoClientIngress.Install(runtime),'one receiver per resource lifetime')
local report={characterId='c',sessionId='s',epoch='e',revision=0,pools={ammo=1}}
WeaponCharacterAmmoClientTransport.Send('observe',1,report,function() replies=replies+1 end)
source=0
events['feather-weapons:client:character-ammo'](1,'e',{ok=true})
events['feather-weapons:client:character-ammo-loadout']({})
assert(replies==0 and receives==0,'local events cannot accept replies or loadouts')
source=65535
events['feather-weapons:client:character-ammo'](1,'e',{ok=true})
events['feather-weapons:client:character-ammo-loadout']({})
assert(replies==1 and receives==1)
Config.CharacterAmmoTransportEnabled=false
events['feather-weapons:client:character-ammo-loadout']({})
assert(receives==1,'disabled transport cannot accept a late loadout')
local stopCleanups,stopSuspends=0,0
WeaponCharacterAmmoActiveOwner={StopZeroAmmo=function() stopCleanups=stopCleanups+1; return true end}
runtime.Suspend=function(why) assert(why=='resource_stopping'); stopSuspends=stopSuspends+1 end
hooks.onClientResourceStop('other'); assert(stopCleanups==0)
hooks.onClientResourceStop('feather-weapons')
hooks.onResourceStop('feather-weapons')
assert(stopCleanups==1 and stopSuspends==1,'both stop events must be bound and cleanup once before suspension')
print('production client ingress PASS (explicit gated install, server-origin replies/loadouts, duplicate installation refusal)')
