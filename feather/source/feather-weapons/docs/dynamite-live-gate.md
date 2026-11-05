# Standard Dynamite live gate

Accepted standard lifecycle: WEAPON_THROWN_DYNAMITE / AMMO_DYNAMITE. Wheel screenshot confirms 8/8; user reports manual checks passed. Isolated placement decreases saved/native four to three with other pools unchanged. Tab tap holsters; hover/release switches; clicking places a stick and draws another. Placement is consumption, with no custom recovery. No volatile variant, unlock changes or cosmetics.

Eighth persistent logical position: throwable_octonary / weapon_throwable_octonary. All seven accepted carriers can coexist. Inventory named-slot persistence requires no schema migration.

Recipe and Weapons install seeds include carrier and ammunition; existing installs use sql/add_dynamite.sql. Catalog expected: 37 weapons / 41 ammunition / 38 attachments.

1. Stop Weapons, then Inventory. Apply SQL and deploy updated code. Start Inventory, then Weapons.
2. Server: grantweapon throwable_dynamite 1. Player chat: /AddItems ammo_dynamite 10.
3. Equip in eighth position; verify wheel coexistence with all seven accepted carriers.
4. Load eight, leaving two in Inventory. Run weaponthrowablecapacity throwable_octonary. Report native maximum/current; stop if different from eight.
5. In a clear test area, throw one and let it detonate. Expect seven saved/native, unrelated pools unchanged. Do not use pickups for this gate.
6. Restart/reconnect; confirm serial, slot and remaining seven persist.
7. Unload seven: Inventory nine. Repeating unload returns nothing.
8. Server: WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1, WeaponDualSlotContractSmokeTest 1, WeaponReleaseContractSmokeTest 1. Client: weaponruntime. Expected 5/5, 17/17, 9/9.

Native application failure must preserve approved ownership for unload. Optional failure test: reload eight; weaponthrowablepoolfailure throwable_octonary; inspect metadata and unload, returning eight once.

Next family: standard Fire Bottle. Improved/volatile variants and cosmetics remain deferred.
