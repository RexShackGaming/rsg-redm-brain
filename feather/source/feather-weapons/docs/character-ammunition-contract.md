# Character-owned native ammunition — alpha contract

Current status (2026-10-12): the scoped normal host and player-facing Inventory
ammo/equipment controls are implemented and live accepted for the recorded
Cattleman primary gates, including completed-transition logout/relogin. See
[native alpha integration](native-alpha-integration.md). Disabled defaults and
single-character DevMode scope remain; normal-host repair/attachments, broad
slot/family and in-flight/abnormal lifecycle coverage are not complete. The
2026-10-08 status below is historical, not the current readiness claim.

Status (2026-10-08): isolated family and identical M1899/Cattleman proof gates
passed their recorded tests. Server lifecycle coordinator/service and Inventory
transaction boundary implemented behind disabled CharacterAmmunitionEnabled
gates. Client/net routes and real enrollment remain unconnected; not production
ready. No real character ammunition migrated. Live runtime rollback gate PASS11/11;
running CFX callback gate pending. Dormant pure client checkpoint coordinator
is automatically tested but not wired to natives, timers, routes or manifest.
Native adapter separately tested: complete pool reads, bijective mapping,
ped-change rejection and explicit restoring-baseline writes with exact readback.
Production manifest still does not activate either client boundary. Proof-only
local bundled snapshots (automatically parity-checked against production) and
read-only nativeproofboundary command have automated coverage. Initial live
external script loading failed; self-contained zero-pool live rerun PASS,
nonzero8/4 revision0 live PASS. This command uses fixture caps, not native caps,
and local acknowledgement, not production server authorization.

Dormant client controller now combines explicit baseline restore/readback,
changed-only ticks, async reply serialization, ped/world suspension and final
checkpoint request. Server CheckpointAndSeal accepts final reductions and seals
only on matched durable completion; idle final requires no SQL. Persistence
failure freezes. Assembled controller/reset suites PASS; production manifest,
materialization remain unconnected. Proof-only explicit restore command live
gate PASS8/4 revision0 with user visuals passed; not production authorization.

Production manifest now loads dormant client boundaries and bounded report
transport. CharacterAmmoTransportEnabled=false AND CharacterAmmunitionEnabled=false
keep routes inert; no automatic Begin/open/grant/economic endpoint. Transport
timeouts do not replay ambiguous saves. Trusted catalog requires complete explicit
server policy and refuses native aliases; LeMat blocked, non-firearms excluded.
Native caps remain pending. Core local left event revokes matching session only.
Proof read-only actual network restore/idle-seal gate LIVE PASS8/4 revision0
sealed. Inventory callable CFX rollback fixture command implemented/tested,
live pending; runtime references cross resources and validator calls back to
Inventory/Core. Running production fixed-export authorization and real cutover
remain pending; fixture does not bypass/enable those boundaries.

External Observe/Mutate require a server-issued runtimeEpoch/runtimeTicket.
Inventory calls the fixed Weapons validation export before work and before
commit, binding session, operation, expected revision, payload and limits.
Restore ack must equal durable baseline; no observations while restoring/sealed/
frozen. Idle samples acknowledge locally without SQL. Economic changes require
fresh native baseline acknowledgement. Persistence errors freeze rather than
silently repairing ammo. Trusted Snapshot is read-only and never enrolls.

Development console `InvCharacterAmmoRuntimeSmokeTest 1` exercises11 checks
under complete real-row rollback while Weapons stays stopped. It sends no native
changes; a running cross-resource Weapons validation callback is a later gate.

## Fixed ownership model

- Character UUID owns one total per compatible native ammunition type. That
  total includes loaded rounds: clips must NEVER be added to it again.
- Serial, attachments, condition and ownership remain on weapon instances.
- Ammo selection, clips, draw and reload are native gameplay. Same-type switch
  reloads are allowed; independent clip preservation is not promised. Initially
  no clip/type restore writes on recovery/restart: restore carried totals only.
