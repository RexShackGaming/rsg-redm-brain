# Controlled native enrollment — staged implementation

2026-11-03: character allowlists and the two-member access limit are removed.
Every authoritative current character can access Weapons. This changes access,
not economic data enrollment or development/runtime requirements. See the
[current all-player access guide](native-rollout-admission.md). The dated
instructions below are historical acceptance evidence, not current access setup.

Current checkpoint: authoritative framework Weapons CHECKPOINT_2026-10-17.md.
InvJohnNativeFixture has been retired from runtime after acceptance; its pure
body is test-only. Retain existing receipt/data and do not repeat old grant
instructions below. Controlled empty enrollment remains explicit/max-two scoped.
Issuance cross-mode receipt fencing is a review finding pending resolution;
native-only replay acceptance does not establish legacy/native key continuity.

2026-10-17 LIVE same-model pair success-path cleanup COMPLETE: after requested
offhand unequip, John source3/sessionb133ab17-ca95-11f1-9ad4-e0d55eaa2deb/
new epoch10178568:5 ACTIVE idle1copy/ledger3/all pools0. Only Cattleman158rev1
reported, soot0.00499999988824/degradation0.00333333341404/other wear0,
trackedExists true/entity2897666/point2 own diagnostic baseline match; point3
absent, points9/10 absent. No refill or residual equipped sibling observed.
Entity replacement is fresh reconstruction under a new epoch, not same-epoch
GUID adoption. No post-shot/pre-unequip wear or removed155 durable read supplied,
so don't independently attribute the firing hand or prove removed-item wear from
this snapshot. Accepts distinct pair baseline, no-fire draw/holster identity,
single shared-pool decrement, and offhand cleanup/zero-balance reconstruction.
Broken same-model primary promotion/customized pair and crash behavior remain
separate. No repeated firing/grants/restart required for this gate.

2026-10-17 LIVE same-model pair single-shot shared-pool decrement accepted:
after requested single shot/holster John same epoch9671643:3 ACTIVE idle2copies,
regular revolver1 ->0/all pools0/ledger2 ->3. Jane ACTIVE idle2copies/
ledger35/repeater1/all other pools0/session4ab3d92b-ca81-11f1-9ad4-e0d55eaa2deb,
epoch9357941:1. Last supplied Jane epoch8281267:1 preceded requested orderly
restart; no fresh pre-shot9357941:1 output was supplied, so do not claim exact
Jane epoch-before/after invariance. Expected observer ammo/copy counts preserved.
No shooter-hand or per-item post-shot wear readback supplied; don't attribute
wear to a particular copy. Pair cleanup/zero-balance reconstruction pending.

2026-10-17 LIVE same-model pair post-draw/holster readbacks accepted following
requested no-fire draw/holster sequence. Same John epoch9671643:3:158rev0
entity1352962/point2/pristine and155rev3/entity1353218/point3/prior soot
0.00499999988824/degradation0.00333333341404/other wear0. Both tracked entities
exist, own diagnostic GUID baselines match, sibling baselines do not; no native/
SQL diagnostic writes. No identity or maintenance swap observed at post-holster
boundary. No in-hand snapshot supplied; shared-pool firing/cleanup still pending.

2026-10-17 LIVE same-model Cattleman pair baseline accepted for John3:
sessionb133ab17-ca95-11f1-9ad4-e0d55eaa2deb/epoch9671643:3 ACTIVE idle2copies,
ledger2/revolver1/all other pools0. Item158rev0 pristine tracked entity1352962
exists at point2; item155rev3 prior soot0.00499999988824/degradation
0.00333333341404/other wear0 tracked entity1353218 exists at point3.
Each point matches its own diagnostic GUID baseline, not the sibling's; both
guidOwnershipCaptured false/guidDiagnosticOnly true. Same-model expectedModel
true on both points is not ownership evidence by itself. Entity readout
noNativeWrites/noSQLWrites true. Distinct tracked objects/separate wear accepted;
draw/holster, shared-pool firing and cleanup/promotion remain separate gates.

