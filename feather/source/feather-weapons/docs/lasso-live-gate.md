# Standard Lasso live gate

2026-10-20 native ownership port evidence: reuse the 2026-10-02 tester-reported
rope/release/switch/nonconsumption gameplay acceptance below. The current native
path retains WEAPON_LASSO and the zero-ammo grant behavior; it does not add custom
rope mechanics. Current item171rev0 (not historical item124) passed issuance replay,
exact GUID cleanup, normal-menu re-equip, post-restart restoration, death/doctor,
normal logout/relogin and unchanged observer checks on Oct19-20. No gameplay rerun
is required solely for this port. The numbered commands below are HISTORICAL,
not deployment or grant instructions for the current native-only system. Broader
crash/multiplayer transfer and other utility models are not accepted by this gate.

Candidate: `utility_lasso` / `weapon_lasso` / `WEAPON_LASSO`.
Dedicated `utility` equipment slot maps to Inventory `weapon_utility`.
No ammunition item, pool or consumption. Uses the existing ammunition-free equipment contract, including its maintenance/repair policy; no custom rope mechanics.
Expected catalog: 40 weapons, 43 ammunition, 38 attachments.

1. Apply sql/add_lasso.sql, reload Inventory item definitions and restart Weapons.
2. Grant one carrier using grantweapon utility_lasso 1, then equip it alongside existing throwables.
3. Check wheel visibility, aim/rope a suitable NPC, release the rope and switch to unarmed/another weapon. Confirm the holder is not consumed.
4. Confirm Lasso is absent from ammunition management and cannot load ammunition.
5. Unequip/re-equip; restart Weapons twice and reconnect. Confirm utility item/serial survives and existing loadout/ammo is unchanged.
6. Run WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1 and WeaponReleaseContractSmokeTest 1; capture weaponruntime client output.

Live acceptance passed, reported by the tester on 2026-10-02 for the checklist above.
Attached server results confirm utility item 124, serial FW-LASS-6AC06B8E-5E4A7F-0001,
zero ammunition and runtimeMatch=true, alongside all ten throwable carriers.
Lease smoke test passed 5/5 against the utility slot; release contract passed 9/9
with 40 weapons, 43 ammunition, 38 attachments and 13 active slots.
Roping, switching and lifecycle checks are tester-reported; the attachment contains
server snapshots, not a client weaponruntime dump or before/after lifecycle trace.
Lua regression cases added to tests/ammunition.lua; local Lua execution unavailable.
