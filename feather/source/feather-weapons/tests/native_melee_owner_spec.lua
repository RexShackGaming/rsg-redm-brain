Config={AmmunitionPools={enabled=false}}
dofile('shared/constants.lua')
dofile('shared/definitions/weapons.lua')
dofile('shared/native_melee_catalog.lua')
dofile('shared/native_knife.lua')
dofile('client/native_melee_owner.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
local identity={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',equipment={},expected={}}
for n,id in ipairs({'melee_knife','melee_machete','melee_hammer','melee_cleaver','melee_hatchet'}) do
 local slot=({'melee','melee_secondary','melee_tertiary','melee_quaternary','melee_quinary'})[n]
 local def=WeaponDefinitionCatalog.weapons[id]
 snapshot.equipment[slot]={id=n,revision=0,itemName=def.itemName,
  metadata=assert(WeaponNativeKnife.Build(def,{serialNumber='M-'..n}))}
 snapshot.expected['weapon_'..slot]={itemId=n,revision=0}
end
local approval=assert(WeaponNativeMeleeCatalog.Project(snapshot,WeaponDefinitionCatalog,identity))
assert(WeaponNativeMeleeCatalog.ValidateApproval(approval,WeaponDefinitionCatalog,identity))
local function fresh() return assert(WeaponNativeMeleeCatalog.Project(snapshot,WeaponDefinitionCatalog,identity)) end
local bad=fresh(); bad.items[1].projection.nativeWeaponName='WEAPON_RIFLE_BOLTACTION'
assert(not WeaponNativeMeleeCatalog.ValidateApproval(bad,WeaponDefinitionCatalog,identity))
bad=fresh(); bad.items[1].slot='unknown'; bad.items[1].equipmentSlot=nil
assert(not WeaponNativeMeleeCatalog.ValidateApproval(bad,WeaponDefinitionCatalog,identity))
bad=fresh(); bad.items[7]=bad.items[1]
assert(not WeaponNativeMeleeCatalog.ValidateApproval(bad,WeaponDefinitionCatalog,identity))
local function scenario(failAt,releaseFail,loseWorld)
 local created,removed={},{}
 local alive=true
 local group
 group=assert(WeaponNativeMeleeOwner.New(fresh(),WeaponDefinitionCatalog,identity,function(def,world)
  local phase='idle'
  world.epoch='adapter-mutation'; def.id='adapter-mutation'
  return {Create=function(row)
   assert(not group.Create(),'no reentrant aggregate creation')
   created[#created+1]=row.id; phase='active'
   if row.id==failAt then error('native created then threw') end
   return true
  end,Release=function()
   local id=created[#created-#removed]
   removed[#removed+1]=id
   if id==releaseFail then return nil end
   phase='released'; if loseWorld then alive=false end
   return true
  end,Status=function() return {phase=phase} end}
 end,function(world)
  assert(world.epoch=='e'); world.epoch='mutation'; return alive
 end))
 local ok=group.Create()
 if failAt then
  assert(not ok and group.Status().phase=='retained' and #created==failAt)
  assert(not group.Create() and not group.Release() and #removed==0)
 else
  assert(ok and #created==5)
  local released=group.Release()
  if releaseFail or loseWorld then assert(not released and group.Status().phase=='retained')
  else assert(released and #removed==5 and removed[1]==5 and removed[5]==1); assert(group.Release()) end
 end
end
scenario(); scenario(3); scenario(nil,5); scenario(nil,nil,true)
local factoryCalls=0
local uncertain=assert(WeaponNativeMeleeOwner.New(fresh(),WeaponDefinitionCatalog,identity,function()
 factoryCalls=factoryCalls+1; error('factory side effect then throw')
end,function() return true end))
assert(not uncertain.Create() and uncertain.Status().phase=='retained')
assert(not uncertain.Create() and not uncertain.Release() and factoryCalls==1)
local empty=assert(WeaponNativeMeleeCatalog.Project({characterId='john',equipment={},expected={}},WeaponDefinitionCatalog,identity))
local emptyOwner=assert(WeaponNativeMeleeOwner.New(empty,WeaponDefinitionCatalog,identity,function()
 error('empty owner must not call factory')
end,function() return true end))
assert(emptyOwner.Create() and emptyOwner.Release())
local plan={identity=identity,items={}}
WeaponCharacterAmmoMaterialization={Build=function() return plan end}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,fresh())
for n=1,5 do assert(lease.Contains(n)) end
assert(not lease.Contains(6))
local current={characterId='john',equipment={},meleeEquipment=snapshot}
assert(lease.Validate(current,WeaponDefinitionCatalog,{}))
snapshot.equipment.melee_secondary.revision=1
assert(not lease.Validate(current,WeaponDefinitionCatalog,{}))
snapshot.equipment.melee_secondary.revision=0
snapshot.equipment.melee_secondary.metadata.quality=99
assert(not lease.Validate(current,WeaponDefinitionCatalog,{}))
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('client/native_melee_owner.lua',1,true))
print('staged aggregate melee ownership/lease: exact approvals, partial failure retention, cleanup barrier, identity and full-row binding PASS')
