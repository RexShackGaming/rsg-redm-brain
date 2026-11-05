# Abnormal connection loss — last durable snapshot

2026-10-14 LIVE confirmed-commit/pending-transfer disconnect gate ACCEPTED. One-use automatic scoped disconnect logged COMMIT confirmed then PASS old session retired with transfer pending before completion. New source3/sessionbcf0d7a4-c81c-11f1-9ae2-e0d55eaa2deb restored ledger32/carried Regular1/one pristine112rev1. Prior source2 acknowledged31/pendingOperation transfer/providerOutcome confirmed/unresolvedPersistence true/retired_unreleased, no invented final observation/native cleanup/adoption/economic replay. Explicit unload cleanup confirmed ledger33/all carried0/active idle one owned copy; temporary convar0 confirmed. No new durable full-row audit was captured for this gate; acceptance is scoped to provider commit log/runtime/session/native readbacks, not a full receipt/material SQL audit. Temporary delay/drop command and runtime machinery removed locally; production recovery coroutine regressions retained and full Lua suite passes. Cleanup deployment pending: Weapons ONLY server/services/character_ammunition_runtime.lua; prepare-stop current source3/PASS, stop/copy/ensure, no refresh/new flags/repeat economic test. Forced crash, pre-commit actual SQL interruption and multiplayer remain separate.

2026-10-14 delayed-reply live attempt NOT accepted: hook armed/COMMIT/30second hold/end logged, reconnect restored112rev1/ledger30/carried1, but prior had acknowledged30/phase restoring/no pending persistence; server retirement occurred after completion. Cleanup unload confirmed31/all carried0/one active copy. Timing correction implemented/automatically tested: console arm optional literal disconnect mode, same default-off convar; after confirmed transfer exact current source/session/epoch/bound recheck, DropPlayer only scoped owner, hold until matching actual runtime retirement with pending transfer (bounded60seconds). Logs PASS only if that evidence observed; timeout refuses test acceptance. No synthetic session retirement or SQL/replay/native changes. Full Weapons Lua suite passes. Live corrected gate pending. Deploy ONLY Weapons server/services/character_ammunition_runtime.lua (existing file/no refresh); preserve flags, temporary feather_native_delay_reply1; WeaponNativeDelayNextTransferReply current-id disconnect then UI load1 existing round. Expected new session112rev1/ledger32/carried1 and prior lastAcknowledged31/pendingOperation transfer/providerOutcome confirmed/unresolvedPersistence true/no cleanup claim. Disable convar, unload1 after verification; no repeat settled matrix.

2026-10-14 live delayed-transfer-reply gate PREPARED, not accepted. Default-off feather_native_delay_reply=1 plus console-only WeaponNativeDelayNextTransferReply current-id arms one exact configured-character/current-session/epoch transfer. Arm consumed before provider call; only confirmed Inventory response is held30seconds before ordinary runtime completion. No SQL/native mutation added, no simulated provider result, no retry/refund, no net arm route; session revocation clears unused arm. Actual hook coroutine test confirms durable transfer then old-session disconnect/new-session reconstruction rejects late completion without changing fresh owner. Full Weapons Lua suite passes. Deploy only server/services/character_ammunition_runtime.lua; existing file, no refresh. Preserve all flags except temporary convar, disable after test. Live test uses one existing loose regular round: arm then UI load1, on COMMIT-confirmed hold log exit RedM without logout; reconnect and inspect new session/ledger30/carried1/item112rev1 and old pending transfer evidence. Capture fresh read-only audit after rejoin; after hold ends verify no additional economic mutation, then unload1 cleanup. Pre-load audit cannot claim ammoUnchanged across intentional load. This tests post-commit reply interruption, not pre-commit SQL rollback or process crash.

