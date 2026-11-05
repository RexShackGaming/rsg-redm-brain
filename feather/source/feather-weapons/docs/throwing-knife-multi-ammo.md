# Throwing Knife multi-type escrow implementation contract

Status: Regular/Poison multi-pool manual lifecycle checks passed, including the
eight-item Poison capacity test. Improved failed native support and is excluded.
Throwing Knives now opts in; no other definition changes to multi-type semantics.
Menu loading preserves the other type, owned-type selection moves no Inventory
quantity, selected-type unload and atomic unload-all return exact definitions.
Restore verifies all native pools after applying them and selecting the saved
type. Independent pool decreases checkpoint together; active weapon-object
selection changes the projection without renewing the lease. Checkpoints cannot
increase ownership, omit compatible pools, or use stale/foreign leases.
Native pickups (including same-type Regular recovery) are not credited for this
initial multi-type slice. Single-type Tomahawk recovery remains unchanged.
Static regression cases were added but have not executed: no local Lua runner
or parser was found. git diff --check passes; startup is part of the live gate.

## Current handoff: Improved deferred

Improved ammunition investigation is deferred at the user's request. The isolated
setter and add-by-type Regular controls passed; Improved pools remained zero.
No unlock cause was established. Improved-only commands and cleanup state have
been removed; the historical investigation below is evidence, not an active
test request. Existing Improved Inventory items and database rows are untouched.
NativeProbe remains disabled by default. Supported catalog counts are32/36/38.
After cleanup, repeat lease/release smokes and verify the Regular/Poison menu;
no Improved tests, grants, database changes or Inventory restart are required.

### Historical exclusion and investigation evidence

Exclusion restart regression passed: Regular5/Poison8 saved/observed/native
agreement with both ready=true, no Improved key, lease5/5 and release9/9 at
counts32/36/38. User confirmed one Improved in Inventory.

The next investigation is whether Improved failures reflect native compatibility,
an unlock, or a different application path. No skill/rank gate for these variants
was found in Feather Weapons; its existing unlock code concerns offhand access.
No specific Improved unlock ID/requirement was established by reference research.
Do not infer an unlock ID from an ammo hash or blanket-enable unlocks.

DevMode `weaponammocompatibility` is read-only. It queries
_IS_AMMO_TYPE_VALID_FOR_WEAPON (0xC570B881754DF609, weaponHash, ammoHash) for
Regular/Poison knife controls versus Improved, Regular/Poison arrow controls
versus Improved, and Regular Tomahawk versus Improved/Homing. The signature was
checked against alloc8or's rdr3 native database. It does not grant native pools,
touch Inventory, select ammo, or read/write guessed unlock IDs. False controls
make the probe inconclusive; true candidate compatibility does not prove runtime
availability or absence of a gate. Improved remains excluded from loading.
Restart Weapons only, run `weaponammocompatibility` in F8 and capture all lines.
Grants: None. No database change or Inventory restart is needed.

Compatibility live result: all nine control/candidate queries returned true,
including Improved knives/arrows and Improved/Homing Tomahawks. The next gate
is the isolated no-clip-write Regular/Improved native grant baseline documented
in native-special-ammo-probe.md. It does not establish a skill gate; no unlocks
will be changed, and production Improved remains excluded.

Improved support failed: saved=1/observed=1 but native=0/ready=false; the user
reported no wheel entry. Regular5/Poison8 remained verified. After the requested
unload/type switch, metadata inspection showed Regular selected with balances
5/8/0 and runtimeMatch=true. Exact Inventory return still relies on manual
confirmation; the metadata alone does not prove it.

Improved definition/allowlist and candidate seed are removed. The existing DB
row and Inventory items are not deleted. Validation strips only the exact
retired Improved key when numeric zero and unselected; nonzero or selected
retired metadata still fails rather than discarding ownership. Restart Weapons
only, inspect Regular5/Poison8 and native readiness, and run lease/release smokes.
Expected catalog counts return to32/36/38. Grants: None. No SQL or Inventory
restart is needed. Confirm one Improved returned before advancing the catalog.

