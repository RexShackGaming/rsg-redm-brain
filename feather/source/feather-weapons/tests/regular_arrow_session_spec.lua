Config={NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
 NativeAlphaLifecycleWearEnabled=true,AmmunitionPools={enabled=false}}
GetConvarInt=function(name,default) return name=='feather_regular_arrows' and 1 or default end
for _,p in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua','shared/validation.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_client.lua','shared/character_ammunition_runtime.lua',
 'shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua',
 'shared/character_ammunition_materialization.lua','client/character_ammunition_native.lua',
 'client/character_ammunition_controller.lua','client/character_ammunition_loadout.lua','client/character_ammunition_session.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local full=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local registry={names={ammo_arrow_regular='AMMO_ARROW',ammo_revolver_regular='AMMO_REVOLVER'},
 limits={ammo_arrow_regular=40,ammo_revolver_regular=100},weapons={bow=full.weapons.bow}}
local row={id=901,revision=0,itemName='weapon_bow',metadata={schemaVersion=2,weaponDefinitionId='bow',serialNumber='BOW-TEST',
 quality=100,condition=100,maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
 ammo={ownership='character',type='ammo_arrow_regular'},attachments={},cosmetics={},flags={stolen=false,evidence=false,disabled=false},provenance={}}}
local R=WeaponCharacterAmmoRuntime.New(function() return true end)
local live=assert(R.Open({source=1,characterId='jane',sessionId='s'},
 {characterId='jane',revision=0,pools={ammo_arrow_regular=5,ammo_revolver_regular=7}},registry.limits,'e'))
local plan=assert(WeaponCharacterAmmoMaterialization.Build({shoulder=row},WeaponDefinitionCatalog,registry,
 {characterId='jane',sessionId='s',epoch='e'}))
local native={AMMO_ARROW=0,AMMO_REVOLVER=0}
local queue,writes,creates,removes={},0,0,0
local api={ped=function() return 1 end,ready=function() return true end,hash=function(n) return n end,
 read=function(_,h) return native[h] end,write=function(_,h,n) writes=writes+1;native[h]=n end,
 remove=function(_,h,n) native[h]=native[h]-n end,block=function() end,
 send=function(kind,id,report,callback) queue[#queue+1]={kind=kind,report=report,callback=callback} end,
 creation=function() return {current=function() return true end,prepareDual=function() return true end,
  createSingle=function(item) creates=creates+1;assert(item.nativeWeaponName=='WEAPON_BOW');return {name='WEAPON_BOW',entity=99} end,
  createPair=function() error('not a sidearm pair') end,finish=function() return true end,
  remove=function(record) assert(record.name=='WEAPON_BOW');removes=removes+1;native.AMMO_ARROW=0;return true end} end}
local session=WeaponCharacterAmmoSession.New(api,registry)
local function nextRequest(kind) local q=table.remove(queue,1);assert(q and q.kind==kind);return q end
assert(session.Begin({creation=plan,runtime=live}) and creates==1)
local q=nextRequest('restore');live=assert(R.ConfirmRestore(1,q.report));q.callback({ok=true,value=live});assert(session.Tick())
assert(native.AMMO_ARROW==5)
local where={version=1,bucket=0,position={x=0,y=0,z=0}}
native.AMMO_ARROW=4
assert(session.Tick());q=nextRequest('observe');local work=assert(R.PrepareObservation(1,q.report));assert(R.AttachQuantitySpend(work,where))
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=1,pools=copy(q.report.pools)}}));q.callback({ok=true,value=live})
native.AMMO_ARROW=5;local before=writes
assert(session.Tick());q=nextRequest('pickup');work=assert(R.PrepareQuantityPickup(1,q.report,where))
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=2,pools=copy(q.report.pools)}}));q.callback({ok=true,value=live})
assert(session.Tick() and creates==1 and writes==before and native.AMMO_ARROW==5,'native recovery grants neither bow nor ammunition')
native.AMMO_ARROW=7;native.AMMO_REVOLVER=6
assert(session.Tick());q=nextRequest('pickup');work=assert(R.PrepareQuantityPickup(1,q.report,where))
local accepted=copy(q.report.pools);accepted.ammo_arrow_regular=6
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=3,pools=accepted,quantityDeclined=true,recovered=1}}))
native.AMMO_ARROW=8 -- one more native pickup arrives during SQL
q.callback({ok=true,value=live,quantityDeclined=true,quantityAccepted=1})
assert(native.AMMO_ARROW==7 and native.AMMO_REVOLVER==6,'compensate rejected units only; preserve later provisional pickup and firearm debit')
assert(session.Tick());q=nextRequest('pickup');work=assert(R.PrepareQuantityPickup(1,q.report,where))
live=assert(R.Complete(work.context,{ok=true,value={characterId='jane',revision=4,pools=copy(q.report.pools)}}));q.callback({ok=true,value=live});assert(session.Tick())
assert(session.Finalize());q=nextRequest('seal');work=assert(R.PrepareFinalObservation(1,q.report));q.callback({ok=true,value=work.value});session.Tick()
assert(session.Cleanup());q=nextRequest('cleanup');live=assert(R.ConfirmCleanup(1,q.report));q.callback({ok=true,value=live});session.Tick()
assert(removes==1 and native.AMMO_ARROW==0 and session.Status().phase=='closed' and live.pools.ammo_arrow_regular==7)
print('PASS regular-arrow session composition: owned bow creation, shot debit, read-only pickup acknowledgement, partial rejection compensation and sealed cleanup retain saved quantities')
