# Scoped all-owner shutdown preparation

Implemented 2026-10-17; live aggregate drain through ready accepted: two individual
release PASS logs followed by aggregate completed2/total2 PASS and status ready.
Post-drain restart restoration also accepted: Jane two copies/ledger35/repeater1,
112rev2 and134rev8 with prior wear; John one copy/ledger2/revolver1,155rev1
with prior wear. Both ACTIVE idle under fresh epochs; no success-path retest
needed. Live failure paths remain unaccepted. This reuses the existing
per-owner release, final ammo seal, maintenance CAS and cleanup protocol.
It is an operator-invoked drain, not an automatic txAdmin shutdown hook.

## Commands

Server console only, no arguments:

```text
WeaponNativePrepareStopAll
WeaponNativeShutdownStatus
```

The first command permanently latches new dispatcher starts and non-shutdown
equipment/repair/attachment/maintenance intents for this resource lifetime.
It snapshots up to two configured, connected native owners, preflights both,
then requests their existing shutdown transitions sequentially. Already
confirmed parked owners are counted without another write/release request.
Empty equipped loadouts still require an acknowledged owner release.

Aggregate PASS requires every captured owner to be parked with confirmed commit
outcome and the exact roster/character/session/epoch still present. Monitoring
continues after PASS; later roster or release-authority changes invalidate it.
Unresolved connected Core sessions, busy/missing/frozen owners, roster changes,
disconnects, identity changes, refusal, exceptions or a 90-second deadline fail
closed. No automatic retries, economic replay, refund, rollback, resource stop,
server restart or admission reset is provided. A failure can leave some owners
already parked. Do not stop/retry or infer cleanup after failure; retain logs
and inspect the scoped recovery/transition state before deciding recovery.

This covers configured connected owners, not a proof that previously disconnected
unresolved holds are drained. It does not intercept arbitrary resource stops,
process crashes or already-running ammo operations. An in-flight operation can
make preflight/release refuse; this is not silent cancellation or SQL rollback.

## Deployment and live gate

Only new runtime delta in Weapons:
`server/services/native_equipment_transition.lua` (existing file).
No manifest, config, client, Inventory or Admin change; no refresh needed.
Preserve previously deployed controlled-enrollment configuration and dispatcher
Start guard. Tests are not deployment files.

To install safely on the old version, with current IDs Jane1/John2:

1. Run `WeaponNativePrepareStop 2`, wait PASS.
2. Run `WeaponNativePrepareStop 1`, wait PASS.
3. Stop Weapons, copy the runtime file, ensure Weapons.
4. Both players must be alive/connected/idle with restored ACTIVE statuses.
   Do not fire, move items, change equipment, disconnect or open another character.
5. Run `WeaponNativePrepareStopAll` once. Wait for aggregate
   `[WeaponNativePrepareStopAll] PASS ... completed=2 total=2`.
   Individual PrepareStop PASS logs alone do not satisfy the aggregate gate.
6. Read `WeaponNativeShutdownStatus`; expect phase ready, completed2,total2.
   On FAIL/REFUSED, stop the test and share output; do not stop the resource.
7. After aggregate PASS and no subsequent FAIL, stop/ensure Weapons and read both
   client status and maintenance outputs. Jane should retain ledger35/repeater1,
   items112rev2/134rev8 and prior wear. John should retain ledger2/revolver1,
   item155rev1 and prior wear (soot0.005/degradation0.00333333341404).
   Normal additional real gameplay wear must be evaluated from actual snapshots.

Human operates two desks independently; no simultaneous action required.
Do not repeat grants, shots, death probes or fixture operations for this gate.

Automated coverage: pure orchestrator sequential confirmation, no waiting retry,
already prepared owners, drift/new owner/disconnect, refusal/exception, busy/frozen,
timeout/late adapter completion, readiness invalidation and concrete console/
argument gates, dispatcher admission latch and release-refusal retention.
132 Lua specs plus runtime syntax and 7 Node tests pass. Native/SQL boundaries
remain mocked in these regressions; no live aggregate drain claim yet.
