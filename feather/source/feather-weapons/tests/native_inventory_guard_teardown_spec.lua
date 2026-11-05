Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,Inventory={requiredContract=4}}
local handlers={}
AddEventHandler=function(name,fn) handlers[name]=fn end
GetCurrentResourceName=function() return 'feather-weapons' end
dofile('server/adapters/character_ammunition_inventory.lua')
local held,removed=false,0
local inventory={GetCapabilities=function() return {ok=true,value={contractVersion=4,characterIdentity={uuid=true,mode='uuid'}}} end,
    Equipment={IsInstanceEquipped=function() return {ok=true,value=false} end},Guards={}}
for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
    inventory.Guards[name]=function() return {ok=true} end
end
for _,name in ipairs({'UnregisterMoveGuard','UnregisterDestroyGuard','UnregisterInstanceChangeGuard'}) do
    inventory.Guards[name]=function(label) assert(label=='feather-weapons'); removed=removed+1 end
end
local function new()
    return WeaponCharacterAmmoInventory.New(function() return inventory end,function() return held end,
        function() return true end,function() return not held end)
end
local owner=new(); assert(owner.Install())
held=true; assert(not owner.Uninstall() and removed==0 and owner.Status()=='ready')
held=false; assert(owner.Uninstall() and removed==3 and owner.Status()=='stopped')
assert(not owner.Uninstall() and removed==3)
owner=new(); assert(owner.Install())
local unregister=inventory.Guards.UnregisterInstanceChangeGuard
inventory.Guards.UnregisterInstanceChangeGuard=nil
assert(not owner.Uninstall() and removed==3,'preflight all callbacks before partial teardown')
inventory.Guards.UnregisterInstanceChangeGuard=unregister
local calls=0
WeaponCharacterAmmoInventoryProvider={Status=function() return 'ready' end,Uninstall=function() calls=calls+1; return true end}
handlers.onResourceStop('other'); assert(calls==0)
handlers.onResourceStop('feather-weapons'); assert(calls==1)
print('native Inventory teardown PASS (held veto, all3 unregister, duplicate/missing refusal, own-resource stop only)')
