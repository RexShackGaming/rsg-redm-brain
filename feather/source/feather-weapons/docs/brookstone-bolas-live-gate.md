# Brookstone Bolas live gate

Accepted: WEAPON_THROWN_BOLAS_INTERTWINED / AMMO_BOLAS_INTERTWINED. Target-build wheel screenshot confirms Brookstone Bolas at 3/3; capacity probe confirms maximum/current three. User reports manual checks passed.

Acceptance evidence: all seven carriers pass metadata inspection; Brookstone saved/native totals both two after throwing one, with other pools unchanged. Lease checks 5/5, dual-slot contract 17/17, release contract 9/9 at 36/40/38 definitions and seven active slots. Optional simulated-failure check was not separately reported.

Seventh logical position: throwable_septenary, persisted as weapon_throwable_septenary. All four Bolas variants can coexist with knives and both Tomahawks. No Inventory schema migration.

Existing-install migration: sql/add_brookstone_bolas.sql. Recipe and Weapons install seeds include the two rows. Catalog now 36 weapons / 40 ammunition / 38 attachments.

1. Stop Weapons then Inventory; apply SQL and deploy; start Inventory then Weapons.
2. Server console: grantweapon throwable_bolas_intertwined 1. Player chat: /AddItems ammo_bolas_intertwined 5.
3. Equip in seventh position beside the six existing carriers; confirm all seven remain available, and screenshot the new wheel label.
4. Load three, leaving two in Inventory. Run weaponthrowablecapacity throwable_septenary; report native maximum and current.
5. Throw one without pickup: two remaining; unrelated pools unchanged. Restart/reconnect and confirm serial, slot and quantity persist.
6. Unload two: Inventory four. Repeat unload: nothing returned. Optionally reload three, simulate weaponthrowablepoolfailure throwable_septenary, inspect approved metadata, then unload; all three must return once.
7. Run WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1, WeaponDualSlotContractSmokeTest 1, WeaponReleaseContractSmokeTest 1 and client weaponruntime. Expected contract results: 5/5, 17/17, 9/9.

Stop if native application fails or capacity differs; preserve approved ownership and unload rather than treating disappearance as consumption.

Sources: https://github.com/femga/rdr3_discoveries/blob/master/weapons/weapons.lua and https://github.com/femga/rdr3_discoveries/blob/master/weapons/ammo_types.lua .

After acceptance, continue with standard Dynamite and Fire Bottle families. Improved ammunition and cosmetics remain deferred.
