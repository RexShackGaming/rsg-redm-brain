Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_materialization.lua','shared/native_throwable_policy.lua',
 'shared/native_throwable_item.lua','client/character_ammunition_native.lua','client/character_ammunition_controller.lua',
 'client/character_ammunition_loadout.lua','client/character_ammunition_session.lua','client/native_throwable_owner.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local catalog=WeaponDefinitionCatalog
local registry=assert(WeaponNativeThrowablePolicy.Preview(catalog,assert(WeaponCharacterAmmoPolicy.Build(catalog)))).registry
local identity={characterId='john',sessionId='s',epoch='e'}
local pools={}; for id in pairs(registry.limits) do pools[id]=0 end
pools.ammo_tomahawk_regular=1
local item={id=170,revision=0,itemName='weapon_thrown_tomahawk',metadata=assert(WeaponNativeThrowableItem.Build(catalog,{serialNumber='T'}))}
local function bundle()
 return {creation={identity=identity,items={},dual=false,sameModel=false},runtime={characterId='john',sessionId='s',epoch='e',
 revision=3,phase='restoring',pools=copy(pools)},throwable={characterId='john',revision=3,pools=copy(pools),
 expected={weapon_throwable={itemId=170,revision=0}},equipment={throwable=item}}}
end
local function setup(mode)
 Config.DevMode=mode=='pickup'
 GetConvarInt=function(name) return mode=='pickup' and name=='feather_native_throwable_pickup' and 1 or 0 end
 local alive=true
 local counts={}; for _,name in pairs(registry.names) do counts[name]=0 end
 local queue,has,grants,cleanup,blocked={},false,0,0,false
 local api={ped=function() return 7 end,ready=function() return alive end,block=function(v) blocked=v end,hash=function(v) return v end,
 read=function(_,name) return counts[name] end,write=function(_,name,n) counts[name]=n end,
 send=function(kind,_,report,cb) queue[#queue+1]={kind=kind,report=report,cb=cb} end,
 deathSnapshot=function() local p={}; for id,name in pairs(registry.names) do p[id]=counts[name] end
  return {characterId='john',sessionId='s',ped=7,lifeState='dead',pools=p} end,
 creation=function() return {current=function() return true end,prepareDual=function() return true end,
  createSingle=function() error('no firearm grant expected') end,createPair=function() error('no pair') end,
  finish=function() return true end,remove=function() error('no firearm removal') end,
  cleanupSetup=function() cleanup=cleanup+1; return true end} end,
 throwable=function(_,id,sealed)
  if mode=='factory_throw' then error('uncertain factory') end
  return WeaponNativeThrowableOwner.New({current=function() return alive end,sealed=sealed,
   present=function() return has end,quantity=function() return counts.AMMO_TOMAHAWK end,
   createFunded=function()
    grants=grants+1; counts.AMMO_TOMAHAWK=1; has=true
    if mode=='foreign_pool' then counts.AMMO_REPEATER=1 end
    return {entity=70,guid=string.rep('a',32)}
   end,removeOwned=function()
    if mode=='cleanup_fail' then return false end
    has=false; counts.AMMO_TOMAHAWK=0; return true
   end,releaseSpent=function() return not has end,
   pickupEnabled=function() return mode=='pickup' end,
   rebindPickup=function()
    return {entity=0,inventoryOnly=true,guid=string.rep('b',32),itemId=170,itemRevision=0}
   end},catalog,id,registry.limits)
 end}
 local session=WeaponCharacterAmmoSession.New(api,registry)
 local durable={characterId='john',sessionId='s',epoch='e',revision=3,pools=copy(pools)}
 local function ack(kind,phase)
  local q=table.remove(queue,1); assert(q and q.kind==kind)
  local value
  if kind=='pickup' then
   assert(durable.pools.ammo_tomahawk_regular==0 and q.report.pools.ammo_tomahawk_regular==1)
   value=copy(durable); value.revision=value.revision+1; value.pools=copy(q.report.pools)
  elseif kind=='cleanup' then value=copy(durable)
  else value=assert(WeaponCharacterAmmunition.Observe(durable,q.report,registry.limits)) end
  value.phase=phase; durable=copy(value)
  q.cb({ok=true,value=value}); session.Tick()
 end
 return session,{ack=ack,queue=queue,counts=counts,die=function() alive=false end,revive=function() alive=true end,
  spent=function() counts.AMMO_TOMAHAWK=0; has=false end,
  pickup=function() counts.AMMO_TOMAHAWK=1; has=true end,blocked=function() return blocked end,
  totals=function() return grants,cleanup end}
end
for _,mode in ipairs({'unfunded','unthrown','spent','death','death_context','cleanup_fail','foreign_pool','factory_throw','pickup'}) do
 pools.ammo_tomahawk_regular=mode=='unfunded' and 0 or 1
 local session,c=setup(mode)
 local ok=session.Begin(bundle())
 if mode=='foreign_pool' or mode=='factory_throw' then
  assert(not ok and session.Status().phase=='frozen' and #c.queue==0)
  assert(not session.Cleanup() and #c.queue==0)
 else
  assert(ok and session.Status().throwable.phase==(mode=='unfunded' and 'empty' or 'active'))
  c.ack('restore','active')
  assert(not session.Transfer('ammo_tomahawk_regular',1,'transfer'),'funded carrier cannot be refilled without rebuild')
  if mode=='spent' or mode=='pickup' then c.spent(); assert(session.Tick()); c.ack('observe','active') end
  if mode=='pickup' then
   c.pickup(); assert(session.Tick())
   assert(session.Status().ammo.pendingKind=='pickup' and c.blocked() and session.Status().throwable.observedQuantity==0)
   c.ack('pickup','active')
   assert(session.Status().phase=='active' and session.Status().throwable.observedQuantity==1 and not c.blocked())
  end
  if mode=='death_context' then
   c.die(); session.Tick()
   assert(session.Status().phase=='active' and session.Status().throwable.phase=='active',
    'dead readiness loss must not invoke alive throwable observer')
  end
  if mode=='death' or mode=='death_context' then assert(session.FinalizeDeath()) else assert(session.Finalize()) end
  if mode=='death_context' then
   session.Tick(); assert(session.Status().throwable.phase=='active','pending death seal skips ordinary polling')
  end
  c.ack('seal','sealed')
  if mode=='death_context' then c.revive() end
  local cleaned=(mode=='death' or mode=='death_context') and session.RecoverDeath() or session.Cleanup()
  if mode=='cleanup_fail' then
   assert(not cleaned and session.Status().phase=='frozen' and #c.queue==0)
   local _,n=c.totals(); assert(n==0,'parent lease cannot close after child failure')
  else
   assert(cleaned); c.ack('cleanup','released'); assert(session.Status().phase=='closed' and session.Status().throwable==nil)
   local grants,n=c.totals(); assert(grants==(mode=='unfunded' and 0 or 1) and n==1)
  end
 end
end
pools.ammo_tomahawk_regular=1
local session,c=setup(); local bad=bundle(); bad.throwable.pools.ammo_tomahawk_regular=0
assert(not session.Begin(bad) and session.Status().phase=='closed' and c.totals()==0,'approval cannot disagree with runtime credit')
-- A character belt remains funded even without an equipped carrier. The
-- unassigned owner restores that belt and its cleanup does not spend it.
session,c=setup('unthrown')
local unassigned=bundle(); unassigned.throwable=nil
assert(session.Begin(unassigned)); c.ack('restore','active')
assert(session.Status().throwable==nil and c.counts.AMMO_TOMAHAWK==1)
assert(session.Finalize()); c.ack('seal','sealed'); assert(session.Cleanup()); c.ack('cleanup','released')
assert(session.Status().phase=='closed' and c.counts.AMMO_TOMAHAWK==1 and c.totals()==0)
assert(session.Begin(bundle()),'re-equip accepts funded belt only when carrier is absent')
c.ack('restore','active')
assert(session.Status().phase=='active' and session.Status().throwable.guidCaptured
 and session.Status().ammo.baseline.revision==3 and c.counts.AMMO_TOMAHAWK==1 and c.totals()==1)
print('actual throwable session/controller PASS: funded restore exception only, monotonic throw observation, exact seal/cleanup ack, death barrier, unrelated-pool/factory/cleanup refusal')
