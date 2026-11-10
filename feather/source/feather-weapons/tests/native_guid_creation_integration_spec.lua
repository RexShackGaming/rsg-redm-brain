dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
vector3=function(x,y,z) return {x=x,y=y,z=z} end
dofile('config.lua')
for _,file in ipairs({'shared/definitions/ammunition.lua','shared/definitions/attachments.lua',
 'shared/definitions/weapons.lua','shared/character_ammunition_materialization.lua'}) do dofile(file) end
dofile('client/character_maintenance_native.lua')
dofile('client/character_ammunition_creation_native.lua')
local identity={characterId='Jane',sessionId='s',epoch='e'}
local points,exists={}, {[42]=true}
local lastPoint,removals=0,0
local words={1,2,3,4}
GetConvarInt=function(name,default)
 -- The manual child-probe assertions below require saved reconstruction off.
 -- GUID capture still exercises its ordinary default without an override.
 return name=='feather_native_saved_attachments' and 0 or default
end
PlayerPedId=function() return 42 end
DoesEntityExist=function(handle) return exists[handle] and 1 or 0 end
IsEntityDead=function() return 0 end
joaat=function(value) return value=='WEAPON_REPEATER_CARBINE' and 100 or 999 end
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId='Jane',sessionId='s',ped=42}} end}
GetGameTimer=function() return 1 end; Wait=function() error('unexpected yield') end
GetCurrentPedWeapon=function(_,_,point) return points[point] and 1 or 0,points[point] and 100 or 0 end
GetCurrentPedWeaponEntityIndex=function(_,point) return points[point] and points[point].entity or 0 end
GiveWeaponToPed=function() error('model grant forbidden') end
RemoveWeaponFromPed=function() error('model removal forbidden') end
HasPedGotWeapon=function() return points[0]~=nil or points[10]~=nil end
SetCurrentPedWeapon=function() end
local function rawGuid() return string.pack('<I4I4I4I4I4I4I4I4',1,0,2,0,3,0,4,0)..string.rep('\0',72) end
local inventoryRecord
local N=WeaponCharacterAmmoCreationNative
local decode=N.DecodeDiagnosticGuid
N.DecodeDiagnosticGuid=function(raw)
 if raw:sub(1,32)==string.rep('\0',32) then
  local p=points[lastPoint];return p and {scriptSlotWords=p.guid}
 end
 return decode(raw)
end
Citizen={InvokeNative=function(hash,_,point)
 if hash==0x6929E22158E52265 then lastPoint=point;return points[point] and 1 or 0 end
 if hash==0x886DFD3E185C8A89 or hash==0x94A3C1B804D291EC then return 1 end
 if hash==0xCB5D11F9508A928D then inventoryRecord=rawGuid():sub(1,32)..string.pack('<I4I4',100,0)..string.rep('\0',136);return 1 end
 if hash==0x3E4E811480B3AE79 then
  removals=removals+1;inventoryRecord=nil
  for p,v in pairs(points) do if v.guid==words then exists[v.entity]=false;points[p]=nil end end
  return 1
 end
 error('unexpected native '..tostring(hash))
end}
local new=N.New
N.New=function(ped,current,prepare,apply,guid,saved)
 return new(ped,current,prepare,apply,guid,{
  buffer=rawGuid,read=function() return inventoryRecord end,
  update=function(_,raw) inventoryRecord=raw;return true end,
  pointGuid=function(p) local v=points[p];return v and ('%08x%08x%08x%08x'):format(table.unpack(v.guid)) end,
  activate=function() points[10]={entity=50,guid=words};exists[50]=true;return true end})
end
GetObjectIndexFromEntityIndex=function(handle) return handle+100 end
for _,name in ipairs({'GetWeaponDegradation','GetWeaponPermanentDegradation','GetWeaponDamage','GetWeaponDirt','GetWeaponSoot'}) do
 _G[name]=function() return 0 end
end
for _,name in ipairs({'SetWeaponDegradation','SetWeaponDamage','SetWeaponDirt','SetWeaponSoot'}) do _G[name]=function() end end
local adapter=assert(WeaponCharacterAmmoCreationNative.Scoped(42,identity,function() return true end,function() return true end))
local record=assert(adapter.createSingle({definitionId='repeater_carbine',itemInstanceId=135,itemRevision=0,serialNumber='FW-ALPHA-MIXED-JANE-V1-repeater_carbine',point=10,
 nativeWeaponName='WEAPON_REPEATER_CARBINE',attachments={},cosmetics={},
 maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0}},0,identity))
assert(record.guidIdentity and record.entity==50)
-- Fresh adapter status must not require an earlier mutating install attempt.
Config.DevMode=true -- remaining assertions intentionally exercise the manual diagnostic probe
local readGuid=Citizen.InvokeNative
Citizen.InvokeNative=function(hash,...)
 if hash==0x6929E22158E52265 then return readGuid(hash,...) end
 if hash==0x033EE4B89F3AC545 then return 1 end
 if hash==0x886DFD3E185C8A89 then return false end
 if hash==0xBE012571B25F5ACA then return 0 end
 error('fresh status attempted native write')
end
Citizen.ResultAsInteger=function() return 'integer-result' end
local fresh=assert(adapter.probeInventoryComponent(record,identity,function() return true end,'status'))
assert(fresh.slotCount==1 and fresh.noNativeWrites and not fresh.owned and not fresh.uncertain)
assert(not adapter.probeInventoryComponent(record,identity,function() return true end,'install'),'existing slot stays protected after read-only initialization')
Citizen.InvokeNative=readGuid
points[0]={entity=51,guid=words}; points[10]=nil; exists[50]=false; exists[51]=true
assert(adapter.readMaintenance(record,identity) and record.entity==51,'concrete adapter follows captured GUID to replacement for wear')
points[9]={entity=52,guid={1,2,3,5}}; exists[52]=true
assert(adapter.remove(record) and removals==1 and points[9] and exists[52],
 'exact GUID cleanup removes our moved representation while preserving a foreign copy of the same model')
print('GUID concrete creation PASS (capture during actual single create, resolved maintenance and cleanup, foreign same-model removal veto)')
