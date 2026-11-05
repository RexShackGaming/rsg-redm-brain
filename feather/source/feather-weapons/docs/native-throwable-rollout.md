# Native throwable port — current scope

2026-10-19 LIVE read-only durable SQL audit PASS from supplied result images:
John ledger16/raw Tomahawk1/repeater0; Jane ledger35/raw Tomahawk NULL/repeater1.
The ledger ReadSnapshot uses pools(document,limits), which fills absent admitted
keys with0, so Jane's absent raw Tomahawk key agrees with acknowledged runtime0;
no repair/migration/write is needed. Receipt namespace native-tomahawk-native-spend-v1
contains spend:165:13 claimed/item165/revision14/Tomahawk1 and spend:165:15
claimed/item165/revision16/Tomahawk1, matching the accepted two session-bound
pickups. This verifies the displayed durable balances and receipt fields, not a
full database integrity scan, projectile provenance or process-crash recovery.
Audit remains read-only; raw JSON absence is explicitly retained in its notes.

2026-10-19 READ-ONLY durable audit prepared at feather-inventory/docs/
native-tomahawk-durable-audit.sql, checked against current ledger/receipt reader
and writer fields. Expected live baseline John16/Tomahawk1, Jane35/Tomahawk0;
accepted pickup spend receipts165:13 and165:15 claimed at14 and16. SQL has not
been executed against the user's database; results pending. Separate SELECTs
require idle players and are not a single atomic snapshot. No runtime deployment,
restart, balance/receipt repair or new funding requested. Original recovery used
session-scoped committed-spend allowances; this audit verifies the new durable
counterpart without restoring the archived runtime.

2026-10-19 LIVE observer isolation for funded client disconnect/reconnect PASS.
Jane's supplied status remains active in the same epoch7828bdf9-cc10-11f1-9ad4-
e0d55eaa2deb:1792461742:11611048:1, ledger35/repeater1/Tomahawk0/all other pools0,
2 firearm copies/no melee/no pending/closing/death/busy/quiesce.112rev2 retains
dirt1/degradation.00871666707098/other wear0;134rev8 remains pristine. This closes
the settled funded John disconnect/reconnect gate including unchanged observer.
No deployment or new grants required. Server/process crash and in-flight uncertain
SQL recovery remain separate, unaccepted live boundaries.

2026-10-19 LIVE funded client-disconnect recovery PASS. John rejoined as source4,
session3032bd4c-cc39-11f1-9ad4-e0d55eaa2deb, epoch ending1792468157:18026387:5.
RecoveryStatus records prior source3/sessionccd30807-cc2b-11f1-9ad4-e0d55eaa2deb
retired_unreleased/player_dropped from active revision16, nativeCleanupConfirmed=false,
finalObservationInvented=false, providerOutcome=not_requested and
unresolvedPersistence=false. New active acknowledged ledger16/Tomahawk1, other
pools0, economicReplay=false/nativeAdoption=false. Carrier165rev0 funded1/observed1/
GUID captured/pickup gate0; five melee160-164rev0 and firearms155rev3/158rev5
preserved. User confirms Tomahawk and melee selectable/drawable. Missing old-client
native cleanup acknowledgement is explicitly recorded, not invented. This accepts
settled funded disconnect/reconnect using last durable snapshot, NOT in-flight
SQL ambiguity, server/process crash, or old-client cleanup proof. Fresh Jane
observer evidence for this disconnect has not been supplied. No grant/funding or
runtime change required.

2026-10-19 AUTOMATED reconnect after uncertain committed pickup PASS: actual
Weapons service fixture retires the disconnected frozen owner, opens a different
source/session/epoch from the mocked canonical Inventory ledger7/Tomahawk1 and
confirms restore. Old-session pickup and fresh-session reuse of the previous spend
allowance are refused; claim count remains2 and durable revision/balance unchanged.
This tests server retirement/reopen composition, NOT native client cleanup, actual
SQL crash recovery or permission to forcibly thaw a connected owner. No runtime
or deployment changes. The bounded automated pickup interruption/replay/reconnect
checks are complete; further live failure injection needs a separately scoped plan.

2026-10-19 AUTOMATED stale receipt-result/runtime reservation boundary PASS:
actual runtime fixture receives historical successful pickup revision12 while a
new revision13->14 pickup is reserved. It freezes at revision13/Tomahawk0, rejects
the old acknowledgement and invalidates the operation; no baseline replenishment.
All171 Weapons Lua specs pass. Together with provider reply-loss, client late-reply
and Inventory zero-write replay checks, this closes the scoped automated reply/
replay matrix. Live interruption/crash tests remain deferred; no runtime changes,
deployment or additional grants are required for these test-only additions.

2026-10-19 AUTOMATED claimed-pickup receipt replay hardening PASS: explicit
zero-write assertions after a subsequent throw, modified session/epoch/carrier/
revision/serial/spend-key/foreign-pool replay rejection, and returned-result mutation
isolation now cover the Inventory claim primitive. Exact replay returns its stored
historical result without replenishing the current zero balance. Inventory full
Lua suite/68-file runtime syntax and2 Node tests pass. Tests/docs only; mocked
transaction evidence, not live adversarial or process-crash acceptance.

2026-10-19 AUTOMATED client pickup acknowledgement interruptions PASS: actual
controller/owner fixture now covers timeout followed by delayed success (no thaw,
rebind or resend), closed lifetime ignoring late success, replacement ped suspending
without rebind, and world exit freezing before rebind. No native ammo setter runs
and foreign repeater balance remains unchanged. Original archived client in-flight/
logout guards were checked as behavioral reference; no legacy runtime restored.
All171 Weapons Lua specs and7 Node tests pass. Tests/docs only; no deployment or
live crash acceptance inferred.

2026-10-19 AUTOMATED pickup unknown-outcome boundary: extended the actual Weapons
service fixture to commit a mocked Inventory pickup and then throw before returning
its acknowledgement. Durable simulated balance remains1/revision7; Weapons retains
the carrier hold and refuses a second provider claim and ordinary observations.
All171 Weapons Lua specs pass. No runtime/deployment change. This is mocked
post-commit export-reply loss, not live SQL/process-crash acceptance. Original
archived client native-pool recovery detection and server committed-spend allowance
were compared; their economic model is retained, not their ephemeral credit storage.

2026-10-19 FINAL LIVE observer isolation after recovered-unit logout/death/
doctor sequence PASS. Jane remains active in unchanged epoch7828bdf9-cc10-11f1-
9ad4-e0d55eaa2deb:1792461742:11611048:1, ledger35/repeater1/Tomahawk0/other pools0,
2 copies/no melee/no pending/closing/death/busy/quiesce.112rev2 retains dirt1/
degradation.00871666707098/other wear0;134rev8 pristine. John's canonical recovered
Tomahawk lifecycle narrow acceptance now includes repeat native pickup, funded
unequip/re-equip, prepared two-owner restart, normal logout/relogin, death/final
seal/doctor recovery, selectable/drawable presentation and observer isolation.
Final John source3 ledger16/Tomahawk1,155rev3/158rev5, melee160-164rev0 and
carrier165rev0; pickup gate0. No new funding/grant needed. This closes the stated
bounded own-character regular-Tomahawk lifecycle gate only; cross-player pickup,
contention, exact projectile provenance, live adversarial receipt replay and
crash/ambiguous-ack testing remain unaccepted/deferred. No production/global
pickup enablement inferred.

2026-10-19 LIVE recovered-unit DEATH/DOCTOR RECOVERY PASS. John source3:
server final wear changes0/Medical17/final ammo seal acknowledged. RecoveryStatus
confirmed current sealed ledger16/Tomahawk1, exact same session/epoch, no economic
replay or native adoption; prior logout record explicitly orderly_release with
nativeCleanupConfirmedtrue and unresolvedPersistencefalse. Doctor MedicalRespawn
authorized alive18; fresh epochccd30807-cc2b-11f1-9ad4-e0d55eaa2deb:
1792463356:13225802:4, active/no pending/closing/death/busy/quiesce. Ledger16/
Tomahawk1 preserved, carrier165rev0 GUID captured/observed1/pickupCreditsfalse,
five melee160-164rev0 active/GUID captured,2 firearm copies.155rev3 wear remains
degradation.00333333341404/soot.00499999988824 and158rev5 pristine. User confirms
Tomahawk and melee selectable/drawable. This accepts recovered carried balance
through final seal/doctor restoration, NOT death credit creation or a thrown-world
pickup across death/epochs. No new grant/funding/throw. Jane fresh observer check
for this death sequence not supplied; earlier observer/restart baselines passed.
Broader crash/ambiguous ack, adversarial duplicate injection, cross-player pickup
contention and exact projectile origin remain separate/unaccepted.

