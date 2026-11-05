dofile('shared/character_ammunition_dispatch.lua')
local session='new'; local sends,opens=0,0
local api={enabled=function() return true end,identity=function() coroutine.yield('identity'); return {characterId='c',sessionId=session} end,
 timeout=function() end,dispatch=function() sends=sends+1 end,
 service={OpenLoadout=function()
  opens=opens+1; coroutine.yield('snapshot')
  local id={characterId='c',sessionId=session,epoch='e'..opens,phase='restoring'}
  return {ok=true,value={runtime=id,creation={identity=id}}}
 end,ValidateLoadout=function() return {ok=true} end,FreezeLoadout=function() end}}
local dispatcher=WeaponCharacterAmmoDispatch.New(api)
local result
local worker=coroutine.create(function() result=dispatcher.Start(1) end)
assert(coroutine.resume(worker)); assert(dispatcher.Forget(1,'old'))
assert(coroutine.resume(worker)); assert(dispatcher.Status(1).identity.sessionId=='new')
assert(not dispatcher.Forget(1,'old') and dispatcher.Forget(1,'new'))
assert(coroutine.resume(worker) and not result.ok and sends==0,'known opening session can cancel a yielded snapshot')
session='cancelled'
worker=coroutine.create(function() result=dispatcher.Start(1) end)
assert(coroutine.resume(worker)); dispatcher.Forget(1,'cancelled')
assert(coroutine.resume(worker) and not result.ok and opens==1,'cancellation while resolving identity cannot reach SQL')
session='fresh'
worker=coroutine.create(function() result=dispatcher.Start(1) end)
assert(coroutine.resume(worker)); dispatcher.Forget(1,'older')
assert(coroutine.resume(worker)); assert(coroutine.resume(worker) and result.ok and sends==1)
print('Dispatch opening retirement PASS (bound Core session before snapshot yield, matching cancellation, late old-session isolation)')
