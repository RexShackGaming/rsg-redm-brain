-- Real transition -> paid binding -> offer -> collector reservation composition.
-- SQL and equipment transaction ports are modeled; their own suites verify CAS.
for _,p in ipairs({'native_throwable_transition_binding','native_throwable_transition_protocol',
 'native_throwable_pickup_claims','native_throwable_pickup_placement','native_throwable_pickup_offer_feed',
 'native_throwable_pickup_backend'}) do dofile('server/services/'..p..'.lua') end
dofile('shared/native_acceptance_view.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local clock,writes,claims=0,0,0
local actors={
 [1]={characterId='donor',sessionId='s',epoch='e',alive=true,bucket=0,position={x=0,y=0,z=0}},
 [2]={characterId='collector',sessionId='t',epoch='f',alive=true,bucket=0,position={x=1,y=0,z=0}}}
local origin={characterId='donor',sessionId='s',epoch='e'}
local spend={custody='spent',operationId='observe:4',itemId=42,itemRevision=8,origin=origin,
 metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid-42',condition=91,flags={stolen=true}}}
local rows={
 [10]={exists=true,networkId=30,netType=23,owner=1,bucket=0},
 [11]={exists=true,networkId=31,netType=8,owner=1,bucket=0}}
local stored,result,offers,backend
local function actor(s) return actors[s] end
backend=WeaponNativeThrowablePickupBackend.New({enabled=function() return true end,actor=actor,
 now=function() return clock end,wait=function(ms) clock=clock+ms end,newId=function() return 'paid-pickup' end,
 readBinding=function() return copy(stored) end,readSpent=function() return copy(spend) end,
 readPage=function() return {bindings=stored and stored.phase=='available' and {copy(stored)} or {},scanned=stored and 1 or 0,hasMore=false} end,
 persistBinding=function(source,b)
  assert(source==1 and backend.ValidateBinding(source,b),'exact live binding writer required')
  assert(b.itemId==42 and b.itemRevision==8 and b.metadata.serialNumber=='paid-42' and b.metadata.flags.stolen)
  writes=writes+1;stored=copy(b);return copy(b)
 end,
 beginPickup=function(source,b,identity,current)
  assert(source==2 and identity.characterId=='collector' and current())
  claims=claims+1;stored.phase='claimed'
  result={phase='claimed',id=b.pickupId,revision=b.pickupRevision,itemId=b.itemId,collector=copy(identity)}
  return {ok=true}
 end,pickupStatus=function() return copy(result) end,
 sendOffers=function(_,snapshot) offers=snapshot end,reply=function() end})
local token=0
local protocol=WeaponNativeThrowableTransitionProtocol.New({actor=actor,now=function() return clock end,
 read=function(h) return rows[h] end,spend=function() return copy(spend) end,
 challenge=function() return {identity=origin,operationId='observe:4',units={{itemId=42,itemRevision=8}}} end,
 newId=function() token=token+1;return 'token-'..token end,place=backend.Place,readPlacement=backend.ReadPlacement})
assert(protocol.Created(10));clock=100;assert(protocol.Created(11))
rows[10].exists=false;protocol.Removed(10)
local linked=protocol.Handle(1,'transition',{id='throw',projectileNetworkId=30,pickupNetworkId=31})
assert(linked.phase=='transition_authorized' and writes==0)
local authorized=protocol.Handle(1,'landing',{id='throw',position={x=1,y=0,z=0},transitionToken=linked.transitionToken})
assert(authorized.phase=='cleanup_authorized')
assert(protocol.Handle(1,'cleaned',{id='throw',cleanupToken=authorized.cleanupToken}).phase=='pending' and writes==0)
rows[11].exists=false;protocol.Removed(11)
local published=protocol.Handle(1,'status',{id='throw'})
assert(published.phase=='available' and writes==1 and stored.itemId==42)
assert(protocol.Handle(1,'status',{id='throw'}).phase=='available' and writes==1)
assert(backend.Step());backend.Offers(2)
assert(#offers.pickups==1 and offers.pickups[1].metadata==nil and offers.pickups[1].itemId==nil)
actors[2].position.x=5
assert(backend.Claim(2,{id='paid-pickup',revision=0}).phase=='refused' and claims==0)
actors[2].position.x=1
assert(backend.Claim(2,{id='paid-pickup',revision=0}).phase=='claimed' and claims==1)
assert(backend.Claim(1,{id='paid-pickup',revision=0}).phase=='refused' and claims==1)
backend.Step();backend.Offers(2);assert(#offers.pickups==0)
print('PASS paid publication composition: server absence before exact serial binding, metadata-free shared offer, distance guard and one collector claim')
