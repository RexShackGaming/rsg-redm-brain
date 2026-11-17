# Throwable world recovery: decompiled reference findings

Reviewed 2026-11-12. Reference files are under
`C:/coding/rdr2-scripts-decompiled/1491.50/`. These are implementation clues from
that game build, not verified RedM runtime observations or server authority.
No decompiled source is copied into the resource runtime.

## Targeted pickup identification

`script_mp_rel/fm_deathmatch_controller.ysc.c`, `func_240`, lines 21865 onward,
switches local pickup permission for `w_melee_tomahawk01` and
`w_melee_tomahawk02`. `fm_race_controller` and `fm_mission_controller` use the
same pattern. This identifies two candidate model names without treating every
nearby object as a throwable. It does not independently assign each model to a
specific Inventory definition, identify the thrower, or establish a paid unit.

The same deathmatch script maps `weapon_thrown_tomahawk` to
`pickup_weapon_thrown_tomahawk_mp` at line 39058. Pickup type, weapon hash and
object model are separate identifiers. Never interchange them.

The local pickup-permission native is a potential means of reserving collection
before payment/custody confirmation. This is a design lead only: the new probe
does not change that permission or enable projectile hit listeners.

## Separate event layouts

`script_mp_rel/fm_race_controller.ysc.c`, event switch near 15454 and `func_256`
at 19915, reads network queue 1, event hash -454144443, eight script slots.
The function uses slot 0 as a pickup handle, slot 1 as a player index, slot 2 as
pickup type, and slot 4 as model. Other slots stay raw in our diagnostic.

`script_mp_rel/short_update.ysc.c`, `func_83` near 2915 and `func_377` at 14601,
reads AI queue 0, event hash -178091376, also eight slots. Its slot 0 is a pickup
type, and slot 7 is an Inventory item hash. The layouts must never be conflated.
In particular, the AI slot 0 must not be used as a world object handle.

`GET_EVENT_DATA` takes a number of RAGE slots, not bytes. Each slot occupies
eight bytes, so the diagnostic allocates 64 bytes and passes 8 as the native size.
Only low 32-bit integer fields used above are interpreted; unknown fields are
retained as raw values. Neither pickup handles nor local player indices are
server entity handles or server player IDs.

`script_mp_rel/fme_archery.ysc.c`, `func_532` near 13174 and `func_790` at 18074,
reads projectile-hit event -2036121834 as six slots. Its handler checks the
shooter and weapon, then uses the hit entity/coordinates. That supplies a lead
for impact observation, not the missing projectile network ID. It is not
registered or decoded by the new pickup-only probe.

## Implemented diagnostic and collector components

`shared/native_throwable_event_reference.lua` contains the two distinct
build 1491 pickup profiles. Unsupported builds, queue/hash mismatches and wrong
buffer sizes refuse decoding. `client/native_throwable_event_probe.lua` captures
only Tomahawk-related matching events under its explicit default-off diagnostic
convar. It runs at most 30 seconds/3600 frames, reads at most 64 events per queue
per frame, retains at most 32 matching records and stops after 16 failed native
reads. Owner/session/epoch changes terminate the capture. It has no network
send, object deletion, pickup permission changes, native grants or SQL writes.
No diagnostic result grants recovery authority.

The collector receipt validator checks exactly one added paid unit, consecutive
ledger revision, full unchanged foreign ammunition pools, unchanged existing
units, matching collector identity and the exact durable custody snapshot.
Loadout lease adoption rejects aliases with firearms, melee, knife or utilities.
The native owner/adapter can recapture the already collected unique Tomahawk
inventory GUID from empty or partially funded custody, including a new lowest-ID
anchor, without a weapon/ammo grant. These methods are not yet connected to a
physical pickup route or world authority; old carrier recovery cannot invoke them.

## Evidence still required

A live capture must show whether native thrown-object recovery emits these
pickup events on the installed build and whether the pickup handle can be linked
to a server-observed world lifetime. Multiplayer shared pickup also needs the
server's current collector/session, bucket/proximity, single-claim reservation,
durable transaction and exact native acknowledgement. A native quantity increase,
model match or client event alone is insufficient. No live engine acceptance or
normal throwable feature activation has occurred.

Source fingerprints (SHA256):

- fm_race_controller:0081CDF586E120FC7AE1FA2B274D2FAA5EEFF8F22BA669264569BEAEAF8F7F1C
- short_update:DCF3ED2ADBCECA52D48B29E0A84078FD51EBB3094B71472B67F6D411D233055A
- fm_deathmatch_controller:731237E6FDE67C1ADC151DA00F31B6C52D6C2BC74F3DEA3946B67358D22AC252
- fme_archery:C31195975A8BF97C56FE3437C1822E36979176EE91FF53BC7A6E392F192CBBB3


2026-11-12 isolated throwable loan fixture (staged, not wired or deployed):
Added client/native_throwable_loan_test.lua as a dependency-injected one-unit
native diagnostic. It composes the real physical throwable owner for creation,
throw observation, read-only pickup GUID recapture and exact owned cleanup.
Synthetic identities/receipts remain internal to the fixture; it has no SQL,
Inventory issuance, saved equipment or ammunition-ledger writes. A zero ped
quantity does not prove a thrown world object was cleaned. An uncollected unit,
changed session, failed recapture, altered foreign pool or uncertain native
cleanup leaves the result review_required without automatic retry. Cancel and
presentation failures do not suppress same-context exact compensation.

Validation: all 250 isolated Weapons Lua specs and runtime syntax passed. The
new spec composes the actual throwable owner with modeled native ports and
covers successful recapture, cancellation, timeout, missing pickup events,
creation/recapture/cleanup failure, context loss and foreign pool changes.
This is not live engine validation or paid pickup authority. The helper is not
manifest-listed and has no command/event admission yet. Remaining next step:
wire the server-challenged release/rebuild reservation, bounded event capture
and narrow temporary firing allowance, then package the reviewed PowerShell
batch. No deployment or server commands are required for this staged step.


2026-11-12 isolated live-test admission and batch prepared (not deployed):
WeaponGuidAcceptance throwable [current-server-id] now reserves the existing
console-only, opt-in GUID acceptance release/rebuild flow for exactly one
connected player. It audits saved/client state before release and after fresh
restoration, executes one temporary native Tomahawk case and persists bounded
report packets before acknowledging them. Report resends never rerun creation.
The loan has no item issuance or Inventory/equipment/ammunition-ledger writes.
It records build1491 pickup events/target evidence during the released-owner
window. These are diagnostic observations, not shared pickup authority.

The normal firing block has one local exception: the matching closed-owner,
alive/current session/ped, noncancelled loan waiting for its one throw within
90seconds and with exactly one native unit. The exception expires on throw,
reporting, context loss, timeout or callback exception. The retired proof
resource may be missing or stopped for this reserved test; running proof
resources still refuse admission. Normal throwable purchases remain disabled.

Validation: 251 isolated Lua specs plus runtime syntax pass. Tests cover actual
throwable-owner composition, command/session/source/ticket admission, duplicate
challenge refusal, bounded firing, report-only acknowledgement, missing retired
proof, one-player admission, state audit/restoration and retained failures.
Native/file/network ports remain modeled: no live throw/pickup test is claimed.

Prepared C:/coding/deployments/throwable-world-capture-2026-11-12 with one
PowerShell installer, SHA256 manifest and104 Weapons runtime files. Excludes
config.lua, shop_config.lua, tests, docs, development fixtures, reports and git.
Disposable local installation verified validation, backup/install, repeat
idempotence, configuration preservation, unknown destination drift refusal and
altered source refusal. Destination text hashes tolerate CRLF/LF only; payload
hashes remain exact. No server files or database were changed.

Deployment requires all clients disconnected and feather-weapons stopped for
installation (-ResourceStopped), then refresh and ensure feather-weapons (new
manifest script). No full server restart, config edits or database steps required.
Live test remains pending. If the unit is thrown but not recovered, report
review_required and retain unresolved world evidence rather than certify cleanup
or automatically restore over it. Shared world lifetime correlation, paid claim
reservation/commit/native acknowledgement, ownership delivery and retirement
remain pending; this diagnostic does not complete normal throwable gameplay.


2026-11-12 first isolated live Tomahawk result (user supplied): native throw,
pool return, GUID recapture and cleanup completed, original loadout restored;
report review_required/pickup_events_not_observed, passed0/1. Build1491 probe
ran2350frames with zero read failures and zero records. Do not record this as
pickup-event or shared recovery acceptance. No Inventory grants occurred.

Capture v2 implementation: keep the same diagnostic open750ms after successful
native pickup to observe later-frame events. Separate bounded world evidence
from pickup events so a nearby object cannot manufacture a test pass. During
only the released loan's awaiting_pickup stage, snapshot at most512 recent
CObject entries twice per second, retain up to6 nearby detached known Tomahawk
models, and report scan errors/partial pools explicitly. Read-only
pickup/projectile/collection gameEventTriggered messages retain up to8 numeric
slots; neither engine messages nor object/model matches establish origin or
paid pickup authority. No pickup permissions or normal gameplay gates changed.

Validation:251 isolated Weapons Lua specs and runtime syntax pass, including
late events, object-only refusal, bounded object snapshots, detached filtering,
engine-event argument bounds and stopping. Prepared the separate immutable
C:/coding/deployments/throwable-world-capture-v2-2026-11-12 batch. Three runtime
files changed from the prior104-file batch; configs and saved reports excluded.
Live v2 capture remains pending. Archive the independently cleaned/restored v1
report before the new explicit test; do not repeat an unresolved native loan.


2026-11-12 user-confirmed live capture v2: complete1/1, cleanupComplete=true,
restored=true, no automatic mutation or report-delivery retries. Build1491,
941frames, five bounded object scans, zero read/scan failures; objectPoolPartial
true, so the diagnostic was not an exhaustive object inventory. At10037ms it
observed a detached networked Tomahawk model3358573347, client entity540162,
networkId16. At12537ms it observed AI pickup event-178091376 with raw slots
[-897823490,1,16,-936393949,0,363259472,1,-1511427369]. Native throw/pickup,
GUID recapture, exact cleanup and original-loadout restoration are live-proven
for this one isolated unit. Shared paid pickup remains unproven and disabled.

User clarified v1 throw hit a wall; v2 throw hit nearby ground. Capture timing
and diagnostics also changed between runs. Do not infer that wall impacts lose
pickup events from these confounded observations. Wall recovery remains a
separate later condition to validate after the server lifetime flow exists.

Reference follow-up: short_update.ysc.c func_377 (14601) passes eventData.f_2
into func_1104 (35844), which compares it to PLAYER::GET_PLAYER_INDEX().
fm_deathmatch_controller.ysc.c func_298 (23160) likewise compares f_2 with its
local Player and f_3 with the p_coffer02x_mp object-model hash. Consequently AI
rawSlots[3] is collectorPlayerIndex and rawSlots[4] is model, not networkId.
The value16 matching the separately observed world networkId16 is coincidental
and MUST NOT authorize a claim or lifetime binding. Initial commentary noted
the equality as a lead; source inspection rejected that interpretation.

Implemented these diagnostic collector/model fields in the build1491 decoder
and added the exact live-event regression asserting no invented networkId or
pickup handle. All251 isolated Weapons Lua specs and runtime syntax pass.
This small decoder refinement is local only, not in the already installed v2
batch. No new server installation/test is requested at this checkpoint.

Next: server-observed projectile creation/lifetime, model/bucket/current-owner
checks and bounded removal evidence integrated into the same released test;
correlate the already observed client object network ID with that lifetime,
without treating event collector identity or model similarity as ownership.
Then complete the durable paid single-claim route and native acknowledgement.


2026-11-12 server lifetime diagnostic implementation (live acceptance pending):
Added native_throwable_lifetime_capture.lua and connected it only to the active
server-reserved isolated throwable GUID test. It passively reads entityCreated,
entityRemoved and startProjectileEvent. Samples at0/100/500ms require a known
Tomahawk object model, target owner, matching player/entity routing bucket,
valid network ID and position within50m of the current player ped. At most64
creation attempts and128 records are retained. Every observed handle generation
gets a separate ticket-scoped lifetime; network ID reuse or changes taint the
match, and delayed callbacks cannot cross removal/replacement/session end.
Projectile events retain known numeric fields only and never invent an object
network ID from unknown fields.

A bounded client world snapshot can match a server lifetime by network ID and
model. Pickup-event collector index is never used as a network ID. A matched
result remains originConfirmed=false and noWrites=true: it is diagnostic
correlation, not proof of paid ownership or permission to commit a claim.
The report records removal separately; status exposes match/removal/read counts.
Native test success without a server match becomes review_required with
server_object_lifetime_not_correlated, while independently confirmed native
cleanup still permits original-loadout restoration. Capture closes before
restoration so restored weapons cannot contaminate this evidence.

Validation:252 isolated Lua specs plus runtime syntax pass. Added actual-module
server orchestration tests and unit tests for owner/bucket/proximity mismatch,
absence/native exception, removed and reused handles, network ID changes,
current-session fencing, truncation, malformed client rows and projectile hints.
No real server-lifetime capture has yet been claimed.

Prepared C:/coding/deployments/throwable-server-lifetime-2026-11-12:105 reviewed
Weapons runtime files, installer and hash manifest. Four files differ from the
installed v2 batch (manifest, server GUID orchestration, new lifetime module,
AI pickup decoder refinement). Configs, prices, reports, tests/docs and database
are excluded/preserved. Local installer validation/install/idempotence and
canonical hashes checked. Requires disconnected clients, stopped Weapons,
installation, server-console refresh then ensure feather-weapons because a new
server script was added. No full server restart, config or SQL change required.
Next live gate: same short ground throw/pickup, inspect world.phase and removal
counts. Durable paid origin binding/shared claim/native acknowledgement remain
pending and normal physical throwable purchases remain disabled.


2026-11-12 latest live server-lifetime capture: native case passed1/1 and exact
cleanup/restoration confirmed; overall review_required because world.phase was
unconfirmed with0records/0matches/0readFailures. Client again captured the
networked Tomahawk (networkId104, model3358573347) and the AI pickup event
(collectorPlayerIndex16). This independently confirms collector index and world
network ID are different values. Current server counters cannot distinguish no
callbacks from objects rejected before recording. No server lifetime pass or
shared pickup authority is claimed. Next diagnostic should expose callback and
rejection counts and inspect an actual server lookup while the object exists,
using a bounded untrusted client network-ID hint rather than waiting until the
final report after pickup. A successful lookup would prove server visibility,
not prove its birth, paid ownership or pickup entitlement.

Original-code review requested by user: inspected available git history at
3a06fd7 (multi-ammo throwing knives/Bolas/five throwable slots) and d96e4b4.
client/main.lua ObserveKnifePools (around947 in3a06fd7) clamps observations with
math.min and explicitly says pickup conversion is not ownership. The throwable
selection probe (around3905) explicitly avoids treating native pickup as
Inventory ownership. server/services/ammo.lua SyncPools (around813) likewise
permits consuming existing ownership, not minting pickups, and states recovery
requires a separate exactly-once ledger. These inspected implementations do not
supply a shared world-object lifetime/paid pickup route to transplant. The local
pre-rebase backup grep found no pickup/projectile implementation; repository root
commit contains only LICENSE. This is a bounded available-history review, not a
claim that every external version has been searched. The decompiled pickup
layouts were separately checked as documented above.

Standing workflow rule recorded in repository AGENTS.md: inspect available
original/history and decompiled references before engine-facing replacements;
separate verified patterns, observations and assumptions, and report absent
sources/behavior. No deployment or server commands required for this record.


2026-11-12 bounded live server-lookup diagnostic (not yet live accepted):
Prior original/history and decompiled review did not identify an existing paid
shared-pickup flow. This addition uses the Cfx documented network-ID/handle
conversion contract, with server-state awareness still to be verified live:
https://docs.fivem.net/docs/scripting-manual/networking/ids/
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/src/state/ServerGameState_Scripting.cpp

The isolated client probe now sends a numeric network-ID/model hint immediately
when it first sees a unique detached Tomahawk, while the object still exists.
The server accepts hints only for the reserved target/session/ticket during the
active loan, at most8requests. It resolves the ID independently, reads model,
owner, bucket and distance, and requires identity readback; no client-provided
entity handle/position/ownership is trusted. All operations remain read-only.
Callback counters distinguish created/removed/projectile event arrival, and
rejection counters identify failed lookup, object type/model, owner, bucket,
range and native-read failures. No entity-control or grant retry is introduced.

Lookup observations explicitly set creationObserved=false. Matching a live
lookup reports observed_without_creation, which remains review_required rather
than upgrading to the server-creation gate's matched result. Native cleanup and
original-loadout restoration remain independent. This should distinguish server
visibility from absent creation events without inventing paid origin proof.

Validation:252 isolated Lua specs plus runtime syntax pass, with live-hint
client/server composition, duplicate object notification suppression, foreign
source/ticket refusal, bounded requests, missing/incorrect lookup, owner gates,
and observed-vs-created separation. Local installation validated105runtime
files, four updates, canonical hashes and repeat idempotence. Prepared
C:/coding/deployments/throwable-live-lookup-2026-11-12; no manifest/script-list
change from the installed lifetime batch, so stop/install/ensure suffices after
clients disconnect. Configs, reports and database remain preserved. No server
installation or engine acceptance is claimed yet; next is one ground throw with
an extra few seconds before pickup to allow the read-only lookup.


2026-11-12 source-led readiness/projectile diagnostic update (live pending):
Rechecked original3a06fd7 throwable code (decreases-only, no shared pickup path),
local1491.50 decompiled usage and native signatures before editing. The inspected
MP scripts use GET_COORDS_OF_PROJECTILE_TYPE_WITHIN_DISTANCE for dynamite; no
exact call site for0x9578986A6105A6AD was found in this local script_mp_rel tree.
The native DB and generated MISC.lua declare its typed return as bool,Vector3,
Object with ped/weapon/distance/flags inputs. Discord research independently
references it, but landed Tomahawk behavior remains unverified. Therefore it
supplements rather than replaces the already live-proven CObject fallback.

CaptureVersion3 performs at most two targeted reads per100ms during only the
isolated loan's awaiting_pickup stage (owned-only and unrestricted query), within
50m, validates known model/existence/network ID, and shares hint deduplication
with fallback scans. Availability/read-failure counts are explicit. It does not
create pickups, change collection permissions or establish paid origin authority.

Server hints now permit six total read-only readiness attempts (immediate,
100/500/1500/3000/5000ms), bounded to8hint requests, stopping when independently
validated or when the reserved session/window ends. Every success still requires
matching native model/network identity, owner, bucket and proximity. Read-only
retries never repeat item/equipment/ammunition mutations. Rejected lookup rows
retain compact server-native readbacks (existence, type, model, net ID, owner,
optional raw net type), instead of hiding all evidence behind a model filter.
Cfx server source confirms WorldProjectile maps to object3 and ped-family to1;
those eligibility filters remain intact:
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/src/state/ServerGameState_Scripting.cpp
The RDR3 sync-tree model getter returns0 when no recognized creation/appearance
model node exists; this is a potential visibility limitation, not confirmation
that our live five model0 rejections were Tomahawks:
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/include/state/SyncTrees_RDR3.h

Validation:252 isolated Lua specs plus runtime syntax pass. Added delayed
readiness, six-read bound, current-session cancellation, target-reader signature/
result validation, cross-reader deduplication and fallback-on-native-error cases.
Prepared C:/coding/deployments/throwable-readiness-2026-11-12 with105runtime files
and three updates from installed live-lookup batch. Local installer validated
hashes/install/idempotence. Configs, reports, SQL and normal gameplay gates remain
unchanged. No new manifest entries, so disconnect/stop/install/ensure suffices;
refresh/full server restart is not required. Live readiness/target-reader
comparison remains pending; no paid shared pickup implementation is claimed.

2026-11-12 readiness/targeted-reader live result and Cfx source review:

The isolated native cycle, pickup observation, exact cleanup and original loadout
restore passed. Overall acceptance remains review_required with
server_object_lifetime_not_correlated; it is not a paid/shared pickup pass.
Capture v3 on build1491 made272 targeted projectile reads with zero failures.
At9314ms both targeted owned-only reader and CObject fallback saw entity429314,
networkID47, model3358573347. The AI pickup arrived at23308ms, about14seconds
later. All six server lookup attempts failed eligibility/resolution: lookup_missing5,
with one additional rejected lookup recorded in the full report. World summary:
recordCount6, matchCount0, createdCallbacks29, removedCallbacks75,
projectileCallbacks0, hintRequests1, hintResolved0, readFailures0.
Other callback rejection counts include model_mismatch_0=10 and entity_type_1=66;
these unrelated callback samples must not be assumed to describe networkID47.
This result weakens a simple short readiness-delay explanation. No repeat of the
same test or relaxed model/type/source eligibility is warranted.

Primary Cfx master source reviewed2026-11-12:
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/src/state/ServerGameState_SyncTrees.cpp
MakeSyncTree explicitly supports RDR3 WorldProjectile using CWorldProjectileSyncTree.
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/include/state/SyncTrees_RDR3.h
CWorldProjectileSyncTree contains CProjectileCreationDataNode (empty struct),
CProjectileAttachNode (empty struct), and CWorldProjectileDataNode (position parser).
GetModelHash handles vehicle/ped/object/player/animal nodes but no projectile node.
Thus lack of a server projectile model readback is source-supported; absence of
all projectile replication is NOT supported. The current server artifact/version
has not been matched to this source. Neither these definitions nor client
networked=true prove why networkID47 could not be resolved on this server.

