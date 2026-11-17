Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','client/character_maintenance_native.lua',
 'client/character_ammunition_native.lua','client/native_throwable_owner.lua','client/native_throwable_adapter.lua'}) do dofile(p) end
local catalog=WeaponDefinitionCatalog
local registry=assert(WeaponNativeThrowablePolicy.Preview(catalog,assert(WeaponCharacterAmmoPolicy.Build(catalog)))).registry
local identity={characterId='john',sessionId='s',epoch='e'}
local metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='T'}))
local snapshot={characterId='john',revision=3,pools={},equipment={throwable={id=170,revision=0,
 itemName='weapon_thrown_tomahawk',metadata=metadata}},expected={weapon_throwable={itemId=170,revision=0}}}
for id in pairs(registry.limits) do snapshot.pools[id]=0 end
snapshot.pools.ammo_tomahawk_regular=1; snapshot.pools.ammo_repeater_regular=1
local native,has,visible,world,guid,hash,entry,grants,setters,removes,sealed
local creationMode,now
local poolRemoves
GetConvarInt=function(name) return name=='feather_native_throwable_pickup' and creationMode:find('pickup',1,true) and 1 or 0 end
Config.DevMode=true
WeaponNativeThrowablePolicy.Enabled=function() return true end -- policy gates covered by policy specs
joaat=function(v) return v=='WEAPON_THROWN_TOMAHAWK' and 42 or v end
PlayerPedId=function() return 7 end
DoesEntityExist=function(entity) return entity==7 or entity==70 end -- projectile can outlive the carrier
HasPedGotWeapon=function() return has end
GetPedAmmoByType=function(_,ammo) return native[ammo] end
SetPedAmmoByType=function(ped,ammo,n)
 assert(ped==7 and ammo=='AMMO_TOMAHAWK' and n==snapshot.pools.ammo_tomahawk_regular,
  'absolute setter is funding-only; reductions require the existing removal primitive')
 setters=setters+1; native[ammo]=n
end
GetCurrentPedWeapon=function(_,_,point) return visible and point==6,42 end
GetCurrentPedWeaponEntityIndex=function(_,point) return visible and point==6 and 70 or 0 end
IsEntityDead=function() return false end
GetGameTimer=function() return now end
Wait=function() assert(creationMode=='hidden_unresolved'); now=now+100 end
GiveWeaponToPed=function(ped,model,n)
 assert(ped==7 and model==42 and n==0,'reuse accepted zero-quantity carrier construction')
 grants=grants+1; has=true; visible=creationMode~='hidden' and creationMode~='hidden_unresolved'; entry=true
 if creationMode=='units_empty_materialization_lost_pool' then native.AMMO_TOMAHAWK=0 end
end
for _,name in ipairs({'SetPedAmmo','SetAmmoInClip','SetCurrentPedWeapon','RemoveWeaponFromPed','DeleteEntity'}) do
 _G[name]=function() error('forbidden mutation '..name) end
end
WeaponCharacterAmmoCreationNative={DecodeDiagnosticGuid=function() return {scriptSlotWords=guid} end,
 DecodeEquippedChild=function(_,result) return result and {itemHash=hash} or nil end}
