# Native acceptance automation

2026-11-02 prepared restart acceptance workflow IMPLEMENTED/local tests PASS; live acceptance PENDING. One co-deployment packages full RedM process restart then MariaDB service restart, with persistent pre-dispatch baselines and no preparation replay. Jane/John are discovered by their stable character IDs. Both normal owners seal/restore before baseline capture. Inventory persists and pauses ONLY an abandoned diagnostic reservation and redelivery of an already-recorded Lasso229 projection, with no gameplay item mutation. Workers resume the diagnostic records after a new server-process convar token (server case), or an observed SQL outage plus decreasing MariaDB Uptime (database case). The live database test must keep the same RedM process. Verification requires normal rollback/scope release, original delivery event IDs/unique provenance, healthy queues and exact saved Inventory/ammo/equipment/native ownership/wear conservation (new session/epoch permitted). A resource-only restart or network outage alone cannot pass. Existing gameplay feature switches are recorded; explicit settings command reapplies only12 whitelisted boolean gameplay switches after a new server process while clients are disconnected. Issuance/fault flags are excluded; this is not acceptance of permanent installer startup configuration. Files native-restart-probe.json and native-restart-report.json are durable evidence and must be preserved. Earlier lifecycle report remains separate. Tests: Inventory Lua/91 runtime syntax plus JS3; Weapons221 Lua/runtime syntax plus JS7. User identified database Windows service MariaDB. One final visual pass remains after both scenarios. Scope is PREPARED GRACEFUL RESTART with abandoned reservation and idempotent existing delivery, not arbitrary in-flight purchase/transfer COMMIT, hard process kill/power loss, all economic APIs, or third-party callback guarantees. See Weapons docs/native-restart-acceptance.md for eight-file co-deployment and every command/UI action.

2026-11-02 LIVE durable move delivery acceptance PASS. InvMoveRecoveryAcceptance returned phase passed/checks4, backgroundRecovered=true, lateOriginalFenced=true, rollback=true, lostCallerReply=true, itemWrites0, automaticMutationRetries0. No deadlock was shown in the supplied run; slow successful queries/commits are timing observations, not failures. Jane's existing Lasso229 committed inventory2->15 and15->2. Weapons persisted durable transitions with delivery IDs 494759f8-d693-11f1-99a9-e0d55eaa2deb:1 and 4cab8b3b-d693-11f1-99a9-e0d55eaa2deb:1. InvMoveDeliveryAcceptance returned phase passed/checks4, roundtrip=true, duplicateDeliveryConserved=true, durableSnapshots=true, provenanceEvents2, newProvenanceEvents0, itemWrites0, automaticMutationRetries0. User confirmed all requested manual observations passed. This accepts the scoped real Inventory/Weapons outbox/export/ledger path and duplicate-delivery conservation. No further deployment, restart or repeat testing is required for this gate. Remaining boundaries: arbitrary third-party broadcast subscribers are best-effort; no claim of whole DB/RedM process crash acceptance, every economic API, chronological delivery, or receipt retention/pruning policy.

2026-11-01 durable ordinary-move projections IMPLEMENTED; live acceptance pending. Inventory now appends an immutable outbox document in the SAME transaction as item writes and the outcome receipt, capturing item/serial/definition/revision and source/destination character identities (including offline owners). A background worker redelivers to a trusted Weapons export only until acknowledgement; Weapons atomically commits provenance plus a payload-checked receipt, so a lost consumer reply/restart cannot duplicate the ledger entry. Native ItemMoved broadcasts are tagged to suppress a second legacy Weapons insert. Current-session Inventory/hotbar refreshes may safely repeat. Legacy broadcast delivery (including arbitrary OwnershipTransitionCommitted/ContainerDeleted subscribers) remains best-effort: no arbitrary third-party callbacks are blindly replayed or claimed exactly-once. Deleted-container facts are retained but no generic subscriber acknowledgement protocol is claimed. Scope acquisition now uses ordered exclusive upserts instead of INSERT IGNORE shared-lock upgrades; this removes that known contention pattern but does not prove every live deadlock source eliminated. New schema auto-initializes and validates InnoDB/primary keys. No manual SQL migration/config change. Local verification: Inventory Lua including 89 runtime syntax files, actual original-mutation/outbox rollback/lost-reply composition, console fixture audit wiring; Weapons220 Lua/runtime syntax, JS7, Inventory JS3. New console InvMoveDeliveryAcceptance audits the two new Lasso229 round-trip snapshots and deliberately redelivers already-recorded projections twice, requiring unchanged event IDs and exactly one ledger event per delivery key, ZERO item writes/new provenance events. Requires a NEW single round-trip after this batch; no SQL dumps, grants, player IDs or repeat of eight utility tests. Whole DB/RedM crash acceptance, all economy APIs, third-party acknowledged subscriptions and retention policy remain outside this gate. See Inventory docs/move-delivery-outbox.md for the exact nine-file co-deployment and commands.

