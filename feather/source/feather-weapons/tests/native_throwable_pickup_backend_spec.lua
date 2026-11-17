for _,file in ipairs({'shared/native_acceptance_view.lua','server/services/native_throwable_pickup_claims.lua',
 'server/services/native_throwable_pickup_placement.lua','server/services/native_throwable_pickup_offer_feed.lua',
 'server/services/native_throwable_pickup_backend.lua'}) do dofile(file) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local actor={characterId='jane',sessionId='sid',epoch='old',alive=true,bucket=1,position={x=0,y=0,z=0}}
local origin={characterId='john',sessionId='donor',epoch='donor-epoch'}
local saved={version=3,kind='paid_tomahawk_pickup',phase='available',pickupId='pickup',pickupRevision=0,itemId=42,itemRevision=7,
 origin=origin,metadata={serialNumber='original'},bucket=1,position={x=1,y=0,z=0}}
local time,writes,begins=0,0,0;local transition,backend;local sent={}
local api={enabled=function() return true end,actor=function() return copy(actor) end,now=function() return time end,
 readBinding=function(id) if id==saved.pickupId then return copy(saved) end end,
 readPage=function() return {bindings=saved.phase=='available' and {copy(saved)} or {},scanned=1,hasMore=false,cursor='pickup'} end,
 sendOffers=function(_,value) sent[#sent+1]=value end,reply=function() end,
 readSpent=function() return {custody='spent',operationId='spend',itemId=99,itemRevision=2,
  origin={characterId='jane',sessionId='sid',epoch='fresh'},metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid-99'}} end,
 newId=function() return 'pickup-99' end}
api.beginPickup=function(source,binding,identity,current)
 assert(source==1 and binding.pickupId=='pickup' and binding.id==nil and binding.revision==nil
  and binding.metadata.serialNumber=='original' and current())
 begins=begins+1;transition={phase='pending',collector=copy(identity)};return {ok=true}
end
api.wait=function(ms)
 time=time+ms;assert(begins==1)
 saved.phase='claimed';actor.epoch='fresh'
 transition.phase='claimed';transition.id='pickup';transition.revision=0;transition.itemId=42;transition.identity=copy(actor)
end
api.pickupStatus=function() return copy(transition) end
api.persistBinding=function(source,record)
 assert(backend.ValidateBinding(source,record));writes=writes+1;saved=copy(record);return copy(record)
end
backend=WeaponNativeThrowablePickupBackend.New(api)
assert(backend.Offers(1).phase=='pending');assert(backend.Step())
assert(sent[#sent].pickups[1].id=='pickup' and not sent[#sent].pickups[1].metadata)
local result=backend.Claim(1,{id='pickup',revision=0})
assert(result.phase=='claimed' and result.identity.epoch=='fresh' and begins==1 and #sent[#sent].pickups==0)
assert(backend.Place(1,{itemId=99,itemRevision=2,spendOperationId='spend',position={x=2,y=0,z=0}}).phase=='available')
assert(writes==1 and saved.pickupId=='pickup-99' and saved.metadata.serialNumber=='paid-99' and saved.networkId==nil)
assert(not backend.ValidateBinding(1,saved),'write authority is retired after known persistence')
assert(backend.Step());assert(backend.Offers(1).phase=='updated' and sent[#sent].pickups[1].id=='pickup-99')
backend.Forget(1)
api.beginPickup=function() return {ok=false,error={code='pickup_wear_snapshot_unavailable'}} end
api.pickupStatus=function() return nil end
local refused=backend.Claim(1,{id='pickup-99',revision=0})
assert(refused.phase=='refused' and refused.code=='pickup_wear_snapshot_unavailable' and writes==1)
print('PASS assembled pickup backend: real claim/placement/feed modules, metadata preservation, reservation filtering, fresh-epoch completion and durable binding authority')
