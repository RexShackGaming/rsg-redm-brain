Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,NativeThrowableQuantityContract=1,AmmunitionPools={enabled=false},DevMode=false}
GetConvarInt=function(name) return name=='feather_throwable_quantities' and 1 or 0 end
for _,p in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_ammunition_item.lua',
 'shared/character_ammunition_materialization.lua','shared/character_ammunition_loadout_lease.lua','shared/character_ammunition_runtime.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local registered={};local alive,current,bucket=true,true,0
local commands,output={},{}
RegisterCommand=function(name,fn) commands[name]=fn end
local expiryEnabled=false
local distanceEnabled=false
local bucketEnabled=false
GetConvar=function(name,default)
 if name=='feather_quantity_distance_test' then return distanceEnabled and '1' or '0' end
 if name=='feather_quantity_bucket_test' then return bucketEnabled and '1' or '0' end
 return name=='feather_quantity_expiry_test' and (expiryEnabled and '1' or '0') or default
end
local clock=1000;os.time=function() return clock end
json={encode=function(v) return v.phase end}
GetGameTimer=function() return 100 end
GetPlayerPed=function(source) assert(source==1);return 7 end
GetEntityCoords=function(ped) assert(ped==7);return {x=1,y=2,z=3} end
GetPlayerRoutingBucket=function() return bucket end
GetInvokingResource=function() return 'feather-inventory' end
AddEventHandler=function() end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='john',sessionId='s'}} end,IsSessionCurrent=function() return current end}
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local db={revision=0,pools={}};for id in pairs(registry.limits) do db.pools[id]=0 end
local function quantity(context)
 return {contract=3,kind='throwable_quantity',characterId='john',identity={characterId='john',sessionId='s',epoch=context.epoch},revision=db.revision,pools=copy(db.pools)}
end
local counts={observe=0,pickup=0,transfer=0};local allow=true
local lastExpiry
local lastDistance
local lastBucketTest
local inventory={GetCharacterFirearmRuntimeSnapshot=function(_,context)
 return {ok=true,value={characterId='john',revision=db.revision,pools=copy(db.pools),equipment={},throwableEquipment=quantity(context)}}
end}
local function save(pools)
 db.revision=db.revision+1;db.pools=copy(pools)
 return {ok=true,value={characterId='john',revision=db.revision,pools=copy(db.pools)}}
end
inventory.MutateCharacterAmmunition=function(_,context,spec)
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'transfer',spec))
 counts.transfer=counts.transfer+1;local pools=copy(db.pools);pools[spec.ammunitionId]=pools[spec.ammunitionId]+spec.amount;return save(pools)