2026-10-19 LIVE recovered-unit LOGOUT/RELOGIN PASS from supplied post-login
status/maintenance. New John sessionccd30807-cc2b-11f1-9ad4-e0d55eaa2deb,
epoch1792462407:12276851:3, new ped8924674, active/no pending/closing/death/
busy/quiesce. Ledger16/Tomahawk1 and all other pools0 preserved; carrier165rev0
funded1/observed1/GUID captured/pickupCreditsfalse, five melee160-164rev0 active/
GUID captured,2 firearm copies.155rev3 degradation.00333333341404/soot.00499999988824
and158rev5 pristine unchanged. Confirms fresh-session authoritative restoration,
NOT pickup-credit carryover (gate0/no credit recovery attempted). Logout console
checkpoint and fresh visual wheel check not supplied; prior orderly restart
visual passed. Current John source omitted, ask before any targeted next gate.
Jane left connected per test instruction; new observer status not yet supplied.
No new funding, grant, throw or death requested. Next candidate gate: recovered
unit death/doctor lifecycle, only after current source confirmation.

2026-10-19 post-restart VISUAL confirmation: user confirms John can select
and draw the restored Tomahawk and melee weapons. Closes presentation portion
of the orderly two-owner recovered-unit restart gate at John ledger16/Tomahawk1,
Jane ledger35/repeater1. Pickup remains disabled. This does not extend acceptance
to crash recovery, ambiguous acknowledgements, duplicate injection or cross-player
pickup/origin authentication. No additional grants, funding, throws or edits.

2026-10-19 LIVE recovered-unit PREPARED TWO-OWNER WEAPONS RESTART PASS.
PrepareStopAll completed2/total2 aggregate PASS; ShutdownStatus phase ready2/2,
then restart Weapons with both clients connected. Jane source2 active fresh epoch
7828bdf9-cc10-11f1-9ad4-e0d55eaa2deb:1792461742:11611048:1, ledger35/repeater1,
Tomahawk0/other pools0,2 copies/no melee, no pending/closing/death/busy/quiesce.
John source3 active fresh epoch998c857c-cc14-11f1-9ad4-e0d55eaa2deb:
1792461742:11611725:2, ledger16/Tomahawk1/other pools0, carrier165rev0
funded1/observed1/GUID captured, pickupCreditsfalse. Five melee160-164rev0
active/GUID captured plus2 firearm copies. No funding/new grant/throw. Confirms
repeated native pickup's recovered carried unit survives orderly seal/cleanup/
server release/restart restoration with sibling isolation. Visual wheel selection
and fresh wear readback after this particular restart not yet supplied; earlier
re-equip/wear/observer gates passed. Live crash/ambiguous ack, duplicate injection,
cross-player pickup contention and exact world origin remain separate/unaccepted.

2026-10-19 LIVE REPEAT native pickup cycle PASS using the SAME recovered unit,
no new funding/grant. John source3, same session998c857c-cc14-11f1-9ad4-e0d55eaa2deb
and epoch1792460580:10449732:4: acknowledged throw ledger14->15/Tomahawk1->0;
subsequent pickup ledger15->16/Tomahawk0->1, pickupAcceptedRevision16, carrier165rev0
GUID captured/active, pickupCreditstrue. Parent active/no pending/closing/death/
busy/quiesce;2 firearm copies, all five melee160-164rev0 and entities unchanged.
Inventory COMMIT supplied queries8/duration1160ms (slow=true); no evidence of
failure. Confirms new consumption/recovery after previous pickup/re-equip, NOT
an adversarial duplicate-receipt/replay-injection test. First-cycle wear/Jane
isolation previously accepted; fresh repeat-cycle observer checks not supplied.
Next return pickup gate0 after successful acknowledgement; no further throw or
funding until next explicit lifecycle gate. Live crash/ambiguous ack/contention/
exact projectile provenance remain pending.

2026-10-19 NARROW NATIVE PICKUP/RECOVERED-CARRIER LIVE GATE CLOSED PASS.
Final John maintenance:155rev3 degradation.00333333341404/soot.00499999988824,
other wear0;158rev5 pristine, unchanged in final epoch998c857c-cc14-11f1-9ad4-
e0d55eaa2deb:1792460580:10449732:4. Final Jane observer isolation: source2 active,
no pending/closing/death/busy/quiesce,2 copies/no melee, unchanged epoch7828bdf9-
cc10-11f1-9ad4-e0d55eaa2deb:1792452298:2167037:1, ledger35/repeater1/Tomahawk0/
all other pools0;112rev2 dirt1/degradation.00871666707098 and134rev8 pristine.
Accepted scope: one physical native pickup with canonical ledger13->14/read-only
GUID rebind; recovered-carrier cleanup; restored unit through prepared restart;
same-session funded unequip/re-equip after prefunded-belt fix; wear and observer
isolation. John source3 final ledger14/Tomahawk1, carrier165rev0/GUID captured,
five melee160-164rev0 active. Pickup gate remains0. No new grant/funding required.
Not accepted: exact projectile-origin authentication, cross-player/contended pickup,
crash/ambiguous-ack behavior live, live duplicate receipt injection or cross-epoch
pickup credit. Automated contracts cover replay/uncertain failures but are not
live multiplayer/security acceptance. No broad production pickup enablement.

2026-10-19 LIVE funded/recovered Tomahawk UNEQUIP/RE-EQUIP regression PASS.
John source3: unequip and re-equip carrier165 both reported conditional commit/
fresh restore PASS; user confirmed wheel removal then return. Same session
998c857c-cc14-11f1-9ad4-e0d55eaa2deb, final epoch1792460580:10449732:4, active,
no pending/closing/death/busy/quiesce. Ledger14/Tomahawk1 preserved, other pools0,
carrier165rev0 funded1/observed1/GUID captured, pickup gate0. Five melee160-164rev0
active/GUID captured,2 firearm copies. Live accepts prefunded-belt creation fix
following earlier failed re-equip; no new funding/grant/consumption. Prior native
pickup13->14 and cleanup remain accepted. Need fresh John/Jane maintenance and
Jane observer baseline before closing this narrow gate. Broader pickup contention,
crash/replay and cross-epoch pickup credit remain unaccepted.

2026-10-19 live recovery after companion flag reset/clean Weapons restart:
PrepareStopAll PASS completed1/total1 for Jane after John disconnected. Restored
knife/melee/throwable1, pickup0. Jane source2 active full28 pools, ledger35/repeater1,
Tomahawk0. John reconnected active, ledger14/Tomahawk1, carrier165rev0 GUID captured,
pickupCreditsfalse, five melee160-164rev0 active and2 firearm copies. No funding.
John's current source was omitted: ask before targeted commands. Restored loadout
confirmed, but same-connection funded unequip/re-equip fix remains live untested.

2026-10-19 LIVE recovered-carrier RE-EQUIP FAILED (retain failed gate):
WeaponNativeEquipmentChange6 equip weapon_throwable165 started; new epoch
0c983294-cb87-11f1-9ad4-e0d55eaa2deb:1792393778:17013152:5 froze before ammo
activation, throwable reason throwable_preexisting_or_unconfirmed, no captured
GUID/owned firearm copies. Prior pickup and isolated unequip remain valid but
full re-equip gate is NOT complete. Reproduced preserved funded-belt transition:
unassigned runtime restores ledger14/Tomahawk1; its no-carrier cleanup leaves
native pool1; old owner and concrete factory incorrectly required pool0.
Fix allows only0 or exact approved funded quantity with weapon absent, independently
requires no carried-inventory GUID, rechecks context/pool before zero-ammo carrier
creation and skips setter when existing pool already matches1. Existing weapon,
existing GUID, over-capacity and unfunded mismatches still refused. Added rejected
preflight diagnostics to child status. Session regression covers unassigned
funded restore/cleanup/re-equip; concrete tests prove zero extra setter for
prefunded pool and rejection of pre-existing weapon/GUID.171 Lua specs/runtime
syntax and seven Node tests PASS; live fix untested. Deployment delta ONLY
Weapons client/native_throwable_owner.lua and client/native_throwable_adapter.lua.
No Inventory/config/manifest/SQL change; existing files need no new refresh.
John must FULLY quit RedM (not selection), then prepare-stop remaining connected
owners and wait aggregate PASS before Weapons restart; Jane may remain connected
through prepared restart. Reconnect John, collect new IDs/status; do not retry,
fund, reset ledger or issue replacement. Canonical recovered unit remains ledger14.

