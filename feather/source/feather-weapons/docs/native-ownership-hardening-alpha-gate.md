# Native ownership transfer/storage hardening

2026-11-01 COMPLETE scoped recovery batch live acceptance:
Deliberate rollback verified/cleared; real pre-COMMIT connection82 termination
produced providerunknown with zero retries. Journal/hold survived prepared resource
restart; Give refused after restart (moved0/skipped1). Verify established rollback
from dead connection + exact readback, then clear released hold while preserving
original providerOutcomeunknown. Final independent SQL229 inventory2/rev8/
condition100/full original metadata exact. Jane11 same8bad115a-d65a session/epoch
1793581990:97332998:1, ledger35/repeater1 and112rev2/134rev8 wear unchanged.
John12 same8e493276-d65a session/epoch1793581995:97338286:2, ledger16/Tomahawk1,
eightutilityGUIDowners and155rev4/158rev5 wear unchanged. Journal cleared/history
retained; both probe opt-ins consumed0. No further fault or grant required.
Known presentation defect deferred to next combined fix: successful greedy Give
refusal wraps marker inside 'Moved 0; skipped 1 native_recovery_audit_pending',
so exact-message translation mapping misses it. Functional hold worked; do not
repeat destructive/recovery matrix for this text fix. COMMIT-in-flight loss,
wholeDB/server crash, generic legacy movement outcome redesign and broader
production automatic reconciliation remain outside accepted scope.

2026-11-01 next combined recovery batch implemented/live pending. Includes unknown
provider-outcome preservation/Weapons uncertain freeze, normal guarded rollback,
own-transaction connection loss, persisted journal/hold, restart readback, explicit
verify/clear and one-use safeguards. All files/commands staged together; see
native-recovery-batch-alpha-gate.md for exact one-deployment handoff. Real
COMMIT-in-flight/whole-database crash remain outside this batch's acceptance.

2026-11-01 LIVE simulated lost-caller-acknowledgement checkpoint COMPLETE:
InvNativeMoveAckLossProbe7 15 6 returned awaiting_independent_readback with
providerCommitConfirmedtrue/simulatedCallerAcknowledgementLosttrue/automaticRetries0.
Ownership log229/same serial deposit2 -> stash15. Independent SQL confirms
stash15/rev7/full original metadata; normal UI pickup15 -> Jane2 followed by
SQL inventory2/rev8/full exact metadata. Jane7 same cf755a66-d649 session/epoch
1793574803:90146019:1, ledger35/repeater1 and112rev2/134rev8 wear unchanged.
John8 same d8c9e4b5-d649 session/epoch1793574820:90163166:2, ledger16/Tomahawk1,
eight utility GUID owners and155rev4/158rev5 wear unchanged. Fixture229 remains
Jane-owned unequipped, probe opt-in consumed0. Acceptance is synthetic diagnostic
caller acknowledgement loss after a confirmed normal commit, independently
resolved by readback; NOT actual MySQL interruption, unknown COMMIT, production
NUI recovery, durable automatic reconciliation or crash recovery. Those remain
pending. No repeated movement or grant required for this checkpoint.

2026-11-01 IMPLEMENTED confirmed-commit/lost-caller-ack simulation; live pending:
InvNativeMoveAckLossProbe reuses exact Jane fixture229, expected revision, normal
open-stash access/current session/native guards and normal MoveInventoryItems.
Independent default0 feather_native_move_ack_probe consumed before admission,
one run per resource lifetime. On confirmed normal move, diagnostic discards
success reply and returns awaiting_independent_readback/automaticRetries0; it
never infers rollback, resends or auto-returns. Exception/refusal remains failed
for inspection, not an accepted simulated lost acknowledgement. This is a
synthetic diagnostic caller boundary, NOT real MySQL disconnect/COMMIT ambiguity,
NUI transport failure, crash recovery or durable automated operation recovery.
Full Inventory Lua suite/83runtime syntax and diff checks pass; tests cover one
call only, no hidden resolution, gates/one-shot and unresolved exceptions.
Deploy only existing Inventory internal/service native_move_contention_probe.lua
files after aggregate drain/stop Weapons/full client quit; restart Inventory and
Stashes, ensure Weapons, new ack flag0. No manifest/newscript/refresh/UI/DB change.
Fixture baseline229 inventory2/rev6; successful probe should leave stash15/rev7,
then independent readback before ordinary return (expectedJane2/rev8). Exact
mapping/ordered handoff in Weapons docs/native-ownership-hardening-alpha-gate.md.

