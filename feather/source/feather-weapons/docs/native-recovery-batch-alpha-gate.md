# Dedicated test-database recovery batch

2026-11-01 LIVE standalone provider boundary acceptance confirmed from remote
PowerShell output, Node26.13, fixture feather_recovery_8d8bf1abc3689d78:
PASS real COMMIT reply loss (public caller unknown, independent row committed
once, no retry); PASS abrupt worker death (connection gone, independent row
unchanged, no retry); Fixture cleanup confirmed, prompt returned. Earlier failed
attempt remains historical harness-boundary error, not this result. Inventory
fixture229 was not involved. This accepts deterministic committed-but-reply-lost
and uncommitted worker termination at provider boundary; whole database/RedM
crash, arbitrary COMMIT interruption timing, and end-to-end durable inventory
reconciliation/production rollout remain separate pending scope.

2026-11-01 remote diagnostic SELECT passed with no leftover fixture tables.
Full attempt then failed at commit_reply_loss/ERR_ASSERTION; fixture cleanup
confirmed, worker-death test not reached. Inspection found a harness boundary
error: raw mysql2 transport errors need publicError classification, as in the
actual CFX bridge. Standalone runner assertion corrected; provider runtime
unchanged. All130 provider/proxy regressions pass. Corrected live test pending;
neither boundary gate is accepted from the failed attempt.

2026-11-01 standalone provider boundary live attempt failed before either PASS.
The old runner withheld failure stage; no acceptance or cleanup inferred. Safe
stage/code diagnostics and SELECT-only --check prepared in the sibling MySQL
runner. Inspect connection and leftover test tables before another full run.

Next provider boundary batch is prepared, not live accepted: see sibling
feather-mysql/docs/RECOVERY_BOUNDARY_WINDOWS.md. Standalone isolated-table tests
cover actual COMMIT reply loss and abrupt worker death; no fixture229 writes,
resource deployment, or client reset. Whole database/RedM crash remains separate.

2026-11-01 LIVE notification preview acceptance: Jane source13 received readable
partial recovery-hold text with moved0/skipped1 and no raw guard key, and explicit
unknown-transfer/do-not-retry text. Both commands reported notice_preview/noWrites.
Status remained cleared, fixture229, disconnect, original providerOutcomeunknown,
connection82, automaticRetries0. This accepts presentation and retained journal
state only; no new database fault was injected and COMMIT-in-flight/crash gates
remain pending.

2026-11-01 readiness follow-up implemented and automatically tested; live deployment pending:
Give partial summaries resolve recovery reasons through the recipient translator.
Legacy movement unknown provider outcomes retain explicit unknown/no-retry fields
through RPC/NUI without false rollback claims or resolved response snapshots.
Read-only console previews (DevMode, current connected player required):

```text
InvNativeRecoveryBatch notice CURRENT_SOURCE partial
InvNativeRecoveryBatch notice CURRENT_SOURCE unknown
```

These send synthetic notifications only; no fixture, hold, journal, or opt-in changes.
Do not re-arm accepted fault probes just to test wording. Keep all diagnostic opt-ins
disabled after acceptance. Generic durable movement reconciliation remains pending.

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

2026-11-01 LIVE recovery batch progress: deliberate rollback verified/cleared.
Real disconnect probe source9 on fixture229 terminated its transaction connection82;
provider raw query1219381 and finish1219382 report DATABASE_ERROR/sqlState70100/
outcomeunknown. Journal awaiting_readback/mode disconnect/providerOutcomeunknown,
automaticRetries0/connectionId82 retained. Independent SQL confirms229 inventory2/
rev8/condition100/full original metadata unchanged; PROCESSLIST82 absent. This
accepts targeted pre-COMMIT connection failure plus independent rollback evidence,
not COMMIT-in-flight loss or wholeDB crash. Hold remains intentionally active;
planned no-copy prepared Inventory/Stashes/Weapons restart will verify persistence
before explicit verify/clear and final player conservation capture.

2026-11-01 implemented/automatically tested; live gates pending.
User confirmed a dedicated test database on another Windows machine.

## Scope and evidence boundaries

- Correct provider-outcome propagation: Inventory TransactionAPI retains unknown
  provider results as transaction_outcome_unknown/outcome unknown/retrySafe false,
  counts them separately from rollback, emits no success fact and caches no success.
  Weapons coordinator records such envelopes as uncertain, freezes, never retries
  or rebuilds. Actual Inventory-to-Weapons regression exercises this boundary.
- One persisted fixture journal and console suite includes deliberate rollback,
  actual termination of the fixture transaction's own connection before COMMIT,
  status, independent verification, explicit release/cleanup and restart holds.
- TransactionAPI/normal access/CAS/native guards still own item229 metadata write.
  It attempts condition100 ->99, then deliberately rolls back or terminates its
  own connection. Expected durable condition100/revision8 unchanged in BOTH cases.
  No grants, payments, moves, ammo writes, native recreation, blanket removal,
  provider shutdown or kill of another connection.
- MariaDB documents that terminating a connection rolls back its active transaction:
  https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/kill
  The caller may still receive unknown because rollback acknowledgement was lost.
  This is a real pre-COMMIT connection fault, not a COMMIT-in-flight interruption,
  whole database crash or fabricated known successful commit.
- The journal is saved/read back before dispatch; connection ID saved before
  termination. Unresolved journal blocks only229 moves/destruction/metadata.
  Private in-memory ticket permits only this probe's own metadata write while
  executing. Restarts reload the hold even with diagnostic opt-ins0.
- Verify requires confirmed deliberate rollback OR recorded connection absent
  from PROCESSLIST, plus exact full original item readback. Baseline-looking rows
  alone do not resolve a live connection. Verification does not release hold;
  explicit clear rechecks row and releases it. Each mode runs once per journal.
  Invalid/partial journal, mismatches and unsupported prepared-state crash remain
  unresolved for inspection; no retry, auto-return, overwrite or speculative cleanup.