- Inactive variants remain separate pools. Exhausted variants need not be
  selectable. Native wheel counts show shared ammunition, not gun reserves.
- All conventional firearm families use the same contract after their own gates.
  Dual wield, LeMat secondary barrel and other special modes require explicit
  tests. Bows, throwables and utility items remain outside this migration.

## Durable transactions and authorization

- Character/session verified on server before mutation and before commit.
- Every runtime delivery has a new server-issued epoch; reports require exact
  character, session, epoch and expected persisted revision. Source reuse and
  delayed reports from before recovery/restart must fail closed.
- Observations cover every authorized pool, reject unknown types, invalid counts
  and growth. Decreases are not proof of legitimate firing/anti-cheat; add bounded
  rate validation and audit before public rollout. Clip decreases do not allocate
  consumption to weapon items anymore.
- Load: lock character ledger, check durable operation receipt, remove exact
  loose inventory quantities and credit carried pool within ONE Inventory DB
  transaction. Unload: inverse, checking capacity/access within that transaction.
  Ledger update and durable receipt use the same bound query. Publish native
  authorization only after commit. Retries reuse operation ID and return receipt.
- Lock order for these routes: character inventory header, access check,
  character ledger, operation receipts, then item rows; all future shared-ammo
  load/unload/migration/observation routes must use the same order.
  Serialize observations against these operations; no stale native snapshot may
  undo an authorized credit. Repository does not itself authorize or commit.

## Transfers and migration

- Giving/storing/unequipping a firearm transfers no carried ammunition, including
  its native clip. Sender keeps carried totals. Recipient gets weapon identity
  and condition, not free rounds. Do not subtract clip values from the belt.
- One-time migration must lock ALL owned firearm items, not just equipped slots.
  Sum accepted current per-item pool totals once by native type; no legacy
  loaded+reserve fallback (alpha requires no backward compatibility). Validate
  every variant and capacity. Excess
  returns to loose inventory atomically or aborts; never truncate.
- Mark each item migrated and clear old authoritative ammo counts in the SAME
  transaction that creates character ledger and migration receipt. Repeated
  migration must not sum again. Audit preview and backup precede execution.
- No production migration yet. Existing metadata remains authoritative until
  character migration commits; never run both ammo authorities for one character.

## Lifecycle and release gates

- Checkpoint before logout/item mutation; retain final shot across death before
  restoring on recovery. Suspend observation during native reset/materialization.
- Missing/corrupt ledger after migration is an error, not empty enrollment.
- Ordinary restart/reconnect/death tests passed in isolated license-keyed proof;
  production character isolation, DB races, failures/retries and transactions
  must be tested separately. Abrupt disconnect/ped-reset timing remains a risk.
- Before enabling: all family native gates, dual wield, grants/unloads, transfer,
  one-time migration/retry, wrong character/session/epoch, concurrent mutations,
  death timing and restart crash recovery. Preserve old runtime until then.

Authoritative progress: framework Weapons expansion master plan.

## Alpha enrollment rollback gate

No backward compatibility is required. Current authoritative per-item pools
are checked once for the alpha cutover; missing pools abort rather than using
legacy loaded/reserve fallback. Production enrollment is not exposed yet.
Deploy Inventory enrollment/preview services; keep Weapons stopped, run refresh
then restart Inventory. Console `InvCharacterAmmoEnrollmentSmokeTest 1` exercises
ledger creation, item metadata ownership replacement and enrollment receipt in
one transaction, intentionally rolls it back, then verifies exact original
metadata/revisions and no ledger/receipt persisted. Expected5/5, rollback VERIFIED.
No native changes. The previous DB test must have created the two ledger tables.
This is not committed-enrollment or native-runtime release evidence.

