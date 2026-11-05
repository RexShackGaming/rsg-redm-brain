dofile('server/services/native_equipment_transition.lua')
local bound={characterId='jane',sessionId='session',epoch='old'}
local sends,writes,rebuilds=0,0,0
local c
c=WeaponNativeEquipmentTransition.New({
 enabled=function() return true end,
 prepare=function(_,intent)
  assert(intent.action=='dry-run')
  return {ok=true,value={identity=bound,spec={characterId='jane',action='dry-run'}}}
 end,
 current=function() return true end,ticket=function() return 'real-ticket' end,
 requestRelease=function() sends=sends+1;return true end,
 released=function() return true end,
 commit=function(_,spec) assert(spec.action=='dry-run');writes=writes+1;return {ok=true,value={unchanged=true}} end,
 rebuild=function() rebuilds=rebuilds+1;return {ok=true,value={characterId='jane',sessionId='session',epoch='new'}} end,
 restored=function() return true end})
local result=assert(WeaponNativeEquipmentTransition.ProbeOverlap(c,3,bound))
assert(result.ok and result.value.competingRefused and result.value.staleAcknowledgementRefused)
assert(sends==1 and writes==0 and rebuilds==0 and c.Status(3).phase=='releasing')
assert(c.Released(3,'real-ticket',bound).ok)
assert(writes==1 and rebuilds==1 and c.Status(3).phase=='rebuilding')
assert(c.Restored(3,'real-ticket',{characterId='jane',sessionId='session',epoch='new'}).ok)
assert(c.Status(3).phase=='active')
print('PASS actual coordinator overlap/stale acknowledgement refusal preserves first ticket and normal restoration')
