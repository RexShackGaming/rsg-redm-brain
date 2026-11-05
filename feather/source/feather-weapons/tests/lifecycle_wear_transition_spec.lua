dofile('server/services/native_equipment_transition.lua')
local old={characterId='jane',sessionId='s',epoch='old'}
local fresh={characterId='jane',sessionId='s',epoch='fresh'}
local writes,finalizations=0,0
local coordinator
local api={enabled=function() return true end,current=function() return true end,
 prepare=function() return {ok=true,value={identity=old,spec={characterId='jane',action='unequip',lifecycleSnapshot={}}}} end,
 released=function() return true end,ticket=function() return 'ticket' end,
 requestRelease=function(requestSource,request) assert(request.collectWear==true); return true end,
 finalizeSpec=function(context,spec,wear)
  assert(writes==0 and coordinator.Status(2).phase=='finalizing_spec')
  if not wear then return {ok=false,error={code='missing_wear'}} end
  finalizations=finalizations+1; spec.lifecycleWear={}; return {ok=true,value=spec}
 end,
 commit=function(context,spec)
  assert(coordinator.CanCommit(context,spec) and spec.lifecycleWear and finalizations==1)
  writes=writes+1; return {ok=true}
 end,rebuild=function() return {ok=true,value=fresh} end,restored=function() return true end}
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
assert(coordinator.Begin(2,{}).ok)
assert(not coordinator.Released(2,'ticket',old).ok and writes==0)
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
assert(coordinator.Begin(2,{}).ok)
assert(coordinator.Released(2,'ticket',old,{epoch='old',items={}}).ok and writes==1)
assert(coordinator.Restored(2,'ticket',fresh).ok)
assert(not coordinator.Released(2,'ticket',old,{}).ok and writes==1)
print('lifecycle_wear_transition_spec PASS (authoritative release before final plan, no commit on missing sample, one reserved commit/restore)')