2026-10-19 LIVE recovered-carrier isolated unequip PASS from John status plus
explicit wheel confirmation (equipment console PASS not supplied). Fresh epoch
0c983294-cb87-11f1-9ad4-e0d55eaa2deb:1792393513:16747645:4, active/nonbusy/
nonquiescing/no pending; throwable child absent and Tomahawk left wheel. Ledger14
and ammo_tomahawk_regular1 preserved, all other pools0; no economic consumption
or refund inferred. Five melee160-164rev0 remain active/GUID captured after rebuild.
Firearm155rev3 degradation.00333333341404/soot.00499999988824 and158rev5 pristine
unchanged. Confirms cleanup after acknowledged native pickup/GUID rebind. Next
re-equip existing carrier165 using preserved carried ledger unit (NO funding or
new grant), confirm active funded1/GUID/wheel and unchanged ledger14, then Jane
observer isolation. Restart/replay/contended pickup remain separate live gates.

2026-10-19 FIRST LIVE NATIVE PICKUP PASS. John source6 physically recovered
visible thrown Tomahawk; client logged WeaponNativeThrowablePickup PASS ledger
acknowledged/read-only GUID rebind revision14; no loose/native ammo grant.
Same session0c983294-cb87-11f1-9ad4-e0d55eaa2deb/epoch1792392965:16199976:3;
ledger13->14, Tomahawk0->1, carrier165rev0 active/observed1/GUID captured,
pickupAcceptedRevision14. Parent active, no pending/closing/death/busy/quiesce;
all five melee160-164rev0 unchanged with identical entities. Other ammo pools0.
This confirms one same-session bounded native pickup and canonical acknowledgement,
NOT exact projectile-origin authentication, multiplayer pickup contention, crash
recovery or live receipt replay. Next isolated unequip of recovered carrier via
WeaponNativeEquipmentChange 6 unequip weapon_throwable; require fresh active
restore, no throwable child, retained ledger14/Tomahawk1 and siblings unchanged.
No unfund/new grant/second throw requested. Wear and Jane observer checks pending.

2026-10-19 live pickup-test throw checkpoint PASS: John source6 remains in
session0c983294-cb87-11f1-9ad4-e0d55eaa2deb, same epoch1792392965:16199976:3.
Acknowledged ledger12->13, ammo_tomahawk_regular1->0; active/nonbusy/nonquiescing,
no pending/closing/death. Carrier165rev0 observed0/funded1/GUID captured and
pickupCreditstrue. Five melee160-164rev0 unchanged/active. User explicitly sees
the landed Tomahawk. Next native physical pickup once, inspect PASS/ledger14/1
and pickupAcceptedRevision14; no new grant/funding or restart. Durable receipt
creation is implied by successful gated observation path, not separately inspected.

2026-10-18 live funded pickup baseline confirmed from John client status:
source6, session0c983294-cb87-11f1-9ad4-e0d55eaa2deb, epoch suffix
1792392965:16199976:3, active/nonbusy/nonquiescing/no pending. Ledger12,
ammo_tomahawk_regular1/all other pools0; carrier165rev0 funded1/observed1,
GUID captured/pickupCreditstrue. All five melee160-164rev0 active/GUID captured.
Funding console PASS not supplied; restored funded state itself confirmed.
Next controlled throw on clear flat ground, wait for acknowledged ledger13/count0
before pickup; no restart/reconnect/gate toggle during this epoch. Physical
pickup and durable spend receipt creation remain unverified live.

2026-10-18 live pickup-test allowance PASS: Jane source5, John source6.
InvNativeThrowablePickupBudget delivered exactly one loose ammo_tomahawk_regular
unit, instance170/definition93, inventory5, receipt native-tomahawk-pickup-budget-v1;
first replayedfalse, second replayedtrue/same instance170. Budget gate reset0.
No carried/native/equipment write in grant. Next enable replicated runtime pickup
gate and fund ONE carried unit via new operation native-tomahawk-pickup-fund-v1,
then inspect restored status before any throw. Physical pickup remains untested.

2026-10-18 user confirms John has NO loose Tomahawk ammunition. Added separate
fixed one-unit console-only pickup-test allowance in existing Inventory
server/services/grants_once.lua: InvNativeThrowablePickupBudget, server-only gate
feather_native_throwable_pickup_budget, stable receipt native-tomahawk-pickup-budget-v1.
Uses existing canonical GrantOnce/private key, exact John UUID/current source,
loose ammo only. Earlier two-unit/death budgets untouched; replay cannot refill.
Tests cover separate gate/receipt, wrong caller/character/args, receipt failure,
session loss rollback, one-unit delivery and spent replay. Full Inventory Lua
suite/68 runtime syntax files and two Node tests PASS (mocked SQL); no live grant.
Deployment delta after user's previous update: ONLY grants_once.lua. Existing
script/manifest path unchanged, no new manifest refresh requirement for this delta.
Prepare Weapons shutdown PASS, fully quit BOTH clients, update that file, restart
Inventory then Weapons, reconnect and collect changed sources before allowance
command. Pickup runtime gate stays0 until funding test setup; budget gate defaults0.
No grant, carried funding or throw performed yet.

2026-10-18 deployment baseline confirmed by user: Jane source3, John source4.
WeaponNativeThrowableStatus enabled/convar1/components loaded; pickupConvar0,
pickupCreditsfalse, exact-origin still false. John active/nonbusy/nonquiescing,
new session817f0650-cb83-11f1-9ad4-e0d55eaa2deb epoch suffix1792390124:13358683:2,
ledger11/all pools0; assigned carrier165rev0 empty/unfunded/no GUID. All five
melee160-164rev0 active/GUID captured; firearms155rev3 and158rev5 retain previous
wear/pristine values. Confirms startup baseline only, not live pickup. Need
current loose Tomahawk quantity before selecting bounded funding/test allowance;
old grant receipts must not be reused to replenish. Keep pickup gate0, no throw.

2026-10-18 native-pickup client request/ack and read-only GUID rebinding
implemented. Explicit replicated feather_native_throwable_pickup gate defaults0.
Owner holds 0->1 native increase as a candidate only against acknowledged same-
epoch ledger0; Session blocks input while a single pickup request is pending.
Client request contains no spend receipt or plan. Exact canonical revision+1
acknowledgement invokes read-only capture of the unique exact-model GUID in this
ped's carried inventory. No ammo setter, loose item grant, world object adoption
or removal during acknowledgement. Confirmed rebind advances owner observation
and pickupAcceptedRevision; PASS log includes accepted revision. Timeout/bad ack,
gate/world change, wrong-model/unknown rebind freeze without automatic retry.
Generic observations and disabled-gate native increases remain fail-closed.
Session composition covers throw/committed-zero/pickup/ack/rebind/normal seal and
cleanup with no extra grant; concrete adapter covers changed GUID and wrong model.
Transport rejects client-selected recovery plans and funding payloads. Read-only
WeaponNativeThrowableStatus now reports pickupConvar/components/policy and gate-
controlled pickupCredits without claiming exact projectile origin. Weapons171
Lua specs/runtime syntax + seven Node tests; Inventory full Lua suite/68 runtime
files syntax + two Node tests PASS (mocked natives/providers/SQL, NOT live pickup).
Next gate: prepared shutdown PASS/ready, fully quit both clients, update BOTH
Weapons and Inventory resource folders including manifests/new scripts, run
server-console refresh BEFORE restarting Inventory then Weapons; reconnect and
collect new player IDs/status. Keep setr feather_native_throwable_pickup 0 until
one-unit test funding is separately staged. No grant/funding/throw performed.
Old epoch receipts cannot fund the new epoch; current last durable Tomahawk11/0
is NOT a live pickup allowance. The first physical pickup test is still pending.

2026-10-18 server native-pickup request/ack path connected behind default-off
feather_native_throwable_pickup gate. Successful normal observation retains its
Inventory-committed spend record privately on the bound Weapons epoch; a pickup
request cannot choose receipt or plan. NativePickup validates the live loadout,
re-derives the exact plan from that record and current full ledger, reserves it
under a one-use runtime ticket, invokes trusted Inventory reconciliation and
retires the private credit after confirmed success. Pickup completion stays
active (native ammo already exists), never goes through a native restore/setter.
Inventory export requires Weapons caller/current session/exact reserved plan at
every boundary; Weapons additionally requires alive Medical state during claim
authorization. Generic observation still rejects all increases. Server service
and runtime tests cover record capture, exact plan reservation, stale/gate/replay
refusal, retained item hold and uncertain commit freeze; mocked provider/SQL only.
Weapons170 Lua specs/runtime syntax + seven Node tests; Inventory complete Lua
suite/68 runtime syntax files + two Node tests PASS. Client automatic pickup
request, canonical acknowledgement and GUID rebinding are still NOT connected;
do not enable gate or deploy/test this partial slice. Shared pure planner and
Inventory claim are now explicitly manifest-listed (exact-origin loose-item claim
remains inactive). Eventual deployment MUST run server-console refresh before
Inventory/Weapons restart after prepared release and full client quits. No new
budget/throw or live acceptance.

