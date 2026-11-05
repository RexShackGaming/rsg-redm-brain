dofile('client/character_maintenance_native.lua')
local function values() return {degradation=0.5,permanentDegradation=0.1,damage=0.5,dirt=1,soot=1} end
local state=values()
local active,entity,writes=true,10,0
local record={entity=10,name='WEAPON_REVOLVER_CATTLEMAN'}
local adapter=WeaponCharacterMaintenanceNative.New({
    current=function() return active end,
    resolve=function(owned) return owned.entity==entity and 100 or nil end,
    read=function(handle,key) assert(handle==100); return state[key] end,
    write=function(handle,key,value) assert(handle==100); writes=writes+1; state[key]=value; return true end,
})
local target={degradation=0,permanentDegradation=0.1,damage=0,dirt=0,soot=0}
assert(adapter.Apply(record,{},target) and writes==4)
assert(state.degradation==0.1 and state.damage==0.1 and target.damage==0)
entity=11; assert(not adapter.Apply(record,{},target) and writes==4)
entity=10; active=false; assert(not adapter.Read(record,{}))
active=true; target.permanentDegradation=0.2
assert(not adapter.Apply(record,{},target) and writes==4)
target.permanentDegradation=0.1; target.dirt=0/0
assert(not adapter.Apply(record,{},target) and writes==4)
target.dirt=0
local refusing=WeaponCharacterMaintenanceNative.New({current=function() return true end,
    resolve=function() return 100 end,read=function(_,key) return values()[key] end,
    write=function() return true end})
assert(not refusing.Apply(record,{},target),'void setter success is not proof of application')
local changing=WeaponCharacterMaintenanceNative.New({current=function() return active end,
    resolve=function() return 100 end,read=function(_,key) return values()[key] end,
    write=function() active=false; return true end})
assert(not changing.Apply(record,{},target),'lifecycle changes during write fail closed')
-- Concrete resolver rejects another same-model entity and follows the exact
-- owned entity to another point. Mock native functions, not an engine proof.
active=true
PlayerPedId=function() return 1 end; DoesEntityExist=function() return 1 end
IsEntityDead=function() return 0 end; joaat=function() return 123 end
GetCurrentPedWeapon=function(_,_,point) return 1,123 end
GetCurrentPedWeaponEntityIndex=function(_,point) return point==3 and entity or 99 end
GetObjectIndexFromEntityIndex=function(handle) assert(handle==10); return 100 end
GetWeaponDegradation=function() return state.degradation end
GetWeaponPermanentDegradation=function() return state.permanentDegradation end
GetWeaponDamage=function() return state.damage end
GetWeaponDirt=function() return state.dirt end; GetWeaponSoot=function() return state.soot end
SetWeaponDegradation=function(_,v) assert(math.type(v)=='float'); state.degradation=v end
SetWeaponDamage=function(_,v) assert(math.type(v)=='float'); state.damage=v end
SetWeaponDirt=function(_,v) assert(math.type(v)=='float'); state.dirt=v end
SetWeaponSoot=function(_,v) assert(math.type(v)=='float'); state.soot=v end
local scoped=WeaponCharacterMaintenanceNative.Scoped(1,function() return true end)
assert(scoped.Apply(record,{},target))
-- Whole-number JSON/default/fixture values must cross the concrete native bridge
-- as floats, not merely compare equal numerically in a Lua-only adapter mock.
state={degradation=0.0,permanentDegradation=0.0,damage=0.0,dirt=0.2,soot=0.0}
assert(scoped.Apply(record,{},{degradation=1,permanentDegradation=0,damage=0,dirt=0.2,soot=0}))
assert(state.degradation==1.0 and state.damage==0.0 and state.dirt==0.2)
assert(scoped.Apply(record,{},{degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0}))
entity=11; assert(not scoped.Read(record,{}),'same hash is not owned-copy authority')
print('character_maintenance_native_spec PASS (exact entity, copy replacement/lifecycle refusal, permanent mismatch, independent readback; native mocks)')
