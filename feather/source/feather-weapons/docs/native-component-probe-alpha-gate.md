# Exact-owned native component probe

2026-10-14 component replacement ROOT CAUSE confirmed live. Draw-only135 entity686082 moved point10→0 preserving readback. Probe install immediate native readback PASS, but subsequent diagnostic found tracked686082 destroyed and new same-model818434 at point0; original112entity685826 unchanged. Exact-owned maintenance correctly refused replacement. Immediate synchronous component presence is insufficient settlement evidence. No removal/visual/economic attachment gate accepted. Temporary in-place component probe removed locally (three client files), read-only entity diagnostic retained with regression test proving replacement is reported and never adopted. Design next: apply canonical compatible components during zero-ammo construction BEFORE final entity settlement/lease registration; verify final component/readback/maintenance on settled created copy, compensate failed creation, no arbitrary live rebind. Same-model GUID pair attachments remain unsupported until exact-copy proof. Transaction integration must validate canonical compatibility/station/authorization/material/full assignment/item revision, release old owner before atomic payment/CAS, reconstruct only committed saved document. No economic attachment route implemented yet. Current server retains destroyed Carbine record; exit RedM then deploy probe cleanup on stopped Weapons and reconnect from durable112/135/ledger33. Do not force release/adopt replacement or invent final wear.

2026-10-14 probe recovery/cleanup confirmed: fresh sessionb3010514-c826-11f1-9ae2-e0d55eaa2deb/source4 restored112rev1/135rev0/allwear0/ledger33/allcarried0. SELECT-only135 verify-wear PASS changedfalse/material0/equip+ammo unchanged; shoulder unequipped, final one active idle copy epoch6412213:2. Probe removal/visual gate remains NOT accepted. Added dev read-only weaponNativeEntityStatus reporting tracked entity/existence and current weapon point model/entity matches plus per-copy underlying maintenance error. No rebinding/adoption/native/SQL writes. Next diagnostic isolates ordinary Carbine draw before component probe; keep probe convar0. Three existing Weapons client files deployment, no refresh. Full Lua suite passes; no economic attachments route.

2026-10-14 probe recovery blocked on current client: after install native PASS, maintenance readback unavailable drawn and holstered; remove guard refused, controlled prepare-stop reported client release refused/ownership retained. Underlying native object/entity failure remains undiagnosed; no visual/removal acceptance. Existing client has no authorized hot-reload route, so local guard fix cannot safely patch retained adapter in place. Recovery plan is complete RedM exit (native world discarded, not cleanup acknowledgment), then stopped-owner Weapons deployment of client/character_ammunition_native_owner.lua and fresh SQL-based reconnect. No adoption/entity rebinding/metadata reset/economic writes. Explicitly no final unreadable wear invented/persisted; last durable snapshot is authority. Do not repeat release/stop on live retained owner. Remaining readback diagnostic/probe removal proof required before economic attachment route.

2026-10-14 live exact-owned component probe install PASS on135rev0 (installedtrue/exactEntity/noSQL/noAmmo). Screenshots do not establish visual difference. Removal REFUSED probe_settled_empty_owner_required despite runtime ACTIVE idle/all carried0/same epoch; independent MaintenanceStatus unavailable maintenance_readback_unavailable while weapon drawn. Probe owner guard unnecessarily coupled component access to all-copy maintenance readback. Local fix uses explicit current session/epoch/world/active idle/ammo flags/zero pools checks without wear getters; exact retained native entity remains enforced by adapter. Full Lua suite passes. Do not restart while installed merely to deploy fix: first holster, retry removal on current build and obtain readback/audit; fix deploy afterward. Visual/removal/durable gate remain pending, no economic attachments enabled.

Prepared 2026-10-14. Attachment cutover economic path is NOT implemented or
accepted. Existing legacy component lifecycle evidence is reused for mappings;
its ped/hash application does not establish exact-copy native ownership.

Temporary default-off F8 weaponNativeComponentProbe install|remove targets only
existing disposable Carbine135rev0 with fixed mixed-fixture serial and fixed Wide
Sight. It requires configured Jane/current active idle owner, empty carried pools,
exact retained entity at a current weapon point, model load bounded100frames and
world/owner checks around every yield/native. No Inventory/SQL/ammo calls or item
grant, payment, attachment metadata change or native loadout adoption. Original112
cannot be targeted. A failure is not compensation/cleanup proof; inspect before
retry. Do not restart/change equipment while probe installed; remove first.

Research reference: https://github.com/femga/rdr3_discoveries/blob/master/weapons/weapon_components.lua
documents entity-targeted give/read/remove component natives. Exact-object behavior
on the target RedM build still requires this live gate. No FiveM/GTA hashes imported.

Deploy Weapons only existing three files:
client/character_ammunition_creation_native.lua
client/character_ammunition_native_owner.lua
client/character_ammunition_startup.lua
No manifest/config changes/refresh. Preserve flags; setr feather_native_component_probe1
only during batch. Prepare-stop current-id/PASS, stop/copy/ensure Weapons; conditional
equip weapon_shoulder135 alongside primary112. Confirm two copies/ledger33/all0.
Preserve completed mixed-slot private audit; capture fresh135 after equip (before
probe) to verify unchanged full items/assignment/ammo after native install/remove.
F8 install; require PASS and visible Wide Sight while primary unchanged. F8 remove;
require PASS/native readback false and standard sight restored. Server SELECT-only
InvNativeRepairAudit current-id Jane135 verify-wear expects changed=false/revision0,
equipment/ammo unchanged/material0. Disable replicated convar then unequip shoulder.
Remove helper after gate. This is native capability only: payment/CAS/gunsmith
authorization, saved-loadout attachment reconstruction, duplicate-pair attachment
isolation and player UI still need implementation/tests before economic rollout.