2026-10-18 durable native-pickup spend writer connected to Inventory's existing
reserved normal-observation transaction behind DEFAULT-OFF server convar
feather_native_throwable_pickup. New service native_throwable_native_pickup_credits.lua
requires the locked after-ledger, exact assigned carrier, full monotonic pools,
current runtime/session authority and committed 1->0 observation. Stable server
receipt spend:<itemId>:<afterRevision> is created in the SAME transaction; receipt
failure rolls consumption back. No client-selected operation ID. Final/death wear
seals, idle samples and disabled gate create no allowance. Claimed records cannot
be overwritten/reopened. Current generic native-increase rejection is unchanged.
Actual observation + writer + claim composition passes mocked-SQL tests including
replay after another spend, both write failures, authority loss after either write,
CFX callable authority and gate/final/idle isolation. Full Inventory Lua suite and
67 runtime files syntax, two Node tests PASS. Live pickup route and client-owner
reconciliation still pending; do NOT enable the pickup gate yet. No live acceptance
or new grant/throw. Eventual deployment adds a service script: prepare/release owners,
fully quit clients for Inventory restart, copy files, run server-console refresh,
restart Inventory then Weapons and reconnect. Do not deploy this partial slice yet.

2026-10-18 native pool pickup accounting transaction primitive implemented:
Inventory server/internal/native_throwable_native_pickup_claim.lua, inactive
(no manifest/export/route). Locks ledger and server-written same-session spend
receipt, requires exact assigned carrier/revision/serial and full unchanged
foreign pools, applies one-unit character-ledger CAS and marks that receipt
claimed inside caller-owned transaction. No loose item grant or native setter.
Exact replay returns the stored result without restoring ammunition already
spent later; altered replay is refused. Failed write or authority change requires
full transaction rollback. Mocked SQL tests cover replay/no replenishment, both
write failures, authority loss, stale/foreign receipts, carrier and pool isolation.
Inventory complete Lua suite/66-file runtime syntax and two Node tests PASS;
Weapons168 Lua specs/runtime syntax and seven Node tests PASS. No live acceptance.
Durable spend writer, trusted server route and client-owner reconciliation remain
unwired; credits DISABLED. This separately named original-style budget policy
bounds amounts but does not establish exact world-projectile origin. No deploy,
new grant, funding or throw requested yet.

2026-10-18 original-policy native pickup transaction planner implemented in
inactive shared/native_throwable_recovery.lua (NativePickupPlan). Separately
named same_session_native_spend_credit_v1 policy, not a weakening/fallback of
projectile-origin BindingPlan. Re-derives exact one-unit committed spend from
server-owned before/after/equipment records, requires unclaimed durable receipt,
same live epoch/carrier/revision/serial, full current ledger and exact 0->1 native
pool increase with all other pools unchanged. Plans character-ledger revision+1
and spend-claim/CAS requirements, no loose item or native setter. Origin is NOT
confirmed. Repeated planning remains data only: durable atomic claim and ledger
CAS are still REQUIRED and not yet wired. Generic monotonic observation remains
unchanged.168 Lua specs/runtime syntax PASS; no live acceptance, manifest/export,
new budget or deployment request. Next: Inventory atomic spend-receipt claim plus
ledger CAS, then guarded owner reconciliation; no automatic credits enabled.

2026-10-18 historical single-type pickup path located in archived client/main.lua
and server/services/ammo.lua. Native GetPedAmmoByType increase detected recovery;
server SyncConsumption capped recovery by ephemeral same-source/session/carrier/
generation/ammo credits created after successful consumption commits. No landed
projectile search was required. docs/throwing-knife-multi-ammo.md explicitly
preserves single-type Tomahawk recovery; earlier knife-only exclusion was not
evidence against it. This is a reusable detection/accounting pattern, not proof
of exact projectile origin. Do not restore the archived runtime or weaken
current accounting silently. Current owner now preserves bounded nativeIncrease
diagnostic evidence (0->1, exact epoch/carrier/type, copied status, no pickup
confirmation/credit) before retaining on an increase.167 Lua specs and runtime
syntax PASS; not live-tested. No new script/manifest or Inventory changes.
Native pickup detection is separate from durable exactly-once reconciliation;
the latter remains pending, as does any decision to require projectile origin.
No new budget/throw requested; deploy client/native_throwable_owner.lua only
at the next successfully prepared Weapons restart, not an immediate live gate.

2026-10-18 user clarifies throwable pickup worked during the native-system
switch; preserve this as a reported working behavior, not a reason to defer
pickup. Exact historical implementation has not yet been identified. Current
native_throwable_owner.Observe explicitly retains on any native quantity
increase (throwable_native_increase_no_pickup_credit); this is incompatible
with accepting native pickup and needs a separately validated reconciliation
path. Investigate native pickup/detection reuse independently of economic
credit. Historical no-pickup acceptance notes do not disprove user observation.

2026-10-18 complete client snapshot attachment received: poolSize1234,
partial=true, ledgerRevision11, output16 objects (eight networked/unattached,
eight local-only/unattached). Networked model3752012054 appears three times;
none of these models is verified as the Tomahawk. Partial output cannot prove
projectile absence; client network IDs/model matches cannot prove throw origin
or authorize recovery. No pickup credit, grant, funding or native mutation
performed. Exact Tomahawk object-model identification and authenticated server
origin/lifetime binding remain pending before recovery can be enabled.

2026-10-18 live client snapshot capability verified, ledger11 unchanged; output
truncated after first objects. Signed model hashes normalize correctly. Probe
generated NETWORK_GET_NETWORK_ID_FROM_ENTITY warnings for local map props/
attachments (networkId0); these are diagnostic getter misuse, not proven native
owner failure. Fixed client probe to check NetworkGetEntityIsNetworked before
network ID lookup; optional missing read remains unknown, never authority.
Scan bounded512 nearby candidates, prioritize networked then unattached/nearest
before output cap16, report poolPartial/outputPartial and nearby total.167 Lua
PASS including local-only no network query and cap/prioritization regression.
Deploy only client/native_throwable_projectile_probe.lua at prepared Weapons
restart; request complete snapshot JSON/text attachment. No new throw/grant/
pickup; observed model hashes so far are NOT identified as landed Tomahawk.