Next: inspect the six compact world.records in the retained live report and
identify the actual server artifact before changing the ownership design. Preserve
native-guid-acceptance-report.json; no Inventory/SQL/config repair is indicated.
If a framework-managed recoverable object is required, raise its native pickup,
visual/physics, duplication and shared-player ownership tradeoffs before building
that replacement. Normal paid Tomahawk activation remains off. This update changes
research/status documentation only; no deployment, restart or new live test needed.
2026-11-12 retained world.records inspected (user supplied read-only report):
Correction to the earlier summary: networkID47 DID resolve on the first lookup
at9342ms. Handle147458 existed, owner1, entityType3, netType23, model0. It was
rejected for model_mismatch_0. Subsequent lookups at9456/9868/10859/12359/14372ms
were missing. The client first saw47 at9314ms and collected at23308ms. Thus this
is initial server visibility followed by loss, not six missing resolutions.
Cfx NetObjEntityType.h explicitly identifies RDR3 WorldProjectile=23:
https://github.com/citizenfx/fivem/blob/master/code/shared/net/NetObjEntityType.h
Together with the empty CProjectileCreationDataNode and absent projectile branch
in GetModelHash, the live model0 result is consistent with a WorldProjectile
model-readback limitation. Type23 alone cannot identify a Tomahawk or prove paid
origin. No relaxation of the Tomahawk filter or claim authority was implemented.
The lifetime helper currently records rejection aggregates for Created samples;
it does not retain raw identity/lifetime evidence for rejected model0 creations.
Consequently this report cannot identify which Created/Removed callback belonged
to47, why lookup later disappeared, or whether it changed network representation.
Next investigation must distinguish engine lifetime behavior from this diagnostic
filter limitation. A server-managed recovery object is a design alternative,
not an implemented fix; its native pickup/physics/shared ownership implications
must be discussed before replacement. No runtime files changed in this review.
2026-11-12 implemented unverified projectile lifecycle diagnostics:
Created samples retain native WorldProjectile23/type3 identity and rejection
readbacks as server_projectile_unverified_sample. Removal records retain the
same lifetime ID and network ID; lookup rejections link to existing callback
lifetimes. These records never populate verified model generations or matches,
never resolve a hint as a Tomahawk and never authorize pickup credits. Reused
handles remain separate and stale timers remain fenced. Verified model filters,
report acceptance, normal gameplay flags and paid claim authority are unchanged.
Validation:252 isolated Lua specs plus runtime syntax pass, including model-zero
creation/lookup/removal and handle-reuse regressions. Prepared one-file batch
C:/coding/deployments/throwable-projectile-lifetime-2026-11-12; installer tested
validation, installation and zero-change revalidation against previous payload.
Only server/services/native_throwable_lifetime_capture.lua changes at runtime.
No refresh/schema/config/full restart required; disconnect, stop/install/ensure.
Live callback/removal correlation remains pending; shared paid pickups remain off.
2026-11-12 projectile-lifetime live result (user-confirmed report):
Native throw/pickup/cleanup/restore passed; overall remains review_required,
server_object_lifetime_not_correlated. Client networkID30/model3358573347 at10226ms,
AI pickup25222ms. Server lookup at10321ms resolved handle144642, owner1,
entityType3, netType23, model0. Actual entityCreated sampling at10321ms retained
lifetime guid-suite:1794522626:1:object:20; actual entityRemoved at10418ms retained
the SAME handle/networkID/lifetime. Server-observed span97ms; five subsequent
lookups missing. Client collection occurred about14.8seconds after removal.
No truncation/read failure; records8. This confirms server creation/removal
correlation for an unverified-model WorldProjectile, not paid Tomahawk ownership.
The initial lookup preceded Created handling (creationObserved=false on that row)
and must not be confused with a missing creation callback.
A longer readiness delay cannot restore an already removed server entity. Cause
of removal (engine representation transition, replication policy, artifact or
another resource) is still unproven; do not claim natural projectile expiry or
intentional deletion from this callback alone. Current callback evidence cannot
prove the client's remaining object stayed the same network generation.
Design checkpoint: investigate server removal cause and a server-owned durable
recovery token tied to confirmed paid spend, with exactly-once shared claim.
Replacing native ground recovery with framework-managed pickup may change pickup
interaction/visual physics, especially wall/body throws; discuss this tradeoff
before implementing. No runtime authority/filter relaxation or new deployment
in this review. Existing diagnostic batch worked; no repeat test needed now.
2026-11-12 removal-cause investigation:
Re-read current loan fixture and real owner Observe: funded quantity decrease only
updates observation/seal; no projectile delete or release occurs before pickup.
Local Feather runtime scan found no general entityCreating cancellation handler;
this does not prove what is running on the remote server. Original owner history
and decompiled short_update pickup reader were rechecked; neither gives a paid
shared-world ownership mapping or server removal cause.
Cfx ServerGameState.cpp source inspected: ProcessCloneRemove validates owner and
uniqifier, logs queueing remove, then RemoveClone marks deleting. FinalizeClone
logs explicit Requested deletion / First owner dropped / Regular entity GC.
onesync_logFile enables these native engine logs dynamically; it is not a pickup
or mutation feature. Next live observation should use this engine log, plus server
version, rather than changing gameplay, culling, ownership or orphan mode.
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/src/state/ServerGameState.cpp
No runtime file changes this investigation. Native cause remains pending; no
claim that GC, impact, resource deletion or client removal has been established.
2026-11-12 engine logging preflight correction:
User server version FXServer-master SERVER v1.0.0.38621 win32. Test native
cleanup/restore passed but absolute onesync_logFile target was not created.
Earlier absolute-path instruction was incorrect: Utils.h MakeRelativeCitPath
concatenates Citizen installation root and requested name; server Logv passes
onesync_logFile through that helper before fopen. Use a plain relative filename
and verify its creation BEFORE another throw. No engine removal-cause evidence
was collected from this run. Logging was reset empty by user. No runtime edits.
https://github.com/citizenfx/fivem/blob/master/code/client/shared/Utils.h
2026-11-12 engine-log capture received:
Relative log successfully written at C:/Servers/redm_feather_dev/cfx/throwable-removal-check.log,
length38785696bytes; user reset onesync_logFile empty. Current projectile networkID51,
handle136543, owner1/type3/netType23/model0. Created7919ms, still visible8035ms,
Removed8117ms (198ms callback lifetime), later four lookup misses. Native cleanup
and restore confirmed. Supplied log tail40 contains client ProcessCloneRemove /
Requested deletion for OTHER IDs, but no51; it cannot establish cause for51.
Next read-only action: filter existing log specifically for51; no new throw,
logging activation, install or restart required. Preserve report/log for correlation.
2026-11-12 exact engine removal correlation supplied by user:
[2466737] ProcessCloneRemove: queueing remove (51 - 30859)
[2466737] RemoveClone: removing object 1 51
[2466806] FinalizeClone: finalizing object 51 (for reason Requested deletion)
This establishes accepted owner-client clone removal for networkID51, followed
by requested-deletion finalization; not Regular entity GC for this removal.
It does not identify the client resource/native/game code initiating removal,
or prove physical pickup-object destruction (client later collected a unit).
Next investigation belongs in Cfx client clone/projectile lifecycle and available
decompiled scripts: distinguish projectile-to-pickup representation transition
from actual destruction. Do not force retention/orphan mode or grant from a
client pool increase. Keep durable paid-unit recovery separate from transient
projectile network lifetime. Existing native cycle cleanup/restore remain passed.
No further identical live throw, runtime deployment or SQL repair required now.
2026-11-12 client lifecycle source investigation and pending UX choice:
Cfx CloneManager.cpp OnObjectDeletion queues owner-client removal for previously
synced local clones. DestroyNetworkObject can also queue removal when a network
object is unregistered, excluding explicit deletion-ack suppression. Therefore
the confirmed ProcessCloneRemove evidence proves clone retirement, not necessarily
physical object destruction or a script DeleteEntity call. Source:
https://github.com/citizenfx/fivem/blob/master/code/components/gta-net-five/src/CloneManager.cpp
The exact native/game initiator is not exposed in these Cfx functions. Available
decompiled short_update func377 consumes pickup type, collector player index,
model and inventory item hash; no durable paid-unit projectile ID is present.
Existing native unit claim storage remains inactive pending trusted binding.

A material design choice was presented before implementing any replacement:
(1) framework-controlled localized Pick up Tomahawk prompt and exactly-once paid
unit transfer, or (2) continue native automatic pickup lifecycle research.
User answer pending. No world replacement or prompt implementation authorized
by assumption; no feature gate activated. Independent implementation checklist:
- Recovery token must originate from confirmed spend of a specific paid item,
  retain full metadata, and admit at most one recovery per spent item revision.
- A prompt/client position/pool increase alone is not proof of world origin.
  Placement admission, bounded throw distance, current owner/bucket and actual
  world representation must be specified before wiring RecordBinding.
- Competing collectors reserve/claim with atomic inventory+ledger commit; lost
  response reads receipt without replaying world consumption or paid mutations.
- Prevent native auto-pickup from separately minting carried ammo if framework
  prompt is chosen; reconcile native acknowledgement without double grant.
- Wall/body/ground behavior, expiry/disconnect/restart and failed world cleanup
  require explicit policies; do not delete arbitrary same-model nearby props.
- Per-player language uses supported settings provider and English fallback.
Current scope is research/design only; no deployment or live retest requested.

2026-11-12 VORP/RSG comparison completed at user request:
Resource research docs/throwable-framework-comparison-2026-11-12.md records exact
public source paths and bounded scope. VORP thrown recovery uses ambient pickup
events and a server map matched by weapon name; its prompt/local prop flow is
ordinary inventory drops, not the same throwable path. RSG consumes an item then
funds native ammo; its ammo companion saves changed native totals. No exact-item
shared throwable recovery was found in reviewed RSG files. Neither supplies our
required durable paid-unit/world binding. Recommendation remains framework pickup
prompt with atomic identity-preserving claim; user leans toward that option but
no replacement runtime implemented by this research. No deployment needed.


2026-11-12 prompt direction approved and reference saved:
User approved framework-controlled pickup prompt. Read umaruru Prompt Research
gist1cdbfc302dda20d8c5601f0ce8f0e03c; local snapshot and revision metadata stored
at C:/coding/research/redm-prompts. Reference added to workspace AGENTS.md.
Research notes: active groups can compete; ambient entity groups can coexist.
Context prompts offer native proximity activation. Delete unused handles and
limit registered prompts; transport mode can restrict interactions to on-foot.
These are community research findings, not a live Feather validation.

Implemented client/native_throwable_pickup_prompt.lua and its Toolkit/Core
adapter, deliberately not manifest-listed or activated until world/claim route
is ready. Bounded64 offers, one nearest two-metre prompt, same-bucket/alive/busy
gates, pending-before-RPC, status-only uncertain readback, session/epoch fences,
language rebuild and cleanup. Adapter uses actual Core TranslateLocale account
selection (feather-settings) with English fallback and cached labels. Caller
must wire locale-changed/resource-stop events; no listener is installed yet.
Group type remains an integration decision: current Toolkit wrapper is active
group only; avoid introducing active-group interference at runtime.
Validation:253 isolated Lua specs plus runtime syntax pass. World placement,
native auto-pickup suppression, durable token publication, shared claim SQL
integration and native acknowledgement remain pending. No server deployment,
normal feature activation or complete shared pickup claim in this increment.


2026-11-12 prompt-backed server admission and durable claim increment:
Implemented inactive Weapons server/services/native_throwable_pickup_claims.lua.
The broker reserves both pickup and actor BEFORE any yielding port, reads actor
identity/position/bucket from server ports, rechecks exact immutable durable
binding and two-metre distance, and passes live authority into the transaction
port. Competing requests are pending, admission-read failures refuse before any
mutation, and a lost transaction reply retains reservation. Read is receipt-only
and checks original collector/session/epoch; a foreign/mismatched receipt cannot
release or confirm the reservation. This does not expose a public route or create
world entitlements; durable binding publication/claim ports remain unconnected.

Inventory inactive native_throwable_shared_claim primitive now supports explicit
version3 prompt-backed bindings (separate receipt namespace, pickupId,
pickupRevision, immutable bucket/position). Network/projectile IDs are forbidden
for version3, rather than inventing an ID for a vanished projectile. Existing
version2 remains supported and uses the SAME unique origin/item-revision alias
namespaces to prevent cross-path duplicate bindings. Apply transfers the exact
spent paid row with full metadata into collector custody, CAS advances collector
ledger, and stores one claim receipt atomically. Added read-only ReadPromptBinding
for available/claimed receipt readback. All remain inactive/not manifest-listed.

Validation:254 Weapons isolated Lua specs plus runtime syntax pass. Full Inventory
Lua runner passes, including real claim/move bodies with modeled SQL, version3
binding/claim/replay/placement refusal and interruption rollback at every query.
No live MariaDB concurrency or RedM world/prompt acceptance claimed. No deployment,
config, schema or version changes required for this staged increment.

Next: server-admitted placement of a recovery representation after confirmed paid
spend; prevent native automatic pickup/double quantity; publish durable offers;
wire collector release/transaction/fresh native restore and status-only recovery;
then admission/list/event wrappers, lifecycle/restart and two-collector tests.
Need ambient/context prompt integration to avoid active-group interference;
locale/resource cleanup hooks are required when activating the existing adapter.
Normal physical throwable gate/catalog remain disabled until these are complete.


2026-11-12 placement admission started; usage-reset handoff checkpoint:
Added inactive server/services/native_throwable_pickup_placement.lua with trusted
actor/spend/persist/read/publish ports. Landing is explicitly a client proposal,
not projectile ownership proof. Admission requires confirmed spent exact item
ID/revision/full metadata and matching origin session/epoch, alive actor and
server bucket, finite coordinates within50m of current server actor position.
Reserves item+revision before yielding and rechecks complete spend/session/bucket/
range at persistence boundaries. Version3 durable binding has no fake network ID.
Lost reply retains reservation; Read queries existing pickup binding only.
Published available record is visual delivery only; no item/native grants.

Validation:255 Weapons isolated Lua specs plus runtime syntax pass. Added unpaid,
foreign session, revision, range/death/NaN refusals, pre-yield competing placement,
metadata authority change and lost-reply readback. Ports are modeled, no live
world placement or end-to-end shared pickup acceptance claimed. Module is not
manifest-listed; no active public route, schema/config/version/deployment changes.

Resume here: connect actual confirmed-spend publication to authoritative placement;
implement the exact local visual-object renderer and ambient/context prompt;
provide scoped native pickup suppression with teardown policy; connect inactive
Inventory version3 binding/claim through released-owner transaction and native
restore/ack; then public admission/readback, delivery/restart/expiry/capacity and
multi-player integration tests. Placement cache currently holds up to64 records
per constructed instance; durable-index reload and bounded completed-record
retirement must be implemented before activation (not a production lifetime cap).
Keep normal physical throwable/catalog flags OFF. No further same diagnostic
throw is needed to resume. All original/decompiled/Cfx/VORP/RSG research is saved
in resource docs and C:/coding/research; prompt reference linked in AGENTS.md.


2026-11-12 recovery representation / ambient prompt increment:
Implemented inactive client/native_throwable_pickup_visuals.lua and Toolkit
adapter. Server-offer snapshots are bounded64, identity/sequence fenced and
same-revision position/bucket changes refused. Render at most8 nearest offers
within32m in current bucket. Model loading yield rechecks session/alive/bucket/
range/offer; stale creations are cleaned using only their owned Toolkit IDs.
Visuals are frozen, non-networked plain Tomahawk props with collision disabled,
not CreateWeaponObject/ambient native pickups. Never scan/delete matching props
or the original projectile. Mismatched model/network state retains exact cleanup
handle rather than deleting a possible replacement entity.

Prompt adapter now uses entity ambient native0x315C81D760609108 with exact owned
visual entity,2m radius,one tab and grouping flag2; no exclusive active group.
Constructor requires owned entity resolver. Missing/replaced visual hides prompt
and blocks input. Locale text is cached and cleared on LanguageChanged, using
Core feather-settings account language contract and English fallback.

Added inactive native_throwable_pickup_permissions.lua. Two known Tomahawk model
permissions are suppressed through an injected native setter; explicit prior
policy is mandatory (there is no assumed native getter). Partial errors attempt
compensation; failed restoration retains cleanup evidence. Integration must own
and supply that prior policy, lifecycle calls and actual setter. This helper
alone does not suppress any live game pickups or install an event/thread.

Validation:258 Weapons isolated Lua specs plus runtime syntax pass, including
real adapter wiring with modeled Toolkit/Core/natives, bounded render selection,
immutable/stale snapshots, loading/session races, foreign-entity refusal, locale
fallback/cache, partial permission failure and retained restoration. Engine live
validation still pending. No manifest/dependency/config/database/version changes
or deployment. Not a complete or enabled shared recovery feature.

Resume: authoritative durable offer publication, normal-lifecycle permission
ownership/suppression and cleanup hooks, paid claim/released-owner fresh native
restore/status route, restart/expiry and completed cache retirement. Package one
combined acceptance batch only once the complete path is integrated. Keep current
normal throwable flags/catalog off; no further diagnostic throw needed now.


2026-11-12 assembled client lifecycle and durable offer reload increment:
Added inactive client/native_throwable_pickup_lifecycle.lua assembling the real
prompt/visual/permission modules. Suppress before creating presentation, compensate
partial start, hold suppression through pending claim, poll receipt only at2s,
refresh visuals at500ms, cleanup independently on epoch/session retirement and
expose LanguageChanged/Stop for eventual normal runtime hooks. No automatic
threads/listeners or manifest activation yet. No claim replay on frame/poll.

Inventory inactive shared-claim primitive now has ReadPromptPage: namespace-index
keyset SELECT limit65, process64, available-only validated version3 bindings,
cursor progression through claimed rows, no ledger/item writes or client export.
Added server/services/native_throwable_pickup_offer_feed.lua: one page per Step,
complete-snapshot replacement only, preserve prior cache after read failures,
filter nearby50m/same bucket/current alive actor and in-flight claims, project
at most64 public offers with per-session/epoch sequence. Public fields exclude
serial/donor/item metadata. Hard scan bound16pages is retained as staging safety;
spatial/expiry/retention production scaling remains to be finalized before rollout.

Validation:260 Weapons isolated Lua specs plus runtime syntax pass. Full Inventory
Lua runner passes including new page reader tests. Model tests cover actual
client module assembly, partial startup compensation, epoch cleanup, bounded
receipt-only polling, privacy/bucket/range projection, page/read failures and
no partial snapshots. No live MariaDB concurrency or RedM end-to-end acceptance.

Outstanding integration is explicit: native_equipment_transition.lua has been
inspected and must be reused for pickup final seal/release/Inventory claim/fresh
restore/ack. No pickup action branch or production Inventory export was added
in this increment. Public source-checked routes, real actor/spend/storage ports,
server publication, normal owner suppression baseline and cleanup hooks, restart/
expiry/cache retirement still remain. No claim that the full shared pickup path
is connected. No deploy/config/schema/version changes or user test yet.


2026-11-12 pickup claim wired into actual equipment coordinator (gated):
Native equipment bindings now expose SERVER-LOCAL PickupTransition and status.
Requires physical UnitsEnabled, exact active Core/native identity, inactive proof
resource and server authority callback; no existing client equipment UI action
can select throwable-pickup. Preflight captures actual final-wear/equipment view;
after acknowledged seal/release, finalizeSpec reads fresh collector ledger and
builds version3 claim. Existing coordinator writing ticket authorizes Inventory
CommitNativeThrowablePromptPickup export, which commits final wear and exact-item
claim in ONE Inventory transaction. Shared primitive is now manifest-listed as
NativeThrowableSharedClaim; no longer describe it as entirely unlisted/inert.
Commit export requires invoking Weapons, current session, exact coordinator ticket
and released native authority. Fresh rebuild and matching native restore ACK
precede claimed completion. Refused/uncertain reservation/commit paths retain
existing coordinator freeze evidence, with no automatic economic replay.

Same-login fresh native epoch is now handled explicitly by prompt/claim broker:
claimed completion requires exact pickup ID/revision plus explicit restored
identity matching current client/server actor. Different login remains refused.
Pending lifecycle survives same-login epoch handoff while receipt-only reads wait;
visuals clean up as ownership changes. No arbitrary new epoch is adopted as proof.

Added server/services/native_throwable_pickup_transport.lua, explicit Install(api)
for the eventual real recovery bootstrap. Installed-handler tests exercise Cfx
source derivation, strict action/payload/session admission, per-source rate limits
(fake client session IDs cannot reset budget), pre-yield in-flight lock, bounded
request-ID deduplication, status-only old-epoch read and private receipt projection.
No automatic installation/manifest admission for this transport yet; bootstrap
ports are not wired and normal gameplay is still disabled.

Validation:262 Weapons Lua specs plus runtime syntax pass. Full Inventory Lua
runner passes, including new actual commit-export guard/composition test. Actual
native equipment coordinator exercised for pickup release/ledger refresh/single
commit/fresh restore/stale ACK/authority-loss failure; database/native/Core ports
modeled. No live MariaDB concurrency or complete RedM shared pickup acceptance.

Next: recovery bootstrap supplying real durable actor/spend/binding/list/claim
ports, source-checked CLIENT transport, spend-triggered placement publication,
permission policy ownership and normal lifecycle hooks; durable restart/expiry/
cache retirement and two-player tests. Public handler is implemented, not yet
installed into normal runtime. No deployment package or live test yet. Eventual
Inventory manifest change requires server refresh before resource ensure/restart.
No config/schema/version bumps or commits performed this increment.

2026-11-12 concrete pickup runtime assembly (staged, supersedes bootstrap status above):
Server/client recovery hosts and their dependencies are now manifest-listed.
Server host supplies actual Core/Medical actor state, Inventory durable storage
exports, equipment coordinator transition/status and Cfx transport. Inventory
storage exports check invoking Weapons and current reservation authority;
ReadSpentUnit obtains exact paid post-spend metadata/revision from the receipt.
Client host supplies guarded server offers/results, Toolkit visuals/ambient
prompts, locale changes and resource-level native pickup permission ownership.
Claim completion still requires exact token and a matching fresh restore ACK.

Admission remains CLOSED: NativeThrowableUnitsEnabled=false explicitly, and no
NativeThrowablePickupContract=1 setting is shipped. Server startup refuses the
missing contract or unavailable Toolkit when units are manually enabled. Firing
is blocked for enabled physical units if recovery client readiness is absent.
Failed client cleanup is retained for review rather than repeated by the idle
loop. Existing gameplay remains on its prior disabled physical-unit policy.

Validation: 265 isolated Weapons Lua specs and runtime syntax pass; full Inventory
Lua runner passes. Added concrete host startup gate/idempotence coverage, client
transport and assembled backend tests. Native/SQL ports remain modeled; this is
not live shared-pickup or MariaDB concurrency acceptance.

Remaining: confirmed-spend challenge publication, targeted landing proposal and
exact original-object cleanup acknowledgement; restart/expiry/cache retirement,
shared ownership/provenance delivery and multiplayer acceptance. No placement
event is registered yet. Do not enable purchases or deploy this partial flow.
No deployment commands are required now. Eventual combined runtime deployment
requires refresh because manifests/new scripts changed, plus resource restart.
No schema/version bumps, commits or deployment performed.

2026-11-12 confirmed-spend challenge integration (staged/default-off):
Added server-local NativeThrowablePickupChallenges. Actual ammunition observation
calls ConfirmedSpend only after confirmed provider completion and successful
remaining-unit lease rebind. Item IDs are derived from the server's reserved
spend set, not client payload. The challenge rereads each exact paid spend receipt,
checks post-move revision/origin/serial, and sends only identity, opaque challenge
ID, operation ID, item IDs/revisions and a 90-second lifetime. Metadata stays private.
Reservation precedes yielding storage/UUID/send ports; duplicate or uncertain
admission is retained without replay. Current alive login/epoch is checked again
after UUID generation. Challenge history is conservatively capped at256; automatic
retirement/restart continuation is not yet implemented. No placement event or
client challenge listener is admitted yet; no pickup is published by this step.

Validation:266 isolated Weapons specs plus syntax pass. Actual ammunition service
composition test checks exact partial/empty spend challenge IDs and no challenge
on unconfirmed provider outcome. Challenge tests cover pre-yield reservation,
private projection, expiry, foreign source, epoch/session replacement and failure
holds. These are modeled ports, not live engine/database acceptance.

Next: targeted client landing capture and exact original-object cleanup handshake,
then source-checked placement admission and durable restart/retention handling.
Physical units remain disabled and the contract setting remains absent. No server
copy, restart, database command, version bump or deployment needed this increment.

2026-11-12 landing capture / cleanup controller (staged, NOT runtime-installed):
Added client/native_throwable_landing_capture.lua with injected native ports.
One challenge/one unit only; batched spends cannot imply projectile order. Tracks
one candidate fingerprint (handle/model/network state plus adapter lifetime token),
never switches to a nearby same-model prop. Requires alive matching login/epoch/ped,
range<=50m, finite unattached sample, speed<=0.1 and position stable within5cm
for750ms. Rechecks session after yielding reads. Challenge expires after90sec.
Cleanup is separately invoked and requires independent authorizeCleanup approval,
then a fresh exact stable sample and current identity. One removal attempt only;
positive absence readback is mandatory. Missing/changing object, lost authority,
exceptions or uncertain deletion retain review evidence without retry.

Important limitation: the adapter lifetime token and independent cleanup authority
are requirements, not engine-proven facts. No concrete native adapter or client
challenge listener is installed yet. This controller does not turn the native
ownedOnly lookup into ownership proof and cannot currently publish a pickup.
Reviewed original3a06fd7 client code and existing saved decompiled/native research:
no reusable canonical paid-projectile shared recovery/cleanup contract found.
Native diagnostic ownedOnly lookup remains candidate evidence only. No broad
CObject fallback or same-model adoption was added to gameplay.

Validation:267 isolated Weapons Lua specs and syntax pass. New modeled controller
coverage: stable landing, changed/reused handle token, attached/moving/changed
network object, distance/session loss, missing read, expiry, reentrancy, unauthorized
cleanup, uncertain absence and no second destructive call. Live native lifetime
validation remains pending. Physical units/default contract admission stay off.

