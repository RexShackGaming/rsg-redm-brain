dofile('tests/native_utility_item_spec.lua')
dofile('shared/native_lasso_policy.lua')
dofile('shared/native_davy_lantern_policy.lua')
dofile('shared/native_utility_collection.lua')
dofile('client/native_utility_owner.lua')
dofile('client/native_utility_collection.lua')
Config.DevMode=true; Config.NativeAlphaRuntime=true; Config.CharacterAmmunitionEnabled=true
Config.CharacterAmmoTransportEnabled=true; Config.NativeAlphaLifecycleWearEnabled=true
local gate=1
GetConvarInt=function(name) return name=='feather_native_davy_lantern' and gate
    or (name=='feather_native_utility' or name=='feather_native_lasso_reinforced') and 1 or 0 end
local U=WeaponNativeUtilityItem
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local id={characterId='john',sessionId='s',epoch='e'}
local function row(n,definition)
    local def=WeaponDefinitionCatalog.weapons[definition]
    return {id=n,revision=0,itemName=def.itemName,metadata=assert(U.Build(def,{serialNumber='S'..n}))}
end
local lasso,lantern=row(172,'utility_lasso_reinforced'),row(173,'utility_davy_lantern')
local snapshot={characterId='john',expected={weapon_utility={itemId=172,revision=0},
    weapon_utility_secondary={itemId=173,revision=0}},
    equipment={utility=lasso,utility_secondary=lantern}}
local approval=assert(U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id))
assert(#approval.items==2 and U.ValidateCollection(approval,WeaponDefinitionCatalog,id))
local original=copy(approval)
approval.items[1].row.metadata.serialNumber='mutated'
assert(snapshot.equipment.utility.metadata.serialNumber=='S172')
approval=original
for _,mutate in ipairs({
    function(s) s.equipment.utility_secondary=copy(lasso); s.expected.weapon_utility_secondary.itemId=172 end,
    function(s) s.equipment.utility_secondary.metadata.weaponDefinitionId='utility_lantern' end,
    function(s) s.expected.weapon_utility_secondary.revision=1 end,
    function(s) s.expected.weapon_melee={itemId=173,revision=0} end,
    function(s) s.equipment.utility_secondary.metadata.ammo={} end,
    function(s) s.characterId='jane' end,
}) do
    local s=copy(snapshot); mutate(s); assert(not U.AssignedSnapshot(s,WeaponDefinitionCatalog,id))
end
local malformed=copy(approval); malformed.items[3]=copy(approval.items[1])
assert(not U.ValidateCollection(malformed,WeaponDefinitionCatalog,id))
malformed=copy(approval); malformed.items[2].identity.epoch='stale'
assert(not U.ValidateCollection(malformed,WeaponDefinitionCatalog,id))
local outer={characterId='john',equipment={},expected=copy(snapshot.expected),utilityEquipment=copy(snapshot)}
local intent={action='unequip',slot='weapon_utility_secondary',selectedItemId=173}
local spec=assert(U.Prepare(outer,WeaponDefinitionCatalog.weapons.utility_davy_lantern,id,intent))
assert(spec.davyFamily and spec.utilityId==173 and spec.expected.weapon_utility.itemId==172)
outer.expected.weapon_utility_secondary=nil; outer.utilityEquipment.expected.weapon_utility_secondary=nil
outer.utilityEquipment.equipment.utility_secondary=nil; outer.candidate=lantern
assert(U.Prepare(outer,WeaponDefinitionCatalog.weapons.utility_davy_lantern,id,
    {action='equip',slot='weapon_utility_secondary',itemId=173}))
outer.candidate=row(174,'utility_lasso')
assert(not U.Prepare(outer,WeaponDefinitionCatalog.weapons.utility_lasso,id,
    {action='equip',slot='weapon_utility_secondary',itemId=174}))
for _,mode in ipairs({'success','create_second','cleanup_second','gate_loss','factory_second'}) do
    local creates,removes,factories=0,0,0
    local sealed=false
    gate=1
    local composite=WeaponNativeUtilityCollection.New(function(_,bound,seal,def)
        factories=factories+1
        if mode=='factory_second' and factories==2 then error('uncertain factory') end
        return assert(WeaponNativeUtilityOwner.New({
            current=function() return gate==1 end,present=function() return false end,
            create=function() creates=creates+1; return not (mode=='create_second' and creates==2) end,
            capture=function() return {guid=string.rep(def.family=='lasso' and 'a' or 'b',32)} end,
            sealed=seal,removeCaptured=function() removes=removes+1; return mode~='cleanup_second' end,
            absent=function() return true end,
        },def,bound))
    end,7,id,function() return sealed end)
    local created=composite.Create(approval)
    if mode=='create_second' or mode=='factory_second' then
        assert(not created and not composite.Release() and removes==0)
    else
        assert(created and creates==2 and #composite.Status().items==2)
        sealed=true
        if mode=='gate_loss' then gate=0 end
        local released=composite.Release()
        if mode=='success' then assert(released and removes==2 and composite.Status().phase=='released')
        else assert(not released and composite.Status().phase=='retained') end
    end
    assert(not composite.Create(approval),'no creation retry')
end
gate=0
assert(not WeaponNativeUtilityCatalog.Resolve(WeaponDefinitionCatalog.weapons.utility_davy_lantern))
assert(not U.AssignedSnapshot(snapshot,WeaponDefinitionCatalog,id),'gate off cannot omit saved Davy')
print('Davy collection PASS: paired approvals, one-family/identity/metadata/CAS guards, exact child cleanup and uncertainty retention')
