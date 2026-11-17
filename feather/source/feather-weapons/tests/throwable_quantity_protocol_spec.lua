Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,NativeThrowableQuantityContract=1,AmmunitionPools={enabled=false}}
GetConvarInt=function(name,default) return name=='feather_throwable_quantities' and 1 or default end
for _,p in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_runtime.lua',
 'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua','shared/native_throwable_policy.lua',
 'shared/native_throwable_item.lua','shared/character_ammunition_item.lua','shared/character_ammunition_materialization.lua','shared/character_ammunition_loadout_lease.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local limits={ammo_tomahawk_regular=3,ammo_revolver_regular=100}
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local function participant(source,tom)
 local C=WeaponCharacterAmmoClient.New()
 local b=assert(R.Open({source=source,characterId='c'..source,sessionId='s'..source},
  {characterId='c'..source,revision=0,pools={ammo_tomahawk_regular=tom,ammo_revolver_regular=7}},limits,'e'..source))
 assert(C.Begin(b,limits,source));local req=assert(C.Prepare(source,b.pools,true))
 local live=assert(R.ConfirmRestore(source,req.report));assert(C.Accept(req.id,{ok=true,value=live},source));return C,live
end
local jane,a=participant(1,2);local john,b=participant(2,0)
local observed=copy(a.pools);observed.ammo_tomahawk_regular=1
local req=assert(jane.Prepare(1,observed,true));local work=assert(R.PrepareObservation(1,req.report))
assert(R.AttachQuantitySpend(work,{version=1,bucket=0,position={x=0,y=0,z=0}}))
assert(R.IsOperationCurrent(work.context,'observe',work.spec))
local forged=copy(work.spec);forged.quantityRecovery.bucket=1
assert(not R.IsOperationCurrent(work.context,'observe',forged),'client/caller cannot change reserved spend location')
a=assert(R.Complete(work.context,{ok=true,value={characterId='c1',revision=1,pools=observed}}))
assert(jane.Accept(req.id,{ok=true,value=a},1))
observed=copy(b.pools);observed.ammo_tomahawk_regular=1;observed.ammo_revolver_regular=6
req=assert(john.PrepareNativePickup(2,observed,true,true))
work=assert(R.PrepareQuantityPickup(2,req.report,{version=1,bucket=0,position={x=1,y=0,z=0}}))
assert(R.IsOperationCurrent(work.context,'pickup',work.spec))
b=assert(R.Complete(work.context,{ok=true,value={characterId='c2',revision=1,pools=observed}}))
assert(john.Accept(req.id,{ok=true,value=b},2))
assert(b.pools.ammo_tomahawk_regular==1 and b.pools.ammo_revolver_regular==6)
observed=copy(b.pools);observed.ammo_tomahawk_regular=2;observed.ammo_revolver_regular=5
req=assert(john.PrepareNativePickup(2,observed,true,true))
work=assert(R.PrepareQuantityPickup(2,req.report,{version=1,bucket=0,position={x=1,y=0,z=0}}))
local declined=copy(observed);declined.ammo_tomahawk_regular=1
b=assert(R.Complete(work.context,{ok=true,value={characterId='c2',revision=2,pools=declined,quantityDeclined=true,recovered=0}}))
local accepted,why=john.Accept(req.id,{ok=true,value=b,quantityDeclined=true,quantityAccepted=0},2)
assert(accepted and why=='quantity_declined' and accepted.pools.ammo_revolver_regular==5
 and accepted.pools.ammo_tomahawk_regular==1,'unfunded pickup compensation never restores fired rounds')
assert(not john.Accept(req.id,{ok=true,value=b,quantityDeclined=true,quantityAccepted=0},2),'late reply cannot match a new request')
observed=copy(b.pools);observed.ammo_tomahawk_regular=3;observed.ammo_revolver_regular=4
req=assert(john.PrepareNativePickup(2,observed,true,true))
work=assert(R.PrepareQuantityPickup(2,req.report,{version=1,bucket=0,position={x=1,y=0,z=0}}))
local partial=copy(observed);partial.ammo_tomahawk_regular=2
b=assert(R.Complete(work.context,{ok=true,value={characterId='c2',revision=3,pools=partial,quantityDeclined=true,recovered=1}}))
accepted,why=john.Accept(req.id,{ok=true,value=b,quantityDeclined=true,quantityAccepted=1},2)
assert(accepted and why=='quantity_declined' and accepted.pools.ammo_tomahawk_regular==2,'partial batch retains funded quantity')
observed=copy(b.pools);observed.ammo_tomahawk_regular=4
assert(not john.PrepareNativePickup(2,observed,true,true),'ceiling3')
observed=copy(b.pools);observed.ammo_tomahawk_regular=3;observed.ammo_revolver_regular=5
assert(not john.PrepareNativePickup(2,observed,true,true),'pickup cannot increase firearm ammunition')
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
assert(registry.throwableQuantityContract==1 and registry.limits.ammo_tomahawk_regular==3 and not WeaponNativeThrowablePolicy.UnitsEnabled())
local identity={characterId='c2',sessionId='s2',epoch='e2'}
local child={contract=3,kind='throwable_quantity',characterId='c2',identity=identity,revision=2,pools={}}
for id in pairs(registry.limits) do child.pools[id]=id=='ammo_tomahawk_regular' and 1 or 0 end
local assigned=assert(WeaponNativeThrowableItem.Assigned(child,WeaponDefinitionCatalog,identity,registry.limits))
assert(assigned.contract==3 and assigned.row==nil and #assigned.units==0)
local plan=assert(WeaponCharacterAmmoMaterialization.Build({},WeaponDefinitionCatalog,registry,identity))
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,child,registry.limits)
assert(not lease.Contains(113) and not lease.Contains(116),'quantity lease cannot claim historical physical item rows')
child.revision=3;child.pools.ammo_tomahawk_regular=2
assert(lease.Validate({characterId='c2',equipment={},throwableEquipment=child},WeaponDefinitionCatalog,registry))
print('PASS quantity protocol: actual client/server reservations, cross-player/same ledger flow, denial without firearm refund, ceiling, stale replies, quantity projection without item leases')
