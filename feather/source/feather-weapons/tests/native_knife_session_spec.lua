Config={AmmunitionPools={enabled=false}}
for _,path in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_knife.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_materialization.lua',
 'client/character_ammunition_native.lua','client/character_ammunition_controller.lua','client/character_ammunition_loadout.lua',
 'client/character_ammunition_session.lua','client/native_knife_owner.lua'}) do dofile(path) end
local def=WeaponDefinitionCatalog.weapons.melee_knife
local row={id=90,revision=0,itemName='weapon_melee_knife',metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='KNIFE'}))}
local id={characterId='c',sessionId='s',epoch='e'}
local approved=assert(WeaponNativeKnife.Assigned({characterId='c',expected={weapon_melee={itemId=90,revision=0}},
 equipment={melee=row}},def,id))
local registry={names={regular='AMMO_PISTOL'},limits={regular=200},weapons={gun={nativeWeaponName='WEAPON_PISTOL_M1899',
 family='pistol',compatible={regular=true}}}}
local function bundle()
 return {runtime={characterId='c',sessionId='s',epoch='e',revision=4,phase='restoring',pools={regular=8}},
 knife=approved,creation={identity=id,dual=false,sameModel=false,items={{slot='primary',point=2,
 itemInstanceId=1,itemRevision=0,definitionId='gun',nativeWeaponName='WEAPON_PISTOL_M1899',preferredAmmoType='regular',
 copyKey='primary:1:0',creation='native_zero_ammo_grant',attachments={},cosmetics={}}}}}
end
local function setup(change)
 local pool,queue,exists,entity,blocked=0,{},false,70,true
 local writes,grants,removes=0,0,0
 local knifeApi={current=function() return true end,present=function() return exists end,
  observe=function() return {entity} end,grant=function() grants=grants+1; exists=true; return true end,
  remove=function() removes=removes+1; exists=false; return true end}
 local api={ped=function() return 7 end,ready=function() return true end,hash=function(v) return v end,
  block=function(v) blocked=v end,read=function() return pool end,write=function(_,_,v) writes=writes+1; pool=v end,
  deathSnapshot=function() return {characterId='c',sessionId='s',ped=7,lifeState='dead',pools={regular=pool}} end,
  send=function(kind,_,report,cb) queue[#queue+1]={kind=kind,report=report,cb=cb} end,
  creation=function() return {current=function() return true end,prepareDual=function() return true end,
   createSingle=function() return {entity=50} end,createPair=function() error('no pair') end,
   finish=function() return true end,remove=function() return true end} end,
  knife=function(_,identity) return assert(WeaponNativeKnifeOwner.New(knifeApi,def,identity)) end}
 if change then change(api,knifeApi) end
 local session=WeaponCharacterAmmoSession.New(api,registry)
 local function ack(kind,phase)
  local q=table.remove(queue,1); assert(q and q.kind==kind); q.report.phase=phase
  q.cb({ok=true,value=q.report}); session.Tick()
 end
 return session,{ack=ack,queue=queue,counts=function() return writes,grants,removes,blocked end,
 replacement=function() entity=71 end}
end
local s,c=setup(); assert(s.Begin(bundle())); assert(s.Status().knife.phase=='active')
c.ack('restore','active'); assert(s.Finalize()); c.ack('seal','sealed')
assert(s.Cleanup()); local _,grants,removed=c.counts(); assert(grants==1 and removed==1)
c.ack('cleanup','released'); assert(s.Status().phase=='closed' and s.Status().knife==nil)
-- Death recovery uses the same cleanup barrier and cannot bypass the knife.
s,c=setup(); assert(s.Begin(bundle())); c.ack('restore','active')
assert(s.FinalizeDeath()); c.ack('seal','sealed')
assert(not s.Cleanup(),'dead cleanup requires explicit recovery')
assert(s.RecoverDeath()); c.ack('cleanup','released'); assert(s.Status().phase=='closed')
-- Replacement/uncertain cleanup blocks the shared release acknowledgement.
s,c=setup(); assert(s.Begin(bundle())); c.ack('restore','active')
assert(s.Finalize()); c.ack('seal','sealed'); c.replacement()
assert(not s.Cleanup() and s.Status().phase=='frozen' and #c.queue==0)
local _,_,removed,blocked=c.counts(); assert(removed==0 and blocked)
s,c=setup(function(_,knife) knife.grant=function() error('uncertain native create') end end)
assert(not s.Begin(bundle()) and s.Status().phase=='frozen')
assert(c.counts()==0 and #c.queue==0,'unknown knife create cannot restore ammo or acknowledge activation')
s,c=setup(function(api) api.knife=function() error('factory unknown') end end)
assert(not s.Begin(bundle()) and not s.Cleanup() and #c.queue==0 and s.Status().knife.phase=='factory_unconfirmed')
s,c=setup(function(api) api.knife=nil end)
assert(not s.Begin(bundle()) and s.Status().phase=='closed' and c.counts()==0)
local bad=bundle(); bad.knife={identity={characterId='foreign',sessionId='s',epoch='e'},equipmentSlot='weapon_melee',row=row}
s,c=setup(); assert(not s.Begin(bad) and s.Status().phase=='closed' and c.counts()==0)
s,c=setup(function(api,knife)
 local changed=false
 api.read=function() return changed and 1 or 0 end
 knife.grant=function() changed=true; return true end
end)
assert(not s.Begin(bundle()) and s.Status().phase=='frozen' and c.counts()==0 and #c.queue==0,
 'knife creation changing firearm pools cannot restore or acknowledge')
s,c=setup(function(api)
 local factory=api.knife
 api.knife=function(...)
  local owner=factory(...); owner.Release=function() return true end
  return owner
 end
end)
assert(s.Begin(bundle())); c.ack('restore','active'); assert(s.Finalize()); c.ack('seal','sealed')
assert(not s.Cleanup() and #c.queue==0,'release true alone is not proof of released knife state')
print('knife shared-session seam PASS (same activation/seal/death cleanup ack, no knife bypass, unresolved holds freeze, firearm-only unchanged)')
