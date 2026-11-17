dofile('client/native_throwable_pickup_prompt.lua')
dofile('client/native_throwable_pickup_visuals.lua')
dofile('client/native_throwable_pickup_permissions.lua')
dofile('client/native_throwable_pickup_lifecycle.lua')
local function fixture()
 local world={alive=true,characterId='jane',sessionId='sid',epoch='epoch',bucket=1,position={x=0,y=0,z=0}}
 local time,claims,reads,props,removed,press=0,0,0,0,0,false
 local policy={w_melee_tomahawk01=true,w_melee_tomahawk02=false}
 local options={world=function() return world end,now=function() return time end,
  claim=function() claims=claims+1;error('lost reply') end,
  readClaim=function() reads=reads+1;return {phase='pending'} end,
  permissions=function() return WeaponNativeThrowablePickupPermissions.New(function(k,v) policy[k]=v end,policy) end,
  visuals=function(current) return WeaponNativeThrowablePickupVisuals.New({world=current,
   create=function() props=props+1;return {entity=props} end,remove=function() removed=removed+1;return true end,
   entity=function(v) return v.entity end}) end,
  prompt=function(ports)
   return WeaponNativeThrowablePickupPrompt.New({world=ports.world,claim=ports.claim,readClaim=ports.readClaim,
    create=function() return 'prompt' end,remove=function() end,enable=function() end,
    label=function(k) return k end,show=function(_,row) return ports.entity(row.id)~=nil end,
    completed=function() return press end})
  end}
 local life=WeaponNativeThrowablePickupLifecycle.New(options)
 return life,world,policy,options,function(t,p) time=t;press=p end,function() return claims,reads,props,removed end
end
local life,w,policy,api,step,counts=fixture()
local rows={{id='one',revision=0,kind='tomahawk',bucket=1,position={x=1,y=0,z=0}}}
assert(life.Start() and not policy.w_melee_tomahawk01 and not policy.w_melee_tomahawk02)
assert(not life.Start() and life.Snapshot(w,1,rows) and not life.Snapshot(w,1,rows))
step(0,true);life.Tick();local c,r,p,d=counts();assert(c==1 and r==1 and p==1)
for t=1,10 do step(t,true);life.Tick() end
c,r=counts();assert(c==1 and r==1,'frames never replay claims or poll every frame')
step(2000,true);life.Tick();c,r=counts();assert(c==1 and r==2)
life.LanguageChanged();w.epoch='new';step(4000,true);life.Tick()
assert(life.Status().phase=='active','same-login pending handoff must survive native epoch change')
w.sessionId='another-login';life.Tick()
assert(life.Status().phase=='closed' and policy.w_melee_tomahawk01 and not policy.w_melee_tomahawk02)
c,r,p,d=counts();assert(d==1 and c==1)
local life,w,policy,api=fixture()
api.visuals=function() error('provider unavailable after suppression') end
assert(not life.Start() and life.Status().phase=='closed' and policy.w_melee_tomahawk01)
print('PASS assembled pickup lifecycle: actual prompt/visual/policy, bounded receipt polling, no claim replay, epoch cleanup and start compensation')