Citizen={InvokeNative=function(name,inventory,input,n,reason)
 if name==0xB6CFEC32E3742779 then
  assert(inventory==7 and input=='AMMO_TOMAHAWK' and n==native.AMMO_TOMAHAWK and reason==0xA07362E6
   and not entry and not has and n>0,'only exact post-GUID-removal retirement')
  poolRemoves=poolRemoves+1
  if creationMode~='pool_remove_ignored' then native.AMMO_TOMAHAWK=0 end
  return
 end
 if name==0x886DFD3E185C8A89 then
  if n==42 then return entry and (((creationMode=='hidden' or creationMode=='spent_entry_retained'
    or creationMode=='spent_foreign_guid' or creationMode=='prefunded_existing_guid'
    or creationMode=='units_empty_recovery' or creationMode:find('pickup',1,true)) and reason=='SLOTID_WEAPON_0')
    or creationMode=='ambiguous') end
  return true
 end
 if name==0x6929E22158E52265 then return true end
 assert(inventory==1)
 if name==0x9700E8EFC4AB9089 then return entry end
 if name==0x3E4E811480B3AE79 then
  assert(type(input)=='string' and #input==104 and n==1 and reason=='REMOVE_REASON_CLIENT_PURGED')
  removes=removes+1; entry=false; has=false; visible=false
  if creationMode~='pool_retained' and creationMode~='pool_remove_ignored' and creationMode~='units_pool_retained' then native.AMMO_TOMAHAWK=0 end; return true
 end
 error('unexpected native')
end}
local function run(mode)
 creationMode=mode; now=0; poolRemoves=0
 native={}; for id,name in pairs(registry.names) do native[name]=id=='ammo_repeater_regular' and 1 or 0 end
 has=false; visible=false; world=true; guid={1,2,3,4}; hash=42; entry=false; grants=0; setters=0; removes=0
 if mode=='prefunded_belt' or mode=='prefunded_existing_weapon' or mode=='prefunded_existing_guid' then
  native.AMMO_TOMAHAWK=1
  has=mode=='prefunded_existing_weapon'
  entry=mode=='prefunded_existing_guid'
 end
 sealed={characterId='john',sessionId='s',epoch='e',phase='sealed',revision=3,pools={}}
 for id,n in pairs(snapshot.pools) do sealed.pools[id]=n end
 local owner=assert(WeaponNativeThrowableAdapter.Scoped(7,identity,function() return world end,
  function() return sealed end,catalog,registry))
 assert(grants==0 and setters==0 and removes==0,'factory is inert')
 if mode=='units_empty_recovery' or mode=='units_empty_materialization' or mode=='units_empty_materialization_lost_pool' then
  local before={};for k,v in pairs(snapshot) do before[k]=v end
  before.units={};before.revision=3;before.pools={}
  for id,n in pairs(snapshot.pools) do before.pools[id]=id=='ammo_tomahawk_regular' and 0 or n end
  local after={contract=2,kind=before.kind,characterId='john',identity=identity,revision=4,pools={},units={}}
  for id,n in pairs(before.pools) do after.pools[id]=id=='ammo_tomahawk_regular' and 1 or n end
  after.units[1]={id=160,revision=1,itemName='weapon_thrown_tomahawk',
   metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='RECOVERED'}))}
  local receipt={characterId='john',collector=identity,origin={characterId='jane',sessionId='old',epoch='old'},
   revision=4,pools=after.pools,throwableUnitsSnapshot=after,itemId=160,itemRevision=1,
   projectileInstanceId='boot:1',nativeAmmoDelta=0,looseInventoryDelta=0}
  -- The engine pickup already supplied the one native unit. No factory grant.
  native.AMMO_TOMAHAWK=1;has=mode=='units_empty_recovery';entry=has
  if mode=='units_empty_recovery' then assert(owner.AcceptPhysicalPickup(before,after,receipt))
  else
   assert(WeaponNativeThrowableItem.Recovered(before,after,receipt,catalog,identity,registry.limits))
   local ok,why=owner.Create(after,true)
   if mode=='units_empty_materialization_lost_pool' then
    assert(not ok and why=='throwable_collected_pool_changed' and setters==0 and grants==1 and not owner.Create(after,true));return
   end
   assert(ok and grants==1)
  end
  assert(grants==(mode=='units_empty_recovery' and 0 or 1) and setters==0 and owner.Status().itemId==160 and owner.Status().observedQuantity==1)
  sealed.revision=4;sealed.pools=after.pools
  assert(owner.Release() and removes==1 and grants==(mode=='units_empty_recovery' and 0 or 1) and setters==0);return
 end
 if mode=='prefunded_existing_weapon' or mode=='prefunded_existing_guid' then
  assert(not owner.Create(snapshot) and grants==0 and setters==0 and removes==0,
   'funded pool cannot authorize adoption of a pre-existing weapon or inventory GUID')
  return
 end
 if mode=='hidden_unresolved' or mode=='ambiguous' then
  local ok,reason=owner.Create(snapshot)
  assert(not ok and reason==(mode=='ambiguous' and 'throwable_inventory_guid_ambiguous' or 'throwable_creation_entity_guid_not_observed')
   and owner.Status().reason==reason and owner.Status().phase=='retained')
  assert(grants==1 and setters==1 and removes==0 and not owner.Create(snapshot))
  return
 end
 assert(owner.Create(snapshot)); assert(grants==1 and setters==(mode=='prefunded_belt' and 0 or 1) and native.AMMO_REPEATER==1)
 if mode=='units_partial' or mode=='units_pickup' or mode=='units_physical_pickup' or mode=='units_physical_pickup_wrong_model' then
  native.AMMO_TOMAHAWK=2;assert(owner.Observe().quantity==2)
  sealed.revision=4;sealed.pools.ammo_tomahawk_regular=2
  if mode=='units_pickup' then
   native.AMMO_TOMAHAWK=3
   assert(not owner.Observe({characterId='john',sessionId='s',epoch='e',phase='active',revision=4,pools=sealed.pools}),
    'old carrier pickup gate cannot authorize physical-unit recovery')
   assert(owner.Status().phase=='retained' and not owner.Status().pickupCredits and removes==0);return
  end
  if mode=='units_physical_pickup' or mode=='units_physical_pickup_wrong_model' then
   local before={contract=2,kind=snapshot.kind,characterId='john',identity=identity,revision=4,pools=sealed.pools,
    units={snapshot.units[1],snapshot.units[2]}}
   local after={contract=2,kind=snapshot.kind,characterId='john',identity=identity,revision=5,pools=snapshot.pools,
    units={{id=160,revision=1,itemName='weapon_thrown_tomahawk',
     metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='RECOVERED'}))},snapshot.units[1],snapshot.units[2]}}
   local receipt={characterId='john',collector=identity,origin={characterId='jane',sessionId='old',epoch='old'},
    revision=5,pools=after.pools,throwableUnitsSnapshot=after,itemId=160,itemRevision=1,
    projectileInstanceId='boot:1',nativeAmmoDelta=0,looseInventoryDelta=0}
   native.AMMO_TOMAHAWK=3;guid={1,2,3,99}
   if mode=='units_physical_pickup_wrong_model' then hash=43 end
   local accepted=owner.AcceptPhysicalPickup(before,after,receipt)
   assert(grants==1 and setters==1 and removes==0,'physical recovery recapture is read-only')
   if mode=='units_physical_pickup_wrong_model' then assert(not accepted and owner.Status().phase=='retained');return end
   assert(accepted and owner.Status().itemId==160 and owner.Status().itemRevision==1)
   sealed.revision=5;sealed.pools=after.pools
  end
 end
 if mode=='units_spent' then
  native.AMMO_TOMAHAWK=0;has=false;visible=false;entry=false
  assert(owner.Observe().quantity==0);sealed.revision=4;sealed.pools.ammo_tomahawk_regular=0
 end
 if mode=='pickup' or mode=='pickup_wrong_model' then
  native.AMMO_TOMAHAWK=0; assert(owner.Observe().quantity==0)
  sealed.revision=4; sealed.pools.ammo_tomahawk_regular=0
  local baseline={characterId='john',sessionId='s',epoch='e',phase='active',revision=4,pools=sealed.pools}
  native.AMMO_TOMAHAWK=1; guid={1,2,3,99}
  assert(owner.Observe(baseline).pickupCandidate)
  if mode=='pickup_wrong_model' then hash=43 end
  local ack={characterId='john',sessionId='s',epoch='e',phase='active',revision=5,pools=snapshot.pools}
  local accepted=owner.AcceptNativePickup(ack)
  assert(grants==1 and setters==1 and removes==0,'pickup rebind is read-only')
  if mode=='pickup_wrong_model' then assert(not accepted and owner.Status().phase=='retained'); return end
  assert(accepted and owner.Status().observedQuantity==1)
  sealed.revision=5; sealed.pools.ammo_tomahawk_regular=1
 end
 if mode=='foreign' then guid={1,2,3,5} end
 if mode=='wrong_model' then hash=43 end
 if mode=='spent' or mode=='spent_entry_retained' or mode=='spent_foreign_guid' then
  native.AMMO_TOMAHAWK=0; has=mode=='spent_entry_retained'; visible=false; entry=mode~='spent'
  if mode=='spent_foreign_guid' then guid={1,2,3,9} end
  assert(owner.Observe().quantity==0)
  sealed.revision=4; sealed.pools.ammo_tomahawk_regular=0
 end
 local ok=owner.Release()
 if mode=='units_three' or mode=='units_partial' or mode=='units_pool_retained' or mode=='units_physical_pickup' then
  assert(ok and removes==1 and native.AMMO_TOMAHAWK==0)
  assert(poolRemoves==(mode=='units_pool_retained' and 1 or 0))
 elseif mode=='units_spent' then assert(ok and removes==0,'empty physical custody never deletes world projectiles')
 elseif mode=='unthrown' or mode=='hidden' or mode=='pool_retained' or mode=='pickup' or mode=='prefunded_belt' then
  assert(ok and removes==1)
  assert(setters==(mode=='prefunded_belt' and 0 or 1) and poolRemoves==(mode=='pool_retained' and 1 or 0) and native.AMMO_TOMAHAWK==0)
 elseif mode=='spent' then assert(ok and removes==0,'world projectile must not be deleted')
 elseif mode=='spent_entry_retained' then
  assert(ok and removes==1 and setters==1 and poolRemoves==0 and DoesEntityExist(70),
   'remove only exact empty ped inventory entry, not world projectile or ammo')
 elseif mode=='pool_remove_ignored' then
  assert(not ok and removes==1 and poolRemoves==1 and owner.Status().phase=='retained'
   and owner.Status().reason=='throwable_cleanup_pool_reset_unconfirmed')
  assert(not owner.Release() and removes==1 and poolRemoves==1,'uncertain retirement cannot retry')
 else assert(not ok and removes==0 and owner.Status().phase=='retained') end
 assert(native.AMMO_REPEATER==1 and snapshot.pools.ammo_tomahawk_regular==(snapshot.contract==2 and 3 or 1),'unrelated pools/ledger preserved')
