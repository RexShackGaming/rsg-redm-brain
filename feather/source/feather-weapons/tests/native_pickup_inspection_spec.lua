dofile('diagnostics/native_pickup_inspect/inspection.lua')
local function raw(guid,hash)
 local out={};for i=1,4 do out[#out+1]=string.pack('<I4I4',guid or 1,0) end
 return table.concat(out)..string.pack('<I4',hash or 40)..string.rep('\0',68)
end
local function scenario(mode)
 local reads=0
 local api={build=function() return mode=='build' and 1436 or 1491 end,current=function() return mode~='context' end,
  quantity=function() return mode=='empty' and 0 or 1 end,present=function() return mode~='ammo-only' and mode~='empty' end,
  hash=function(v) return ({CHARACTER=10,CARRIED_WEAPONS=20,SLOTID_CARRIED_WEAPONS=30,WEAPON_THROWN_TOMAHAWK=40,SLOTID_WEAPON_0=50,SLOTID_WEAPON_1=60})[v] or error(v) end,
  resolve=function(parent,item,slot)
   reads=reads+1
   if mode=='parent' and item==20 then return false end
   if item==40 then
    if mode=='ammo-only' or mode=='empty' then return false end
    if slot==60 and mode~='ambiguous' then return false end
   end
   return true,raw(item+slot,40)
  end,
  read=function(guid) return true,mode=='changed' and raw(999,40) or mode=='model' and guid:sub(1,32)..string.pack('<I4',99)..guid:sub(37) or guid end}
 return WeaponPickupReadOnlyInspection.Read(api),reads
end
local r=scenario('unique');assert(r.phase=='read_complete' and r.inventoryPhase=='unique' and #r.guids==1 and not r.canClaim and r.noWrites)
local r=scenario('ammo-only');assert(r.phase=='read_complete' and r.quantity==1 and r.weaponPresent==false and r.inventoryPhase=='absent')
local r=scenario('empty');assert(r.phase=='read_complete' and r.quantity==0 and r.inventoryPhase=='absent')
local r=scenario('ambiguous');assert(r.inventoryPhase=='ambiguous' and #r.guids==2)
local r=scenario('parent');assert(r.stage=='carried_weapons' and r.inventoryPhase=='absent')
for _,mode in ipairs({'changed','model','context'}) do assert(scenario(mode).phase=='review_required',mode) end
local r,reads=scenario('build');assert(r.phase=='refused' and reads==0)
-- Concrete command registers without inspecting or changing anything at load.
local command,calls
RegisterCommand=function(name,fn) assert(name=='weaponPickupInspect');command=fn end
PlayerPedId=function() return 7 end
DoesEntityExist=function() return true end
IsEntityDead=function() return false end
GetGameBuildNumber=function() return 1491 end
joaat=function() return 1 end
GetPedAmmoByType=function() return 1 end
HasPedGotWeapon=function() return false end
Citizen={InvokeNative=function(hash)
 assert(hash==0x886DFD3E185C8A89 or hash==0x9700E8EFC4AB9089,'only documented inventory READ natives permitted')
 calls=(calls or 0)+1;return false
end}
local report
json={encode=function(row) report=row;return 'read-only-report' end}
dofile('diagnostics/native_pickup_inspect/client.lua')
assert(command and not calls);command();assert(calls==1 and report.quantity==1 and report.noWrites)
print('PASS read-only live sidecar inspection: ammo-only/unique/ambiguous/missing parent, changed readback/model/context/build fences, explicit command and no mutation ports')
