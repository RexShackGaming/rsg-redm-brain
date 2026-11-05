# Combined final wear and attachment payment — scoped live gate accepted

Permanent composed regression added to Inventory's explicit Lua runner: actual
CommitNativeAttachmentTransition export, NativeLifecycleWear, NativeRepairCommit
and NativeAttachmentCommit bodies execute together against mocked transactional
storage with14-digit JSON wear rounding. Changed install and changed removal both
save wear and attachment with two CAS revisions/one payment. Payment refusal,
return-capacity refusal, second CAS conflict and post-payment authority loss roll
back the whole mocked transaction; original reservation remains unchanged.
Full Inventory runner passes. This closes an offline composition coverage gap,
not live MariaDB failure/crash/multiplayer acceptance. No new runtime deployment,
grants, flag changes or repeat live tests required. Accepted baseline retained.

Post-acceptance cleanup implemented locally: temporary AttachmentWearFixture
owner method, F8 command and disposable helper-specific test removed. No runtime
fixture flag reads remain. Historical helper instructions below are retired.
Added permanent coordinator refusal regression: bounded provider diagnostics,
private status snapshots, malformed diagnostic fields, frozen no retry/rebuild.
Server coordinator Status now returns copied commitRefusal code/message (no item
metadata). Inventory atomic export regression expanded for attachment refusal after
wear and post-payment authority loss, both rolling back wear/payment together in
the mocked transaction. All113 Weapons Lua/7Node plus Inventory Lua runner pass.
Live accepted state unchanged; no new failure/multiplayer live acceptance claimed.
Next batched Weapons-only deployment: client/character_ammunition_native_owner.lua,
client/character_ammunition_startup.lua, server/services/native_equipment_transition.lua.
No Inventory runtime files/config/manifest changes or repeated live test needed.
Server still has disabled old helper until these files are copied/restarted;
keep fixture flag0. Use accepted PrepareStop PASS/stop/copy/ensure workflow when
deploying, not an unnecessary immediate restart for this documentation update.

Post-gate runtime baseline confirmed: ACTIVE/idle/nonquiescing/notreceiving,
ownedCopies1/sessioncopies1, epoch5122423:1/same13d8d3d6-c8e7-11f1-9ad4-e0d55eaa2deb
session/ped108546; ledger33/all27pools0/no pending/closing/deathClosing. Runtime
restoration complete. Last canonical evidence112rev1 pristine,135rev11/dirt≈0.2/
empty attachments/material1 retained; one-copy status does not independently
identify the item. Fixture flag0 explicitly logged earlier; three attachment flags
instructed0 without independent readback. Temporary helper source removal remains
local cleanup next, not another live proof gate.

LIVE unchanged-wear REMOVE/RETURN ACCEPTED: fixture flag explicitly set0;
Inventory COMMITcd6847ae-bb37-4106-9900-ba0f3bf4c4cb:1057/23queries followed by
AttachmentChange PASS fresh same-session restore/no ammo economic writes.
Independent status135rev11/attachments empty/material1, shoulder assignment and
112rev1 preserved; fresh epoch4964606:3/same13d8d3d6-c8e7-11f1-9ad4-e0d55eaa2deb
session. Native maintenance135rev11/dirt0.20000000298023/otherwear0 and112rev1/
allwear0. Combined changed-wear install + retained-wear removal gate COMPLETE.
No second changed-wear removal input, failure/race/multiplayer acceptance inferred.
Primary-only restoration, three attachment flag shutdown and helper source cleanup
remain next; no reset/heal/grant or repeat proof required. Historical pending
entries below describe progression, not reopened gates.

LIVE combined INSTALL ACCEPTED: helper135rev8/native dirt≈0.2/no SQL/ammo/material
writes at epoch4572108:1. Inventory COMMITcd6847ae-bb37-4106-9900-ba0f3bf4c4cb:1005
(24queries) then AttachmentChange PASS. Independent status135rev10/saved wide sight/
material0/same shoulder assignment; fresh epoch4757241:2/session13d8d3d6-c8e7-11f1-
9ad4-e0d55eaa2deb. Native maintenance135rev10/dirt0.20000000298023/all other wear0;
112rev1/allwear0 unchanged. ACTIVEidle/copies2/ledger33/all27ammo0/no pending or
closing. Accepts changed-wear + attachment install atomic composition and fresh
reconstruction after precision fix. Unchanged-wear removal/return still pending;
expect135rev11/dirt preserved/material1. Disable fixture input now, no reinjection.
Does not accept changed-wear removal, multiplayer/failure/live unknown commit cases.

