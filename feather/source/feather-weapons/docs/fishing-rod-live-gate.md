# Fishing Rod live gate

2026-10-31 scoped native-only batch live gate COMPLETE: issuance/replay,
isolated removal/menu restore, eight-utility coexistence, shared restart,
death/doctor recovery, fresh session and final ammo/wear/observer checks accepted.
See native-tools-batch-alpha-gate.md. Pending integration notes below are historical.

2026-10-31 native-only batch implemented; new-port live acceptance pending.
Independent default-off gates and Utility7/8 ownership use existing collection
lease/CAS/cleanup. Original gameplay evidence below is reused, not native-only
acceptance. Use native-tools-batch-alpha-gate.md for current deployment/test steps;
historical grant commands below are not the native-only issuance protocol.

utility_fishing_rod / weapon_fishingrod / WEAPON_FISHINGROD.
Eighth utility position: utility_octonary -> weapon_utility_octonary.
Equipment-only scope; bait, fishing controls, catches and rewards belong to an add-on.
Expected catalog: 49 weapons / 43 ammunition / 38 attachments. Live accepted: user confirmed all manual checks. Fishing Rod appears in the Items wheel Hunting category; item 140 serial FW-FISH-6AC17516-C3F034-0001 metadata/runtime matches with native ownership. Server and client show all 25 equipped items; lease 5/5 and release 9/9 passed.

1. Apply sql/add_fishing_rod.sql, refresh Inventory definitions and deploy Weapons.
2. grantweapon utility_fishing_rod 1 (use current source ID).
3. Equip alongside all seven utility carriers, melee weapons and throwables.
4. Check both wheel pages for Fishing Rod; capture native label and check coexistence.
5. Draw, holster, switch to unarmed and other equipment; check no drops/lost ownership.
6. Confirm no ammunition-management entry, consumed carrier or altered existing ammo.
7. Unequip/re-equip, restart twice and reconnect. Confirm serial and full loadout persist.
8. WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1, WeaponReleaseContractSmokeTest 1; client weaponruntime and screenshot.

Successful fishing is not required for this equipment gate. No custom fishing controls or unlock writes are included.
