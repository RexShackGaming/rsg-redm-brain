-- Execute actual shipped server graph without obsolete globals/provider loaded.
local function scenario(quantityMode,knifeMode)
local f=assert(io.open('fxmanifest.lua','r')); local manifest=f:read('*a'); f:close()
local function paths(section)
 local block=assert(manifest:match(section..'%s*{(.-)}'))
 local result={}; for p in block:gmatch("'([^']+)'") do if p:sub(1,1)~='@' then result[#result+1]=p:gsub('^/','') end end
 return result
end
vector3=function(x,y,z) return {x=x,y=y,z=z} end
GetGameTimer=function() return 100 end
GetResourceState=function() return 'started' end
GetConvarInt=function(name,default) return (name=='feather_throwable_quantities' and quantityMode or name=='feather_throwing_knife_quantities' and knifeMode) and 1 or default or 0 end
GetConvar=function(name,default) return (name=='feather_throwable_quantities' and quantityMode or name=='feather_throwing_knife_quantities' and knifeMode) and '1' or default end
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
assert(commands.WeaponNativeThrowableFunding==nil,'retired exact-item funding must not register in supported runtime')
assert(WeaponNativeThrowablePickupServer==nil and WeaponNativeProjectileCollectionProbe==nil)
assert(WeaponNativeThrowablePolicy.QuantityEnabled()==quantityMode)
local threadCount=#threads
for _,action in ipairs({'throwable','landing','shared','shared-competing'}) do
 commands.WeaponGuidAcceptance(0,{action})
 assert(#threads==threadCount,'retired suite action cannot start a loan/release')
end
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
assert(WeaponNativeThrowableOwner==nil and WeaponNativeThrowableAdapter and WeaponThrowableQuantityOwner
 and WeaponNativeThrowablePickupPermissions and not WeaponNativeThrowablePolicy.Enabled())
assert(WeaponNativeThrowablePickupClient==nil and WeaponNativeThrowableCollectionClientHost==nil)
source=65535
threadCount=#threads
events['feather-weapons:client:guid-suite-throwable']('retired',{},1)
events['feather-weapons:client:guid-suite-shared-collector']('retired',{}, {},1)
assert(#threads==threadCount,'stale retired suite events do not start client native work')
print('Native-only manifest client graph PASS (no hybrid owner/coordinator/GUID helper dependency)')
end
scenario(false);scenario(true);scenario(true,true)