Next: implement and verify concrete native capture/lifetime/cleanup ports before
connecting client challenges and source-checked placement acknowledgements; retain
unbound spent items on ambiguity. No copy/restart/database commands needed now.

2026-11-12 concrete native landing ports (staged, unlisted/unconstructed):
Added client/native_throwable_landing_adapter.lua. Uses targeted native projectile
lookup with ownedOnly=true, no CObject pool fallback and no unowned lookup. Captured
Tomahawk receives a reserved integer decorator marker with verified readback;
existing markers are not overwritten. Exact reads check handle/model/network
identity and marker before/after sampling. Decorator proves continuity only AFTER
capture, not paid ownership, projectile birth or security authority. Registration
uses native decorator type3; allocation is bounded to signed positive int range.

Deletion still requires an injected independent authorization callback, matching
current capture and existing local control. No NetworkRequestControl or mission
entity adoption. DeleteObject invoked at most once, success requires entity
absence; a surviving/reused handle remains uncertain. Failed marker readback,
changed marker/network identity or lost control cannot delete a replacement.
No gameplay listener, manifest admission or paid pickup publication was added.

References checked: native database DecorRegister/DecorSetInt/DecorGetInt and
NetworkHasControlOfEntity; decompiled startup.ysc.c decorator registration,
rcm_gunslinger1_2.ysc.c around8376 targeted projectile lookup with false,true;
Toolkit client/services/entities.lua existing DeleteObject(handle) wrapper use.
Original3a06fd7 client code has no reusable paid shared-projectile cleanup flow.
The decompiled dynamite example supports lookup shape, not Tomahawk ownership.

Validation:268 isolated Weapons Lua specs plus syntax pass. Adapter tests mock the
actual native globals and cover lookup arguments, verified markers, unauthorized
cleanup, changed lifetime/network ID, lost control, failed stamping, unconfirmed
deletion and no second deletion call. Live decorator/throw behavior not validated.

Next: pre-throw freshness association (do not select an older owned projectile),
source-checked challenge/landing/cleanup handshake and receipt-backed publication.
The independent cleanup authority remains intentionally unwired. Normal physical
units and pickup contract remain disabled. No server copy/restart/DB commands.

2026-11-12 freshness association and placement handshake (staged/default-off):
Added client/native_throwable_throw_freshness.lua. Arms only after a targeted
owned-projectile lookup returns no candidate. Requires a one-unit native quantity
decrease and candidate within a <=250ms sampling interval; an older candidate,
early candidate, multi-unit drop, increase, missing candidate or long gap cannot
be associated. Captured fingerprint is immutable, scoped to login/epoch/ped and
expires after90sec. This is temporal evidence, not server engine ownership proof.
Landing adapter now REQUIRES freshness callback and exact candidate fingerprint
match before stamping. No arbitrary standalone ownedOnly lookup is enough.

Added server/native_throwable_placement_handshake service and installed it through
the concrete pickup server only behind the still-absent full contract gate.
Actual Cfx source selects challenge; client actor/item/metadata fields are refused.
Landing is immutable and bounded50m to current alive server actor/same bucket.
Server UUID cleanup token is issued after current challenge checks. Exact token
acknowledgement permits one backend.Place call using server-reserved item/revision
and spend operation. Pre-yield reservation blocks duplicate/reentrant writes.
Unknown outcome stays pending; status calls use backend.ReadPlacement only.
Requests are rate-limited4/sec/source before actor/storage work, with post-yield
challenge recheck before token/result delivery. Challenge stores operation ID.

Threat/availability limits: landing and cleanup are client reports, not verified
server physical-object origin. Conservation relies on exact canonical paid spend,
unique durable binding and claim transaction. Freshness intentionally holds
ambiguous throws; production arming/readiness must respect this. Challenge/status
expiry and conservative256-entry caches still need retention/restart treatment.
No client message host is integrated yet; native capture/freshness modules remain
unlisted/unconstructed and no normal throw is admitted. No purchase activation.

Validation:270 Weapons isolated Lua specs and syntax pass. New tests cover old
projectile exclusion, sampling gaps/multiple drops, immutable candidate/session
scope, immutable landing, foreign source, wrong token, pre-yield reentry, lost
write reply with read-only recovery, replacement session and source rate limit.
All engine/DB ports modeled; live native acceptance remains pending.
Next: client pre-throw/landing/cleanup handshake host, then isolated live test and
restart/shared-player acceptance. No server copy/restart/database commands yet.

2026-11-12 client placement host connected (default-off; not deployed):
Added native_throwable_placement_client orchestrator and manifest-listed freshness,
landing controller/native adapter before the existing concrete client host. Host
world now supplies actual ped and ledger revision. Dedicated50ms observer uses
only targeted owned projectile lookup and actual Tomahawk native quantity. Firing
readiness requires an armed current observer; one pending throw blocks additional
firing rather than mixing paid units with multiple world candidates. Busy ammo
observation preserves capture evidence; candidate must match server observe:<rev>.

Server-only challenge/result events check Cfx source65535. Duplicate challenges
are inert, never a second cleanup. Client waits for a matching server cleanup
token before reserving cleanup and invoking the landing adapter. It sends the
cleaned acknowledgement only after exact native absence. Lost replies poll status
at2sec, never resend landing, deletion or publication. Same exact login/epoch is
required; timeout or uncertain cleanup retains review evidence. Completion creates
a new observer only; it never grants native ammunition. Server refusal replies
now carry the echoed challenge ID so the client can terminate clearly.

Landing stability uses a fixed interval origin, not successive per-frame points,
so slow cumulative drift beyond5cm resets the750ms interval. Server position
projection keeps only x/y/z. Native lookup/decorator continuity remains evidence,
not proof of canonical server projectile ownership. Client ACK is still a report.

Validation:272 isolated Weapons specs plus runtime syntax pass. Added client
orchestration and real composed freshness+landing+native adapter+server handshake
test: native absence precedes one storage publication; duplicate delivery/reentry,
wrong revision/session, transport loss and read-only recovery tested. Engine and
storage calls modeled. No live decorator/ground/wall/body behavior acceptance yet.

Next: isolated engine test through existing release/restore acceptance harness,
then durable restart/cache/expiry and shared-player acceptance before normal paid
purchase activation. Contract remains absent and physical units explicitly false.
No deployment package, server copy/restart, schema or database command this turn.

2026-11-12 isolated live landing probe prepared (NOT run on server):
New WeaponGuidAcceptance landing mode uses existing exactly-one-player console
opt-in/release/preflight/audit/report/restore flow. It lends one synthetic native
unit, suppresses native model pickup under an explicit prior policy, exercises
real pre-throw freshness/decorator/stable landing/exact deletion client modules,
then releases spent ped custody and compares complete native pools with baseline.
Local synthetic cleanup/complete ACKs are fixture-only; no paid placement events,
Inventory grants or SQL publication. Original loadout restores only after cleanup
is independently confirmed. A thrown uncleaned world object retains failure.
Existing server WorldProjectile lifetime correlation is deliberately not a pass
gate for this separate native-cleanup probe; its previous evidence is preserved.

Older test configs without NativeThrowablePickupPriorPolicy require explicit
replicated feather_native_landing_prior_pickups=1 (allowed) or0 (denied) before
the test. Missing declaration fails before creating the test unit. This value
states prior framework pickup policy; it is not a native getter. Do not override
an existing customized Config prior policy. Normal units remain disabled.

Validation:273 isolated Weapons Lua specs plus syntax pass. New loan test covers
one creation, seal, cleanup prerequisite, cancellation/timeout, suppression and
permission restoration failure. Server orchestration test covers new mode and
release/restore without world-model match. No live probe results claimed.

Prepared C:/coding/deployments/throwable-landing-probe-2026-11-12, nine runtime
files plus manifest and Install-ThrowableLandingBatch.ps1. Isolated manifest is
based on reviewed live-lookup batch plus six probe modules; it DOES NOT load normal
paid pickup server/client hosts or require the new Inventory prompt exports.
Config/shop config, reports and DB untouched. Installer refuses unknown edits,
requires stopped-resource assertion, backs up originals and verifies SHA256.
Actual PowerShell fixture validation/install/idempotence/hash/preserved config/
report/unknown-edit rejection passed. Fixture evidence at
C:/coding/landing-installer-check-s0brmv1j. Builder/verifier scripts stay outside
runtime deployment. Source package is ready for operator ValidateOnly on server.
Refresh required because isolated manifest adds scripts; only Weapons restart.
No full-server restart or DB migration required. No live files copied this turn.

2026-11-12 live landing probe FAILED; diagnostic fix/session verification:
Operator report: landing mode received one failed case, passed0, cleanupComplete
false; row reason only landing_loan_capture_or_cleanup_failed. Normal client owner
closed/quiescing, ownedCopies0, cleanupCompletetrue. Operator confirms test Tomahawk
was thrown and remained visible, then subsequently disappeared. Do NOT equate
normal-owner closure or later visual disappearance with successful exact deletion.
Underlying native cause remains UNKNOWN; no functional native fix claimed.

Fixed diagnostic loss across layers: landing capture retains last sample/bounded
native exception and adapter last rejection/removal-attempt status. Placement
Status carries freshness and nested landing state; loan persists this even on
failure, plus owner cleanup and permission restoration outcomes and F8 diagnostic.
Server keeps native root reason and stores generic transitionReason separately.
Added recover-session ONLY for failed synthetic landing reports with economicWrites0.
Requires original character in fresh active Core session and exact saved/native
baseline comparison. Archives detailed prior evidence and marks recovered_session_failure;
never changes passed0/old cleanupCompletefalse or retries/repairs a native/SQL move.
Same login and changed saved state refused. Report files change; saved items do not.

Validation:273 Weapons specs pass, including deep reason preservation, marker
rejection, native exception, source/session recovery admission, retained prior
failure and changed-durable refusal. Nine-file isolated deployment rebuilt and
PowerShell upgrade tested from pristine original probe payload. Exact known v1
canonical hashes accepted; unknown edits still refused. Evidence fixture:
C:/coding/landing-installer-check-rf87vmtn. Config/reports preserved. No live copy.
Operator handoff: update same batch, validate, quit client, stop/install/ensure only
Weapons, reconnect original character then recover-session and inspect status.
No new scripts/manifest changes relative to the first landing batch, so no refresh
or full FXServer restart required for this update. No DB commands/migration.
Do not archive/repeat landing test before fresh-session verification is reviewed.

2026-11-12 operator-confirmed fresh-session recovery after failed landing probe:
WeaponGuidAcceptance recover-session returned recovered_session_failure,
recoveryconfirmed/restoredtrue, passed0/total1 and cleanupCompletefalse retained.
Client normal owner ACTIVE, runtime active/notbusy/notquiescing, ownedCopies1,
five melee assignments active, current ammo ledger revision1 with100 regular
revolver rounds. Recovery compared unchanged saved/native preflight baseline;
this does NOT certify original thrown-object cleanup. Prior failed evidence and
its generic reason remain preserved. Operator is now eligible for one new
instrumented isolated landing probe after evidence-only archive. No new deployment
needed; capture detailed WeaponNativeLandingProbe F8 output and nested report.

2026-11-12 second live landing probe FAILED with concrete capture evidence:
Fresh one-unit decrease associated with observe:1; captured Tomahawk model3358573347,
entity573186/netID87, verified marker fw_throw_capture_v1:1. Capturing began426670,
stable interval began426781; before750ms completed, adapter rejected original as
entity_or_model_unavailable. removeAttemptedfalse; permissionRestoredtrue; normal
owner closed/ownedCopies0. No deletion or paid/Inventory write occurred. Native
object was unavailable; a projectile->pickup successor is a hypothesis, NOT proven.
Do not shorten stability wait or mark disappearance as successful cleanup.

Rechecked decompiled targeted projectile lookup, pickup-object APIs, pickup-model
permission usage and native signatures. No canonical old-projectile->new-pickup
mapping found. Native pickup permission limit10 is compatible with our two models;
source usage does not prove a destruction side effect. Added isolated-loan-only
read-only Survey on capture failure: three samples over200ms of exact old handle,
owned projectile lookup and old network ID; one nearby2m snapshot over at most512
CObjects, retaining at most3 nearby candidates/6 observations total. Records marker
presence/network/model/absence, never adopts/stamps/deletes/grants a replacement.
Pool partial flag makes scan limit explicit. Normal gameplay does not call Survey.

Validation:274 Weapons specs and syntax pass, including bounded evidence-only
survey with mutators configured to throw. Same nine-file isolated batch rebuilt;
PowerShell upgrade from previous diagnostic/recover-session package passed. No
manifest/config/schema changes relative to prior probe batch. Next handoff:
copy updated batch, validate, quit/stop/install/ensure Weapons, reconnect original
character/recover-session then review status before one new surveyed probe.
Existing failed report retained; normal units and paid publication remain off.

2026-11-12 operator-confirmed recovery after tracked_object_changed probe:
With transition-survey update installed, recover-session returned confirmed,
recovered_session_failure/restoredtrue; passed0/cleanupCompletefalse and original
tracked_object_changed reason remain preserved. Client ACTIVE/notbusy/notquiescing,
one firearm copy/five melee, ammo revision1 with100 regular revolver rounds,
fresh session c73761d6-df1e-11f1-9a69-e0d55eaa2deb. Saved/native baseline recovery
passed; transition survey itself has NOT run yet. Next: one isolated landing run
with new bounded read-only survey, after evidence-only archive. No deployment.

2026-11-12 surveyed live probe FAILED; stable-handle assumption invalidated:
Original entity580354/netID91/model3358573347 was captured/stamped at197495;
stable timer197604; then entity_or_model_unavailable before750ms. No removal
attempt. Survey original.existsfalse; netID91 failed resolution; zero read errors,
but CObject snapshot poolPartialtrue so no successor conclusion possible. Operator
confirmed visible Tomahawk remained after old handle loss, then disappeared later.
Normal owner closed/ownedCopies0; permissions restored; economicWrites0. This does
not identify whether rendering/entity replacement/despawn occurred. No pass claim.

Surveyv2 replaces partial pool scan with two targeted GetClosestObjectOfType
queries within3m of last position at0/100/250/500/1000ms; all three filter flags
false per native signature (include network/local/script objects). Still evidence
only: no marker transfer/adoption/deletion/credit. At most6 deduplicated observations.
NetworkDoesNetworkIdExist now gates old-ID resolution to avoid known-missing-ID
warnings. Native references and decompiled act_hunting_2 lookup / fme_archery network
existence patterns checked; no Tomahawk canonical transition bridge found.

274 Weapons specs pass, including late successor500ms, ten bounded spatial reads,
no pool scan/control/deletion/stamping. Same nine-file batch rebuilt; PowerShell
upgrade from deployed surveyv1 payload validated. Fixture evidence:
C:/coding/landing-installer-check-7rqeqx_g. Not deployed. No more identical probes.
Current operator step: quit/rejoin original character and existing recover-session;
review recovery before installing targeted-survey update. No file changes needed
for this recovery. Preserve prior failed cleanup and baseline comparisons.

2026-11-12 latest operator recovery confirmed after surveyv1 failure:
recover-session confirmed/recovered_session_failure/restoredtrue; failed cleanup
remains false/passed0. Fresh active session0483acc5-df20-11f1-9a69-e0d55eaa2deb,
one firearm/five melee, ammo ledgerrevision1/100 revolverregular. Normal runtime
notbusy/notquiescing. Eligible for isolated targeted-surveyv2 deployment, then
one survey run after archived evidence. Existing targeted-survey batch is ready;
no normal paid/native pickup activation or new DB requirements.

2026-11-12 surveyv2 live evidence identifies distinct landed candidate:
Original projectile entity399618/netID20/model3358573347 captured/stamped, then
original existsfalse/networkmissing. Targeted closest query immediately observed
entity410114/netID57, same model, no capture marker recorded. Ten closest reads,
no read failures. Thus two distinct objects are observed near the landing spot;
new one is a plausible landed pickup, NOT verified original-throw origin. Native
cleanup stillfailed; no deletion/economicwrites; normal ownerclosed/copies0.

Next observer now enables existing server lifetime capture during landing mode,
but keeps it diagnostic-only (does not change native cleanup pass gate). Isolated
client survey sends bounded source/ticket-checked network hints for successor
candidates; loan case includes candidateOnly worldEvidence for server matching.
Server independently reads model/owner/bucket/proximity and correlates Created
lifetime. Old projectile model0 limitation may not affect this regular object;
this is a hypothesis for live validation. No proximity-only adoption/paid credit.

274 Weapons specs pass: candidate-only projection, server source/ticket matching,
creation/owner/bucket/native lookup and diagnostic/pass-gate separation. Existing
nine-file batch rebuilt; upgrade from surveyv2 payload validated (fixture
C:/coding/landing-installer-check-wme_p8t_). No manifest/config/DB changes. Prepared
handoff: update batch, validate; quit/stop/install/ensure; fresh session recovery;
only after confirmed recovery archive failed evidence and run one landing-object
server observation. No creation-matrix rerun or normal paid activation needed.

2026-11-12 server successor observation live result / hint timing fix:
Operator server has no status command; prior instruction was incorrect. Isolated
probe did run. Client original556034/net108 disappeared; closest candidate559106/
net25/model3358573347 observed. Server hintRequests1/lookupAttempts1/hintResolved0,
worldunconfirmed, records3; no readFailures. Need saved report.world.records to
see exact rejection before inferring successor server readability.

Found observer timing gap: successor hints sent only after the1sec survey returned;
client final report immediately ended server r.waiting, cancelling later100/500ms
native-read callbacks. Fixed Survey optional observed callback: immediate network
candidate hint on first observation, deduplicated within survey while reservation
remains live. No new economic/native mutation or adoption.274 specs pass including
hint at500ms before survey completion1000ms and no hint for local-only objects.
Fix stays local/unpackaged pending current saved server world-read evidence.
No further throw/restart/deployment requested; first read saved report.world.

2026-11-12 source-confirmed Pickup model limitation (stop identical probes):
Saved server records: original net108 created as netType23/WorldProjectile, owner4,
model0; removed158ms later. Successor candidate net25 created as netType8/Pickup,
owner4, model0, independent lifetimeobject11 following originalobject10. Client
reported that candidate as Tomahawk model3358573347. Server native read succeeds
but model gate rejects. This is NOT merely propagation delay. Same paid throw
origin is still an inference; lifetime/owner alone is not a canonical item link.

Verified current Cfx primary source:
https://github.com/citizenfx/fivem/blob/master/code/shared/net/NetObjEntityType.h
RDR3 Pickup=8, WorldProjectile=23.
https://github.com/citizenfx/fivem/blob/master/code/components/citizen-server-impl/include/state/SyncTrees_RDR3.h
CPickupCreationDataNode empty; CPickupSyncTree uses it; GetModelHash handles vehicle,
ped, ordinary Object, player and animal, not Pickup. This supports observed model0
and explains why a matching server Tomahawk model gate cannot pass for pickups.
Current upstream source is explanatory, not proof deployed binary equals master.

Local changes: explicit pickup_model_unavailable diagnostic; retain unverified
Pickup sample/removal lifetime evidence separately from WorldProjectile. Neither
enters verified model generations or grants/claims.275 Weapons specs and syntax
pass, including model-zero Pickup retention without fake model/authority. Prior
immediate-hint fix remains local. No new deployment or identical test requested.
Next implementation must explicitly handle projectile->Pickup transition with
canonical paid spend and bounded server lifetime evidence, keeping client model
reports supportive and ambiguous origins held. No model0-as-match fallback.
Current live session remains failed/normal ownerclosed; user should quit/rejoin
and existing recover-session before further testing; no file/DB changes needed.

2026-11-12 operator recovery confirmed; staged explicit transition linker:
Fresh session0d024161-df25-11f1-9a69-e0d55eaa2deb active with one firearm/five melee,
ammo revision1/100 regular revolver rounds. recover-session confirmed restored
unchanged baseline; original probe remains failed/cleanupfalse/passed0. No new probe.

Added server/services/native_throwable_transition_binding.lua, unlisted/uninstalled.
Only actual server Created callbacks populate bounded generation records (not a
client hint). Records type23 projectile and type8 Pickup, owner/bucket/current
Core/native scope. Link requires original removed, unique eligible live pickup
within bounded temporal window, same owner/bucket/session/epoch, no network ID
reuse or competing pickup. Exact single-item challenge is checked against the
canonical paid-spend receipt, including post-move revision/serial/full metadata.
Pickup and paid-row reservations precede yielding receipt checks. Current proof
rechecks native type/owner/bucket/network ID, scope/challenge/full receipt and
late competition before use. Creation callback also reserves before yielding.
No dependency on server GetEntityModel(Pickup); no guessed model or model0 match.

Proof explicitly keeps originConfirmedfalse/serverModelReadablefalse; canonical
paid spend supplies economic authority. Temporal linkage does not cryptographically
prove engine origin. No native object deletion, SQL write, claim/public handler or
runtime bootstrap admission is added by this module. Capacity256 remains a staged
hold; production retention/restart handling still required before admission.

Validation:276 isolated Weapons Lua specs plus syntax pass. New tests cover paid
metadata continuity, session/receipt/source/late/ambiguous/reused/missing object
refusal, ownership changes and late competition revocation, forged proof, receipt
and creation reentry reservations. Engine/SQL/Core ports modeled, not live proven.
Next: client pickup-lifetime handoff/cleanup plus integrate this proof with current
placement handshake and existing claim transaction. No deployment needed now.

2026-11-12 transition-to-Pickup implementation connected; ready for isolated test:
Client landing controller now treats loss of its original projectile as an
explicit transition phase (max3sec) instead of immediately assuming cleanup.
Targeted1.5m model queries propose one unmarked locally controlled network pickup;
no proximity-only adoption. Source/ticket-scoped server transition authorization
must match original/new net IDs before the client revalidates original absence,
new handle/model/network/control/position and stamps a NEW lifetime marker.
At most one handoff; reused/live original, ambiguous candidate, changed network or
failed stamping retains review. Stable landing750ms then separate cleanup token;
one native DeleteObject attempt and positive client absence still required.

New native_throwable_transition_protocol composes real server lifetime linker,
canonical single-unit challenge/paid receipt and post-cleanup server absence gate.
Both pickup generation removal and native absence required before one publication;
unknown publication uses receipt-only status. Reservations precede yielding ports.
Actor/session/bucket/range/receipt/late competition rechecked. Creation event time
is captured before yielding; removal arriving during creation read is retained.
No model0-as-match or fake copied marker. OriginConfirmed remainsfalse; economic
authority canonical paid spend (or explicitly isolated synthetic fixture).

Normal pickup host wired to protocol behind still-closed Config contract/units
flags; requires GetNetTypeFromEntity capability. Normal runtime manifests list two
new server modules. Retention/restart/shared-player normal acceptance still pending;
no ordinary paid activation. Isolated test manifest deliberately excludes normal
pickup hosts and new Inventory exports.

Existing landing acceptance now uses REAL source/ticket/rate-checked client/server
transition messages, not local synthetic success ACKs. Only receipt/state are
synthetic server memory; zero Inventory/SQL economic writes. Existing release/
preflight/audit/report/restore retained. Server refuses a client-reported complete
result unless its protocol confirmed pickup removal. Summary includes transition
serverRemovalConfirmed. Client row probeVersion2/enginePathprojectile_to_pickup.

Validation:277 isolated Weapons specs and syntax pass; full Inventory runner passes.
Composed test includes real client freshness/controller/native adapter, real server
linker/protocol: actual distinct pickup handoff, marker, cleanup, delayed server
removal, lost write reply/read-only completion, single deletion/publication.
Real registered acceptance handlers tested for foreign source/ticket/token refusal,
server absence before completion and one original-loadout restore. Native/DB/Core
ports modeled; live native handoff/deletion/empty spent-ped release not yet proven.

