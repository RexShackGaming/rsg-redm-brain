# Ironspiked Bolas live gate

Status: accepted. Manual lifecycle checks passed; native maximum/current confirmed at three; release-contract rerun passed 9/9 with 35/39/38 definitions. Cosmetics and Improved ammunition remain deferred.

Adds WEAPON_THROWN_BOLAS_IRONSPIKED with AMMO_BOLAS_IRONSPIKED, and a sixth persistent logical throwable position (throwable_senary). The three-item ceiling is verified on the target build. The supplied wheel screenshot displays Gravesend Bolas at 3/3; catalog and seed display labels now match. Internal definition, item and native identifiers remain ironspiked to preserve existing ownership.

Reported results: six distinct equipped carriers pass metadata inspection; lease checks 5/5; dual-slot contract 17/17. Release check initially returned 8/9 solely because its expected counts were still 34/38/38 instead of 35/39/38. Final Ironspiked metadata is zero after the reported manual unload checks.

Apply sql/add_ironspiked_bolas.sql to an existing install. Recipe and install_items.sql include the new rows for fresh installs. Existing Inventory named-slot persistence needs no schema migration.

1. Stop Weapons, stop Inventory, apply SQL, start Inventory, start Weapons.
2. Grant one carrier and five ammunition items. Equip beside the five existing distinct carriers; confirm all six are available in the wheel.
3. Load: expect three saved and two left in Inventory. Query weaponthrowablecapacity throwable_senary; expect native maximum three.
4. Throw one without pickup: expect two saved/native. Confirm other throwable quantities unchanged.
5. Restart/reconnect: confirm serial, slot and remaining quantity persist.
6. Unload the remaining two: expect four in Inventory. Repeating unload must return nothing.
7. Run WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1, WeaponDualSlotContractSmokeTest 1, WeaponReleaseContractSmokeTest 1 and weaponruntime. Expected catalog counts: weapon=35 ammunition=39 attachment=38.

If native application fails or capacity differs, stop and report; unload must conserve approved ownership. Do not treat disappearance as consumption.

Next catalog candidates: Intertwined Bolas, then standard Dynamite and Fire Bottle. Each requires its own capacity/lifecycle gate; Improved variants remain deferred.
