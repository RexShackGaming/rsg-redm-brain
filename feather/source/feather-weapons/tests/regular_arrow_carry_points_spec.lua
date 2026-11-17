Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
dofile('client/character_maintenance_native.lua')
dofile('client/character_ammunition_creation_native.lua')
local make=dofile('tests/support/guid_creation_fixture.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
local N=WeaponCharacterAmmoCreationNative
for _,point in ipairs({8,7}) do
 local adapter,items,state=make(nil,{0},'WEAPON_BOW',{point})
 local record=assert(adapter.createSingle(items[1],0,identity))
 assert(record.point==point and record.name=='WEAPON_BOW')
 assert(adapter.finish({record},identity))
 local options=assert(N.GuidOptions(record.guid,joaat('WEAPON_BOW'),point,1))
 assert(string.unpack('<I4',options,49)==point,'GUID activation encodes the bow-specific point')
 assert(adapter.remove(record))
 local removed,grants=state();assert(removed==1 and grants==0,'exact GUID cleanup without model grant')
end
for _,point in ipairs({9,10}) do
 local adapter,items=make(nil,{0},'WEAPON_BOW',{point})
 assert(not adapter.createSingle(items[1],0,identity),'bow cannot fall back to rifle carry point')
end
for _,point in ipairs({7,8}) do
 local adapter,items=make(nil,{0},'WEAPON_RIFLE_SPRINGFIELD',{point})
 assert(not adapter.createSingle(items[1],0,identity),'bow points do not broaden firearm admission')
end
print('PASS bow carry points: exact GUID creation/settle/identity/cleanup at8 and7; rifle-point bows and bow-point firearms refused')
