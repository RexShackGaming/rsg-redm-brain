Config={AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
dofile('shared/constants.lua'); dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/validation.lua'); dofile('shared/character_ammunition_catalog.lua'); dofile('shared/character_ammunition_item.lua')
local catalog=WeaponDefinitionCatalog
local policy={}
for _,w in pairs(catalog.weapons) do
    if ({pistol=true,revolver=true,repeater=true,rifle=true,shotgun=true})[w.family] and w.nativeWeaponName~='WEAPON_REVOLVER_LEMAT' then
        for _,id in ipairs(w.ammunitionTypes) do policy[id]=catalog.ammunition[id].maxTotal or 200 end
    end
end
local registry=assert(WeaponCharacterAmmoCatalog.Build(catalog,policy))
local function row(id,weapon)
    local def=catalog.weapons[weapon]
    return {id=id,revision=3,itemName=def.itemName,metadata={schemaVersion=2,weaponDefinitionId=weapon,serialNumber='serial-'..id,
        condition=100,quality=100,maintenance={degradation=0,permanentDegradation=0,damage=0,dirt=0,soot=0},
        ammo={ownership='character',type=def.ammunitionType},attachments={},cosmetics={},
        flags={stolen=false,evidence=false,disabled=false},provenance={}}}
end
local primary,offhand=row(1,'pistol_m1899'),row(2,'pistol_m1899')
local loadout=assert(WeaponCharacterAmmoItem.Loadout({primary=primary,offhand=offhand},catalog,registry))
assert(loadout.dual and loadout.sameModel and loadout.slots.primary.point==2 and loadout.slots.offhand.point==3)
assert(loadout.slots.primary.ammo==nil and loadout.slots.primary.loaded==nil,'never project item-owned ammo')
loadout.slots.primary.maintenance.dirt=1; assert(primary.metadata.maintenance.dirt==0,'defensive identity snapshot')
assert(primary.metadata.ammo.loaded==nil and primary.metadata.ammo.reserve==nil,'validation must not repair new metadata')
primary.metadata.ammo.loaded=0; assert(not WeaponCharacterAmmoItem.Validate(primary.metadata,catalog.weapons.pistol_m1899))
primary.metadata.ammo.loaded=nil
primary.metadata.condition=0/0; assert(not WeaponCharacterAmmoItem.Validate(primary.metadata,catalog.weapons.pistol_m1899))
primary.metadata.condition=100
assert(not WeaponCharacterAmmoItem.Loadout({primary=primary,offhand=primary},catalog,registry))
assert(not WeaponCharacterAmmoItem.Loadout({offhand=offhand},catalog,registry))
assert(not WeaponCharacterAmmoItem.Loadout({shoulder=primary},catalog,registry))
assert(not WeaponCharacterAmmoItem.Loadout({primary=row(3,'revolver_lemat')},catalog,registry))
assert(not WeaponCharacterAmmoItem.Loadout({shoulder=row(3,'repeater_carbine'),back=row(4,'repeater_carbine')},catalog,registry))
primary.metadata.flags.evidence=true; assert(not WeaponCharacterAmmoItem.Loadout({primary=primary},catalog,registry))
print('character_ammunition_item_spec PASS (identity preserved, no item ammo, slots/duplicates/special-mode rejection)')