## Failed candidate: Improved Throwing Knives (one item)

Final Poison capacity checks were reported passed. After unloading the remaining
five Regular, both saved pools were zero and runtimeMatch=true. Lease smoke
passed 5/5; release smoke passed 9/9 with counts32/36/38. This signs off the
reported Regular/Poison loading, wheel selection, restart, independent
consumption, exact unload and failure-conservation checks, not pickup recovery.

Improved uses AMMO_THROWING_KNIVES_IMPROVED (1222378998) from femga's native
ammo list. A listed hash is not native support evidence. Its maxTotal is one
until tested. Catalog counts are now weapon=32 ammunition=37 attachment=38.
Apply sql/add_improved_throwing_knives.sql with Inventory and Weapons stopped,
start Inventory before Weapons, and reuse the existing carrier. Server weapon
grant: None. Player grant: /AddItems ammo_throwing_knives_improved 1.

Load existing Regular and Poison and record their quantities; then load one
Improved via Ammunition Management. Capture metadata and weaponruntime. Improved
must show saved=1/observed=1/native=1/ready=true, without changing the other pools.
If it fails verification or disappears from the wheel, do not throw it: unload
the selected Improved type, verify one exact return, and send diagnostics.
If verified, wheel-select/draw Improved and capture weaponthrowableselection
throwable_secondary 30; its active object must match Improved. Restart Weapons
and confirm all balances restore, then throw Improved once without pickup and
verify only Improved becomes zero. Finish exact unloads, metadata, lease/release
smokes and runtime output. Pickup recovery remains disabled for all knife types.

Native reference: https://github.com/femga/rdr3_discoveries/blob/master/weapons/ammo_types.lua

## Previous gate: eight-item Poison capacity

User reported the Regular/Poison manual checks passed. Captured final consumed
state was Regular=5, Poison=0 with saved/observed/native agreement. The remaining
five Regular unloaded exactly, with no Poison or repeated return. Populated-pool
unload left both saved pools at zero; the menu correctly hid unload controls.
The simulated selected Poison application failure was then run and the user
confirmed correct returned quantities. A temporary wheel delay before Regular
displayed five was reported; its cause is not established by the final snapshot.

Poison maxTotal is now eight as a live-test candidate, not signed-off native
capacity. Restart feather-weapons only. Server grant: None. Player /AddItems:
None if the observed 16 Poison items remain available; otherwise
`/AddItems ammo_throwing_knives_poison 8`. Preserve the existing Regular stock.

Load Regular first (record actual R), then Poison. Poison must cap at eight,
with excess Inventory unchanged and Regular R still owned/native. Inspect both
pools and weaponruntime: Poison saved=8/observed=8/native=8/ready=true. Wheel
cycle without throwing and verify neither pool changes. Restart Weapons and
verify both restore. Throw one Poison without pickup: expect R/7. Unload only
Poison: exactly seven Poison returns and Regular remains R. Unload remaining
Regular exactly, then finish metadata inspection, lease smoke (5/5), release
smoke (9/9, counts32/36/38), and weaponruntime. Stop on native verification
warnings or quantity mismatch. Pickup recovery remains disabled.

Regression cases cover loading eight from sixteen, preserving excess stock and
Regular ownership, rejecting nine in metadata/checkpoints, independent Poison
consumption, and exact seven-item unload. Tests remain unexecuted locally.

## Previous gate: simultaneous Regular and Poison

First gate attempt exposed a serialization omission: server runtime carried
ammoPools, but ReconciliationService.Snapshot omitted them from its client
response. The menu therefore showed the legacy Switch to Poison option instead
of saved-pool balances and multi-type loading. Snapshot now copies pools into
both slot and compatibility-equipped responses. Regression cases cover slot
response completeness and copy isolation. Repeat the load gate after restart;
the prior screenshot does not validate simultaneous pool behavior.

