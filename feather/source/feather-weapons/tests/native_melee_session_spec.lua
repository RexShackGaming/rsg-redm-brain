Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/native_melee_catalog.lua',
 'shared/native_knife.lua','client/native_melee_owner.lua','client/character_ammunition_session.lua'}) do dofile(p) end
local id={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',expected={},equipment={}}
for n,name in ipairs({'knife','machete','hammer','cleaver','hatchet'}) do
 local slot=({'melee','melee_secondary','melee_tertiary','melee_quaternary','melee_quinary'})[n]
 local def=WeaponDefinitionCatalog.weapons['melee_'..name]
 snapshot.equipment[slot]={id=n,revision=0,itemName=def.itemName,
  metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='M-'..n}))}
 snapshot.expected['weapon_'..slot]={itemId=n,revision=0}
end
local approval=assert(WeaponNativeMeleeCatalog.Project(snapshot,WeaponDefinitionCatalog,id))
WeaponCharacterAmmoMaterialization={Validate=function() return true end}
WeaponCharacterAmmoClient={New=function() return {Begin=function() return {} end} end}
WeaponCharacterAmmoNative={New=function() return {Read=function() return {ammo=0} end} end}
WeaponCharacterAmmoLoadout={New=function() return {Create=function() return {handles={}} end} end}
local function scenario(failCreate,failRelease,death)
 local state={phase='active'}
 local grants,removed,acks,setup,restores=0,0,0,0,0
 WeaponCharacterAmmoController={New=function() return {
  Status=function() return state end,Begin=function() restores=restores+1; return true end,
  Finalize=function() state.phase='sealed'; return true end,
  FinalizeDeath=function() state.phase='sealed'; state.deathClosing=true; return true end,
  AllowDeathCleanup=function() state.deathClosing=false; return true end,
  ConfirmCleanup=function() acks=acks+1; return true end} end}
 local api={ped=function() return 7 end,ready=function() return true end,block=function() end,
  creation=function() return {cleanupSetup=function() setup=setup+1; return true end} end,
  melee=function(_,identity,approved)
   return assert(WeaponNativeMeleeOwner.New(approved,WeaponDefinitionCatalog,identity,function()
    local phase='idle'
    return {Create=function(row)
     grants=grants+1; if row.id==failCreate then error('uncertain grant') end
     phase='active'; return true
    end,Release=function(recovery)
     assert(recovery==(death==true),'only doctor recovery propagates death absence permission')
     removed=removed+1; if failRelease then return nil end
     phase='released'; return true
    end,Status=function() return {phase=phase} end}
   end,function() return true end))
  end}
 local session=WeaponCharacterAmmoSession.New(api,{limits={},names={}})
 local bundle={runtime=id,creation={identity=id},melee=approval}
 local ok=session.Begin(bundle)
 if failCreate then
  assert(not ok and grants==failCreate and restores==0)
  assert(not session.Cleanup() and acks==0 and setup==0)
 else
  assert(ok and grants==5 and restores==1 and session.Status().melee.phase=='active' and session.Status().knife==nil)
  if death then assert(session.FinalizeDeath()); assert(not session.Cleanup()) else assert(session.Finalize()) end
  local cleaned=death and session.RecoverDeath() or session.Cleanup()
  if failRelease then assert(not cleaned and acks==0 and setup==0 and session.Status().phase=='frozen')
  else assert(cleaned and removed==5 and acks==1 and setup==1) end
 end
end
scenario(); scenario(nil,nil,true); scenario(3); scenario(nil,true)
print('aggregate melee actual session PASS: five-copy creation before ammo restore, same death/shutdown cleanup barrier, partial failure blocks acknowledgement')
