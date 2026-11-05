dofile('server/services/native_throwable_projectile_observer.lua')
local time,owner,session,epoch,exists,net,changed=100,2,'s','e',true,90,false
local identity={characterId='john',sessionId='s',epoch='e'}
local observer=WeaponNativeThrowableProjectileObserver.New({bootId='server-boot',weaponHash=42,objectModel=43,
 now=function() return time end,
 session=function(source)
  if source~=2 then return nil end
  return {identity={characterId='john',sessionId=session,epoch=epoch},pedNetworkId=80}
 end,
 entity=function()
  local e={exists=exists,model=43,networkId=net,ownerSource=owner}
  if changed then net=net+1 end; return e
 end})
assert(not observer.ProjectileHint(3,{weaponHash=42,ownerId=80}))
assert(not observer.ProjectileHint(2,{weaponHash=42,ownerId=81}))
assert(observer.ProjectileHint(2,{weaponHash=42,ownerId=80,clientClaimsOrigin=true}))
local first=assert(observer.Created(10))
assert(first.correlatedHint and first.originConfirmed==false and first.pickupCredits==false)
assert(not observer.Created(10),'duplicate callback cannot create a second lifetime')
first.identity.sessionId='changed'; assert(observer.Read(10).identity.sessionId=='s')
observer.Removed(10); assert(not observer.Read(10))
local second=assert(observer.Created(10))
assert(first.instanceId~=second.instanceId and first.networkId==second.networkId,'recycled net/handle receives new lifetime')
owner=3; assert(not observer.Created(11)); owner=2
exists=false; assert(not observer.Created(11)); exists=true
changed=true; assert(not observer.Created(11)); changed=false
time=4000; local expiredHint=assert(observer.Created(11)); assert(not expiredHint.correlatedHint)
epoch='new'; assert(observer.ProjectileHint(2,{weaponHash=42,ownerId=80}))
session='new-session'; local replacement=assert(observer.Created(12)); assert(not replacement.correlatedHint)
time=40001; assert(not observer.Read(10) and not observer.Read(11))
time=1; assert(not observer.Read(12),'clock rollback invalidates observations')
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(not manifest:find('native_throwable_projectile_observer.lua',1,true))
print('inert server projectile observer PASS: bounded hints/lifetimes, owner/session/reuse/expiry checks, never origin proof or pickup credit')
