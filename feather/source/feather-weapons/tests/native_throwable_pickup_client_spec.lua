Config={DevMode=true,AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua','shared/native_throwable_item.lua','shared/character_ammunition_client.lua',
 'client/character_ammunition_native.lua','client/character_ammunition_controller.lua','client/native_throwable_owner.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local registry=assert(WeaponNativeThrowablePolicy.Preview(WeaponDefinitionCatalog,
 assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog)))).registry
local gate=1
GetConvarInt=function(name) return name=='feather_native_throwable_pickup' and gate or 0 end
local identity={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',revision=10,pools={},expected={weapon_throwable={itemId=165,revision=0}},
 equipment={throwable={id=165,revision=0,itemName='weapon_thrown_tomahawk',
 metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='T'}))}}}
for id in pairs(registry.limits) do snapshot.pools[id]=0 end
snapshot.pools.ammo_tomahawk_regular=1; snapshot.pools.ammo_repeater_regular=1
local function run(mode)
 local native={}; for id,name in pairs(registry.names) do native[name]=snapshot.pools[id] end
 local queue,writes,rebinds,blocked={},0,0,false
 local world,ped=true,7
 local has=false; native.AMMO_TOMAHAWK=0
 local owner=WeaponNativeThrowableOwner.New({
  current=function() return world end,sealed=function() return nil end,present=function() return has end,
  quantity=function() return native.AMMO_TOMAHAWK end,
  createFunded=function() has=true; native.AMMO_TOMAHAWK=1; return {entity=70,guid=string.rep('a',32)} end,
  removeOwned=function() error('not requested') end,releaseSpent=function() error('not requested') end,
  pickupEnabled=function() return gate==1 end,rebindPickup=function(handle,bound)
   assert(handle.guid==string.rep('a',32) and bound.epoch=='e'); rebinds=rebinds+1
   if mode=='rebind_failure' then return nil end
   return {entity=0,inventoryOnly=true,guid=string.rep('b',32),itemId=165,itemRevision=0}
  end},WeaponDefinitionCatalog,identity,registry.limits)
 assert(owner.Create(snapshot))
 local api={ready=function() return world end,ped=function() return ped end,hash=function(v) return v end,
  read=function(_,hash) return native[hash] end,write=function(_,hash,n) writes=writes+1; native[hash]=n end,
  block=function(v) blocked=v end,send=function(kind,id,report,callback)
   queue[#queue+1]={kind=kind,id=id,report=copy(report),callback=callback}
  end}
 local controller=WeaponCharacterAmmoController.New(api,function(baseline) return owner.AcceptNativePickup(baseline) end)
 local initial=copy(identity); initial.phase='restoring'; initial.revision=10; initial.pools=copy(snapshot.pools)
 assert(controller.Begin(initial,registry.names,registry.limits))
 local q=table.remove(queue,1); assert(q.kind=='restore')
 local ack=copy(initial); ack.phase='active'; q.callback({ok=true,value=ack})
 native.AMMO_TOMAHAWK=0; assert(owner.Observe(controller.Status().baseline).quantity==0)
 assert(controller.Tick()); q=table.remove(queue,1); assert(q.kind=='observe')
 ack=copy(q.report); ack.revision=11; ack.phase='active'; q.callback({ok=true,value=ack})
 local beforeWrites=writes
 native.AMMO_TOMAHAWK=1
 assert(owner.Observe(controller.Status().baseline).pickupCandidate and owner.Status().observedQuantity==0)
 assert(controller.Tick()); q=table.remove(queue,1)
 assert(q.kind=='pickup' and q.report.revision==11 and q.report.nativePickupPlan==nil
  and q.report.spendReceiptId==nil and controller.Status().pendingKind=='pickup' and blocked)
 assert(not owner.Release(),'pending recovery cannot be cleaned up')
 assert(not controller.Tick() and #queue==0,'one in-flight request, no resend')
 if mode=='timeout' then
  q.callback({ok=false,error={code='runtime_request_timeout'}})
  assert(controller.Status().phase=='frozen' and rebinds==0 and owner.Status().observedQuantity==0)
  -- A server commit may have succeeded before the transport timed out. Its
  -- delayed success must not thaw this owner or perform an unreserved rebind.
  ack=copy(q.report); ack.phase='active'; ack.revision=12
  q.callback({ok=true,value=ack})
  assert(controller.Status().phase=='frozen' and rebinds==0)
  assert(not controller.Tick() and #queue==0,'timeout never automatically resends pickup')
 elseif mode=='closed_reply' then
  controller.Close()
  ack=copy(q.report); ack.phase='active'; ack.revision=12
  q.callback({ok=true,value=ack})
  assert(controller.Status().phase=='closed' and rebinds==0,'closed lifetime ignores delayed pickup success')
 elseif mode=='ped_changed' then
  ped=8
  ack=copy(q.report); ack.phase='active'; ack.revision=12
  q.callback({ok=true,value=ack})
  assert(controller.Status().phase=='suspended' and rebinds==0,'replacement ped cannot inherit pending pickup')
 elseif mode=='world_left' then
  world=false
  ack=copy(q.report); ack.phase='active'; ack.revision=12
  q.callback({ok=true,value=ack})
  assert(controller.Status().phase=='frozen' and rebinds==0,'world exit prevents pickup GUID rebind')
 else
  ack=copy(q.report); ack.phase='active'; ack.revision=12
  if mode=='bad_ack' then ack.epoch='foreign' end
  q.callback({ok=true,value=ack})
  if mode=='bad_ack' or mode=='rebind_failure' then assert(controller.Status().phase=='frozen')
  else
   assert(controller.Status().phase=='active' and owner.Status().observedQuantity==1 and rebinds==1 and not owner.Status().nativeIncrease)
   q.callback({ok=true,value=ack}); assert(rebinds==1,'duplicate callback cannot rebind/credit twice')
  end
 end
 assert(writes==beforeWrites and native.AMMO_REPEATER==1,'pickup acknowledgement never restores native ammo or foreign pools')
end
for _,mode in ipairs({'success','timeout','closed_reply','ped_changed','world_left','bad_ack','rebind_failure'}) do run(mode) end
-- The specialized pure client request cannot carry simultaneous consumption,
-- missing pools or increases in any other type.
local C=WeaponCharacterAmmoClient.New()
local initial=copy(identity); initial.phase='restoring'; initial.revision=11; initial.pools=copy(snapshot.pools); initial.pools.ammo_tomahawk_regular=0
assert(C.Begin(initial,registry.limits,7)); local req=assert(C.Prepare(7,initial.pools,true))
local ack=copy(initial); ack.phase='active'; assert(C.Accept(req.id,{ok=true,value=ack},7))
local pools=copy(initial.pools); pools.ammo_tomahawk_regular=1; pools.ammo_repeater_regular=0
assert(not C.PrepareNativePickup(7,pools,true)); pools.ammo_repeater_regular=1; pools.ammo_rifle_regular=nil
assert(not C.PrepareNativePickup(7,pools,true))
print('native pickup client PASS: committed-zero candidate, one request/exact ack, GUID rebind callback, timeout/refusal/failure freeze, no native restore')
