-- Actual normal policies with developer mode off; feature switches still apply.
dofile('shared/constants.lua')
Config={DevMode=false,NativeAlphaRuntime=true,CharacterAmmunitionEnabled=true,
 CharacterAmmoTransportEnabled=true,NativeAlphaLifecycleWearEnabled=true}
GetConvarInt=function() return 1 end
dofile('shared/native_knife.lua')
dofile('shared/native_melee_catalog.lua')
dofile('shared/native_throwable_policy.lua')
dofile('shared/native_utility_catalog.lua')
local policies={WeaponNativeKnife,WeaponNativeMeleeCatalog,WeaponNativeThrowablePolicy,WeaponNativeUtilityCatalog}
for _,policy in ipairs(policies) do assert(policy.Enabled(),'normal feature requires no developer mode') end
for _,flag in ipairs({'NativeAlphaRuntime','CharacterAmmunitionEnabled','CharacterAmmoTransportEnabled','NativeAlphaLifecycleWearEnabled'}) do
 Config[flag]=false
 for _,policy in ipairs(policies) do assert(not policy.Enabled(),'normal feature gate still required: '..flag) end
 Config[flag]=true
end
GetConvarInt=function() return 0 end
for _,policy in ipairs(policies) do assert(not policy.Enabled(),'feature convar still required') end
print('Normal gameplay gates PASS (DevMode=false, native/transport/lifecycle/feature switches preserved)')
