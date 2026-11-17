joaat=function() return 123 end
dofile('client/native_throwable_landing_capture.lua')
local function fixture(parent)
 local clock,mode,deletes=0,'projectile',0
 local world={characterId='j',sessionId='s',epoch='e',ped=7,alive=true,position={x=0,y=0,z=0}}
 local original={entity=8,model=3358573347,networked=true,networkId=2,captureToken='old'}
 local pickup={entity=9,model=3358573347,networked=true,networkId=18,captureToken='new'}
 local api={world=function() return world end,now=function() return clock end,candidate=function() return original end,
  read=function(object)
   if mode=='lost' then return nil end
   return {entity=object.entity,model=object.model,networked=true,networkId=object.networkId,captureToken=object.captureToken,
    speed=0,position={x=1,y=0,z=0},attached=mode=='pickup',attachmentParent=mode=='pickup' and parent or nil}
  end,
  proposeTransition=function() return {projectileNetworkId=2,pickupNetworkId=18} end,
  acceptTransition=function() mode='pickup';return pickup end,
  authorizeCleanup=function() return true end,
  remove=function(object) assert(object.entity==9 and object.entity~=parent,'never delete the attachment parent');deletes=deletes+1;return true end,
  absent=function() return true end}
 local c=WeaponNativeThrowableLandingCapture.New(api)
 assert(c.Start({id='challenge',identity=world,units={{itemId=42,itemRevision=8}}}))
 c.Tick();clock=50;mode='lost';assert(c.Tick().phase=='transition_pending')
 assert(c.AcceptTransition({id='challenge',transitionToken='server-token',projectileNetworkId=2,pickupNetworkId=18}))
 clock=100
 return c,function(t,p) clock=t;parent=p end,function() return deletes end
end
for _,parent in ipairs({0,500}) do
 local c,set,count=fixture(parent)
 assert(c.Tick().phase=='capturing');set(850,parent);assert(c.Tick().phase=='landed')
 assert(c.Cleanup() and count()==1,'server-authorized marked pickup permits stable engine attachment')
end
local c,set,count=fixture(nil)
assert(c.Tick().reason=='pickup_attachment_unreadable' and count()==0)
local c,set,count=fixture(500);c.Tick();set(850,500);assert(c.Tick().phase=='landed')
set(900,501);assert(not c.Cleanup() and count()==0,'cleanup cannot follow a changed parent')
local c,set,count=fixture(500);c.Tick();set(400,501);assert(c.Tick().phase=='capturing')
set(850,501);assert(c.Tick().phase=='capturing','parent change resets full landing interval')
set(1150,501);assert(c.Tick().phase=='landed' and c.Cleanup() and count()==1)
print('PASS pickup attachment: server-authorized stable parent0/object parent, no parent mutation, unreadable/changed parent refusal and full stability reset')
