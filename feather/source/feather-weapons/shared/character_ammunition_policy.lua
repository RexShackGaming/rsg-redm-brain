-- Alpha ceilings bounded by 2026-10-09 live native pool readbacks.
-- Acceptance evidence, not a claim of universal engine maximum capacity.
-- Per character/native type, loaded rounds included; loose Inventory separate.
-- Explicit IDs: new types require a deliberate policy update, never a fallback.
WeaponCharacterAmmoPolicy={}
local limits={
    ammo_pistol_regular=100,ammo_pistol_express=100,ammo_pistol_high_velocity=100,
    ammo_pistol_split_point=50,ammo_pistol_explosive=10,
    ammo_revolver_regular=200,ammo_revolver_express=200,ammo_revolver_high_velocity=200,
    ammo_revolver_split_point=100,ammo_revolver_explosive=10,
    ammo_repeater_regular=200,ammo_repeater_express=200,ammo_repeater_high_velocity=200,
    ammo_repeater_split_point=100,ammo_repeater_explosive=10,
    ammo_rifle_regular=100,ammo_rifle_express=100,ammo_rifle_high_velocity=100,
    ammo_rifle_split_point=50,ammo_rifle_explosive=10,
    ammo_shotgun_regular=60,ammo_shotgun_slug=60,
    ammo_shotgun_buckshot_incendiary=14,ammo_shotgun_slug_explosive=10,
    ammo_varmint=100,ammo_varmint_tranquilizer=200,ammo_rifle_elephant=20,
}
function WeaponCharacterAmmoPolicy.Limits()
    local copy={}; for id,cap in pairs(limits) do copy[id]=cap end; return copy
end
function WeaponCharacterAmmoPolicy.Build(catalog)
    local registry,why=WeaponCharacterAmmoCatalog.Build(catalog,WeaponCharacterAmmoPolicy.Limits())
    if not registry then return nil,why end
    if WeaponNativeThrowablePolicy and WeaponNativeThrowablePolicy.Enabled() then
        local candidate
        candidate,why=WeaponNativeThrowablePolicy.Preview(catalog,registry)
        if not candidate then return nil,why end
        return candidate.registry
    end
    return registry
end
