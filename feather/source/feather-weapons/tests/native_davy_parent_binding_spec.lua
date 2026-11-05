dofile('tests/native_davy_collection_spec.lua')
if NativeTestBinoculars then dofile('shared/native_binoculars_policy.lua') end
if NativeTestCamera then dofile('shared/native_camera_policy.lua') end
if NativeTestAdvancedCamera then dofile('shared/native_advanced_camera_policy.lua') end
if NativeTestImprovedBinoculars then dofile('shared/native_improved_binoculars_policy.lua') end
if NativeTestFishingRod then dofile('shared/native_fishing_rod_policy.lua') end
if NativeTestMetalDetector then dofile('shared/native_metal_detector_policy.lua') end
local advancedGate=1
local metalDetectorGate=1
local fishingRodGate=1
local improvedGate=1
GetConvarInt=function(name)
    if NativeTestFishingRod and name=='feather_native_fishing_rod' then return fishingRodGate end
    if NativeTestMetalDetector and name=='feather_native_metal_detector' then return metalDetectorGate end
    if NativeTestAdvancedCamera and name=='feather_native_camera_advanced' then return advancedGate end
    if NativeTestImprovedBinoculars and name=='feather_native_binoculars_improved' then return improvedGate end
    return (name=='feather_native_utility' or name=='feather_native_lasso_reinforced'
    or name=='feather_native_davy_lantern' or NativeTestBinoculars and name=='feather_native_binoculars'
    or NativeTestCamera and name=='feather_native_camera'
    or NativeTestAdvancedCamera and name=='feather_native_camera_advanced') and 1 or 0 end
Config.CharacterAmmoTransportEnabled=true
dofile('client/character_ammunition_native_owner.lua')
local U=WeaponNativeUtilityItem
local bound={characterId='john',sessionId='s',epoch='e'}
local entries={}
local definitions={'utility_lasso_reinforced','utility_davy_lantern'}
if NativeTestBinoculars then definitions[3]='utility_binoculars' end
if NativeTestCamera then definitions[4]='utility_camera' end
if NativeTestAdvancedCamera then definitions[5]='utility_camera_advanced' end
if NativeTestImprovedBinoculars then definitions[6]='utility_binoculars_improved' end
if NativeTestFishingRod then definitions[8]='utility_fishing_rod' end
if NativeTestMetalDetector then definitions[7]='utility_metal_detector' end
for n,definition in ipairs(definitions) do
    local def=WeaponDefinitionCatalog.weapons[definition]
    entries[n]={identity=bound,equipmentSlot=({'weapon_utility','weapon_utility_secondary','weapon_utility_tertiary','weapon_utility_quaternary','weapon_utility_quinary','weapon_utility_senary','weapon_utility_septenary','weapon_utility_octonary'})[n],
        row={id=171+n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='S'..n}))}}
end
local modes={'success','second_factory','second_cleanup'}
if NativeTestAdvancedCamera then modes[#modes+1]='advanced_gate_loss' end
if NativeTestImprovedBinoculars then modes[#modes+1]='improved_gate_loss' end
if NativeTestMetalDetector then modes[#modes+1]='metal_detector_gate_loss' end
if NativeTestFishingRod then modes[#modes+1]='fishing_rod_gate_loss' end
for _,mode in ipairs(modes) do
    fishingRodGate=1
    metalDetectorGate=1
    advancedGate=1
    improvedGate=1
    local create,track,utility
    local factories,removed=0,0
    local owner=assert(WeaponCharacterAmmoNativeOwner.New({
        context=function() return {ok=true,value={characterId='john',sessionId='s',ped=7}} end,
        ped=function() return 7 end,dual=function() return {} end,
        creation=function(_,_,_,cleanup) return {cleanupSetup=cleanup} end,
        bootstrap=function(c,t,_,_,_,u)
            create,track,utility=c,t,u
            return {Start=function() return true end,Status=function() return {runtime={phase='active'}} end}
        end,
        utility=function(_,identity,current,sealed,def)
            factories=factories+1
            assert(current(identity))
            if mode=='second_factory' and factories==#definitions then error('uncertain factory') end
            local phase='idle'
            return {Create=function() assert(current(identity)); phase='active'; return true end,
                Release=function()
                    assert(current(identity),'revoked child cannot release')
                    if mode=='second_cleanup' and def.id==definitions[#definitions] then return nil end
                    phase='released'; removed=removed+1; return true
                end,Status=function() return {phase=phase} end}
        end,
    }))
    assert(owner.Start())
    local adapter=assert(create(7,bound)); track(adapter,{})
    local tools=assert(utility(7,bound,function() return true end,{id='native_utility_collection'}))
    local made=tools.Create({items=entries})
    assert(not adapter.cleanupSetup(),'parent held while any utility is unconfirmed')
    if mode=='advanced_gate_loss' then advancedGate=0 end
    if mode=='improved_gate_loss' then improvedGate=0 end
    if mode=='fishing_rod_gate_loss' then fishingRodGate=0 end
    if mode=='metal_detector_gate_loss' then metalDetectorGate=0 end
    if mode=='second_factory' then assert(not made and not tools.Release() and not adapter.cleanupSetup())
    elseif mode=='second_cleanup' then assert(made and not tools.Release() and not adapter.cleanupSetup())
    elseif mode=='advanced_gate_loss' then assert(made and not tools.Release() and not adapter.cleanupSetup())
    elseif mode=='metal_detector_gate_loss' then assert(made and not tools.Release() and not adapter.cleanupSetup())
    elseif mode=='fishing_rod_gate_loss' then assert(made and not tools.Release() and not adapter.cleanupSetup())
    elseif mode=='improved_gate_loss' then assert(made and not tools.Release() and not adapter.cleanupSetup())
    else assert(made and tools.Release() and removed==#definitions and adapter.cleanupSetup()) end
end
print('Davy actual native parent PASS: both child factories tracked and uncertain second factory/cleanup retain parent')
