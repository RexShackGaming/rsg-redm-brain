dofile('client/character_maintenance_native.lua')
dofile('client/character_ammunition_creation_native.lua')
dofile('client/character_ammunition_loadout.lua')
local fixture=dofile('tests/support/guid_creation_fixture.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
-- One factory performs a full mixed four-slot build; cleanup keys stay distinct.
local adapter,items,state=fixture(nil,{0.25,0})
local plan={identity=identity,dual=true,sameModel=false,items={}}
for index,point in ipairs({2,3,10,9}) do
 local source=items[index==1 and 1 or 2];local item={}
 for k,v in pairs(source) do item[k]=v end
 item.itemInstanceId=100+index;item.serialNumber='mixed-'..index;item.point=point
 item.nativeWeaponName=({'WEAPON_REVOLVER_CATTLEMAN','WEAPON_REVOLVER_LEMAT','WEAPON_RIFLE_BOLTACTION','WEAPON_REPEATER_CARBINE'})[index]
 item.creation='native_inventory_guid';item.copyKey=tostring(index);plan.items[index]=item
end
local result=assert(WeaponCharacterAmmoLoadout.New(adapter).Create(plan))
local seen={}
for _,handle in ipairs(result.handles) do
 local key=WeaponCharacterAmmoCreationNative.GuidKey(handle.guid)
 assert(handle.guidIdentity and not seen[key]);seen[key]=true
end
for index=#result.handles,1,-1 do assert(adapter.remove(result.handles[index])) end
local removals,grants=state();assert(removals==4 and grants==0)
for _,legacy in ipairs({'native_zero_ammo_grant','inventory_guid_pair','unknown'}) do
 plan.items[1].creation=legacy
 local before=#adapter.creationAttemptHandles()
 assert(not WeaponCharacterAmmoLoadout.New(adapter).Create(plan))
 assert(#adapter.creationAttemptHandles()==before,'obsolete creation instructions refused before native work')
end
-- Clean and worn matching copies share activation and cleanup, with no model special case.
for _,model in ipairs({'WEAPON_REVOLVER_CATTLEMAN','WEAPON_REVOLVER_LEMAT','WEAPON_PISTOL_M1899','WEAPON_SHOTGUN_SAWEDOFF'}) do
 for _,wear in ipairs({{0,0},{0.1,0.25}}) do
  local a,i,state=fixture(nil,wear,model)
  local handles=assert(a.createPair(i,identity));assert(a.finish(handles,identity))
  assert(a.remove(handles[2]) and a.remove(handles[1]));local _,grants=state();assert(grants==0)
 end
end
print('unified production creation PASS (mixed four slots, distinct issued GUIDs, all shared activation/cleanup, clean and worn pairs, obsolete strategies refused)')
