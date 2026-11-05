dofile('client/character_ammunition_creation_native.lua')
local decoded=assert(WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(string.pack('<I4I4I4I4I4I4I4I4',1,2,3,4,5,6,7,8)))
assert(decoded.packedWords[4]==4 and decoded.scriptSlotWords[4]==7 and #decoded.raw32==64)
assert(not WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid(string.rep('\0',104)))
assert(not WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid('short'))
Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
local identity={characterId='Jane',sessionId='s',epoch='e'}
local current,entity=true,50
PlayerPedId=function() return 42 end
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value={characterId='Jane',sessionId=current and 's' or 'new',ped=42}} end}
WeaponCharacterMaintenanceNative={Scoped=function() return {Apply=function() return true end,
 Read=function(record) if entity~=record.entity then return nil,'maintenance_owned_object_unavailable' end; return {dirt=0} end} end}
WeaponCharacterAmmoCreationNative.New=function() return {} end
joaat=function(v) return v end
GetCurrentPedWeapon=function() return 1,'WEAPON_REPEATER_CARBINE' end
GetCurrentPedWeaponEntityIndex=function() return entity end
DoesEntityExist=function(handle) return handle==entity and 1 or 0 end
Citizen={InvokeNative=function() error('diagnostic must not mutate native components') end}
local adapter=assert(WeaponCharacterAmmoCreationNative.Scoped(42,identity,function() return true end,function() return true end))
local record={itemInstanceId=135,itemRevision=0,name='WEAPON_REPEATER_CARBINE',entity=50}
local diagnostic=assert(adapter.inspectTrackedEntity(record,identity))
assert(diagnostic.trackedEntity==50 and diagnostic.maintenance.dirt==0 and diagnostic.trackedExists)
entity=51; diagnostic=assert(adapter.inspectTrackedEntity(record,identity))
assert(diagnostic.points[1].expectedModel and not diagnostic.points[1].tracked
 and diagnostic.maintenanceError=='maintenance_owned_object_unavailable' and not diagnostic.trackedExists)
assert(record.entity==50,'diagnostics must never adopt matching-model replacement')
local originalDecode=WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid
Citizen.InvokeNative=function(hash) assert(hash==0x6929E22158E52265,'GUID read is the only native allowed'); return 1 end
WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid=function() return decoded end
entity=50; diagnostic=assert(adapter.inspectTrackedEntity(record,identity))
assert(diagnostic.diagnosticGuidBaseline==decoded.raw32 and diagnostic.points[1].guidMatchesDiagnosticBaseline)
entity=51; diagnostic=assert(adapter.inspectTrackedEntity(record,identity))
assert(diagnostic.points[1].guidMatchesDiagnosticBaseline and record.entity==50,'same GUID diagnostic does not grant rebinding')
WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid=function() return {raw32='foreign',packedWords={},scriptSlotWords={}} end
diagnostic=assert(adapter.inspectTrackedEntity(record,identity))
assert(not diagnostic.points[1].guidMatchesDiagnosticBaseline and diagnostic.diagnosticGuidBaseline==decoded.raw32)
WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid=originalDecode
local writes=0
record.serialNumber='FW-ALPHA-MIXED-JANE-V1-repeater_carbine'
entity=50
WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid=function() return decoded end
RequestModel=function() end; HasModelLoaded=function() return 1 end; SetModelAsNoLongerNeeded=function() end
Citizen.InvokeNative=function(hash,target,component,name,flag)
 if hash==0x6929E22158E52265 then return 1 end
 if hash==0x59DE03442B6C9598 then return 77 end
 assert(hash==0x74C9090FDD1BB48E and target==50 and flag==false)
 writes=writes+1; entity=51
end
local observed=assert(adapter.probeGuidComponent(record,identity,function() return true end))
assert(observed.guidBefore.raw32==decoded.raw32 and writes==1 and record.entity==50,'capture exact GUID then observe, never adopt replacement')
assert(not adapter.probeGuidComponent(record,identity,function() return true end) and writes==1,'replacement cannot be targeted by another call')
WeaponCharacterAmmoCreationNative.DecodeDiagnosticGuid=originalDecode
current=false; assert(not adapter.inspectTrackedEntity(record,identity))
print('Entity diagnostic PASS (numeric bool, exact tracked readback, replacement reported not adopted, stale refusal, no native mutation)')