2026-11-01 final persisted report confirmation: WeaponNativeAcceptance visual
pass then status both returned run1793599650:114993425, phase complete,
passed3/total3, visual pass, automaticRetries0. Scoped automated lifecycle and
human visual acceptance are now both persisted in native-acceptance-report.json.
No additional tests, deployments or restarts required for this batch.

2026-11-01 LIVE acceptance suite PASS run1793599650:114993425, complete3/3,
automaticRetries0: Jane normal seal/restore; Jane competing-request/stale-ack
refusal with normal restore; John normal seal/restore. Each completed with
conserved durable inventory/metadata/revisions/equipment/ammo and native
ownership/wear plus unchanged observer epoch. User separately confirmed visual
passed. Console summary still visual pending until the console visual pass
command persists that observation; do not infer JSON already updated. No repeat
of accepted batch required. Earlier preflight refusals remain historical harness
issues. This accepts the scoped lifecycle automation, not production automatic
recovery, whole DB/RedM crash or economic movement automation.

Second live run1793598207:113549828 reached client readback but stopped before
baseline/dispatch with generic client/durable mismatch, passed0. Audit comparison
corrected to call the normal server-catalog ammunition validator for both client
and durable pools: omitted supported zero pools are valid; unknown keys,
noninteger/over-limit counts and nonzero mismatches still refuse. Raw durable
snapshots remain unchanged for conservation checks. Exact comparison category,
actor and bounded numeric item/pool/wear details now persist in the report and
console; no serial/provenance dump. Corrected live run remains pending; do not
infer a proven live root cause solely from the old generic message. This update
touches only two Weapons files and permits prepared Weapons-only restart with
clients connected, no Inventory/Stashes restart or refresh.

2026-11-01 implemented and automatically tested; first live run pending.
First live run1793597319:112662093 stopped in initial read-only audit, passed0,
before a baseline or lifecycle dispatch. Read-only remote SQL inspection found
Jane inventory2 has10 rows including2 SQL NULL metadata rows; John inventory5
has17 rows with none NULL/empty/invalid. Audit corrected to preserve SQL NULL,
empty text and decoded documents distinctly instead of rejecting ordinary empty
metadata. Invalid nonempty documents still refuse. Detailed safe audit reasons
now reach the summary. Explicit run may repeat only a failed initial preflight
with no baseline/pending action/passed step; prior preflight summary is retained.
Failures after dispatch and interrupted pending actions remain non-replayable.
Live corrected batch is pending; no lifecycle gate is accepted from this refusal.
This is developer test orchestration, not the production recovery service and
not an installer troubleshooting requirement. It replaces repeated status/wear
dumps, source-ID tracking and lifecycle/overlap command exchanges for this batch.

## One live-session batch

The console-only development runner finds Jane and John by enrolled character
UUID, not changing player IDs. Both must be connected, active and idle. It reads
both inventories (all instance metadata/revisions), equipment and ammunition;
checks the real move guard refuses each equipped native item without moving it;
requests bounded current-session/epoch client ownership and maintenance views;
matches those against durable data; then runs Jane seal/restore, Jane overlap
and stale acknowledgement refusal/restore, and John seal/restore sequentially.
After each action it verifies conserved durable data and normalized native
ownership/wear, plus an unchanged observer epoch. Fresh tested-player epochs
must be acknowledged by the real coordinator. No fixture grants, moves, SQL
fault injection or direct equipment/ammo/material changes are requested. Normal
release/restore remains the production lifecycle implementation.

Before each action it saves and reads back `native-acceptance-report.json` in
the Weapons resource. It retains baseline, last readback, passed steps and the
pending step. Completed reports survive resource restart and `run` returns them
without replay. Interrupted/failed/invalid reports stop for review; there is no
automatic retry, journal deletion, fixture repair, or unsafe resume. Missing
characters before a run is admitted can reconnect and retry preflight normally.
An initial audit refusal with no baseline and no dispatch can also repeat its
read-only preflight on explicit `run`; it retains the previous refusal summary.
Once interrupted, this version deliberately requires developer inspection; it
does not claim generic resumable crash reconciliation. Preserve the report.

The read-only Inventory export accepts only feather-weapons, DevMode, the suite
opt-in and these two exact current sessions. An uncleared recovery journal blocks
the suite. Client diagnostics never authorize gameplay writes. No player notices
or translation dictionary additions are introduced; output is developer console
and server-owned JSON only.

## Deployment (one copy and client reset)

Runtime files, local roots under `C:\coding\feather-scripts`:

