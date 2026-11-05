dofile('tests/native_utility_item_spec.lua')
dofile('client/native_utility_owner.lua')
local def=WeaponDefinitionCatalog.weapons.utility_lasso
local identity={characterId='john',sessionId='s',epoch='e'}
local approval={identity=identity,equipmentSlot='weapon_utility',row={id=200,revision=0,itemName='weapon_lasso',
 metadata={schemaVersion=2,weaponDefinitionId='utility_lasso',serialNumber='L',condition=100,quality=100,
 flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}}
local function run(mode)
 local creates,removes,world=0,0,true
 local owner
 local api={current=function() return world end,
 present=function() if mode=='present' then return true end; return false end,
 create=function(p)
  assert(p.nativeGrantAmount==0 and p.nativeWeaponName=='WEAPON_LASSO')
  creates=creates+1
  assert(not owner.Create(approval),'reentrant create is blocked')
  if mode=='create_throw' then error('native may already have created') end
  return true
 end,
 capture=function() if mode=='capture' then return nil end; return {guid=string.rep('a',32)} end,
 sealed=function() return mode~='unsealed' end,
 removeCaptured=function(h,a)
  assert(h.guid==string.rep('a',32) and a.row.id==200); removes=removes+1
  if mode=='remove_throw' then error('unknown cleanup') end
  if mode=='world_left' then world=false end
  return true
 end,
 absent=function() return mode~='absence' end}
 owner=assert(WeaponNativeUtilityOwner.New(api,def,identity))
 assert(creates==0 and owner.Status().phase=='idle')
 local made=owner.Create(approval)
 if mode=='present' or mode=='create_throw' or mode=='capture' then
  assert(not made and owner.Status().phase=='retained' and removes==0)
 else
  assert(made and owner.Status().guidOwnershipCaptured)
  local released=owner.Release()
  if mode=='success' then assert(released and owner.Release() and removes==1)
  else assert(not released and owner.Status().phase=='retained') end
 end
 local c,r=creates,removes
 assert(not owner.Create(approval))
 if mode~='success' then assert(not owner.Release()) end
 assert(creates==c and removes==r,'uncertain creation/cleanup must never retry')
end
for _,m in ipairs({'success','present','create_throw','capture','unsealed','remove_throw','world_left','absence'}) do run(m) end
print('staged utility owner PASS: exact approval/GUID, zero-ammo contract, sealed cleanup, uncertainty retained; injected adapters only')