## 2026-11-01 acknowledgement-loss diagnostic deployment

Required runtime sources -> relative server resources destinations:

- C:/coding/feather-scripts/feather-inventory/server/internal/native_move_contention_probe.lua -> feather-inventory/server/internal/native_move_contention_probe.lua
- C:/coding/feather-scripts/feather-inventory/server/services/native_move_contention_probe.lua -> feather-inventory/server/services/native_move_contention_probe.lua

Preserve config.lua. Tests/docs remain local. Server console:
WeaponNativePrepareStopAll; wait aggregate PASS; WeaponNativeShutdownStatus must
be ready/completed=total; stop feather-weapons. Fully quit both clients; copy2files.
Server console in order:

```text
set feather_native_move_ack_probe 0
set feather_native_move_contention_probe 0
restart feather-inventory
restart bcc-stashes
ensure feather-weapons
```

No refresh because both files are existing/manifest-listed and no dependencies
changed. No DB migration/reset, UI build, new grants or Core/fullserver restart.
Reconnect/report current IDs; both F8 weaponNativeStatus. Jane opens existing
stash with free slot and keeps lasso unequipped. Do not arm before review.
Subsequent invocation after reviewed baseline:
set feather_native_move_ack_probe 1;
InvNativeMoveAckLossProbe CURRENT_JANE_SOURCE CURRENT_STASH_ID EXPECTED_REVISION.
Use actual IDs and baseline revision6. Awaiting readback is intentional, not a
PASS of recovery. Do not retry/re-arm on any result. Server owns normal commit
evidence; only the diagnostic caller reply is discarded. It is not injected
uncertainty inside SQL or a production UI recovery mechanism.
Independent SELECT id,inventory_id,row_revision,metadata FROM inventory_items
WHERE id=229 should show stash15/rev7/full unchanged metadata. Review it before
normal UI retrieval; then Jane2/rev8 readback and both players ammo/wear unchanged.

2026-11-01 LIVE overlapping Inventory movement checkpoint COMPLETE:
Jane5/John6 baseline active. InvNativeMoveContentionProbe5 15 4 passed with
 overlappingMoveCallstrue, one committed move and one not_found refusal; supplied
TX86894 ROLLBACK (7queries/1215ms) corroborates losing transaction. Ownership log
229/same serial inventory2 -> stash15; independent SQL stash15/rev5/full metadata
unchanged. Normal UI pickup15 -> Jane2 followed by SQL inventory2/rev6/exact
original metadata. Jane same session/epoch ff3daec1-d645...:1793573165:88508444:1,
ledger35/repeater1 and112rev2/134rev8 wear unchanged. John same0311547a-d646...
epoch:1793573172:88514747:2, ledger16/Tomahawk1/eightutilityowners and155rev4/158rev5
wear unchanged. Fixture229 remains Jane-owned unequipped. Probe opt-in consumed0
and one-run latch remains used. Accepted overlapping normal move calls, single
commit/stale-source rollback/conservation; exact MariaDB lock-wait timing not
instrumented. Ambiguous-commit/crash recovery remains separate and pending.

2026-11-01 IMPLEMENTED bounded same-item Inventory movement contention probe;
live pending. One-shot console InvNativeMoveContentionProbe targets only Jane's
original lasso229/serial/ref, exact expected revision and existing authorized open
stash. Two gated worker calls use ordinary MoveInventoryItems with actor/session
context and all normal capacity/ownership/native guards. No SQL sleeps, grant,
bypass, retry, automatic return, new container or original-firearm mutation.
PASS requires overlapping move calls, one commit plus stale-source refusal,
exact same metadata/item and +1 revision in stash, unchanged other rows across
both inventories. Serial scheduling is inconclusive; exception/session/conservation/
timeout fail closed for reporting with no automatic recovery. This observes API
call overlap, not instrumented MariaDB lock-wait timing. Full Inventory Lua suite/
83runtime syntax pass with deterministic orchestrator and command-gate tests.
Runtime files: Inventory fxmanifest.lua, server/internal/native_move_contention_probe.lua,
server/services/native_move_contention_probe.lua. Exact deployment in Weapons
native-ownership-hardening-alpha-gate.md: prepared drain/ready then stop Weapons,
fully quit clients, copy3files, refresh/newscripts, restart Inventory/Stashes,
ensure Weapons with probe0, reconnect/capture IDs and verify stash before arm.

