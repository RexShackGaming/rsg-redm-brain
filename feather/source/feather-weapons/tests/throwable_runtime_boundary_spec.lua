local function read(path)
 local f=assert(io.open(path));local text=f:read('*a');f:close();return text
end
local manifest=read('fxmanifest.lua')
local retired=dofile('tests/archive/throwable-research/retired-scripts.lua')
assert(#retired==45)
for _,path in ipairs(retired) do
 assert(not manifest:find("'"..path.."'",1,true) and not manifest:find("'/"..path.."'",1,true),path..' is research, not normal runtime')
 assert(#read(path)>0,'preserve original source for offline evidence: '..path)
end
assert(manifest:find('/shared/throwable_mode.lua',1,true))
assert(manifest:find('/client/throwable_quantity_owner.lua',1,true))
assert(manifest:find('/client/native_throwable_pickup_permissions.lua',1,true))
assert(manifest:find('/server/services/native_guid_acceptance.lua',1,true),'firearm GUID suite remains supported')
assert(not manifest:find('tests/',1,true),'archive never becomes a runtime dependency')
-- The supported mode forces stale physical settings off and refuses old
-- console switches before any host/loan/issuance setup can occur.
local flags={}
GetConvarInt=function(name,default) return flags[name] or default end
GetConvar=function(name,default) return name=='feather_throwable_quantities' and '1' or default end
local function config()
 return {NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,
  NativeAlphaLifecycleWearEnabled=true,NativeThrowableUnitsEnabled=true,NativeThrowableNativeCollectionContract=1}
end
Config=config();dofile('shared/throwable_mode.lua')
assert(Config.NativeThrowableQuantityOnly and Config.NativeThrowableQuantityContract==1
 and not Config.NativeThrowableUnitsEnabled and Config.NativeThrowablePickupContract==0
 and Config.NativeThrowableNativeCollectionContract==0)
for _,name in ipairs({'feather_native_paid_throwables','feather_native_paid_collection','feather_native_throwable','feather_native_throwable_pickup'}) do
 Config=config();flags[name]=1
 local ok,reason=pcall(dofile,'shared/throwable_mode.lua')
 assert(not ok and tostring(reason):find(name,1,true))
 flags[name]=nil
end
print('PASS supported throwable boundary: 45 retired entries offline, original evidence retained, quantity-only composition, firearm suite retained and obsolete switches refused')