Rollback live gate passed5/5 with exact restoration. Next durable fixture gate:
deploy new Inventory enrollment test service, refresh then restart Inventory
while Weapons stays stopped. Run `InvCharacterAmmoEnrollmentReplayTest prepare`.
This commits four disposable firearm rows, ledger revision0 and one receipt in
dedicated fi_ammo_enroll_* tables only. Expected pistol Express3/repeater Regular8
Express4. After prepare PASS, restart Inventory and run the separate verify step;
expected5/5 persisted state/ownership clearing/identity/receipt/duplicate refusal.
Cleanup removes only reserved fixture rows, leaving empty tables. No production
enrollment command/export, native changes, or compatibility runtime is enabled.

## Consumption observation boundary

Inventory's gated direct ObserveCharacterAmmunition export accepts only trusted
Weapons and a current Core character session. Header/ledger lock order serializes
with economic mutations. Complete bounded pools and expected revision required;
only reductions persist. Unchanged samples return same revision without UPDATE.
Weapons must enforce runtime epoch/reset windows before calling; no native/client
caller wired yet and production gate stays false. Future client sends changes,
not idle DB polls. Deploy new Inventory test service, refresh then restart it
with Weapons stopped. InvCharacterAmmoObservationSmokeTest 1 temporarily enrolls
real rows, exercises reduction/no-op/rejection and rollback. Expected6/6,
rollback VERIFIED, all original metadata/revisions/ledger/receipt state restored.
No native changes; at least2 carried rounds required. Not runtime/death acceptance.

## First live database gate

On a development server, stop production weapons BEFORE restarting Inventory
(old guard registrations can otherwise retain invalid consumer references), and leave Inventory's
CharacterAmmunitionEnabled false. Deploy updated Inventory config/API and new
server service; run server-console `refresh` before `restart feather-inventory`
(new script discovered through services wildcard). Wait for Inventory readiness,
then server-console `InvCharacterAmmoTxSmokeTest 1` using connected test player ID.

The command creates the two empty production ledger tables if absent. It refuses
an already-enrolled character. Inside one transaction it inserts a disposable
ledger, adds one temporary Regular ammo item, exercises load, receipt retry,
changed-input refusal and unload, then deliberately rolls back. It verifies
quantity equality and no ledger/receipt left. No native loadout changes or grants
are published. One round's slot/weight capacity is required. Expected5/5 PASS.
On failure, stop and inspect; do not enable the migration gate. Actual committed
receipt replay across restart, concurrency and failure injection remain later
gates. The smoke's same-transaction retry is not a durable-restart proof.

## Committed receipt fixture gate

Deploy Inventory's new character_ammunition_replay_test service; refresh then
restart Inventory with Weapons stopped. Console:
`InvCharacterAmmoReplaySmokeTest prepare`. This creates three dedicated
fi_ammo_smoke_* tables and commits a reserved fixture only: loose7, carried5,
revision1, receipts1. No real character/items/native state is used. After a PASS,
restart Inventory again, then `InvCharacterAmmoReplaySmokeTest verify`.
Expected5/5 verifies stored receipt replay, changed request rejection, stale
revision rejection and exact conserved fixture counts. Do not prepare again to
fix a failure: preserve evidence. Finally `InvCharacterAmmoReplaySmokeTest cleanup`
removes only reserved fixture rows; empty test tables stay. These are disposable
test rows, recoverable by preparing a new test, not real ammunition. Migration
gate stays false. This test does not replace real-inventory concurrency testing.

After cleanup passes, deploy updated existing replay-test script, restart
Inventory and run `InvCharacterAmmoReplaySmokeTest concurrent` without prepare.
It creates fresh fixture data and runs same-ID duplicate requests and competing
revision requests in parallel, holding the fixture header100ms per transaction
to exercise overlap. It then forces rollback after ledger/receipt writes.
Expected5/5 and final fixture loose6/carried6/revision2/receipts2. On timeout do
not cleanup or retry until workers settle; preserve evidence. On success use
cleanup separately. All concurrent work is confined to dedicated fixture tables.
