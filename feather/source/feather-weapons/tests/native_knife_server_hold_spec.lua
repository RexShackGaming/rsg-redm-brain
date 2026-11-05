dofile('tests/character_ammunition_item_spec.lua')
for _,p in ipairs({'shared/native_knife.lua','shared/character_ammunition.lua','shared/character_ammunition_policy.lua',
 'shared/character_ammunition_materialization.lua','shared/character_ammunition_loadout_lease.lua',
 'shared/character_ammunition_runtime.lua'}) do dofile(p) end
Config.CharacterAmmunitionEnabled=true
local flag,current,changed=1,true,false
GetConvarInt=function(name) return name=='feather_native_knife' and flag or 0 end
GetGameTimer=function() return 1 end
AddEventHandler=function() end
GetInvokingResource=function() return 'feather-inventory' end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='c',sessionId='s'}} end,
 IsSessionCurrent=function() return current end}
local metadata=assert(WeaponNativeKnife.Build(WeaponDefinitionCatalog.weapons.melee_knife,{serialNumber='KNIFE'}))
local row={id=90,revision=0,itemName='weapon_melee_knife',metadata=metadata}
local registered={}
local inventory={GetCharacterFirearmRuntimeSnapshot=function(_,context,limits)
 local pools={}; for k in pairs(limits) do pools[k]=0 end
 local knife={characterId='c',expected={weapon_melee={itemId=90,revision=row.revision}},equipment={melee=row}}
 return {ok=true,value={characterId='c',revision=0,pools=pools,equipment={},knifeEquipment=flag==1 and knife or nil}}
end}
exports=setmetatable({['feather-inventory']=inventory},{__call=function(_,n,fn) registered[n]=fn end})
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local policy=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)).limits
local opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,policy).value)
assert(opened.knife.row.id==90 and S.IsNativeItemBound(90) and not S.IsNativeItemBound(91))
opened.knife.row.metadata.serialNumber='mutated'; assert(S.ValidateLoadout(1).ok,'returned approval is private')
local guard=WeaponCharacterAmmoLoadoutLease.Guard(S.IsNativeItemBound)
assert(not guard({id=90}),'same production predicate protects knife from Inventory mutation')
local report=opened.runtime
assert(S.ConfirmRestore(1,report).ok); assert(S.CheckpointAndSeal(1,report).ok)
assert(S.IsNativeItemBound(90),'seal does not release knife hold')
report.cleanupComplete=true; report.remainingCopies=0
assert(S.ConfirmCleanup(1,report).ok and not S.IsNativeItemBound(90))
opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,policy).value)
row.revision=1
assert(not S.ValidateLoadout(1).ok and S.IsNativeItemBound(90),'changed knife freezes whole owner but retains hold')
assert(not S.ConfirmCleanup(1,opened.runtime).ok)
S.Revoke(1); row.revision=0
opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,policy).value)
flag=0
assert(not S.ValidateLoadout(1).ok and S.IsNativeItemBound(90),'disabling knife cannot discard live hold')
print('knife real server hold PASS (immutable atomic snapshot, shared lease/guard, seal retains, cleanup releases, mismatch/flag loss freezes)')
