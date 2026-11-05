dofile('client/character_ammunition_lifecycle.lua'); dofile('client/character_ammunition_driver.lua')
local now,ped,life,current,ticks,deathCalls,blocked=0,1,'alive',true,0,0,false
local state={phase='closed'}
local host={Status=function() return state end,Receive=function() state={phase='active',session={ammo={}}}; return true end,
    Tick=function() ticks=ticks+1; return true end,Suspend=function(why) state.phase='frozen'; state.reason=why end,
    FinalizeDeath=function() deathCalls=deathCalls+1; return nil,'death_context_not_ready' end,
    RecoverDeath=function() return true end}
local api={ped=function() return ped end,identity=function() return current and {characterId='c',sessionId='s'} end,
    life=function() return life end,now=function() return now end,block=function(value) blocked=value end}
local driver=assert(WeaponCharacterAmmoDriver.New(host,api))
assert(not driver.Receive({runtime={characterId='c',sessionId='s'}},false) and state.phase=='closed')
assert(driver.Receive({runtime={characterId='c',sessionId='s'}},true))
assert(driver.Step() and ticks==1)
for frame=1,15 do now=frame*16; assert(driver.Step()) end
assert(ticks==1,'normal samples must not run every frame')
now=250; assert(driver.Step() and ticks==2)
now=251; life='dead'; assert(not driver.Step() and deathCalls==1 and blocked and ticks==2,
    'native death must bypass sample interval and never ordinary-tick before Medical context')
now=252; ped=2; assert(not driver.Step() and state.phase=='frozen' and blocked)
ped=1; assert(not driver.Step(),'latched identity/ped failure cannot recover automatically')
print('native driver PASS (250ms sampling, frame death/current checks, stale origin/ped fault latch)')
-- Adapter exceptions must not unwind the frame runner or automatically heal.
for _,failure in ipairs({'clock','status','tick','life','suspend'}) do
    local broken=false
    state={phase='closed'}; ped=1; current=true; life='alive'; now=0; blocked=false
    local originalStatus,originalTick,originalSuspend=host.Status,host.Tick,host.Suspend
    local originalNow,originalLife=api.now,api.life
    host.Status=function() if broken and failure=='status' then error('status') end; return originalStatus() end
    host.Tick=function() if broken and failure=='tick' then error('tick') end; return originalTick() end
    host.Suspend=function(why) if failure=='suspend' then error('suspend') end; return originalSuspend(why) end
    api.now=function() if broken and (failure=='clock' or failure=='suspend') then error('clock') end; return originalNow() end
    api.life=function() if broken and failure=='life' then error('life') end; return originalLife() end
    local guarded=assert(WeaponCharacterAmmoDriver.New(host,api))
    assert(guarded.Receive({runtime={characterId='c',sessionId='s'}},true))
    broken=true
    local called,result=pcall(guarded.Step)
    assert(called and not result and blocked,'adapter exception must block without unwinding: '..failure)
    broken=false
    assert(not guarded.Step(),'adapter exception must remain latched: '..failure)
    host.Status,host.Tick,host.Suspend=originalStatus,originalTick,originalSuspend
    api.now,api.life=originalNow,originalLife
end
print('native driver exception safety PASS (clock/status/tick/life/suspend faults latch firing block)')
state={phase='closed'}; ped=1; current=true; life='alive'; now=0; blocked=false
local originalTick=host.Tick
host.Tick=function() coroutine.yield('checkpoint_wait'); return true end
local serialized=assert(WeaponCharacterAmmoDriver.New(host,api))
assert(serialized.Receive({runtime={characterId='c',sessionId='s'}},true))
local thread=coroutine.create(serialized.Step)
local resumed,wait=coroutine.resume(thread)
assert(resumed and wait=='checkpoint_wait' and serialized.Status().stepping)
local result,why=serialized.Step()
assert(not result and why=='driver_step_in_flight' and blocked)
result,why=serialized.Receive({runtime={characterId='c',sessionId='s'}},true)
assert(not result and why=='driver_step_in_flight','receive cannot overlap yielded checkpoint')
assert(coroutine.resume(thread)); assert(not serialized.Status().stepping)
host.Tick=originalTick
now=250; assert(serialized.Step(),'completed step must release serialization guard')
-- Receive also yields during native creation; frames must wait without ticking.
state={phase='closed'}
local originalReceive=host.Receive
host.Receive=function(...) coroutine.yield('creation_wait'); return originalReceive(...) end
local opening=assert(WeaponCharacterAmmoDriver.New(host,api))
local creation=coroutine.create(function() return opening.Receive({runtime={characterId='c',sessionId='s'}},true) end)
resumed,wait=coroutine.resume(creation)
assert(resumed and wait=='creation_wait')
result,why=opening.Step(); assert(not result and why=='driver_receiving')
result,why=opening.Receive({runtime={characterId='c',sessionId='s'}},true)
assert(not result and why=='driver_receiving')
assert(coroutine.resume(creation)); assert(opening.Step())
host.Receive=originalReceive
print('native driver serialization PASS (yielded checkpoint/creation reject overlapping operations)')
state={phase='closed'}; now=0
host.Tick=function() coroutine.yield('checkpoint_wait'); return true end
local changed=assert(WeaponCharacterAmmoDriver.New(host,api))
assert(changed.Receive({runtime={characterId='c',sessionId='s'}},true))
thread=coroutine.create(changed.Step); assert(coroutine.resume(thread))
ped=2
local completed,accepted,reason=coroutine.resume(thread)
assert(completed and not accepted and reason=='driver_identity_or_ped_changed' and blocked)
ped=1; assert(not changed.Step(),'identity change during yield remains latched')
host.Tick=originalTick
print('native driver post-yield identity PASS')
