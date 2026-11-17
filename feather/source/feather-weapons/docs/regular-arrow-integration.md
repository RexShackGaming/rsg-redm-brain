# Regular arrows: current-runtime integration, 2026-11-16

Implemented, locally tested and live accepted on Jane in the shoulder slot.

The September 30 special-weapon checkpoint in the framework Weapons plan already
records standard Bow and Regular/Small Game/Poison/Fire/Dynamite arrow validation.
Improved Arrows failed native pool readback and remain excluded. Do not repeat
that broad compatibility matrix. This pass ports only Regular arrows to the
current GUID-owned weapon, character-ledger and bounded quantity-recovery path.

The historical 40-Regular-arrow definition ceiling is retained. The bow is a
serialized owned longgun; `ammo_arrow_regular` / `AMMO_ARROW` is a character pool.
`setr feather_regular_arrows 1` is required on both server and clients, in addition
to the existing native runtime/transport/lifecycle gates. It defaults off.
Bow shop price is $5 (user approved); existing five-arrow boxes remain $0.50.
Specialty arrow offers are hidden during this admission and specialty types are
not registered for loading or metadata selection. Existing item keys and rows
are preserved. No automatic old-bow conversion, refunds or fixture grants.

An observed funded arrow reduction records an allowance in the same transaction
as its debit. Recovery uses the existing 180-second, 50-metre, same-bucket rule,
with a separate `regular-arrow-quantity-allowance-v1` receipt namespace. An arrow
claim cannot consume a Tomahawk allowance. Current equipped bow and unchanged
equipment lease are required before an arrow claim is dispatched. Pickup credits
the saved quantity only; the already-owned bow remains, with no extra native
ammo grant. Partial rejection removes only rejected provisional units. Other
firearm reductions and subsequent native pickups are retained. SQL uncertainty
stays fail-closed without automatic mutation retries.

Source review: build 1491.50 MP `short_update.ysc.c` function1455 explicitly treats
bow ammunition separately from firearm clips; MP `fm_mission_controller.ysc.c`
function981 recognizes `pickup_ammo_arrow` as an ammunition pickup. These support
ammo classification, not exact origin/ownership proof. Original archived resource
code and September acceptance preserve the earlier bow behavior. New GUID creation,
cleanup and ledger recovery integration passed the focused live gate below on
November16; the exact result and remaining scope are recorded at the end.

Known limits: one increased ammunition type per sample/claim; simultaneous arrow
and Tomahawk increases fail closed. Recovering without an equipped owned bow is
refused; native pickup never issues a bow. World arrows may despawn naturally.
Own/batched/cross-player recovery, recovered-arrow reselection/draw, loaded
death/revive and resource restoration, both corrected carry positions, and the
40-arrow capacity/headroom checks are live accepted. Competing-collector races
remain modeled rather than live tested. No physical quiver is introduced.

Local verification: 309 Weapons Lua suites plus syntax, 7 Weapons JavaScript
checks, full Inventory Lua runner including real observation/recovery primitives,
and 44 Shops composition scenarios pass. New tests cover policy/default-off,
owned bow slots, type reservations, partial rejection, exact session cleanup,
current equipment lease, type-separated SQL allowances and atomic rollback.
Windows PowerShell 5.1 installer fixtures pass exact copies, stopped gate,
reviewed baselines, payload hashes, backups/idempotence and scoped $5 Bow price
changes while retaining operator config, BOM/CRLF and acceptance evidence.

Initial package: `C:\coding\deployments\regular-arrows-2026-11-16`.
It installs 15 existing runtime files across Weapons, Inventory and Shops and
patches only the Bow price in Weapons shop_config.lua. No manifests, SQL schema,
images, test fixtures or resource config files are replaced. No refresh is needed.
The subsequent four-file Bow placement correction is packaged separately at
`C:\coding\deployments\bow-placement-2026-11-16`; both batches were live tested.
These historical test packages predate the final version-only release bumps.

