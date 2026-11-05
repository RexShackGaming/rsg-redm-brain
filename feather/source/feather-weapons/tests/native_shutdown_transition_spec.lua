dofile('server/services/native_equipment_transition.lua')
local id={characterId='Jane',sessionId='s',epoch='e'}
local released=false
local rebuilds=0
local coordinator
coordinator=assert(WeaponNativeEquipmentTransition.New({enabled=function() return true end,
 prepare=function() return {ok=true,value={identity=id,spec={characterId='Jane',action='shutdown'}}} end,
 current=function() return true end,released=function() return released end,
 requestRelease=function() return true end,ticket=function() return 'shutdown' end,
 commit=function(context,spec) assert(coordinator.CanCommit(context,spec)); return {ok=true,value={unchanged=true}} end,
 rebuild=function() rebuilds=rebuilds+1; error('shutdown may not rebuild') end,
 restored=function() error('shutdown needs release, not a new restore') end}))
assert(coordinator.Begin(1,{}).ok)
assert(not coordinator.Released(1,'forged',id).ok and rebuilds==0)
released=true
local done=coordinator.Released(1,'shutdown',id)
assert(done.ok and done.value.phase=='parked' and rebuilds==0)
local status=coordinator.Status(1)
assert(status.phase=='parked' and not status.committed and status.commitOutcome=='confirmed')
assert(not coordinator.Begin(1,{}).ok and not coordinator.Released(1,'shutdown',id).ok)
assert(not coordinator.Cancel(1,'other') and coordinator.Status(1).phase=='parked')
assert(coordinator.Cancel(1,'s') and coordinator.Status(1)==nil)
print('Native orderly shutdown PASS (release authority, no writes/rebuild, parked duplicate refusal, scoped retirement)')
