# Periodic wear saving — scoped alpha

2026-10-14 abnormal connection recovery hardening implemented/automatically tested, live funded reconnect gate pending. Fresh SQL remains sole reconstruction authority; no intent replay/refund/invented final observation or native adoption/removal. Core-verified new sessions may retire obsolete server holds/openings, dispatcher and equipment/read/UI/periodic/shutdown reservations; same-session frozen/parked state remains blocked. Dispatcher opening binds Core session before SQL yield and matches late cancellations. Transient diagnostics preserve last acknowledged revision/provider outcome without treating it as durable truth; server WeaponNativeRecoveryStatus reports fresh startup/current baseline and four deployment contract markers. Tests cover source reuse, expired vs current holds, late old events/timers/ack, coroutine commit-before-lost-reply and refused writes, no second mutation/rebuild. Full Weapons Lua suite and7 Node checks pass. Five existing Weapons shared/server files only; no new flags/schema/client/UI/other-resource/manifest delta. Last periodic cleanup/original restoration user-confirmed complete. Unreported shots/wear cannot be recovered; real server crash, abrupt funded hot-stop, multiplayer/in-flight live coverage remain separate. Runbook docs/native-disconnect-recovery-alpha-gate.md uses one existing loose round for funded loss/rejoin, no new grant or repeat proof matrix.

2026-10-13 LIVE periodic changed-wear/no-op gate ACCEPTED after corrected deployment: fixed native dirt0.7 on128rev6 saved by automatic timer alone; periodic PASS and maintenance CAS/restore PASS logged. Fresh same-session epoch2 restored128rev7 dirt≈0.7 with other wear unchanged. Server status enabledtrue/60000ms/persisted1/unchanged5/lastOutcomeunchanged establishes a subsequent no-op sample with no second save; Inventory verify-wear PASS revision7/equipmentUnchangedtrue/ammoUnchangedtrue/materialConsumed0. No repeat timer wait/gate needed. Earlier128rev5→6 dirt0.6 was saved by orderly stop during deployment correction and is explicitly NOT timer acceptance. Temporary helper removed locally; four-client-file cleanup deployment and original112 restoration pending. Periodic flag remains enabled/60000 for batch. Abnormal-disconnect/crash reconciliation, general enrollment, broken policy and GUID permanent-wear support remain separate gaps.

2026-10-13 periodic deployment correction: missing startup helper file was corrected, then live dirt0.6 remained128rev5 with no timer save. Server periodic status command was absent; required server files were missing. Safe prepare-stop/redeploy saved that input via accepted stop boundary; restart readback128rev6 dirt≈0.6 is NOT periodic acceptance. Timer gate remains pending. Revised temporary helper now targets exact128rev6 dirt0.6→0.7 (native-only, no grants/economics/original mutation), automatically tested. Confirm installed periodic status command/config before another input, retain old audit and capture freshrev6 baseline. Earlier rev5→6 timer instructions are superseded by this corrected baseline.

2026-10-13: implemented and automatically tested; live acceptance pending.
Default NativeAlphaPeriodicWearEnabled=false. Existing scoped Dev/native/transport
and NativeAlphaMaintenanceEnabled gates are still required. Default interval60000ms,
valid15000–300000. One equipped copy per interval in stable-ID round-robin; four
equipped copies can take up to four intervals. No periodic SQL/epoch/revision churn
for unchanged samples: compare bounded actual readback against retained server
lease metadata before any SQL or release. Copies without readable wear are skipped
through the bounded readback timeout; no synthetic observations or silent retries
of uncertain writes. Busy/sealed/frozen/retiring owners and concurrent intents skip.

Changed wear reuses the accepted maintenance release/CAS/full assignment validation/
fresh same-session restore protocol. This first alpha implementation briefly
reconstructs owned copies on a changed save; it is NOT seamless in-place saving.
Ammo/material economics and assignment do not change. New periodic flag is part
of the reserved root intent and checked at commit. Failed/uncertain transitions
remain frozen, not automatically resumed. A server-only status command reports
epoch, interval, last outcome and unchanged/persisted counts. Counters preserve
same-session epoch changes; late old-epoch reports/session events cannot affect
new work. Arbitrary client events cannot schedule or choose a periodic item.

Full Weapons Lua suite, scheduler/concrete periodic/no-op/release-before-CAS/race
tests and7 Node checks pass. Current-session retained candidate metadata is copied,
not exposed as mutation authority. No Inventory/Medical/Character/Admin/UI/runtime
manifest changes. Abnormal disconnect/crash reconciliation, general enrollment,
broken-weapon policy and GUID permanent-wear support remain separate gaps.

## Exact deployment delta

feather-weapons only, existing files:

```text
server/services/character_ammunition_runtime.lua
server/services/native_equipment_transition.lua
client/character_maintenance_native.lua
client/character_ammunition_creation_native.lua
client/character_ammunition_native_owner.lua
client/character_ammunition_startup.lua
```

Merge these two config entries, preserving all existing server overrides:

```lua
NativeAlphaPeriodicWearEnabled = true,
NativeAlphaPeriodicWearIntervalMs = 60000,
```

Keep NativeAlphaMaintenanceEnabled=true and previously accepted lifecycle flags;
repair/self-kill/helpers remain disabled. Do not replace full config with defaults.
No new runtime file/manifest or refresh required. Prepare-stop current-id, wait
PASS, stop Weapons, copy files/merge config, ensure Weapons. Then conditional
unequip/equip existing fixture128; readback must show128rev5 dirt≈0.5.

## One focused live gate

Retain the completed wear audit by renaming .native-wear-audit-<Jane>.json to
.native-wear-audit-<Jane>.completed-rev5.json before fresh revision5 capture.
No grant, oil, ammo or artificial original112 metadata input. Temporary default-off
helper binds exact Jane/fixture128rev5/fixed serial/current owned entity/zero belt
and changes only native dirt0.5→0.6 with independent unchanged-other-wear readback.
User authorized continuing fixture inputs without repeated approval.

After fresh capture PASS: `setr feather_native_fixture_dirt 1`, client
weaponNativeFixtureDirt, expect native-only PASS, then `setr feather_native_fixture_dirt 0`. Stay alive/in the
same session, leave firearm holstered. Do NOT invoke an explicit checkpoint,
equipment change, logout, prepare-stop/restart or death: only the automatic timer
may save the input for this gate. Within the next eligible interval expect
WeaponNativePeriodicWear PASS changed wear persisted/restored. Read native status:
ACTIVE one copy128rev6 dirt≈0.6, fresh epoch, same session, ledger25 all pools0.
Verify-wear: changed=true/revision6/no ammo/equipment/material changes.

Wait one additional eligible interval without another dirt input; run server
WeaponNativePeriodicWearStatus current-id. Expect unchanged count to increase,
persisted count not increase, no metadata/epoch/revision churn; repeat SELECT-only
audit remains revision6. Counters may include earlier unchanged setup polls, so
compare increments rather than hardcoded initial counts. Remove helper afterward,
restore original112, preserve audits and leave periodic configuration stable for
the batch. No accepted family/stop/logout/death proof is reopened by this gate.
