dofile('server/services/native_equipment_transition.lua')
local old={characterId='Jane',sessionId='s',epoch='old'}
local new={characterId='Jane',sessionId='s',epoch='new'}
local spec={characterId='Jane',slot='weapon',action='unequip',expected={weapon={itemId=112,revision=1}}}
local enabled,current,released,active=true,true,false,false
local writes,rebuilds=0,0
local coordinator
local api={enabled=function() return enabled end,prepare=function()
 return {ok=true,value={identity=old,spec=spec}}
end,current=function() return current end,released=function() return released end,
 ticket=function() return 'ticket' end,requestRelease=function() return true end,
 commit=function(context,request)
  assert(coordinator.CanCommit(context,request))
  local bad={characterId='Jane',slot='offhand',action='unequip',expected=spec.expected}
  assert(not coordinator.CanCommit(context,bad))
  writes=writes+1; return {ok=true}
 end,rebuild=function() rebuilds=rebuilds+1; return {ok=true,value=new} end,
 restored=function() return active end}
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
assert(coordinator.Begin(5,{action='unequip'}).ok)
assert(not coordinator.Begin(5,{}).ok and writes==0)
assert(not coordinator.Released(5,'foreign',old).ok and writes==0)
assert(not coordinator.Released(5,'ticket',old).ok and writes==0 and coordinator.Status(5).phase=='frozen')
coordinator=assert(WeaponNativeEquipmentTransition.New(api)); released=true
assert(coordinator.Begin(5,{}).ok)
assert(coordinator.Released(5,'ticket',old).ok and writes==1 and rebuilds==1)
assert(not coordinator.Released(5,'ticket',old).ok and writes==1)
assert(not coordinator.Restored(5,'ticket',old).ok)
active=true
assert(coordinator.Restored(5,'ticket',new).ok and coordinator.Status(5).phase=='active')
assert(not coordinator.Cancel(5,'old-session') and coordinator.Status(5).phase=='active')
assert(coordinator.Cancel(5,'s') and coordinator.Status(5)==nil,'completed logout retires, rather than strands, coordinator')
assert(coordinator.Begin(5,{}).ok,'fresh authoritative preflight is possible after completed logout')
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
api.commit=function() writes=writes+1; error('commit reply lost') end
assert(coordinator.Begin(5,{}).ok)
assert(not coordinator.Released(5,'ticket',old).ok and coordinator.Status(5).reason=='equipment_commit_uncertain_no_retry')
assert(not coordinator.Begin(5,{}).ok and rebuilds==1)
coordinator=assert(WeaponNativeEquipmentTransition.New(api)); current=false
assert(not coordinator.Begin(5,{}).ok and coordinator.Status(5).phase=='frozen')
current=true
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
api.ticket=function() coordinator.Cancel(5,'s'); return 'ticket' end
assert(not coordinator.Begin(5,{}).ok and coordinator.Status(5).phase=='frozen','cancellation during ticket allocation cannot reopen release')
api.ticket=function() return 'ticket' end
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
api.prepare=function()
 coordinator.Cancel(5,'old-session')
 return {ok=true,value={identity=old,spec=spec}}
end
assert(coordinator.Begin(5,{}).ok,'delayed unrelated session during preflight cannot cancel current identity')
coordinator=assert(WeaponNativeEquipmentTransition.New(api))
api.prepare=function()
 coordinator.Cancel(5,'s')
 return {ok=true,value={identity=old,spec=spec}}
end
assert(not coordinator.Begin(5,{}).ok and coordinator.Status(5).phase=='frozen','matching session loss during preflight still cancels')
print('Native equipment transition PASS (server release barrier, scoped CAS ticket, fresh rebuild ack, duplicate/uncertain refusal)')
