Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,NativeThrowableUnitsEnabled=true,AmmunitionPools={enabled=false}}
for _,path in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_ammunition_item.lua','shared/character_ammunition_materialization.lua',
 'shared/character_ammunition_loadout_lease.lua','shared/character_ammunition_runtime.lua'}) do dofile(path) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local registered,current,ack=true,true,true
registered={}
GetConvarInt=function() return 0 end
GetGameTimer=function() return 100 end
GetInvokingResource=function() return 'feather-inventory' end
AddEventHandler=function() end
CoreAdapter={ResolveSession=function() return {ok=true,value={characterId='john',sessionId='s'}} end,
 IsSessionCurrent=function() return current end}
local policy=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)).limits
assert(policy.ammo_tomahawk_regular==3)
local db={revision=0,pools={},units={}}
for id in pairs(policy) do db.pools[id]=id=='ammo_tomahawk_regular' and 3 or (id=='ammo_revolver_regular' and 7 or 0) end
for id=170,172 do db.units[#db.units+1]={id=id,revision=0,itemName='weapon_thrown_tomahawk',
 metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T-'..id}))} end
local function custody(context)
 return {contract=2,kind='physical_throwable_units',characterId='john',identity={characterId='john',sessionId='s',
 epoch=context.epoch or context.runtimeEpoch},revision=db.revision,pools=copy(db.pools),units=copy(db.units)}
end
local savedScope
local inventory={GetCharacterFirearmRuntimeSnapshot=function(_,context)
 assert(type(context.epoch)=='string','activation and validation carry authoritative epoch')
 return {ok=true,value={characterId='john',revision=db.revision,pools=copy(db.pools),equipment={},throwableEquipment=custody(context)}}
end}
inventory.ObserveCharacterAmmunition=function(_,context,spec)
 assert(registered.ValidateCharacterAmmoRuntimeOperation(context,'observe',spec))
 local scope=copy(context);scope.resource='feather-weapons';scope.reason='character_ammunition_observation';scope.nativeThrowableSpend=true
 local count=spec.pools.ammo_tomahawk_regular
 for index,row in ipairs(db.units) do
  assert(WeaponCharacterAmmoService.IsThrowableSpendMoveAuthorized(row.id,scope)==(index>count))
 end
 local forged=copy(scope);forged.runtimeTicket='other'
 assert(not WeaponCharacterAmmoService.IsThrowableSpendMoveAuthorized(172,forged))
 forged=copy(scope);forged.nativeThrowableSpend=nil
 assert(not WeaponCharacterAmmoService.IsThrowableSpendMoveAuthorized(172,forged))
 savedScope=scope
 if not ack then return {ok=false} end
 while #db.units>count do table.remove(db.units) end
 db.revision=db.revision+1;db.pools=copy(spec.pools)
 return {ok=true,value={characterId='john',revision=db.revision,pools=copy(db.pools),throwableUnitsSnapshot=custody(context)}}
end
exports=setmetatable({['feather-inventory']=inventory,['feather-medical']={ReadNativeWeaponCondition=function()
 return {ok=true,value={lifeState='alive',revision=0}} end}},
 {__call=function(_,name,fn) registered[name]=fn end})
dofile('server/services/character_ammunition_runtime.lua')
local S=WeaponCharacterAmmoService
local challenges={}
WeaponNativeThrowablePickupServer={Ready=function() return true end,
 ConfirmedSpend=function(source,identity,operationId,ids)
  assert(source==1 and identity.characterId=='john' and identity.sessionId=='s' and type(identity.epoch)=='string')
  challenges[#challenges+1]={operationId=operationId,ids=copy(ids)};return true
 end}
local start=S.OpenLoadout(1,WeaponDefinitionCatalog,policy)
local opened=assert(start.value,start.error and start.error.code)
assert(S.ConfirmRestore(1,opened.runtime).ok and S.IsNativeItemBound(170) and S.IsNativeItemBound(172))
local report=copy(opened.runtime);report.pools.ammo_tomahawk_regular=1;report.pools.ammo_revolver_regular=6
local observed=assert(S.Observe(1,report).value)
assert(#challenges==1 and challenges[1].operationId=='observe:0'
 and challenges[1].ids[1]==171 and challenges[1].ids[2]==172)
assert(observed.revision==1 and observed.pools.ammo_tomahawk_regular==1 and observed.pools.ammo_revolver_regular==6)
assert(S.IsNativeItemBound(170) and not S.IsNativeItemBound(171) and not S.IsNativeItemBound(172))
assert(not S.IsThrowableSpendMoveAuthorized(172,savedScope),'spend ticket is retired immediately after provider returns')
assert(S.ValidateLoadout(1).ok,'fresh custody remains bound after a partial spend')
report=copy(observed);report.pools.ammo_tomahawk_regular=0
local empty=assert(S.Observe(1,report).value)
assert(#challenges==2 and challenges[2].operationId=='observe:1' and challenges[2].ids[1]==170)
assert(empty.revision==2 and not S.IsNativeItemBound(170) and S.ValidateLoadout(1).ok)
assert(not S.Observe(1,report).ok,'late observation cannot spend twice')
local sealed=assert(S.CheckpointAndSeal(1,empty).value)
sealed.cleanupComplete=true;sealed.remainingCopies=0
assert(S.ConfirmCleanup(1,sealed).ok and S.CanReleaseInventoryGuards())
db.units={{id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T-170'}))}}
db.pools.ammo_tomahawk_regular=1
opened=assert(S.OpenLoadout(1,WeaponDefinitionCatalog,policy).value);assert(S.ConfirmRestore(1,opened.runtime).ok)
ack=false;report=copy(opened.runtime);report.pools.ammo_tomahawk_regular=0
assert(not S.Observe(1,report).ok and S.IsNativeItemBound(170),'unconfirmed provider retains original ownership')
assert(#challenges==2,'unconfirmed spend cannot publish a recovery challenge')
assert(not S.IsThrowableSpendMoveAuthorized(170,savedScope) and not S.CanReleaseInventoryGuards())
print('Physical throwable service PASS: authoritative custody activation, ticket-scoped spend, remaining-unit lease rebinding, empty cleanup and failed-provider holds; mocked provider')
