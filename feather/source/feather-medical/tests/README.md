# Medical lifecycle checks

Run `lua tests/run.lua` from the Medical repository root (Lua 5.4).
The aggregate runner includes the persisted client lifecycle regression. The
observer input harness loads lifecycle before observer, matching the manifest,
and uses session-bound condition snapshots; it still tests input without the
former standalone MedicalInput helper.
Tests exercise episode deduplication, configurable lethal handling, offline
deadlines, explicit doctor eligibility and stale recovery rejection.
The storage harness also checks migration reruns/drift/failure and transactional
rollback on outbox failure using a mock database. It does not prove real database
transactions, authorization, networking or native behavior.

Live test: `MedicalStorageSmokeTest` in the server console after starting Medical.
No player required. See the resource README for setup, expected output and cleanup.

Live acceptance recorded 2026-10-02: user reported 10/10 passed and cleanup=ok
on the running server. Resource restart/rerun, checksum drift against a real
database, concurrent mutations and crash/unknown-outcome handling remain pending.

The requested restart/rerun also returned 10/10 with cleanup=ok. The separate
pending-episode test is now `MedicalPersistenceSmokeTest seed | check | cleanup`;
follow the stop/wait/start sequence in the resource README. It needs no player
and runs in the server console. Live acceptance passed 7/7 with cleanup=ok on
2026-10-02: Medical stopped before the saved deadline and restarted after it;
the worker persisted death while preserving the original episode/doctor deadline.
This validates orderly resource downtime, not process-crash/unknown-commit recovery.
Worker harness checks cover per-row failure isolation and server time/event IDs.

Recovery/service harnesses cover deadline enforcement, captured destinations,
duplicate operations/acks, failed-outbox rollback, mid-write session changes,
nonpersistent activation reset, policy denial/failure and delivery binding.
Run `node tests/web_spec.cjs` from the resource root for the recovery UI behavior
check. Countdown expiry must not submit a request; the UI is a passive configurable
key prompt with no clickable button or fetch handler. The Lua input gate ignores
early presses, in-flight/pending recovery, and input while another NUI is focused.
Only the configured key sends the empty server request. Native behavior, passive
UI presentation and Admin integration still need the
solo gameplay acceptance in the README/master plan; use F8 for MedicalStatus and
the server console for MedicalRevive. No second player is required for that gate.

Live gameplay acceptance on 2026-10-02: user confirmed Character activation,
grounded player-requested respawn and retained death after logout to selection
and reactivation. Separate male/female appearance, staff/Admin recovery,
countdown expiry without clicking, network reconnect and active-death resource
restart remain pending; do not infer them from this report.

Subsequent live acceptance: normal Admin revive works after the countdown panel
stopped taking NUI focus (2026-10-02). Configured E-key respawn and countdown
expiry without pressing the key still need explicit live acceptance.

After the reported dead-ped E failure, added a mock-client input integration
harness: eligible control enablement, recovery route dispatch, other-NUI focus
protection and early-key rejection. It does not prove real dead-ped input.
MedicalStatus prints input gates; MedicalRespawn exercises the same guarded
request from F8 for diagnosis. Native errors and server rejection codes are logged.

Live logs then identified a nil MedicalInput global. The gate now lives inside
observer.lua; there is no separate helper file/manifest entry. The integration
harness explicitly starts with MedicalInput nil and exercises the actual observer
through control enablement and server dispatch. The old standalone helper test
was removed with that helper. User subsequently reported E-key recovery working
on 2026-10-02. Countdown expiry without input, separate male/female appearance,
network reconnect and Medical restart while dead still require explicit acceptance.

Latest live report (2026-10-02): countdown expiry without pressing the key keeps
the character dead; relog persistence and both genders work. These gates are now
accepted in the master plan. Active-death Medical restart, interrupted recovery
and stale-session/source-reuse remain pending.

User subsequently confirmed repeated Medical reloads while dead preserve death
and respawn works afterward. Active-death restart is accepted; interruption during
an authorized recovery, exact deadline comparison and stale-session/source-reuse
are still separate checks.

Recovery hardening adds session-specific acknowledgement tokens, observation
revision guards, lost-commit-reply retry reconciliation, captured nearest-hospital
destinations, Core restart generation guards and strict outbox publication checks.
Mocks cover these rules; they do not establish runtime interruption behavior.

New server-console diagnostics require no player: MedicalOutboxSmokeTest expects
2/2 with cleanup after one intentional listener failure; MedicalRecoverySmokeTest
seed, restart feather-medical, then MedicalRecoverySmokeTest check expects 6/6
with cleanup. Keep Character/Core running. Recovery uses reserved disposable
smoke:recovery:v1 records and preserves failed checks for retry or explicit cleanup.
Follow with solo E/Admin acceptance on the updated token protocol. Hospital
coordinates and nearest-location placement acceptance remain pending owner input.

Live acceptance (2026-10-06): outbox 2/2 and pending-recovery restart 6/6,
cleanup=ok for both. User then enabled gameplay and confirmed respawn/ground
placement across all six hospital locations and surrounding areas, plus normal
Admin revive. Per-location gender/appearance audits and advanced interruption/
multiplayer scenarios were not separately reported.

Config/export cutover: 121 Lua harness checks passed, including 24 checks for
absent, stopped, starting, invalid, throwing, disabled and ready Medical across
Character/server Admin/client Admin policies. Changed-file Lua syntax, UI check
and whitespace checks passed. Live config-only install retest remains required.
