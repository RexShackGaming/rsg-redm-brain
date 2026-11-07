local commands,report,messages={},nil,{}
RegisterCommand=function(name,callback) commands[name]=callback end
dofile('tests/support/native_pair_options_probe.lua')
local P=WeaponNativePairOptionsProbe
GetConvarInt=function() return 1 end
json={encode=function(value) report=value; return 'report' end}
local oldPrint=print
print=function(value) messages[#messages+1]=value end
local active=true
local context={characterId='c',sessionId='s',ped=10}
WeaponCharacterAmmoWorldContext={Read=function() return {ok=true,value=context} end}
WeaponCharacterAmmoActiveOwner={Status=function()
 return {ownedCopies=active and 1 or 0,cleanupComplete=not active,
  bootstrap={runtime={phase=active and 'active' or 'closed',epoch='e'}}}
end,MaintenanceStatus=function()
 return {items={{itemInstanceId=128,name='WEAPON_REVOLVER_CATTLEMAN',maintenance={permanentDegradation=0.1}}}}
end}
joaat=function(name) return name=='SLOTID_NONE' and 0 or 100 end
GetCurrentPedWeapon=function(_,_,point) return point==2,point==2 and 100 or 0 end
GetCurrentPedWeaponEntityIndex=function(_,point) return point==2 and 1000 or 0 end
GetObjectIndexFromEntityIndex=function(entity) assert(entity==1000); return entity end
GetWeaponPermanentDegradation=function(entity) assert(entity==1000); return 0.1 end
local reads=0
Citizen={InvokeNative=function(native)
 assert(native==0x6929E22158E52265 or native==0x025A1B1FB03FBF61,'read-only inspection attempted a native write')
 reads=reads+1; return true
end}
-- CFX mutates pointer-buffer strings; emulate those decoded boundary results.
-- Exact bytes/offsets and GUID/hash validation are covered in the packing spec.
P.GuidKey=function() return '00000001000000020000000300000004' end
P.WearFields=function() return {field16=0.1,field17=0.1,field18=0.1,field19=0,field20=0} end
commands.weaponNativePairOptionsProbe(0,{'inspect-wear'})
assert(report.phase=='verified_field17' and report.readOnly and report.noNativeWrites and reads==3)
assert(report.observed.itemId==128 and report.observed.nativePermanent==0.1)
P.WearFields=function() return {field17=0} end
commands.weaponNativePairOptionsProbe(0,{'inspect-wear'})
assert(report.phase=='review_required' and report.reason:find('inspect_field17_native_mismatch',1,true))
active=false
commands.weaponNativePairOptionsProbe(0,{'run','wear'})
assert(messages[#messages]:find('verified inspect-wear required',1,true),'failed inspection cannot enable temporary mutation')
print=oldPrint
print('Pair wear inspection PASS (known worn copy, read-only native allowlist, mismatch refusal clears calibration and blocks mutation)')
