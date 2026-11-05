dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
Config={CharacterAmmunitionEnabled=false,CharacterAmmoTransportEnabled=false}
dofile('shared/character_ammunition_activation.lua')
local providerReady=false
WeaponCharacterAmmoInventoryProvider={Status=function() return providerReady and 'ready' or 'dormant' end}
CoreAdapter={ResolveSession=function(source)
    assert(source==1); return {ok=true,value={characterId='Jane',sessionId='current'}}
end}
dofile('shared/definitions/ammunition.lua'); dofile('shared/definitions/weapons.lua')
dofile('shared/character_ammunition_catalog.lua'); dofile('shared/character_ammunition_policy.lua')
local calls,captured=0,nil
WeaponCharacterAmmoService={}
WeaponCharacterAmmoDispatch={New=function()
    return {Start=function(source,catalog,limits)
        calls=calls+1; captured={catalog=catalog,limits=limits}
        assert(source==1 and limits.ammo_pistol_regular==100 and limits.ammo_shotgun_slug==60)
        catalog.weapons.pistol_m1899.label='mutated snapshot'
        limits.ammo_pistol_regular=999
        return {ok=true}
    end,Forget=function() end,Status=function() return nil end}
end}
AddEventHandler=function() end
dofile('server/services/character_ammunition_dispatch.lua')
for _,flags in ipairs({{false,false},{true,false},{false,true}}) do
    Config.CharacterAmmunitionEnabled,Config.CharacterAmmoTransportEnabled=table.unpack(flags)
    assert(not WeaponCharacterAmmoDispatcher.Start(1).ok and calls==0)
end
Config.CharacterAmmunitionEnabled,Config.CharacterAmmoTransportEnabled=true,true
assert(not WeaponCharacterAmmoActivationOwner.Ready(1,{characterId='Jane',sessionId='current'}).ok
    and calls==0,'native provider barrier precedes Core/loadout activation')
local label=WeaponDefinitionCatalog.weapons.pistol_m1899.label
assert(WeaponCharacterAmmoDispatcher.Start(1,{}, {ammo_pistol_regular=999}).ok)
assert(calls==1 and WeaponDefinitionCatalog.weapons.pistol_m1899.label==label
    and WeaponCharacterAmmoPolicy.Limits().ammo_pistol_regular==100)
assert(WeaponCharacterAmmoDispatcher.Start(1).ok and calls==2)
WeaponDefinitionCatalog.ammunition.ammo_new={id='ammo_new',nativeAmmoName='AMMO_NEW'}
table.insert(WeaponDefinitionCatalog.weapons.pistol_m1899.ammunitionTypes,'ammo_new')
local refused=WeaponCharacterAmmoDispatcher.Start(1)
assert(not refused.ok and refused.error.code=='missing_or_invalid_policy_limit' and calls==2)
WeaponCharacterAmmoPolicy.Build=function() error('unavailable') end
assert(WeaponCharacterAmmoDispatcher.Start(1).error.code=='approved_policy_unavailable' and calls==2)
providerReady=true; Config.NativeAlphaRuntime=true; Config.DevMode=true
Config.NativeAlphaCharacterId='foreign'
assert(WeaponCharacterAmmoActivationOwner.Ready(1,{characterId='Jane',sessionId='current'}).error.code
    =='approved_policy_unavailable' and calls==2,'old test allowlist does not restrict another current character')
Config.NativeAlphaCharacterId='Jane'
assert(WeaponCharacterAmmoActivationOwner.Ready(1,{characterId='Jane',sessionId='current'}).error.code
    =='approved_policy_unavailable' and calls==2,'matching scope reaches authoritative policy validation')
print('production dispatcher canonical policy PASS (gates, caller override ignored, snapshot isolation, missing-policy refusal)')
