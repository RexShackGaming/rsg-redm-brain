# Standard Camera live gate

2026-10-20 native-only port: original equipment-only evidence below is reusable.
Strict Standard Camera profile and fourth-slot ownership/transition integration
implemented under default0 feather_native_camera;197 Weapons Lua specs/full Inventory
suite pass. Scoped live new-port equipment gates passed2026-10-20: issued175/replay,
four-utility coexistence, exact cleanup/menu re-equip, prepared restart, death/doctor
and new-session restoration; four drawable and John/Jane ammo/wear preserved.
See native-camera-alpha-gate.md; no repeated issuance/test requested.
Historical instructions below are not native-only deployment commands; do not
assume historical item133 is currently owned by John.

utility_camera / weapon_kit_camera / WEAPON_KIT_CAMERA.
Fourth logical utility position: utility_quaternary -> weapon_utility_quaternary.
No ammo, film item, unlock writes, custom camera controls or photo storage added.
Scope confirmed by user: Weapons owns the equipment carrier and persistence only.
Camera controls, viewfinder, shutter and photo saving belong in a separate optional add-on.
Native wheel position remains engine-controlled. Photo saving is not promised by ownership.
Expected catalog: 44 weapons / 43 ammunition / 38 attachments.

1. Apply sql/add_camera.sql, reload Inventory definitions and deploy/restart Weapons.
2. grantweapon utility_camera 2 (use current player server ID).
3. Equip alongside Binoculars, Davy Lantern, one Lasso, all four melee and existing throwables.
4. Check both wheel pages/cycle items; confirm every previous carrier remains accessible.
5. Test camera view, available controls, exit and switching to Binoculars, Lantern, each melee, firearm and unarmed. Report shutter/photo behavior separately; do not infer photo persistence from a shutter animation.
6. Confirm no stuck view/light, no holder consumption, no ammo-management entry or changed existing ammo quantities.
7. Unequip/re-equip Camera, restart twice and reconnect. Confirm equipped state/serial persists.
8. WeaponMetadataInspect 2, WeaponRuntimeLeaseSmokeTest 2, WeaponReleaseContractSmokeTest 2; capture client weaponruntime and wheel screenshot.

Equipment/wheel/coexistence acceptance passed, reported by tester on 2026-10-02.
Screenshot confirms Items wheel / Kit / Camera (2 of 2 alongside Binoculars).
Tester confirms Camera equips without disturbing the rest of the loadout, but no
camera controls are available by default. This is acceptable for the Weapons scope;
photography functionality is not claimed or implemented here.
Follow-up source=3 server results confirm Camera item 133, serial
FW-CAME-6AC097F2-28FAEF-0001, restored in utility_quaternary with zero ammo,
generation 4 and runtimeMatch=true alongside the complete 20-slot equipped loadout.
Lease checks passed 5/5 (utility/Lasso); release checks passed 9/9 with
44 weapons / 43 ammunition / 38 attachments. This supports restored equipment
persistence; the attachment does not contain a trace of each requested restart.
Camera is accepted within the equipment-only Weapons scope, not as a photography implementation.
Static contracts pass; Lua regression execution unavailable locally.