## 2026-11-01 movement contention deployment (not yet live)

Required runtime source -> destination relative to server resources root:

- C:/coding/feather-scripts/feather-inventory/fxmanifest.lua -> feather-inventory/fxmanifest.lua
- C:/coding/feather-scripts/feather-inventory/server/internal/native_move_contention_probe.lua -> feather-inventory/server/internal/native_move_contention_probe.lua
- C:/coding/feather-scripts/feather-inventory/server/services/native_move_contention_probe.lua -> feather-inventory/server/services/native_move_contention_probe.lua

Tests/docs stay local. Preserve config.lua and all existing feature flags.
Server console: WeaponNativePrepareStopAll; await aggregate PASS, then
WeaponNativeShutdownStatus must be ready/completed=total. Stop feather-weapons
while Inventory guard provider is still live. Fully quit both clients, copy3files.
Server console in order:

```text
set feather_native_move_contention_probe 0
refresh
restart feather-inventory
restart bcc-stashes
ensure feather-weapons
```

Refresh required: explicit new internal manifest script and new service file.
Stashes restart rebinds Inventory foreign/usable registrations. No Core/full server
restart, SQL migration/reset, UI build or extra grant. Reconnect, report current
IDs, both F8 weaponNativeStatus + weaponNativeMaintenanceStatus. Jane opens existing
stash with free slot, lasso remains unequipped. Confirm stash ID15 still current.
Do not arm until baseline reviewed.

Subsequent console invocation after reviewed baseline (replace current source,
stash ID and exact expected revision; no placeholders sent to console):
set feather_native_move_contention_probe 1;
InvNativeMoveContentionProbe CURRENT_JANE_SOURCE CURRENT_STASH_ID EXPECTED_REVISION.
Flag consumed0, only one run allowed per resource lifetime. Original baseline229
inventory2/rev4 expects stash15/rev5 after exactly one successful contested move.
Do not touch item or stash contents during probe. On failure/timeout/inconclusive
inspect state, do not re-arm, retry, return item automatically or restart pending
workers. Normal successful run leaves lasso stored until readback reviewed.
Independent SQL item229 full row plus player ammo/wear closes conservation.
The report proves overlapping normal move calls; SQL engine lock timing is not
instrumented and should not be claimed from two worker launches alone.

2026-11-01 LIVE controlled coordinator overlap checkpoint COMPLETE:
WeaponNativeOverlapProbe3 reports competingRefusedtrue, staleAcknowledgementRefusedtrue,
noEquipmentWriteRequestedtrue; original dry-run final seal/owned cleanup/server release/
fresh same-session restore PASS. Jane restored active epoch suffix1793571990:87333176:3,
ledger35 and112rev2/134rev8 wear unchanged; John active observer same epoch after
resource restart suffix1793571871:87214497:2, ledger16/eightutilityowners and
155rev4/158rev5 wear unchanged. Independent postprobe SQL confirms lasso229
inventory2/rev4 and full original metadata unchanged. One-shot opt-in consumed0.
Acceptance covers release-phase coordinator contention and invalid-ticket rejection;
not actual concurrent SQL moves, crash or ambiguous-commit recovery. No repeat needed.

2026-11-01 controlled coordinator overlap probe implemented; live pending.
Current Jane source3, John4; both active after restarting Weapons cleared last
night's completed drain latch (2/2 releases then roster_changed after disconnect).
Jane ledger35/wear112rev2+134rev8 and John16/wear155rev4+158rev5 unchanged.
SQL confirms fixture229 remains inventory2/rev4/exact original metadata.

