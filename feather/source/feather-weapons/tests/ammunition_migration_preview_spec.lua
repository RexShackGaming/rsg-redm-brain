dofile('shared/ammunition_migration_preview.lua')
local build=WeaponAmmoMigrationPreview.Build
local catalog={weapons={gun={id='gun',itemName='weapon_gun',family='repeater',capacity=7,
    ammunitionType='regular',ammunitionTypes={'regular','express'}},
    bow={id='bow',itemName='weapon_bow',family='bow'}},
    ammunition={regular={nativeAmmoName='AMMO_REPEATER'},express={nativeAmmoName='AMMO_REPEATER_EXPRESS'}}}
local limits={regular=200,express=200}
local function item(id,pools,loaded,reserve)
    return {id=id,name='weapon_gun',type='item_weapon',revision=1,
        metadata={weaponDefinitionId='gun',ammo={type='regular',loaded=loaded,reserve=reserve,pools=pools}}}
end
local one=item(1,{regular=8,express=4},7,1)
local two=item(2,{regular=5},3,2)
local plan=build({one,two,{id=3,name='weapon_bow',type='item_weapon'},
    {id=4,name='regular',type='item_ammo'}},catalog,limits)
assert(plan.validationPassed and not plan.productionReady and plan.firearmCount==2)
assert(plan.pools.regular==13 and plan.pools.express==4)
assert(plan.nativePools.AMMO_REPEATER.total==13 and plan.loose.regular==1)
assert(#plan.excluded==1 and one.metadata.ammo.loaded==7 and one.metadata.ammo.pools.regular==8)
assert(not build({one,one},catalog,limits).validationPassed)
assert(not build({item(8,nil,3,2)},catalog,limits).validationPassed)
local invalid=item(5,{regular=9},7,1)
assert(not build({invalid},catalog,limits).validationPassed)
invalid=item(5,{regular=8,foreign=1},7,1)
assert(not build({invalid},catalog,limits).validationPassed)
invalid=item(5,nil,0,-1)
assert(not build({invalid},catalog,limits).validationPassed)
invalid=item(5,nil,0,0); invalid.metadata.ammo.ownership='character'
assert(not build({invalid},catalog,limits).validationPassed)
invalid=item(5,{regular=8},7,1); invalid.metadata.ammo.clips={regular=8}
assert(not build({invalid},catalog,limits).validationPassed)
local overflowing=item(6,{regular=199},7,192)
assert(#build({overflowing,two},catalog,limits).overflow==1)
assert(not build({{id=7,name='weapon_unknown',type='item_weapon'}},catalog,limits).validationPassed)
print('ammunition migration preview PASS (pure read-only)')