end
for _,mode in ipairs({'unthrown','spent','spent_entry_retained','spent_foreign_guid','foreign','wrong_model','hidden','hidden_unresolved','ambiguous','pool_retained','pool_remove_ignored','pickup','pickup_wrong_model','prefunded_belt','prefunded_existing_weapon','prefunded_existing_guid'}) do run(mode) end
local limits={};for id,n in pairs(registry.limits) do limits[id]=n end;limits.ammo_tomahawk_regular=3
registry=assert(WeaponNativeThrowablePolicy.RegistryFromLimits(catalog,limits))
snapshot={contract=2,kind='physical_throwable_units',characterId='john',identity=identity,revision=3,pools={},units={}}
for id in pairs(registry.limits) do snapshot.pools[id]=id=='ammo_tomahawk_regular' and 3 or (id=='ammo_repeater_regular' and 1 or 0) end
for id=170,172 do snapshot.units[#snapshot.units+1]={id=id,revision=0,itemName='weapon_thrown_tomahawk',
 metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='T-'..id}))} end
for _,mode in ipairs({'units_three','units_partial','units_spent','units_pool_retained','units_pickup',
 'units_empty_recovery','units_physical_pickup','units_physical_pickup_wrong_model'}) do run(mode) end
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('client/native_throwable_adapter.lua',1,true))
print('inert concrete throwable native port PASS: zero carrier grant/funded pool only, exact GUID inventory removal, spent absence/no projectile deletion, foreign refusal')
run('units_empty_materialization');run('units_empty_materialization_lost_pool')

