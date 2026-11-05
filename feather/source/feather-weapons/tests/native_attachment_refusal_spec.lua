dofile('server/services/native_equipment_transition.lua')
local identity={characterId='Jane',sessionId='s',epoch='e'}
local calls,rebuilds=0,0
local function fixture(outcome)
 return assert(WeaponNativeEquipmentTransition.New({enabled=function() return true end,
  prepare=function() return {ok=true,value={identity=identity,spec={characterId='Jane',action='attachment-install'}}} end,
  current=function() return true end,released=function() return true end,
  requestRelease=function() return true end,ticket=function() return 'ticket' end,
  commit=function() calls=calls+1; return outcome end,
  rebuild=function() rebuilds=rebuilds+1; error('refused commit must not rebuild') end,
  restored=function() return false end}))
end
local coordinator=fixture({ok=false,error={code=string.rep('c',200),message=string.rep('m',400),metadata={secret=true}}})
assert(coordinator.Begin(2,{}).ok)
assert(not coordinator.Released(2,'ticket',identity).ok)
local state=coordinator.Status(2)
assert(state.phase=='frozen' and state.commitOutcome=='refused' and not state.committed)
assert(#state.commitRefusal.code==128 and #state.commitRefusal.message==256 and not state.commitRefusal.metadata)
assert(not coordinator.Begin(2,{}).ok and calls==1 and rebuilds==0,'refusal cannot auto retry/refund/rebuild')
state.commitRefusal.code='changed'
assert(coordinator.Status(2).commitRefusal.code~='changed','diagnostics are private snapshots')
coordinator=fixture({ok=false,error={code={},message={}}})
assert(coordinator.Begin(2,{}).ok)
assert(not coordinator.Released(2,'ticket',identity).ok)
assert(coordinator.Status(2).commitOutcome=='refused' and calls==2 and rebuilds==0)
print('Attachment refusal PASS (bounded provider diagnostics, frozen no replay/rebuild, malformed diagnostic fields)')