Restart feather-weapons only; no manifest, database migration or Inventory
restart is needed for existing installations that already tested Poison.
Server weapon grant: None; reuse the existing Throwing Knives carrier.
Player /AddItems: None if both ammo definitions are available. Otherwise use
`/AddItems ammo_throwing_knives_regular 2` and
`/AddItems ammo_throwing_knives_poison 1` in the authorized development setup.

1. In Ammunition Management choose Throwing Knives. Unload all knife types to
   establish an Inventory baseline, then load Regular and Poison using the menu.
   Record the actual Regular count R (up to eight) and Poison count one. Loading
   Poison must leave Regular R saved and present natively. Capture metadata and
   weaponruntime; both native pools must match and report ready=true.
2. Wheel-cycle between both types, close the wheel and draw/aim each. After
   each selection, metadata's selected projection should change but both pools
   must remain R/1. Restart feather-weapons and verify both balances and wheel
   variants restore, then reopen the menu.
3. Select Regular in the menu and unload only Regular. Inventory must gain R
   Regular, Poison must remain one saved/native. Then unload all knife types:
   Inventory must gain exactly one Poison, and both saved pools must be zero.
   Repeat unload-all: it must not return more items.
4. Reload both. Throw one Regular and do not pick it up. Inspect: Regular R-1,
   Poison one. Throw Poison without pickup. Inspect: Regular still R-1, Poison
   zero. A zero Poison selection may project 0/0 without erasing Regular.
5. Unload all remaining types and verify exact Regular returns. Refill and run
   weaponthrowablepoolfailure throwable_secondary. Saved selected ownership
   must remain unchanged; unload-all must return both exact saved quantities.
6. Finish WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1,
   WeaponReleaseContractSmokeTest 1 and weaponruntime. Release counts remain
   weapon=32 ammunition=36 attachment=38. Pool lines and runtimeMatch must
   agree, not just the selected total.

Stop on any pool verification warning, disappearing balance, failed checkpoint,
or quantity mismatch and send the output. Do not test pickup conservation yet:
the consumption-only route deliberately ignores native increases.

The next live gate is the DevMode read-only `weaponthrowableselection` probe.
It samples the native weapon ammo-type query and every compatible native pool
for 15 seconds by default (maximum 30), logs changes, and stops if the equipped
item or generation changes. It never enables variants, sets ammunition, calls
an ownership RPC, or credits recovery. Signed and unsigned hashes are compared
as 32-bit values. A missing native query is reported rather than substituted
with the approved metadata type.

Restart only feather-weapons. Server weapon grant: None. Player /AddItems:
None if one Poison round is already available. Using the existing knife carrier,
load one Poison round through the existing menu, then run
`weaponthrowableselection throwable_secondary 30` in F8. Observe/select Poison,
throw and retrieve it, then select the resulting Regular knife. Capture probe
output and the wheel labels before throwing and after pickup. If the 30-second
window expires, rerun the command without opening the ammunition menu or
reconciling, which could clear the unowned pickup. Do not infer ownership from
the probe: the Regular pickup remains uncredited. Expected evidence is a
matched Poison hash when Poison is selected and a matched Regular hash when
Regular is selected. A constant/base-type query means a different selection
query is needed before server wheel-selection integration.

Finish with WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1,
WeaponReleaseContractSmokeTest 1 and weaponruntime. This gate does not validate
simultaneous loading, pool transactions, or full multi-type lifecycle behavior.

## Accepted evidence

Correction: the user did not use the wheel within the first probe window, so
that test is inconclusive, not a failed selection query. It returned Regular
while the approved Poison pool was populated, but active selection was not
established. Do not use that initial sample to infer query semantics.

The upgraded probe produced activeCarrier=true and object hash 2074469742
matching Poison before the throw, then activeCarrier=true and object hash
-1639263599 matching Regular after pickup. Both BOOL variants agreed. Unarmed
samples returned false/no object, and a different selected weapon produced an
unknown ammo hash. The object query passes this active-single-type selection
check; simultaneous owned pools and manual wheel cycling remain untested.