- Guard reasons are stable keys; ordinary RPC error presentation resolves current
  recipient language through existing feather-settings/Core locale path with
  English fallback. No translation lookup while guards hold transaction locks.

## Automated checks

215 Weapons Lua specs/runtime syntax, full Inventory suite/85runtime syntax,
7 Weapons and3UI Node tests,128 MySQL bridge/driver tests pass. New tests cover
unknown provider envelopes/no success cache/events, actual coordinator freeze,
durable journal-before-dispatch, private ticket, command/default/double opt-ins,
one self connection only, exact CAS, save failure/corrupt journal, restart hold,
terminated-connection requirement, mismatched readback, explicit cleanup and
per-recipient language fallback. No actual DB fault run locally; live evidence
must come from the dedicated test server. MySQL resource itself is unchanged.

## One combined runtime deployment

Destinations relative to unknown server resources root. Preserve both config.lua
files, accepted gates/enrollment and any existing native-recovery-batch.json.
Do not copy .git/tests/docs/.gitignore/node_modules or a local audit journal.

| Absolute local source | Relative destination |
| --- | --- |
| C:/coding/feather-scripts/feather-inventory/fxmanifest.lua | feather-inventory/fxmanifest.lua |
| C:/coding/feather-scripts/feather-inventory/server/services/transactions.lua | feather-inventory/server/services/transactions.lua |
| C:/coding/feather-scripts/feather-inventory/server/helpers/main.lua | feather-inventory/server/helpers/main.lua |
| C:/coding/feather-scripts/feather-inventory/translations/en_us.lua | feather-inventory/translations/en_us.lua |
| C:/coding/feather-scripts/feather-inventory/server/internal/native_recovery_batch.lua | feather-inventory/server/internal/native_recovery_batch.lua |
| C:/coding/feather-scripts/feather-inventory/server/services/native_recovery_batch.lua | feather-inventory/server/services/native_recovery_batch.lua |
| C:/coding/feather-scripts/feather-weapons/server/services/native_equipment_transition.lua | feather-weapons/server/services/native_equipment_transition.lua |

Server console BEFORE copy:

```text
WeaponNativePrepareStopAll
WeaponNativeShutdownStatus
```

Wait aggregate PASS and ready/completed=total. On failure stop handoff. Then
server console stop feather-weapons. Fully quit both clients; copy7files above.
Server console in order:

```text
set feather_native_recovery_batch 0
set feather_native_recovery_disconnect 0
refresh
restart feather-inventory
restart bcc-stashes
ensure feather-weapons
InvNativeRecoveryBatch status
```

Refresh required for new internal manifest entry and service file. Stashes rebinds
Inventory registrations. No DB migration/reset, UI build, Core/MySQL/fullserver
restart. Reconnect/report current IDs; both F8 weaponNativeStatus. Expect idle
journal on first deployment; existing unresolved journals are never overwritten.
Keep Jane's229 unequipped, inventory2/rev8/original metadata. Review baseline before
arming either mode. Source IDs from older sessions must not be reused.

## All subsequent test and cleanup commands already included

These are the planned sequence AFTER current IDs and baseline review, not an
instruction to paste placeholders. No more source copies are expected unless a
test reveals a bug. Keep both players idle/no inventory changes during probes.

Server console known rollback:

```text
set feather_native_recovery_batch 1
InvNativeRecoveryBatch run CURRENT_JANE_SOURCE rollback 8
InvNativeRecoveryBatch status
```

Await awaiting_readback/providerOutcome rolled_back. Independent SQL editor:

```sql
SELECT id,inventory_id,row_revision,metadata FROM inventory_items WHERE id=229;
```

Expected Jane2/rev8/condition100/all metadata exact. Server:

```text
InvNativeRecoveryBatch verify
InvNativeRecoveryBatch clear
```

Verify must say verified_rollback, clear must say cleared. If either differs,
do not arm next mode. With current Jane source still verified, actual disconnect:

```text
set feather_native_recovery_batch 1
set feather_native_recovery_disconnect 1
InvNativeRecoveryBatch run CURRENT_JANE_SOURCE disconnect 8
InvNativeRecoveryBatch status
```

Expect awaiting_readback/providerOutcome unknown and a recorded connectionId.
This terminates only the connection reported inside THIS fixture transaction.
Both flags consumed0. Do not re-arm on any result. Database remains running.
Repeat same independent SQL read, expected unchanged Jane2/rev8/full metadata.
Verify/clear commands above already implement connection absence + exact readback.

For a live hold-persistence check, leave disconnect unresolved across a planned
prepared resource restart BEFORE verify/clear. This inherently tests a restart;
it is not another code deployment. Seal/release both owners/ready; stop Weapons,
quit clients, restart Inventory/Stashes, ensure Weapons (no refresh/new files).
InvNativeRecoveryBatch status should retain mode/connectionId/awaiting_readback;
fixture229 stays held. Then readback/verify/clear normally. This can be combined
with the next planned break rather than resetting clients immediately again.
Do not interrupt an outstanding executing transaction or delete the journal.

Final both players F8 weaponNativeStatus and weaponNativeMaintenanceStatus;
independent229 SQL unchanged. Finish server console:

```text
set feather_native_recovery_batch 0
set feather_native_recovery_disconnect 0
InvNativeRecoveryBatch status
```

Final cleared journal is retained server-side as audit history, ignored by Git.
Do not delete it to repeat a mode. No item grants/restoration/deletion required.
Crash during prepared dispatch, COMMIT-in-flight transport loss, whole database
restart and production automatic reconciliation remain separate unaccepted scope.
