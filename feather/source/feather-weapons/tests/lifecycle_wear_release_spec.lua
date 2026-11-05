dofile('client/character_ammunition_release.lua'); dofile('client/character_ammunition_client_runtime.lua')
local phase,order='active',{}
local identity={characterId='c',sessionId='s',epoch='e'}
WeaponCharacterAmmoWorldContext={Identity=function() return identity end}
WeaponCharacterAmmoHost={New=function() return {
 Status=function() return {phase=phase,epoch='e'} end,
 PrepareEquipmentRelease=function() order[#order+1]='prepare'; return true end,
 Finalize=function() order[#order+1]='seal'; phase='sealed'; return true end,
 Cleanup=function() order[#order+1]='remove'; phase='closed'; return true end,
 Tick=function() return true end,Suspend=function() phase='frozen' end,
} end}
WeaponCharacterAmmoDriver={New=function() return {Status=function() return {} end} end}
local runtime=assert(WeaponCharacterAmmoClientRuntime.New({life=function() return 'alive' end,
 now=function() return 0 end,wait=function() end,block=function() end}))
WeaponCharacterAmmoActiveOwner={FinalWear=function(bound)
 assert(bound==identity and runtime.Status().runtimeBusy and phase=='active')
 order[#order+1]='sample'; return {epoch='e',items={}}
end}
local ok,reason,wear=runtime.ReleaseEquipment(identity,'ticket',true)
assert(ok and reason==nil and wear.epoch=='e')
assert(table.concat(order,',')=='sample,prepare,seal,remove','sample must precede seal/removal under one reservation')
phase='active'; order={}; WeaponCharacterAmmoActiveOwner=nil
assert(not runtime.ReleaseEquipment(identity,'ticket',true) and #order==0,'failed sample must not release owner')
print('lifecycle_wear_release_spec PASS (reserved pre-seal sample, extra result preserved, read failure retains copies)')