Live combined attempt REFUSED equipment_commit_refused/commitOutcome=refused/
committed=false; subsequent active-only readers unavailable. No combined acceptance.
Underlying provider reason was discarded. Local reproduction found native dirt
0.20000000298023224 vs JSON reread0.20000000298023 fails Inventory attachment
locked metadata equality after wear CAS. New regression failed before fix/pass
after fix: only five bounded unit wear fields permit1e-12 persisted-read roundoff;
requested before/after attachment-only delta remains exact. Real dirt mismatch
still refuses. Added bounded provider refusal logging in Weapons; live cause is
consistent but not conclusively identified without the original provider message.
Inventory full Lua runner and113 Weapons Lua specs pass. Recovery requires fresh
session/last durable snapshot, not retrying retained frozen transition. Disable
fixture while recovering; verify durable revision/material/native wear before
another controlled input. Do not manually reset SQL or presume partial commit.
Deployment: Inventory server/services/native_attachment_commit.lua and Weapons
server/services/native_equipment_transition.lua. Existing files/no manifest delta.

Baseline correction: user performed a pristine install/remove before dirt input.
Confirmed135rev8/empty attachments/material1/allwear0 and112rev1/allwear0 at
epoch3437746:4/session84bbcefc-c8e3-11f1-9ad4-e0d55eaa2deb. No SQL reset,
material grant or heal needed. Temporary helper now binds exact revision8;
previous revision6 guard is superseded. Deploy only native_owner.lua as below.

2026-10-15: scoped pristine UI install/remove remains accepted; do not repeat
its native proof matrix. This gate adds a changed final-wear sample to installation.
The actual coordinator test now uses the real maintenance/lifecycle planner,
verifies changed install and changed removal preserve dirt and advance two target
revisions, unchanged wear advances one, duplicate release cannot pay twice, and
uncertain acknowledgement does not retry. Inventory's existing atomic export/body
tests cover wear rebase plus payment and authority-loss rollback. These are mocks,
not live combined SQL/native acceptance. All113 Weapons Lua/7Node specs and the
Inventory Lua runner passed.

## Temporary input and deployment

Weapons only: client/character_ammunition_native_owner.lua and
client/character_ammunition_startup.lua. No new script/manifest/config replacement.
PrepareStop current player, wait PASS, stop Weapons, copy both existing files.
Enable existing GUID/saved/transaction flags and new replicated
feather_native_attachment_wear_fixture=1, ensure Weapons. Other probes stay off.
No Inventory/Medical/Character/Admin changes or new items/material grants.

F8 weaponNativeAttachmentWearFixture requires configured alpha character,
active/idle/current owner, all tracked wear zero, exact fixed disposable Carbine135
revision8/known fixture serial/alive owned entity plus the three attachment gates.
It writes native dirt0→0.2 once; immediately verifies readback. No SQL/ammo/material
write, no new weapon. It refuses original112 and later revisions, stale/busy/dead
or unreadable/foreign entities, nonzero wear and duplicate input. Remove helper
after gate acceptance. Do not use generic native component probes.

## Batched test

At configured gunsmith, equip135 shoulder using Equipment and reopen Equipment
so the Install button is already available. Preflight server
WeaponNativeAttachmentStatus current-player 135: revision8/empty/material1;
F8 weaponNativeMaintenanceStatus:112rev1 and135rev8/allwear0.

Then run F8 weaponNativeAttachmentWearFixture once and immediately close F8 and
click Install — Wide sight. Do not restart, logout, trigger another checkpoint or
wait for periodic saving between those actions. Capture server commit/PASS,
AttachmentStatus and F8 MaintenanceStatus/weaponNativeStatus. Expected135rev10
(wear CAS + attachment CAS), saved sight/material0, native dirt≈0.2/otherwear0,
112rev1/allwear0 and ledger33/allammo0/idlecopies2. If periodic saver wins first,
rev9 may be saved before install: inspect logs; that is NOT combined acceptance.
Do not inject more dirt/retry uncertain writes or bypass guards to force the gate.

After confirmed combined install, use menu Remove once. Expected135rev11,
empty attachment/material1, dirt≈0.2 preserved (unchanged wear adds only one
revision), same equipment/ammo/original112. This removal checks retained wear,
not a second changed-wear input. Changed-removal composition is covered in mocks.

After success unequip shoulder, PrepareStop/stop, disable fixture and three
attachment flags, ensure baseline112. Retain returned material/worn disposable
Carbine until alpha flush. No heals/manual SQL edits or unnecessary fixture reset.
Failure/unknown result: retain evidence, no automatic retry or grant/refund.