dofile('client/native_throwable_collection_escrow.lua')
local originalInvoke,originalGive=Citizen.InvokeNative,GiveWeaponToPed
local function collection(mode)
 creationMode='pool_retained';now=0;poolRemoves=0;world=true;guid={1,2,3,4};hash=42
 grants,setters,removes=0,0,0
 native={};local baseline={}
 for id,name in pairs(registry.names) do
  native[name]=id=='ammo_repeater_regular' and 1 or 0;baseline[id]=native[name]
 end
 native.AMMO_TOMAHAWK=mode=='two' and 2 or 1
 has=mode~='missing' and mode~='lost_pool' and mode~='foreign_pool';entry=has;visible=false
 Citizen.InvokeNative=function(name,inventory,input,n,reason)
  if name==0x886DFD3E185C8A89 and n==42 then
   return entry and (reason=='SLOTID_WEAPON_0' or mode=='ambiguous')
  end
  if name==0x3E4E811480B3AE79 and mode=='ignored_remove' then removes=removes+1;return true end
  return originalInvoke(name,inventory,input,n,reason)
 end
 GiveWeaponToPed=function(...)
  originalGive(...)
  if mode=='lost_pool' then native.AMMO_TOMAHAWK=0 end
  if mode=='foreign_pool' then native.AMMO_REPEATER=2 end
 end
 if mode=='wrong_model' then hash=43 end
 if mode=='dead' then world=false end
 local escrow=assert(WeaponNativeThrowableAdapter.ScopedCollection(7,identity,function() return world end,
  function() return {characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,
   alive=world,ped=7,bucket=0} end,catalog,registry))
 assert(grants==0 and setters==0 and removes==0,'escrow factory is inert')
 local result=escrow.Begin('trusted-ticket',identity,baseline)
 if mode=='carried' or mode=='missing' then
  assert(result.phase=='cleaned' and result.guidReleased and result.otherPoolsUnchanged,mode)
  assert(removes==1 and poolRemoves==1 and native.AMMO_TOMAHAWK==0 and native.AMMO_REPEATER==1)
  assert(grants==(mode=='missing' and 1 or 0) and setters==0,'collected ammo is never funded or set')
 else
  assert(result.phase=='review_required' or result.phase=='refused',mode)
  if mode~='ignored_remove' then assert(removes==0 and poolRemoves==0,mode..' must not remove an unproven GUID') end
 end
 local before={grants,setters,removes,poolRemoves}
 escrow.Step();escrow.Begin('replay',identity,baseline)
 assert(grants==before[1] and setters==before[2] and removes==before[3] and poolRemoves==before[4],mode..' cannot replay natives')
