dofile('tests/character_ammunition_item_spec.lua')
for _,p in ipairs({'shared/character_ammunition.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_ammunition_materialization.lua',
 'shared/character_ammunition_loadout_lease.lua','shared/character_ammunition_runtime.lua',
 'shared/character_lifecycle_wear.lua'}) do dofile(p) end
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true
Config.NativeAlphaCharacterId='c'
local flag,current,count,revision=1,true,1,3
GetConvarInt=function(name) return name=='feather_native_throwable' and flag or 0 end
GetGameTimer=function() return 1 end
AddEventHandler=function() end
GetInvokingResource=function() return 'feather-inventory' end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='c',sessionId='s'}} end,IsSessionCurrent=function() return current end}
local row={id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T'}))}
local registered={}
local dead,enriched=false,false
local inventory={GetCharacterFirearmRuntimeSnapshot=function(_,context,limits)
 local pools={}; for id in pairs(limits) do pools[id]=0 end; pools.ammo_tomahawk_regular=count
 return {ok=true,value={characterId='c',revision=revision,pools=pools,equipment={},throwableEquipment=flag==1 and {
  characterId='c',revision=revision,pools=pools,expected={weapon_throwable={itemId=170,revision=row.revision}},equipment={throwable=row}} or nil}}
end}
inventory.ReadNativeEquipmentTransition=function(_,context,item,limits)
 assert(limits and limits.ammo_tomahawk_regular==1,'death preflight passes exact server registry')
 local snapshot=inventory.GetCharacterFirearmRuntimeSnapshot(nil,context,limits).value
 if not enriched then snapshot.throwableEquipment.revision=nil; snapshot.throwableEquipment.pools=nil end
 snapshot.expected={weapon_throwable={itemId=170,revision=0}}
 snapshot.brokenDeathEquipmentContract=1; snapshot.brokenPromotionContract=1
 return {ok=true,value=snapshot}
end
inventory.ObserveCharacterAmmunition=function(_,context,spec)
 assert(spec.finalWear.action=='death' and #spec.finalWear.lifecycleWear==0)
 return {ok=true,value={characterId='c',revision=spec.expectedRevision,pools=spec.pools}}
end
exports=setmetatable({['feather-inventory']=inventory,['feather-medical']={ReadNativeWeaponCondition=function()
 return {ok=true,value={lifeState=dead and 'dead' or 'alive',revision=1}}
end}},{__call=function(_,name,fn) registered[name]=fn end})
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
assert(registry.limits.ammo_tomahawk_regular==1)
local opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,registry.limits).value)
assert(opened.throwable.equipment.throwable.id==170 and opened.runtime.pools.ammo_tomahawk_regular==1 and S.IsNativeItemBound(170))
local report=opened.runtime
assert(S.ConfirmRestore(1,report).ok)
for _,amount in ipairs({1,-1}) do
 local denied=S.Transfer(1,report,'ammo_tomahawk_regular',amount,'crafted-transfer')
 assert(not denied.ok and denied.error.code=='throwable_transfer_requires_rebuild')
end
opened.throwable.equipment.throwable.metadata.serialNumber='changed'
assert(S.ValidateLoadout(1).ok,'returned bundle cannot mutate carrier hold')
assert(S.CheckpointAndSeal(1,report).ok and S.IsNativeItemBound(170))
report.cleanupComplete=true; report.remainingCopies=0
assert(S.ConfirmCleanup(1,report).ok and not S.IsNativeItemBound(170))
opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,registry.limits).value)
row.metadata.quality=99
assert(not S.ValidateLoadout(1).ok and S.IsNativeItemBound(170))
S.Revoke(1); row.metadata.quality=100
opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,registry.limits).value)
flag=0
assert(not S.ValidateLoadout(1).ok and S.IsNativeItemBound(170),'gate loss retains hold')
S.Revoke(1); flag=1; dead=false
opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,registry.limits).value)
report=opened.runtime; assert(S.ConfirmRestore(1,report).ok)
dead=true; report.deathWear={epoch=report.epoch,medicalRevision=1,items={}}
local refused=S.CheckpointAndSeal(1,report)
assert(not refused.ok and refused.error.code=='death_wear_loadout_changed','equipment-only snapshot cannot validate funded throwable')
enriched=true
assert(S.CheckpointAndSeal(1,report).ok,'atomic ledger-enriched death preflight seals funded throwable')
print('actual throwable runtime/service hold PASS: explicit funded registry, same snapshot/bundle, immutable guard, seal retains/cleanup releases, mutation/gate loss refuses')
