# Medical integration and validation notes

These notes are for developers. Server owners should start with the README.

## Recovery and restarts

Medical writes an episode and its deadlines once. Duplicate death observations
cannot extend the timer. Offline bleedout uses stored UTC deadlines. Restarting
Medical while a player is dead preserves death and the original episode.

A recovery request creates one durable operation for the episode. The current
session receives a delivery token, Character applies the same-ped recovery, and
Medical completes the operation after acknowledgement. After interruption,
pending operations are delivered again with the saved destination. New sessions
and Medical reloads get new tokens; old acknowledgements cannot complete a new
delivery. Duplicate completions do not add another recovery transition. A delayed
observation based on an old condition revision cannot undo a newer recovery.

Medical re-registers its event/routes after Core restarts and blocks gameplay while
Core is unavailable. Core owns sessions: players must reconnect if Core restarts.
Do not restart Core as part of an ordinary Medical update.

## Commands and troubleshooting

| Command | Where | Purpose |
|---|---|---|
| `MedicalHealth` | Server console | Startup state, policy, hospital count and pending transition count. |
| `MedicalRevive <server ID>` | Server console | Authorize in-place staff recovery for a current world-ready character. |
| `MedicalStatus` | F8, active character | Own condition plus key/deadline/focus diagnostics. |
| `MedicalRespawn` | F8, active character | Diagnostic request using the same timer/session/focus guards as the key. |

Normal Admin revive retains Admin permission and hierarchy checks. When integrated
Medical is enabled, Admin never falls back to an untracked direct revive if
Medical is unavailable. An authorized operation request is not proof that the
client applied it; check the resulting status/visible recovery.

- **Character activation fails:** send the server startup output and
  `PrepareCharacter`/`Medical preparation failed` lines. Missing condition with
  history or corrupt records require investigation/backup restoration, not a reset.
- **Key does nothing:** close F8/Admin, wait for the prompt, press the configured
  key. If it fails, run MedicalStatus in F8 and send its input gates and recovery
  error. Copy the complete resource and refresh/restart after manifest changes.
- **Respawn unavailable:** check the server delay, active session, hospitals and
  fallback settings. A captured invalid/unsafe destination needs investigation;
  changing config does not rewrite an already pending operation.
- **Floating or ground failure:** inspect the saved hospital coordinates and
  collision. Character grounds the resurrected ped; placement failure does not
  acknowledge recovery. Validate the location before releasing it.
- **Transition backlog:** MedicalHealth shows pendingTransitions. Inspect Core
  listener errors and Medical publication warnings. Delivery retries; consumers
  must handle duplicate event IDs. Do not delete the outbox to silence errors.

## Acceptance and diagnostics

Live acceptance already covers the normal death/E-respawn loop, proper ground
placement, waiting past zero without automatic revival, normal Admin revive,
relog persistence, both genders and repeated Medical reloads while dead.

For the new hardening/outbox checks, **no player is required**. Run in the server
console after copying/refreshing/restarting Medical with updated Character running:

```text
MedicalOutboxSmokeTest
MedicalRecoverySmokeTest seed
restart feather-medical
MedicalRecoverySmokeTest check
```

Expect `done 2/2 passed; cleanup=ok` for outbox, and `done 6/6 passed; cleanup=ok`
for recovery. Outbox intentionally makes its first test listener fail; one Core
listener-error log is expected before stable-ID replay succeeds. These commands
use disposable `smoke:*` Medical records, never real player characters. Recovery
failures retain the reserved test records for inspection/retry; use
`MedicalRecoverySmokeTest cleanup` to remove only those test records. An outbox
cleanup failure prints its exact event ID. Existing storage diagnostics remain
`MedicalStorageSmokeTest` and `MedicalPersistenceSmokeTest seed|check|cleanup`.

These checks establish real storage/publication behavior, not client-native or
network interruption acceptance. Follow with a solo normal E/Admin recovery test
on the updated token protocol. The six hospitals and surrounding areas passed user-reported respawn/ground
placement testing on 2026-10-06. Normal Admin revive also passed on the updated
protocol. Outbox 2/2 and pending-recovery restart 6/6 passed with cleanup=ok. Runtime process-crash/unknown-commit and two-client stale packet tests
remain separate acceptance gates; offline mocks do not prove those scenarios.

## Boundaries and integrations

### Weapons condition reader (0.1.1 follow-up)

Server export `ReadNativeWeaponCondition(source, context)` is restricted to
`feather-weapons`. Supply a positive integer player source and the current
`characterId`/`sessionId`. Medical checks Core and Character readiness both before
and after reading storage, then returns `{ok=true,value=snapshot}`. Rejections
return `{ok=false,code=...}`: `forbidden`, `stale_session`,
`storage_unavailable`, or `condition_missing`.

This reader never initializes missing records, advances deadlines, authorizes
recovery or writes life state. It does not transfer Medical authority to Weapons.
The gameplay harness covers caller/input rejection, disabled Medical, stale
sessions (including changes during storage), missing conditions, storage errors
and unchanged lifecycle-write counters. The full Lua 5.4 aggregate suite and
Node UI check passed during PR preparation on 2026-10-14. Reported live Weapons
death-final-wear/doctor recovery acceptance is recorded in the framework Medical
master plan; interrupted recovery and multiplayer races remain separate gates.

Medical owns life state, episodes and recovery. Status owns metabolism. Character
owns appearance and ped placement. Loot access is deferred; this resource does not
enable looting or tied-player access. Incapacitated mode currently uses the proven
native-dead ped during a logical recovery window; living unconscious animations
and injury/ailment treatment are not implemented by this slice.

Physical death is client-observed. A modified client can conceal/fabricate its own
physical state or application acknowledgement. The server owns the persisted
condition, transitions, deadlines and authorized recovery; RedM's tested server
health getters are not proof of physical death. This trust limit is explicit.

`medical.condition.changed.v1` is a **server-only Core broker event** published
from the committed outbox. It contains stable eventId, characterId, optional
episodeId, revision, lifeState, reason and occurredAt; it contains no private injury
or appearance data. Delivery is **at least once**. Consumers must deduplicate
by eventId (durably when their side effects are durable) and use revision to reject
stale facts. A publication mark can be lost after delivery, causing replay. A
failing listener retains the fact for retry before later revisions of that
character. Other characters can continue. Core publication with zero subscribers
counts as published; late subscribers must read current state rather than expect
historical replay. The disposable diagnostics emit smoke:* character IDs; consumers
must not treat those as real Core characters.

For development, run `lua tests/run.lua` (Lua 5.4) and
`node tests/web_spec.cjs` from this resource root. Local validation was run using
Lua 5.1-compatible harnesses; it does not replace live Cfx/MariaDB acceptance.
See the framework-docs Medical master plan for the checked implementation guide
and research findings.

Configuration now uses ordinary Config.medical fields. Server GetHealth includes
enabled and readiness; client GetHealth exposes enabled for Admin legacy revive
guards. Missing resource permits legacy behavior; any installed non-started state
or invalid export fails closed. Explicit false permits legacy behavior only while
Medical is started and returns a valid health response. Old convars are ignored.
