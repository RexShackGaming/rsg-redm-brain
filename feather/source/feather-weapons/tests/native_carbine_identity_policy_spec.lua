dofile('client/character_maintenance_native.lua')
dofile('client/character_ammunition_creation_native.lua')
local fixture=dofile('tests/support/guid_creation_fixture.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
for _,spec in ipairs({{135,'WEAPON_REVOLVER_CATTLEMAN',2},{901,'WEAPON_REPEATER_CARBINE',10},
 {902,'WEAPON_RIFLE_BOLTACTION',9}}) do
 local adapter,items,state=fixture(nil,{0,0},spec[2]);local item=items[1]
 item.itemInstanceId=spec[1];item.serialNumber='ordinary-'..spec[1];item.itemRevision=7;item.point=spec[3]
 local record=assert(adapter.createSingle(item,0,identity))
 assert(record.guidIdentity and record.itemInstanceId==spec[1] and record.serialNumber==item.serialNumber)
 assert(adapter.remove(record));local _,grants=state();assert(grants==0)
end
for _,change in ipairs({function(i) i.itemInstanceId=0 end,function(i) i.serialNumber='' end,
 function(i) i.itemRevision=-1 end,function(i) i.itemRevision=0/0 end}) do
 local adapter,items,state=fixture(nil,{0,0},'WEAPON_REPEATER_CARBINE');change(items[1])
 assert(not adapter.createSingle(items[1],0,identity) and #adapter.creationAttemptHandles()==0)
end
print('canonical GUID identity PASS (all firearms capture exact GUIDs, no reserved fixture ID, malformed identities refused before insertion)')
