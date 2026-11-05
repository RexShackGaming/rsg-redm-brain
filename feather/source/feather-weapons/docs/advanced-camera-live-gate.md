# Advanced Camera equipment live gate

2026-10-31 scoped native-only equipment gate PASSED with John225rev0:
issuance/replay, five-utility/paired-camera wheel draw, isolated fifth removal,
normal menu equip/English layout, prepared restart, death/doctor and fresh-session
restoration with unchanged John/Jane ammo/wear. See native-advanced-camera-alpha-gate.md.
No repeat native lifecycle tests/grants requested. Separate selected-language UI
live check pending; no photography or broader production acceptance implied.

2026-10-31 integration now complete under default0 feather_native_camera_advanced.
Strict profile is manifest-loaded; fifth-slot runtime/menu/status and current-gate
checks are wired. Equipment UI now resolves text through each player's Core locale
cache selected by feather-settings, reacts to locale changes, and falls back to
English.201 Weapons Lua specs/full Inventory suite/Node tests/touched UI lint/build
pass; live new-port ownership/layout/language checks pending. See
native-advanced-camera-alpha-gate.md for exact runtime source/destination mappings
and first gate-off deployment. Earlier staged notes below are historical.

2026-10-31 staged Inventory/native layer: exact fifth-slot reader/conditional commit,
separate camera carrier groups, independent commit/current-gate checks and five-child
session/lease/parent cleanup barriers implemented. Concrete adapter Advanced GUID
mock and fifth factory/create/cleanup/gate-loss cases pass;201 Weapons Lua specs and
full Inventory Lua suite pass. Profile still OUT of manifest; localized menu and
server route/status admission pending. No partial deployment or live commands.

2026-10-31 staged projection update: guarded catalog/fifth-slot approval, collection
coexistence and exact lease holds are implemented;199 Weapons Lua specs pass.
Standard/Advanced retain canonical camera family with distinct trusted carrier
groups. The Advanced profile is still NOT manifest-loaded. Inventory/native-owner/
localized-menu integration and live gates remain pending; no partial deployment,
convar enabling or grant requested.

2026-10-31 native-only port: original paired-camera evidence below is reusable.
Strict Advanced Camera-only profile staged in shared/native_advanced_camera_policy.lua;
198 Weapons Lua specs pass. NOT manifest-loaded or runtime admitted; fifth-slot
ownership/transition/UI integration remains pending. Canonical camera family is
preserved with a distinct planned carrier ownership group, allowing coexistence.
New player-facing UI must follow the player's feather-settings-selected language.
No deployment, convars, config changes or grant requested for this inert slice.
Commands/item IDs below are historical, not current native-only test instructions.

utility_camera_advanced / weapon_kit_camera_advanced / WEAPON_KIT_CAMERA_ADVANCED.
Fifth logical utility position: utility_quinary -> weapon_utility_quinary.
Equipment ownership, equip and persistence only. No photography controls or storage integration.
No ammunition, film, unlock writes or forced wheel placement.
Expected catalog: 45 weapons / 43 ammunition / 38 attachments.

1. Apply sql/add_advanced_camera.sql, reload Inventory definitions and deploy/restart Weapons.
2. grantweapon utility_camera_advanced 3 (replace with current server ID).
3. Equip alongside Standard Camera, Binoculars, Davy Lantern, one Lasso, four melee and all existing throwables.
4. Cycle both wheel pages. Confirm both cameras and all prior carriers remain selectable; report any suppression.
5. Draw/holster and switch between cameras, Binoculars, Lantern, melee, firearm and unarmed. No photography functionality is required for acceptance.
6. Confirm holders persist, no ammo-management entry, no stuck state or unintended ammo changes.
7. Unequip/re-equip Advanced Camera, restart twice and reconnect. Confirm both Camera IDs/serials persist.
8. WeaponMetadataInspect 3, WeaponRuntimeLeaseSmokeTest 3, WeaponReleaseContractSmokeTest 3; client weaponruntime and wheel screenshot.

Equipment wheel/metadata checks passed: supplied screenshot confirms Kit / Advanced Camera
and server/client snapshots confirm item 134 (FW-CAME-6AC0A4BD-5A63C5-0001)
coexisting with Standard Camera item 133, runtimeMatch=true and nativeOwned=true.
Lease checks passed 5/5 and release checks 9/9. Subsequent restart metadata retains
both serials. Photography remains explicitly outside Weapons scope.
Snapshots do not independently demonstrate every manual switch transition.
Static contracts pass; Lua regression execution unavailable locally.
