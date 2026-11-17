dofile('server/services/native_throwable_collection_inventory.lua')
local binds,claims,reads=0,0,0
local current=true
local binding={version=4,presentation='native',kind='paid_tomahawk_native_pickup',pickupId='paid',itemId=109}
local identity={characterId='john',sessionId='collector',epoch='before'}
local authorization={originSource=1,origin={characterId='jane',sessionId='donor',epoch='origin'},binding=binding}
exports={['feather-inventory']={
 BindNativeThrowableNativePickup=function(_,context,record)
  binds=binds+1;assert(context.actorSource==1 and context.characterId=='jane' and context.sessionId=='donor' and context.epoch=='origin')
  assert(record.version==4 and record.itemId==109);return {ok=true,value={binding=record}}
 end,
 ReadNativeThrowableNativeBinding=function(_,id) reads=reads+1;assert(id=='paid');return {ok=true,value=binding} end}}
local settled=false
WeaponNativeEquipmentBindings={NativePickupTransition=function(source,record,bound,live)
 claims=claims+1;assert(source==2 and record.itemId==109 and bound.characterId=='john' and live());return {ok=true}
end,NativePickupTransitionStatus=function(source,id)
 reads=reads+1;assert(source==2 and id=='paid')
 return settled and {phase='claimed',itemId=109} or {phase='pending'}
end}
local ports=WeaponNativeThrowableCollectionInventory.New()
assert(binds==0 and claims==0 and reads==0,'construction performs no cross-resource calls')
assert(ports.bind(authorization,function() return current end).itemId==109)
assert(ports.readBinding(authorization).version==4 and binds==1)
assert(ports.claim(2,binding,identity,function() return current end).phase=='pending' and claims==1)
settled=true
assert(ports.readClaim(2,binding,identity).phase=='claimed' and claims==1,'status cannot repeat transition Begin')
current=false
assert(ports.bind(authorization,function() return current end).phase=='refused' and binds==1)
assert(ports.claim(2,binding,identity,function() return current end).phase=='refused' and claims==1)
exports['feather-inventory'].ReadNativeThrowableNativeBinding=function() return {ok=false} end
assert(not pcall(ports.readBinding,authorization),'unknown storage outcome remains uncertain for receipt-only handoff recovery')
print('PASS concrete native collection Inventory ports: origin writer context, collector released transition, no construction I/O or mutation replay')
