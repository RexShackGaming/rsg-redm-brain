-- Production policy + item/materialization + all-pool accounting composition.
-- Native pool storage is mocked: live LeMat mode readback remains a separate gate.
Config={DevMode=false,NativeAlphaRuntime=true}
GetConvarInt=function(_,default) return default end
for _,file in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua',
 'shared/definitions/attachments.lua','shared/definitions/weapons.lua','shared/validation.lua',
 'shared/character_ammunition.lua','shared/character_ammunition_catalog.lua',
 'shared/character_ammunition_policy.lua','shared/character_ammunition_item.lua',
 'shared/character_ammunition_materialization.lua','client/character_ammunition_native.lua'}) do dofile(file) end
local registry=assert(WeaponCharacterAmmoPolicy.Build(WeaponDefinitionCatalog))
local lemat=registry.weapons.revolver_lemat
assert(lemat and lemat.compatible.ammo_revolver_regular and lemat.compatible.ammo_shotgun_regular)
assert(not lemat.compatible.ammo_shotgun_slug and not lemat.compatible.ammo_pistol_regular)
assert(registry.limits.ammo_shotgun_regular==60 and registry.limits.ammo_revolver_regular==200,
 'shared character ceilings are not replaced with clip capacities')
local function row(id)
 return {id=id,revision=0,itemName='weapon_revolver_lemat',metadata={schemaVersion=2,
  weaponDefinitionId='revolver_lemat',serialNumber='lemat-'..id,condition=100,quality=100,
  maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
  ammo={ownership='character',type='ammo_revolver_regular'},
  attachments={{definitionId='lemat_long_barrel',slot='barrel'},{definitionId='lemat_wide_sight',slot='sight'}},
  cosmetics={},flags={disabled=false,evidence=false,stolen=false},provenance={}}}
end
local identity={characterId='Jane',sessionId='s',epoch='e'}
local primary,offhand=row(901),row(902)
local plan=assert(WeaponCharacterAmmoMaterialization.Build({primary=primary,offhand=offhand},WeaponDefinitionCatalog,registry,identity))
assert(plan.dual and plan.sameModel and WeaponCharacterAmmoMaterialization.Validate(plan,registry,identity))
assert(#plan.items[1].attachments==2 and #plan.items[2].attachments==2)
primary.metadata.ammo.loaded=1
assert(not WeaponCharacterAmmoItem.Validate(primary.metadata,WeaponDefinitionCatalog.weapons.revolver_lemat),
 'dual modes never introduce item-owned quantities')
primary.metadata.ammo.loaded=nil
local pools={};for id in pairs(registry.limits) do pools[id]=0 end
pools.ammo_revolver_regular=9;pools.ammo_shotgun_regular=1;pools.ammo_repeater_regular=7
local native={};for id,name in pairs(registry.names) do native[name]=pools[id] end
local writes=0
local boundary=assert(WeaponCharacterAmmoNative.New(registry.names,registry.limits,{
 ped=function() return 42 end,hash=function(name) return name end,
 read=function(_,name) return native[name] end,
 write=function(_,name,count) writes=writes+1;native[name]=count end,
 remove=function(_,name,count) writes=writes+1;native[name]=native[name]-count end}))
local record={characterId='Jane',sessionId='s',epoch='e',revision=1,pools=pools}
local function observe()
 return WeaponCharacterAmmunition.Observe(record,{characterId='Jane',sessionId='s',epoch='e',
  revision=record.revision,pools=assert(boundary.Read(42,true))},registry.limits)
end
assert(observe().revision==1 and writes==0,'mode/clip changes alone do not spend or create rounds')
-- Use catalog native names: no hard-coded alias can accidentally pass the test.
native[registry.names.ammo_shotgun_regular]=0
record=assert(observe())
assert(record.revision==2 and record.pools.ammo_revolver_regular==9 and record.pools.ammo_shotgun_regular==0)
native[registry.names.ammo_revolver_regular]=8
record=assert(observe())
assert(record.revision==3 and record.pools.ammo_shotgun_regular==0 and record.pools.ammo_repeater_regular==7)
native[registry.names.ammo_shotgun_regular]=1
assert(not observe(),'switching modes must not credit a new shotgun round')
assert(boundary.Restore({phase='restoring',pools=record.pools},42,true))
assert(native[registry.names.ammo_shotgun_regular]==0 and native[registry.names.ammo_revolver_regular]==8,
 'fresh restore clears unfunded alternate-mode ammo and preserves revolver rounds')
local transferred,inventory=WeaponCharacterAmmunition.Transfer(record,'ammo_shotgun_regular',1,registry.limits)
assert(transferred and inventory.inventoryDelta==-1 and transferred.pools.ammo_revolver_regular==8)
local unloaded,returned=WeaponCharacterAmmunition.Transfer(transferred,'ammo_revolver_regular',-8,registry.limits)
assert(unloaded and returned.inventoryDelta==8 and unloaded.pools.ammo_shotgun_regular==1
 and unloaded.pools.ammo_repeater_regular==7,'independent unload preserves the other mode and unrelated pools')
assert(boundary.Restore({phase='restoring',pools=unloaded.pools},42,true))
assert(primary.metadata.ammo.loaded==nil and primary.revision==0 and offhand.revision==0)
print('LeMat ammunition composition PASS (separate shared pools, mode no-op, shot isolation, increase refusal, restore/load/unload; mocked native totals)')