Prepared C:/coding/deployments/throwable-transition-test-2026-11-12:
12 runtime files, manifest, Install-ThrowableTransitionBatch.ps1. New manifest adds
server transition_binding/protocol; updated lifetime diagnostic file included.
PowerShell validation/install/stopped gate/hash/idempotence/config+report preservation/
unknown-edit refusal passed against known prior installed baseline, including old
projectile-lifetime file. Evidence C:/coding/landing-installer-check-dm54u9s7.
No live deployment, DB migration, version bump or commit. Operator test handoff:
validate; save/disconnect all; stop Weapons/install; refresh/ensure Weapons; only
Jane reconnect; archive previously recovered report; opt-in landing once on clear
ground, wait for automatic pickup cleanup and restore. No creation-matrix rerun.

2026-11-12 first live transition protocol test FAILED before cleanup:
Client fresh projectile net2/entity376322 -> Pickup proposal net18/entity385282;
server refused observed_transition_required. No deletion attempted; permissions
restored; normal ownerclosed/copies0. Server world capture5 Created callbacks,
46 Removed,9 evidence records,3 hint lookups; no read errors. Exact transition
link condition failing is not yet known (initial creation readiness vs callback
ordering vs absent registration etc.). Read saved report.world records BEFORE
changing gate or asking another throw. No claim pass/relaxation/retry requested.

2026-11-12 saved timeline reviewed and bounded readiness correction prepared:
Attachment52e45369 server evidence: projectile net2 created7119ms; pickup net18
created7295ms, sameowner1; projectile removed7308ms (13ms overlap). Pickup remains
readable through7840ms+. Initial transition request time was not recorded, so a
request/removal race is plausible, not conclusively proven root cause. No need
for another identical observer run. Old gate aggregated missing/pending lifetimes
into immediate observed_transition_required and permanently held the request.

Linker now distinguishes pending creation/removal from wrong type/owner/scope,
ID reuse and competing pickups. Protocol holds SAME proposed IDs for up to5sec;
status-only rechecks can authorize after actual server callbacks settle. No client
hint creates a lifetime, no deletion/publication before authorization and no SQL
mutation retry. Actual Created metadata readiness samples at100/500ms retain the
original event timestamp/removal-during-read; unrelated entity types are ignored.
Native exceptions/readiness reasons retained. Summary transition.readinessVersion2
includes source, requested time, selected generations/types/owners/buckets/event
timestamps, pending creations and bounded last native exception/reason. This will
identify any remaining gate failure rather than another aggregate refusal.

Validation:278 Weapons specs and syntax pass. New regression reproduces exact
7119/7295/7308 timeline with transition request at7296: pending with ZERO receipt/
publication calls, then authorized from same request after removal. Missing removal
expires/refuses; metadata propagation cannot invent duplicate events; native
exceptions retained. Existing transition cleanup/absence/lost-write tests pass.

Same12-file transition-test batch rebuilt. Existing v1 exact canonical hashes
accepted, unknown edits refused; actual PowerShell upgrade validation/install/
idempotence/hash/config+report preservation verified. Evidence:
C:/coding/landing-installer-check-gq4z6n1o. Only server runtime behavior changed;
manifest/script count unchanged from installed transition batch. No refresh/full
server restart/Inventory restart/DB migration required. No live copy performed.
Handoff: update batch/validate; quit all/stop-install-ensure Weapons; fresh original
character recover-session; only after confirmed recovery archive/run one landing.
Normal paid units remain disabled; no existing claim authority weakened.

2026-11-13 live transition readiness PASSED; attached-pickup stability gate fixed:
Attachment151854a7 server diagnostics transition_authorized: projectile net47
created1321419/removed1321590; pickup net118 created1321549, sameowner1/bucket0,
unique generations, no read errors. Client adopted new pickup1249538/net118 and
verified marker fw_throw_capture_v1:2. Refusal followed because exact stationary
sample attachedtrue/speed0 failed blanket attachment predicate. No deletion;
permissions restored, normal ownerclosed/copies0. This confirms the prior bounded
readiness correction worked; attached parent details not yet read live.

References rechecked: GetEntityAttachedTo native signature; decompiled
1491.50/script_rel/discoverable_generic_corpse.ysc.c around909/919 explicitly
attaches GetPickupObject to another entity. Confirms pickups may be attached;
does not identify this ground pickup's parent. No original paid cleanup reuse found.

Client now permits attachment ONLY after explicit server-authorized transition.
Reads exact attachment parent (including native parent0/internal representation),
requires finite integer, tracks attached flag+parent throughout750ms stability and
rechecks unchanged attachment before cleanup. Changes reset stability; unknown
parent or cleanup-time change refuses. Original/unapproved attached projectile
still refused. Exact marker/model/network/local control, source scope, server
cleanup token/client absence/server-removal gates remain. No DetachEntity or parent
write/delete is introduced; only exact authorized pickup is a cleanup target.

279 isolated Weapons specs plus syntax pass. Composed real client/server transition
now runs with attached pickup parent500 and verifies one child deletion, delayed
server absence, one publication and lost-write receipt completion. New tests cover
parent0/object parent, unknown parent refusal, changed-parent cleanup refusal,
full stability interval reset and no parent deletion. Native engine ports modeled.

Same12-file transition batch rebuilt; actual PowerShell upgrade from readinessv2
passed (fixture C:/coding/landing-installer-check-42iyzp9u). This increment changes
only client/native_throwable_landing_capture.lua and native_throwable_landing_adapter.lua
runtime contents; manifest unchanged. No refresh/full server restart/Inventory
restart/config/DB change required. No live copy. Next operator action: update batch,
validate; quit/stop/install/ensure Weapons; reconnect original character/recover-session;
after confirmed recovery archive/run one clear-ground landing cleanup test.
Normal paid units remain disabled. Live pickup-parent read/deletion/spent-ped release
and original-loadout restore still require confirmation; no pass claimed yet.

### 2026-11-13 — asynchronous landing completion latch

Latest live probe reached server protocol `available` with `serverRemovalConfirmed:true`; the operator observed the landed pickup disappear. The harness nevertheless timed out because placement Tick cleared asynchronous `complete` before Status read it. The failed report remains failed; spent native ped-owner release and original-loadout restoration were not established by that run.

Placement completion now stays latched until explicit matching-ID acknowledgement. The normal paid host acknowledges completion to rearm; the isolated loan retains completion long enough to release the spent native owner and check its baseline. No native identity/cleanup checks were relaxed. Normal paid throwable activation remains disabled.

Automatically verified: 280 isolated Lua specs, including real loan-runner/placement-controller asynchronous reply ordering; PowerShell 12-file validation/install, stopped gate, hashes, idempotence, config/report preservation and unknown-edit refusal (C:/coding/landing-installer-check-k8zlq8hv). Updated batch: C:/coding/deployments/throwable-transition-test-2026-11-12. Only client/native_throwable_placement_client.lua changes in this isolated runtime payload; normal paid-host acknowledgement is not included. Existing manifest unchanged: no refresh, full server restart, Inventory restart, config or database change. Live completion/spent-owner release/restore remains pending the next isolated test.

### 2026-11-13 — live isolated landing/cleanup PASS

Operator evidence (attachment 7c8bfbf4-a9b7-4a53-92a4-07e44010f158): server phase complete, passed 1/1, cleanupComplete true, restored true, zero automatic/mutation/report retries. Transition serverRemovalConfirmed true, protocol available; server observed projectile net63/type23 removed and Pickup net99/type8 removed. Client probe passed, placement complete/cleaned, nativeOwnerCleanup confirmed, permissionRestored true, economicWrites 0. New pickup stable attachment was attached=true,parent=0. Original normal runtime active afterward with one firearm and all five melee, ammo revision1/revolver regular100 preserved. This confirms the asynchronous completion latch fix and the isolated projectile-to-Pickup cleanup/spent-owner-release/same-session restore path on the current dev server.

Scope remains syntheticNativeOnly; visual report pending. Legacy world model diagnostic stays unconfirmed/originConfirmed false, consistent with server Pickup model unreadability; no claim of engine-authenticated model/origin. Paid publication, inventory conservation through actual throwing/recovery, framework prompt claim and another-player recovery remain pending. Next gate is integrate/audit the existing paid receipt bridge and explicit prompt recovery flow against this now-live-verified transition protocol, keeping paid activation disabled until a bounded deployment/test handoff.

### 2026-11-13 — combined paid-unit prompt test prepared (not live accepted)

Audited the staged normal server/client hosts against the live-passed synthetic projectile-to-Pickup protocol. Normal paid startup now has a prepared opt-in deployment including canonical Inventory spend/binding/claim exports, one-unit commerce, equipped-unit UI, inert Toolkit visual, hold-G ambient prompt, server-only unique lifetime pairing and exact paid metadata/serial binding. Prompt localization uses Core account-settings-backed locale resolution (player feather-settings selection), language-change event and English fallback; checked actual Core locale/settings and Toolkit entity/prompt providers plus saved umaruru reference. Prior original/decompiled research findings remain unchanged; no new engine identity shortcut introduced.

Fixed a combined-host timing hazard: read-only freshness observation continues while ammo.pending waits for a server receipt; runtime rebuild/receive/quiesce/close still suspends observation. Readiness/firing remain blocked by the full busy state. This avoids missing the short-lived projectile while a database request is outstanding. Added local F8 weaponThrowableStatus (read-only, bounded placement/lifecycle/permission state). Completion remains explicitly acknowledged by the ordinary host.

Verified 281 isolated Weapons Lua specs, including real transition/backend/placement/feed/claim composition: no paid publication before server-observed absence, preserved serial/metadata, private-data-free shared offers, distance refusal and one collector claim. Inventory Lua suite passed (native/SQL ports modeled), all five Inventory UI tests passed, Vite build passed, 44 four-resource checkout scenarios passed. No live paid grant or shared-player success claimed. Capacity/retention stress, failure/restart, cross-player recovery and full logout acceptance remain later live gates.

Prepared C:/coding/deployments/paid-throwables-2026-11-13: 77 required runtime/UI files across Weapons, Inventory and Shops. Existing config.lua/shop_config.lua/item images/reports remain untouched. Generated shared paid_throwable_test.lua and server paid_throwable_shop_test.lua activate only when replicated feather_native_paid_throwables=1; require existing native lifecycle config, use contract1 and temporary test price $1.50 for one actual unit. Source defaults remain disabled. No separate Tomahawk ammo offer. Actual PowerShell validation/install/stopped gate/idempotence/hash preservation/unknown-edit refusal plus payload Lua syntax and off/on overlay checks passed at C:/coding/paid-throwable-installer-check-qrpa_t5s. Manifest/new scripts require refresh; coordinated stop/start Shops, Weapons, Inventory with all clients disconnected. Ensure existing Toolkit. No manual schema edits/migrations or full server restart required. Handoff is bounded one-player purchase/equip/throw/prompt recovery/unequip conservation before cross-player live test. No server files changed by this work.

### 2026-11-13 — paid-test startup blocked by mixed SQL collations; fix prepared

First combined live attempt failed before purchase: Accounting's c.character_id=source.character_id join produced ER_CANT_AGGREGATE_2COLLATIONS in both character_ammunition_snapshot and GetInventoryItems. Native readiness exhausted; Inventory then indexed nil RPC results at client/controllers/inventory.lua:131. No paid throwable gameplay pass claimed.

Accounting now resolves the source UUID with an indexed inventory ID query and compares it as a bound parameter against the collection table; it no longer compares differently collated character columns. Both reads retain FOR UPDATE when requested. Non-character inventories return empty carried accounting, missing/malformed headers fail closed, and custody/weight checks remain intact. Client Open rejects nil/non-table inventory replies with the existing localized err_invalid_inventory fallback instead of indexing nil.

Full Inventory Lua suite passed, including real Open response fragment regression and updated custody/weight transaction models. Added actual-Lua Accounting mixed-collation MariaDB regression (reproduces old join error1267 then exercises bound lookup, locked/unlocked). Local unittest: 2 adapter tests passed, 2 MariaDB tests skipped because isolated service unavailable; do not claim actual MariaDB execution. Two-file stopped-resource PowerShell upgrade from exact deployed paid batch passed hashes/idempotence/config preservation/unknown-edit refusal at C:/coding/throwable-startup-fix-check-gkvw1044.

Deploy C:/coding/deployments/paid-throwable-startup-fix-2026-11-13 to corresponding dev-server deployments folder; installer changes only Inventory server/services/native_throwable_unit_storage.lua and client/controllers/inventory.lua. Quit current failed-readiness client; stop Shops/Weapons/Inventory, install fix, ensure Inventory/Weapons/Shops and retain replicated paid-test flag1. No manifest/new runtime scripts changed: no refresh, database ALTER, manual schema changes or full server restart required. Existing initial77-file paid batch must be followed by this fix. Live startup/Inventory open and paid conservation remain pending.

### 2026-11-13 — live combined startup recovered

Operator confirmed after the two-file startup fix: normal Weapons active, one firearm and five melee, ammo revision1/revolver regular100 preserved, Tomahawk pool0. weaponThrowableStatus enabled/ready true, failed/stopped false, lifecycle active, freshness armed at quantity0, permissions suppressed/active. Shops release smoke9/9; reconciliation healthy0pending/failed; Inventory recovery healthy0pending moves/deliveries/refreshes. This confirms live normal loadout snapshot/startup through the corrected accounting query; Inventory-open success was not explicitly stated in this status report. Paid purchase/throw/prompt recovery and conservation remain untested. No further deployment required before the one-unit live gate.

### 2026-11-13 — first paid throw timed out before prompt; receipt-delay fix prepared

Live paid checkout confirmed $1.50 and carry/equip committed. Native observation committed Tomahawk pool1->0, ledger revision2->3; all100 revolver rounds preserved. Placement failed with placement_timeout, landing capturing with no object. Freshness captured original projectile entity624642/net13 at333234ms; paid challenge/landing started336482ms (~3.25sec later). Adapter previously attempted initial native capture only after that challenge, so the short-lived projectile had already become the visible pickup. No cleanup/publication/prompt claim occurred. This is not a shared prompt interaction failure.

New read-only pre-receipt observation starts immediately after the existing single-decrease/fresh-owned-projectile capture. It preserves marker, last samples and successor proposal while the server spend completes. Matching paid challenge binds the existing observation; cleanup, transition approval and publication still require server identity/operation/item receipt. No fake paid unit, pre-receipt economic write, fallback origin proof or widened object search. AcceptTransition/Cleanup explicitly refuse observation-only state. Same existing engine/decompiled source patterns apply; only lifecycle timing changed. Added real client/native adapter/server protocol composition with receipt withheld until3300ms after original removal; no server request/deletion/storage write before challenge, then full authorized cleanup/publication/readback succeeds. Weapons282 isolated specs passed.

The separate live DB.query-inside-transaction warning was traced to Tx:MoveInstance calling GuardsAPI.CanMoveInstance -> InstancesAPI.GetInstance on a separate connection. CanMoveInstance now accepts the internal transaction query and resolves a locked full item/equipment snapshot through it. Generic nontransaction callers retain existing behavior. Shared normalizer preserves description/usable/category fields alongside metadata/identity. Guard vetoes remain active; no bypass. Regression runs actual MoveInstance/guards/normalizer with nontransactional read ports forced to throw, validates exact metadata/definition, locked equipment and external vetoes. Full Inventory Lua suite and44 four-resource checkout scenarios passed (modeled SQL/native ports).

Read-only live evidence for held failed unit: item108, inventory5, row_revision2, serial FW-TOMA-6AF6E130-A6BBF7-0001, purchase order e861209e-df49-11f1-9a69-e0d55eaa2deb, condition/quality100, canonical throwable metadata preserved. No refund/delete/replay/repair performed; retain for explicit later review. Next live run uses one newly purchased unit, not an automatic replay of108.

Five-file update prepared C:/coding/deployments/paid-throwable-receipt-fix-2026-11-13: Weapons client/native_throwable_landing_capture.lua + client/native_throwable_placement_client.lua; Inventory server/services/guards.lua + server/services/transactions.lua + server/controllers/inventory.lua. Actual PowerShell upgrade validation/stopped gate/hash/idempotence/config+manifest preservation/unknown-edit refusal passed at C:/coding/throwable-receipt-fix-check-wisrxv74. Existing paid77 and two-file startup fixes must already be installed. No new runtime scripts or manifest changes: no refresh, manual database change, UI build or full server restart required. Quit failed client; coordinated stop Shops/Weapons/Inventory/install/ensure sequence; keep existing paid-test flag1. Paid throw/prompt conservation remains pending fresh live test, other-player/restart/retention gates remain pending.

### 2026-11-13 — paid landing publication live, prompt claim refusal unresolved

After receipt-delay fix, paid checkout/carry/spend committed and framework visual/hold-G prompt appeared. User completing prompt removes visual/prompt briefly, then it returns without restoring unit. Status: native owner active, ledger revision5/Tomahawk0/revolver100; held native shell item109 observed0; pickup host ready true/failed false, observer rearmed quantity0, no pending prompt at capture. No server equipment-release/restore PASS was supplied for claim. This confirms normal paid placement progressed through publication, but not paid recovery/conservation. Do not mark claims complete or infer a successful inventory grant from visual disappearance.

Exact claim refusal code was discarded by backend beginPickup response mapping and transport projection, and prompt retained no last outcome. Cause still unconfirmed: no native/schema/transaction policy changes made on speculation. Added bounded begin-refusal console code, projected stable refusal code (no private receipt/metadata), and prompt.lastResult diagnostic visible in weaponThrowableStatus. Existing distance/identity/current-reservation/CAS/released-owner checks unchanged; no item repair/refund/grant/replay.

Weapons282 specs passed with regression assertions for backend/coordinator refusal-code preservation, public response projection and prompt last outcome. Three-file diagnostic deployment C:/coding/deployments/paid-throwable-claim-diagnostics-2026-11-13 prepared/PowerShell upgrade verified (C:/coding/throwable-receipt-fix-check-20iggor3). Files: server/services/native_throwable_pickup_backend.lua, server/services/native_throwable_pickup_transport.lua, client/native_throwable_pickup_prompt.lua. No new manifest/scripts, no refresh/Inventory restart/DB changes. Quit client, stop Shops/Weapons, install, ensure Weapons/Shops; reconnect and attempt existing durable pickup once (do not purchase/throw another unit), inspect F8 lastResult and server [WeaponThrowablePickup] refusal. If pickup does not reload, stop before purchase and inspect saved binding. Current unit109 remains governed by durable receipt, prior failed item108 remains held. Shared claims/restart conservation remain pending.

### 2026-11-13 — prompt refusal diagnosed: missing preflight epoch; fix prepared

After client+server restart, existing durable pickup tomahawk:b59a9f4e-df4c-11f1-9a69-e0d55eaa2deb reloaded and diagnostic prompt attempt returned pickup_wear_snapshot_unavailable. Native owner remains active, no pending request, ledger revision5/Tomahawk0/revolver100 unchanged. This confirms durable offer reload after restart but not claim/conservation success.

Exact contract bug found: the pickup-specific ReadNativeEquipmentTransition call passed actorSource/characterId/sessionId and physical limits but omitted bound.epoch. Inventory's NativeThrowableUnitStorage.Read deliberately requires a nonempty current epoch, including when carried quantity is zero, and correctly refused. Other physical equip/finalization paths already carry full context. Fixed the pickup call to include bound.epoch; no Inventory relaxation, grant, storage edit or retry. Current pickup can be retested without buying another unit.

Regression: real Weapons pickup coordinator composition now asserts full identity/epoch and physical limit on its Inventory read port; Inventory actual preflight/storage composition explicitly refuses a missing epoch without custody changes. Weapons282 isolated specs and full Inventory Lua suite passed (SQL/native ports modeled). One-file PowerShell upgrade hashes/stopped gate/idempotence/config+manifest preservation/unknown-edit refusal passed at C:/coding/throwable-receipt-fix-check-ik2ev9ec.

Prepared C:/coding/deployments/paid-throwable-epoch-fix-2026-11-13; only required runtime server/services/native_equipment_transition.lua in Weapons. Quit client; stop Shops/Weapons; install; ensure Weapons/Shops with existing paid-test flag1. No refresh, Inventory restart, schema edit or full server restart. Reconnect and use existing saved pickup once, then capture native/throwable status and claim errors. Live recovery, unequip conservation and cross-player gates remain pending. Retain prior item108 for review; no automatic refunds or item recreation.

### 2026-11-13 — live paid recovery confirmed; NULL-capacity unequip rollback fixed for retest

Paid prompt recovery succeeded: same unit109 restored carried at revision3, ledger revision6/Tomahawk1/revolver100, native owner active and GUID captured under fresh epoch; no new purchase required. Operator then used Unequip one; native cleanup/release completed (closed parent, ownedCopies0, cleanupComplete true), but Inventory transaction rolled back after23queries with throwable_unit_storage_refused, commitOutcome refused/committed false. No claim that unequip/conservation cycle is complete.

Read-only DB confirms unit109 remains in private character_collection inventory4/max_slots3 at revision3; Jane's public inventory1 has max_slots NULL/max_weight NULL/ignore_item_limit0; ledger revision6/pool1 and revolver100 unchanged. Root mismatch: physical return used tonumber(header.max_slots) with no fallback, while ordinary Inventory explicitly defines NULL as Config.maxItemSlots. Updated return maximum to stored numeric capacity or configured default or0, keeping explicit zero/missing invalid defaults fail-closed. Same locked header reused; no new connection, schema edit, capacity enlargement beyond existing Inventory contract, refund or item recreation.

Regression executes real storage/move body with NULL max_slots/configured default and verifies same item returns, plus explicit-zero and missing-default rollback. Full Inventory Lua suite passed (SQL/native ports modeled). One-file upgrade from actually deployed startup-fixed storage validated/stopped-gate/hash/idempotence/config+manifest preservation/unknown-edit refusal passed at C:/coding/throwable-receipt-fix-check-2yxxlhau. Prepared C:/coding/deployments/paid-throwable-capacity-fix-2026-11-13, only Inventory server/services/native_throwable_unit_storage.lua. Quit current closed native session; stop Shops/Weapons/Inventory, install, ensure Inventory/Weapons/Shops with paid-test flag1; reconnect to restore durable carried unit, use Unequip one once. No refresh/new runtime scripts/manifest/UI rebuild/DB mutation/full server restart. Need verify item109 reaches public inventory1/revision4 and ledger advances to Tomahawk0, preserving other ammo. Cross-player, multi-unit, logout/restart/stress and prior item108 review remain later gates.

### 2026-11-13 — first paid Tomahawk conservation cycle live PASS

Operator confirmed after NULL-capacity fix: Unequip one transaction COMMIT (31queries), WeaponNativeEquipmentChange PASS/fresh same-session restore. Read-only database row item109 inventory_id1 row_revision4, matching the same purchased/recovered physical unit. Native runtime active with original firearm and five melee; ledger revision7/Tomahawk0/revolver regular100, no pending/closing/death flags. Pickup host enabled/ready true, failed/stopped false, observation armed quantity0. This completes the first paid one-unit purchase -> carry/equip -> spend/throw -> server-authorized native landing cleanup -> durable framework prompt -> same-item recovery -> return to public inventory live cycle. No replacement item or manual DB repair/refund was used for109. Startup collation, delayed receipt, pickup epoch and nullable public capacity fixes were required along the way; this was not a single uninterrupted clean acceptance run.

Remaining live gates: repeat uninterrupted same-unit cycle on final combined code; carried-unit logout/rejoin and saved exit; two/three units and depletion; another-player recovery/race/distance/capacity handling; restart/failure/retention stress. Prior failed item108 remains held for explicit review. Existing ground-offer reload after client/server restart was observed before claim fix, but full normal multi-player/restart conservation is not yet accepted. No new deployment required for the next uninterrupted one-unit repeat.

