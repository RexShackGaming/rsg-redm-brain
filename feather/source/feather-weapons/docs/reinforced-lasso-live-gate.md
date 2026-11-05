# Reinforced Lasso live gate

2026-10-20 native-only port: original tester-reported rope/release/switch gameplay
below is reusable evidence, not a reason to repeat those mechanics. New two-slot
identity/ownership/transition policy preserves existing item/native/slot names and
requires explicit unequip before switching. Conflicting saved assignments now fail
closed; no automatic clearing/reconciliation is restored. Independent replicated
feather_native_lasso_reinforced defaults0 and requires existing utility admission.
Automated current-port tests pass. As of 2026-10-20, scoped native-only issuance/
replay, family conflict refusal, explicit switching, exact cleanup, Inventory menu
equip/slot display, Weapons restart, death seal/doctor and normal new-session
restoration are live accepted. John172rev0 is the reinforced carrier; last observed
ledger16/Tomahawk1 and firearm155rev4/158rev5. This is not broad crash/production
acceptance. Numbered commands below are
historical, NOT deployment or grant instructions for this native-only port.

Candidate: utility_lasso_reinforced / weapon_lasso_reinforced / WEAPON_LASSO_REINFORCED.
The second utility slot maps to Inventory weapon_utility_secondary; automatic equip uses either free utility slot.
Policy: only one Lasso-family carrier can be equipped at a time. Unequip before switching.
Previously saved dual-Lasso loadouts restore the first valid carrier in loadout order;
the conflicting equipment assignment is cleared by reconciliation, not the owned item.
Regular wheel suppression with both equipped was observed, despite both reporting native ownership.
Both lassos are reusable, ammunition-free carriers. No unlock writes or custom rope mechanics.
Native identifier reference: https://github.com/femga/rdr3_discoveries/blob/master/weapons/weapons.lua
Expected catalog: 41 weapons, 43 ammunition, 38 attachments.

1. Apply sql/add_reinforced_lasso.sql, reload Inventory definitions and restart Weapons.
2. Keep Standard Lasso equipped; attempt Reinforced and confirm rejection without losing either owned item.
3. Unequip Standard, equip Reinforced, rope/release an NPC and switch weapons. Repeat the switch back to Standard.
4. Confirm neither carrier is consumed or appears in ammunition management. Check all existing quantities remain unchanged.
5. Restart Weapons twice and reconnect. Confirm exactly one Lasso is equipped and both owned item identities/serials persist.
6. Run WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1 and WeaponReleaseContractSmokeTest 1. Run client weaponruntime and share outputs.

Live acceptance passed: tester reported the one-Lasso policy manual checks passed on 2026-10-02.
Attached source=2 results confirm Standard Lasso item 124 in utility, utility_secondary empty,
all ten throwables intact, lease checks 5/5 and release checks 9/9 with 13 active slots.
Catalog counts confirmed: 41 weapons, 43 ammunition, 38 attachments.
Switching, rejection, owned Reinforced carrier retention and restart/reconnect behavior
are tester-reported; the final server snapshot does not independently show those transitions.
Static contract checks cover slot/seed/catalog wiring; Lua runtime regression execution remains unavailable locally.
