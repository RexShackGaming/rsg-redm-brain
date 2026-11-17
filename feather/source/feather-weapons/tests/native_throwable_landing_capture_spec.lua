joaat=function() return 123 end
dofile('client/native_throwable_landing_capture.lua')
local function fixture()
 local time,deletes,authorized=0,0,false
 local world={characterId='jane',sessionId='sid',epoch='epoch',ped=7,alive=true,position={x=0,y=0,z=0}}
 local object={entity=8,model=3358573347,networked=true,networkId=9,captureToken='observed-lifetime'}
 local sample={entity=8,model=3358573347,networked=true,networkId=9,captureToken='observed-lifetime',position={x=1,y=0,z=0},speed=0,attached=false}
 local c;local api={world=function() return world end,now=function() return time end,candidate=function() return object end,
 read=function() return sample end,authorizeCleanup=function() return authorized end,
 remove=function() deletes=deletes+1;assert(not c.Cleanup());return true end,absent=function() return true end}
 c=WeaponNativeThrowableLandingCapture.New(api)
 local challenge={id='challenge',identity={characterId='jane',sessionId='sid',epoch='epoch'},units={{itemId=42,itemRevision=8}}}
 assert(c.Start(challenge));assert(not c.Start(challenge))
 return c,api,world,sample,function(t,a) time=t;authorized=a end,function() return deletes end
end
local c,api,w,s,set,count=fixture()
assert(c.Tick().phase=='capturing');set(749,true);assert(c.Tick().phase=='capturing')
set(750,true);assert(c.Tick().phase=='landed');assert(c.Cleanup() and count()==1)
assert(not c.Cleanup() and count()==1)
for _,mode in ipairs({'unauthorized','changed','attached','moving','far','session','missing','uncertain'}) do
 local c,api,w,s,set,count=fixture();c.Tick();set(750,true);assert(c.Tick().phase=='landed')
 if mode=='unauthorized' then set(750,false) elseif mode=='changed' then s.networkId=10
 elseif mode=='attached' then s.attached=true elseif mode=='moving' then s.speed=1
 elseif mode=='far' then s.position.x=10 elseif mode=='session' then w.sessionId='other'
 elseif mode=='missing' then api.read=function() return nil end
 else api.absent=function() return false end end
 assert(not c.Cleanup() and c.Status().phase=='review_required',mode)
 assert(count()==(mode=='uncertain' and 1 or 0));assert(not c.Cleanup())
end
local c,api,w,s,set=fixture();c.Tick();s.captureToken='reused-handle';assert(c.Tick().phase=='review_required')
local c,api,w,s,set=fixture();set(90000,true);assert(c.Tick().reason=='landing_timeout')
local c,api,w,s,set,count=fixture();api.read=function() w.epoch='replacement';return s end
assert(c.Tick().reason=='capture_owner_changed' and count()==0)
local c,api,w,s,set=fixture();c.Tick()
for i=1,8 do set(i*100,true);s.position.x=1+i*0.02;assert(c.Tick().phase=='capturing','slow cumulative drift must reset landing interval') end
local c,api,w,s,set=fixture();api.read=function() error('native-read-sentinel') end
assert(c.Tick().reason=='capture_read_failed' and c.Status().detail:find('native%-read%-sentinel'))
print('PASS landing capture: exact lifetime, stable landing, independent cleanup authority, no candidate adoption, bounded session/range and one destructive attempt')
