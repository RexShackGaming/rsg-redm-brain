Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,NativeThrowableQuantityContract=1,AmmunitionPools={enabled=false}}
GetConvarInt=function(name) return name=='feather_throwable_quantities' and 1 or 0 end
for _,p in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_runtime.lua',
 'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua','shared/native_throwable_policy.lua',
 'shared/native_throwable_item.lua','shared/character_ammunition_item.lua','shared/character_ammunition_materialization.lua',
 'client/character_ammunition_native.lua','client/character_ammunition_controller.lua','client/character_ammunition_loadout.lua',
 'client/character_ammunition_session.lua','client/throwable_quantity_owner.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local registry={names={ammo_tomahawk_regular='AMMO_TOMAHAWK',ammo_revolver_regular='AMMO_REVOLVER'},
 limits={ammo_tomahawk_regular=3,ammo_revolver_regular=100},weapons={},throwableQuantityContract=1}
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local initial={characterId='john',revision=0,pools={ammo_tomahawk_regular=0,ammo_revolver_regular=7}}
local live=assert(R.Open({source=7,characterId='john',sessionId='s'},initial,registry.limits,'quantity-session'))
local identity={characterId='john',sessionId='s',epoch=live.epoch}
local plan=assert(WeaponCharacterAmmoMaterialization.Build({},WeaponDefinitionCatalog,registry,identity))
local bundle={runtime=live,creation=plan,throwable={contract=3,kind='throwable_quantity',characterId='john',
 identity=identity,revision=0,pools=copy(initial.pools)}}
