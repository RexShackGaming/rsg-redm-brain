local ped,current,permit,model=1,true,false,'mp_male'
local added,removed=0,0; local counts={}; local failEquip,failRemove=false,false
PlayerPedId=function() return ped end; DoesEntityExist=function() return 1 end
IsEntityDead=function() return 0 end; GetEntityModel=function() return model end
joaat=function(name) return name end
GetAllowDualWield=function() return permit and 1 or 0 end
SetAllowDualWield=function(_,v) permit=v end
local integerResult={}
Citizen={ResultAsInteger=function() return integerResult end,InvokeNative=function(hash,...)
    local args={...}
    if hash==0x886DFD3E185C8A89 then return 1 end
    if hash==0xE787F05DFC977BDE then
        if args[4]~=integerResult then return false end
        return counts[args[2]] or 0
    end
    if hash==0xCB5D11F9508A928D then added=added+1; return 1 end
    if hash==0x734311E2852760D0 then return not failEquip end
    if hash==0x3E4E811480B3AE79 then if failRemove then return 0 end; removed=removed+1; return 1 end
    return true
end}
dofile('client/character_ammunition_dual_native.lua')
local scope=WeaponCharacterAmmoDualNative.New(1,function() return current end)
assert(scope.Ensure() and permit and added==2); assert(scope.Ensure() and added==2)
ped=2; assert(not scope.Cleanup() and removed==0 and scope.Status().ownedCount==2)
ped=1; assert(scope.Cleanup() and removed==2 and not permit)
counts.CLOTHING_ITEM_M_OFFHAND_000_TINT_004=1; counts.UPGRADE_OFFHAND_HOLSTER=1
assert(scope.Ensure() and scope.Cleanup() and removed==2,'pre-existing GUIDs retained')
counts={}; failEquip=true; assert(not scope.Ensure() and removed==3 and not permit)
failRemove=true; assert(not scope.Ensure() and scope.Status().ownedCount==1)
failRemove=false; failEquip=false; assert(scope.Cleanup() and not permit)
model='unsupported'; assert(not scope.Ensure())
model='mp_female'; assert(scope.Ensure() and scope.Cleanup())
current=false; assert(not scope.Ensure())
print('dual ownership scope PASS (numeric BOOL, ped binding, idempotence, existing GUIDs, compensation, retained failed cleanup, permission restoration)')
