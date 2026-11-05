# Hammer live gate

melee_hammer / weapon_melee_hammer / WEAPON_MELEE_HAMMER.
Fifth logical melee position: melee_quinary -> weapon_melee_quinary.
No ammunition, custom damage, unlock writes or forced native wheel placement.
Identifier reference: https://github.com/Rexshack-RedM/rsg-weapons/blob/main/config.lua
Expected catalog: 46 weapons / 43 ammunition / 38 attachments.

1. Apply sql/add_hammer.sql, reload Inventory definitions and deploy/restart Weapons.
2. grantweapon melee_hammer 3 (use current server ID).
3. Equip alongside all four existing melee, Davy Lantern, one Lasso, Binoculars, both cameras and throwables.
4. Cycle wheel options; confirm Hammer and previous carriers remain selectable.
5. Test draw, swings, holster and switching to unarmed/other equipment; check no native drop or lost ownership.
6. Confirm no consumed carrier, ammo-management entry or unintended ammo changes.
7. Unequip/re-equip, restart twice and reconnect. Confirm carrier identity/serial and full loadout persist.
8. WeaponMetadataInspect 3, WeaponRuntimeLeaseSmokeTest 3, WeaponReleaseContractSmokeTest 3; client weaponruntime and screenshot.

Live accepted: wheel Hammer selectable, item 137 metadata/runtime matched; lease 5/5 and release 9/9. User confirmed all manual checks passed, including lifecycle and coexistence. Lua regression execution unavailable locally.