local native={AMMO_TOMAHAWK=0,AMMO_REVOLVER=0}
local queue,blocked={},true
local carrier,materialized,cleaned,restored,removed=false,0,0,0,0
local api={ped=function() return 7 end,ready=function() return true end,hash=function(n) return n end,
 read=function(_,h) return native[h] end,write=function(_,h,n) native[h]=n end,
 remove=function(_,h,n) removed=removed+n;native[h]=native[h]-n end,
 block=function(v) blocked=v end,send=function(kind,id,report,callback) queue[#queue+1]={kind=kind,id=id,report=report,callback=callback} end,
 creation=function() return {current=function() return true end,prepareDual=function() return true end,
  createSingle=function() error('no firearm grant') end,createPair=function() error('no pair') end,
  finish=function() return true end,remove=function() error('no firearm removal') end} end,
 throwable=function(_,bound,sealed)
  return WeaponThrowableQuantityOwner.New({current=function() return true end,sealed=sealed,
   quantity=function() return native.AMMO_TOMAHAWK end,find=function() return carrier and {guid='one-carrier'} or false end,
   materialize=function() materialized=materialized+1;carrier=true;return {guid='one-carrier'} end,
   remove=function() cleaned=cleaned+1;carrier=false;native.AMMO_TOMAHAWK=0;return true end,
   allow=function() return true end,suppress=function() return true end,
   restorePermissions=function() restored=restored+1;return true end},
   WeaponDefinitionCatalog,bound,registry.limits)
 end}
local session=WeaponCharacterAmmoSession.New(api,registry)
local function nextRequest(kind)
 local q=table.remove(queue,1);assert(q and q.kind==kind,kind);return q
end
local function restoreAck()
 local q=nextRequest('restore');live=assert(R.ConfirmRestore(7,q.report));q.callback({ok=true,value=live});assert(session.Tick())
end
assert(session.Begin(bundle) and materialized==0);restoreAck();assert(not blocked)
assert(session.Transfer('ammo_tomahawk_regular',1,'paid-load'))
local q=nextRequest('transfer');local work=assert(R.PrepareTransfer(7,q.report,'ammo_tomahawk_regular',1,'paid-load'))
live=assert(R.Complete(work.context,{ok=true,value={characterId='john',revision=1,pools={ammo_tomahawk_regular=1,ammo_revolver_regular=7}}}))
q.callback({ok=true,value=live});assert(materialized==1 and native.AMMO_TOMAHAWK==1);restoreAck()
native.AMMO_TOMAHAWK=0;carrier=false -- ordinary game throw
assert(session.Tick());q=nextRequest('observe');work=assert(R.PrepareObservation(7,q.report))
assert(R.AttachQuantitySpend(work,{version=1,bucket=0,position={x=0,y=0,z=0}}))
live=assert(R.Complete(work.context,{ok=true,value={characterId='john',revision=2,pools=copy(q.report.pools)}}))
q.callback({ok=true,value=live});assert(session.Tick() and not blocked)
native.AMMO_TOMAHAWK=1 -- game-native collection; no arm, escrow or entity deletion
assert(session.Tick());q=nextRequest('pickup');work=assert(R.PrepareQuantityPickup(7,q.report,{version=1,bucket=0,position={x=0,y=0,z=0}}))
live=assert(R.Complete(work.context,{ok=true,value={characterId='john',revision=3,pools=copy(q.report.pools)}}))
q.callback({ok=true,value=live});assert(session.Tick() and materialized==2 and cleaned==0 and not blocked)
native.AMMO_TOMAHAWK=2;native.AMMO_REVOLVER=6 -- unfunded pickup plus real fired round
assert(session.Tick());q=nextRequest('pickup');work=assert(R.PrepareQuantityPickup(7,q.report,{version=1,bucket=0,position={x=0,y=0,z=0}}))
local deniedPools=copy(q.report.pools);deniedPools.ammo_tomahawk_regular=1
live=assert(R.Complete(work.context,{ok=true,value={characterId='john',revision=4,pools=deniedPools,quantityDeclined=true,recovered=0}}))
native.AMMO_TOMAHAWK=3 -- another pickup arrives while this result is in flight
q.callback({ok=true,value=live,quantityDeclined=true,quantityAccepted=0})
assert(native.AMMO_TOMAHAWK==2 and native.AMMO_REVOLVER==6 and removed==1,
 'compensation removes only rejected report units, preserving subsequent provisional pickup')
assert(session.Tick());q=nextRequest('pickup');work=assert(R.PrepareQuantityPickup(7,q.report,{version=1,bucket=0,position={x=0,y=0,z=0}}))
deniedPools=copy(q.report.pools);deniedPools.ammo_tomahawk_regular=1
live=assert(R.Complete(work.context,{ok=true,value={characterId='john',revision=5,pools=deniedPools,quantityDeclined=true,recovered=0}}))
q.callback({ok=true,value=live,quantityDeclined=true,quantityAccepted=0})
assert(session.Tick() and native.AMMO_TOMAHAWK==1 and native.AMMO_REVOLVER==6 and removed==2 and not blocked)
assert(session.Transfer('ammo_tomahawk_regular',-1,'store-generic'))
q=nextRequest('transfer');work=assert(R.PrepareTransfer(7,q.report,'ammo_tomahawk_regular',-1,'store-generic'))
live=assert(R.Complete(work.context,{ok=true,value={characterId='john',revision=6,pools={ammo_tomahawk_regular=0,ammo_revolver_regular=6}}}))
q.callback({ok=true,value=live});restoreAck()
assert(session.Finalize());q=nextRequest('seal');work=assert(R.PrepareFinalObservation(7,q.report))
live=work.value;q.callback({ok=true,value=live});session.Tick()
assert(session.Cleanup() and cleaned==1 and restored==1)
q=nextRequest('cleanup');live=assert(R.ConfirmCleanup(7,q.report));q.callback({ok=true,value=live});session.Tick()
assert(session.Status().phase=='closed' and native.AMMO_REVOLVER==6 and cleaned==1)
-- Reconnect with funded quantity: carrier creation must preserve the initial
-- zero native pool, then the controller restores the authoritative balance.
for _,funded in ipairs({1,3}) do
 native.AMMO_TOMAHAWK=0;native.AMMO_REVOLVER=0;carrier=false;queue={}
 local restarted=copy(bundle)
 restarted.runtime.pools.ammo_tomahawk_regular=funded
 restarted.throwable.pools.ammo_tomahawk_regular=funded
 local resumed=WeaponCharacterAmmoSession.New(api,registry)
 assert(resumed.Begin(restarted),'funded quantity reconnect must reach restore')
 assert(native.AMMO_TOMAHAWK==funded and native.AMMO_REVOLVER==7)
 nextRequest('restore')
end
print('PASS quantity session/controller/native pool composition: ordinary load/store, paid throw, native pickup without handoff/rebuild, definite rejection clears excess only, sealed carrier cleanup; modeled native/SQL ports')
