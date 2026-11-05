# Standard Fire Bottle live gate

Accepted: WEAPON_THROWN_MOLOTOV / AMMO_MOLOTOV. Native capacity probe confirmed maximum/current eight. Manual checks passed; final metadata is zero after unload and a second unload is unavailable. Lease 5/5, dual-slot 17/17, release 9/9 at 38/42/38 and ten active slots. No volatile variant or custom projectile recovery. Improved ammunition and cosmetics remain deferred.

Restart regression: initial snapshots were sent during yielding bootstrap rehydration and omitted later slots. Client-ready now waits for startup bootstrap completion. Two successive live restarts restored the same Fire Bottle instance with seven saved/native bottles, without re-equipping.

Ninth logical position: throwable_nonary / weapon_throwable_nonary. Inventory named-slot persistence needs no schema migration. Recipe and Weapons install seeds include both items; existing installs use sql/add_fire_bottle.sql.

1. Stop Weapons then Inventory, apply SQL and deploy code; start Inventory then Weapons.
2. Server: grantweapon throwable_molotov 1. Chat: /AddItems ammo_molotov 10.
3. Equip beside all eight current carriers. Confirm nine entries coexist; native wheel order need not match persistent logical slots.
4. Load eight, leaving two in Inventory. Run weaponthrowablecapacity throwable_nonary; report maximum/current. Stop if different from eight.
5. Throw one in a clear test area, away from people and structures: saved/native seven, other pools unchanged. Switch using Tab hover/release and tap Tab to holster; report unexpected consumption.
6. Restart/reconnect; serial, slot and seven remaining must persist.
7. Unload seven: Inventory nine. Repeat unload: nothing returned.
8. Server: WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1, WeaponDualSlotContractSmokeTest 1, WeaponReleaseContractSmokeTest 1. Client: weaponruntime. Catalog expected 38/42/38; smoke checks 5/5, 17/17, 9/9.

Optional failure injection: reload eight, run weaponthrowablepoolfailure throwable_nonary; approved ownership must persist and unload return eight once.