2026-10-17 LIVE equipped-give notification retest accepted by human report:
"refused and a message shown" following deployment instructions for the two
Inventory server files. Confirms refusal remains enforced and player-visible
feedback now appears. Exact notification wording and fresh runtime/provenance
snapshots were not supplied for this retest; do not claim independent content
or post-attempt state measurements beyond prior guard-isolation evidence.
Equipped-transfer visibility gate complete; no repeat give attempt needed.

2026-10-17 LIVE equipped donor give attempt reportedly refused silently.
Jane status remains exact epoch3599671:9/two copies/ledger35/repeater1;
John exact epoch3618303:10/one copy/ledger2/revolver1; both ACTIVE idle and
other pools0. Accepts observed blocked action/state isolation, not an identified
live guard-code trace. Root cause found in code: greedy give skips guarded rows,
returns non-error moved0/skipped1, while callback only notifies error responses.
FIX IMPLEMENTED/automatically tested, live notification acceptance PENDING:
Inventory server/controllers/inventory.lua preserves first skipped guard reason
and moved/skipped summary; server/services/callbacks.lua uses existing RightNotify
for skipped gives, including partial commits. No economic/guard policy change,
no UI bundle/CSS/config/manifest delta. Full Inventory Lua/runtime syntax and two
Node tests PASS; actual callback regression verifies recipient-capacity and
zero-move guard notification, retained reason/no extra committed move events.
Deploy only these two existing Inventory runtime files, after aggregate Weapons
PrepareStopAll PASS/ready and stopping Weapons; restart Inventory/dependents,
then ensure Weapons. No refresh needed. Live retest only equipped155 give
refusal visibility; do not bypass by unequipping or repeat grants/transfers.

2026-10-17 LIVE round-trip transfer cleanup COMPLETE by maintenance readbacks:
Jane epoch3599671:9 reports112rev2 (dirt1/degradation0.00871666707098/other
wear0) and134rev8(all wear0); John epoch3618303:10 reports155rev3
(soot0.00499999988824/degradation0.00333333341404/other wear0).
Both original equipment sets are materialized with preserved wear. Item155
revision advanced across the two observed ownership moves (donor1,recipient2,
returned3); exact write causation not isolated by maintenance output alone.
Previously supplied transfer statuses confirmed separate unchanged carried
balances. No fresh post-restoration ammo status or equipment PASS logs supplied,
so do not claim separate remeasurement of those at cleanup. Cross-character
give/return, donor request refusal, recipient materialization, provenance and
wear-restoration gate accepted in this observed scope; no repetition needed.

2026-10-17 LIVE unequipped return transfer/provenance accepted: item155 current
true/destroyed false/serialFW-ALPHA-MULTI-JOHN-V1 has two transfer events:
event12 inventory_move/give John inventory5 ->Jane inventory2 at17:09:02,
event13 inventory_move/give Jane inventory2 ->John inventory5 at17:14:39.
Fresh Jane ACTIVE idle0copies/epoch3409457:7/ledger35/repeater1/revolver0;
John ACTIVE idle0copies/same epoch2939348:3/ledger2/revolver1; all other pools0.
Together with preceding recipient155 wear readback and donor equip refusal,
accepts observed cross-character round trip with provenance and no carried-ammo
movement. Final Jane112/134 and John155 equipped restoration remains pending.
No extra grants, firing or fixture replay needed.

2026-10-17 LIVE recipient maintenance materialization observed after requested
Jane sidearm isolation/equip155: single reported Cattleman155rev2 at Jane
session4ab3d92b-ca81-11f1-9ad4-e0d55eaa2deb/epoch3316415:6. Wear preserves
degradation0.00333333341404/soot0.00499999988824/damage0/dirt0/permanent0.
Previous donor item revision1; reason/timing of advancement to2 not independently
isolated. Individual equipment PASS logs and recipient ammo status not supplied
at this step; do not infer them from maintenance alone. Return transfer,
provenance readback and final original-loadout restoration remain pending.

