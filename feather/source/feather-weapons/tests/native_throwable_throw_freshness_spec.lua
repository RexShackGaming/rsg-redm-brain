dofile('client/native_throwable_throw_freshness.lua')
local function fixture()
 local world={characterId='j',sessionId='s',epoch='e',ped=7,alive=true};local n,t,obj=3,0,nil
 local api={world=function() return world end,quantity=function() return n end,now=function() return t end,probe=function() return obj end}
 local f=WeaponNativeThrowableThrowFreshness.New(api)
 return f,world,api,function(q,time,o) n=q;t=time;obj=o end
end
local object={entity=8,model=3358573347,networked=true,networkId=9}
local f,w,api,set=fixture();f.Tick();set(2,100,object);f.Tick()
assert(f.Candidate(w).entity==8)
set(1,200,{entity=10});f.Tick();assert(f.Candidate(w).entity==8,'second object never replaces capture')
w.sessionId='new';assert(not f.Candidate(w))
for _,mode in ipairs({'old','gap','multi','missing','early','increase'}) do
 local f,w,api,set=fixture()
 if mode=='old' then set(3,0,object);f.Tick();assert(f.Status().phase=='baseline' and not f.Candidate(w))
 else
  f.Tick()
  if mode=='gap' then set(2,300,object) elseif mode=='multi' then set(1,100,object)
  elseif mode=='missing' then set(2,100,nil) elseif mode=='early' then set(3,100,object)
  else set(4,100,object) end
  f.Tick();assert(f.Status().phase=='review_required' and not f.Candidate(w),mode)
 end
end
local pending,pw,_,change=fixture();pw.revision=8;pending.Tick()
pw.busy=true;pw.observationBusy=false
change(2,50,object);pending.Tick()
assert(pending.Candidate(pw).entity==8 and pending.Matches('observe:8'),
 'in-flight server observation cannot hide the short-lived projectile')
pw.observationBusy=true;change(1,100,{entity=99});pending.Tick()
assert(pending.Candidate(pw).entity==8,'rebuild cannot replace captured evidence')
print('PASS pre-throw freshness: empty baseline, one observed unit decrease, bounded sampling gap, immutable capture and ambiguity refusal')
