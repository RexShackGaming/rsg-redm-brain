dofile('server/services/native_equipment_transition.lua')
local normal={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=false,DevMode=false}
assert(WeaponNativeShutdownDrain.RuntimeAvailable(normal,'missing'),'fresh release can shut down without retired proof or optional wear')
assert(WeaponNativeShutdownDrain.RuntimeAvailable(normal,'stopped'))
for _,proof in ipairs({'started','starting','stopping','unknown','uninitialized'}) do
 assert(not WeaponNativeShutdownDrain.RuntimeAvailable(normal,proof),'competing/uncertain proof must not be treated as inactive')
end
normal.CharacterAmmoTransportEnabled=false
assert(not WeaponNativeShutdownDrain.RuntimeAvailable(normal,'missing'))
local function fixture()
 local rows={{source=1,characterId='Jane',sessionId='j',epoch='je'},
             {source=2,characterId='John',sessionId='n',epoch='ne'}}
 local states={[1]={phase='active',sessionId='j'},[2]={phase='active',sessionId='n'}}
 local queue,reports,calls={},{},{}
 local now=0
 local reject,throws=false,false
 local drain=WeaponNativeShutdownDrain.New({now=function() return now end,
  roster=function() return rows end,status=function(s) return states[s] end,
  begin=function(s,bound)
   assert(bound.sessionId==states[s].sessionId)
   calls[#calls+1]=s
   if throws then error('uncertain') end
   if reject then return {ok=false} end
   states[s].phase='releasing'; return {ok=true}
  end,
  schedule=function(fn) queue[#queue+1]=fn end,
  report=function(s) reports[#reports+1]=s end})
 return {drain=drain,rows=rows,states=states,calls=calls,reports=reports,
  tick=function() local fn=table.remove(queue,1); assert(fn); fn() end,
  time=function(t) now=t end,reject=function() reject=true end,throws=function() throws=true end}
end
local f=fixture()
assert(not f.drain.IsLatched() and f.drain.Status().phase=='idle')
assert(f.drain.Begin() and f.drain.IsLatched())
assert(not f.drain.Begin())
f.tick(); assert(#f.calls==1 and f.calls[1]==1)
f.tick(); assert(#f.calls==1,'no release retry while waiting')
f.states[1].phase='parked'; f.states[1].commitOutcome='confirmed'
f.tick(); f.tick(); assert(f.calls[2]==2 and #f.reports==0)
f.states[2].phase='parked'; f.states[2].commitOutcome='confirmed'
f.tick(); f.tick(); assert(f.drain.Status().phase=='ready' and f.drain.Status().completed==2)
f.rows[2].sessionId='replacement'; f.tick()
assert(f.drain.Status().phase=='failed' and f.drain.IsLatched(),'ready invalidates after identity replacement')
for _,kind in ipairs({'busy','disconnect','refused','uncertain','timeout','frozen','new_owner','epoch'}) do
 f=fixture()
 if kind=='busy' then f.states[2].phase='writing'; assert(not f.drain.Begin()); assert(#f.calls==0)
 else
  assert(f.drain.Begin())
  if kind=='disconnect' then table.remove(f.rows,2)
  elseif kind=='refused' then f.reject()
  elseif kind=='uncertain' then f.throws()
  elseif kind=='timeout' then f.time(90000)
  elseif kind=='frozen' then f.states[1].phase='frozen'
  elseif kind=='new_owner' then f.rows[3]={source=3,characterId='Other',sessionId='o',epoch='oe'}
  elseif kind=='epoch' then f.rows[1].epoch='changed' end
  f.tick()
 end
 assert(f.drain.Status().phase=='failed' and f.drain.IsLatched(),kind)
 for _,r in ipairs(f.reports) do assert(r.phase~='ready',kind..' false success') end
 assert(not f.drain.Begin(),'failed latch cannot retry')
end
f=fixture(); for _,s in pairs(f.states) do s.phase='parked'; s.commitOutcome='confirmed' end
assert(f.drain.Begin()); f.tick(); f.tick(); f.tick()
assert(f.drain.Status().phase=='ready' and #f.calls==0,'already prepared owners are not repeated')
print('Native shutdown drain PASS (sequential release, aggregate confirmation, one-way latch, roster/session/epoch drift, no retry)')
-- Independent deadline cannot be undone by a late yielding roster adapter.
local expire
local late=WeaponNativeShutdownDrain.New({now=function() return 0 end,
 deadline=function(fn) expire=fn end,
 roster=function() expire(); return {} end,
 report=function(s) assert(s.phase=='failed') end,
 schedule=function() error('timed-out drain cannot resume') end})
assert(not late.Begin() and late.Status().phase=='failed' and late.IsLatched())
-- All-player access must also drain every owner, without the former two-person cap.
f=fixture()
for id=3,5 do
 local session='session-'..id
 f.rows[#f.rows+1]={source=id,characterId='character-'..id,sessionId=session,epoch='epoch-'..id}
 f.states[id]={phase='active',sessionId=session}
end
assert(f.drain.Begin())
for id=1,5 do
 while #f.calls<id do f.tick() end
 assert(f.calls[id]==id)
 f.states[id].phase='parked';f.states[id].commitOutcome='confirmed'
end
while f.drain.Status().phase~='ready' do f.tick() end
assert(f.drain.Status().completed==5 and f.drain.Status().total==5 and #f.calls==5)
print('All-player shutdown PASS (five owners, sequential one-shot release, aggregate confirmation)')
