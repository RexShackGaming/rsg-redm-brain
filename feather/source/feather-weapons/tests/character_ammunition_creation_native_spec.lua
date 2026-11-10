dofile('client/character_maintenance_native.lua')
dofile('client/character_ammunition_creation_native.lua')
local fixture=dofile('tests/support/guid_creation_fixture.lua')
local identity={characterId='c',sessionId='s',epoch='e'}
local adapter,items,state=fixture(nil,{0.25,0})
DoesEntityExist=function() return 1 end; IsEntityDead=function() return 0 end
assert(adapter.current(identity) and adapter.prepareDual(identity))
IsEntityDead=function() return 1 end
assert(not adapter.current(identity) and not adapter.prepareDual(identity))
IsEntityDead=function() return 0 end; DoesEntityExist=function() return 0 end
assert(not adapter.current(identity))
DoesEntityExist=function() return 1 end
assert(not adapter.createSingle(items[1],1,identity),'creation never grants ammo')
HasPedGotWeapon=function() return 1 end
assert(not adapter.createSingle(items[1],0,identity),'preexisting model refused before insertion')
assert(state()==0)
HasPedGotWeapon=function() return 0 end
local record=assert(adapter.createSingle(items[1],0,identity))
assert(record.guid and record.entity and adapter.finish({record},identity))
assert(not adapter.remove({guid=record.guid}),'fabricated record cannot remove an owned GUID')
local original=record.guid; record.guid='foreign'
assert(not adapter.remove(record),'mutated GUID cannot remove the owned copy')
record.guid=original
assert(adapter.remove(record) and not adapter.remove(record),'exact issued GUID removed once')
local removals,grants,applied=state();assert(removals==1 and grants==0 and applied[101]==0.25)
for _,bad in ipairs({'itemInstanceId','itemRevision','serialNumber','point','maintenance'}) do
 local a,i=fixture(nil,{0,0});i[1][bad]=nil
 assert(not a.createSingle(i[1],0,identity),'invalid copy '..bad)
end
local missing,i=fixture(nil,{0,0});GetWeaponPermanentDegradation=nil
assert(not missing.createSingle(i[1],0,identity),'readback is required even for unworn singles')
local stale,i=fixture(nil,{0,0});PlayerPedId=function() return 11 end
assert(not stale.current(identity) and not stale.createSingle(i[1],0,identity))
local delayed,i=fixture('delayed-primary',{0,0})
local wait=Wait;Wait=function() wait();PlayerPedId=function() return 11 end end
local made,reason,partial=delayed.createSingle(i[1],0,identity)
assert(not made and reason:find('creation_identity_changed',1,true) and partial.cleanupComplete,
 'identity expiration while yielding removes only the exact inserted GUID')
local timed,i=fixture('wrong-primary-guid',{0,0});local waits=0;local wait=Wait
Wait=function() waits=waits+1;wait() end
local made,reason,partial=timed.createSingle(i[1],0,identity)
assert(not made and waits>0 and waits<=120 and partial.cleanupComplete,'GUID settlement is bounded')
print('creation native PASS (unified production GUIDs, numeric BOOL, no ammo/model grants, exact issued ownership, invalid input, ped binding, bounded settlement and compensation)')