### 2026-11-13 — missing Equip traced to death-close freeze; physical death snapshot epoch corrected

After the successful return of109 to public inventory1/revision4, operator reported no Equip action. Current runtime is frozen (ownedCopies1, cleanupComplete false), ammo deathClosing/closing true, reason dispatch_CheckpointAndSeal_failed, last acknowledged ledger revision7/Tomahawk0/revolver100. Operator confirms Jane died and Admin revive was used in between. This is a frozen lifecycle owner, not proof of invalid returned-item metadata or a context-menu regression. Saved-state/precise server refusal evidence requested before reconnect; no writes/repair/retry performed.

Source audit found a definite paired-contract omission: deathPlan passed actorSource/characterId/sessionId to ReadNativeEquipmentTransition with bound.registry.limits but omitted native epoch. Physical unit reader rejects that context even for empty carry. Added bound.epoch; actual Medical provider accepts/normalizes CID/SID and does not reject the extra epoch. Exact live server REFUSED code remains requested; a revive-before-checkpoint medical-state race is not ruled out by generic client reason alone. No medical check or death revision validation relaxed.

Audited all server ReadNativeEquipmentTransition callers: physical pickup now has epoch (previous fix), explicit physical equip/funding-reject route and general physical options route already use bound epoch, finalize-spec already gets full coordinator context; remaining no-limit wear/evidence/repair readers do not request physical-unit snapshots. Death wear service regression now requires exact current epoch in its read port across existing zero/funded, dead revision, exact metadata guards, stale/foreign/duplicate/CAS cases. Weapons282 specs passed; runtime-native/DB ports modeled. One-file PowerShell upgrade from deployed paid baseline passed stopped gate/hash/idempotence/config+manifest preservation/unknown-edit refusal at C:/coding/throwable-receipt-fix-check-18k0zref.

Prepared C:/coding/deployments/paid-throwable-death-fix-2026-11-13; required runtime only Weapons server/services/character_ammunition_runtime.lua. Pending saved-state review, quit frozen client and coordinated stop Shops/Weapons/install/ensure with paid-test flag1; fresh same-character admission reads existing durable balances, no repair/grant. No manifest/new runtime file, refresh, Inventory restart, manual DB change, full server restart or UI build. Next paid gate still uninterrupted existing-unit109 equip/throw/prompt/unequip; death/admin-revive acceptance must be separately confirmed afterward. Prior item108 remains held for review.

Saved-state reply before death-fix handoff: item109 remains public inventory1/revision4; ledger revision7/Tomahawk0/revolver100 unchanged. Operator found no server console refusal line. The missing epoch is a source-confirmed physical death-snapshot contract bug; exact live provider failure was not preserved by generic dispatch reason, so Admin-revive timing/race remains a separate unresolved possibility until tested. No DB repair/refund/grant necessary; fresh login may restore from these confirmed durable balances after installing fix. Current unit109 should be re-equipped only after native active status is restored.

### 2026-11-13 — uninterrupted paid repeat reported functional; latency/visual UX unacceptable

Operator reports final existing-unit equip/throw/framework pickup/unequip cycle all worked; server logs show carry22query/1.511s, spend34query/2.222s, bind11query/5.354s, pickup41query/7.552s, return31query/2.075s COMMITs and equipment fresh-restore PASS. Supplied status revision7/pool0 appears pre-repeat, so do not invent final ledger/item revisions; functional cycle result is operator-confirmed. User reports extremely clunky native-landed -> inert framework visual handoff and slow transactions; asks whether native pickup can now be used reliably.

Current assessment: new server lifetime pairing + canonical spend makes a native-interaction bridge worth investigating, but does not by itself establish exact native collection-event-to-item mapping or atomic ownership for shared recipients. Prior native collection reports lacked an authenticated exact physical-item/pickup identity; server Pickup model unreadability remains. Native visual/interaction and economic authority are separate choices. No native activation/design change made on question alone. Native pickup will not remove demonstrated 5.35/7.55s SQL latency. Proposed next focus is timing/profile unnecessary serial reads/authority revalidation round-trips and assess seamless native visual/prompt handoff using existing verified continuity; retain canonical one-claim transaction and no speculative refunds. Another-player native collection/race/failure proof still pending. Primary Cfx SyncTrees_RDR3 source rechecked online; original/decompiled research record retained.


### 2026-11-13 — native collection identity probe v4 prepared (live pending)

User approved investigating smooth native collection before considering fungible throwable quantities. Per-item metadata remains unchanged. Rechecked original/history and build1491 decompiled references: fm_race_controller func_256 uses network event f_0 as a known pickup handle; short_update func_377/func_1104 identifies AI collector f_2 as Player, not a pickup identity. The observed AI event still has no verified exact-unit handle. Discord is available for research; no additional verified pickup identity solution was established there.

Extended existing read-only event probe to capture exact eight-byte raw event slots as hex strings (no JSON precision loss), local collector comparison, native Tomahawk quantity at event time, and network-handle HasPickupBeenCollected readback where available. The synthetic loan also samples closest-model candidates within2m of its owned projectile's last observed position at100ms intervals, bounded to six fingerprints, and records present/missing-or-changed transitions through event settling. These remain candidate-only, originConfirmed=false/pickupCredits=false; no nearest-model result or opaque event word becomes authority. Object-pool coverage is still partial. Increased loan world-evidence allowance to12 bounded records; pickup events remain6 and global probe32 with event capacity reserved.

All282 Weapons Lua specs passed, including added upper-word fidelity, separate AI/network readbacks and candidate disappearance tests; native/engine ports modeled. Three-file PowerShell batch C:/coding/deployments/native-pickup-probe-2026-11-13 validated against reviewed paid payload: stopped gate, hashes, idempotence, preserved config/manifest, unknown-edit refusal. No manifest changes/new runtime files, DB changes, inventory grants, paid native pickup activation, or metadata conversion. Live source/event-to-exact-successor mapping and cross-player races remain pending. Existing isolated throwable command may still report server_object_lifetime_not_correlated because server model readback remains0; inspect detailed native case evidence rather than interpreting this as paid recovery acceptance. First test is one connected player, paid host disabled before restart, synthetic throw/native collection on nearby clear ground. Preserve existing failed paid item108; do not collect old framework offers during probe.


### 2026-11-13 — isolated probe admission correction (v2, live pending)

Operator hit native readiness retries exhausted after following the initial probe handoff. That handoff incorrectly disabled feather_native_paid_throwables: source confirms this removes ammo_tomahawk_regular from Weapons limits, while Inventory rejects any persisted pool key absent from supplied limits, even when zero. Exact live server refusal code was not captured; source incompatibility is definite. Do not edit/remove the saved ledger key or reset balances. Initial v1 handoff superseded.

Keep paid flag1 and durable units registry intact. Added local pickup-host BeginNativeLoan/EndNativeLoan: begin requires normal owner closed/ownedCopies0/cleanupComplete true, refuses stopped/failed/nested admission, pauses interaction, restores explicit prior pickup permissions and clears stale local placement/offer scope. Server-challenged isolated world-capture fixture invokes this before creating its synthetic unit, and resumes only after confirmed cleanup. Existing single-throw predicate is checked before paid-host readiness in firing enforcement; all ordinary firing remains gated on host readiness. No public native pickup claim endpoint or paid ownership credit added. Native event probe itself remains read-only. No registry/DB authority loosened.

Weapons283 isolated Lua specs passed, including real client host pause/restoration/re-suppression, admission integration and firing fence tests (native/SQL ports modeled). Six-runtime-file PowerShell batch C:/coding/deployments/native-pickup-probe-v2-2026-11-13 passed reviewed baseline/hash/stopped gate/idempotence/config+manifest preservation/unknown edit refusal. Files: client/native_throwable_event_probe.lua, shared/native_throwable_event_reference.lua, client/native_throwable_loan_test.lua, client/native_throwable_pickup_client.lua, client/character_ammunition_client_runtime.lua, client/native_guid_acceptance.lua. All already in manifest; no refresh/schema/UI/full server restart. Quit failed-admission client, stop Shops/Weapons, setr feather_native_paid_throwables1, install six files, ensure Weapons/Shops, reconnect exactly one player and verify ACTIVE before running isolated throwable test. Live native collection identity remains pending.


### 2026-11-13 — isolated loan drew but could not throw; release-state firing fence corrected

Operator reports v2 synthetic Tomahawk could draw but not throw. Source-confirmed integration mismatch: character_ammunition_release.Step explicitly calls api.block(false) when native host closes; firing exemption was conditional on blocked=true. With units enabled and pickup host deliberately paused, the skipped exemption fell through to the normal host-not-ready firing block. Removed the blocked precondition on evaluating the existing bounded server-challenged loan predicate. This does not admit ordinary firing: predicate false/error still reaches the normal readiness fence. No setter to force-enable all firing/controls was added.

Regression now models actual block(false) after release, confirms the isolated predicate permits the throw, and checks false/error still block in that state. Weapons283 Lua specs passed. One-file reviewed-baseline installer C:/coding/deployments/native-pickup-firing-fix-2026-11-13 passed hash/stopped gate/idempotence/config+manifest preservation/unknown-edit refusal. Required runtime client/character_ammunition_client_runtime.lua only; no refresh/schema/UI/full server restart. Current acceptance status and native owner status requested before restart/retry, to confirm unthrown synthetic cleanup and restored normal owner. Correction not yet live confirmed. Keep paid flag1 and prior item108 retained; do not replay unresolved loan.


Live v2 blocked-throw timeout settled cleanly: operator status throwable_world_capture/review_required/loan_throw_or_pickup_timeout, passed0/1, cleanupComplete=true and restored=true, no automatic retries. Normal native runtime ACTIVE with original firearm and five melee, ledger revision11/Tomahawk0/revolver100, no pending/closing/death flags, epoch03196074-dfb9-11f1-9a69-e0d55eaa2deb:1794612904:10780329:2. Parent cleanupComplete=false is expected for the active restored loadout, not evidence of a retained synthetic unit. One-file firing correction may now be installed after orderly client disconnect and resource stop; exact native pickup evidence still pending.


### 2026-11-13 — native collection probe v4 live functional PASS; exact identity unresolved

Operator supplied F8 capture and detailed native report after firing correction. Synthetic case passed1/1, economicWrites0, cleanupComplete=true, restored=true. Overall remains review_required/server_object_lifetime_not_correlated: server model0 readbacks reject matching; no automatic mutation/report retries. Normal runtime restored ACTIVE at epoch9c4113a1-dfbb-11f1-9a69-e0d55eaa2deb:1794613326:11202621:2, ledger revision11/Tomahawk0/revolver100, original firearm/five melee, no pending/closing/death flags. No paid recovery acceptance or metadata conversion.

Exact observed client timeline: elapsed6070ms native throw quantity0 and owned projectile entity430082/net23/model3358573347; at6281ms original missing/changed and closest-model successor entity435970/net24 present (211ms later). At11385ms AI queue0/event-178091376 reports collector16 == localPlayer16 and native Tomahawk quantity1. At11469ms candidate net24 missing/changed (84ms after event) and a nonnetworked same-model object entity450050 appears. This supports normal native interaction and likely projectile->pickup->held visual progression, but the nearest candidate and local visual are not proven continuity/ownership links. No network pickup event/handle was captured. Unknown AI f_5 lowword147252816/fullword0000027d08c6e650 remains opaque; mixed nonzero upper words in other slots warn against interpreting full64bit values as script handles. No undocumented pointer dereference or guessed object conversion introduced.

Outcome: firing/permission isolation now works live, native pool1->0->1 plus cleanup/restore works with no economics. Do not repeat the same one-unit test expecting server model support to change. Next development should attach collection observations to the already server-bound exact successor lifetime (using existing spend/transition context), explicitly handle ambiguity/other same-model pickups and another collector, and test reject/reconcile behavior before paid native claims. Native collection alone still does not identify the paid unit from this evidence. Preserve current working framework prompt path and metadata model while evaluating that bridge. No new deployment required to interpret this run.


### 2026-11-13 — lifetime-bound native collection observation staged and ready for isolated test

User disabled guid suite after successful native pickup and authorized next part; also raised recovered arrows. Design: keep lifetime/collector correlation separate from projectile-specific event profiles. Recommend fungible units by arrow type if arrows are added, with duplicate/race protection; no arrow native support, metadata migration or approval of arrow catalog implied. Existing sources/history rechecked: fm_race_controller func_256 network handle versus short_update func_377 AI type/collector. No verified AI exact pickup handle discovered.

Added read-only NativeProjectileCollectionObservation factory. Watches require a currently valid server transition proof, exact item/revision and pickup lifetime/network ID; duplicate unit/lifetime watches refused. Observations use explicit1491 AI Tomahawk profile, one unit/local-collector consistency, authoritative server actor identity/bucket/distance, server-confirmed bound lifetime absence. Competing nearby watched lifetimes (including removed ones), late/unsupported events, stale/moved/dead/foreign-epoch collector, duplicate events/second observation and failed reads refuse or retain review. Reports always canClaim=false/pickupCredits=false/originConfirmed=false/economicWrites0; it cannot confer ownership. Unwatched/unknown world pickups remain an unresolved ambiguity outside this diagnostic's watched set. No paid native claim integration activated.

Added synthetic-only NativeProjectileCollectionProbe composition with real TransitionBinding and Observation factories. Existing isolated throwable command now sends bounded owned-projectile, landed-candidate and collection-event hints under server ticket/source/current-session gates. Factory uses only synthetic900000001/itemRevision1 receipt, actor/native reads and callback history; no Inventory writes/publication. Binding must be established while successor exists; early collection is explicitly collection_before_binding. More than one candidate yields competing_native_candidates. Event-read-before-removal is sampled at100/300/600ms, read-only; never mutation replay. Server report adds collection diagnostics while old model-readable world matcher still may produce overall review_required/server_object_lifetime_not_correlated. Keep those independent outcomes; even correlated_observation does not certify paid pickup or engine origin.

Tests:285 isolated Weapons Lua specs pass, including foreign collector with original exact proof/metadata, real TransitionBinding + Observation composition, ambiguity with live/removed candidates, scope/distance/bucket/death/epoch, pending removal/expiry/replay/failures, and synthetic probe real-binding composition. Native/SQL ports modeled. New modules are factories only, instantiated in explicit isolated acceptance; normal paid path unchanged. Six-runtime-file PowerShell batch C:/coding/deployments/native-collection-binding-probe-2026-11-13 passed hashes/stopped gate/idempotence/config + paid overlay preservation/unknown edit refusal. Manifest preserves both installed paid test overlays and adds two server scripts. Required files: fxmanifest.lua; server/services/native_projectile_collection_observation.lua; server/services/native_projectile_collection_probe.lua; server/services/native_guid_acceptance.lua; client/native_guid_acceptance.lua; client/native_throwable_event_probe.lua. Prior v2 + firing correction remain prerequisites. Refresh required after installation because manifest/new server script list changed, followed by ensure Weapons/Shops; no Inventory/schema/UI/full server restart. Keep paid registry flag1. Next live gate one connected player, clear ground isolated throw, allow landing before native collection, detailed report.collection + native case evidence and normal restored state. Two-player/race/overlapping physical pickups and paid atomic commit compensation remain later gates. Prior held item108 untouched.


### 2026-11-13 — first lifetime-bound native collection observation LIVE PASS (synthetic, one player)

Operator supplied report.collection=correlated_observation and native case passed1/1, cleanupComplete=true/restored=true/economicWrites0, no automatic retries. Actual server callback history: projectile net53/type23/generation1 created12860299 removed12860475; pickup net19/type8/generation1 created12860422 removed12866963; same owner9/bucket0, registered2, no native read errors or deferred readiness. Synthetic item900000001/revision1 is associated with pickup lifetime2, original/collector same bound native-loan identity (Jane). canClaim=false/pickupCredits=false/originConfirmed=false remain intentional. Old model-readable world matcher still yields overall review_required/server_object_lifetime_not_correlated; it is not a failure of the separate collection correlation stage.

Client timeline: owned projectile net53 at8726ms, successor candidate net19 at8929ms; AI collection at15351ms reports localPlayer16/collector16 and native quantity1, local same-model object at15366ms, candidate net19 missing at15470ms. Raw opaque slot6 value2021962064 is not a pickup/network ID. Post-test normal loadout ACTIVE, original firearm and five melee, ledger revision11/Tomahawk0/revolver100 unchanged, no pending/closing/death flags, restored epoch5740c406-dfbf-11f1-9a69-e0d55eaa2deb:1794614992:12867780:2. No paid item moved or recreated by the synthetic test.

This confirms one-player native interaction + registered synthetic transition lifetime + collection/removal observation composition live. It does not establish adversarial exact-item ownership from the event, paid recovery, cross-player pickup, concurrent/racing collectors, competing untracked pickups or restart durability. Next gate: extend isolated harness for a second collector and competing pickup identities, retain no economic writes until those outcomes are observed. Do not repeat the same one-player happy path or enable a paid claim from this pass. No new deployment required to interpret the evidence. Disable guid suite after this run; keep paid units registry1.


### 2026-11-13 — two-player native collection acceptance harness ready (live pending)

Operator confirms a second player is available, but will control both clients sequentially. Added console-only WeaponGuidAcceptance shared <thrower-server-id> <collector-server-id>, exactly two connected distinct current characters/idle owners. Both native owners are reserved/released through existing GUID dry-run barriers; both saved Inventory/ammo/guard snapshots and native views are audited before/after, requiring fresh restored epochs and exact saved/native equality. Shared-only durable audit explicitly permits a zero-firearm baseline so a fresh collector needs no purchase; normal firearm acceptance still requires its previous baseline. No paid claim/grant/SQL-economic port added.

Thrower creates one synthetic unit900000001; only designated collector events are accepted as foreign collection observations. Collector waits with native pickup permission restored, never grants ammo, captures the actually collected native GUID through existing idle AcceptPhysicalPickup using synthetic receipt, then removes that exact GUID and verifies all native pools return to baseline. Thrower may retire only its spent entry after the server has both a passed/cleaned collector report and correlated removal of the exact bound pickup lifetime. Cleanup of a different unit cannot certify the thrower's world object. Collector report is saved/read back before acknowledgement; up to three report-only sends, never replay native recapture. Group cleanupComplete requires both; partial failure retains review. Both players' normal paid pickup suppression is restored on confirmed native cleanup. Synthetic serial is consistent ISOLATED-SHARED-LOAN; no paid item metadata migration.

Three-minute native interaction/capture window accommodates switching clients. Jane throws5–8m onto clear ground, stays still, operator switches to parked second player and collects; no simultaneous actions. Watch TTL shared180s, native server reservation300s. Ordinary one-player fixture retains90s. Shared collector never receives firing exemption. Death/session changes, duplicate tickets, wrong-role/source replies, uncorrelated removal and cleanup failures do not authorize a retry or pickup credit. Shared failure recovery is not generalized/automatic; preserve both status reports before any further action.

Added read-only TransitionBinding.CollectionPresent(proof,collectorSource) for expected native ownership migration to designated collector while awaiting removal. It revalidates exact registered generation, paid/synthetic receipt, origin scope and collector bucket/alive state. Existing Current cleanup authorization still rejects migration/unreadable owner; no cleanup authority transferred. This migration handling is source-informed design plus modeled regression, not yet live cross-player proof. Engine AI event still lacks a verified exact pickup handle; all reports canClaim/pickupCredits/originConfirmed remain false. Competing bound/candidate rejection remains automatically tested; live competing pickup/race test is deferred until this foreign collector baseline works. Arrow type/profile/quantity design remains separate; no arrow runtime enabled.

Weapons288 isolated Lua specs pass. Includes real idle native owner foreign recapture/cleanup, full-pool conservation, >90s sequential-switch case, no collector creation, ambiguous quantities/failed events/timeouts/epoch/pool failures; source/closed-owner client wiring and report ack/replay; cooperative real server harness with both release barriers, distinct roles, both durable audits/restores, report resend, partial cleanup and wrong-lifetime refusal; normal cleanup vs designated-collector migration tests. Native/DB/client IO ports modeled. Ten-file PowerShell batch C:/coding/deployments/native-shared-collection-probe-2026-11-13 passed reviewed last-deployment baseline/hash/stopped gate/idempotence/config + paid overlay preservation/unknown edit refusal, evidence C:/coding/throwable-receipt-fix-check-p_sltqfj. Required runtime: fxmanifest.lua; shared/native_acceptance_view.lua; client/native_throwable_collector_loan_test.lua; client/native_throwable_loan_test.lua; client/native_throwable_event_probe.lua; client/native_guid_acceptance.lua; server/services/native_throwable_transition_binding.lua; server/services/native_projectile_collection_observation.lua; server/services/native_projectile_collection_probe.lua; server/services/native_guid_acceptance.lua. Manifest adds collector helper, so refresh then ensure Weapons/Shops required after both clients quit/install. No Inventory/schema/UI/full-server restart. Keep paid registry1, use current server IDs from txAdmin Players, never CID/old session IDs. Live cross-player result pending; previous one-player correlation stays recorded as synthetic diagnostic PASS only.


Final shared-test batch refreshed after late collector-report acknowledgement handling (acknowledged, cleaned local fixture may clear its retained admission without replaying native work). Weapons288 specs and ten-file installer checks passed again; latest installer fixture C:/coding/throwable-receipt-fix-check-8drnfxwp. Test handoff saved at C:/coding/deployments/native-shared-collection-probe-2026-11-13/TEST-HANDOFF.txt. Shared live acceptance remains pending; no deployment performed by agent.


### 2026-11-13 — first shared live test FAILED at fresh collector GUID recapture; preserve state

Two actual parties admitted: Jane source10/CID688a98dc-de34-11f1-9a69-e0d55eaa2deb/SIDeee12862-dfc4-11f1-9a69-e0d55eaa2deb; fresh collector source11/CID1d78d31a-dfc5-11f1-9a69-e0d55eaa2deb/SID1ddba819-dfc5-11f1-9a69-e0d55eaa2deb. Fixture guid-suite:1794617997:1. Collector helper observed native quantity1 (required to reach line29) but AcceptPhysicalPickup failed before captured=true; generic assert hid second return. Shared report: failed/captured=false/cleanupComplete=false, no Inventory/economic writes. Collector trace stopped with no local AI pickup event retained. Jane saw projectile net44 -> candidate net75, then remote AI event with collector31 != local16, native quantity0, f_1/f_6=-1/inventoryItemHash0; candidate net75 subsequently missing. This remote event is not the local collector profile or an exact GUID link.

Both normal parents now closed/ownedCopies0/cleanupComplete=true; pickup hosts paused/disabled. This only certifies original loadout release, not exact cleanup of temporary foreign native unit. Server collector rebuild froze (guid_suite_cleanup_unconfirmed); thrower suite aborted (guid_collector_transition_frozen_no_retry/rebuild_adapter_exception). Collection/native final evidence absent in saved report because collector failure preempted main finalization. No cross-player acceptance, recovery/refund, paid claim or automatic replay approved. User confirms Tomahawk is not on ground, in Inventory or wheel. Current ammo/GUID not yet directly inspected; possible pool-before-GUID timing or ammo-only native recovery on fresh no-carrier collector, not established fact. Original/decompiled sources have not established automatic foreign carrier creation.

Source-only diagnostic corrections queued, not deployed to frozen sessions: preserve exact second capture return and native owner status/quantity in future collector reports; preserve read-only server collection/world evidence on main error before discarding run. Weapons289 specs pass after these and added independent inspector tests. No behavioral GUID retry, creation fallback, forced ammo reset or metadata conversion implemented while cause remains uncertain.

