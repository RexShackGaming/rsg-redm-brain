Config={AmmunitionPools={enabled=false}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/weapons.lua','shared/definitions/ammunition.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua','shared/character_ammunition_policy.lua',
 'shared/native_throwable_policy.lua'}) do dofile(p) end
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local base=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local candidate=assert(WeaponNativeThrowablePolicy.Preview(WeaponDefinitionCatalog,base))
local id='ammo_tomahawk_regular'
assert(candidate.testCeiling==1 and candidate.pickupCredits==false and candidate.requiresFundedQuantity)
assert(candidate.registry.names[id]=='AMMO_TOMAHAWK' and candidate.registry.limits[id]==1)
assert(base.names[id]==nil and base.limits[id]==nil and base.weapons.throwable_tomahawk==nil)
candidate.registry.limits.ammo_revolver_regular=1
assert(base.limits.ammo_revolver_regular==200,'private candidate registry')
candidate=assert(WeaponNativeThrowablePolicy.Preview(WeaponDefinitionCatalog,base))
local limits=candidate.registry.limits
local pools={}; for pool in pairs(limits) do pools[pool]=0 end
pools.ammo_repeater_regular=1
local record={characterId='john',sessionId='s',epoch='e',revision=3,pools=pools}
local funded,inventory=WeaponCharacterAmmunition.Transfer(record,id,1,limits)
assert(funded and funded.revision==4 and funded.pools[id]==1 and inventory.inventoryDelta==-1)
assert(record.pools[id]==0 and record.pools.ammo_repeater_regular==1)
assert(not WeaponCharacterAmmunition.Transfer(funded,id,1,limits),'bounded first-test ceiling')
local report=copy(funded); report.pools[id]=0
local spent=assert(WeaponCharacterAmmunition.Observe(funded,report,limits))
assert(spent.revision==5 and spent.pools[id]==0 and spent.pools.ammo_repeater_regular==1)
local gained=copy(spent); gained.pools[id]=1
assert(not WeaponCharacterAmmunition.Observe(spent,gained,limits),'pickup increase is not ownership credit')
assert(not WeaponCharacterAmmunition.Observe(spent,report,limits),'stale throw cannot be replayed')
local foreign=copy(spent); foreign.characterId='jane'
assert(not WeaponCharacterAmmunition.Observe(spent,foreign,limits))
local missing=copy(funded); missing.pools[id]=nil
assert(not WeaponCharacterAmmunition.Observe(funded,missing,limits))
for _,mutate in ipairs({function(c) c.weapons.throwable_tomahawk.nativeWeaponName='WEAPON_MELEE_HATCHET' end,
 function(c) c.weapons.throwable_tomahawk.ammunitionTypes[2]='ammo_tomahawk_improved' end,
 function(c) c.ammunition[id].nativeAmmoName='AMMO_REVOLVER' end}) do
 local bad=copy(WeaponDefinitionCatalog); mutate(bad)
 assert(not WeaponNativeThrowablePolicy.Preview(bad,base))
end
local alias=copy(base); alias.names.foreign='AMMO_TOMAHAWK'
assert(not WeaponNativeThrowablePolicy.Preview(WeaponDefinitionCatalog,alias))
local f=assert(io.open('fxmanifest.lua')); local manifest=f:read('*a'); f:close()
assert(manifest:find('shared/native_throwable_policy.lua',1,true))
GetConvarInt=function() return 0 end
assert(not WeaponNativeThrowablePolicy.Enabled(),'normal manifest loading must not enable throwable admission')
print('inert native Tomahawk policy PASS: existing ledger funding/spend, one-unit ceiling, no pickup credit, no alias/import/other variants')
