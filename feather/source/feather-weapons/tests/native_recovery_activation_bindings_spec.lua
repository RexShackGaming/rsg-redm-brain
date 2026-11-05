dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane'}
dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/character_ammunition_catalog.lua'); dofile('shared/character_ammunition_policy.lua')
dofile('shared/character_ammunition_dispatch.lua'); dofile('shared/character_ammunition_activation.lua')
local sid,retire,deny='old',false,false
local handlers,timers={},{}
AddEventHandler=function(name,fn) handlers[name]=fn end
SetTimeout=function(_,fn) timers[#timers+1]=fn end
local starts,sends,retireCalls=0,0,0
TriggerClientEvent=function() sends=sends+1 end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='Jane',sessionId=sid}} end}
WeaponCharacterAmmoInventoryProvider={Status=function() return 'ready' end}
WeaponNativeEquipmentBindings={Attach=function() end,IsStopping=function() return false end,
 RetireSession=function(target,session) assert(target==1 and session=='old'); retireCalls=retireCalls+1 end,
 ReconcileSession=function() return {ok=not deny} end}
WeaponCharacterAmmoService={
 ReconcileSession=function() return {ok=true,value={retired=retire and {{source=1,sessionId='old'}} or {}}} end,
 OpenLoadout=function()
  starts=starts+1; local id={characterId='Jane',sessionId=sid,epoch='e'..starts,phase='restoring'}
  return {ok=true,value={runtime=id,creation={identity=id}}}
 end,ValidateLoadout=function() return {ok=true} end,
 ConfirmRestore=function(_,report) return {ok=true,value={characterId=report.characterId,sessionId=report.sessionId,epoch=report.epoch,phase='active'}} end,
 FreezeLoadout=function() error('late old timer must not freeze current owner') end,
}
dofile('server/services/character_ammunition_dispatch.lua')
local dispatcher=WeaponCharacterAmmoDispatcher
assert(WeaponCharacterAmmoActivationOwner.Ready(1,{characterId='Jane',sessionId='old'}).ok)
local old=dispatcher.Status(1).identity; assert(dispatcher.ConfirmRestore(1,old).ok)
sid='new'; retire=true
assert(WeaponCharacterAmmoActivationOwner.Ready(1,{characterId='Jane',sessionId='new'}).ok)
local current=dispatcher.Status(1).identity; assert(current.sessionId=='new' and retireCalls==1 and starts==2 and sends==2)
assert(dispatcher.ConfirmRestore(1,current).ok)
timers[1](); handlers['core.session.left.v1']({source=1,sessionId='old'})
assert(dispatcher.Status(1).phase=='active' and dispatcher.Status(1).identity.sessionId=='new')
assert(not dispatcher.ConfirmRestore(1,old).ok,'stale restore cannot acknowledge new epoch')
retire=false; deny=true
assert(not WeaponCharacterAmmoActivationOwner.Ready(1,{characterId='Jane',sessionId='new'}).ok and starts==2)
print('Recovery activation concrete bindings PASS (server Core scope, old session retirement, fresh start, late old event/timer/ack isolation, held transition veto)')
