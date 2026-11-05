# Binoculars and combined melee/utility live gate

2026-10-20 native-only port: original gameplay evidence below is reusable.
A strict Standard Binoculars profile and third-slot Inventory/collection/transition
integration are implemented under default0 feather_native_binoculars;193 Weapons Lua
specs and full Inventory suite pass. Scoped new-port ownership gates passed
2026-10-20: issued174rev0/replay, coexistence beside172/173, isolated cleanup/menu
re-equip, prepared restart, death/doctor and normal new-session restoration.
All three drawable; John ammo/wear and Jane observer baseline preserved.
See native-binoculars-alpha-gate.md for gate-off deployment/read-only baseline.
Commands below are historical,
not native-only port instructions; do not reuse historical item128 as current ownership.

Candidate: utility_binoculars / weapon_kit_binoculars / WEAPON_KIT_BINOCULARS.
Third persistent utility slot: utility_tertiary -> weapon_utility_tertiary.
No ammo or custom viewing controls. Existing maintenance contract is retained.
Logical utility/melee/throwable slots are persistence positions, not forced native wheel positions.
Tester observed Lasso bottom-left throwable and Davy Lantern bottom-right melee.
Expected catalog: 43 weapons, 43 ammunition, 38 attachments.

1. Apply sql/add_binoculars.sql, reload Inventory definitions and deploy/restart Weapons.
2. Grant utility_binoculars, melee_knife, melee_machete, melee_cleaver and melee_hatchet if not already owned.
3. Equip all four melee, one Lasso, Davy Lantern, Binoculars and existing throwables together.
4. Check every wheel page and cycle all options. Confirm each melee is selectable; capture any hidden/replaced entry.
5. Use Binoculars and verify viewing/zoom and exit; switch to Lantern, Lasso, each melee, firearm and unarmed. Confirm no stuck view or lighting.
6. Confirm ammo-free items absent from ammo management, all holders remain owned, and existing ammo quantities unchanged.
7. Unequip/re-equip Binoculars; restart twice and reconnect. Confirm all carrier IDs/serials and equipped states persist.
8. Run WeaponMetadataInspect 2, WeaponRuntimeLeaseSmokeTest 2, WeaponReleaseContractSmokeTest 2 and client weaponruntime. Replace 2 with current server ID.

Live acceptance passed on 2026-10-02: tester reported all combined manual checks passed.
Screenshot confirms Items wheel / Kit / Binoculars. Server metadata confirms
Binoculars item 128 (FW-BINO-6AC0943E-A51247-0001), Reinforced Lasso 125,
Davy Lantern 127 and all four melee carriers 129-132 with runtimeMatch=true,
zero saved ammo and client nativeOwned=true. Regular/Poison knife pools remain 8/8.
Lease checks passed 5/5; release checks passed 9/9 with 19 active slots and
43 weapons / 43 ammunition / 38 attachments.
Viewing, switching, every melee's wheel access and restart/reconnect behavior are
tester-reported; snapshots do not independently demonstrate every transition.
Cleaver/Hatchet clip queries returned false, which alone does not fail ammunition-free equipment.
Static contracts pass; Lua regression execution unavailable locally.
