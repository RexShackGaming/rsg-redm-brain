Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','client/native_throwable_owner.lua'}) do dofile(p) end
local catalog=WeaponDefinitionCatalog
local candidate=assert(WeaponNativeThrowablePolicy.Preview(catalog,assert(WeaponCharacterAmmoPolicy.Build(catalog))))
local pools={}; for id in pairs(candidate.registry.limits) do pools[id]=0 end
local row={id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='T'}))}
local function run(mode)
 local count,has,world,sealed,grants,removed,spent=0,false,true,false,0,0,0
 local snapshot={characterId='john',revision=3,pools={},expected={weapon_throwable={itemId=170,revision=0}},equipment={throwable=row}}
 for k,v in pairs(pools) do snapshot.pools[k]=v end
 snapshot.pools.ammo_tomahawk_regular=mode=='empty' and 0 or 1
 local owner
 local api={current=function() return world end,sealed=function() return sealed end,
  quantity=function() return count end,present=function() return has end,
  createFunded=function(approval)
   assert(approval.fundedQuantity==1 and approval.row.metadata.ammo.quantity==nil)
   assert(not owner.Create(snapshot),'factory cannot reenter create')
   grants=grants+1; count=1; has=true
   if mode=='creation_throw' then error('grant then throw') end
   if mode=='readback_failed' then count=2 end
   return {entity=70,guid=string.rep('a',32)}
  end,removeOwned=function(handle)
   assert(handle.guid==string.rep('a',32)); removed=removed+1; count=0; has=false
   if mode=='cleanup_failed' then return nil end
   return true
  end,releaseSpent=function(handle)
   assert(handle.entity==70); spent=spent+1; has=false; return true
  end}
 owner=WeaponNativeThrowableOwner.New(api,catalog,{characterId='john',sessionId='s',epoch='e'},candidate.registry.limits)
 assert(owner.Status().phase=='idle' and grants==0)
 local created=owner.Create(snapshot)
 if mode=='creation_throw' or mode=='readback_failed' then
  assert(not created and owner.Status().phase=='retained' and not owner.Create(snapshot))
  assert(not owner.Release() and removed==0); return
 end
 assert(created and grants==(mode=='empty' and 0 or 1))
 assert(not owner.Release() and removed==0 and spent==0,'existing seal required before cleanup')
 if mode=='throw' or mode=='pickup' then
  count=0; assert(owner.Observe().quantity==0)
  if mode=='pickup' then
   count=1; assert(not owner.Observe() and owner.Status().phase=='retained')
   local status=owner.Status()
   local evidence=assert(status.nativeIncrease)
   assert(evidence.kind=='native_pool_increase' and evidence.previousQuantity==0
    and evidence.observedQuantity==1 and evidence.units==1 and evidence.itemId==170
    and evidence.itemRevision==0 and evidence.ammunitionId=='ammo_tomahawk_regular'
    and evidence.identity.characterId=='john' and evidence.identity.sessionId=='s'
    and evidence.identity.epoch=='e' and evidence.pickupConfirmed==false
    and evidence.pickupCredits==false and evidence.clientDiagnosticOnly==true)
   assert(status.observedQuantity==0 and snapshot.pools.ammo_tomahawk_regular==1,
    'diagnostic increase does not accept native ammo or mutate snapshot')
   evidence.identity.epoch='tampered'; evidence.units=99
   assert(owner.Status().nativeIncrease.identity.epoch=='e' and owner.Status().nativeIncrease.units==1)
   assert(not owner.Observe(),'retained increase cannot be observed/credited twice')
   assert(not owner.Release() and removed==0 and spent==0); return
  end
 end
 if mode=='world_lost' then
  world=false; count=1
  assert(not owner.Observe() and owner.Status().phase=='retained' and owner.Status().nativeIncrease==nil)
  return
 end
 sealed={characterId='john',sessionId='s',epoch='e',phase='sealed',revision=mode=='throw' and 4 or 3,pools={}}
 for k,v in pairs(snapshot.pools) do sealed.pools[k]=v end
 if mode=='throw' then sealed.pools.ammo_tomahawk_regular=0 end
 if mode=='stale_seal' then sealed.pools.ammo_tomahawk_regular=0 end
 local released=owner.Release()
 if mode=='stale_seal' then assert(not released and removed==0 and owner.Status().reason=='throwable_final_observation_not_sealed'); return end
 if mode=='cleanup_failed' then
  assert(not released and owner.Status().phase=='retained' and removed==1)
  assert(not owner.Release() and removed==1); return
 end
 assert(released and owner.Status().phase=='released' and owner.Release())
 assert(removed==((mode=='empty' or mode=='throw') and 0 or 1))
 assert(spent==(mode=='throw' and 1 or 0))
 assert(snapshot.pools.ammo_tomahawk_regular==(mode=='empty' and 0 or 1),'owner never mutates economic ledger')
end
for _,mode in ipairs({'funded','empty','throw','pickup','creation_throw','readback_failed','cleanup_failed','world_lost','stale_seal'}) do run(mode) end
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('client/native_throwable_owner.lua',1,true))
print('inert funded throwable owner PASS: no unfunded grant, monotonic observations/no pickup credit, existing seal, spent-proof versus exact cleanup, uncertainty retained')
