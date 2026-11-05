-- Execute actual shipped server graph without obsolete globals/provider loaded.
local f=assert(io.open('fxmanifest.lua','r')); local manifest=f:read('*a'); f:close()
local function paths(section)
 local block=assert(manifest:match(section..'%s*{(.-)}'))
 local result={}; for p in block:gmatch("'([^']+)'") do if p:sub(1,1)~='@' then result[#result+1]=p:gsub('^/','') end end
 return result
end
vector3=function(x,y,z) return {x=x,y=y,z=z} end
GetGameTimer=function() return 100 end
GetResourceState=function() return 'started' end
GetConvarInt=function() return 0 end
SetConvar=function() end
LoadResourceFile=function() return nil end
SaveResourceFile=function() return true end
GetCurrentResourceName=function() return 'feather-weapons' end
joaat=function() return 1 end
local events,commands,public,threads={},{},{},{}
RegisterNetEvent=function(n,fn) events[n]=fn end
AddEventHandler=function() end
RegisterCommand=function(n,fn) commands[n]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end
SetTimeout=function() end
exports=setmetatable({}, {__call=function(_,n,fn) public[n]=fn end})
for _,p in ipairs(paths('shared_scripts')) do dofile(p) end
Config.CharacterAmmunitionEnabled=true; Config.CharacterAmmoTransportEnabled=true
Config.NativeAlphaRuntime=true; Config.NativeAlphaCharacterId='Jane'
for _,p in ipairs(paths('server_scripts')) do dofile(p) end
assert(InventoryAdapter==nil and WeaponRuntime==nil and ReconciliationService==nil and FeatherCore==nil)
assert(AttachmentService.AuthorizeNativeModification and AttachmentService.Install==nil)
assert(WeaponCharacterAmmoService and WeaponCharacterAmmoDispatcher and WeaponNativeEquipmentBindings)
assert(commands.WeaponNativePrepareStopAll and commands.WeaponNativeIssue and commands.WeaponProvenanceInspect)
assert(commands.grantweapon==nil and commands.WeaponNativeTestPrepare==nil)
assert(public.IssueWeapon and public.ValidateNativeIssuance and public.InspectWeaponHistory)
local api=public.initiate()
assert(api.Inventory==nil and api.Runtime==nil and api.Inspection.Reconcile==nil)
assert(WeaponProvenanceService.BeginIssuance==nil)
assert(WeaponNativeThrowablePolicy and WeaponNativeThrowableItem and not WeaponNativeThrowablePolicy.Enabled())
assert(commands.WeaponNativeThrowableFunding,'funding remains server-console-only and separately gated')
print('Native-only manifest server graph PASS (real module composition, no legacy globals/commands/provider/ledger)')
-- Native-only client composition must not require the retired hybrid helpers.
PlayerPedId=function() return 1 end
NetworkIsSessionStarted=function() return true end
DoesEntityExist=function() return true end
IsEntityDead=function() return false end
TriggerServerEvent=function() end
RegisterKeyMapping=function() end
for _,p in ipairs(paths('client_scripts')) do dofile(p) end
assert(FeatherWeaponsClient==nil and FeatherNativeWeaponCoordinator==nil and FeatherGuidWeapons==nil)
assert(WeaponCharacterAmmoNativeOwner and WeaponCharacterAmmoClientIngress)
assert(WeaponNativeThrowableOwner and WeaponNativeThrowableAdapter and not WeaponNativeThrowablePolicy.Enabled())
print('Native-only manifest client graph PASS (no hybrid owner/coordinator/GUID helper dependency)')
