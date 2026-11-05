Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false,Inventory={requiredContract=4}}
dofile('server/adapters/character_ammunition_inventory.lua')
local registrations,held={},false
local equipped=false
local function policy() return true end
local inventory={GetCapabilities=function() return {ok=true,value={contractVersion=4,
    characterIdentity={uuid=true,mode='uuid'}}} end,Guards={},Equipment={
        IsInstanceEquipped=function() return {ok=true,value=equipped} end}}
for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
    inventory.Guards[name]=function(label,guard)
        assert(label=='feather-weapons'); registrations[#registrations+1]=guard; return {ok=true}
    end
end
local owner=WeaponCharacterAmmoInventory.New(function() return inventory end,function() return held end,policy)
assert(not owner.Install() and #registrations==0 and owner.Status()=='dormant')
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
assert(owner.Install() and #registrations==3)
for _,guard in ipairs(registrations) do
    held=false; assert(guard({id=112})); held=true; assert(not guard({id=112}))
    assert(not guard({})); assert(not guard(nil)); assert(not guard({id=-1}))
    assert(not guard({id=1.5}))
end
assert(not owner.Install() and #registrations==3)
held=false; equipped=true; assert(not registrations[1]({id=112}))
assert(registrations[3]({id=112}),'metadata guard concerns native ownership, not saved assignment')
equipped=false
local readEquipment=inventory.Equipment.IsInstanceEquipped
inventory.Equipment.IsInstanceEquipped=function() return {ok=false} end
assert(not registrations[1]({id=112}))
inventory.Equipment.IsInstanceEquipped=readEquipment
local broken=WeaponCharacterAmmoInventory.New(function() return inventory end,function() error('ownership unavailable') end,policy)
assert(broken.Install()); assert(not registrations[4]({id=112}))
local original=inventory.Guards.RegisterMoveGuard
inventory.Guards.RegisterMoveGuard=function(...)
    Config.CharacterAmmoTransportEnabled=false; return original(...)
end
local partial=WeaponCharacterAmmoInventory.New(function() return inventory end,function() return false end,policy)
assert(not partial.Install() and partial.Status()=='failed')
Config.CharacterAmmoTransportEnabled=true
assert(not partial.Install(),'partial installation must not silently retry')
inventory.Guards.RegisterMoveGuard=original
local function reference(fn)
    return setmetatable({__cfx_functionReference='mock'}, {__call=function(_,...) return fn(...) end})
end
inventory.GetCapabilities=reference(inventory.GetCapabilities)
for name,fn in pairs(inventory.Guards) do inventory.Guards[name]=reference(fn) end
local refs=WeaponCharacterAmmoInventory.New(reference(function() return inventory end),
    reference(function() return false end),reference(policy))
assert(refs.Install(),'cross-resource callable tables must be accepted')
local denied=WeaponCharacterAmmoInventory.New(function() return inventory end,function() return false end,
    function() return false,'evidence hold' end)
assert(denied.Install()); assert(not registrations[#registrations-2]({id=112}))
local scoped=WeaponCharacterAmmoInventory.New(function() return inventory end,function(id,context)
    return not (id==128 and context and context.operation=='metadata_write' and context.runtimeTicket=='approved')
end,policy)
assert(scoped.Install())
assert(not registrations[#registrations-2]({id=128},{operation='metadata_write',runtimeTicket='approved'}),'movement callback never forwards metadata authority')
assert(not registrations[#registrations-1]({id=128},{operation='metadata_write',runtimeTicket='approved'}),'destruction remains held')
assert(registrations[#registrations]({id=128},{operation='metadata_write',runtimeTicket='approved'}))
assert(not registrations[#registrations]({id=112},{operation='metadata_write',runtimeTicket='approved'}))
print('character_ammunition_inventory_spec PASS (native-only guards; scoped metadata context never authorizes movement/destruction)')
