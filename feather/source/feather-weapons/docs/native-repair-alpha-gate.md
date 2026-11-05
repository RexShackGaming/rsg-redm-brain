# Disposable alpha repair gate

2026-10-15 live Equipment-menu result: user reports oil removed; status128
revision8/weapon_already_serviced after revision7 dirty preflight. Menu success
message unobserved; no independent final five-field/material audit supplied.
Do not repeat repair or grant oil to recover that message. Subsequent isolation
fix in native_equipment_transition.lua prevents delayed old repair/maintenance
export results from assigning postcommit data to a new same-source request.

## Current gate — 2026-10-15 Equipment-menu repair

This section supersedes the historical deployment/fixture instructions below.
Do not recreate the accepted fixture or replace server config. The only pending
live gate is player-facing repair through Equipment, reusing the accepted transaction.

Copy these existing files from feather-weapons:

- shared/definitions/attachments.lua
- shared/character_attachments.lua
- shared/character_ammunition_materialization.lua
- client/native_equipment_actions.lua
- server/services/native_equipment_transition.lua

Copy from feather-inventory:

- server/services/native_equipment_commit.lua
- client/services/nuicallbacks.lua
- complete rebuilt ui/ folder

PrepareStop with the current player ID, wait PASS, then stop Weapons before
copying. Restart updated Inventory and restore its stopped Admin/Shops dependents.
Merge only `NativeAlphaRepairEnabled = true` in Weapons config, preserving all
other settings, then start Weapons. Existing files only: no refresh needed.
Keep catalog/representative/attachment probes off; repair needs no attachment flags.

First server-console command (replace 2 if current player ID changed):

```text
WeaponNativeRepairStatus 2 128
```

Read-only expected historical snapshot: revision7, condition90, permanent wear
0.1, dirt about0.7; actual output controls the next step. Do not grant oil,
equip, repair or overwrite an old audit baseline until reviewed. Original112
stays pristine/primary. Live Equipment repair remains pending; no repeat of
accepted console repair/native-proof matrices. Automated 120 Weapons Lua specs,
7 Node tests, Inventory suite, UI lifetime tests, lint and build passed.

User authorized one disposable worn Cattleman and exactly one gun oil on Jane.
Original item112 metadata/serial/ownership remain unchanged. Its primary assignment
is temporarily replaced during the gate and restored afterward. No ammunition
grant, load/unload or shot is required. Database rebuilds flush this fixture and
its receipt; do not reuse an audit file from the old database.

## Runtime files to copy

From **feather-weapons**:

- `config.lua` (preserve server-local settings; new `NativeAlphaRepairEnabled=false` initially)
- `fxmanifest.lua`
- `shared/character_maintenance.lua`
- `shared/character_ammunition_materialization.lua`
- `client/character_maintenance_native.lua`
- `client/character_ammunition_creation_native.lua`
- `client/character_ammunition_native_owner.lua`
- `client/character_ammunition_startup.lua`
- `server/services/native_equipment_transition.lua`

From **feather-inventory**:

- `server/services/native_equipment_commit.lua`
- `server/services/native_repair_commit.lua`
- `server/services/native_repair_verify.lua`
- `server/services/native_repair_audit.lua`
- `server/services/native_repair_fixture.lua`

Do not move tests/docs/UI. Run server-console `refresh` before restarting; this
bundle adds a manifest entry and Inventory service-glob scripts.

## Stage 1: fixture only

Keep Weapons and native-proof stopped. Inventory `CharacterAmmunitionEnabled`
must be false during the fixture grant, as in the completed offline verifier.
Restart updated Inventory and restore Shops once. Jane must be logged in.
Use the current server ID, not an old ID from the transcript.

```text
refresh
ensure feather-inventory
ensure feather-shops
set feather_jane_repair_fixture 1
InvJaneRepairFixture <CURRENT_ID> 6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb
set feather_jane_repair_fixture 0
```