Console-only WeaponNativeOverlapProbe uses normal dry-run seal/rebuild. With
feather_native_overlap_probe=1 it consumes the flag0 before admission, starts
one dry-run, immediately submits a second dry-run and empty-ticket Released.
PASS requires competing equipment_transition_in_flight refusal, stale refusal
and unchanged first reservation phase/session/outcome. Await actual restored
ACTIVE before acceptance. No SQL sleeps, drop hooks, mutation bypasses or
equipment write request; normal ammo seal/restore can run. This proves release-
phase coordinator overlap, not concurrent SQL movement or old-commit recovery.
Actual coordinator regression confirms exactly one release/commit/rebuild and
valid original ticket still restores after refusals. Full Weapons Lua suite pass.

Required runtime source:
C:/coding/feather-scripts/feather-weapons/server/services/native_equipment_transition.lua
Destination relative to server resources root:
feather-weapons/server/services/native_equipment_transition.lua
Optional tests/docs stay local. Preserve config and all feature flags.
Server console: WeaponNativePrepareStopAll, wait aggregate PASS, then
WeaponNativeShutdownStatus must be ready/completed=total. Copy only the above
file; set feather_native_overlap_probe 0; restart feather-weapons.
No refresh/new runtime file/dependency, Inventory/Core restart or DB migration.
Clients may remain connected. Confirm both F8 weaponNativeStatus ACTIVE, then
server: set feather_native_overlap_probe 1; WeaponNativeOverlapProbe 3.
Do not retry failed/uncertain probe; inspect normal restore. After restore,
both F8 weaponNativeStatus and weaponNativeMaintenanceStatus. Repeat SELECT
id,inventory_id,row_revision,metadata FROM inventory_items WHERE id=229;
expect2/rev4/exact metadata; Jane ledger35, John16 and wear unchanged.

2026-10-31 COMPLETE scoped Jane ownership transfer/storage conservation:
Independent SQL capture confirms item229 inventory2 row_revision4 after exactly
four committed moves (Jane -> John -> Jane -> stash15 -> Jane). Complete metadata
matches issuance: serialFW-LASS-6AE6BCBA-26771B-0001, utility_lasso/schema2,
condition100/quality100, all flagsfalse, empty cosmetics/attachments and unchanged
provenance including original Jane CID/reference/createdAt1793506490. Equipped
Give/stash movement refusals and released roundtrips accepted, both players'
ammo/wear unchanged. Fixture remains Jane-owned unequipped. This closes final
metadata/revision capture pending below. Automated stale/boundary regressions pass;
genuine concurrent SQL, ambiguous-write/crash recovery and broader rollout remain
pending, not implied by scoped successful movement. No further mutation required.

2026-10-31 LIVE Jane transfer/storage roundtrip accepted at observed boundaries:
Lasso229/same serial returned John5 -> Jane2, equipped stash drag refused
(generic inventory-changed message; exact guard cause not established), then
unequipped deposit2 -> stash15 and pickup15 -> Jane2 logged. Jane active/idle,
no utility owner, ledger35/repeater1 and firearm112rev2/134rev8 wear unchanged.
John same session/epoch/eight utility owners, ledger16/Tomahawk1 and complete
firearm155rev4/158rev5 wear unchanged. Stash restart ready/smoke4of4/no missing
list warnings and empty storage UI confirmed. Final lasso full metadata and row
revision still require independent read-only inventory_items229 capture; expect
inventory2/revision4 for four committed moves, investigate any mismatch. Genuine
concurrent SQL/ambiguous persistence remain separate; do not repeat lifecycle.

Final read-only database SQL editor checkpoint (not a migration):

```sql
SELECT id, inventory_id, row_revision, metadata
FROM inventory_items
WHERE id = 229;
```

Compare full metadata to issuance: schemaVersion2, utility_lasso, serial
FW-LASS-6AE6BCBA-26771B-0001, quality100/condition100, empty cosmetics/attachments,
disabled/evidence/stolen false and original provenance reference/resource/type/
issuedToCharacterId/createdAt1793506490 unchanged. Do not rewrite on mismatch.