| Absolute local source | Destination relative to server resources root |
| --- | --- |
| `C:\coding\feather-scripts\feather-inventory\server\services\native_acceptance_audit.lua` | `[feather]\feather-inventory\server\services\native_acceptance_audit.lua` |
| `C:\coding\feather-scripts\feather-weapons\fxmanifest.lua` | `[feather]\feather-weapons\fxmanifest.lua` |
| `C:\coding\feather-scripts\feather-weapons\server\services\native_equipment_transition.lua` | `[feather]\feather-weapons\server\services\native_equipment_transition.lua` |
| `C:\coding\feather-scripts\feather-weapons\server\services\native_acceptance_suite.lua` | `[feather]\feather-weapons\server\services\native_acceptance_suite.lua` |
| `C:\coding\feather-scripts\feather-weapons\shared\native_acceptance_view.lua` | `[feather]\feather-weapons\shared\native_acceptance_view.lua` |
| `C:\coding\feather-scripts\feather-weapons\client\native_acceptance_suite.lua` | `[feather]\feather-weapons\client\native_acceptance_suite.lua` |

Preserve deployed configs, `native-recovery-batch.json`, and any existing
`native-acceptance-report.json`. Optional documentation/tests stay local; do not
copy .git, dependencies, fixtures or build output. No database migration, npm
installation, UI rebuild or full server restart is needed.

Server console before copying:

```text
InvNativeRecoveryBatch status
WeaponNativePrepareStopAll
WeaponNativeShutdownStatus
```

Require recovery cleared (or idle with no unresolved recovery), aggregate PASS
and shutdown ready/completed=total. On any refusal/failure stop for inspection.
Then server console:

```text
stop feather-weapons
```

Fully quit both RedM clients, copy the six runtime files, then server console:

```text
refresh
restart feather-inventory
restart bcc-stashes
ensure feather-weapons
```

Refresh is required because the Weapons manifest/script lists and runtime files
are new. Inventory's existing service glob loads the new audit file. Stashes
restarts after Inventory to rebind its registrations. Reconnect both players;
no new player IDs need to be supplied. Leave both idle with weapons holstered;
do not fire, change equipment, transfer items or perform gameplay during the run.

Server console:

```text
set feather_native_acceptance_suite 1
WeaponNativeAcceptance run
```

Expect three PASS lines and one summary phase complete/passed3/total3/visual
pending. The suite flag resets0 on resource boot and after the batch. If refused,
review_required, timeout, or conservation failure occurs, do not re-arm/restart
to bypass it. `WeaponNativeAcceptance status` reads the retained summary without
running actions and never needs player IDs or the opt-in.

One native UI check after completion: Jane selects/draws her existing equipped
firearms; John selects/draws his eight existing utilities and checks Tomahawk and
five melee remain selectable. This does not pretend to automate visual animation
or gameplay acceptance. Server console, according to the observation:

```text
WeaponNativeAcceptance visual pass
WeaponNativeAcceptance status
```

Use `visual fail` instead of pass if any check fails. To deliberately repeat a
completed batch later (not a failed/interrupted one), use `set
feather_native_acceptance_suite 1` then `WeaponNativeAcceptance again`.

## Coverage boundaries

This does not replay previously accepted issuance, economic movement, destructive
recovery, death/doctor, reconnect, or database crash tests. The standalone MySQL
COMMIT-reply-loss/worker-death tests remain their separately accepted evidence.
Automatic production recovery, whole DB/RedM crash reconciliation, safe automated
fixture movements and broader test profiles are still future work. This batch
reduces the repeated lifecycle evidence burden without overstating coverage.

Regression checks cover the real runtime wiring, current character discovery,
console/default gates, challenge matching, before-dispatch report persistence,
snapshot matching, observer conservation, refusal/timeout/session changes,
completed-run deduplication, interrupted/corrupt evidence, and read-only audit.


2026-11-01 follow-up: ordinary Inventory move recovery is implemented and locally verified, live deployment pending. See ../feather-inventory/docs/ordinary-move-recovery.md (sibling repository) for the seven-file package and one-batch acceptance. The completed native lifecycle report above remains accepted; background post-commit consumer/outbox recovery remains outstanding.


2026-11-01 LIVE ordinary move recovery acceptance PASS: InvMoveRecoveryAcceptance returned phase passed/checks4, lostCallerReply=true, rollback=true, lateOriginalFenced=true, backgroundRecovered=true, itemWrites0 and automaticMutationRetries0. One ER_LOCK_DEADLOCK/40001 transaction was explicitly rolled back during the run; the completed receipt diagnostic did not replay gameplay mutations. Do not describe the run as contention-free or infer the deadlock root cause from logs alone. User completed Jane's unequipped test Lasso229 stash round-trip: committed deposit inventory2->15 and pickup15->2 with the same immutable serial FW-LASS-6AE6BCBA-26771B-0001; all requested observations passed (one Lasso, Jane draws firearms, John wheel unchanged). No further deployment/restart/test is required to record this accepted gate. Remaining: review concurrent scope lock-upgrade contention (INSERT IGNORE followed by FOR UPDATE), durable post-commit outbox/consumer deduplication/provenance delivery, receipt retention, and broader crash acceptance. Bundle compatible follow-up fixes into the next deployment; do not repeat accepted utility/receipt tests without a concrete regression reason.

