dofile('server/services/native_equipment_transition.lua')
local old={characterId='Jane',sessionId='s',epoch='old'}
local fresh={characterId='Jane',sessionId='s',epoch='new'}
local spec={characterId='Jane',action='unequip',slot='weapon',expected={weapon={itemId=112,revision=1}}}
local function scenario(boundary,outcome)
 local coordinator
 local writes,rebuilds=0,0
 local api={enabled=function() return true end,
  prepare=function() if boundary=='prepare' then coroutine.yield('pause') end; return {ok=true,value={identity=old,spec=spec}} end,
  current=function() return true end,ticket=function() return 'ticket' end,
  requestRelease=function() if boundary=='release' then coroutine.yield('pause') end; return true end,
  released=function() if boundary=='release-check' then coroutine.yield('pause') end; return true end,
  commit=function(context,request)
   assert(coordinator.CanCommit(context,request))
   if boundary=='commit' then
    writes=writes+1; coroutine.yield('pause')
    if outcome=='uncertain' then error('lost transaction result') end
    if outcome=='malformed' then return nil end
    return {ok=true}
   end
   writes=writes+1; return {ok=true}
  end,
  rebuild=function() rebuilds=rebuilds+1; if boundary=='rebuild' then coroutine.yield('pause') end; return {ok=true,value=fresh} end,
  restored=function() if boundary=='restore-check' then coroutine.yield('pause') end; return true end}
 coordinator=assert(WeaponNativeEquipmentTransition.New(api))
 local task=coroutine.create(function()
  local begun=coordinator.Begin(1,{})
  if not begun.ok then return begun end
  local released=coordinator.Released(1,'ticket',old)
  if not released.ok then return released end
  return coordinator.Restored(1,'ticket',fresh)
 end)
 local resumed,pause=coroutine.resume(task)
 assert(resumed and pause=='pause',boundary)
 assert(coordinator.Cancel(1,'s'))
 local done,result=coroutine.resume(task)
 assert(done and coroutine.status(task)=='dead' and not result.ok,boundary)
 local state=coordinator.Status(1)
 assert(state.phase=='frozen' and not coordinator.Begin(1,{}).ok,boundary..': no automatic retry')
 if boundary=='commit' then
  assert(writes==1 and rebuilds==0,'cancelled commit must not rebuild')
  assert(state.commitOutcome==(outcome=='confirmed' and 'confirmed' or 'uncertain'))
  assert(state.committed==(outcome=='confirmed'),'late confirmed result preserved even after cancellation')
 elseif boundary=='rebuild' or boundary=='restore-check' then
  assert(writes==1 and rebuilds==1 and state.committed and state.commitOutcome=='confirmed')
 else assert(writes==0 and rebuilds==0,'pre-write cancellation cannot reach commit') end
 assert(not coordinator.Released(1,'ticket',old).ok and not coordinator.Restored(1,'ticket',fresh).ok)
end
for _,boundary in ipairs({'prepare','release','release-check','commit','rebuild','restore-check'}) do scenario(boundary,'confirmed') end
scenario('commit','uncertain')
scenario('commit','malformed')
print('Native equipment cancellation PASS (yield boundaries, pre-write refusal, late commit evidence, uncertainty, no rebuild/retry)')
