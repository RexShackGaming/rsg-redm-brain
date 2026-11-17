for _,native in ipairs({false,true}) do
Config={AmmunitionPools={enabled=false},DevMode=false,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,NativeAlphaLifecycleWearEnabled=true}
local nativeGate=0
local commands,events,registered={},{},{}
RegisterCommand=function(n,f) commands[n]=f end
RegisterNetEvent=function(n,f) events[n]=f end
AddEventHandler=function() end;SetTimeout=function() end;GetGameTimer=function() return 100 end
GetResourceState=function() return 'stopped' end;GetConvarInt=function(name) return name=='feather_native_paid_collection' and nativeGate or 0 end
GetInvokingResource=function() return 'feather-inventory' end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='jane',sessionId='sid'}} end,
 IsSessionCurrent=function(_,sid,cid) return sid=='sid' and cid=='jane' end}
WeaponNativeEnrollment={Allows=function() return true end}
local enabled=true
WeaponNativeThrowablePolicy={UnitsEnabled=function() return enabled end}
WeaponCharacterAmmoPolicy={Build=function() return {limits={ammo_tomahawk_regular=3}} end}
WeaponCharacterLifecycleWear={Plan=function() return {},nil,{} end}
local id={characterId='jane',sessionId='sid',epoch='old'}
local state={phase='active',identity=id};local release,writes,starts=nil,0,0
TriggerClientEvent=function(name,_,request) if name=='feather-weapons:client:native-equipment-release' then release=request end end
local binding={version=3,kind='paid_tomahawk_pickup',phase='available',pickupId='paid-pickup',pickupRevision=0,
 itemId=42,itemRevision=7,originEventId='paid-pickup',spendOperationId='spend',bucket=1,position={x=1,y=0,z=0},
 origin={characterId='john',sessionId='donor',epoch='donor-epoch'},metadata={serialNumber='paid'}}
if native then binding.version=4;binding.kind='paid_tomahawk_native_pickup';binding.presentation='native' end
local valid=true
exports=setmetatable({['feather-inventory']={
 ReadNativeEquipmentTransition=function(_,context,_,limits)
  assert(context.actorSource==1 and context.characterId=='jane' and context.sessionId=='sid'
   and context.epoch==state.identity.epoch and limits.ammo_tomahawk_regular==3,
   'physical pickup preflight must carry the full current identity, including epoch')
  return {ok=true,value={expected={},equipment={},brokenEquipmentContract=1,brokenPromotionContract=1}}
 end,
 GetCharacterFirearmRuntimeSnapshot=function()
  assert(state.phase=='released','collector ledger must be refreshed after seal/release')
  return {ok=true,value={revision=21,pools={ammo_tomahawk_regular=0}}}
 end,
 CommitNativeThrowablePromptPickup=function(_,context,spec)
  assert(state.phase=='released' and registered.ValidateNativeEquipmentCommit(context,spec))
  local old=spec.pickupClaim.itemId;spec.pickupClaim.itemId=99
  assert(not registered.ValidateNativeEquipmentCommit(context,spec),'forged paid item cannot reuse ticket')
  spec.pickupClaim.itemId=old
  assert(spec.pickupContract==(native and 2 or 1))
  assert(spec.pickupClaim.kind==(native and 'physical_throwable_native_claim' or 'physical_throwable_prompt_claim') and spec.pickupClaim.phase==nil
   and spec.pickupClaim.expectedRevision==21 and spec.pickupClaim.expectedPools.ammo_tomahawk_regular==0
   and spec.pickupClaim.collector.epoch=='old' and spec.pickupClaim.pickupId=='paid-pickup')
  writes=writes+1;return {ok=true,value={pickupId='paid-pickup',itemId=42,itemRevision=8}}
 end}}, {__call=function(_,n,f) registered[n]=f end})
if native then
 exports['feather-inventory'].CommitNativeThrowableNativePickup=exports['feather-inventory'].CommitNativeThrowablePromptPickup
 exports['feather-inventory'].CommitNativeThrowablePromptPickup=function() error('native claim must not enter prompt export') end
end
WeaponCharacterAmmoDispatcher={Status=function() return state end,Start=function()
 starts=starts+1;local bundle={};WeaponNativeEquipmentBindings.Attach(1,bundle)
 assert(bundle.equipmentTransition.ticket==release.ticket)
 id={characterId='jane',sessionId='sid',epoch='new'};state={phase='restoring',identity=id}
 return {ok=true,value=id}
end}
dofile('server/services/native_equipment_transition.lua')
local begin=native and WeaponNativeEquipmentBindings.NativePickupTransition or WeaponNativeEquipmentBindings.PickupTransition
local status=native and WeaponNativeEquipmentBindings.NativePickupTransitionStatus or WeaponNativeEquipmentBindings.PickupTransitionStatus
if native then
 assert(not begin(1,binding,id,function() return true end).ok and not release,'native path defaults off')
 Config.NativeThrowableNativeCollectionContract=1
 assert(not begin(1,binding,id,function() return true end).ok and not release,'config alone cannot enable native claims')
 nativeGate=1
 assert(not WeaponNativeEquipmentBindings.PickupTransition(1,binding,id,function() return true end).ok,'prompt API cannot accept native binding')
end
enabled=false
assert(not begin(1,binding,id,function() return true end).ok and not release)
enabled=true
assert(begin(1,binding,id,function() return valid end).ok and writes==0)
assert(not begin(1,binding,id,function() return true end).ok)
source=1
events['feather-weapons:server:native-equipment-released']('stale',release.identity,true,{epoch=release.identity.epoch,items={}})
assert(writes==0)
state={phase='released',identity=release.identity}
events['feather-weapons:server:native-equipment-released'](release.ticket,release.identity,true,{epoch=release.identity.epoch,items={}})
assert(writes==1 and starts==1 and status(1,'paid-pickup').phase=='pending')
events['feather-weapons:server:native-equipment-restored']('stale',id)
assert(status(1,'paid-pickup').phase=='pending')
state={phase='active',identity=id}
events['feather-weapons:server:native-equipment-restored'](release.ticket,id)
local result=status(1,'paid-pickup')
assert(result.phase=='claimed' and result.receipt.itemId==42 and writes==1)
if native then assert(not WeaponNativeEquipmentBindings.PickupTransitionStatus(1,'paid-pickup'),'prompt status cannot settle native claim')
else assert(not WeaponNativeEquipmentBindings.NativePickupTransitionStatus(1,'paid-pickup'),'native status cannot settle prompt claim') end
events['feather-weapons:server:native-equipment-released'](release.ticket,release.identity,true,{epoch=release.identity.epoch,items={}})
assert(writes==1,'duplicate release cannot repeat pickup transaction')
assert(begin(1,binding,id,function() return valid end).ok)
valid=false;state={phase='released',identity=release.identity}
events['feather-weapons:server:native-equipment-released'](release.ticket,release.identity,true,{epoch=release.identity.epoch,items={}})
assert(writes==1 and status(1,'paid-pickup').transition.phase=='frozen',
 'reservation loss after release cannot reach Inventory or grant a native unit')
print('PASS prompt pickup uses actual equipment coordinator: final seal, exact released ticket, fresh ledger, single claim and fresh-epoch acknowledgement')
end