2026-10-18 complementary client READ-ONLY snapshot implemented/manifest-listed:
client/native_throwable_projectile_probe.lua command weaponNativeProjectileSnapshot,
replicated default-off feather_native_throwable_client_probe gate, active alive
same-epoch before/after read and5s cooldown. GetGamePool CObject bounded512 entries,
max16 within50m; reports signed/normalized model, coordinates/network readback and
attachment status with partial flag. No loops/threads, network send, control
request, deletion, ammo write or credit; output explicitly clientDiagnosticOnly,
originConfirmed=false/pickupCredits=false.167 Lua/runtime syntax PASS. Cfx pool
declaration includes objects/projectiles, but client evidence cannot authorize
server recovery (https://github.com/citizenfx/fivem/blob/master/ext/native-decls/GetGamePool.md).
Deploy Weapons manifest + new client probe + signed-hash server probe patch after
prepared drain; server-console refresh and Weapons restart. Initial live client
snapshot only, no new throw/grant, last ledger11/count0. Verify capabilities and
mapping before any further controlled funded test; authoritative origin remains
unresolved, all recovery claims inactive.

2026-10-18 detailed live probe confirms old handle142104 entity_absent; no
recovery target. Other created handles157055/161378/162360 reported model_invalid,
5 owner mismatches/9 reads/projectileEvents0. Found diagnostic rejects signed
32-bit model hashes. Normalize valid signed[-2147483648..-1] to unsigned32,
retain modelRaw in output; still reject NaN/fraction/out-of-range.166 Lua PASS
including signed hash regression. Actual rejected live values were not logged,
so signed hash is a code defect correction, not proven cause of every live error.
Update existing probe script at next prepared Weapons restart; do not repeatedly
inspect absent old handle or issue another budget merely for that readback.
Last durable Tomahawk11/count0; live origin/pickup still unverified, credits off.

2026-10-18 diagnostic ambiguity fixed without any ammo/world changes. Concrete
probe now separates entity_absent, native unavailable/exception/nil/invalid and
disappearance-during-read; aggregate bounded reason counters plus max8 failure
logs (no raw exception text). Model0 is modelSettled=false with separate count,
not native read failure; owner mismatch/non-object filtered counts explicit.
Regression cases cover all these categories;166 Weapons Lua PASS. User reports
no landed Tomahawk visible; no recovery proof accepted. Deploy only existing
server/services/native_throwable_projectile_probe.lua after prepared drain and
Weapons restart. Existing handle readback can classify failure without another
throw/grant. Last known durable ledger11/count0; credits remain disabled.

2026-10-18 optional handle142104 readback yielded no usable observation: probe
armed source2 then stopped, projectileEvents0/entityEvents0,16 entity read
attempts/2 nativeReadFailures; flag reset0. Current probe conflates absent entity
with native read exceptions, so this does NOT prove projectile despawn, invalid
mapping or absent RedM support separately. No provenance binding/credit accepted.
No additional budget/throw authorized by this diagnostic. Next distinguish
read failure causes and determine whether landed Tomahawk is still visible before
choosing further observation; keep pickup disabled and preserve ledger11/count0.

2026-10-18 live read-only probe inconclusive for origin: John source2 throw
decreased durable client baseline10->11/Tomahawk1->0, owner/siblings active.
Probe observed object handles143146/net18 and142104/net11, both model0/type3 at
creation;143146 later removed. No startProjectileEvent observed (count0),57
entity-read attempts/no native failures. Probe stopped/flag0; no credit awarded.
This does NOT identify landed projectile or establish origin. Added bounded
100/500/1500ms settle reads, invalidated on lifetime/run/epoch removal; optional
console handle readback WeaponNativeProjectileProbe source handle permits
read-only examination without another funded throw.166 Weapons Lua PASS.
Deploy only existing probe file after prepared drain/Weapons restart; no client
quit required for ordinary successful drain. Inspect surviving handle142104 if
still present and owned; no new grants/throws/pickups. Artifact event support and
model synchronization remain unresolved until concrete readback.

2026-10-18 concrete READ-ONLY projectile diagnostic ready for deployment:
server/services/native_throwable_projectile_probe.lua now manifest-listed,
default-off feather_native_throwable_projectile_probe convar, console-only
WeaponNativeProjectileProbe currentSource / stop. Requires active enrolled epoch,
expires60s or gate/owner change; max8 sender projectile hints,32 owned object
observations,128 entity read attempts. Logs bounded numeric event fields, expected
ped network ID, object model/network/handle and removals. Explicit noWrites,
originConfirmed=false/pickupCredits=false; no consumption/deletion/ammo/Inventory
or recovery claims.166 Weapons Lua/runtime syntax +7 Node PASS. Native event and
landed model mapping still pending live probe, not inferred from mocked tests.
Deploy Weapons fxmanifest.lua + new probe script after aggregate prepared drain;
server-console refresh then restart Weapons. Keep probe flag0 and confirm John's
funded ledger10/unit1 baseline before arming. No pickup credit route deployed.

2026-10-18 inactive recovery reconciliation coordinator implemented/tested:
reserve spend/projectile/origin before yielding, require trusted verified binding
and current authority, exact world lifetime/model/network identity, alive actor
same bucket within2m; consume once, require exact-lifetime absence, then invoke
transaction-backed claim. Unknown deletion/SQL response or partial failure stays
frozen with separate worldOutcome/commitOutcome evidence, no retry/refund/new
credit.165 Weapons Lua PASS; no manifest/event/native host integration. Injected
tests cover reentrancy, stale lifetime/proximity/NaN/bucket/death, false/exceptional
consume, still-present world entity, refused/uncertain SQL and authority loss.
Cfx source verified explicit STATE_RDR3 startProjectileEvent handler (not just
FiveM docs): https://raw.githubusercontent.com/citizenfx/fivem/master/code/components/citizen-server-impl/src/state/ServerGameState.cpp
This does NOT prove deployed artifact behavior or landed-entity association.
Next concrete read-only RedM origin/lifetime diagnostic and durable spend/binding
writer; native auto-pickup reconciliation and actual SQL contention remain open.
Pickup credits stay disabled; no deployment/manual throws requested.

2026-10-18 inactive atomic recovery claim primitive added under Inventory
server/internal/native_throwable_recovery_claim.lua (outside services wildcard,
no export/event/command). Requires existing durable committed spend AND verified
binding records plus exact current released-authority callback; never creates
origin proof. Existing inventory_grant_receipts namespaces reserve spend,
projectile lifetime and origin uniqueness in deterministic order; delivery is
one regular Tomahawk LOOSE ammo unit via canonical AddQuantity, never carried
ledger/native adoption. Three completion receipts + spend claimed marker share
caller-owned transaction. Replay returns historical result without replenishment;
partial/corrupt/conflicting receipt/capacity/session failures require rollback.
Mocked SQL tests cover four write-failure points, post-delivery authority loss,
duplicate/replacement-origin claims and immutable binding. Inventory full Lua/
65 syntax PASS. No schema/manifest/deployment change and no live credit route;
trusted RedM origin provider, durable spend/binding writer and released-owner
world-consumption reconciliation remain absent. John retains ledger10/unit1.

2026-10-18 inert server projectile-observer cache implemented/tested, not live
origin attestation. Explicit injected server session/entity/hash ports, boot-scoped
lifetime IDs independent of recycled entity/network IDs, capped64 entities/16
hints, 30s/3s expiry, duplicate/owner/session/change checks. Projectile events
remain hints; every output originConfirmed=false/pickupCredits=false and cannot
satisfy authenticated recovery binding. No event registrations/manifest/native
or economic writes.164 Weapons Lua PASS. Cfx server event reference lists
startProjectileEvent/entityCreated/entityRemoved, but does not establish target
RedM behavior (https://docs.fivem.net/docs/scripting-reference/events/server-events/).
No server observer/origin provider previously exists in this workspace; object
model mapping and actual RedM event/lifetime relationship need verification.
Next durable atomic claim contract plus trusted-origin provider/probe; credits
stay disabled. No manual throw/deployment; John's funded ledger10/unit1 retained.

2026-10-18 inert pickup binding contract added: BindingPlan joins exact immutable
spend candidate with committed/unclaimed receipt record and independently supplied
server projectile-origin record. Requires same carrier item/revision/serial,
character/session/epoch, regular model/ammo/unit, bounded spawn window, server
projectile lifetime ID + origin event (network ID alone insufficient). Claimed,
stale/foreign/missing-origin/variant records refuse. Output remains pickupCredits
false and explicitly requires atomic single claim/current projectile/proximity.
163 Weapons Lua/runtime syntax PASS. These are pure contract tests with fabricated
server records, NOT live native-origin proof or a durable claim implementation.
No live server observer/receipt store exists yet; no exports/events/manifest or
native/economic mutation enabled. Next implement trusted observer and atomic
single-use spend/projectile claim; no manual throw or deployment requested.

2026-10-18 pickup preparation started, no runtime admission: inert
shared/native_throwable_recovery.lua builds an unbound spend candidate from
server-confirmed before/after active observations and exact pre-commit carrier
snapshot. Requires full pools, same character/session/epoch, ledger successor,
regular Tomahawk1->0, original item/revision/serial; repeated evidence uses same
structured spend key. Explicitly pickupCredits=false and requires projectile
binding + durable single claim: candidate alone is NOT recovery authorization,
receipt or proof that loss was a throw. No export/events/native calls/SQL/manifest
entry, no legacy item-ammo escrow restored.163 Weapons Lua/runtime syntax PASS.
Next: trustworthy projectile binding/proximity/ownership evidence and atomic
single-use claim contract before credits or live pickup. John retains funded1
ledger10; no deployment or further manual throws requested.

2026-10-18 user-confirmed funded resource-restart restoration PASS: both clients
active/fresh epochs after requested prepared-restart procedure (drain console
output not supplied). Jane epoch1792379080:2314506:1 ledger35/repeater1/Tomahawk0,
two copies/no melee unchanged. John epoch1792379080:2315202:2 carrier165rev0
active/GUID captured/funded1/observed1, ledger10/Tomahawk1, two firearm copies/
five melee160..164rev0 active, no pending/closing/quiescing. No payment/refund or
ammo revision churn. Readiness result confirms restoration, not unprovided drain
aggregate proof. Regular one-unit base, spent cleanup and funded death gates
remain passed; pickup recovery/credit and other variants remain pending.

2026-10-18 FUNDED REGULAR TOMAHAWK DEATH/DOCTOR GATE COMPLETE: final Jane
observer source1 active/two copies/empty melee, ledger35/repeater1/Tomahawk0,
session10fcf095-cb65-11f1-9ad4-e0d55eaa2deb epoch1792377048:283095:1;
maintenance112rev2 degradation0.00871666707098/dirt1/others0 and134rev8 pristine
unchanged. Combined with John's sealed10/count1, doctor alive16, fresh GUID-bound
carrier165rev0/selectable count1, firearm155rev3/158rev5 wear unchanged and five
melee restored, confirms funded death/doctor behavior and cross-character
isolation. Paid unit remains carried by John; no extra grant/payment. Pickup
credit/recovery remains unimplemented/unaccepted, as do additional throwable
models and production admission. Existing regular-only one-unit boundary retained.

2026-10-18 user confirms Tomahawk selectable after doctor recovery. John funded
death/doctor lifecycle gate now manually confirmed: sealed/restored ledger10/
quantity1, carrier165rev0/GUID captured, two firearms/five melee and firearm wear
unchanged, wheel selection restored. No new grants/payment. Final Jane observer
snapshot still pending for death-cycle cross-character isolation; earlier base
throw/unfund/spent gate observer isolation passed. Pickup recovery/credit remains
unimplemented/unaccepted; do not infer it from post-respawn wheel selection.

2026-10-18 live funded Tomahawk death seal + doctor restoration PASS (post-
respawn wheel selection awaiting user confirmation): after server restart flags
knife/melee/throwable restored1, Jane source1/John source2. John active carrier
165rev0/GUID captured/count1 ledger10, then medical dead15; server final wear
changes0/final ammo seal acknowledged. Recovery currentAcknowledged sealed10/
Tomahawk1, no economic replay/native adoption. MedicalRespawn alive16 restored
same session1693f6d4-cb65-11f1-9ad4-e0d55eaa2deb fresh epoch ending
1792378370:1604380:3, throwable165 active/GUID captured/funded1/observed1,
two firearms/five melee160..164rev0 active and no pending/closing flags.
Final maintenance155rev3 degradation0.00333333341404/soot0.00499999988824 and
158rev5 pristine unchanged. No additional funding/payment. Jane current observer
snapshot and post-doctor selectable confirmation not supplied yet. Pickup credit/
recovery, other throwable models and production admission remain unaccepted.

2026-10-18 second funded-death test: John source20 recovered alive medical12
with ledger10/count1, then dead medical13; child remains active (polling fix held)
but CheckpointAndSeal failed before seal. Reproduced server contract defect:
deathPlan ReadNativeEquipmentTransition returned equipment-only throwable data,
while lease.Validate correctly requires ledger revision/full pools. Added explicit
server limits argument to that read; Inventory enriches child from ledger inside
same transaction when requested (ordinary equipment reads unchanged). Death plan
passes original registry limits. Tests reproduce equipment-only refusal and
successful funded death seal using complete snapshot; Inventory test verifies
same transaction/ceiling/read-only enrichment. 162 Weapons Lua +Inventory full
Lua/64 syntax PASS. Added server seal-preflight refusal code logging. Deploy
Weapons server/services/character_ammunition_runtime.lua and Inventory
server/services/native_equipment_commit.lua after John full quit/observer prepared
stop, restart Inventory then Weapons; medically recover and confirm ledger10
before next death. No new budget/funding. Live funded-death remains pending.

2026-10-18 funded death gate FAILED pre-seal: separate one-unit death budget
receipt delivered instance169/replay safe, carrier165 equipped and funded with
native-tomahawk-death-fund-v1 ledger9->10/count1. Medical dead revision11
persisted, but ordinary throwable observation used alive context during pending
death seal, retained throwable_quantity_unconfirmed and froze parent. Server
recovery activation ledger10, no seal confirmation. Fixed session Tick to skip
ordinary throwable polling when deathClosing or alive readiness unavailable;
existing identity-checked dead snapshot/controller remains sole death observation
authority. Alive readiness-loss/pending-seal/doctor-cleanup regression added;
162 Weapons Lua PASS. Deploy only client/character_ammunition_session.lua with
John full quit, observer prepared stop before restart. Recover medically if still
dead after rejoin, verify paid ledger10/count1 before repeat death; no new grants.
Funded death/doctor live acceptance still pending.

2026-10-18 next funded-death gate prepared: separate private Inventory budget
profile for exact John CID, quantity1 regular Tomahawk, fixed receipt
native-tomahawk-death-budget-v1 and default-off feather_native_throwable_death_budget.
Console InvNativeThrowableDeathBudget uses existing GrantOnce transaction with
session/definition/receipt checks; original two-unit receipt remains unchanged.
Tests prove separate flags, fixed quantity/receipt, no replay replenishment and
receipt/session rollback. Inventory full Lua/64 syntax +2 UI tests PASS.
Deployment change only server/services/grants_once.lua, no manifest/SQL changes.
PrepareStopAll, both clients fully quit before Inventory restart, then Weapons;
confirm current IDs and ledger9/empty baseline before separate one-unit grant,
carrier165 re-equip and new funding operation. No live death result accepted yet.

2026-10-18 BOUNDED REGULAR TOMAHAWK LIVE GATE PASSED: user confirms final
observer Jane active ledger35/repeater1/Tomahawk0, two firearms; maintenance
112rev2 degradation0.00871666707098/dirt1/others0 and134rev8 pristine unchanged.
John final ledger9/Tomahawk0, no throwable owner, two firearms/five melee active;
155rev3 degradation0.00333333341404/soot0.00499999988824/others0 and158rev5
pristine unchanged. Confirmed scope: pristine carrier165 issuance+receipt replay,
unfunded assignment, fixed loose-budget replay, canonical +1 funding/restart
restoration, selectable/drawable carrier, unthrown exact release/-1 return,
refunding, controlled throw monotonic accounting and spent exact unequip without
ammo refund, sibling/observer isolation. Earlier failed attempts remain recorded.
NOT accepted: pickup credit/recovery or world projectile persistence, funded
death/doctor restoration, additional models/variants, capacity above1 or general
production admission. No automatic budget replenishment; two test units spent.
Next separate gate: funded death/doctor lifecycle; requires explicit bounded
new test allowance (existing budget receipt must never refill). No grants made.

2026-10-18 live spent cleanup/unequip PASS after exact empty-carrier fix: John
source17 restored empty ledger7, native-tomahawk-fund-v3 committed ledger8/count1,
second controlled throw observed ledger9/count0, then unequip weapon_throwable
PASS conditional equipment commit/fresh same-session restore/no ammo economic
writes. Post-restore epoch ending1792367087:56494969:4 active, no throwable
owner, Tomahawk0/revision9 unchanged; two firearm copies/five melee160..164rev0
active, no pending/closing/frozen state. Confirms spent release path, not pickup
recovery/world projectile persistence or broad throwable support. Fixed loose
budget originally2 has funded two spent throws; do not replay budget for refill.
Next inspect Jane observer status and both firearm maintenance baselines before
closing this bounded regular-Tomahawk gate. Funded death/pickup remain untested.

2026-10-18 live spent unequip FAILED before equipment commit: source16 owner
retained throwable_cleanup_unconfirmed, sealed ledger7/Tomahawk0, siblings intact.
Old spent path required automatic GUID/model disappearance; no branch detail in
old output, so exact live cause still unproven. Added spent diagnostics and exact
empty-carrier removal only when original GUID independently reads expected model
AND resolves in current ped CHARACTER/CARRIED_WEAPONS slots. No world entity
handle/deletion, ammo setters/reductions, refund or replacement-GUID adoption.
Already absent entry still accepted only with ped model absence; all pool counts
must remain unchanged. Retained-empty/readback/foreign GUID regressions pass;
162 Weapons Lua PASS. Deploy only native_throwable_adapter.lua after John full
quit/observer prepared stop; reconnect ledger7/empty without payment. A new funded
throw cycle is required to retest spent cleanup; empty reconnect alone is not proof.

2026-10-18 live single throw observation PASS: John source16 client active,
carrier165rev0 initial funded1/current observed0, ledger baseline7/Tomahawk0;
server currentAcknowledged revision7/active/Tomahawk0, economicReplay=false,
nativeAdoption=false. Top-level recovery ledgerRevision6 remains activation
snapshot, not newer acknowledged count. Two firearms/five melee unchanged.
No pickup reported. Next spent carrier unequip through same release coordinator;
must prove ped-owned GUID absence without deleting projectile or refunding ammo.
Spent cleanup and pickup remain unaccepted.

2026-10-18 live refunding PASS: John source16 operation native-tomahawk-fund-v2
committed with same-session restore; ledger5->6/Tomahawk0->1, carrier165rev0
active/guidCaptured/funded1/observed1, two firearm copies and five melee intact.
Next exactly one throw into clear ground away from both players; do not approach
or pick up projectile. Verify observer decrease and durable ledger7/Tomahawk0
before testing spent carrier release. Pickup recovery remains out of scope.

2026-10-18 live unthrown release/unfund PASS: John source16 original operation
native-tomahawk-unfund-v1 committed; server PASS loose-ammo/character-ledger/fresh
same-session restore. Ledger4->5/Tomahawk1->0; carrier165rev0 empty/funded0/
observed0/guidCaptured=false. Two firearm copies and five melee160..164rev0 active,
no closing/pending/frozen state. Targeted ammo reduction fixes prior setter issue.
Loose count not independently displayed; expected return follows confirmed commit.
Next separately keyed +1 refunding and verify ledger6/quantity1 before one throw.
Throw consumption/spent cleanup/pickup remain unaccepted.

2026-10-18 live unthrown cleanup diagnosis: source15 exact GUID/model removal
passed (present=false), but absolute ammo setter left quantity1; retained with
throwable_cleanup_pool_reset_unconfirmed, seal ledger4/balance1, no economic
unfund commit. Existing CharacterAmmoNative.Restore already documents setter
reduction limitation. Reused its targeted removal native0xB6CFEC32E3742779 with
reason0xA07362E6 for exactly one Tomahawk, only after sealed exact GUID absence.
No global ammo reset/clip changes/repeated remove. Tests disallow zero absolute
setter, verify retained-pool reduction and failed reduction/no retry;162 Weapons
Lua/runtime syntax PASS. Deploy only client/native_throwable_adapter.lua; full
John quit and observer prepare-stop before restart; current ID/status then same
unfund operation key. Live successful unfunding still pending.

2026-10-18 live unthrown unfund FAILED before economic commit: source13 release
refused, throwable_cleanup_unconfirmed, sealed ledger4/Tomahawk1, carrier165
retained and siblings not removed. No return payment accepted. Found cleanup code
assumed exact inventory removal also clears separate native ammo pool. Added
post-removal exact GUID/model absence requirement, then sealed-owner Tomahawk-only
pool retirement to0 with full unrelated-pool readback preservation. No ledger
consumption/credit or extra remove retry. Added branch-specific cleanup diagnostics
and retained reasons; actual live failing branch still unproven until retest.
Native-removal-leaves-pool1 regression +162 Weapons Lua PASS. Deploy same two
throwable client files after full John quit/observer prepared stop. Reconnect
must restore paid balance1; retry original unfund operation only after active
restoration/current source confirmed. Throw/pickup still prohibited.

2026-10-18 user confirms funded regular Tomahawk selectable and drawable after
GUID inventory fix; John current source13. No throw reported. Next unthrown -1
released-owner funding transition should return one loose unit, advance ledger4
to5/Tomahawk0 and rebuild carrier165 empty with melee/firearm siblings intact.
Exact unthrown removal/economic return still pending live evidence.

2026-10-18 live funded restore after carried-GUID fix PASS: John session
197939f6-cb49-11f1-9ad4-e0d55eaa2deb epoch ending1792365038:54446624:2,
carrier165rev0 active/guidCaptured=true/funded1/observed1, ledger4/Tomahawk1,
two firearm copies and five melee160..164rev0 active, no pending/closing/frozen
state. Restored existing paid balance; no second funding needed. Current source
ID not supplied after reconnect. Wheel selection, unthrown release and throwing
remain pending; next confirm current source and selectable carrier without throw.

2026-10-18 live diagnostic: carrier165 native present=true/quantity1, but no
attach-point entity/GUID observed; owner retains/frozen as intended. Compared
archived tested throwable GUID hierarchy (native semantics only, no legacy runtime
or item escrow restored). Added carried-inventory GUID resolution through exact
CHARACTER/CARRIED_WEAPONS and WEAPON_0/1 slots: require absence before native give,
unique exact GUID/model independent inventory readback afterward. Hidden carrier
may bind entity0 only with explicit inventoryOnly approval; removal still uses
captured GUID, not hash/global cleanup. Hidden inventory success/exact cleanup,
unresolved timeout and ambiguous GUID retention regressions pass. 162 Weapons
Lua/runtime syntax PASS. Live fix pending; balance already funded, never pay again.
Deploy client/native_throwable_adapter.lua and native_throwable_owner.lua with
John fully quit; prepare-stop observer before Weapons restart; reconnect to same
durable ledger4/balance1 and capture status. No throw/pickup yet.

2026-10-18 server evidence confirms funding COMMIT and RecoveryStatus ledger4
(prior3), carrier165rev0 retained in recovery roster, economicReplay=false.
Do not fund again. Added bounded client creation diagnostics separating native
pool readback, foreign pool changes, context loss, multiple entities, GUID capture/
change and absent entity/GUID timeout; exact reason propagates into retained owner
status. Hidden-entity timeout regression proves single grant/setter/no cleanup or
retry. 162 Weapons Lua PASS. Diagnostic-only patch is NOT a materialization fix.
Next deploy two client throwable files with John fully quit, then fresh login
restores already durable balance (no new funding) and capture precise refusal.

2026-10-18 first live funded materialization FAILED safely retained: John source11
fresh epoch fd55b2a0-cb46-11f1-9ad4-e0d55eaa2deb:1792364290:53698776:3,
fault throwable_creation_unconfirmed; carrier165rev0 fundedQuantity1,
observedQuantity1/guidCaptured=false, reason throwable_funded_creation_unconfirmed;
parent frozen/quiescing, zero firearm copies. Native creation/readback/GUID branch
not distinguished by current diagnostic. Funding commit not confirmed by this
client output alone; request server RecoveryStatus and funding console result.
Do not retry payment, issue replacement, throw/pickup or force cleanup. Positive
funded/native gate remains unaccepted; exact failing branch requires diagnosis.

2026-10-18 live fixed loose Tomahawk budget/replay PASS after callable fix:
Jane source10, John source11. Receipt native-tomahawk-loose-budget-v1 delivered
quantity2 regular ammo definition93, instanceIds166/167, inventory5; exact replay
returned same delivery/replayed=true. Budget flag reset0. Carrier165 funding/native
materialization still pending. Next reserved +1 funding with stable operation ID;
verify active funded carrier and unchanged observer before any throw.

2026-10-18 live budget blocked before transaction: grants_once.lua called absent
global IsCallable. No budget delivered. Fixed with local CFX-aware callable check;
audited/fixed identical dependency in character_ammunition.lua funding primitive.
Budget and funding tests now explicitly run with IsCallable=nil; Inventory full
Lua/64 syntax PASS. Deploy both Inventory files after prepared drain/client exit
and restart resources; re-establish current IDs before repeating fixed budget.
Budget/funded native gates remain pending, not accepted.

2026-10-18 live unfunded carrier activation PASS: John source9, item165rev0
assigned/empty, fundedQuantity0/observedQuantity0/guidCaptured=false,
pickupCredits=false; fresh epoch ending1792363733:53141223:3 active/not busy,
ledger3/Tomahawk0, two firearm copies and all five melee remain active. This
confirms zero-funded activation, not positive native materialization/throwing.
Next fixed two-unit loose budget grant/replay, then separately reserved +1 funding.

2026-10-18 live regular Tomahawk issuance/replay PASS: John source9 received
item165rev0, serial FW-TOMA-6AD54C85-93A9E7-0001, provenance event22,
request native-tomahawk-alpha-v1; repeat returned same identity/replayed=true.
Schema2 pristine carrier has character-owned regular ammo type, no item quantity
or maintenance. Issuance flag reset0. Equip/funding/native throw not tested yet.
Next: assign weapon_throwable while ledger balance0 and verify empty/no grant.

2026-10-18 user-confirmed enabled registry restart: ThrowableStatus loaded/
enabled=true, convar1, missing empty. Jane source8 active ledger35/repeater1,
Tomahawk0; John source9 active ledger3/all pools0 including Tomahawk, five
melee160..164rev0/GUID captured, two firearm copies. Both fresh epochs and no
pending/closing flags. No carrier issued or funded yet. Next exact regular
Tomahawk issuance/replay with stable native-tomahawk-alpha-v1 key; no throw.

2026-10-18 user-confirmed deployed disabled-path baseline: Jane source8 active,
two firearms112rev2/134rev8 and ledger35/repeater1 unchanged; John source9 active,
firearms155rev3/158rev5 and ledger3/all pools0 unchanged, five melee160..164rev0
active/GUID captured. ThrowableStatus loaded=true, all config gates true,
convar0/enabled=false, sole missing gate feather_native_throwable. No throwable
issued/funded/native-tested yet. Next: PrepareStopAll while flag remains0; only
after aggregate PASS set replicated throwable flag1 and restart Weapons to build
fresh 28-pool registries for both owners. Verify active status before issuance.

2026-10-18 controlled live-gate preparation complete (not live acceptance):
WeaponNativeThrowableStatus is console-only/read-only and reports module/config/
convar/exact catalog readiness, ceiling1, rebuild funding and no pickup credits.
InvNativeThrowableBudget uses existing GrantOnce delivery, private fixed scope:
John UUID4560a489-ca6c-11f1-9ad4-e0d55eaa2deb, two loose regular Tomahawk units,
fixed native-tomahawk-loose-budget-v1 receipt, separate default-off
feather_native_throwable_budget convar. Receipt replay never replenishes spent
stacks; malformed receipt, failed receipt write or session loss refuses/rolls back.
No carrier/equipment/carried-ammo/native grant or enrollment in budget command.
162 Weapons Lua/runtime syntax +7 Node; Inventory full Lua/64 syntax +2 Node PASS.
Next manual step: prepared drain, disconnect clients before Inventory restart,
deploy both resources, server-console refresh, restart/rejoin, report current IDs
and read-only WeaponNativeThrowableStatus plus both clients' status/maintenance.
Keep throwable runtime, issuance and budget flags zero for this baseline. Do not
throw or pick up projectiles until the bounded funded gate is explicitly staged.

2026-10-18 funded composition regressions: actual Inventory export, empty final-
wear plan, assigned-carrier reader and canonical funding/observation/receipt SQL
bodies run together against a mocked transactional database. Fund/unfund/spend,
CAS/receipt/authority/assignment rollback, overfill, stale lost-reply retry and
reused-receipt replenishment refusal pass; unrelated repeater balance preserved.
Actual equipment UI event/options/unequip/rebuild roundtrip also passes. Client
session now covers unfunded carrier (zero native grants) plus funded/spent/death
cleanup. Found/fixed server generic Transfer bypass: regular Tomahawk transfers
are refused server-side as well as client-side; only released funding is allowed.
161 Weapons Lua/runtime syntax +7 Node, Inventory full Lua/64 syntax +2 Node PASS.
This is automatic composition evidence, not live CFX/native/SQL contention proof.
Next: controlled live-gate diagnostics/funding-budget preparation; no live test
or server deployment yet. Keep throwable flag zero; eventual manifest deployment
requires server-console refresh before resource restart.

2026-10-18 exact regular-Tomahawk carrier issuance/metadata now gated through
canonical durable issuance receipts; no quantity in metadata, maintenance, native
grant, equipment assignment or ammunition grant. Issuance regressions cover
disabled/replay/variant/loaded-ammo refusal. Equipment UI options now resolve the
owned carrier's exact throwable slot through server preflight. Funding remains
console-only (no generic in-place ammo UI bypass). Normal manifest now lists both
shared and both client throwable modules; actual server/client graph loads with
flag zero, so loading alone does not admit throwables. 161 Weapons Lua specs,
runtime syntax and 7 Node tests pass. Expanded UI/funded end-to-end composition
and live native acceptance remain pending; keep feather_native_throwable=0.
Do not deploy for testing yet. When deploying these new manifest entries later,
run server-console refresh before restarting Weapons.

2026-10-18 funding coordinator integration staged: server-console-only bounded
funding intent (+1/-1, stable operation ID) uses exact released reservation;
post-seal ledger snapshot avoids stale preflight balances. Trusted Inventory
export composes final firearm wear and canonical ammo funding in one transaction,
then existing coordinator performs fresh same-session rebuild. Tests cover exact
ticket/payload, release ordering and rollback on funding/authority refusal.
161 Weapons Lua/runtime syntax +7 Node and Inventory full Lua/64 syntax PASS.
No live acceptance/deployment yet; throwable remains default-off and new modules
remain outside manifest. Next: issuance/UI/composition and end-to-end test gate.

2026-10-18 staged internal throwable funding primitive: exact assigned carrier,
metadata/full equipment snapshot and ledger revision/full pools are checked under
the caller-owned transaction and released-authority callback. Reuses canonical
CharacterAmmunitionAPI.Apply (loose-ammo debit/credit, ledger CAS and durable
receipt), with post-mutation authority failure returned for transaction rollback.
Inventory full Lua suite/64 runtime syntax PASS, including new primitive tests.
Not exported or activated: funding coordinator/transaction composition, public
issuance/UI and manifest integration remain next; throwable flag stays off.

2026-10-18 runtime/equipment follow-up: optional gated registry extension, exact
funded limits recompilation, matching child/main ledger snapshot, same server
lease/private activation bundle and recovery carrier revision wired. Existing
coordinator supports carrier equip/unequip with release/final wear/exact reservation/
fresh restore; trusted Inventory export commits wear+assignment atomically and
generic assignment bypass is blocked.161 Weapons Lua/runtime syntax+7 Node and
full Inventory Lua/64 syntax+2 Node checks PASS. All native/SQL behavior remains
mocked for this slice. Modules not manifest-loaded; keep throwable flag disabled.
Canonical funding release/rebuild, issuance/UI and normal manifest composition
remain pending before deployment/live tests. No grants/migrations requested.

2026-10-18 server-binding follow-up: internal Inventory throwable reader/apply
reuses existing full equipment CAS/guards. Exact regular carrier and character-
owned ammo type only; no item quantities/maintenance. Atomic runtime snapshot
combines locked carrier with same ledger revision/private pools under default-off
flag and explicit limit1. Existing server loadout lease optional throwable binding
guards full carrier row independently of valid balance/revision changes.
159 Weapons Lua/runtime syntax+7 Node and full Inventory Lua/64 syntax+2 Node
checks PASS. Runtime activation/public equipment/funding/issuance/UI integration
still pending; keep throwable flag disabled, no server deployment/live test.

2026-10-18 session follow-up: optional authoritative throwable snapshot is bound
to runtime full-pool balances/revision. Same concrete parent lease creates one
child before pool restoration; only funded Tomahawk delta is allowed during
creation. Actual existing controller handles observations/seal/cleanup ack; child
must release under exact sealed baseline before parent setup closure/ack. Death
recovery uses this barrier; unresolved child cannot emergency-close. Direct active
Tomahawk transfers refuse pending controlled release/rebuild funding route.
158 Lua/runtime syntax+7 Node checks PASS including actual controller/session and
concrete parent-factory binding. Not manifest-admitted; server/Inventory snapshot/
lease/funding/issuance/UI composition remains pending. No server update/live test.

2026-10-18 concrete port follow-up: native_throwable_adapter.Scoped remains inert,
outside manifest. Preserves zero-count native carrier grant, then only approved
AMMO_TOMAHAWK pool=1; checks every registered pool before/after. No clips/global
resets or forced selection. Captures exact GUID; owned unthrown cleanup verifies
native inventory GUID+model before targeted removal. Spent proof requires captured
entry absent/model absent/count0/no visible match, never deletes projectile or
credits pickup. Still-present spent entry fails closed.156 Lua/runtime syntax+7
Node checks PASS, with mocked buffer decoding/native readbacks; not live engine
proof. Session/server/Inventory/payment/issuance/UI integration remains pending.
No server deployment/manual test/grants requested yet.

2026-10-18 owner follow-up: client/native_throwable_owner.lua is inert/injected,
not manifest-loaded. Creates at most one approved funded native copy with GUID
readback; zero-funded carrier never grants. Observation decreases only, with
native increases retained/no pickup credit. Cleanup requires exact current sealed
ledger identity/count/revision, not an unverified boolean. Unthrown captured copy
uses exact removal; spent adapter must prove captured native inventory entry left
ped without deleting/crediting world projectile. Unknown outcomes retain/no retry.
155 Lua specs PASS including stale-seal, post-grant exception, native increase,
readback failure, spent proof, zero grant and cleanup failure under mocks.
Concrete native ports/throw detection/controller/server/Inventory/UI wiring remain
pending; no live throwing/cleanup claims or server deployment requested.

2026-10-18 carrier follow-up: strict native_throwable_item metadata and saved-
assignment projection implemented, not manifest/publicly admitted. Item stores
only selected ammo type/character ownership, never quantity/loaded/reserve or
maintenance. Projection binds full equipment assignment IDs/revisions, character/
session/epoch, exact private carrier row, independent ledger revision/0-or-1
funding. Zero funding means no native copy requested, not an automatic grant.
154 Lua specs/runtime syntax+7 Node checks PASS. Native creation/throw depletion/
sealed cleanup, reservation/payment, issuance/UI integration remain pending.
No Inventory/config/schema/grants/server deployment changes for this step.

2026-10-18: inert policy preview only, not manifest-loaded or publicly admitted.
Authoritative planning: framework Weapons expansion master/remaining-work docs.

Reuse earlier evidence in throwing-knife-multi-ammo.md and five-throwable-slots.md
for established names, native models, wheel behavior and lifecycle findings.
Do not restore item-owned ammo escrow, old runtime providers or data conversion.
Improved variants remain excluded. Pickup increases are not economic credits.

First candidate: regular Tomahawk, weapon_thrown_tomahawk, AMMO_TOMAHAWK and
existing weapon_throwable slot. First controlled test ceiling is1 funded unit,
not a revised engine maximum (catalog maximum3 unchanged). Candidate registry
uses the existing character-ammo contract and does not mutate the firearm registry.
No grants, native mutations, receipts, new storage/schema or second ledger.

153 Lua specs/runtime syntax and7 Node tests PASS. New tests use existing
Transfer/Observe for inventory-funded1->consumed0, same-firearm balances and
stale/foreign/incomplete/native-increase/alias refusal. This is mocked/pure
contract acceptance, not native throwing/pickup behavior.

Pending: native-only carrier metadata, exact owned native copy/session cleanup,
canonical transfer/observation integration and default-off admission before live
tests. Pickup attribution/credits are separate, not inferred from old native
recovery behavior. No server update or manual test requested yet.
