Config={AmmunitionPools={enabled=false}}
dofile('shared/definitions/weapons.lua'); dofile('shared/native_lasso_policy.lua')
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local P=WeaponNativeLassoPolicy; local catalog=WeaponDefinitionCatalog
for _,id in ipairs({'utility_lasso','utility_lasso_reinforced'}) do
 local def=catalog.weapons[id]; assert(P.Resolve(def).nativeGrantAmount==0)
 local changed=copy(def); changed.nativeWeaponName='forged'; assert(not P.Resolve(changed))
 changed=copy(def); changed.ammunitionTypes={'ammo_tomahawk_regular'}; assert(not P.Resolve(changed))
end
local function row(id) return {id=200,itemName=catalog.weapons[id].itemName,metadata={weaponDefinitionId=id}} end
local standard,reinforced=row('utility_lasso'),row('utility_lasso_reinforced')
local single=assert(P.ValidateAssignments({utility_secondary=reinforced},catalog))
assert(single.equipmentSlot=='weapon_utility_secondary')
for _,pair in ipairs({{utility=standard,utility_secondary=reinforced},
 {utility=reinforced,utility_octonary=standard},{utility=standard,utility_secondary=copy(standard)}}) do
 local accepted,why=P.ValidateAssignments(pair,catalog)
 assert(accepted==nil and why=='one_equipped_lasso_required')
 assert(pair.utility.itemName~=nil,'conflicts are refused, never reconciled/deleted')
end
assert(P.ValidateAssignments({},catalog)==false)
assert(P.ValidateAssignments({utility=standard,utility_secondary=row('utility_davy_lantern')},catalog))
assert(not P.ValidateAssignments({utility_unknown=reinforced},catalog))
local f=assert(io.open('fxmanifest.lua','r')); local m=f:read('*a'); f:close()
assert(m:find('native_lasso_policy.lua',1,true),'family policy must load before explicit gated admission')
print('staged lasso family policy PASS: exact two models, stable utility slots, single-lasso refusal without deleting ownership')
