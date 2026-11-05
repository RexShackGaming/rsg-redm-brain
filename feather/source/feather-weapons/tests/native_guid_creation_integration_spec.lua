dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
dofile('client/character_maintenance_native.lua')
dofile('client/character_ammunition_creation_native.lua')
Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane',CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
local identity={characterId='Jane',sessionId='s',epoch='e'}
local points,exists={}, {[42]=true}
local lastPoint,removals=0,0
local words={1,2,3,4}
GetConvarInt=function(name) return name=='feather_native_guid_ownership' and 1 or 0 end
PlayerPedId=function() return 42 end
DoesEntityExist=function(handle) return exists[handle] and 1 or 0 end
IsEntityDead=function() return 0 end
joaat=function(value) return value end
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId='Jane',sessionId='s',ped=42}} end}
GetGameTimer=function() return 1 end; Wait=function() error('unexpected yield') end
GetCurrentPedWeapon=function(_,_,point) return points[point] and 1 or 0,points[point] and 'WEAPON_REPEATER_CARBINE' or 0 end
GetCurrentPedWeaponEntityIndex=function(_,point) return points[point] and points[point].entity or 0 end
GiveWeaponToPed=function(_,_,ammo) assert(ammo==0); points[10]={entity=50,guid=words}; exists[50]=true end
HasPedGotWeapon=function() return points[0]~=nil or points[10]~=nil end
RemoveWeaponFromPed=function() removals=removals+1; points={}; exists[51]=false end
Citizen={InvokeNative=function(hash,_,point)
 assert(hash==0x6929E22158E52265); lastPoint=point; return 1
end}
WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid=function()
 return {scriptSlotWords=points[lastPoint].guid}
end
GetObjectIndexFromEntityIndex=function(handle) return handle+100 end
for _,name in ipairs({'GetWeaponDegradation','GetWeaponPermanentDegradation','GetWeaponDamage','GetWeaponDirt','GetWeaponSoot'}) do
 _G[name]=function() return 0 end
end
for _,name in ipairs({'SetWeaponDegradation','SetWeaponDamage','SetWeaponDirt','SetWeaponSoot'}) do _G[name]=function() end end
local adapter=assert(WeaponCharacterAmmoCreationNative.Scoped(42,identity,function() return true end,function() return true end))
local record=assert(adapter.createSingle({itemInstanceId=135,itemRevision=0,serialNumber='FW-ALPHA-MIXED-JANE-V1-repeater_carbine',point=10,
 nativeWeaponName='WEAPON_REPEATER_CARBINE',attachments={},cosmetics={},
 maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0}},0,identity))
assert(record.guidIdentity and record.entity==50)
-- Fresh adapter status must not require an earlier mutating install attempt.
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
assert(not adapter.remove(record) and removals==0,'model-wide native removal cannot delete foreign copy')
points[9]=nil
assert(adapter.remove(record) and removals==1,'cleanup follows exact GUID-resolved representation')
print('GUID concrete creation PASS (capture during actual single create, resolved maintenance and cleanup, foreign same-model removal veto)')