2026-10-14 deterministic in-flight recovery coverage extended and PASS: real coroutine suspension before provider commit and after durable commit/before reply; old session retires, same numeric source restores fresh session before old reply resumes. Pre-commit authority loss refuses mutation; post-commit SQL state reconstructs once; late old reply cannot acknowledge/freeze/replace/mutate fresh runtime or replay economics. Full Weapons Lua suite and diff check pass. Test-only change, no runtime deployment/flags. This is mocked provider boundary coverage, NOT actual SQL fault-injection acceptance. A deterministic live delayed-reply gate needs a narrowly scoped provider test hook; random disconnect timing is not sufficient evidence.

2026-10-14 LIVE settled funded full server-process restart ACCEPTED. Before restart original112 revision1/ledger28/Regular carried1 captured; after operator restart preserving database/audit, fresh Core session6a2c1f35-c818-11f1-9ae2-e0d55eaa2deb/source1 reconstructed one pristine112rev1 and ledger28/carried1. Recovery contracts all1; economicReplay=false/nativeAdoption=false; transient prior history absent as expected after server memory loss. SELECT-only verify-wear PASS changed=false/revision1/materialConsumed0/ammoUnchanged=true/equipmentUnchanged=true. Explicit unload cleanup confirmed ledger29/all27 carried pools0, active idle one owned copy. Loose2 expected from unload, not independently SQL-read back. This accepts settled process restart only, NOT forced crash, in-flight SQL interruption, unreported shot/wear recovery or abrupt funded same-session resource hot-stop. No runtime deployment/config change or repeat accepted gate required.

2026-10-14 next focused gate prepared: full server-process restart with settled funded SQL snapshot. Added automated service restart case discarding runtime/retirement memory while retaining provider state: funded reconstruction performs no economic mutation, prior history stays absent (not inferred cleanup), old session reports refuse. Full Weapons Lua suite passes. No runtime code/file/config changes. Live process restart remains pending and requires an operator-controlled alpha server restart; not an in-flight SQL crash or abrupt same-session resource hot-stop claim.

2026-10-14 LIVE funded connection-loss/rejoin gate ACCEPTED. Original112 revision1 pristine, ledger26/carried Regular1 reconstructed under new Core session998db792-c815-11f1-9ae2-e0d55eaa2deb/current source2 after old source1/session25bd2f04-c813-11f1-9ae2-e0d55eaa2deb dropped. All four recovery contracts1; prior reason player_dropped/kind retired_unreleased/nativeCleanupConfirmed=false/finalObservationInvented=false/unresolvedPersistence=false. No economic replay or native adoption. SELECT-only verify-wear PASS changed=false/revision1/equipmentUnchanged=true/ammoUnchanged=true/materialConsumed0. Explicit UI unload then confirmed ledger27/all carried pools0, one active idle owned copy. Loose2 is expected from the unload, not independently SQL-read back here. Periodic helper cleanup/original restoration already user-confirmed. This closes only settled funded disconnect recovery; process/server crash, in-flight live SQL loss, abrupt funded hot-stop, multiplayer, general enrollment, attachments/broken policy and GUID permanent-wear support remain separate. No repeat accepted gate, runtime deployment or config change needed.

2026-10-14: recovery hardening implemented and automatically tested; live funded
disconnect/rejoin acceptance pending. Existing scoped development gates are reused.
There is no new config flag, database schema, item/ammo grant or recovery mutation.

## Policy and limitations

Reconnect reconstructs only the fresh Inventory-owned SQL snapshot. It never
replays a lost economic intent, refunds an acknowledged reduction, invents a
final observation, adopts untracked weapons or blanket-removes ped weapons.
Client observations not committed before connection loss cannot be reconstructed;
periodic wear reduces this window, not eliminates it. This is not exactly-once
recovery of unreported shots/wear, nor live process/server-crash acceptance.

Core must independently confirm the new current session and that old relevant
sessions are no longer current. Only then may obsolete server reservations be
retired. No same-session frozen/parked transition is thawed. Old native cleanup is
not inferred from a server detach; target native creation retains its preexisting
weapon refusal. Scope changes never weaken client-owned entity checks.