2026-10-17 LIVE post-give donor equip request blocked:
WeaponNativeEquipmentChange2 equip weapon155 REFUSED equipment_snapshot_unavailable.
No STARTED or commit reported. Accepts observed unauthorized donor request refusal;
generic snapshot code does not independently identify the precise ownership
validation branch or establish a forged network-intent attack test. Recipient
materialization and return/provenance gate remain pending.

2026-10-17 LIVE unequipped cross-character give observed: John after unequip
ACTIVE idle0copies/ledger2/revolver1/epoch2939348:3. Ownership transition log
item155 serialFW-ALPHA-MULTI-JOHN-V1/revolver_cattleman from inventory5/
John4560a489-ca6c-11f1-9ad4-e0d55eaa2deb to inventory2/
Jane6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb type transfer/reason give.
Both supplied post-transfer statuses retain exact prior epochs and balances:
Jane2791602:1/two copies/ledger35/repeater1/revolver0; John2939348:3/
zero copies/ledger2/revolver1; all other pools0 and idle flags. Accepts
observed give without native copy creation or carried-ammo movement.
Donor equip ownership veto, recipient materialization/wear, return transfer
and provenance readback remain pending; SQL receipt not independently supplied.

2026-10-17 LIVE aggregate drain plus resource restart gate COMPLETE in observed
scope. Following aggregate2/2 PASS and ready status, supplied post-stop/ensure
snapshots restore Jane ACTIVE idle two copies, ledger35/repeater1/all other
pools0/session4ab3d92b-ca81-11f1-9ad4-e0d55eaa2deb/new epoch2791602:1;
112rev2 dirt1/degradation0.00871666707098/other wear0 and134rev8 all wear0.
John ACTIVE idle one copy, ledger2/regular revolver1/all other pools0/
session890a50aa-ca81-11f1-9ad4-e0d55eaa2deb/new epoch2791796:2;
155rev1 soot0.00499999988824/degradation0.00333333341404/other wear0.
Both clear pending/closing/deathClosing/runtimeBusy/quiescing flags.
Accepts operator-invoked aggregate connected-owner drain and funded restoration.
No further success-path repetition required. Live refusal/disconnect/timeout
paths, automatic shutdown interception and abrupt crash remain separate.

2026-10-17 LIVE aggregate scoped connected-owner drain accepted through ready:
WeaponNativePrepareStopAll STARTED/admission latched, two individual final
seal/owned cleanup/server release PASS logs, then aggregate PASS completed2/
total2. WeaponNativeShutdownStatus independently reports phase ready,
completed2,total2. Post-drain stop/ensure and funded maintenance restoration
remain pending. This is operator-invoked aggregate drain, not automatic txAdmin
interception, crash handling or live failure-path acceptance.

2026-10-17 scoped connected-owner aggregate shutdown preparation IMPLEMENTED,
automatically tested, NOT live accepted. Existing Weapons server/services/
native_equipment_transition.lua adds console-only WeaponNativePrepareStopAll
and WeaponNativeShutdownStatus. One-way resource-lifetime admission latch uses
the deployed dispatcher Start/IsStopping guard and denies non-shutdown transition
intents. Exact bounded connected roster is snapshotted/preflighted; existing
per-owner final seal/wear/cleanup transitions run sequentially. Aggregate ready
requires confirmed parked owners and unchanged identities; ready continues to
be monitored. Missing/busy/frozen owner, unresolved Core identity, roster drift,
disconnect, refusal/exception or 90-second deadline fails closed without retry,
reset, economic replay or resource stop. Existing unconnected unresolved holds
are not claimed drained; arbitrary stop/crash/txAdmin interception remains absent.
132 Lua specs/runtime syntax and 7 Node checks PASS; native/SQL boundaries mocked.
Live gate and failure caveats: Weapons docs/native-shutdown-drain-alpha.md.
Deploy ONLY existing Weapons server/services/native_equipment_transition.lua
after old per-player PrepareStop PASS for John2/Jane1 and stop; ensure afterward.
No refresh, config, Inventory or Admin runtime delta. Test aggregate drain once
both restore, require aggregate completed2/total2 plus ready status before stop.
Preserve funded balances/maintenance; do not repeat grants, firing or death gates.