Live gate (Jane only): orderly PrepareStopAll/aggregate PASS, disconnect, stop
Shops/Weapons/Inventory, install, enable replicated flag, start Inventory/Weapons/
Shops. Buy the current $5 Bow and one $0.50 five-arrow box; equip shoulder/back,
load5, shoot once into nearby clear ground, wait for saved/native4, then walk over
the arrow within180seconds and50metres. Expect saved/native5 and one arrow ledger
acknowledgement without a bow/ammo grant. Verify unload returns5 loose arrows,
reload5, Return to Selection/reselect, loaded5/draw, and unchanged Tomahawk balance.
Stop and report the first refusal; do not buy/replay to repair it. Broad historic
arrow-type tests and John are not required for this first integration gate.

Persist `setr feather_regular_arrows 1` before resource startup in the server's
existing startup configuration while this feature is in use. Do not remove a
funded pool from the policy by disabling the flag: disabling is not a migration.
No agent commits, pushes or PR changes were performed.

2026-11-16 Regular-arrow integration LIVE PASS (Jane, shoulder slot). User reports all posted manual checks passed and supplied screenshot of holstered Bow in the selected shoulder position. Paid Bow and five-arrow box purchases fulfilled. F8 Regular-arrow saved/native5 revision63 -> fired4 revision64 -> native pickup PASS, no bow/ammo grant, saved/native5 revision65. User confirms exact unload/reload, reselection persistence and draw checks passed; post-reselection arrow status was not separately pasted. Tomahawk saved/native3 remained unchanged, revision62 initially and67 after unload/reload/reselection. Shared ledger revisions65->67 are consistent with the two ammo transfers; do not infer additional arrow sample output. This accepts the focused current-runtime paid Bow/Regular-arrow integration in the shoulder slot, not the untested back-slot visual, cross-player arrow recovery, live concurrency or specialty-arrow expansion. Historical September30 compatibility matrix remains separate accepted evidence. No further deployment or commands required merely to record this result. User handles commits/pushes/PRs.

2026-11-16 Jane multiple-outstanding/batched Regular-arrow recovery LIVE PASS. F8 active saved/native5 revision67 -> three fired arrows -> saved/native2 revision70 -> native pickup acknowledgements71 and72 -> active saved/native5 revision72. Three units recovered in two acknowledgements establishes at least one multi-unit credit; exact batch sizes/order were not logged. Tomahawk saved/native3 remained unchanged at shared revision72, guidCapturedtrue/pickupAllowedfalse. No bow/native ammo grant reported. This accepts three outstanding funded arrow allowances and batched own recovery on Jane; it does not establish cross-player arrow recovery or live SQL contention. No deployment/config/restart needed for this recorded gate. Next focused checks: loaded-arrow death/revive and prepared resource restart, then back-slot visual. John not needed for those checks.

2026-11-16 Jane loaded-Regular-arrow DEATH/ADMIN-REVIVE and RESOURCE-RESTART RESTORE LIVE PASS. Attached F8 trace begins active arrows5/Tomahawks3 revision72. Medical dead revision5; native runtime/session/ammunition sealed (not frozen), deathClosing/closingtrue,2ownedcopies, belt arrows5/Tomahawks3/revolver100 revision72. Server confirms death final wear persisted changes1 medicalRevision5 and final ammo seal acknowledged; no item-specific wear breakdown supplied. Medical alive revision6; fresh epoch ending1794870122:148430403:4 restores ACTIVE idle,2copies, five melee records, arrows5/Tomahawks3/revolver100 revision72 and closing/deathClosingfalse. Later resource-stop cleanup PASS no tracked copies remain, scoped native startup and fresh epoch ending1794870284:148592835:1 restore ACTIVE idle2copies, same belt at revision72; short F8 statuses independently confirm arrows5/Tomahawks3. These supplied states accept death seal/revive and post-resource-restart restoration without ammo quantity/revision churn. Aggregate PrepareStopAll/ShutdownStatus and Shops smoke outputs, and explicit post-revive/post-restart bow-draw confirmation, were not separately pasted; do not invent those outputs. No crash/unprepared restart or cross-player arrow acceptance implied. No deployment needed to record result. Next remaining focused check is back-slot placement; bow draw confirmation can accompany that check. User handles commits/pushes/PRs.