Prepared independent temporary read-only resource feather-weapons-pickup-inspect, outside normal Weapons manifest, source diagnostics/native_pickup_inspect/{fxmanifest.lua,inspection.lua,client.lua}. F8 weaponPickupInspect explicitly reads build1491, local ammo quantity, HasPedGotWeapon and original CHARACTER -> CARRIED_WEAPONS -> SLOTID_WEAPON_0/1 inventory hierarchy, exact GUID/model readback. Uses only existing verified inventory-read natives0x886DFD3E185C8A89/0x9700E8EFC4AB9089 plus read-only ped/ammo APIs. No startup reads/threads, setters, creation, deletion, exports, net routes, Core/SQL writes or permission changes. Diagnostic values cannot authorize a claim. Tests cover ammo-only/unique/ambiguous/absent parent/build/context/model/readback changes plus concrete command-only read hash allowlist. This does not assume a unique same-model GUID is owned by the fixture.

Deployment C:/coding/deployments/native-pickup-readonly-inspect-2026-11-13 contains three runtime files and separate PowerShell installer supporting new sidecar directory. Verified no-write validation, explicit sidecar-not-running gate, hashes, idempotence and unknown-edit refusal, fixture C:/coding/pickup-inspect-check-j387xkmj. Keep clients and all existing gameplay resources running; only add helper folder, refresh, ensure feather-weapons-pickup-inspect, run command in collector and Jane F8 and preserve reports. No existing Weapons/Inventory/Shops restart or file modification, no DB changes. Current frozen-state recovery decision pending these reads; no rerun/archive/reconnect requested.


### 2026-11-13 — live fresh-collector ammo-only recovery confirmed; strict zero-ammo carrier fix ready

Read-only inspector evidence while both failed sessions remained connected: John build1491 quantity1/quantityAfter1, weaponPresent=false/After=false, complete carried hierarchy read with guids[]/inventoryPhase absent. Jane quantity0/After0, weaponPresent=true/Aftertrue, unique slot0 GUID80000000000000001da48367d779134b. This confirms ammo-only native pickup on this fresh collector and an empty native carrier remaining on the thrower. It does not prove the observed Jane GUID equals the fixture's original captured GUID, and the read-only sidecar has no cleanup/claim authority. No database or native repair was performed. Original shared acceptance remains failed/captured=false/cleanupComplete=false.

Metadata model stays intact: database unit ID/revision/serial/maintenance belong to canonical server custody; the recipient's native carrier GUID can be newly materialized after native ammo collection. No need to drop metadata from this observation. Native event/collector/lifetime proof and paid atomic claim remain separate pending gates. Future arrows should remain ammunition-type recovery and require an owned bow under its own policy; picking up an arrow must not imply a free bow.

Implemented optional preserveExistingPool=true in local ThrowableOwner.Create and concrete createFunded port, physical contract2/max3 only. Requires current native count exactly matches approved funded count, weapon and native carried GUID absent. Reuses original zero-quantity GiveWeaponToPed and GUID path, but never calls an ammo setter if creation reduces that count: hold/retain on any count change instead. All other known pools still checked. Repeated creation is refused. Normal creation behavior unchanged. Synthetic foreign collector now captures actual event evidence before carrier materialization, validates the existing physical recovery receipt, uses strict zero-ammo carrier materialization if HasPedGotWeapon=false, or existing read-only GUID rebind if present, then exact cleanup/full-native-pool baseline verification. No paid native claim route activated or new SQL entitlement introduced.

Added console recover-shared <current-Jane-server-id> <current-John-server-id> for retained failed shared reports. Requires both original characters in fresh active sessions and original role order. Reads both canonical durable snapshots and actual native views against retained before/sharedBefore (allowing empty-firearm collector baseline), tolerates only usual float representation difference in private comparison copy, archives original evidence before success, then marks recovered_shared_session_failure/restored/collectorRestored. Does not release owners, mutate balances/items, retry native fixture, repair differences or retroactively certify original cleanupComplete. Changed durable state or same-session participant refuses. Existing ReconcileSession handles fresh session admission/retirement of stale coordinator scope. Recovery must be verified before archiving/repeating the shared fixture.

Weapons289 isolated Lua specs pass: real concrete native port validates zero-quantity carrier with already-collected unit, zero setters/no ammo addition, unexpected pool loss retained without restoration/retry, existing carrier/GUID refusal, real collector owner materialization/cleanup and foreign-pool conservation; shared recovery accepts both fresh unchanged sessions with no new native transitions and preserves cleanup=false, rejects stale participant and changed durable state. Native/SQL ports modeled; carrier fix not yet live accepted. Five-file PowerShell batch C:/coding/deployments/native-shared-carrier-fix-2026-11-13 validated against reviewed shared deployment and paid owner/adapter baselines; stopped gate/hash/idempotence/config+manifest preservation/unknown edit refusal passed at C:/coding/throwable-receipt-fix-check-o30vxqwd.

Required runtime only client/native_throwable_owner.lua, client/native_throwable_adapter.lua, client/native_throwable_collector_loan_test.lua, client/native_guid_acceptance.lua, server/services/native_guid_acceptance.lua. No manifest change/new normal script, refresh, Inventory/schema/UI/full-server restart. Next handoff full quit both game clients (no successful frozen Save/Exit checkpoint assumed), preserve failed report, stop only read-only helper/Shops/Weapons after both disconnected, keep paid registry1, install five files, ensure Weapons/Shops, reconnect same characters and verify ACTIVE plus canonical Tomahawk0 on both, Jane revolver100/revision11 and John empty/revision0, run recover-shared read-only verification. Do not begin another shared fixture until recovery result is reviewed. Prior cleanupComplete=false remains historical evidence even if recovery confirms current fresh loadouts. Held paid item108 remains untouched.


### 2026-11-13 — failed shared fixture recovered in two fresh sessions, live read-only verification PASS

Operator installed strict carrier fix, fully quit/rejoined both clients and ran recover-shared12 13. Report phase recovered_shared_session_failure/recovery confirmed/restored true/collectorRestored true, original passed0 and failed sharedCollector cleanupComplete=false preserved. Read-only recovery compared both original before/sharedBefore durable snapshots and native views; no repair, native creation or fixture retry performed. Jane CID688a98dc-de34-11f1-9a69-e0d55eaa2deb active at epoch18a66a69-dfd4-11f1-9a69-e0d55eaa2deb:1794623756:21631957:1, ledger revision11/Tomahawk0/revolver100, original firearm/five melee, no pending/closing/death flags. John CID1d78d31a-dfc5-11f1-9a69-e0d55eaa2deb active at epoch1b99085b-dfd4-11f1-9a69-e0d55eaa2deb:1794623762:21638216:2, ledger revision0/all pools0, zero firearm/melee copies, no pending/closing/death flags. Source IDs12 Jane/13 John current for this next test only. Parent cleanupComplete=false is normal while restored runtime active.

Canonical saved state unchanged and normal fresh loadouts confirmed. No further deployment or restart required before strict zero-ammo carrier shared retest. Retain old failure archive via explicit archive command, re-arm guid suite (recover consumed flag), shared12 13 while current IDs remain valid. Sequential throw/wait2s/switch/collect within3min; no purchase/equip extra Tomahawks. New live carrier materialization/conservation and collector local AI event profile remain pending; do not infer success from recovery. Prior paid item108 untouched.


### 2026-11-13 — zero-ammo recipient carrier LIVE PASS; donor confirmation held by removal validation

Retest guid-suite:1794625621:3, sources12 Jane/13 John. Shared collector live passed: quantityAtCapture1/captureMode zero_ammo_carrier/captured true, exact native GUID acquired for synthetic900000001/revision2 then owner phase released, cleanupComplete true/economicWrites0. Local AI event at23864ms is full supported profile: local collector16, native quantity1, pickupType3397143806/model3358573347/inventoryItemHash2783539927. John normal runtime restored ACTIVE with ledger revision0/all pools0, ready pickup lifecycle, no pending/closing/death flags. Strict carrier strategy now live-supported for this fresh no-carrier collector; no need to discard canonical per-unit metadata from this result.

Donor remained closed and fixture timed out/retained: projectile net3 -> pickup net117; remote AI witness collector31 !=local16/native quantity0/inventoryItemHash0, then candidate missing. Saved server collection report confirms registered projectile generation1/type23/owner12 created23509679 removed23510220; pickup generation1/type8/owner12 created23510161 removed23522911; no creation read errors or competing registered generation. Observation ended review_required/transition_authority_changed despite eventual registered removal; no donor shared-collected notification was issued. Final case cleanupComplete false/uncollected_test_projectile_retained_no_retry, overall review_required/passed0. This is harness-held donor state, not evidence John failed pickup/cleanup. Both contexts preserved pending patch/recovery. Do not call full shared cycle accepted.

Source audit found an actual observation-state gap: Current/CollectionPresent rejects once the removal callback is seen; Absent rejects until native readback is absent. Reverse ordering also fails if native absence appears before callback. Existing observation treated both transitional gaps as terminal authority changes. Prior report lacks exact native readback/rejection details at first failure, so which ordering caused this live rejection is not established; these modeled races produce the same rejection. Added read-only CollectionPending that preserves exact reservation, unique generation, candidate count, origin/collector scope, challenge and canonical receipt guards while waiting up to the existing750ms observation window for both callback and absence. Strict Current cleanup and Absent authority remain unchanged; pending never grants cleanup, claim or ammo credit. Supports native-before-callback and callback-before-native-finalization, rejects replaced net IDs and changed receipt. Reports now retain collectionRead native/callback fields and specific collectionRejection reason for next live diagnosis.

Also corrected independent event-source lifetime hazards: snapshot collection/shared-ready/shared-result source before Core/export checks; pass captured player to probe and acknowledgement instead of rereading global source after possibly yielding calls. Regression simulates global source resetting during Core validation; designated collector identity and acknowledgements remain correct. This was not proven to be the current live rejection (an observation was admitted); it is separately verified hardening.

Weapons289 specs pass including both real binding/removal ordering compositions, receipt and native replacement refusal, cross-player scope and source-reset cases. Four-server-file PowerShell batch C:/coding/deployments/native-shared-removal-fix-2026-11-13 passed reviewed carrier/shared baselines, hashes/stopped gate/idempotence/config+manifest preservation/unknown edit refusal, fixture C:/coding/throwable-receipt-fix-check-tcjqd0wd. Required runtime only server/services/native_throwable_transition_binding.lua, native_projectile_collection_observation.lua, native_projectile_collection_probe.lua, native_guid_acceptance.lua. Client carrier code unchanged. No manifest/new scripts, refresh, Inventory/schema/UI/full-server restart. Full quit both clients, preserve failed report, stop Shops/Weapons, paid registry1, install/ensure, reconnect same characters and recover-shared current role IDs. Only after read-only recovery confirms both unchanged active loadouts may archive/re-arm/shared retest. Stop John after native pickup for diagnostic sampling. Historical failed cleanup remains in archived report. Live removal-settlement fix and complete shared cycle pending; paid claims still disabled, prior item108 untouched.


### 2026-11-13 — removal-fix retest: recipient carrier PASS repeated; donor retained, final server diagnostics requested

Operator supplied two client traces for guid-suite:1794628549:3 and PowerShell sharedCollector output. John again passed zero_ammo_carrier, quantityAtCapture1, captured=true, exact owner released, cleanupComplete=true/economicWrites0; local full AI profile at25661ms. Normal John restored ACTIVE at epoch7f17b349-dfde-11f1-9a69-e0d55eaa2deb:1794628578:26454439:3 with ledger revision0/all pools0 and ready normal pickup host. This confirms repeatable recipient carrier/capture/retirement in these two runs, not full shared acceptance.

Jane source trace: original active snapshot revision11/Tomahawk0/revolver100, then released for fixture. Projectile net104 -> successor net21 (~633ms later), remote collector31/local16 event at25480ms with native quantity0/IHash0, candidate21 missing25563ms; later local same-model candidate appeared/disappeared without network ID. Capture ended loanStage retained at full180s; native parent stayed closed/ownedCopies0/cleanupComplete=true, host paused. No donor restoration shown. PowerShell report.collection was empty while sharedCollector had passed; final report.phase/reason/transitionReason/native cases were not provided. May be an intermediate persisted report before donor finalization/transport; do not infer exact new failure or patch again from an absent section.

Requested current server WeaponGuidAcceptance status plus report phase/reason/transitionReason/cleanupComplete/restored/collectorRestored and full report.collection after this run. Both clients to remain connected; no archive/retry/restart/new deployment requested. Removal-fix exact native readback/collectionRejection fields are needed to distinguish callback settlement, authority rejection, or incomplete report delivery. No new runtime edits made in this result-review turn. Full shared cycle, competing pickups and paid claims remain unaccepted; prior canonical metadata and item108 unchanged by diagnostic design, no new post-run durable audit yet.


### 2026-11-13 — shared native collection filter diagnostics; live recipient pass, candidate rejected

Final saved report for the removal-fix retest confirms collection review_required/no_bound_candidate, before native removal validation. Projectile104/type23 and pickup21/type8 each have one registered generation, owner14/bucket0; recipient zero-ammo carrier capture and exact cleanup passed, donor fixture retained. Overall shared cleanup remains false. Operator confirms every pickup was performed by walking directly over the visible item; do not attribute the rejection to operator distance. First candidate position is sampled only when the replacement object first appears, so a stale proposal position is a hypothesis, not established cause. Existing report omits filter positions and rejection inputs. Remote Desktop access to the server report in VS Code was verified; operator need not relay the full JSON through Steam.

Added read-only candidateDiagnostics to collection observations: source, received/current collector position and bucket, two-metre squared threshold, watch age limit, each bound watch position/network lifetime, squared distance, age and each acceptance predicate. Rejected watches remain visible; diagnostics are copied and bounded by the existing64-watch admission cap. No range, candidate selection, ownership, native calls or economic behavior changed. Added regression cases distinguishing distance, bucket and expired-watch rejection plus report-copy isolation; all289 isolated Lua specs and runtime syntax pass. Rechecked original short_update func377's eight-slot AI event profile and cached RSG/VORP source patterns; none supplies an authoritative framework per-item pickup identity or validates widening this range.

Prepared one-file diagnostic batch C:/coding/deployments/native-shared-position-diagnostics-2026-11-13 with Install-SharedPositionDiagnostics.ps1; installer verified against reviewed removal-fix baseline, hashes, stopped gate, idempotence, unknown-edit refusal and config/manifest preservation. Runtime file server/services/native_projectile_collection_observation.lua only. Local initial installer verification under Windows PowerShell was blocked by local execution policy; rerun using bundled PowerShell7 passed. No live installation/test claimed. Preserve failed evidence, reconnect both characters and confirm read-only recover-shared before archiving/retesting. No schema/Inventory/UI/manifest/new-script changes or refresh required. Full shared acceptance, races and paid native claims remain pending; prior item108 unchanged.


### 2026-11-13 — shared fresh-session recovery confirmed through Remote Desktop

After the operator reconnected both characters, txAdmin showed player16 LazyBat6934 and player17 CleverFrog2715. Executed set feather_native_guid_suite1 and WeaponGuidAcceptance recover-shared16 17 through txAdmin's application console (not Windows terminal automation). Live result at20:34:20: recovered_shared_session_failure, recovery confirmed, restored true, collectorRestored true. This command verifies original role identities, fresh sessions and unchanged durable/native loadouts; historical cleanupComplete false and no_bound_candidate failure remain preserved. Requested evidence-only archive after confirmed recovery; next shared diagnostic test is operator-controlled so its three-minute window starts when both clients are ready. No economic repair or replay performed. Resource restart was visible in server history; installer hash output was not independently inspected.


### 2026-11-13 — shared diagnostic attempt interrupted by collector death

Operator reported John was too close and died during Jane's attempted throw. Inspected txAdmin through Remote Desktop at20:41. Run shared16 17 started20:36:56 and failed20:37:10: sharedCollector reason collector_scope_changed (native_throwable_collector_loan_test.lua:17), captured false, nativeOwner idle/guidCaptured false, cleanupComplete false; server guid_collector_transition_frozen_no_retry at native_guid_acceptance.lua:551. Collection not correlated, registered lifetimes0, projectile/pickup generations0, world recordCount0. Donor/collector rebuild failures retained. No successful throw or bound pickup inferred from this attempt, no position diagnostic conclusion. This is an interrupted test, not a regression verdict on the new candidate diagnostics. Do not archive/replay in the failed sessions. Next handoff: fully quit both clients to end synthetic native lifetimes, reconnect same original characters; if John remains dead, use existing MedicalRespawn path after its timer. Then verify both fresh active sessions with recover-shared using current role IDs before evidence-only archive/new run. No runtime/database repair, grants or revive performed by agent. No additional deployment required.


### 2026-11-13 — recovery after collector-death interruption LIVE confirmed

Both characters reconnected as Jane18/John19; txAdmin player list verified. Read-only recover-shared18 19 at20:47:11 returned recovery confirmed, recovered_shared_session_failure, restored true and collectorRestored true. Original failed cleanup remains false; no inventory/ammunition repair or replay. Server history showed admin revive request after reconnect; recovery nevertheless confirmed both fresh native/durable loadouts unchanged. Issued evidence-only archive after confirmation. Next operator test uses shared18 19, with collector parked behind thrower until ground landing; user starts window when ready. No new runtime changes or deployment.


### 2026-11-13 — first complete synthetic shared native collection/cleanup/restore LIVE success

Operator confirmed John collected in shared18 19 run native-loan:guid-suite:1794632113:8. Read final txAdmin result directly through Remote Desktop at20:56. passed1/total1, cleanupComplete true, restored true, collectorRestored true; collection observation correlated_observation/client_event_not_ownership_proof with watch isolated-native-pickup, synthetic item900000001/revision1/pickupLifetime2. Projectile30/type23/owner18 generation1 created30001642 removed30002063; pickup116/type8/owner18 generation1 created30002018 removed30015745. New candidate diagnostics show candidateCount1, age13788ms, squared collector distance1.30283168889582 (about1.14m), same bucket0, within age and distance; accepted true. Stored candidate position (-388.3882751464844,809.4869995117188,114.84536743164063). This run validates the diagnostic deployment and existing2m filter; it does not explain the historical no_bound_candidate run because that earlier report lacked positions.

John sharedCollector passed zero_ammo_carrier, native quantityAtCapture1, exact GUID captured/released, cleanupComplete true, economicWrites0. Local full AI profile at24993ms, nativeTomahawkQuantity1. Donor received bound correlated confirmation, completed exact spent-entry retirement, and both fresh-epoch saved/native audits passed. This is the first live complete synthetic shared native collection/cleanup/restore cycle, distinct from prior recipient-only successes. No recovery/reconnect is required for this completed run. Do not reinterpret historical failed cleanup as repaired.

Overall report intentionally remains review_required/server_object_lifetime_not_correlated from the older model-based world probe: server GetEntityModel for RDR3 pickup/worldprojectile remains0, world matchCount0/originConfirmedfalse. Collection canClaimfalse/pickupCreditsfalse/originConfirmedfalse and economicWrites0 remain. Native event+scope+lifetime correlation is observed, not paid economic authority. Next design work: report the independent native collection lifecycle result separately from legacy world-model capability; test competing lifetimes/replay and scope changes before integrating canonical paid claim transaction. Do not widen radius or claim stale first-position hypothesis proven by this successful run. Existing paid prompt route unchanged; no paid native transfer enabled, no prior item108 repair. No runtime change or new deployment in this result-review turn.


### 2026-11-13 — synthetic shared lifecycle acceptance separated from model diagnostics (implemented, live pending)

Following the first complete shared synthetic native collection/cleanup/restore run, changed server native_guid_acceptance.lua so shared synthetic acceptance no longer inherits the independent world-model matcher failure. Keeps full world evidence/phase unchanged; standalone throwable world-capture acceptance still requires its original matcher. Shared runs now explicitly require correlated_observation even when the model matcher says matched. Report acceptanceScope synthetic_shared_native_lifecycle and lifecycle result published only after both fresh-epoch native/durable audits, cleanup and recipient result checks. Success has lifecycle passed and overall complete; originConfirmed/canClaim/pickupCredits remain false, economicWrites0/syntheticNativeOnlytrue. Failures retain review_required, explicit scope and no paid authority. No retroactive rewrite of live evidence, Inventory export, claim route, native engine changes or metadata migration.

Regression extends the real shared acceptance server scheduler: unconfirmed model diagnostics plus valid collection/restores pass only synthetic scope; matched world diagnostics with uncorrelated collection cannot pass. Added two-collector pending-removal race in both winner orders: one retained observation, second refused lifetime_already_observed; duplicate event IDs and fresh replay IDs cannot reuse the lifetime, rereads stable. A competing nearby watched lifetime arriving after initial observation but before removal settles causes ambiguity. Existing scope/death/expiry/net generation/receipt tests retained. All289 isolated Lua suites and runtime syntax pass. These race checks are modeled; live simultaneous collector and nearby-unit tests remain pending. The two-client operator can switch sequentially for the happy path; automated race coverage does not imply live simultaneous input was tested.

Prepared one-runtime-file batch C:/coding/deployments/native-shared-lifecycle-report-2026-11-13 with Install-SharedLifecycleReport.ps1. Installer hashes/stopped gate/idempotence/config+manifest preservation/unknown-edit refusal passed against reviewed installed removal-fix source in fixture C:/coding/throwable-receipt-fix-check-l2ldumjr. Runtime only server/services/native_guid_acceptance.lua. No manifest/new scripts/refresh/Inventory/UI/DB/full server restart needed. Installation and revised report live test pending. Current prior run cleanupComplete true/both restored, so reconnect after controlled Weapons restart is sufficient; retained report remains until evidence-only archive for next test. Paid native collection integration deferred until remaining validation; existing paid prompt route unchanged.


### 2026-11-13 — separated shared lifecycle report LIVE PASS

After one-file reporting deployment and reconnect, txAdmin verified Jane20/John21. Prior report retained cleanupComplete true/both restored and was archived evidence-only at21:13:48. Operator ran shared20 21 and confirmed collection. Final server output21:15:30 inspected directly via Remote Desktop: phase complete, passed1/total1, acceptanceScope synthetic_shared_native_lifecycle, lifecycle phase passed/collectionCorrelated true/cleanupComplete true/bothLoadoutsRestored true; restored true/collectorRestored true, automaticRetries0/automaticMutationRetries0/reportDeliveryRetries0. Both native equipment dryrun barriers logged PASS at21:15:28.

Run native-loan:guid-suite:1794633303:1, projectile66/type23 -> pickup58/type8, generation1 each, owner20/bucket0, registered2/readErrors0. Candidate diagnostic accepted one, age11334ms, squared distance2.16693048179149 (~1.47m), all distance/bucket/window checks pass. Recipient again zero_ammo_carrier quantityAtCapture1/exact GUID captured then released, cleanupComplete true; local full AI profile at20037ms. Independent world diagnostic correctly stays unconfirmed/model0 capability, no longer overrides synthetic lifecycle success. canClaim/pickupCredits/originConfirmed remain false, economicWrites0/syntheticNativeOnlytrue. Revised reporting live accepted; two full happy-path synthetic shared cycles now observed across the prior and revised reporting builds. No reconnect/recovery or further deployment needed for this run; visual remains pending and not automatically marked by agent. Remaining work: live competing lifetime/scope validation and canonical paid-native claim integration, still disabled. Modeled race/replay checks are not live race acceptance.


### 2026-11-13 — two-unit competing synthetic probe implemented, live pending

Added console opt-in action WeaponGuidAcceptance shared-competing <thrower> <collector>, reusing existing two-player release barriers, fresh durable/native audits and three-minute sequential-control window. Donor receives exactly two synthetic units in one approved carrier, throws both; firing exception accepts only quantities2/1 in the released competing fixture and stops at0, deadline, death, cancellation or session change. Collector waits for quantity2, preserves both observed AI events, constructs only a zero-ammo carrier around that already-collected pool, captures its exact GUID and retires it; partial collection or existing ambiguous carrier is retained, never overwritten. Ordinary one-unit paths unchanged.