2026-10-17 LIVE two-player death/doctor recovery isolation gate COMPLETE in
observed scope: Jane's fresh post-John-recovery status preserves exact session
4ab3d92b-ca81-11f1-9ad4-e0d55eaa2deb/epoch162143:1/ped97538,
ledger35/repeater1/all other pools0/two copies/ACTIVE idle flags. Combined with
John's scoped death seal and doctor recovery snapshots below, accepts one
owner's death/recovery without observer session, epoch, ammo or copy-count
change. No further death/respawn/observer repetition needed for this gate.
Automatic all-owner drain, overlapping SQL contention and abrupt crash remain
separate; no new runtime deployment accompanies this acceptance record.

2026-10-17 LIVE John doctor recovery accepted in owner scope: MedicalRespawn
authorized/alive revision2; same session890a50aa-ca81-11f1-9ad4-e0d55eaa2deb,
new epoch705385:3/ped701442 ACTIVE idle one copy, ledger2/regular revolver1/
all other pools0. Maintenance155rev1 preserves soot0.00499999988824,
degradation0.00333333341404/other wear0. No pending/closing/deathClosing/
quiescing/runtimeBusy. Jane's observer was unchanged at death but fresh
post-doctor observer status is not yet supplied, so full recovery observer
isolation is still pending; no repeat death or owner recovery needed.

2026-10-17 LIVE John death sealed balance confirmed by scoped
WeaponNativeRecoveryStatus2: character4560a489-ca6c-11f1-9ad4-e0d55eaa2deb,
session890a50aa-ca81-11f1-9ad4-e0d55eaa2deb/epoch266157:2,
currentAcknowledged phase sealed/revision2/regular revolver1/all other pools0;
ledgerRevision2/item155rev1/economicReplay false/nativeAdoption false.
Together with preceding Jane unchanged observer, accepts death-seal balance
isolation. Doctor recovery and post-recovery native maintenance still pending.

2026-10-17 LIVE staged John death observer isolation: following requested John2
admin kill, supplied server log reports death final wear persisted changes0,
medicalRevision1, final ammo seal acknowledged. Log itself has no source identity.
Jane observer remains ACTIVE idle two copies with exact prior session4ab3d92b-
ca81-11f1-9ad4-e0d55eaa2deb/epoch162143:1, ledger35/repeater1/all other pools0.
John's scoped sealed ledger/pool readback and subsequent doctor recovery remain
pending; do not infer his round balance solely from the unscoped seal log.

2026-10-17 LIVE full server restart after individual preparation accepted.
Operator explicitly reports both clients remained connected during server
restart and PrepareStop was performed for each beforehand (fresh preparation
logs not supplied for this run). Post-restart Jane source1/new session
4ab3d92b-ca81-11f1-9ad4-e0d55eaa2deb/epoch162143:1/ped97538 ACTIVE idle two
copies, ledger35/repeater1/all other pools0; 112rev2 dirt1/
degradation0.00871666707098/other wear0 and134rev8 all wear0 preserved.
John source2/new session890a50aa-ca81-11f1-9ad4-e0d55eaa2deb/epoch266157:2/
ped701442 ACTIVE idle one copy, ledger2/regular revolver1/all other pools0;
155rev1 soot0.00499999988824/degradation0.00333333341404/other wear0 preserved.
Both snapshots have pending/closing/deathClosing/quiescing/runtimeBusy false.
Accepts prepared full-process restart reconstruction with both clients connected,
not an unprepared resource stop, automatic global drain, abrupt process crash,
or in-flight SQL interruption. Current targeted IDs are Jane1 and John2;
prior source4/8 must not be reused.

