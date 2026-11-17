Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,AmmunitionPools={enabled=false},DevMode=false}
GetConvarInt=function(name) return name=='feather_regular_arrows' and 1 or 0 end
GetConvar=function(name,default) return name=='feather_regular_arrows' and '1' or default end
for _,p in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua','shared/validation.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/character_ammunition_item.lua','shared/character_ammunition_materialization.lua',
 'shared/character_ammunition_loadout_lease.lua','shared/character_ammunition_runtime.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
RegisterCommand=function() end;AddEventHandler=function() end
GetGameTimer=function() return 100 end;GetPlayerPed=function() return 1 end
GetEntityCoords=function() return {x=1,y=2,z=3} end;GetPlayerRoutingBucket=function() return 0 end
GetInvokingResource=function() return 'feather-inventory' end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='jane',sessionId='s'}} end,IsSessionCurrent=function() return true end}
local row={id=901,revision=0,itemName='weapon_bow',metadata={schemaVersion=2,weaponDefinitionId='bow',serialNumber='BOW-TEST',
 quality=100,condition=100,maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
 ammo={ownership='character',type='ammo_arrow_regular'},attachments={},cosmetics={},flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local db={revision=0,pools={}};for id in pairs(registry.limits) do db.pools[id]=0 end;db.pools.ammo_arrow_regular=5
local equipment={shoulder=row}
local registered={};local calls=0
local inventory={GetCharacterFirearmRuntimeSnapshot=function() return {ok=true,value={characterId='jane',revision=db.revision,pools=copy(db.pools),equipment=copy(equipment)}} end}
local function save(pools) db.pools=copy(pools);db.revision=db.revision+1;return {ok=true,value={characterId='jane',revision=db.revision,pools=copy(pools)}} end
inventory.ObserveCharacterAmmunition=function(_,context,spec)
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec))
 assert(spec.quantityRecovery.position.x==1 and spec.quantityRecovery.bucket==0)
 local forged=copy(spec);forged.quantityRecovery.position.x=100
 assert(not registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',forged))
 return save(spec.pools)
end
inventory.ReconcileNativeThrowablePickup=function(_,context,spec)
 calls=calls+1
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'pickup',spec))
 assert(spec.nativePickupPlan.ammunitionId=='ammo_arrow_regular')
 local forged=copy(spec);forged.nativePickupPlan.ammunitionId='ammo_tomahawk_regular'
 assert(not registered.ValidateCharacterAmmoRuntimeOperation(context,'pickup',forged))
 return save(spec.pools)
end
exports=setmetatable({['feather-inventory']=inventory,['feather-medical']={ReadNativeWeaponCondition=function()
 return {ok=true,value={lifeState='alive',revision=0}} end}}, {__call=function(_,n,fn) registered[n]=fn end})
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local opened=S.OpenLoadout(1,WeaponDefinitionCatalog,registry.limits);assert(opened.ok,opened.error and opened.error.code)
assert(opened.value.creation.items[1].definitionId=='bow' and S.IsNativeItemBound(901))
local live=opened.value.runtime;assert(S.ConfirmRestore(1,live).ok);live.phase='active'
local report=copy(live);report.pools.ammo_arrow_regular=4
local r=S.Observe(1,report);assert(r.ok,r.error and r.error.code);live=r.value
report=copy(live);report.pools.ammo_arrow_regular=5
r=S.NativePickup(1,report);assert(r.ok,r.error and r.error.code)
assert(r.value.pools.ammo_arrow_regular==5 and calls==1 and S.ValidateLoadout(1).ok)
-- Equipment replacement must invalidate the lease before it can authorize another pickup.
equipment.shoulder.revision=1
report=copy(r.value);report.pools.ammo_arrow_regular=6
assert(not S.NativePickup(1,report).ok and calls==1 and S.IsNativeItemBound(901),'stale bow cannot reach economic claim')
print('PASS regular-arrow server composition: current equipped bow/lease, arrow-only opt-in, paid debit context and immutable type/location reservation; stale equipment retains holds')
