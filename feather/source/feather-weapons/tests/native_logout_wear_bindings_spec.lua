dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
local events,registered,timers={},{},{}
Config={DevMode=true,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,NativeAlphaCharacterId='Jane'}
RegisterCommand=function() end
RegisterNetEvent=function(name,fn) events[name]=fn end
AddEventHandler=RegisterNetEvent
SetTimeout=function(_,fn) timers[#timers+1]=fn end
GetGameTimer=function() return 1 end
GetResourceState=function() return 'stopped' end
GetInvokingResource=function() return 'feather-inventory' end
local id={characterId='Jane',sessionId='s',epoch='e'}
local state={phase='active',identity=id}
local release,reply,writes=nil,nil,0
TriggerClientEvent=function(name,target,a,b,c)
 assert(target==1)
 if name=='feather-weapons:client:native-equipment-release' then release=a
 elseif name=='feather-weapons:client:native-logout-wear-result' then reply={id=a,scope=b,result=c} end
end
CoreAdapter={ResolveSession=function() return {ok=true,value=id} end,
 IsSessionCurrent=function(target,s,c) return target==1 and s==id.sessionId and c==id.characterId end}
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function() error('logout must not rebuild old session') end}
WeaponDefinitionCatalog={}
WeaponCharacterLifecycleWear={Plan=function(_,wear,_,epoch)
 assert(wear.epoch==epoch and #wear.items==0); return {} end}
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function() return {ok=true,value={expected={},equipment={}}} end,
 CommitNativeEquipmentTransition=function(_,context,spec)
  assert(state.phase=='released' and spec.action=='shutdown' and #spec.lifecycleWear==0)
  assert(registered.ValidateNativeEquipmentCommit(context,spec)); writes=writes+1
  return {ok=true,value={unchanged=true}}
 end,
}},{__call=function(_,name,fn) registered[name]=fn end})
dofile('server/services/native_equipment_transition.lua')
source=1
events['feather-weapons:server:native-logout-wear']('stale',{characterId='Jane',sessionId='old',epoch='e'})
assert(reply and not reply.result.ok and not release and writes==0)
events['feather-weapons:server:native-logout-wear']('logout',id)
assert(release and release.collectWear and writes==0)
local ticket=release.ticket
events['feather-weapons:server:native-logout-wear']('duplicate',id)
assert(release.ticket==ticket and writes==0)
events['feather-weapons:server:native-equipment-released']('forged',id,true,{epoch='e',items={}})
assert(writes==0)
state={phase='released',identity=id}
events['feather-weapons:server:native-equipment-released'](ticket,id,true,{epoch='e',items={}})
assert(writes==1 and reply.id=='logout' and reply.result.ok and WeaponNativeEquipmentBindings.IsStopping(1))
events['feather-weapons:server:native-equipment-released'](ticket,id,true,{epoch='e',items={}})
assert(writes==1,'duplicate cannot repeat commit')
for _,fn in ipairs(timers) do fn() end
assert(reply.result.ok,'old timeout cannot overwrite completed result')
events['core.session.left.v1']({source=1,sessionId='s'})
assert(not WeaponNativeEquipmentBindings.IsStopping(1),'logout retire marker clears on exact session exit')
print('Native logout wear concrete bindings PASS (scope/rate/pending gate, release-before-commit, parked acknowledgment, no rebuild, duplicate and timer retirement)')
