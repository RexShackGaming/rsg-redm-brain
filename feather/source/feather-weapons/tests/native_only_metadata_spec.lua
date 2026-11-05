Config={CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true,AmmunitionPools={enabled=false},Escrow={maxTotal=200}}
for _,p in ipairs({'shared/constants.lua','shared/definitions/ammunition.lua','shared/definitions/weapons.lua',
 'shared/validation.lua','shared/character_ammunition_item.lua'}) do dofile(p) end
WeaponResult={Ok=function(v) return {ok=true,value=v} end,Error=function(c,m) return {ok=false,error={code=c,message=m}} end}
WeaponErrors={ITEM_INVALID='invalid'}
DefinitionRegistry={ValidateAttachmentSet=function() return {ok=true} end}
dofile('server/services/metadata.lua')
local def=WeaponDefinitionCatalog.weapons.revolver_cattleman
local value=WeaponMetadata.Build(def,{serialNumber='FW-NATIVE-ONLY'})
assert(value.ok and value.value.ammo.ownership=='character' and value.value.ammo.loaded==nil)
for _,key in ipairs({'loadedAmmo','reserveAmmo','chambered'}) do
 local options={serialNumber='FW-NATIVE-ONLY'}; options[key]=0
 assert(not WeaponMetadata.Build(def,options).ok)
end
local metadata=value.value
metadata.ammo={type='ammo_revolver_regular',loaded=0,reserve=0,chambered=false}
assert(not WeaponMetadata.Validate(metadata,def).ok and metadata.ammo.ownership==nil,'old document is refused, not converted')
Config.CharacterAmmunitionEnabled=false; Config.CharacterAmmoTransportEnabled=false
assert(not WeaponMetadata.Build(def,{serialNumber='FW-NATIVE-ONLY'}).ok,'flags off cannot create old metadata')
print('Native-only metadata PASS (native documents, no old ammo fields/import/projection, no disabled-gate fallback)')