end
inventory.ObserveCharacterAmmunition=function(_,context,spec)
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec))
 local forged=copy(spec);forged.quantityRecovery.position.x=100
 assert(not registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',forged),'reserved server location immutable')
 forged=copy(spec)
 if spec.quantityRecovery.expiryTestSeconds==5 then forged.quantityRecovery.expiryTestSeconds=nil
 else forged.quantityRecovery.expiryTestSeconds=5 end
 assert(not registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',forged),'test expiry must match the reserved server operation')
 assert(spec.quantityRecovery.bucket==0 and spec.quantityRecovery.position.x==1)
 lastExpiry=spec.quantityRecovery.expiryTestSeconds
 lastDistance=spec.quantityRecovery.distanceTestOffset
 lastBucketTest=spec.quantityRecovery.bucketTest
 forged=copy(spec)
 if spec.quantityRecovery.bucketTest==true then forged.quantityRecovery.bucketTest=nil
 else forged.quantityRecovery.bucketTest=true end
 assert(not registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',forged),'bucket test must match server reservation')
 forged=copy(spec)
 if spec.quantityRecovery.distanceTestOffset==100 then forged.quantityRecovery.distanceTestOffset=nil
 else forged.quantityRecovery.distanceTestOffset=100 end
 assert(not registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',forged),'distance tag must be reserved')
 counts.observe=counts.observe+1;return save(spec.pools)
end
inventory.ReconcileNativeThrowablePickup=function(_,context,spec)
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'pickup',spec))
 assert(spec.nativePickupPlan.version==2 and spec.nativePickupPlan.location.bucket==0)
 counts.pickup=counts.pickup+1
 local accepted=copy(spec.pools);if not allow then accepted.ammo_tomahawk_regular=db.pools.ammo_tomahawk_regular end
 local recovered=accepted.ammo_tomahawk_regular-db.pools.ammo_tomahawk_regular
 local result=save(accepted);result.value.quantityDeclined=not allow;result.value.recovered=recovered;return result
end
exports=setmetatable({['feather-inventory']=inventory,['feather-medical']={ReadNativeWeaponCondition=function()
 return {ok=true,value={lifeState=alive and 'alive' or 'dead',revision=0}} end}},
 {__call=function(_,name,fn) registered[name]=fn end})
WeaponNativeThrowablePickupServer={Ready=function() error('quantity mode cannot publish a physical recovery challenge') end}
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local start=S.OpenLoadout(1,WeaponDefinitionCatalog,registry.limits)
local opened=assert(start.value,start.error and start.error.code)
assert(opened.throwable.contract==3 and opened.throwable.units==nil and opened.throwable.equipment==nil)
assert(S.ConfirmRestore(1,opened.runtime).ok and not S.IsNativeItemBound(113) and S.ValidateLoadout(1).ok)
local live=assert(S.Transfer(1,opened.runtime,'ammo_tomahawk_regular',2,'paid-loose-ammo').value)
assert(live.phase=='restoring' and live.pools.ammo_tomahawk_regular==2 and S.ConfirmRestore(1,live).ok)
live.phase='active';local report=copy(live);report.pools.ammo_tomahawk_regular=1
live=assert(S.Observe(1,report).value)
assert(live.pools.ammo_tomahawk_regular==1 and counts.observe==1 and S.ValidateLoadout(1).ok)
report=copy(live);report.pools.ammo_tomahawk_regular=2
live=assert(S.NativePickup(1,report).value)
assert(live.phase=='active' and live.pools.ammo_tomahawk_regular==2 and counts.pickup==1 and S.ValidateLoadout(1).ok)
allow=false;report=copy(live);report.pools.ammo_tomahawk_regular=3
local refused=S.NativePickup(1,report)
assert(refused.ok and refused.quantityDeclined and refused.value.pools.ammo_tomahawk_regular==2
 and refused.value.revision==live.revision+1 and S.ValidateLoadout(1).ok,'definite no-credit response leaves session active')
live=refused.value;alive=false;report=copy(live);report.pools.ammo_tomahawk_regular=3
assert(not S.NativePickup(1,report).ok and counts.pickup==2,'dead player cannot dispatch quantity claim')
alive=true
local savedPrint=print;print=function(line) output[#output+1]=line end
local command=assert(commands.WeaponQuantityExpiryTest)
command(0,{'arm','1'});assert(output[#output]:find('REFUSED',1,true),'explicit switch required')
expiryEnabled=true
command(1,{'arm','1'});assert(output[#output]:find('REFUSED',1,true),'player command ignored')
command(0,{'arm','1'});assert(output[#output]:find('ARMED',1,true))
command(0,{'arm','1'});assert(output[#output]:find('REFUSED',1,true),'cannot silently replace an armed test')
report=copy(live);report.pools.ammo_tomahawk_regular=1
live=assert(S.Observe(1,report).value)
assert(lastExpiry==5 and output[#output]:find('debit_confirmed',1,true))
report=copy(live);report.pools.ammo_tomahawk_regular=2
local expired=S.NativePickup(1,report);live=expired.value
assert(expired.ok and expired.quantityDeclined and output[#output]:find('pickup_declined',1,true))
report=copy(live);report.pools.ammo_tomahawk_regular=0
live=assert(S.Observe(1,report).value);assert(lastExpiry==nil,'next normal spend is not shortened')
command(0,{'cancel','1'})
live=assert(S.Transfer(1,live,'ammo_tomahawk_regular',1,'expiry-test-funding').value)
assert(S.ConfirmRestore(1,live).ok);live.phase='active'
command(0,{'arm','1'});clock=1061
report=copy(live);report.pools.ammo_tomahawk_regular=0
live=assert(S.Observe(1,report).value);assert(lastExpiry==nil,'arming expires after 60 seconds')
command(0,{'cancel','1'});expiryEnabled=false
live=assert(S.Transfer(1,live,'ammo_tomahawk_regular',2,'distance-test-funding').value)
assert(S.ConfirmRestore(1,live).ok);live.phase='active'
local distanceCommand=assert(commands.WeaponQuantityDistanceTest)
distanceCommand(0,{'arm','1'});assert(output[#output]:find('REFUSED',1,true))
distanceEnabled=true
distanceCommand(1,{'arm','1'});assert(output[#output]:find('REFUSED',1,true),'player source ignored')
distanceCommand(0,{'arm','1'});assert(output[#output]:find('ARMED',1,true))
command(0,{'arm','1'});assert(output[#output]:find('REFUSED',1,true),'one shared test reservation per player')
report=copy(live);report.pools.ammo_tomahawk_regular=1
live=assert(S.Observe(1,report).value)
assert(lastDistance==100 and lastExpiry==nil and output[#output]:find('[WeaponQuantityDistanceTest] debit_confirmed',1,true))
report=copy(live);report.pools.ammo_tomahawk_regular=2
local distant=S.NativePickup(1,report);live=distant.value
assert(distant.ok and distant.quantityDeclined and output[#output]:find('[WeaponQuantityDistanceTest] pickup_declined',1,true))
report=copy(live);report.pools.ammo_tomahawk_regular=0
live=assert(S.Observe(1,report).value);assert(lastDistance==nil and lastExpiry==nil,'distance mode is one-shot')
distanceCommand(0,{'cancel','1'});distanceEnabled=false
live=assert(S.Transfer(1,live,'ammo_tomahawk_regular',2,'bucket-test-funding').value)
assert(S.ConfirmRestore(1,live).ok);live.phase='active'
local bucketCommand=assert(commands.WeaponQuantityBucketTest)
bucketCommand(0,{'arm','1'});assert(output[#output]:find('REFUSED',1,true))
bucketEnabled=true
bucketCommand(1,{'arm','1'});assert(output[#output]:find('REFUSED',1,true),'player cannot arm bucket test')
bucketCommand(0,{'arm','1'});assert(output[#output]:find('ARMED',1,true))
distanceCommand(0,{'arm','1'});assert(output[#output]:find('REFUSED',1,true),'test modes remain exclusive')
report=copy(live);report.pools.ammo_tomahawk_regular=1
live=assert(S.Observe(1,report).value)
assert(lastBucketTest==true and lastDistance==nil and lastExpiry==nil
 and output[#output]:find('[WeaponQuantityBucketTest] debit_confirmed',1,true))
report=copy(live);report.pools.ammo_tomahawk_regular=2
local isolated=S.NativePickup(1,report);live=isolated.value
assert(isolated.ok and isolated.quantityDeclined and output[#output]:find('[WeaponQuantityBucketTest] pickup_declined',1,true))
report=copy(live);report.pools.ammo_tomahawk_regular=0
live=assert(S.Observe(1,report).value);assert(lastBucketTest==nil,'bucket test affects only next single debit')
bucketCommand(0,{'cancel','1'});bucketEnabled=false
print=savedPrint
print('PASS actual quantity service: empty activation, ordinary funding, signed spend location, pickup/no-credit active ack, no physical item lease/challenge, current-life gates; modeled Inventory provider')
