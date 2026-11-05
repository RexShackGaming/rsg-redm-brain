dofile('server/services/native_equipment_transition.lua')
local now,enabled,interval,busy=0,true,60000,false
local id={characterId='c',sessionId='s',epoch='e'}
local status={phase='active',identity=id}
local items={{id=128},{id=129}}
local requests={}
local sampler=WeaponNativePeriodicWear.New({enabled=function() return enabled end,now=function() return now end,
 interval=function() return interval end,status=function() return status end,busy=function() return busy end,
 items=function() return items end,request=function(target,item) requests[#requests+1]=item; return true end})
assert(not sampler.Step(1) and #requests==0)
now=59999; assert(not sampler.Step(1))
now=60000; busy=true; assert(not sampler.Step(1) and #requests==0); busy=false
assert(sampler.Step(1) and requests[1]==128)
assert(not sampler.Step(1) and #requests==1,'one request per interval')
assert(sampler.Complete(1,id,'unchanged') and sampler.Status(1).unchanged==1)
now=120000; assert(sampler.Step(1) and requests[2]==129,'round robin')
assert(sampler.Complete(1,id,'persisted') and sampler.Status(1).persisted==1)
status={phase='sealed',identity=id}; now=180000; assert(not sampler.Step(1) and #requests==2,'dead/sealed skipped')
status={phase='active',identity={characterId='c',sessionId='s',epoch='new'}}
assert(not sampler.Step(1) and sampler.Status(1).persisted==1,'fresh epoch resets due time but keeps same-session counters')
assert(not sampler.Complete(1,id,'persisted'),'late old epoch result cannot count')
assert(not sampler.Forget(1,'old-session') and sampler.Status(1))
now=240000; assert(sampler.Step(1) and requests[3]==128)
interval=1; now=300000; assert(not sampler.Step(1) and #requests==3,'invalid interval fails closed')
interval=60000; enabled=false; assert(not sampler.Step(1) and not sampler.Status(1))
enabled=true; assert(not sampler.Step(1),'reenable establishes new deadline')
items={}; now=360000; assert(not sampler.Step(1) and #requests==3)
assert(sampler.Forget(1,'s') and not sampler.Status(1))
print('Periodic wear scheduler PASS (bounded interval, quiet idle, busy/death skips, one per interval, round robin, fresh-epoch/late/disable/session guards)')
