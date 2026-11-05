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
 assert(ped==7 and ammo=='AMMO_TOMAHAWK' and n==1,
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
end
for _,name in ipairs({'SetPedAmmo','SetAmmoInClip','SetCurrentPedWeapon','RemoveWeaponFromPed','DeleteEntity'}) do
 _G[name]=function() error('forbidden mutation '..name) end
end
WeaponCharacterAmmoCreationNative={DecodeDiagnosticGuid=function() return {scriptSlotWords=guid} end,
 DecodeEquippedChild=function(_,result) return result and {itemHash=hash} or nil end}
Citizen={InvokeNative=function(name,inventory,input,n,reason)
 if name==0xB6CFEC32E3742779 then
  assert(inventory==7 and input=='AMMO_TOMAHAWK' and n==1 and reason==0xA07362E6
   and not entry and not has and native.AMMO_TOMAHAWK==1,'only exact post-GUID-removal retirement')
  poolRemoves=poolRemoves+1
  if creationMode~='pool_remove_ignored' then native.AMMO_TOMAHAWK=0 end
  return
 end
 if name==0x886DFD3E185C8A89 then
  if n==42 then return entry and (((creationMode=='hidden' or creationMode=='spent_entry_retained'
    or creationMode=='spent_foreign_guid' or creationMode=='prefunded_existing_guid'
    or creationMode:find('pickup',1,true)) and reason=='SLOTID_WEAPON_0')
    or creationMode=='ambiguous') end
  return true
 end
 if name==0x6929E22158E52265 then return true end
 assert(inventory==1)
 if name==0x9700E8EFC4AB9089 then return entry end
 if name==0x3E4E811480B3AE79 then
  assert(type(input)=='string' and #input==104 and n==1 and reason=='REMOVE_REASON_CLIENT_PURGED')
  removes=removes+1; entry=false; has=false; visible=false
  if creationMode~='pool_retained' and creationMode~='pool_remove_ignored' then native.AMMO_TOMAHAWK=0 end; return true
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
 if mode=='unthrown' or mode=='hidden' or mode=='pool_retained' or mode=='pickup' or mode=='prefunded_belt' then
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
 assert(native.AMMO_REPEATER==1 and snapshot.pools.ammo_tomahawk_regular==1,'unrelated pools/ledger preserved')
end
for _,mode in ipairs({'unthrown','spent','spent_entry_retained','spent_foreign_guid','foreign','wrong_model','hidden','hidden_unresolved','ambiguous','pool_retained','pool_remove_ignored','pickup','pickup_wrong_model','prefunded_belt','prefunded_existing_weapon','prefunded_existing_guid'}) do run(mode) end
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('client/native_throwable_adapter.lua',1,true))
print('inert concrete throwable native port PASS: zero carrier grant/funded pool only, exact GUID inventory removal, spent absence/no projectile deletion, foreign refusal')
