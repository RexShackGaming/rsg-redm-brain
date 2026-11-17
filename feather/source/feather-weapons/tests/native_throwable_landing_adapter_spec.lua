joaat=function(name) return name=='w_melee_tomahawk01' and 3358573347 or name=='w_melee_tomahawk02' and 123 or 456 end
dofile('client/native_throwable_landing_capture.lua')
dofile('client/native_throwable_landing_adapter.lua')
local registered,exists,control,mark,time,deletes=true,true,true,nil,0,0
DecorIsRegisteredAsType=function(_,kind) assert(kind==3);return registered end
DecorRegister=function() registered=true end
DecorExistOn=function() return mark~=nil end
DecorSetInt=function(_,_,value) mark=value;return true end
DecorGetInt=function() return mark end
DoesEntityExist=function() return exists end
GetEntityModel=function() return 3358573347 end
NetworkGetEntityIsNetworked=function() return true end
NetworkGetNetworkIdFromEntity=function() return 9 end
NetworkHasControlOfEntity=function() return control end
GetProjectileOfProjectileTypeWithinDistance=function(ped,weapon,radius,unknown,ownedOnly)
 assert(ped==7 and weapon==456 and radius==50 and unknown==false and ownedOnly==true);return true,{},8
end
GetGameTimer=function() return time end
GetEntityCoords=function() return {x=1,y=0,z=0} end
GetEntitySpeed=function() return 0 end
IsEntityAttached=function() return false end
DeleteObject=function(entity) assert(entity==8);deletes=deletes+1;exists=false end
local world={characterId='jane',sessionId='sid',epoch='epoch',ped=7,alive=true,position={x=0,y=0,z=0}}
local authorized=false
local function fresh() return {entity=8,model=3358573347,networked=true,networkId=9} end
local function start()
 mark=nil;exists=true;control=true;time=0
 local c=WeaponNativeThrowableLandingAdapter.New(function() return world end,function() return authorized end,fresh)
 assert(c.Start({id='challenge',identity=world,units={{itemId=42,itemRevision=8}}}))
 assert(c.Tick().phase=='capturing');time=750;assert(c.Tick().phase=='landed');return c
end
local c=start();assert(not c.Cleanup() and deletes==0,'decorator is not deletion authority')
authorized=true;c=start();assert(c.Cleanup() and deletes==1);assert(not c.Cleanup() and deletes==1)
c=start();mark=999;assert(not c.Cleanup() and deletes==1,'reused/mutated lifetime is never deleted')
assert(c.Status().nativeDiagnostic.lastReject=='capture_marker_changed')
c=start();control=false;assert(not c.Cleanup() and deletes==1,'no request for foreign control')
c=start();DeleteObject=function() deletes=deletes+1 end
assert(not c.Cleanup() and deletes==2);assert(not c.Cleanup() and deletes==2,'unconfirmed deletion never repeats')
c=start();NetworkGetNetworkIdFromEntity=function() return 10 end
assert(not c.Cleanup() and deletes==2,'network identity change cannot adopt a replacement')
NetworkGetNetworkIdFromEntity=function() return 9 end
mark=nil;exists=true;control=true;time=0
DecorSetInt=function() return false end
c=WeaponNativeThrowableLandingAdapter.New(function() return world end,function() return true end,fresh)
assert(c.Start({id='challenge',identity=world,units={{itemId=42,itemRevision=8}}}))
assert(c.Tick().phase=='review_required' and deletes==2,'unverified lifetime marker freezes without deleting')
print('PASS native landing adapter: targeted owned lookup, verified decorator continuity, separate deletion authority, control refusal and exact absence')
