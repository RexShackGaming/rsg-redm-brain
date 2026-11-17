dofile('server/services/native_throwable_transition_binding.lua')
dofile('server/services/native_throwable_transition_protocol.lua')
local function fixture()
 local time,reads,places=7119,0,0
 local identity={characterId='j',sessionId='s',epoch='e'}
 local actor={characterId='j',sessionId='s',epoch='e',alive=true,bucket=0,position={x=0,y=0,z=0}}
 local rows={[10]={exists=true,netType=23,networkId=2,owner=1,bucket=0},[20]={exists=true,netType=8,networkId=18,owner=1,bucket=0}}
 local api={now=function() return time end,actor=function() return actor end,read=function(h) return rows[h] end,
  challenge=function() return {identity=identity,operationId='observe:1',units={{itemId=42,itemRevision=8}}} end,
  spend=function() reads=reads+1;return {custody='spent',operationId='observe:1',itemId=42,itemRevision=8,origin=identity,
   metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid'}} end,
  newId=function() return 'token' end,place=function() places=places+1;error('must not publish during readiness') end,readPlacement=function() end}
 local p=WeaponNativeThrowableTransitionProtocol.New(api)
 assert(p.Created(10));time=7295;assert(p.Created(20))
 return p,rows,api,function(t) time=t end,function() return reads,places end
end
local p,rows,api,time,counts=fixture()
time(7296)
assert(p.Handle(1,'transition',{id='challenge',projectileNetworkId=2,pickupNetworkId=18}).phase=='pending')
assert(counts()==0 and p.Diagnostics().reason=='projectile_removal_not_ready')
time(7308);rows[10].exists=false;p.Removed(10)
time(9296);assert(p.Handle(1,'status',{id='challenge'}).phase=='transition_authorized')
local reads,places=counts();assert(reads>0 and places==0)
local d=p.Diagnostics();assert(d.binding.projectile.created==7119 and d.binding.projectile.removed==7308 and d.binding.pickup.created==7295)
local p,rows,api,time,counts=fixture();time(7296)
assert(p.Handle(1,'transition',{id='challenge',projectileNetworkId=2,pickupNetworkId=18}).phase=='pending')
time(12296);local result=p.Handle(1,'status',{id='challenge'})
assert(result.phase=='refused' and result.reason=='transition_lifetime_readiness_timeout' and counts()==0)
-- Actual creation callback was seen, but initial metadata was not yet ready.
local timers={};local clock=100;local owner=0
local api={now=function() return clock end,later=function(delay,fn) timers[delay]=fn end,
 read=function() return {exists=true,netType=23,networkId=7,owner=owner,bucket=0} end,
 actor=function() return {characterId='j',sessionId='s',epoch='e',alive=true,bucket=0} end}
local b=WeaponNativeThrowableTransitionBinding.New(api)
assert(not b.Created(10));assert(b.Diagnostics(7).pendingCreations==1)
clock=200;owner=1;timers[100]()
local d=b.Diagnostics(7);assert(d.projectile.created==100 and d.projectile.owner==1 and d.pendingCreations==0)
timers[500]();assert(b.Diagnostics(7).projectile.generations==1,'deferred reads cannot invent duplicate creation events')
local b=WeaponNativeThrowableTransitionBinding.New({now=function() return 0 end,read=function() error('native-read-sentinel') end})
assert(not b.Created(10) and b.Diagnostics().lastReadError:find('native%-read%-sentinel'))
print('PASS transition readiness: recorded 13ms overlap, pending server removal, bounded status-only completion, no premature receipt/publication, actual-event metadata readiness and detailed native diagnostics')
