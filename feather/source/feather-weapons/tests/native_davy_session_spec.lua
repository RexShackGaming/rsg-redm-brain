dofile('tests/native_davy_collection_spec.lua')
dofile('client/character_ammunition_session.lua')
dofile('shared/character_ammunition_loadout_lease.lua')
if NativeTestBinoculars then dofile('shared/native_binoculars_policy.lua') end
if NativeTestCamera then dofile('shared/native_camera_policy.lua') end
if NativeTestAdvancedCamera then dofile('shared/native_advanced_camera_policy.lua') end
if NativeTestImprovedBinoculars then dofile('shared/native_improved_binoculars_policy.lua') end
if NativeTestFishingRod then dofile('shared/native_fishing_rod_policy.lua') end
if NativeTestMetalDetector then dofile('shared/native_metal_detector_policy.lua') end
GetConvarInt=function(name) return (name=='feather_native_utility' or name=='feather_native_lasso_reinforced'
    or name=='feather_native_davy_lantern' or NativeTestBinoculars and name=='feather_native_binoculars'
    or NativeTestCamera and name=='feather_native_camera'
    or NativeTestAdvancedCamera and name=='feather_native_camera_advanced'
    or NativeTestMetalDetector and name=='feather_native_metal_detector'
    or NativeTestFishingRod and name=='feather_native_fishing_rod'
    or NativeTestImprovedBinoculars and name=='feather_native_binoculars_improved') and 1 or 0 end
local U=WeaponNativeUtilityItem
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local id={characterId='john',sessionId='s',epoch='e'}
local snapshot={characterId='john',expected={},equipment={}}
local definitions={'utility_lasso_reinforced','utility_davy_lantern'}
if NativeTestBinoculars then definitions[3]='utility_binoculars' end
if NativeTestCamera then definitions[4]='utility_camera' end
if NativeTestAdvancedCamera then definitions[5]='utility_camera_advanced' end
if NativeTestImprovedBinoculars then definitions[6]='utility_binoculars_improved' end
if NativeTestFishingRod then definitions[8]='utility_fishing_rod' end
if NativeTestMetalDetector then definitions[7]='utility_metal_detector' end
for n,definition in ipairs(definitions) do
    local slot=({'utility','utility_secondary','utility_tertiary','utility_quaternary','utility_quinary','utility_senary','utility_septenary','utility_octonary'})[n]
    local def=WeaponDefinitionCatalog.weapons[definition]
    snapshot.equipment[slot]={id=171+n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='S'..n}))}
    snapshot.expected['weapon_'..slot]={itemId=171+n,revision=0}
end
local approval=assert(U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id))
local plan={identity=id,items={{itemInstanceId=155,itemRevision=4}}}
WeaponCharacterAmmoMaterialization={Validate=function() return true end,Build=function() return copy(plan) end}
local lease=WeaponCharacterAmmoLoadoutLease.New(plan,nil,nil,nil,{},snapshot)
assert(lease.Contains(172) and lease.Contains(173) and lease.Contains(155))
if NativeTestBinoculars then assert(lease.Contains(174)) end
if NativeTestCamera then assert(lease.Contains(175)) end
if NativeTestAdvancedCamera then assert(lease.Contains(176)) end
if NativeTestImprovedBinoculars then assert(lease.Contains(177)) end
assert(lease.Validate({characterId='john',equipment={},utilityEquipment=snapshot},WeaponDefinitionCatalog,{}))
local changed=copy(snapshot); changed.equipment.utility_secondary.metadata.serialNumber='changed'
assert(not lease.Validate({characterId='john',equipment={},utilityEquipment=changed},WeaponDefinitionCatalog,{}))
changed=copy(snapshot); changed.equipment.utility_secondary=nil; changed.expected.weapon_utility_secondary=nil
assert(not lease.Validate({characterId='john',equipment={},utilityEquipment=changed},WeaponDefinitionCatalog,{}))
WeaponCharacterAmmoClient={New=function() return {Begin=function() return {} end} end}
WeaponCharacterAmmoNative={New=function() return {Read=function() return {} end} end}
WeaponCharacterAmmoLoadout={New=function() return {Create=function() return {handles={}} end} end}
for _,mode in ipairs({'success','death','second_create','second_cleanup'}) do
    local state={phase='active',baseline=id}
    local grants,removes,acks,setup,restores=0,0,0,0,0
    WeaponCharacterAmmoController={New=function() return {
        Status=function() return state end,Begin=function() restores=restores+1; return true end,
        Finalize=function() state.phase='sealed'; return true end,
        FinalizeDeath=function() state.phase='sealed'; state.deathClosing=true; return true end,
        AllowDeathCleanup=function() state.deathClosing=false; return true end,
        ConfirmCleanup=function() acks=acks+1; return true end} end}
    local api={ped=function() return 7 end,ready=function() return true end,block=function() end,
        creation=function() return {cleanupSetup=function() setup=setup+1; return true end} end}
    api.utility=function(ped,bound,sealed,def)
        assert(def.id=='native_utility_collection')
        return WeaponNativeUtilityCollection.New(function(_,identity,seal,definition)
            return assert(WeaponNativeUtilityOwner.New({
                current=function() return true end,present=function() return false end,
                create=function() grants=grants+1; return not(mode=='second_create' and grants==#definitions) end,
                capture=function() return {guid=string.rep('a',32)} end,sealed=seal,
                removeCaptured=function() removes=removes+1; return mode~='second_cleanup' end,
                absent=function() return true end,
            },definition,identity))
        end,ped,bound,sealed)
    end
    local session=WeaponCharacterAmmoSession.New(api,{limits={},names={}})
    local began=session.Begin({runtime=id,creation=plan,utility=approval})
    if mode=='second_create' then
        assert(not began and restores==0 and not session.Cleanup() and acks==0 and setup==0)
    else
        assert(began and grants==#definitions and restores==1 and #session.Status().utility.items==#definitions)
        if mode=='death' then assert(session.FinalizeDeath()); assert(not session.Cleanup()); assert(session.RecoverDeath())
        else assert(session.Finalize()) end
        local released=mode=='death' or session.Cleanup()
        if mode=='second_cleanup' then assert(not released and acks==0 and setup==0)
        else assert(released and removes==#definitions and acks==1 and setup==1,mode..':'..removes..':'..acks..':'..setup) end
    end
end
print('Davy actual session/lease PASS: both item holds, mutation refusal, pre-restore creation, death/orderly cleanup and retained second-child failure')
