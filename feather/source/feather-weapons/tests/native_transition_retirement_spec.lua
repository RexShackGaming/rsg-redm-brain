dofile('server/services/native_equipment_transition.lua')
local sid='old'; local sends,rebuilds,commits=0,0,0
local id={characterId='c',sessionId='old',epoch='old-epoch'}
local coordinator
local api={enabled=function() return true end,current=function(_,scope) return scope.sessionId==sid end,
 prepare=function() return {ok=true,value={identity=id,spec={characterId='c',action='dry-run'}}} end,
 released=function() return true end,ticket=function() return id.epoch end,
 requestRelease=function() sends=sends+1; return true end,
 commit=function(context,spec)
  assert(coordinator.CanCommit(context,spec)); commits=commits+1
  coroutine.yield('commit_reply_lost')
  return {ok=true,value={unchanged=true}}
 end,
 rebuild=function() rebuilds=rebuilds+1; return {ok=true,value={characterId='c',sessionId=sid,epoch='restored'}} end,
 restored=function() return true end}
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
assert(coordinator.Begin(1,{}).ok and not coordinator.Retire(1,'old'),'cannot retire current old session')
local result
local worker=coroutine.create(function() result=coordinator.Released(1,'old-epoch',id) end)
assert(coroutine.resume(worker)); assert(commits==1 and coordinator.Status(1).commitOutcome=='pending')
sid='new'
assert(coordinator.Retire(1,'old') and not coordinator.Status(1),'Core-retired session may discard reservation, not replay')
id={characterId='c',sessionId='new',epoch='new-epoch'}
assert(coordinator.Begin(1,{}).ok)
assert(coroutine.resume(worker) and not result.ok and rebuilds==0,'late old commit reply cannot rebuild onto new source')
assert(coordinator.Status(1).sessionId=='new' and not coordinator.Retire(1,'old'))
assert(not coordinator.CanCommit({actorSource=1,characterId='c',sessionId='old',epoch='old-epoch',ticket='old-epoch'},{}))
print('Transition retirement PASS (current owner cannot retire, Core-expired pending outcome stays non-replayed, late commit cannot rebuild/new source unaffected)')