2026-10-17 LIVE two-owner prepared resource restart restoration accepted:
after individual PrepareStop PASS for John8/Jane4 and requested Weapons stop/
ensure, both supplied ACTIVE idle snapshots. Jane retains session609d32df-
ca6c-11f1-9ad4-e0d55eaa2deb, new epoch87981985:1, ledger35/repeater1/all other
pools0/two copies; 112rev2 retains dirt1/degradation0.00871666707098 and other
wear0; 134rev8 all wear0. John retains session9bdcc7d3-ca7f-11f1-9ad4-
e0d55eaa2deb, new epoch87982114:2, ledger2/regular revolver1/all other pools0/
one copy; Cattleman155 now rev1 with soot0.00499999988824,
degradation0.00333333341404 and other wear0. Wear revision persistence timing
is not isolated by these outputs. No pending/closing/deathClosing/quiescing
or runtimeBusy in either final snapshot. Accepts individually prepared two-owner
restart with funded snapshot and maintenance restoration; NOT automatic global
drain, process crash, overlapping SQL contention or unrestricted rollout.

2026-10-17 LIVE sequential two-owner orderly release accepted: confirmed current
John source8 then Jane source4 each returned WeaponNativePrepareStop PASS final
seal/owned cleanup/server release, ready to stop, no equipment/ammo economic
writes. Both connected owners were individually drained. Resource restart and
post-restart snapshots remain pending. This is not an automatic global drain
or overlapping shutdown stress test.

2026-10-17 LIVE funded John normal quit/rejoin isolation accepted: new session
9bdcc7d3-ca7f-11f1-9ad4-e0d55eaa2deb/epoch87687765:5/ped78594 restores ACTIVE
idle one copy, ledger2/regular revolver1/all other pools0. Jane's supplied
observer status retains exact session609d32df-ca6c-11f1-9ad4-e0d55eaa2deb,
epoch86881660:1, ledger35/repeater1/all other pools0/two copies and idle flags.
This accepts funded orderly reconnect snapshot preservation and observer
isolation; it does not establish process-crash recovery, overlapping SQL
transactions or all-player shutdown drain. John's new source ID not supplied;
do not reuse source6 for targeted commands without fresh confirmation.

2026-10-17 LIVE funded one-shot two-character isolation accepted in observed
scope. John status after requested single shot: regular revolver2 ->1,
ledger1 ->2, ACTIVE idle one copy, same sessiona5e938d4-ca75-11f1-9ad4-e0d55eaa2deb,
new epoch87227766:4 (previous86920912:3); all other pools0. Cause of epoch
transition not established by these status outputs. Jane supplied before/after
statuses exactly preserve session609d32df-ca6c-11f1-9ad4-e0d55eaa2deb,
epoch86881660:1, ledger35/repeater1/all other pools0, ACTIVE idle two copies.
No pending/closing/deathClosing in either observed final state. This accepts
consumption isolation with two armed owners, not simultaneous SQL contention,
funded reconnect persistence, global drain or crash recovery. Next staged gate:
John orderly logout/rejoin retaining one round while Jane remains connected.

2026-10-17 LIVE John equip/funding readback accepted: independent John client
UUID4560a489-ca6c-11f1-9ad4-e0d55eaa2deb/sessiona5e938d4-ca75-11f1-9ad4-e0d55eaa2deb
ACTIVE idle one copy, Cattleman155rev0 with all maintenance0 at epoch86920912:3.
Subsequent status at that same epoch shows ledger revision0 ->1 and regular
revolver pool0 ->2, all other pools0, pending/closing/deathClosing false.
This confirms the funded runtime snapshot, not an independently supplied SQL
payment receipt. One-shot consumption and Jane before/after isolation remain
pending; no new grant or timer-sensitive action required.