Stop here and return the PASS/REFUSED output. PASS includes `fixtureId`, `oilId`
and `fixtureRevision`; do not guess IDs. A replay returns historical delivery
without issuing another weapon or oil. Fresh grant requires the accepted
ledger25/carried0/loose2/item112revision1 primary baseline. A refusal must be
investigated, not bypassed with a generic grant.

## Remaining batch (after fixture PASS)

Enable the existing scoped native flags and `NativeAlphaRepairEnabled=true`
once; leave them enabled throughout the batch. Restart Inventory/Shops and start
Weapons in the normal scoped configuration. No native-proof run is needed.

1. Unequip original primary, then equip the fixture as primary using the existing
   conditional equipment coordinator; confirm a single holstered fixture.
2. Run client `weaponNativeMaintenanceStatus`: fixture must read degradation0.5,
   permanent0.1, damage0.5, dirt0.7, soot0.3. Stop on refusal/mismatch.
3. Server `InvNativeRepairAudit <ID> <JANE_UUID> <FIXTURE_ID> capture` must PASS.
   Keep `.native-repair-audit-<uuid>.json` in the Inventory resource; no overwrite.
   If persistence is refused, do not repair or delete/rewrite the file. Use
   `inspect` mode to validate any retained baseline against pre-repair SQL state.
   Save diagnostics distinguish acknowledgement and exact file-readback failure.
   If post-repair verify reports changed equipment or readback has zero copies,
   stop the gate. `diagnose` mode reports baseline/current assignments, target wear/
   revision, material count and original/ammo preservation without changes. Do not
   regrant, recharge, overwrite the baseline or claim the previous coordinator PASS
   proves full repair acceptance. Transaction/rebuild equipment postconditions now
   reject assignment loss rather than accepting an empty ACTIVE loadout.
4. Server `WeaponNativeRepair <ID> <FIXTURE_ID>` must PASS after release/payment/
   metadata CAS/fresh restore. It consumes one gun oil, never ammunition.
5. Client `weaponNativeMaintenanceStatus` must show permanent/degradation/damage0.1,
   dirt/soot0; durable fixture condition should be90. Confirm one holstered copy.
6. Server audit `verify` must PASS: one item revision increment, exact oil
   consumption, unchanged equipment/other items/all ammo ledgers and receipts.
7. At zero carried ammo, restart Weapons once. Preserve the audit file and do not
   rebuild the database. Repeat only maintenance readback and audit `verify` to
   prove this new repair persistence path. No repeated family/equipment test matrix.
8. Restore primary item112 using the coordinator after final audit; this equipment
   change is intentionally outside the repair comparison. Keep the disposable
   repaired fixture unequipped until the alpha flush; do not add a broad cleanup
   command. Disable repair/native gates once at the end as appropriate.

No live fixture grant, native readback or repair acceptance has occurred yet.
Automated tests cover mocked transaction/native/file boundaries, not the server.
# Player-facing repair preparation: material quantity preflight

Native console repair remains gated/off by default; next slice is Inventory UI.
Before exposing it, ReadNativeRepairMaterial now returns own-inventory quantity
using SELECT-only reads with post-yield session checks. Weapons refuses zero,
insufficient, noninteger/nonfinite or missing quantity before native release.
Existing transaction still locks/rechecks/consumes material and CASes metadata;
preview is not payment authority or guarantee against later contention. Tests
cover missing/NaN oil with no release/write and Inventory reader current/caller/
invalid quantity checks. Full Inventory Lua runner and119 Weapons Lua specs pass.
No new material grant/live test or repair-enable change. Staged matching files:
Inventory server/services/native_equipment_commit.lua and Weapons
server/services/native_equipment_transition.lua; deploy together in next batch.
Player-facing repair menu/intent integration still pending. Existing accepted
repair economic/native reconstruction evidence is retained, not reopened.

