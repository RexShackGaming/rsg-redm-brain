dofile('client/character_maintenance_native.lua')
local id={characterId='c',sessionId='s',epoch='e'}
local dead,entity,revision=true,12,7
PlayerPedId=function() return 1 end
DoesEntityExist=function() return 1 end
IsEntityDead=function() return dead and 1 or 0 end
joaat=function() return 33 end
GetCurrentPedWeapon=function() return 1,33 end
GetCurrentPedWeaponEntityIndex=function() return entity end
GetObjectIndexFromEntityIndex=function(e) assert(e==12); return 13 end
local change=false
GetWeaponDegradation=function() if change then revision=8 end; return 0.1 end
GetWeaponPermanentDegradation=function() return 0.1 end
GetWeaponDamage=function() return 0.1 end
GetWeaponDirt=function() return 0.4 end
GetWeaponSoot=function() return 0 end
local context=function() return {ok=true,value={characterId='c',sessionId='s',ped=1,lifeState='dead',medicalRevision=revision}} end
local adapter=assert(WeaponCharacterMaintenanceNative.DeathReadOnly(1,id,context))
assert(not adapter.Apply,'death adapter cannot restore/repair')
local record={entity=12,name='WEAPON_REVOLVER_CATTLEMAN'}
assert(adapter.Read(record,id).dirt==0.4)
assert(not adapter.Read(record,{characterId='c',sessionId='s',epoch='other'}))
entity=14; assert(not adapter.Read(record,id),'same model does not prove owned entity')
entity=12; dead=false; assert(not adapter.Read(record,id),'revived ped cannot provide death readback')
dead=true; change=true; assert(not adapter.Read(record,id),'Medical revision changes invalidate readback')
assert(not WeaponCharacterMaintenanceNative.DeathReadOnly(1,{},context))
print('Death wear read-only adapter PASS (exact copy/epoch/dead ped/Medical revision, no setters or recovery authority)')