This is a negative attribution test. Probe records distinct owned-projectile and candidate hints, refuses per-item binding on competition, requires two candidate proposals within2m of each other for expectedAmbiguityRefused, and never sets canClaim/pickupCredits/originConfirmed. Synthetic-only batch-absence read requires exactly two registered type23 and two type8 lifetimes, matching thrower identity/bucket, distinct non-reused network generations, all observed projectile/candidate IDs, no pending creation/read errors, registered removal callbacks AND current native absence for all four, plus final scope recheck. It does not authorize world deletion or paid item transfer. Server only signals donor spent-entry retirement after the paired recipient cleanup report and expected refusal plus complete batch absence. Missing evidence stays review_required/no retry. Successful expected refusal publishes synthetic_competing_native_cleanup scope, lifecycle expectedAmbiguityRefused=true/collectionCorrelated=false, both cleanup/restores audited. No paid claim route enabled.

Reviewed available original short_update func377 eight-slot ammo/weapon pickup flow and cached RSG ammo carrier prerequisite before extending the existing multi-unit owner. These references do not provide canonical per-item origin attribution. Added modeled real-owner donor/collector pair tests, partial throw/collection retention, paired firing admission/no third throw, two actual server projectile/Pickup callback pairs, one missing native/callback refusal, near/far candidate separation, native reappearance refusal, two-participant scheduler with negative verdict and missing-batch refusal. All289 isolated Weapons Lua suites/runtime syntax pass. These paired engine transitions are not yet live tested.

Prepared C:/coding/deployments/native-shared-competing-probe-2026-11-13, installer Install-SharedCompetingProbe.ps1. Six existing runtime files only: client/native_guid_acceptance.lua, client/native_throwable_loan_test.lua, client/native_throwable_collector_loan_test.lua; server/services/native_guid_acceptance.lua, native_throwable_transition_binding.lua, native_projectile_collection_probe.lua. Strict hashes/baselines/stopped gate/idempotence/config+manifest preservation/unknown edit refusal verified using staged installed reporting/removal/carrier chain. No manifest/new-file registration changes, refresh, DB/schema/Inventory/UI or full server restart. Preserve prior completed report, quit both clients, stop Shops/Weapons, validate/install batch with Weapons stopped, paid registry1, ensure Weapons/Shops, reconnect same characters; agent verifies IDs/archive before operator starts shared-competing. John stays behind Jane until both land; throw two onto same nearby clear patch about2seconds apart, then collect BOTH and stop. Do not repeat on failure. Live paired negative verdict/cleanup remains pending; prior successful single-unit native cycles remain recorded separately.


### 2026-11-13 — competing two-unit negative fixture LIVE PASS

After six-file competing fixture deployment/reconnect, txAdmin verified Jane22/John23 and retained prior single-unit report complete/cleanup true/both restored. Evidence-only archive completed21:39:01. Operator ran shared-competing22 23 at21:40:21 and reported both collected. Final output21:40:57 inspected directly in Remote Desktop: passed1/total1, phase complete, acceptanceScope synthetic_competing_native_cleanup, lifecycle passed, expectedAmbiguityRefused true, collectionCorrelated false, cleanupComplete true/bothLoadoutsRestored true, restored true/collectorRestored true, automaticRetries0/automaticMutationRetries0/reportDeliveryRetries0. Both native release/rebuild barriers PASS at21:40:55.

Collection retained review_required/competing_native_candidates as the expected negative attribution result, canClaimfalse/pickupCreditsfalse/originConfirmedfalse/economicWrites0. Two candidates net14 and117, squared separation1.03856814745813 (~1.02m), expectedAmbiguityRefused true. syntheticBatchAbsent true, registered4/pendingCreations0/readErrors0 establishes exact two projectile/two pickup removal callbacks and native absence under same synthetic scope. First projectile net96/type23 created32708879 removed32709214; first pickup14/type8 created32709169 removed32725850, owner22/bucket0/generation1. Independent world matcher remains unconfirmed/model0; not promoted into authority.

John recipient passed zero_ammo_carrier, expectedUnits2/quantityAtCapture2, captured true, exact GUID owner released/fundedQuantity2/observedQuantity2, cleanupComplete true. Two local full AI events at26921ms/nativequantity1 and28657ms/nativequantity2, confirming sequential client control and pooled two-unit pickup without recreating ammo. Donor exact spent entry retirement and both saved/native/fresh epoch audits passed. Native paired batch flow and expected refusal now live accepted. This validates one collector with two competing nearby units; simultaneous two-collector race/replay remains modeled, not live-tested. No paid native Inventory claim enabled. No reconnect/recovery/restart or new files required for this completed run. Keep report evidence; visual pending not automatically marked.

### 2026-11-13 — isolated paid handoff and native escrow components

Added unregistered factories native_throwable_collection_handoff.lua (server) and native_throwable_collection_escrow.lua (client). Server reservation spans paid correlation, exact ticketed native cleanup, binding, one atomic claim request and receipt-only uncertain-outcome recovery. Client escrow checks a single provisional collected unit against every baseline ammo pool, captures/releases only an injected exact GUID, verifies absence, and retains ambiguous/death/scope/deadline failures without native replay. No manifest, routes, native adapters, Inventory writes, gate or deployment added. The existing prompt flow is unchanged. These are modeled components rather than a usable paid native pickup path. All291 isolated Lua suites/runtime syntax pass.

Rechecked short_update func377 and cached RSG ammo carrier mapping. The native ammo/weapon pickup and carrier prerequisite remain source-confirmed; canonical per-item origin is still a framework responsibility. Concrete composition must intercept provisional native increases before ordinary ammo observation, preserve death/checkpoint safety, validate real server lifetime plus paid spend, exclude native-only bindings from prompt publication/claims, and reuse the canonical atomic Inventory transaction after native escrow cleanup. See authoritative FEATHER_WEAPONS_MASTER_PLAN_NEXT.md for exact pending gates. No live test or server command is needed yet; prior item108 is unchanged.

### 2026-11-13 — runtime hold and receipt separation

Runtime now has opt-in host-only collection hold/release methods. Normal native adapters provide no enabling ports, so no gameplay bypass is active. A hold blocks ordinary pool sampling and lifecycle/equipment writes while checking death, ped/login/epoch, ammo revision/full saved pools, pending state and deadline every frame; it releases only on the matching exact-GUID cleanup receipt. Ticket replay is refused. Automatic provisional-increase detection and concrete escrow transport remain pending.

Inventory shared-claim primitive gained v4 native presentation/kind with its own native-tomahawk-native-binding-v4 namespace and internal receipt reader, reusing the existing canonical item move/metadata preservation, collector CAS and historical replay checks. Global paid-unit/origin aliases remain shared. No v4 export/commit admission is enabled yet. Prompt record parsing, Weapons prompt claim admission and offer projection refuse native presentation, preventing a native binding from becoming a duplicate green prop/prompt offer. All292 Weapons suites and Inventory Lua/runtime syntax checks pass; native claim SQL/rollback and runtime guards are modeled. No live paid transfer, deployment or database mutation occurred. See authoritative plan for concrete composition/test gates.

### 2026-11-13 — concrete collected-GUID escrow and paid composition

ScopedCollection now reuses the real adapter inventory hierarchy/GUID reader and pool map in an explicit escrow-only mode. Existing collected carrier is captured directly; ammo-only collection may materialize a zero-ammo carrier only after proven inventory/weapon absence and unchanged collected pool. No setters or ammo funding. Only the captured GUID is removed, followed by exact absence and at most one retained pool reduction; foreign pools, ambiguous/missing/wrong-model readbacks and uncertain removal retain review without retry. Rechecked original short_update func377 and cached RSG zero-ammo carrier prerequisite; original code does not supply framework canonical attribution. No live test of this new adapter mode yet.

Unregistered native_throwable_collection_service.lua now composes real paid-spend transition binding, collection observer, escrow handoff and injected canonical storage/claim ports. Native-only v4 binding metadata comes from the server-confirmed spend; stale (>10s) collection cannot start a new handoff. All293 Weapons suites/runtime syntax pass, including real adapter/modeled native failures and actual service+observer+handoff+client escrow composition with modeled SQL ports. Lost replies read receipts; cleanup failures do not transfer; exact row metadata survives the modeled successful transfer. No events, feature activation, server deployment or database mutations added. Concrete trusted transport/interception and Inventory export/released transition composition remain pending as detailed in the authoritative plan.

### 2026-11-14 — concrete Inventory and released transition boundary

Native-only v4 read/bind/atomic claim exports now exist behind default-off feather_native_paid_collection and exact Weapons writer/released-ticket validation. Weapons adds NativePickupTransition/NativePickupTransitionStatus, separate from prompt admission and status history. Config contract defaults0; no production service is constructed/attached. The same lifecycle wear, canonical item move, ledger CAS and fresh native epoch barriers are reused. Native claim requires empty expected collector pool. Unregistered native_throwable_collection_inventory.lua supplies concrete origin-context binding and collector transition/receipt ports. Writer reservation spans cross-resource storage, with unknown outcomes settled by matching receipt reads only. Existing prompt path remains compatible.

All294 Weapons suites/runtime syntax and Inventory Lua checks pass, including actual coordinator and export bodies with modeled SQL/native ports, cross-profile denial, gate revocation/rollback, exact writer/current epoch, stale acknowledgements, fresh restore and lost binding response. No live native-to-paid transfer or deployment yet. Remaining is trusted client arming/transport and provisional-increase interception before ordinary sampling, followed by combined lifecycle tests and installer. See authoritative plan for exact implemented/pending scope; no operator commands required yet.

### 2026-11-14 — armed client/transport composition

Unregistered client collection and server transport factories now connect a trusted30s server arm to same-frame runtime interception, one full local AI observation, actual lifetime/paid-spend correlation, preissued cleanup ticket, exact native escrow, runtime hold release, canonical claim and fresh-epoch completion. Events arriving before/after the ammo increase are covered. Status reads never repeat Begin/claim; duplicate cleanup only resends its receipt. Transport scopes source/identity/bucket/watch/ticket, bounds requests/tickets, strips unsupported receipt fields and requires runtimeReleased. Runtime pre-sample callback exists but production adapters do not supply it yet.

All296 Weapons suites/runtime syntax pass, including integrated actual factories with modeled native/SQL/runtime ports, reentrant fast completion, lost SQL reply, packet replay/source forgery, client death/scope/pool/timeouts and a separate real runtime same-frame hold test. No live network/native paid transfer, permission change or deployment performed. Production bootstrap, registered handlers, projectile evidence capture/challenge association, permission ownership and lifecycle teardown remain before installer/live testing. Authoritative plan records exact pending gates; prior item108 unchanged.

### 2026-11-14 — bounded paid live test READY

New server/client collection hosts and manifest registrations connect the previously isolated factories. Default-off shared overlay preserves paid registry admission and requires explicit replicated native collection opt-in. Console WeaponNativeCollectionTest start throwerId collectorId admits exactly two live distinct same-bucket characters, empty collector pool, and one attempt per resource start. No grants. Normal-runtime event probe caches donor projectile/candidate evidence until confirmed-spend challenge; server records actual entity lifetimes and arms only the other designated player. Native collection is suppressed except while that collector is armed, then suppressed before escrow; explicit prior permission policy is restored on stop. Existing custom prompt client is paused in this experimental mode. Trusted-source handlers, native pre-sample hook, exact escrow and concrete Inventory/released-epoch ports are connected. First live scope is one cross-player paid unit; general own/multi-unit recovery remains deferred.

All298 Weapons suites/runtime syntax and Inventory Lua checks pass, with bounded host/client startup/source/lifetime/one-arm/permission compensation tests added. These still model engine/network/SQL ports. Prepared21-file reviewed installer package C:/coding/deployments/native-paid-collection-test-2026-11-14; TEST-STEPS.md lists exact absolute paths, flags, refresh/stop/ensure order and sequential Jane-to-John test followed by unequip/save/reconnect. Strict payload/baseline hashes, stopped gate, backup, idempotence, config/Inventory manifest preservation, unknown edits and tamper refusal verified. No remote install, live paid success or database mutation yet. No schema/recipe/Menu change. Preserve item108 and all failure evidence; after a failure do not retry/restart before review. Disable native collection only after successful orderly disconnect and resource restart back to existing prompt path; retain paid registry.

2026-11-14 correction: absent Throwables menu was traced to the new manifest dropping the existing paid_throwable_shop_test.lua registration, not a pickup or database failure. Restored that gated $1.50 one-unit price overlay after shop_config, added manifest/order/default-off regression, all299 suites/syntax pass. Verified two-file shop correction installer at C:/coding/deployments/native-collection-shop-fix-2026-11-14. Full future package now22 files. No Inventory/DB/config modification; correction needs client disconnect, Shops/Weapons stop, installer, refresh and ensures. Live menu and paid pickup verification still pending.

2026-11-14 paid run reached ARMED then invalid_read; John walked over the unit and it disappeared, but runtime is frozen with provisional collectionHold/review and saved ledger0/Tomahawk0. No canonical cleanup/claim pass. Traced/reproduced a status poll entering observer.Read while a yielding actor/medical/spend read held its busy latch. Busy now returns pending; transport serializes per ticket before yielding actor reads and retains at most one sanitized observation and cleanup report, rather than losing them or replaying mutations. Coroutine overlap/reverse-order tests and direct busy-read regression pass, all299 suites/syntax. Two-existing-server-file correction prepared at C:/coding/deployments/native-collection-read-fix-2026-11-14, installer checks pass; not deployed. Awaiting John's read-only native inspector and Jane's thrown itemId with clients retained before any cleanup/disconnect/restart decision. Separate item110 was thrown before test start and remains held, as does item108. No refund/replay or arbitrary native deletion.

Evidence received: John has native pooled quantity1, no weapon/carried GUID (absent inventory, noWrites/canClaimfalse); Jane's thrown item is111, saved Tomahawk0/revision15, native owner funded1/observed0. Exact-GUID cleanup is therefore unavailable for this failed provisional pickup. Keep111/110/108 held. Operator handoff now permits Jane's normal save/disconnect and John's full RedM exit to discard native-only residue, followed by stopped-resource two-file read fix and fresh login quantity0 verification. No native ammo setter/removal, economic refund, canonical repair or failed-item replay. Install/relogin/retest remain unobserved; no refresh/Inventory restart or migration needed.

2026-11-14 next run reached paid binding COMMIT11queries/7611ms and claim ABORT24queries/9940ms with confirmed transaction rollback. John inspector now native0/no weapon/GUID and cleanupComplete true; client later result_timeout, not native cleanup failure. Jane unit112/saved revision17/Tomahawk0. Direct read-only HeidiSQL audit through RDP confirmed item112 inventory5/revision2, v4 binding available, John's saved revision0/Tomahawk0; zero rows modified. No native/canonical claim success inferred.

Removed recursive external paid-receipt transaction reads from repeated economic continuation callbacks using a paid-only exact reserved/absent lifetime guard with live actor checks and90s expiry. Strict initial correlation remains; actual Inventory transaction still locks/checks paid receipt, metadata, custody and CAS itself. Native service deduplicates fresh Medical reads within an authority pass; no life caching, permission weakening or timeout increase. All299 Weapons/Inventory checks pass, including zero extra receipt reads over20guards and actual canonical altered-receipt rollback. Three-file transaction correction prepared at C:/coding/deployments/native-collection-transaction-fix-2026-11-14; installer checks pass, not installed, live latency pending. Preserve held112/111/110/108; no repair/refund/replay. No refresh/Inventory restart/database changes required for this patch.

### 2026-11-14 — paid native cross-player recovery LIVE PASS

After guard correction, operator start5 7 produced paid spend COMMIT2219ms/34queries, native binding COMMIT2505ms/11queries and canonical claim COMMIT5203ms/43queries, equipment restore PASS and final/status phase complete for item113. Binding native:b4fa5b36-e014-11f1-9a69-e0d55eaa2deb; ticket collect:b6201c1e-e014-11f1-9a69-e0d55eaa2deb. John SID56edbdfa-e014-11f1-9a69-e0d55eaa2deb changed from epoch ending1794651352:3749360:4 to1794651529:3926494:5. Local full AI pickup at28187ms/native1; owner_changed probe completion is expected during that fresh restore. Client reports COMPLETE and operator confirms the item remains in John's Inventory after reconnecting. This validates the first bounded one-unit empty-collector paid transfer/persistence, not arbitrary pooled metadata attribution or unrestricted native/arrow recovery. ItemRevision2 in the status is the spent binding revision, not a new SQL audit.

Binding latency improved from7611ms to2505ms; claim now finishes under the unchanged timeout. Remaining combined binding/claim delay (~7.7s) still merits profiling. Next scope: timing, deployment consolidation, own/existing-funded/multi-unit design and tests. Held108/110/111/112 remain untouched. Recommended leaving experimental mode through orderly disconnect, Shops/Weapons stop, native collection flag0 and ensures while keeping paid registry1; no new deployment/refresh/DB/Inventory restart required. Teardown not yet observed.

2026-11-14 timing follow-up: deduplicated origin Medical read at native-bind storage boundary; exact reserved writer still checks both actors fresh. Added default-off request-local Inventory timing for inclusive authority/body/wall durations and counts, preserving callback results/errors and isolating logging/clock failures. All299 Weapons and Inventory Lua checks pass. Five-file timing package prepared at C:/coding/deployments/native-collection-timing-2026-11-14, installer safety/idempotence tests pass; not deployed/live measured. Inventory helper/manifest added, requiring refresh and coordinated Shops/Weapons/Inventory stop/ensure. No SQL/schema change, timeout increase, metadata relaxation or engine-facing replacement. Next test retains the same one-unit empty-collector case, compares two timing summaries without summing inclusive spans, verifies persistence and preserves held failures. See authoritative NEXT plan and package TEST-STEPS.md.

### 2026-11-14 — paid item114 refused after seven reads

Authoritative NEXT plan records direct RDP timing/SQL audit: binding1952ms COMMIT, claim1656ms ROLLBACK (no timeout), item114 spent inv5/rev2, binding available, John ledger rev2/Tom0 and native inspector0/no weapon/noGUID. No DB writes/replay. Exact failing early predicate unknown; full-precision stored coordinates do not justify a rounding workaround. Inventory now distinguishes fixed binding/collector predicate reasons without changing authority or exact comparisons; full Inventory tests pass. One-file diagnostic batch native-collection-claim-diagnostics-2026-11-14 prepared, installer verified, not deployed. Preserve114 and other held rows; fresh live diagnostic test pending. See authoritative Weapons NEXT plan and package TEST-STEPS.md for complete handoff.

2026-11-14 paid115 never armed: capture generic object10 at9639ms preceded owned projectile10 at9652ms and landed pickup146 at9970ms, zero errors. Shared hint fingerprint suppressed the owned notification; separate typed deduplication now allows one owned callback after generic/unowned-first while suppressing redundant generic callbacks after owned-first. Snapshot bounded admission retained, no engine/native/server authority change. Regression orders and all299 Weapons suites pass. SQL audit115 spent inv5/rev2/no binding, John rev2/Tom0; preserve115, no replay. One-file native-collection-owned-hint-fix-2026-11-14 prepared/installer tested, not deployed. Earlier114 claim refusal remains unresolved; authoritative NEXT plan records full scope.

2026-11-14 paid116: owned-hint fix reached ARMED; game pickup recorded, observer rejected no_bound_candidate before native cleanup/canonical bind/claim. SQL116 inv5/rev2/no binding, John saved rev2/Tom0; native inspector1/no weapon/noGUID. Preserve116, full client exit then native0 check. Existing observer distance/bucket/age diagnostics were dropped by transport; server-only immutable readback/host printing prepared, all299 suites pass. No radius/authority change, underlying filter unresolved, no new handoff pass. Authoritative NEXT plan and observation-diagnostics batch document handoff.

### 2026-11-14 — quantity Tomahawk recovery prepared; live acceptance pending

Implemented the approved bounded shared quantity allowance instead of exact serialized projectile handoff. Confirmed paid throws create allowances atomically with their debit; native recovery consumes nearby same-bucket allowances once, within 50 metres and 180 seconds, capped at three carried units. No serial, condition or provenance follows new thrown quantities. Historical serialized rows remain untouched. Logical per-type carrier only; physical holder items, knives and arrows are deferred.

Partial/batched recovery preserves genuine ammunition reductions and later native pickups while removing only rejected provisional quantities. Inventory now exposes Ammunition from the footer even for empty inventories, using the existing per-player feather-settings/Core locale contract and English fallback. Live read-only item audit confirmed the existing stack ammunition definition, so no schema/item migration is needed.

Automated validation passed: 303 Weapons Lua suites, Inventory Lua checks, six UI tests, ESLint and production UI build. The 32-file installer passed reviewed-baseline upgrade, backups, exact hashes, idempotence, operator-config preservation and unknown-edit/tamper refusal. SQL race/rollback coverage is modeled, not live concurrency proof.

Prepared package: C:/coding/deployments/throwable-quantities-2026-11-14. TEST-STEPS.md contains exact source/destination paths and ordered installation/test commands. Not deployed; own pickup, shared pickup, unload and reconnect acceptance remain pending. Old exact-item failure causes are not claimed resolved; that experimental path is disabled in quantity mode. Startup-setting persistence is deferred until acceptance.

2026-11-14 startup follow-up: live quantity initialization refused throwable_factory_unconfirmed. Quantity overlay now supplies the explicit prior pickup policy when preserved older operator configs omit it; existing explicit policies remain unchanged. Added missing-config regression; all 303 Weapons Lua suites passed. Updated package installer checks passed. Live retest pending; no balance repair or replay.


2026-11-14 live quantity test: purchase/load succeeded (revision 26, saved/native 1), but paid throw observation rolled back with ER_NO_DEFAULT_FOR_FIELD. Record omitted inventory_grant_receipts.request_fingerprint (NOT NULL). Added deterministic fingerprint and regression enforcing the actual insert column/parameter shape; Inventory Lua suite passes. Recovery is not live accepted. Existing funded unit must be reused; no grant/refund or SQL balance repair.


2026-11-14 funded reconnect follow-up: live saved quantity 1 failed startup at creation_changed_native_pool. Session creation check incorrectly expected physical-unit factory funding for contract 3; quantity carrier deliberately preserves initial pool and controller restores saved counts afterward. Restricted old expectation to non-quantity contracts; added funded reconnect 1 and 3 composition regressions. All 303 Weapons Lua suites pass. Live reconnect/recovery remains pending; saved revision 26 quantity 1 is unchanged; no new purchase or balance mutation required.


2026-11-14 user-confirmed live quantity results: Jane reconnect restored saved/native 1 at revision 26; own throw saved/native 0 revision 27 and native own recovery saved/native 1 revision 28. Cross-player throw saved Jane 0 revision 29; John began 0 revision 2 and native recovery acknowledged saved/native 1 revision 3 with GUID rebound, both active. Own and cross-player quantity recovery passed in this run. Unload/loose-item reconnect persistence, capacity/batches and lifecycle edge acceptance remain pending. No claim of subjective interaction smoothness yet.


2026-11-14 user-confirmed live unload/persistence PASS: John unloaded the cross-player recovered quantity; one loose Tomahawk ammunition unit appeared and remained after reconnect. Quantity status active, revision 4, saved/native 0, guidCaptured false. Read-only inspector confirmed quantity 0 before/after, weapon absent and no GUIDs. Basic quantity loop now manually confirmed: paid load, funded reconnect, own throw/recovery, cross-player recovery, unload and loose inventory persistence. Capacity 3/batched recovery, rejection races, death/admin revive/resource-stop behavior and startup-config persistence remain separate pending gates; no broad production acceptance implied.


2026-11-14 user-confirmed recovered-unit load/reconnect PASS: John loaded the persisted loose Tomahawk ammunition, passed the requested active saved/native quantity 1 checks before and after reconnect, and could draw the Tomahawk. Basic quantity lifecycle acceptance now includes loaded and unloaded reconnect persistence. Capacity/batch, death/revive, resource-stop and startup configuration persistence remain pending.