2026-11-16 Jane back-slot test: persistence/balances PASS, distinct holster placement NOT accepted. User reports holstered position unchanged after selecting Back; supplied screenshot shows the same low across-back Bow pose as the prior Shoulder screenshot. Before reselection native ACTIVE idle2copies, arrows5/Tomahawks3/revolver100 at revision72, fresh epoch ending1794870470:148778974:3. After Return to Selection/reselection, short F8 statuses remain ACTIVE arrows5/Tomahawks3 revision72. No ammunition loss/duplication or frozen state shown. Source mapping still distinguishes Shoulder point10 and Back point9 and passes that point into GUID options. This alone does not establish that the engine visually differentiates Bow holsters or prove a saved/native slot mismatch. Do not claim separate visual placement PASS or an engine limitation without further evidence; no forced attach/offset workaround applied. Existing weaponNativeEntityStatus requires DevMode and is not requested for the release-config test. Explicit bow draw confirmation was not separately supplied. No new runtime changes/deployment needed to record result; distinct Bow holster rendering remains an open presentation issue. User handles commits/pushes/PRs.

2026-11-16 Bow placement correction IMPLEMENTED / LOCAL PASS; LIVE PENDING. User clarified original runtime had correct placement, then corrected the previously attached back screenshot: the actual Back pose is diagonal and differs from Shoulder but remains misplaced. Supersedes the earlier same-image/no-distinct-pose inference; ammunition/persistence results unchanged. Original archived client grant uses engine-default attach point0 for longguns rather than forcibly applying9/10. Build1491.50 MP weapon_locker.ysc.c func103 explicitly maps Bow index0->8,index1->7 versus two-handed firearm10/9; its callers use those values with GET_PED_WEAPON_GUID_AT_ATTACH_POINT. Current character-ledger integration incorrectly mapped Bow to rifle carry points10/9. Corrected owned Bow logical Shoulder->8, Back->7 in materialization and strict preflight; GUID creation/options admit bow7/8 while refusing rifle-point bows/bow-point firearms. Exact GUID identity/representation and maintenance/cleanup scans now include7/8. No model grant fallback, manual entity offsets, ammo/economic writes or change to firearm carry mapping. Weapons309 Lua suites+syntax and7JS PASS including real GUID creation/settle/capture/removal with modeled Bow points7/8. Four-file Weapons-only package C:/coding/deployments/bow-placement-2026-11-16 validated under Windows PowerShell5.1 for original arrow-deployed baselines, hashes, backups/idempotence, BOM/CRLF/config/evidence preservation. Required runtime paths: shared/character_ammunition_item.lua, shared/character_ammunition_materialization.lua, client/character_ammunition_creation_native.lua, client/character_maintenance_native.lua. No manifest, configuration, Inventory, Shops runtime or database changes; no refresh required. Orderly PrepareStopAll/aggregate PASS, stop Shops/Weapons, install, ensure Weapons/Shops. Focused Jane live gate pending: Back/Shoulder draw/holster visual, reselection and saved/native arrows5/Tomahawks3 unchanged. No agent commit/push/PR operations. Full installation/testing steps posted in chat.

2026-11-16 Bow carry-point correction LIVE PASS. User confirms both Shoulder and Back positions look correct after four-file installation and reselection. Supplied trace shows orderly client stop cleanup PASS, resource startup, Return to Selection/reselection and fresh active session a35563c1-e215-11f1-9a69-e0d55eaa2deb / epoch ending1794871815:150123262:4. Native ACTIVE idle/nonquiescing/nonreceiving,2ownedcopies, five GUID-captured melee items; arrow saved/native5, Tomahawk saved/native3/pickupAllowedfalse, revolver100, shared ledger72 unchanged. This accepts Bow-specific Shoulder8/Back7 visual placement and reselection restoration without ammo loss/duplication; no screenshots or explicit new draw statement supplied in this result, so retain prior draw evidence separately. Previous incorrect rifle10/9 Bow mapping is corrected. No further deployment or commands needed for placement gate. Remaining arrow work includes cross-player live recovery and live contention; specialty expansion remains deferred. User handles commits/pushes/PRs.