end
for _,mode in ipairs({'carried','missing','two','ambiguous','wrong_model','lost_pool','foreign_pool','ignored_remove','dead'}) do collection(mode) end
Citizen.InvokeNative,GiveWeaponToPed=originalInvoke,originalGive
print('Concrete native collection escrow PASS: existing/missing carrier, exact GUID removal, zero ammo grants/setters, foreign/ambiguous/uncertain native refusal')

dofile('client/native_throwable_pickup_permissions.lua')
dofile('client/throwable_quantity_owner.lua')
WeaponNativeThrowablePolicy.QuantityEnabled=function() return true end
Config.NativeThrowablePickupPriorPolicy={w_melee_tomahawk01=true,w_melee_tomahawk02=true}
local permissionState={}
SetLocalPlayerPermittedToCollectPickupsWithModel=function(model,allowed)
 assert(type(allowed)=='boolean');permissionState[model]=allowed
end
registry.throwableQuantityContract=1
for _,initial in ipairs({0,2,3}) do
 creationMode='units_empty_recovery';world=true;has=false;visible=false;entry=false
 guid={1,2,3,4};hash=42;grants=0;setters=0;removes=0;poolRemoves=0;sealed=nil;now=0
 native={};for id,name in pairs(registry.names) do native[name]=id=='ammo_repeater_regular' and 1 or 0 end
 local child={contract=3,kind='throwable_quantity',characterId='john',identity=identity,revision=0,pools={}}
 for id in pairs(registry.limits) do child.pools[id]=id=='ammo_tomahawk_regular' and initial or (id=='ammo_repeater_regular' and 1 or 0) end
 local q=assert(WeaponNativeThrowableAdapter.Scoped(7,identity,function() return world end,function() return sealed end,catalog,registry))
 assert(q.Create(child) and grants==(initial>0 and 1 or 0) and setters==0 and native.AMMO_TOMAHAWK==0,
  'quantity factory only constructs a zero-ammo carrier before parent restore')
 assert(q.Status().pickupAllowed==(initial<3) and permissionState.w_melee_tomahawk01==(initial<3)
  and permissionState.w_melee_tomahawk02==(initial<3),'capacity policy applies before initial restore')
 native.AMMO_TOMAHAWK=initial -- parent restore is modeled separately
 assert(q.Observe(child))
 native.AMMO_TOMAHAWK=0;entry=false;has=false;visible=false
 assert(q.Observe(child) and not q.Status().guidCaptured,'engine spent carrier absence is not item ownership loss')
 assert(q.Status().pickupAllowed and permissionState.w_melee_tomahawk01,'throwing creates pickup room')
 native.AMMO_TOMAHAWK=1
 local empty={pools={ammo_tomahawk_regular=0}}
 assert(q.Observe(empty).pickupCandidate and setters==0,'provisional native increase is not funding')
 local ack={pools={ammo_tomahawk_regular=1}}
 native.AMMO_TOMAHAWK=2 -- another native pickup before the first acknowledgement
 assert(q.AcceptNativePickup(ack) and native.AMMO_TOMAHAWK==2 and setters==0,
  'funded pickup may materialize zero-ammo carrier without resetting collected quantity')
 assert(q.Observe(ack).pickupCandidate,'later quantity remains provisional for the next report')
 assert(not q.Release(),'no cleanup without parent seal')
 -- A failed premature cleanup intentionally retains this owner. Use a fresh
 -- active owner for the actual sealed cleanup path below.