2026-10-17 LIVE John bounded grant accepted: InvJohnNativeFixture source6,
exact John UUID4560a489-ca6c-11f1-9ad4-e0d55eaa2deb returned PASS/replayed=false
after SQL transaction :16913 COMMIT (34 queries). Created Cattleman item155rev0,
serial FW-ALPHA-MULTI-JOHN-V1 and two loose regular revolver rounds. Report
explicitly excludes equipment/carried-ammo/native writes. Human cleared
feather_john_native_fixture to0. This supersedes deployment/live-grant pending
notes below; normal equip, material-funded carried ammo and two armed-owner
isolation are still pending. No receipt replay or additional grant requested.

2026-10-17 John grant preparation: human confirmed current source6 and authorized
one disposable Cattleman plus two loose regular revolver rounds; Admin deferred.
Implemented console-only InvJohnNativeFixture in Inventory's existing
server/services/native_repair_fixture.lua. Exact John UUID, DevMode, enabled
character ammunition, ready Inventory, stopped Weapons/proof, absent retained
Weapons guard and current Core session are required. A single transaction locks
the empty inventory/equipment and zero revision0 ledger, validates native firearm
metadata, creates serial FW-ALPHA-MULTI-JOHN-V1 and two loose ammo items, and
completes a fixed grant receipt. Completed receipt replay cannot replenish items
or spent/transferred rounds. No carried ledger, equipment or native writes.
Automated Inventory Lua/runtime syntax and two Node tests pass, including grant,
receipt replay, rollback, authority loss and nonempty/funded snapshot refusals.
Deployment/live grant PENDING. Copy only the existing Inventory runtime file;
orderly PrepareStop both active sources4/6 before stopping Weapons and restarting
Inventory/dependents. No refresh or config replacement required. Opt in with
set feather_john_native_fixture 1, invoke InvJohnNativeFixture 6 with John's UUID,
then clear the opt-in. Keep CharacterAmmunitionEnabled true. This is a bounded
alpha fixture, not production issuance or an Admin permission change. Armed/funded
multiplayer acceptance remains pending. This supersedes the earlier source-ID
confirmation/authorization pending notes below.

2026-10-17 LIVE controlled two-character baseline/sequential isolation accepted
in observed scope. Jane source4/CID6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb
session609d32df-ca6c-11f1-9ad4-e0d55eaa2deb ACTIVE2copies/ledger35/repeater1,
112rev2 priorwear and134rev8 pristine. John source6 initially needed explicit
empty enrollment: COMMITTEDledger0/items0/itemRevisions[]/pools[]; subsequent
server+client ACTIVE0copies/complete27pools0, session35b59121-ca6f-11f1-9ad4-
e0d55eaa2deb/epoch82809286:2. Duplicate Jane clipboard blocks were resolved by
fresh John client output; no cross-character identity failure established.

Jane unequip: native only112rev2 unchanged at epoch83220691:3 while John's epoch,
ledger0/allammo0/copies0/idle state unchanged; unequip command PASS not supplied.
Jane restore offhand134 explicit conditional-equipment PASS/noammo economicwrites.
John normal logout/re-entry then returned ACTIVE0copies/ledger0/27pools0 under
new sessiona5e938d4-ca75-11f1-9ad4-e0d55eaa2deb/epoch83409470:5/ped2485762.
Jane afterward ACTIVEidle2copies/same originalsession/ledger35/repeater1/
epoch83338276:4. Exact Jane pre-John-logout epoch was not separately captured
after offhand restore, so no exact epoch-before/after claim. John current source
after logout not supplied; must confirm before targeted console actions.

This accepts independent activation and sequential equipment/logout isolation
with John empty; NOT simultaneous SQL contention, two armed/funded owners,
foreign-intent attack, process crash or global shutdown drain. No further
repetition of these accepted gates needed. Human operates desks independently;
use staged controls/no narrow timing windows. No new runtime delta/deployment.
Next meaningful gate needs an explicitly authorized John firearm and/or funding,
or an armed-owner lifecycle test preserving an empty observer; no grant inferred.

2026-10-17: shared enrollment policy wired through startup, authoritative
activation, equipment/repair/maintenance/death, scoped attachment reconstruction
and own-current evidence checks. Feature opt-ins, DevMode, Core sessions, epoch,
item ownership, material payment and evidence permissions remain independent.
No live second-character enrollment or multiplayer acceptance yet.