2026-11-16 Regular-arrow CROSS-PLAYER LIVE PASS (sequential operator control). John prepared with owned equipped Bow, active arrow saved/native0 revision10. Jane active5rev72 fired once and settled4rev73; repeated final sample remained4rev73. John native collection logged WeaponRegularArrowPickup PASS ledger acknowledged revision11; no bow or ammo grant, and active saved/native1rev11. Combined saved quantities conserved5 (Jane4+John1). This accepts one paid regular arrow recovered by a different equipped-bow character through the normal bounded quantity path, without simultaneous operator actions or experimental commands. It does not establish live competing-collector races, no-bow collection behavior or specialty conversion. No new deployment/configuration or grants required for this result. Current known arrows Jane4rev73 / John1rev11. User handles commits/pushes/PRs.

2026-11-16 John recovered-Regular-arrow RESELECTION/DRAW LIVE PASS. User confirms all requested checks passed: Return to Selection, reselect John, recovered arrow saved/native1 remains and bow can be drawn. Last supplied John ledger revision11; no new numerical revision output was pasted for this confirmation. Together with Jane4rev73 / John1rev11 transfer evidence, accepts recovered cross-player arrow persistence and usability under current owned-Bow runtime. No new deployment/config/restart needed. Live competing-collector contention and arrow capacity/overflow remain distinct unaccepted gates; specialty expansion deferred. User handles commits/pushes/PRs.

2026-11-16 Jane Regular-arrow CAPACITY/UI/RESELECTION LIVE PASS. User confirms all posted manual checks passed. Supplied F8 active saved/native4 revision73; four Shops purchase fulfillments; load36 -> active saved/native40 revision74. User confirmation covers loose stock still available, Load disabled at40 with capacity reason/no loose loss, unload1 ->39 and one loose returned/Load enabled, reload1 ->40/Load disabled, plus bow draw. Intermediate39 sample/loose counts were not separately pasted. Return to Selection/reselect supplies active saved/native40 revision76; Tomahawk saved/native3 GUID captured/pickupAllowedfalse at shared76. Revision74->76 is consistent with the two transfers. This accepts the40-arrow loaded ceiling, UI headroom behavior, exact one-unit unload/reload and full-capacity reselection persistence. It does not prove native world-pickup overflow behavior at full40, live competing-collector contention or specialty arrows. No additional deployment/config/restart required to record result. Latest known Jane arrows40/Tomahawks3 rev76; last known John arrows1 rev11 (reselection/draw user-confirmed). User handles commits/pushes/PRs.

2026-11-16 Jane full-capacity native-arrow/headroom recovery LIVE RESULT accepted within supplied evidence. Initial active saved/native40rev76; after unload1/fire1/load2 sequence user supplies active saved/native40rev79. User then tried unloading1 while very close to the grounded arrow; native pickup PASS ledger acknowledged81, no bow/ammo grant. Final active idle2copies, saved/native arrows40, Tomahawks3/pickupAllowedfalse, revolver100, ledger81; no frozen/pending/closing state. Revision79->81 and proximity report are consistent with unload1 at80 immediately followed by native recovery at81; intermediate39/native sample and explicit at-capacity world observation were not pasted. Do not label the immediate refill an unload failure or infer duplicate grant. Evidence accepts no over-cap credited balance/freeze in this run and recovery as headroom becomes available, with other pools unchanged. Precise native event timing/at-capacity world-retention readback remains inferred rather than separately measured. No repeat, deployment or repair required on this evidence. Current Jane40arrows/3Tomahawks/100revolver rev81. User handles commits/pushes/PRs.