end
creationMode='units_empty_recovery';world=true;has=false;visible=false;entry=false
guid={1,2,3,4};hash=42;grants=0;setters=0;removes=0;poolRemoves=0;sealed=nil;now=0
native={};for id,name in pairs(registry.names) do native[name]=id=='ammo_repeater_regular' and 1 or 0 end
local child={contract=3,kind='throwable_quantity',characterId='john',identity=identity,revision=0,pools={}}
for id in pairs(registry.limits) do child.pools[id]=id=='ammo_repeater_regular' and 1 or 0 end
local q=assert(WeaponNativeThrowableAdapter.Scoped(7,identity,function() return world end,function() return sealed end,catalog,registry))
assert(q.Create(child));native.AMMO_TOMAHAWK=1
assert(q.AcceptNativePickup({pools={ammo_tomahawk_regular=1}}))
native.AMMO_TOMAHAWK=3
assert(q.AcceptNativePickup({pools={ammo_tomahawk_regular=3}}) and not q.Status().pickupAllowed
 and permissionState.w_melee_tomahawk01==false,'acknowledged full pool suppresses native pickup')
assert(q.PrepareRestore({pools={ammo_tomahawk_regular=2}}) and q.Status().pickupAllowed
 and permissionState.w_melee_tomahawk02==true,'unload re-enables native collection before parent restore')
native.AMMO_TOMAHAWK=1
sealed={pools={ammo_tomahawk_regular=1}}
assert(q.Release() and q.Status().phase=='released' and removes==1 and poolRemoves==0
 and native.AMMO_REPEATER==1 and native.AMMO_TOMAHAWK==0 and setters==0)
assert(permissionState.w_melee_tomahawk01==true and permissionState.w_melee_tomahawk02==true,
 'sealed release restores explicit prior model permissions')
assert(q.Release() and removes==1,'released quantity carrier cannot repeat removal')
local fullChild={contract=3,kind='throwable_quantity',characterId='john',identity=identity,revision=0,pools={}}
for id in pairs(registry.limits) do fullChild.pools[id]=id=='ammo_tomahawk_regular' and 3 or (id=='ammo_repeater_regular' and 1 or 0) end
SetLocalPlayerPermittedToCollectPickupsWithModel=function() error('permission write failed') end
local failedCapacity=assert(WeaponNativeThrowableAdapter.Scoped(7,identity,function() return world end,function() return sealed end,catalog,registry))
assert(not failedCapacity.Create(fullChild) and failedCapacity.Status().phase=='retained'
 and failedCapacity.Status().reason=='quantity_pickup_permission_failed'
 and native.AMMO_TOMAHAWK==0 and native.AMMO_REPEATER==1 and setters==0,
 'permission suppression failure retains owner without restoring/amending native ammunition')
print('PASS concrete quantity adapter: zero-ammo carrier, no canonical item IDs, native pool preservation, paid pickup rebind and sealed exact cleanup')
