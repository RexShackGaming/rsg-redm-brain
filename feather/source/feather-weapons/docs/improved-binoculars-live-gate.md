# Improved Binoculars live gate

2026-10-31 scoped new-port live gate accepted: item226 rev0 issuance/replay,
sixth equip/isolated removal/menu indicator, resource restart, death/doctor recovery
and fresh John session all confirmed with all six utilities selectable/drawable.
John ledger16 and maintenance unchanged; Jane observer ledger35 and maintenance
unchanged. See native-improved-binoculars-alpha-gate.md. Earlier pending notes
below are historical; broader production acceptance remains pending.

2026-10-31 native-only integration complete under default0
feather_native_binoculars_improved. Strict profile now manifest-loaded; sixth-slot
read/commit/lease/native parent, coordinator/menu/status and existing per-player
localized Utility6 display wired.205 Weapons Lua specs/full Inventory suite/Node
tests/changed UI lint/build pass. New-port live gates pending; see
native-improved-binoculars-alpha-gate.md for exact deployment mappings and first
gate-off baseline. Earlier staged notes below are historical, not current requests.

2026-10-31 staged ownership update: guarded sixth-slot projection/lease, Inventory
owned read/conditional commit/export, and native parent current-gate binding are
implemented.205 Weapons Lua specs/full Inventory suite pass, including six-child
failure/death cleanup barriers and paired-binocular identity checks. Strict profile
is still OUT of manifest; concrete adapter model case/server/menu/status wiring
and new-port live acceptance pending. No partial deployment or flags/grant requested.

2026-10-31 native-only port: original coexistence/viewing evidence below is reusable.
Strict Improved Binoculars-only profile staged in
shared/native_improved_binoculars_policy.lua;202 Weapons Lua specs pass.
It is NOT manifest-loaded or runtime admitted. Canonical family remains binoculars
with a separate planned carrier group and original weapon_utility_senary mapping.
Sixth-slot ownership/transaction/menu integration and live gates remain pending.
No deployment, flags, configuration or grant requested for this inert slice.
Commands/item138 below are historical, not current native-only instructions.

Definition utility_binoculars_improved; item weapon_kit_binoculars_improved;
native WEAPON_KIT_BINOCULARS_IMPROVED. Reuses utility_senary / weapon_utility_senary.
Expected catalog: 47 weapons / 43 ammunition / 38 attachments.
No ammunition, unlock changes or custom gameplay controls. Live accepted: user confirmed all manual checks; native wheel label Refined Binoculars. Item 138 metadata matches runtime, nativeOwned=true; 23 active slots, lease 5/5 and release 9/9 passed.

1. Apply sql/add_improved_binoculars.sql, refresh Inventory definitions and deploy Weapons/Recipe changes.
2. grantweapon utility_binoculars_improved 1 (substitute current server ID).
3. Equip with standard Binoculars, one Lasso, Davy Lantern and both cameras; confirm sixth utility slot.
4. Check Items wheel Kit category; test whether both Binoculars remain selectable. Capture native label.
5. Draw, try native viewing controls, switch/holster. Confirm no dropped equipment or suppressed unrelated carriers.
6. Confirm no ammo-management entry or altered ammo totals.
7. Unequip/re-equip; restart Weapons twice and reconnect. Confirm same carrier identity/serial and loadout.
8. Run WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1, WeaponReleaseContractSmokeTest 1 and client weaponruntime.

If missing from the wheel, test once with standard Binoculars unequipped and report the difference.
Do not treat nativeOwned=true or clipOk as functional acceptance for ammunition-free equipment.
