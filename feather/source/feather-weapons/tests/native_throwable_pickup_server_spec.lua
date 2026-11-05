dofile('tests/character_ammunition_item_spec.lua')
for _,p in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/native_throwable_recovery.lua',
 'shared/character_ammunition_materialization.lua','shared/character_ammunition_loadout_lease.lua',
 'shared/character_ammunition_runtime.lua','shared/character_lifecycle_wear.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true; Config.NativeAlphaCharacterId='c'
local gate,current,dead,count,revision,claims=1,true,false,1,3,0
GetConvarInt=function(name) return (name=='feather_native_throwable' and 1) or (name=='feather_native_throwable_pickup' and gate) or 0 end
GetGameTimer=function() return 1 end
AddEventHandler=function() end
GetInvokingResource=function() return 'feather-inventory' end
local sessionId='s'
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='c',sessionId=sessionId}} end,IsSessionCurrent=function() return current end}
local row={id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T'}))}
local registered={}
local inventory={}
function inventory:GetCharacterFirearmRuntimeSnapshot(context,limits)
 local pools={}; for id in pairs(limits) do pools[id]=0 end; pools.ammo_tomahawk_regular=count
 return {ok=true,value={characterId='c',revision=revision,pools=pools,equipment={},throwableEquipment={
  characterId='c',revision=revision,pools=copy(pools),expected={weapon_throwable={itemId=170,revision=0}},equipment={throwable=copy(row)}}}}
end
function inventory:ObserveCharacterAmmunition(context,spec)
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec))
 local snapshot=self:GetCharacterFirearmRuntimeSnapshot(context,spec.limits).value.throwableEquipment
 local before={phase='active',characterId='c',sessionId='s',epoch=context.runtimeEpoch,revision=revision,pools=copy(snapshot.pools)}
 revision=revision+1; count=spec.pools.ammo_tomahawk_regular
 local after=copy(before); after.revision=revision; after.pools=copy(spec.pools)
 local candidate=assert(WeaponNativeThrowableRecovery.SpendCandidate(before,after,snapshot,WeaponDefinitionCatalog,spec.limits))
 return {ok=true,value={characterId='c',revision=revision,pools=copy(spec.pools),nativePickupSpend={
  policy='same_session_native_spend_credit_v1',phase='committed_unclaimed',receiptId='spend:170:'..revision,
  before=before,after=after,snapshot=snapshot,candidate=candidate}}}
end
function inventory:ReconcileNativeThrowablePickup(context,spec)
 if not registered.ValidateCharacterAmmoRuntimeOperation(context,'pickup',spec) then return {ok=false} end
 claims=claims+1
 assert(spec.nativePickupPlan.spendReceiptId=='spend:170:'..revision and spec.nativePickupPlan.itemId==170)
 revision=revision+1; count=1
 return {ok=true,value={characterId='c',revision=revision,pools=copy(spec.pools)}}
end
exports=setmetatable({['feather-inventory']=inventory,['feather-medical']={ReadNativeWeaponCondition=function()
 return {ok=true,value={lifeState=dead and 'dead' or 'alive',revision=1}}
end}},{__call=function(_,name,fn) registered[name]=fn end})
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,registry.limits).value)
local report=copy(opened.runtime); assert(S.ConfirmRestore(1,report).ok)
assert(not S.NativePickup(1,report).ok and claims==0,'funded item has no committed spend credit')
report.pools.ammo_tomahawk_regular=0
local spent=assert(S.Observe(1,report).value); assert(spent.revision==4 and count==0)
report=copy(spent); report.pools.ammo_tomahawk_regular=1
gate=0; assert(not S.NativePickup(1,report).ok and claims==0)
gate=1; local stale=copy(report); stale.epoch='old'
assert(not S.NativePickup(1,stale).ok and claims==0)
assert(not S.Observe(1,report).ok and claims==0,'generic observations still reject increases')
local result=S.NativePickup(1,report)
assert(result.ok and result.value.phase=='active' and result.value.revision==5 and claims==1 and count==1)
assert(not S.NativePickup(1,report).ok and claims==1,'server receipt is retired after acknowledgement')
assert(S.IsNativeItemBound(170),'pickup preserves equipment/lifetime hold')
-- The provider can commit durably and then lose its return across the export
-- boundary. Never turn that unknown outcome into a second claim or a release.
report=copy(result.value); report.pools.ammo_tomahawk_regular=0
local spentAgain=assert(S.Observe(1,report).value)
assert(spentAgain.revision==6 and count==0)
report=copy(spentAgain); report.pools.ammo_tomahawk_regular=1
local reconcile=inventory.ReconcileNativeThrowablePickup
function inventory:ReconcileNativeThrowablePickup(context,spec)
 local committed=reconcile(self,context,spec)
 assert(committed.ok and revision==7 and count==1)
 error('simulated reply loss after durable pickup commit')
end
assert(not S.NativePickup(1,report).ok and claims==2 and revision==7 and count==1)
assert(S.IsNativeItemBound(170),'unknown commit outcome retains carrier hold')
assert(not S.NativePickup(1,report).ok and claims==2,'unknown outcome must not retry provider claim')
assert(not S.Observe(1,report).ok,'frozen owner cannot resume ordinary observations')
-- Simulate the server retiring a disconnected owner, not a forced live thaw.
-- A new connection reads the canonical committed ledger rather than inventing
-- a final observation or retrying the uncertain economic operation.
local oldReport=copy(report)
S.Revoke(1,'s','player_dropped')
assert(not S.IsNativeItemBound(170),'retired connection releases its server lifetime hold')
sessionId='new-session'
local recovered=assert(S.OpenLoadout(2,WeaponDefinitionCatalog,registry.limits).value)
assert(recovered.runtime.sessionId==sessionId and recovered.runtime.epoch~=oldReport.epoch
 and recovered.runtime.revision==7 and recovered.runtime.pools.ammo_tomahawk_regular==1)
assert(S.ConfirmRestore(2,copy(recovered.runtime)).ok)
assert(not S.NativePickup(2,oldReport).ok and claims==2,'old connection cannot replay its pickup')
assert(not S.NativePickup(2,copy(recovered.runtime)).ok and claims==2,
 'fresh durable baseline does not import a previous session spend allowance')
assert(S.IsNativeItemBound(170) and revision==7 and count==1,
 'new lifetime restores canonical balance without a second economic write')
print('native pickup service PASS: committed-record capture, exact planner/runtime/Inventory bridge, gate/stale/replay denial and retained item hold; mocked Inventory')