Dispatcher now binds its opening Core session before the Inventory snapshot can
yield. Matching cancellation invalidates that opening; late old-session events
cannot erase a different new opening. Service opening reservations/loadout holds,
dispatcher state and equipment/read/UI/periodic/shutdown reservations retire by
session, not merely recycled numeric source ID. Pending SQL contexts become stale;
late replies cannot grant/rebuild onto a newer session. Retired transition evidence
is retained in memory and never used as an economic replay instruction.

Diagnostic retirement records show last acknowledged ledger revision, prior phase,
pending operation and provider-reported confirmed/refused/pending/uncertain outcome.
Those are not substitutes for the reconnect SQL snapshot: a committed write whose
reply was lost is restored from SQL, without replay or refund. Records are transient;
server restart can have no prior history. WeaponNativeRecoveryStatus current-id
reports the startup SQL snapshot, current acknowledged baseline, old history if any,
and four contract markers (runtime/dispatch/activation/transitions), all1.

## Automated evidence

Full Weapons Lua suite/7 Node checks pass. Added service tests cover source reuse,
retired holds, current-session refusal, late old reports/events, provider refusal
and commit-before-lost-reply restoration without a second mutation. Dispatcher
coroutine tests bind opening identity across cancellation; concrete activation
tests prevent late old timers/restore acknowledgments from changing the new owner.
Transition tests retire only Core-expired sessions and prevent a late commit reply
from rebuilding onto a new source. These are mocks/coroutine checks, not live crash
proof. Accepted stop/logout/death/periodic gates are not reopened.

## Runtime deployment — Weapons only

```text
shared/character_ammunition_runtime.lua
shared/character_ammunition_dispatch.lua
server/services/character_ammunition_runtime.lua
server/services/character_ammunition_dispatch.lua
server/services/native_equipment_transition.lua
```

Copy all five existing files. No client/UI/Inventory/Medical/Character/Admin,
config or manifest changes; no refresh. Preserve scoped native/lifecycle/periodic
flags, keep temporary helper/self-kill/repair disabled. Prepare-stop current-id,
wait PASS, stop Weapons, copy files, ensure Weapons. First check RecoveryStatus
contracts all1 and original112rev1; do not begin loss test with incomplete deploy.

## One focused live gate

1. Original112 equipped, one native copy, pristine wear, carried0/loose2/ledger25
   are the last accepted setup. Confirm actual current values before proceeding.
2. Through existing ammunition UI, load exactly one existing loose regular round.
   No grant, shooting, oil or fixture input. Confirm carried1/loose1 and durable
   ledger26 (use actual resulting revision, do not substitute assumptions).
3. Retain the completed periodic wear audit by renaming its private JSON file to
   .native-wear-audit-<Jane>.completed-periodic-rev7.json. Capture fresh wear audit
   for item112 AFTER the load, so conservation comparison includes funded state.
4. Completely exit/close RedM without logout, prepare-stop, unloading or restarting
   Weapons/server. Wait for server playerDropped/session-left, then reconnect and
   select Jane. This loses the connection instead of using voluntary checkpoint.
5. Read native status/maintenance and server RecoveryStatus using current player
   ID (may change). Expect a new Core session/epoch, one original112rev1, same
   durable carried1 and ledger26, pristine wear. Recovery prior can report an
   unreleased old owner, but must not claim native cleanup or economic replay.
6. SELECT-only InvNativeRepairAudit current-id Jane 112 verify-wear: changed=false,
   item revision1, materialConsumed0, equipment/ammo/other items/receipts unchanged.
7. Unload exactly one existing round through the UI to return carried0/loose2;
   that explicit unload is a new normal economic operation, not recovery replay.

Do not add a dirt helper or repeat firearm families. In-flight SQL loss, abrupt
funded resource hot-stop, real server/process crash and multiplayer contention
remain separate live coverage gaps even if this connection-loss gate passes.
Alpha rebuilds invalidate old item IDs and private baselines; no production fixture
migration or synthetic restored-state grant is needed.