2026-10-31 LIVE return transfer log confirms229/same serial inventory5/John ->
inventory2/Jane, type transfer/reason give. Storage checkpoint paused for stash
startup race: early list route/rate-safe retry fix implemented and tested in
bcc-stashes. See framework bcc-stashes/STARTUP_READINESS.md for exact two-file
deployment and restart/smoke. No Inventory/Weapons runtime changes. Storage UI/
free-slot verification still pending; do not infer metadata/revision audit from
ownership log alone.

2026-10-31 LIVE Jane first transfer boundary accepted: dedicated Standard Lasso229
rev0/serialFW-LASS-6AE6BCBA-26771B-0001/provenance32 issued and replayed exactly.
Normal menu equip captured GUID; Give while held refused with native-loadout
ownership message, same epoch/rev0/no recipient copy. After menu unequip, Jane
utility owner absent and ledger35 unchanged. Committed ownership log confirms
item229/same serial from inventory2/Jane to inventory5/John, type transfer/reason
give. Return transfer, complete moved-row metadata/revision, storage and final
observer comparison remain pending. UI does not currently expose serial in item
details; use known newly received slot only if distinguishable, never guess.

2026-10-31 prepared; live checks pending. Jane is primary tester on main PC;
John observes from laptop. Do not migrate John's eight-item fixture loadout.

## Automated evidence and limits

213 Weapons Lua specs pass. New native_inventory_move_composition_spec.lua
executes actual Weapons guard and Inventory move controller within Inventory's
existing deterministic SQL/rollback harness. It verifies native-held drag and
ID-based movement refusal with zero writes/events, saved equipment/provider/
administrative refusal, authority acquired at transaction entry, released utility
roundtrip preserving ID/metadata with one revision per move, stale source retry,
stale selected-item refusal, and SQL failure rollback/no committed move fact.
This models serialized boundary changes, not actual concurrent MariaDB execution.
Existing Inventory tests cover recipient proximity/session recheck and mutation
capacity/guard/stale-source cases. Real multiplayer delivery/storage remain pending.
No runtime behavior changes; do not deploy tests or docs to server.

## First checkpoint — baseline only

No runtime files to move, no refresh/restart/configuration/database change.
Report current Jane/John player IDs before any target command.

Jane F8:

```text
weaponNativeStatus
weaponNativeMaintenanceStatus
```

John F8:

```text
weaponNativeStatus
```

Server console:

```text
WeaponNativeUtilityStatus
```

Expected prior Jane baseline: character6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb,
ledger35/repeaterRegular1, two firearms112rev2 and134rev8.112 dirt1.0 and
degradation0.00871666707098;134 pristine. John ledger16/Tomahawk1, eight utilities
172/173/174/175/225/226/227/228. Actual supplied snapshots take precedence.

## Planned focused live sequence (not yet authorized commands to execute)

After baseline review inspect Jane's inventory for a spare Standard Lasso. If no
appropriate dedicated fixture exists, issue exactly one utility_lasso using
stable request native-jane-ownership-lasso-alpha-v1; replay same request, disable
issuance, retain returned item ID/serial. No ammo/material or firearm grant.
Equip the dedicated fixture in Jane's Utility slot, confirm active ownership.
Keep characters close for Give. Attempt normal inventory Give while held and
verify refusal/same owner/item/revision; do not force transfer through exports.
Attempt storage only in an existing authorized empty container whose UI/access
has been verified; do not assume the development open_storage UUID exists.
After normal unequip/PASS/ownership release, transfer to John and return the
same unequipped item. John need not equip it or change his existing loadout.
Separately deposit/retrieve it through verified storage. Each committed move
must preserve serial/provenance/condition/cosmetics/attachments and add exactly
one row revision; refused/stale attempts must not add moves or revisions.
Readbacks and ownership transition logs establish item/owner boundaries; a UI
notification alone does not prove conservation. Do not replenish by rekeying
issuance receipt, grant permissions, clear holds, or retry uncertain outcomes.
Capture Jane/John ammo and wear unchanged. Genuine competing SQL requests and
ambiguous persistence/failure recovery remain separate later gates.
