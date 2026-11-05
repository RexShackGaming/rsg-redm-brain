# Five throwable positions

Hawkmoth manual lifecycle checks passed with lease5/5, release9/9 at34/38/38.
Binding/pickup recovery remain unverified. Improved remains deferred.

Five positions now accommodate all current distinct throwable models together:
Throwing Knives, regular Tomahawk, Ancient Tomahawk, Bolas and Hawkmoth Bolas.
New positions: throwable_quaternary and throwable_quinary. These are persistent
Feather positions sharing RedM's existing wheel, not new native wheel sectors.
Matching-model rejection and native pool verification remain unchanged.

SQL: None. Inventory uses arbitrary named slots; no schema change needed.
Restart Weapons only. Grants: None if previously issued carriers are retained.
Equip Ancient and regular Bolas without unequipping the existing three models.

Checks:
1. All five carriers visible in the Weapons menu and native wheel; cycle each.
2. F8 weaponruntime: all five owned; loaded pools agree with approved metadata.
3. Server WeaponMetadataInspect 1: new positions present, runtimeMatch=true.
4. Server WeaponDualSlotContractSmokeTest 1, WeaponRuntimeLeaseSmokeTest 1,
   WeaponReleaseContractSmokeTest 1: all PASS; counts34/38/38 unchanged.
5. Restart Weapons; all five restore with identical serials and quantities.
6. Logout/reconnect; all five restore. Repeat metadata and runtime snapshots.
7. Unload one new-slot carrier: exact return, no duplicate; other pools unchanged.
8. Unequip/re-equip it: other four stay present; no slot-occupied error.

Do not assume zero saved quantity guarantees wheel visibility. Load retained ammo
through the menu if a carrier is empty. Do not issue duplicate carriers merely
to fill positions. Lua regression checks were added but not executed locally.
