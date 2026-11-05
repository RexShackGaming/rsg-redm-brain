Config={AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua')
dofile('shared/definitions/weapons.lua'); dofile('shared/validation.lua')
dofile('shared/character_ammunition_item.lua'); dofile('shared/character_maintenance.lua')
local definition=WeaponDefinitionCatalog.weapons.revolver_cattleman
local function item()
    return {schemaVersion=2,weaponDefinitionId=definition.id,serialNumber='serial-1',condition=60,quality=100,
        maintenance={degradation=0.4,permanentDegradation=0.1,damage=0.2,dirt=0.5,soot=0.3},
        ammo={ownership='character',type=definition.ammunitionType},attachments={},cosmetics={},
        flags={stolen=false,evidence=false,disabled=false},provenance={}}
end
local original=item()
local observed=assert(WeaponCharacterMaintenance.Observe(original,definition,
    {degradation=0.2,permanentDegradation=0.15,damage=0.5,dirt=0.1,soot=0.7}))
assert(observed.condition==50 and observed.maintenance.degradation==0.4)
assert(observed.maintenance.dirt==0.5 and observed.maintenance.soot==0.7)
assert(original.condition==60 and original.maintenance.soot==0.3)
local repaired,cost=WeaponCharacterMaintenance.Repair(observed,definition)
assert(repaired.condition==85 and repaired.maintenance.permanentDegradation==0.15)
assert(repaired.maintenance.damage==0.15 and repaired.maintenance.degradation==0.15)
assert(repaired.maintenance.dirt==0 and repaired.maintenance.soot==0)
assert(cost.itemDefinitionId=='gun_oil' and cost.quantity==1)
assert(repaired.serialNumber==original.serialNumber and repaired.quality==original.quality)
assert(repaired.ammo.ownership=='character' and repaired.ammo.type==original.ammo.type)
assert(repaired.ammo.loaded==nil and repaired.ammo.reserve==nil)
repaired.ammo.type='changed'; assert(observed.ammo.type==original.ammo.type)
for _,invalid in ipairs({-0.1,1.1,math.huge,0/0,'0.5'}) do
    local report={degradation=invalid,permanentDegradation=0,damage=0,dirt=0,soot=0}
    assert(not WeaponCharacterMaintenance.Observe(original,definition,report))
    local bad=item(); bad.maintenance.dirt=invalid
    assert(not WeaponCharacterMaintenance.Repair(bad,definition))
end
assert(not WeaponCharacterMaintenance.Observe(original,definition,{dirt=0}))
local report={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0,ammo=1}
assert(not WeaponCharacterMaintenance.Observe(original,definition,report))
for _,flag in ipairs({'disabled','evidence'}) do
    local bad=item(); bad.flags[flag]=true
    assert(not WeaponCharacterMaintenance.Repair(bad,definition))
end
local clean=item(); clean.condition=100
for key in pairs(clean.maintenance) do clean.maintenance[key]=0 end
assert(not WeaponCharacterMaintenance.Repair(clean,definition))
clean.maintenance.dirt=0.5; assert(WeaponCharacterMaintenance.Repair(clean,definition).condition==100)
local inconsistent=item(); inconsistent.condition=100
assert(not WeaponCharacterMaintenance.Repair(inconsistent,definition))
local damaged=item(); damaged.condition=20
assert(WeaponCharacterMaintenance.Observe(damaged,definition,
    {degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0}).condition==20)
print('character_maintenance_spec PASS (monotonic wear, permanent repair floor, immutable ammo/identity, strict reports)')