The upgraded probe retains that comparison and additionally reads weapon
objects using 0x6CA484C9A7377E4F with both BOOL variants, then reads each
object's current ammo hash with 0x7E7B19A4355FEE13. These getter signatures
were checked against the alloc8or rdr3 native database. It reports activeCarrier
and the current selected weapon alongside the objects; inactive/unarmed samples
must not establish carrier selection. No new query feeds an ownership RPC yet.
Repeat the existing Poison/throw/pickup/Regular test, but close the wheel and
draw/aim the knife for each type so its active weapon object can be sampled.
Expected usable evidence: activeCarrier=true and an object reporting Poison
before the throw, then Regular after pickup. A zero/missing/stale object is
inconclusive, not an instruction to materialize or refill ammunition.

Reference: https://github.com/alloc8or/rdr3-nativedb-data/blob/master/natives.json

Regular Throwing Knives are live-validated. Poison is selectable and throwable.
Poison pickup on the tested build increases `AMMO_THROWING_KNIVES`, leaving
`AMMO_THROWING_KNIVES_POISON` and the selected Poison escrow at zero. That
native Regular increase is not yet authoritative Feather ownership.

## Scope

One unique Throwing Knives carrier will hold separately conserved Regular and
Poison balances. Add other knife types only after these two pass. Existing
firearm, bow, and Tomahawk single-type semantics remain supported.

The first implementation slice covers multi-type loading, selection, throw
consumption, exact-type unloading, and restart persistence. Poison-to-Regular
pickup conversion is a following slice and must not be silently credited by
the first slice.

## Persistent state

For explicitly opted-in definitions, `ammo.pools` maps compatible ammunition
definition IDs to nonnegative integer owned totals. `ammo.type` identifies the
selected type. Existing loaded/reserve/chambered fields project only that
selected balance and must agree with its pool. Never count that projection a
second time. Legacy carrier metadata without pools imports its current balance
exactly once within a server-owned metadata transaction.

Reject incompatible keys, malformed values, per-type over-cap totals, and
selected-projection mismatches. A native hash is not a metadata ownership key.
Metadata normalization, inspection, movement, issuance, and reconciliation must
preserve every pool. Loading a second type must not return the first to Inventory.

## Transactions and runtime

Load removes only the requested Inventory definition and increments only its
owned pool. Select changes the projection and native selected type without
loading from or returning items to Inventory. Unload returns only the requested
pool's exact definition; unload-all returns every pool atomically. Every path
uses existing character/session/item/slot/generation and revision checks.

Runtime restore carries an immutable snapshot of all approved pools to the
client. The client materializes only those balances and enables only supported
variants. Pool verification must succeed independently for each nonzero pool
before its consumption observer is armed. Failure preserves that pool's escrow.

Wheel selection is an observation, not authority to load or increase a pool.
Verify the native selected-ammunition query on the target build before using it
to drive the server selection transaction. Reconcile/checkpoint order must not
attribute a Regular throw to Poison or count the shared clip a second time.

## Recovery boundary

Recovery credit must include the thrown ammunition type, item, lease generation,
and session. Ordinary recovery consumes same-type credit after a committed
throw. The initial multi-type slice must preserve the current prohibition on
unselected native pickups minting ownership.

A later Poison-to-Regular conversion transaction may consume one Poison throw
credit and credit one Regular item, never restore Poison as well. Its ledger
must handle capacity and Inventory failure without spending credit early, and
must reject duplicates and type switches that replay old credit. Bounded
same-runtime observations do not identify physical projectiles: cross-player
transfer and provable physical-item attribution remain deferred to a server
projectile/pickup ledger.

## Live acceptance for the first slice

Load Regular and Poison on one carrier; wheel-cycle while both balances remain
owned. Inspect both persistent pools before and after a throw of each type.
Unload one type without changing the other, then unload all and verify exact
Inventory totals by definition. Repeat restart restoration, unsupported-pool
failure conservation, and foreign/stale lease rejection. Finish with metadata
inspection, lease/release/multi-slot smoke tests, and native pool diagnostics.

Do not accept the slice from wheel visuals or a single selected-total inspection.
