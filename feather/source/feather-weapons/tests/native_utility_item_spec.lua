Config={AmmunitionPools={enabled=false}}
dofile('shared/constants.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/native_utility_catalog.lua'); dofile('shared/native_utility_item.lua')
local function copy(v) if type(v)~='table' then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local U=WeaponNativeUtilityItem
local def=WeaponDefinitionCatalog.weapons.utility_lasso
local bound={characterId='john',sessionId='s',epoch='e'}
local row={id=200,revision=0,itemName='weapon_lasso',metadata={schemaVersion=WeaponConstants.MetadataSchemaVersion,
 weaponDefinitionId='utility_lasso',serialNumber='L',condition=100,quality=100,
 flags={stolen=false,evidence=false,disabled=false},attachments={},cosmetics={},provenance={}}}
local snapshot={characterId='john',expected={weapon_utility={itemId=200,revision=0}},equipment={utility=copy(row)}}
local approval=assert(U.Assigned(snapshot,def,bound))
assert(U.ValidateApproval(approval,def,bound))
assert(U.Project(row,def,bound).slot=='utility')
approval.row.metadata.serialNumber='changed'; assert(row.metadata.serialNumber=='L' and snapshot.equipment.utility.metadata.serialNumber=='L')
assert(U.Assigned({characterId='john',expected={},equipment={}},def,bound)==false)
for _,mutate in ipairs({function(s) s.characterId='jane' end,
 function(s) s.expected.weapon_utility.revision=1 end,
 function(s) s.expected.weapon_utility=nil end,
 function(s) s.equipment.utility=nil end,
 function(s) s.expected.weapon_melee={itemId=200,revision=0} end}) do
 local s=copy(snapshot); mutate(s); assert(U.Assigned(s,def,bound)==nil)
end
for _,mutate in ipairs({function(r) r.metadata.ammo={} end,
 function(r) r.metadata.flags.disabled=true end,function(r) r.metadata.flags.evidence=true end,
 function(r) r.metadata.condition=0 end,function(r) r.metadata.quality=0/0 end,
 function(r) r.metadata.attachments.barrel='x' end,function(r) r.metadata.weaponDefinitionId='melee_knife' end,
 function(r) r.itemName='renamed' end,function(r) r.id=math.huge end,
 function(r) r.metadata.provenance.createdAt=-1 end}) do
 local r=copy(row); mutate(r); assert(not U.Project(r,def,bound))
end
local a=assert(U.Assigned(snapshot,def,bound)); local changed=copy(bound); changed.epoch='new'
assert(not U.ValidateApproval(a,def,changed)); a.nativeGrantAmount=1
assert(not U.ValidateApproval(a,def,bound))
local file=assert(io.open('fxmanifest.lua','r')); local manifest=file:read('*a'); file:close()
assert(manifest:find('native_utility_item.lua',1,true))
print('native utility identity PASS: exact assignment, immutable approval, metadata/epoch/duplicate rejection; no runtime admission')