2026-11-14 live repeated-transfer evidence: following John's recovered-unit loaded reconnect, user performed the requested return transfer; Jane native pickup acknowledged revision 30, active saved/native quantity 1 with GUID captured. Confirms a recovered quantity can be thrown and recovered by the prior owner again. John's post-throw status and Jane draw confirmation were not included in this result; do not infer separate verification of those checks.


2026-11-14 user-confirmed three-unit capacity live PASS: Jane active saved/native 3 revision 31 after loading two additional paid units; one throw saved/native 2 revision 32; native own recovery acknowledged revision 33 and restored saved/native 3, runtime active. This verifies capacity-three single-unit spend/recovery, not simultaneous batched recovery or over-cap rejection. Remaining separate gates include multiple outstanding throws, death/revive, resource-stop and startup configuration persistence.


2026-11-14 user-confirmed multiple-outstanding-throws live PASS: Jane threw all three units and remained active saved/native 0 revision 36. John recovered all three with separate native pickup acknowledgements revisions 7, 8, 9 and ended active saved/native 3 revision 9. Confirms three outstanding paid allowances and sequential cross-player consumption; not a single batched-report proof. Remaining gates include death/revive, resource-stop, over-cap rejection, and persistent startup configuration.


2026-11-14 user-confirmed full-capacity loaded reconnect live PASS: John reconnected with saved/native 3, revision 9, quantityMode true, active carrier/GUID, and could draw the Tomahawk. Main quantity happy-path acceptance now covers capacity-three reconnect in addition to load/unload, own/shared/repeated/sequential outstanding recovery and loose persistence. Death/admin-revive and resource-stop cleanup remain unaccepted lifecycle gates; persistent startup convars and over-cap/batched-report edge verification remain pending. No production-wide lifecycle acceptance claimed.


2026-11-14 death gate FAILED before revive: John remained dead, quantity baseline/native 3 revision 9, but runtime froze dispatch_CheckpointAndSeal_failed; server refused death_wear_snapshot_unavailable. Inventory equipment preflight incorrectly selected legacy physical unit storage whenever Tomahawk limit was 3. Added quantity-mode branch projecting same-transaction ledger/epoch, preserving current-session and legacy-carried/equipped refusal checks. Full Inventory Lua runner passes including new actual-export regression. Frozen session is not retried or marked recovered; fresh login and live death seal/revive retest remain pending. Package now includes native_equipment_commit.lua as a required runtime correction.


2026-11-14 live death/admin-revive acceptance PASS after quantity equipment snapshot fix: death runtime sealed successfully, server acknowledged final ammo seal with changes=0 medicalRevision=5; saved/native Tomahawk quantity remained 3 revision 9. Admin revive automatically cleaned/rebuilt into a new active epoch, closing=false/deathClosing=false/quiescing=false, saved/native 3 revision 9; user confirmed John can draw. No reconnect or balance repair needed for this successful death/revive cycle. Resource-stop cleanup/startup configuration persistence and over-cap/single-batched-report edge gates remain pending.


2026-11-14 user-confirmed orderly shutdown preparation live PASS: WeaponNativePrepareStopAll aggregate ready completed=2 total=2, both final seal/owned cleanup/server release PASS. John runtime closed cleanupComplete=true ownedCopies=0; quantity owner released guidCaptured=false observed=0, retained funded baseline 3 revision 9. Read-only inspector quantity/after 0, no weapon or GUIDs. Actual resource stop/start restoration remains pending; this confirms prepared cleanup, not unprepared crash-stop safety.


2026-11-14 live prepared resource stop/start restoration PASS for John: client stop cleanup reported no tracked copies remain and no new SQL/release acknowledgement; after stop/ensure John runtime active, quantity owner active saved/native 3 revision 9, fresh epoch. No pending/deathClosing/quiescing. Jane post-start quantity status and John draw confirmation were not supplied; remain unconfirmed for this gate. Unprepared crash/stop is not covered by this result. Persistent startup configuration and edge-case acceptance remain pending.


2026-11-14 prepared resource stop/start gate fully user-confirmed: John can draw his restored three Tomahawks; Jane quantity owner active, saved/native 0, guidCaptured=false revision 36 after resource restart. Combined with prior aggregate prepared cleanup and John's restored ledger/native state, orderly connected-player stop/start acceptance passes for both participants. Main quantity-mode manual gates passed: paid load; own/shared/repeated recovery; three outstanding sequential pickups; capacity-three loaded reconnect; unloaded inventory persistence; death/admin revive; prepared stop/start. Remaining limitations: unexpected shutdown, over-cap/expiry/radius rejection and true batched-report live cases not accepted; persistent startup config not yet applied. Historical serialized rows remain untouched.


2026-11-14 startup configuration handoff: user identified active config C:/Servers/redm_feather_dev/server/server.cfg. Prepared deployment throwable-quantities.cfg with tested quantity opt-in and legacy test flags disabled; handoff requires executing it before affected resources start and removing later conflicting assignments. Not applied or restart-verified; no need to restart the live tested session solely for persistence editing.


2026-11-14 startup-settings follow-up: user supplied quantity statuses matching Jane active saved/native 0 revision 36 and John active saved/native 3 revision 9, quantityMode=true for both. Settings/state checks pass. User did not explicitly state whether a full server restart occurred before these readings; startup-config execution and full-restart persistence must not yet be marked confirmed.


2026-11-14 FULL SERVER RESTART persistence user-confirmed PASS: user explicitly confirmed preceding Jane active saved/native 0 revision 36 and John active saved/native 3 revision 9 readings were taken after a full server restart. Quantity mode true for both verifies startup configuration execution and saved-quantity restoration. Main happy-path/lifecycle acceptance gates complete for tested Tomahawk quantity scope. Remaining nonblocking test limitations: unexpected crash/unprepared stop, over-cap/expiry/radius rejection and true batched-report live cases; these are not claimed live accepted. No historical serialized item conversion/refund/deletion performed.


2026-11-15 Jane capacity-load test: Load was incorrectly enabled at carried 3; attempted load refused, quantity status remained active saved/native 3 revision 37. UI displayed ambiguous transfer warning and cleared options; loose-unit preservation was not explicitly confirmed. Implemented policy-derived option capacity, pre-dispatch bridge/action capacity refusal (no mutation), disabled Load with localized short capacity/headroom/stock reasons, removed introductory load/unload help paragraph, preserved refreshed capacity. Existing feather-settings/Core player locale bundle and English fallback reused. Automated validation passes 303 Weapons Lua suites, Inventory Lua runner, six UI tests, ESLint and production build. New regressions cover full-pool refusal before owner dispatch, retained loose stock in modeled bridge, and rendered full-pool disabled Load with usable Unload. Local changes only; deployment and Jane retest pending. Jane remains primary tester.


2026-11-15 user-confirmed connected restart + voluntary selection return PASS: after deploying Inventory hotkey reattachment and non-mutating Weapons checkpoint diagnostics, I opened Inventory while still connected; Jane active saved/native 3 revision 37. Return to Selection completed, selector listed and Jane reactivated into new session/epoch. Native runtime active, saved/native Tomahawks 3 revision 37, revolver regular 100, melee assignments retained, no pending/closing/deathClosing/quiescing. Earlier logout refusal did not recur; original cause remains unproven and diagnostic-only change must not be described as a logout logic fix. Save and Quit has not yet been rechecked. User said all worked, but no explicit full-capacity disabled-button screenshot/result; request targeted UI confirmation before marking capacity presentation live accepted.


2026-11-15 user confirmed capacity presentation checks all passed: introductory load/unload help removed, At capacity (3/3) displayed, Load disabled, Unload enabled, extra loose unit retained. Jane is primary tester; John may disconnect via ordinary Save and Quit (outcome not yet reported). Next planned live gate is expired allowance rejection; explicitly distinguish engine world-object despawn from actual native collection followed by rejection. No expiry result yet.


2026-11-15 live expiry test INCONCLUSIVE: Jane began active saved/native 3 revision 37; one paid throw confirmed active saved/native 2 revision 38. User reports world Tomahawk disappeared before delayed collection, so no expired native pickup occurred. Do not mark allowance expiry rejection accepted; natural despawn only observed. Jane now has two funded loaded units plus prior loose inventory stock. Prefer deterministic rejection diagnostics/model or separately designed controlled test rather than repeated paid throws awaiting engine despawn.


2026-11-15 user-confirmed Jane Save and Quit/rejoin PASS: after requested normal Save and Quit, rejoin native runtime active, saved/native Tomahawk quantity 2 revision 38, revolver regular 100, five melee assignments preserved, no pending/closing/deathClosing/quiescing. Both voluntary selection return and Save and Quit now passed in new sessions; original earlier refusal cause remains undiagnosed, not retrospectively fixed. Prior expiry test remains inconclusive due natural despawn. Jane remains primary tester; do not repeat paid expiry throws without deterministic test design.


2026-11-15 controlled quantity expiry harness IMPLEMENTED / LIVE PENDING: console-only WeaponQuantityExpiryTest arm|status|cancel <current-id>, gated by non-replicated feather_quantity_expiry_test=1. One current funded alive session/epoch/revision, arm deadline 60 seconds; only next single paid reduction can attach reserved expiryTestSeconds=5; annotation consumed before dispatch, no write retry/grant. Inventory accepts short records only under explicit switch + exact trusted reservation, units=1, and exact five-second test tag. Normal records remain 180 seconds even with test switch on; test receipts remain expired when switch is off. Status reports confirmed debit/pickup outcome and elapsed seconds. Actual zero-credit claim path remains unchanged; no direct SQL edit/refund. Automated 303 Weapons suites and Inventory runner pass, including disabled gate, source restriction, one-shot, stale arm, immutable signed test field, early/expired short allowance and normal TTL regressions. Deploy only Weapons server/services/character_ammunition_runtime.lua and Inventory server/internal/throwable_quantity_recovery.lua; manifests unchanged. Use Jane existing two units; test consumes one and expects saved/native one after expired pickup compensation. Remove runtime test switch afterward; do not persist it in server.cfg.


2026-11-15 controlled expiry rejection LIVE PASS: WeaponQuantityExpiryTest armed Jane source 6; next single paid throw debit_confirmed, saved quantity 1 revision 39, five-second allowance. Status before collection showed elapsedSeconds=28. Native collection produced pickup_declined, saved quantity 1 revision 40; Jane F8 quantity owner active, saved/native 1, GUID captured. Confirms expired allowance did not credit quantity and provisional native excess was removed without freezing session. Status after pickup elapsedSeconds=78. User cancelled test and set feather_quantity_expiry_test 0. Normal 180-second live delayed-pickup test remains inconclusive due natural despawn; controlled five-second path specifically accepted. No refund/grant/SQL edit. Remaining live gates include distance/bucket rejection, full native pickup behavior, true batched-report edge cases and unexpected shutdown.


2026-11-15 controlled distance harness IMPLEMENTED / LIVE PENDING: added console-only WeaponQuantityDistanceTest arm|status|cancel <current-id>, gated by feather_quantity_distance_test=1. Shares one-shot reservation with expiry harness (mutually exclusive), bound to session/epoch/revision, 60-second arm, next single paid debit only. Inventory stores that test allowance position +100m on x, leaves visible native object and actual observed location untouched, keeps TTL180; normal receipt positioning unchanged even with switch on. Exact fixed signed annotation required; no arbitrary offsets, multiple-unit tag or combined expiry tag accepted. Real radius query and ordinary zero-credit/native-compensation path remain unchanged. Automated all 303 Weapons suites and full Inventory runner pass incl signed tag immutability, source/gate/one-shot, 100m query exclusion and in-radius positive control. Intended live test spends Jane's one remaining funded unit, expecting active saved/native zero after prompt nearby collection. No grants/refunds/direct SQL edits. Pending deployment of Weapons server/services/character_ammunition_runtime.lua and Inventory server/internal/throwable_quantity_recovery.lua; no manifest/config-schema changes. Disable both test switches after use; distance test receipt naturally expires after180 seconds.


2026-11-15 controlled distance rejection LIVE PASS: Jane began active saved/native 1 revision 40. WeaponQuantityDistanceTest armed source6, single paid debit confirmed with allowance position offset100m and TTL180. Native nearby collection produced pickup_declined; server status elapsed42s kind distance, saved0 revision42. Jane F8 active saved/native0 revision42, retained carrier GUID. Confirms synthetic out-of-radius allowance is excluded by real claim path and provisional native quantity cleared without freezing. Test cancelled; user explicitly disabled feather_quantity_distance_test and feather_quantity_expiry_test. This is controlled predicate/native-compensation evidence, not proof of physically moving a world projectile100m. Outstanding test receipt naturally expires180s after debit; avoid further recovery tests near synthetic location until expiry. Jane has zero loaded; prior loose inventory stock remains separate/unverified this step. Remaining live gates include full native pickup behavior, true batched report, bucket rejection and unexpected shutdown.


2026-11-15 full-native-pickup preparation IMPLEMENTED / LIVE PENDING: found quantity owner always allowed model pickup at cap3. Now suppresses both supported Tomahawk pickup models at native count3 and before restoring funded3; allows again when throw/unload creates room. Also updates at provisional pickup and acknowledged counts, preserves explicit prior permission restoration, reports pickupAllowed in quantity status. Does not grant, clamp or refund economic quantities; unhandled over-cap native burst still fails closed. Two runtime files changed: client/throwable_quantity_owner.lua and client/native_throwable_adapter.lua. All303 Weapons Lua suites pass including concrete initial0/2/3 policy, throw/unload re-enable, pickup-full suppression, cleanup restoration and permission-write-failure retention. Proposed Jane-only test uses four paid loose units: load1/throw, load3, walk over ground at cap without collection, step away/unload1, recover original ground unit within180s to end carried3 + loose1. No live result yet; normal quantity mode and rejection switches unchanged.


2026-11-15 full-capacity native collection LIVE PASS: initial delayed attempt inconclusive because user was away several minutes. Prompt retry: Jane unloaded/reloaded as instructed, created ground unit, loaded3, walked over it; user confirmed unit stayed on ground. Jane active saved/native3 revision49, pickupAllowed=false. Confirms full-holder model suppression prevents collection in this live case. Re-enable after unloading one and recovery of same outstanding unit still pending; must occur within original180s allowance. No unexpected native credit or frozen runtime reported.


2026-11-15 full-capacity native pickup/re-enable gate COMPLETE / LIVE PASS: following blocked collection at active saved/native3 revision49, user performed instructed step-away/unload1/recollect sequence and confirmed all worked. Native recovery acknowledged revision51; Jane active saved/native3, pickupAllowed=false, GUID captured. Confirms unloaded space re-enabled collection and collecting to full suppressed it again without freezing. Intermediate count2/allowed=true confirmed by user's all-worked statement rather than separate pasted status. No automatic grants/refunds/clamps used. Main current state Jane carried3; loose quantity not explicitly re-audited in this result. Remaining distinct gates: true batched report, bucket rejection and unexpected shutdown/crash behavior. Earlier original logout-refusal cause remains unproven despite successful selection/Save and Quit retests.


2026-11-15 controlled bucket isolation harness IMPLEMENTED / LIVE PENDING: console-only WeaponQuantityBucketTest arm|status|cancel <current-id>, explicit feather_quantity_bucket_test=1 switch, same per-session/epoch/revision one-shot reservation and60s deadline as expiry/distance tests. Next single paid debit marks bucketTest; Inventory records allowance bucket actual+1 (max int wraps0) without moving player/world entity, preserves real position/TTL180. Fixed exact marker, units1, no combination with expiry/radius tags; signed pending operation checks prevent annotation changes. Normal records stay unchanged even with switch enabled. Status exposes actualBucket/allowanceBucket. All303 Weapons suites and Inventory runner pass, including gate/source restrictions, shared exclusivity, reservation immutability, no cross-bucket consumption and matching-bucket positive control. Live expected Jane3->2 then declined pickup remains2 active; not yet tested. Two server runtime files only; no manifests/schema changed. Disable all test switches after use; no grants/refunds/direct SQL repair.


2026-11-15 bucket-test interruption: NPC killed Jane while holding, not throwing, Tomahawk. Bucket harness status armed, saved3 revision51; user cancelled arm and set feather_quantity_bucket_test0. No test debit/allowance or bucket result occurred. Jane native runtime sealed (not frozen), deathClosing=true, saved/native Tomahawk3 revision51, revolver regular100, firearm plus five melee assignments present. Confirms death seal with mixed full holder/loadout while pickup suppressed. Revive/rebuild and bucket test remain pending; no balance repair or replay authorized/needed.


2026-11-15 controlled routing-bucket isolation LIVE PASS: after NPC-death recovery/readiness, Jane source6 bucket0 single paid throw recorded test allowance bucket1. debit_confirmed then pickup_declined at elapsed38s, saved2 revision53. Jane F8 quantity owner active saved/native2, pickupAllowed=true, GUID captured. Confirms real claim predicate excludes another recorded bucket and provisional native excess clears without freeze. Test cancelled; bucket/distance/expiry switches explicitly0. This is controlled recorded-bucket isolation, not actual player routing migration acceptance. Remaining separate live cases include true batched-report pickup, unexpected/unprepared shutdown, and actual bucket migration lifecycle. Prior full-holder collection suppression/re-enable accepted. No refunds/grants/direct SQL edits; unused test allowance naturally expires180s after debit.


2026-11-15 natural batched recovery LIVE PASS: Jane stationary grouped throws ended active saved/native0 revision58 with pickupAllowed=true. One collection pass produced exactly two native pickup acknowledgements revisions59 and60, ending active saved/native3 revision60, pickupAllowed=false. Three recovered units across two acknowledged pickup transactions establish at least one multi-unit credited pickup (batch sizes/order not separately logged). This naturally exercises actual native aggregation without sampling-delay harness or synthetic grant. No freeze reported. Remaining primary live risk gate is unexpected/unprepared shutdown/crash behavior; do not treat prepared stop/full restart acceptance as that proof. Current Jane carried3 revision60; loose inventory quantity not re-audited this step.


2026-11-15 unprepared-stop gate PLANNED after code inspection: loaded active owner StopZeroAmmo requires all native and baseline pools zero; with Jane Tomahawk3/revolver100 it intentionally refuses stop_nonzero_or_unreadable_ammo_requires_orderly_release before native removal. Stop closes client transport/suspends runtime and must not invent final SQL/release acknowledgement; server guard uninstall can refuse native_inventory_holds_remain. Existing unit test native_zero_stop_cleanup_spec covers funded/pending/native-only refusal. Next manual scenario is settled loaded resource stop without PrepareStopAll, preserve logs/read-only pickup inspector, then full client exit before restart/rejoin recovery. This is unprepared resource-stop handling, not literal process-crash or in-flight transaction crash proof. No code/deployment changes introduced for this test; pending user execution.


2026-11-15 unprepared loaded Weapons stop observed as designed: Jane pre-stop runtime active no pending/closing, saved/native Tomahawk3 revision60, revolver regular100, firearm/five melee intact. User stopped feather-weapons without preparation. Client REFUSED stop_nonzero_or_unreadable_ammo_requires_orderly_release; server guard teardown REFUSED native_inventory_holds_remain; Shops marked catalog owner stopped. No successful save/release ack claimed. Inspector command pasted without output, so post-stop native quantity/GUID retention not yet independently observed. Need standalone read-only sidecar output if available; then full RedM exit before resource restart and rejoin saved-state verification. Literal process crash/in-flight write durability not proven.


2026-11-15 unprepared resource-stop + fresh-client recovery LIVE PASS (settled balances only): post-stop standalone inspector quantity/after3, weapon present, unique GUID slot0, noWrites=true confirmed native remnants retained after explicit cleanup refusal. User then followed full RedM exit/resource ensure/Shops restart/rejoin path. Jane new session native runtime active, no pending/closing/deathClosing/quiescing, saved/native Tomahawk3 revision60, pickupAllowed=false, revolver regular100, firearm/five melee assignments restored. No balance repair/grant/release ack invented. Draw confirmation not explicitly supplied in pasted result. This validates graceful unprepared resource-stop refusal and recovery by full client exit at acknowledged idle balances, NOT in-place hot-restart cleanup, literal process/server crash or interrupted DB transaction durability. Main planned quantity recovery and rejection gates now passed within stated scopes. Server test switches were previously explicitly disabled; no new switch used here.


2026-11-15 final unprepared-stop recovery draw confirmation PASS: user confirmed Jane can draw the restored Tomahawk. Planned Tomahawk quantity/recovery test gates are complete within recorded scopes: load/unload and capacity UI; own/shared/repeated recovery; capacity suppression/re-enable; natural multi-unit pickup across fewer acknowledgements; controlled expiry/radius/bucket rejection; loaded/unloaded reconnect; selection return/Save and Quit; death/admin revive; prepared resource/full-server restart; settled unprepared resource stop refusal and full-client-exit recovery. Current Jane active carried3 revision60, revolver100. Explicit limitations remain: no literal process crash or in-flight SQL crash durability proof, no live actual routing-bucket migration, and original earlier logout refusal root cause unproven. No automatic historical serialized-item migration or repair. Operator-facing changes and tests remain available for next PR updates; no commit/push/release performed by this documentation step.


2026-11-15 supported-path cleanup local follow-up: Weapons now excludes45 retired exact-item/prompt/handoff/capture/loan script entries from normal startup; offline source/regressions retained and old suite actions refused before dispatch. Inventory runtime/schema unchanged; retained exact-item storage/readers preserve historical data and no longer have a normal Weapons gameplay host. New shared quantity-mode wiring replaces paid-test overlay loading; normal shop_config ammunition offer provides price/pack size. Local304 Weapons suites/7JS, Inventory Lua runner and44 Shops scenarios pass; new composition live acceptance pending. No historical records converted/deleted, no commit/push/PR action performed. Keep this distinction separate from previously accepted runtime behavior.


2026-11-15 deployment handoff revised to PowerShell at user request. Prepared C:/coding/deployments/quantity-runtime-cleanup-2026-11-15/Install-QuantityRuntimeCleanup.ps1 plus reviewed manifest/runtime payload. ValidateOnly is read-only; ResourceStopped acknowledgement required; eligible targets eight Weapons runtime files plus one inline shop_config.lua Tomahawk value (.50/rounds1). Existing config.lua, all other operator shop bytes, BOM/CRLF/comments, historical scripts/reports and data preserved. Unknown baselines/custom price/layout, duplicate entries and payload tampering refused before writes; backups/restore record and idempotence checked. Actual Windows PowerShell5.1 fixtures passed including prior0.23.0 manifest/BOM/CRLF and false/1.00/1.50 offer baselines. Only fixture execution so far; live installer/restart still pending. Copy installer+manifest+runtime to remote deployments folder; no manual config edit, archive/test copy, Inventory/schema change or full-server restart. Refresh required for manifest/new shared script. No commit/push/PR actions performed.


2026-11-15 supported quantity runtime cleanup LIVE PASS: user reports all manual checks passed after PowerShell installer handoff. Supplied Jane active saved/native2 revision61 pickupAllowed=true after throw; native pickup acknowledged revision62 and restored active saved/native3 pickupAllowed=false. Shops read-only release contract9/9 PASS including development/acceptance/admin-test-trust absence and catalog/character-bound commerce readiness. WeaponGuidAcceptance throwable explicitly REFUSED retired exact-item experiment without loan. User all-manual-checks confirmation covers draw, startup and $1.50 single-unit catalog checks; no separate installer stdout or native full status pasted, so do not infer raw installer changed-file counts. New slimmer manifest/composition now live accepted for focused startup/catalog/own recovery. Retired sources/archives/data preserved, normal price wired through shop_config, no Inventory/schema migration. Local304 Lua/7JS + Inventory runner/44 Shops scenarios passed before deployment. No agent commit/push/PR updates performed; user handles them. Current Jane loaded3 revision62. Cleanup step1 complete within tested scope; separate single-unit purchase limit improvement remains next design task.