WeaponNativeEnrollment.Validate/Allows lives in existing shared/constants.lua.
It accepts the existing explicit NativeAlphaCharacterId and an optional exact
UUID-keyed NativeAlphaAdditionalCharacters map with literal true values. The
combined set is capped at two characters; wildcard, array, false-valued, malformed
or over-limit configuration denies the whole policy. The existing singleton
string contract is retained. No automatic enrollment, grants, database writes,
new network route or gameplay privilege is provided by this helper.

130 Lua specs/runtime syntax and 7 Node tests pass. New policy tests cover both
members, outsiders, malformed/over-limit failure, singleton compatibility and
independent returned snapshots. Production activation binding and client startup
tests cover the second member, outsiders, malformed maps, forged readiness and
duplicate-owner refusal. Real coordinator interleaving retains isolation under
confirmed/refused/uncertain outcomes and source reuse, with mocked SQL/native
boundaries. This is not live multiplayer acceptance. Inventory is unchanged.

## Server deployment preparation

2026-10-17 live John diagnosis: UUID4560a489-ca6c-11f1-9ad4-e0d55eaa2deb/source6
has an inventory container, no items, no equipment and no ammunition ledger by
human SELECTs. Allowlisting alone does not migrate data; runtime readers must not
implicitly create ledgers. Inventory now has explicit InvNativeEmptyAmmoEnroll
console command in existing server/services/character_ammunition_enrollment.lua.
It requires DevMode, exact feather_native_empty_enrollment_character UUID opt-in,
Weapons/proof stopped and no retained Weapons guard; Core target/session current
before and after canonical transaction. Empty inventory/equipment locked and
rechecked, canonical Apply creates zero ledger+receipt; existing ledger/receipt,
nonempty data or lost authority refuses/rolls back. Full InventoryLua/syntax+2UI
PASS, mocked SQL tests cover body/rollback and command early denial; live pending.
Deploy that existing Inventory file, no refresh. Prepare-stop Jane CURRENT4 and
waitPASS before stopping Weapons/restarting Inventory/dependents. John has no
native owner to seal. With both Core sessions still current and Weapons stopped,
set exact optin, invoke with CURRENTJohn source+UUID, inspect COMMITTED, clear
optin, then start Weapons. No grants, item migration, equip or native writes.
Do not disable/re-enable customized Inventory ammo config for this command.

Wait for the human to identify and authorize a second tester character UUID and
confirm a second player can connect concurrently. Do not copy test UUIDs from Lua
fixtures into the live config. Existing NativeAlphaCharacterId remains Jane.
Merge only this optional setting in feather-weapons/config.lua:

```lua
NativeAlphaAdditionalCharacters = {
    -- ['SECOND_AUTHORIZED_CHARACTER_UUID'] = true,
},
```

Do not replace customized config; leave the map empty until the tester is chosen.
Restart for membership changes; do not revoke a live owner by changing config
mid-transaction. Prepare-stop every active enrolled source and wait PASS, stop
Weapons, copy the paired shared/client/server files, then start Weapons. No new
runtime script/manifest, refresh, migration, UI build or Inventory update.
Do not enable hybrid legacy fallback or global native activation for outsiders.

Exact Weapons runtime files (copy together):

```text
shared/constants.lua
shared/definitions/attachments.lua
shared/character_ammunition_materialization.lua
client/character_ammunition_creation_native.lua
client/character_ammunition_native_owner.lua
client/character_ammunition_startup.lua
server/main.lua
server/services/character_ammunition_dispatch.lua
server/services/character_ammunition_runtime.lua
server/services/native_equipment_transition.lua
server/services/evidence.lua
```

Next live gate starts with read-only status from both current sources; no new
ammo/item grants or evidence permissions are implied. Start by confirming distinct
characters/sessions/epochs/equipment before any interleaved mutation is requested.
