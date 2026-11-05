Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
dofile('shared/character_ammunition.lua'); dofile('client/character_ammunition_native.lua')
dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/character_ammunition_catalog.lua'); dofile('shared/character_ammunition_policy.lua')
local captured,checkpointApi,receives,suspended
WeaponCharacterAmmoWorldContext={Identity=function() return {characterId='actual',sessionId='session'} end,
    Read=function() return {ok=true,value={ped=1}} end}
WeaponCharacterAmmoReceiver={New=function(api,registry)
    captured=api; assert(registry.limits.ammo_pistol_regular==100 and registry.limits.ammo_shotgun_slug==60)
    return {Receive=function(_,origin) receives=(receives or 0)+1; return origin end,
        Tick=function() return true end,Suspend=function(reason) suspended=reason; return nil,reason end,
        Status=function() return {phase='closed'} end}
end}
WeaponCharacterAmmoCheckpoint={New=function(_,api) checkpointApi=api; return {Run=function() return {ok=true} end} end}
dofile('client/character_ammunition_host.lua')
local adapters={ped=function() return 1 end,identity=function() return {characterId='fake'} end,
    ready=function() return true end,enabled=function() return true end}
for _,name in ipairs({'block','hash','read','write','creation','send','now','wait','caller'}) do adapters[name]=function() end end
local reads,readHook=0,nil
adapters.hash=function(name) return name end
adapters.read=function() reads=reads+1; if readHook then readHook() end; return 0 end
adapters.write=function() error('death observation cannot write') end
local host=assert(WeaponCharacterAmmoHost.New(adapters))
assert(not host.Receive({},true) and not receives)
Config.CharacterAmmunitionEnabled=true
assert(not host.Receive({},true) and not receives)
Config.CharacterAmmoTransportEnabled=true
assert(host.Receive({},true) and receives==1)
local deathRevision=2
WeaponCharacterAmmoWorldContext.ReadDeath=function()
    return {ok=true,value={characterId='actual',sessionId='session',ped=1,medicalRevision=deathRevision}}
end
local death=assert(host.ReadDeathObservation())
local count=0; for _ in pairs(death.pools) do count=count+1 end
assert(count==27 and reads==27 and death.epoch==nil and death.lifeState=='dead')
readHook=function() deathRevision=deathRevision+1 end
local observed,why=host.ReadDeathObservation()
assert(not observed and why=='death_context_changed','Medical revision change refuses snapshot')
readHook=nil
Config.NativeAlphaLifecycleWearEnabled=true
WeaponCharacterAmmoActiveOwner={DeathWear=function(value)
    assert(value.medicalRevision==deathRevision); return {epoch='e',medicalRevision=deathRevision,items={}}
end}
assert(host.ReadDeathObservation().deathWear.epoch=='e','final death sample carries exact owned wear')
WeaponCharacterAmmoActiveOwner.DeathWear=function() return nil end
assert(not host.ReadDeathObservation(),'missing owned wear refuses death snapshot')
Config.NativeAlphaLifecycleWearEnabled=false
assert(captured.identity().characterId=='actual' and captured.ready())
adapters.ped=function() return 99 end
assert(captured.ready(),'adapter table mutation cannot replace captured ped callback')
WeaponCharacterAmmoWorldContext.Read=function() return {ok=true,value={ped=2}} end
assert(not captured.ready())
assert(checkpointApi.identity().characterId=='actual' and host.Checkpoint({}).ok)
Config.CharacterAmmunitionEnabled=false; host.Tick(); assert(suspended=='native_host_disabled')
assert(not WeaponCharacterAmmoHost.New({}))
WeaponCharacterAmmoPolicy.Build=function() error('policy') end
local result,why=WeaponCharacterAmmoHost.New(adapters)
assert(not result and why=='host_policy_unavailable')
print('dormant host composition PASS (canonical policy, actual context, gates, adapters, checkpoint binding)')
