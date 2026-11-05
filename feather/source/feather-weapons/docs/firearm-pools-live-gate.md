# Firearm ammunition pools: first live gate

Experimental; not general catalog acceptance. No SQL/seed changes required.
Set Config.AmmunitionPools.enabled = true on the development server; leave its
allowlist at revolver_cattleman only. Deploy the complete Weapons resource and
restart it. Keep offhand and other ammunition-using weapons unequipped for this
first test, so observations concern only the Cattleman. Do not expand the list yet.

1. Record Inventory ammo quantities and WeaponMetadataInspect 1 before enabling.
2. Preserve existing Express ownership; load 10 Regular through ammo management
   without unloading Express. Inventory must decrease by exactly 10 Regular.
3. Cycle Regular/Express in the wheel. Confirm both funded counts remain and
   other unfunded revolver types remain zero. Run weaponruntime.
4. Fire one Regular, switch to Express and fire one. Each corresponding pool
   must decrease once, and switching alone must not consume or create ammo.
5. Checkpoint, restart twice and reconnect. Confirm both pools and selected type.
6. Partially unload selected ammo, then unload all types. Confirm exact items
   return to Inventory and a second unload-all is rejected without duplication.
7. Reload both types, repeat switching/holstering and run WeaponMetadataInspect 1,
   WeaponRuntimeLeaseSmokeTest 1, WeaponReleaseContractSmokeTest 1 and weaponruntime.

Stop on a pool warning, failed checkpoint, missing count or free rounds; send
both consoles and wheel screenshots. Shared sidearms/long guns and all other
native variants are separate gates after this passes.

Do not turn the option off while saved firearm pools contain ammunition. Unload
all opted-in types first; otherwise opt-out must reject, not discard, metadata.

## Cattleman lifecycle gate

Basic load, wheel switching, one shot per type, resource restart, selected-type
unload and all-type unload have passed manual testing. The redesigned menu also
opens after preserving accordion keys. These do not establish lifecycle or broad
catalog acceptance. Keep the allowlist Cattleman-only for the following checks.

1. Load 10 Regular and 10 Express from owned Inventory ammunition. Record both
   Inventory quantities and saved pools; loading must subtract exactly 10 each.
2. Switch without firing, holster, unequip and re-equip. Both pools must stay 10.
3. Fire two rounds of one type, reload, then switch. Only that pool becomes 8;
   the other stays 10. Check loaded and reserve counts as well as totals.
4. Log out through the normal character flow and reconnect. Confirm 8/10 and
   the selected type persist; also check the menu can reopen.
5. On a development character, test death/respawn with the same recorded counts.
   Separate any configured death inventory policy from ammo checkpoint behavior.
6. Restore throwing-knife/Tomahawk ammo from existing Inventory, then repeat a
   Weapons restart. Their saved and native totals must agree and remain independent.
7. Run WeaponMetadataInspect 1, WeaponRuntimeLeaseSmokeTest 1,
   WeaponReleaseContractSmokeTest 1 and weaponruntime; provide both consoles on failure.

Stop on free rounds, lost pools, restore failure, or checkpoint warnings. No SQL
changes or additional item grants are required when the ammo is already owned.

## Distinct shoulder/back repeater gate

The experimental allowlist now includes repeater_carbine and repeater_lancaster.
Single and distinct dual revolver manual gates have passed, including mixed
selected types and isolated unload; death handling remains deferred.

Unequip the Bow to free the shoulder slot. Keep tested revolvers holstered.
Grant the two repeaters only if not already owned; equip Carbine on shoulder and
Lancaster on back. Empty weapons must have zero saved/loaded ammunition.
Load 10 Regular and 10 Express into each through slot-specific ammo management.
Inventory must lose exactly 20 of each repeater type overall. Native aggregate
totals must be Regular 20 and Express 20, with 10 per item per type. Check
weaponruntime and WeaponMetadataInspect 1 before firing. Stop on any warning.

Later gates cover per-instance firing, shared/different selected types, reload,
isolated unload, restart and normal reconnect. No item seeds or SQL are needed.

## Single M1899 partial-reload and switch gate

The four-weapon revolver/repeater gate has passed. The allowlist now adds only
`pistol_m1899`; the other three pistol models remain on the legacy single-type
path. This is a new native ammunition family and a detachable-magazine reload
gate, not broad pistol acceptance. No item seeds, compensating ammunition, or
database migration are required.

Start from the confirmed checkpoint: Cattleman 5 Regular/9 Express, Schofield
empty, Carbine 7 Regular/8 Express, and Lancaster empty. Leave those four items
equipped and holstered if practical, but do not load their empty companions.
Equip one M1899 in either sidearm position only after recording which revolver
was moved. Use ammunition already owned in Inventory.

1. Load exactly 10 Regular and 10 Express into the M1899 through its slot-specific
   ammunition management. Inventory must decrease by 10 of each. Metadata must
   show M1899 Regular 10/Express 10; existing four-weapon balances must be unchanged.
2. Select Regular in the native wheel and fire three shots (M1899 Regular 7).
   Reload normally. With only seven Regular owned, the resulting magazine must
   remain partial; reopening ammunition management must still show total 7 and
   must not change either saved pool.
3. Switch to Express in the native wheel without firing. Express must remain 10.
   Switch back to Regular without firing; Regular must remain 7. Repeat the
   Regular/Express switch once while holstered and verify no count changes.
4. Select Express, fire two shots, interrupt the next reload by switching or
   holstering after the native reload has begun, then reopen ammunition
   management. Express must be 8 and Regular 7; an interrupted reload must not
   create, lose, or transfer rounds. Stop if the game forces a completed reload;
   report that outcome rather than repeating uncontrolled attempts.
5. Holster, draw, and re-equip the M1899. Confirm 7 Regular/8 Express. Restart
   only `feather-weapons`, then confirm the same balances and selected type.
6. Complete a normal reconnect and confirm M1899 7 Regular/8 Express plus the
   unchanged checkpoint balances on Cattleman, Schofield, Carbine, and Lancaster.
7. Unload only M1899 Express: exactly 8 Express must return to Inventory and its
   Regular 7 must remain. Then unload all M1899 types: exactly 7 Regular must
   return. The four earlier weapons must remain unchanged.
8. Run `WeaponMetadataInspect 1`, `WeaponRuntimeLeaseSmokeTest 1`,
   `WeaponReleaseContractSmokeTest 1`, and client `weaponruntime`. Expected
   catalog counts remain weapon=49, ammunition=43, attachment=38.

Stop on a pool/checkpoint warning, a native total increase, an unexplained count
decrease, a changed companion balance, or a menu that cannot reopen. Capture
both consoles and the before/after metadata. Death remains deferred until the
Character resource owns the supported death/respawn flow.

### M1899 result — accepted 2026-10-05

The tester confirmed the complete manual checklist passed, including native
Regular/Express switching, partial and interrupted reload handling, holster and
re-equip, Weapons restart, normal reconnect, isolated Express unload, and final
all-type unload. The supplied pre-unload snapshots directly show M1899 item 411
at Regular 7/Express 8 with both saved pools matching native totals and
`runtimeMatch=true`. Across restart/reconnect snapshots, Carbine remained
Regular 7/Express 8 and Lancaster remained empty. Client `weaponruntime` agreed
with the saved M1899 and repeater totals and reported no in-flight checkpoint.

The supplied server evidence also records runtime lease 5/5 and release 9/9 at
weapon=49, ammunition=43, attachment=38. Exact Inventory quantities returned by
the two unload operations are tester-confirmed manual observations; the pasted
server snapshots capture the 7/8 checkpoint before those unloads rather than an
independent Inventory ledger. This accepts only the single M1899 gate. Volcanic,
Semi-Automatic, and Mauser Pistols remain outside the allowlist.

The tester then repeated the gate from a verified empty M1899 baseline, one
step at a time. Metadata showed Regular-only 10 as loaded 8/reserve 2, followed
by simultaneous Regular 10/Express 10. Native-wheel switching conserved 10/10.
Three Regular shots produced 7 total, loaded 5/reserve 2; reload produced loaded
7/reserve 0 without changing ownership. Two Express shots produced 8 total,
loaded 6/reserve 2; the attempted interruption completed natively at loaded
8/reserve 0 without changing ownership. Client runtime matched saved/native
pistol totals at Regular 7/Express 8 with no checkpoint pending.

Weapons restart and normal reconnect each preserved M1899 7/8, Carbine 7/8,
and empty Lancaster with `runtimeMatch=true`. Isolated Express unload returned
exactly eight Inventory cartridges and left Regular seven; all-type unload then
returned exactly seven Regular. Final metadata and client runtime showed every
M1899 saved/native pool at zero, Carbine still 7/8, and Lancaster empty. Runtime
lease remained 5/5 and release remained 9/9 at 49/43/38. This structured rerun
directly closes the earlier lack of a pasted post-unload snapshot.

## Single Volcanic partial-reload and switch gate

The accepted M1899 remains enabled. The next allowlist expansion adds only
`pistol_volcanic`; Semi-Automatic and Mauser Pistols remain on the legacy path.
This gate repeats the proven Regular/Express ownership checks while exercising
the Volcanic's different native reload behavior. It does not test dual-pistol
contention. Start with the M1899 empty, Carbine Regular 7/Express 8, and Lancaster
empty. Use a single Volcanic in the primary slot with the offhand empty.

Follow the same stepwise 10 Regular/10 Express sequence used for the clean M1899
rerun: verify empty baseline; load Regular then Express separately; wheel-switch
without firing; fire three Regular; reload and confirm total conservation; fire
two Express; attempt one reload interruption without repeating it; verify native
runtime; restart Weapons; reconnect normally; unload Express only; unload all;
then run lease 5/5, release 9/9, and a final native runtime snapshot. Expected
ownership transitions are 10/10 to Regular 7/Express 10 to Regular 7/Express 8,
then Express 0/Regular 7, then all zero. Loaded/reserve projections may follow
the Volcanic's native per-round reload timing, but their sum must equal the
selected owned total and switching/reload alone must never change either pool.

No weapon grant is needed if a Volcanic is already owned. Otherwise use
`grantweapon pistol_volcanic 1` from the server console. If ammunition is not
already available, use `/AddItems ammo_pistol_regular 10` and
`/AddItems ammo_pistol_express 10` from the authorized player's command entry.
No database migration or compensating ammunition is required.

### Volcanic result — accepted 2026-10-05

The stepwise gate passed from an empty Volcanic item 467. Regular-only loading
produced total 10, loaded 8/reserve 2; adding Express produced simultaneous
10/10. Native-wheel cycling preserved both pools. Three Regular shots produced
Regular 7 with loaded 5/reserve 2, and reload produced loaded 7/reserve 0 without
changing ownership. Two Express shots produced Express 8 with loaded 6/reserve
2. The single interruption attempt completed the native reload at loaded
8/reserve 0 and preserved Regular 7/Express 8.

Client runtime matched saved/native pistol totals at 7/8 with no pending
checkpoint. Weapons restart and normal reconnect preserved Volcanic 7/8,
Carbine 7/8, and empty Lancaster with `runtimeMatch=true`. Isolated unload
returned exactly eight Express; final all-type unload returned exactly seven
Regular. Final metadata and native runtime showed all Volcanic pistol pools at
zero while the repeater checkpoint remained unchanged. Runtime lease passed
5/5 and release passed 9/9 at 49/43/38.

During the three-Regular-shot checkpoint, one Inventory pool-batch transaction
hit `ER_LOCK_DEADLOCK` and rolled back. A subsequent automatic retry committed,
and authoritative/native state converged at the expected 7/10 without loss or
duplication. The deadlock did not recur during the remaining gate. This is valid
rollback/retry conservation evidence, not proof that the underlying database
contention is resolved; track recurrence in later gates.

## Distinct M1899/Volcanic shared-pool gate

Both models have passed isolated testing and are already allowlisted. This gate
does not add a definition. It equips Volcanic primary and M1899 offhand to test
two different weapon instances sharing the native pistol ammunition pools.
Start with both pistols empty, Carbine Regular 7/Express 8, and Lancaster empty.

Load each pistol with 10 Regular and 10 Express through its slot-specific menu.
The native aggregate must become 20 Regular/20 Express while metadata retains
10/10 on each item. Exercise same-type and mixed selected types, fire one round
from each pistol with unambiguous hand/selection changes, and verify only the
firing item/type is debited. Include a partial reload on one item while its
companion retains ammunition, then holster/re-equip, restart Weapons, and
reconnect. Unload the M1899 only and prove the Volcanic remains unchanged; then
unload the Volcanic and verify all pistol native pools return to zero.

Stop on ambiguous attribution, a changed companion pool, a native aggregate
that differs from the sum of owned pools, checkpoint warnings, or a recurring
database deadlock. Use ammunition already returned by the isolated gates; grant
only a missing quantity. No migration is required.

The first isolated Volcanic deadlock recurred on the first paired Volcanic shot.
The automatic retry again conserved the expected primary Regular 9 and all
companion pools, but the recurrence stopped the gate. Review found that the
multi-item firearm pool checkpoint and periodic maintenance checkpoint could
enter Inventory concurrently for the same equipped item metadata. Client mutual
exclusion now defers pool capture while a maintenance batch is active and
defers maintenance while a firearm pool transaction is active. Restart Weapons
and resume from the preserved 9/10 Volcanic and 10/10 M1899 checkpoint; any
further deadlock stops the gate for deeper Inventory/MySQL investigation.

### Distinct M1899/Volcanic result — accepted 2026-10-05

The pair started empty and reached per-item Regular 10/Express 10, with native
aggregates Regular 20/Express 20. Because the menu loads the available amount,
the test intentionally staged 20 of each type on the Volcanic, unloaded 10, and
then loaded the returned 10 into the M1899; every intermediate metadata snapshot
matched the expected ownership split.

An isolated Volcanic Regular shot changed only that pool to 9. The first attempt
encountered the recurring database deadlock and safely retried, which stopped
the gate for the maintenance/pool mutual-exclusion fix. After deploying and
restarting, ownership restored as Volcanic 9/10 and M1899 10/10. An isolated
M1899 Express shot then changed only that pool to 9 with no deadlock; three more
shots changed it to 6 with loaded 5/reserve 1. Its native holster reload produced
loaded 6/reserve 0 without borrowing from the funded Volcanic. Same-type Regular
selection preserved ownership and produced native aggregates Regular 19 and
Express 16.

Weapons restart and normal reconnect preserved Volcanic 9/10, M1899 10/6,
Carbine 7/8, and empty Lancaster with runtime matches. Isolated M1899 all-type
unload returned exactly 10 Regular and 6 Express while preserving the Volcanic.
Volcanic unload then returned exactly 9 Regular and 10 Express. Final metadata
and runtime showed both pistol items and every native pistol pool at zero,
Carbine 7/8, Lancaster empty, dual enabled, and no pending checkpoint. Runtime
lease passed 5/5 and release passed 9/9 at 49/43/38.

No deadlock recurred after the mutual-exclusion fix across the remaining firing,
reload, restart, reconnect, and unload steps. This live-validates the local race
fix for this gate; it does not prove all Inventory/MySQL contention impossible.

## Four-funded-firearm contention gate

Do not expand the allowlist for this gate. Keep Volcanic primary, M1899 offhand,
Carbine shoulder, and Lancaster back. Begin with both pistols and Lancaster
empty and Carbine Regular 7/Express 8. Fund each previously empty weapon with
Regular 5/Express 5 through its slot-specific menu, using controlled Inventory
quantities and correcting any load-all staging before continuing.

Verify per-item ownership and native aggregates, then fire one isolated selected
round from each of the four items, checking metadata after every shot. This
forces the atomic firearm checkpoint to cover four funded items across pistol
and repeater native families while preserving per-item attribution. Follow with
one reload on a partially loaded pistol and one on a partially loaded repeater,
Weapons restart, normal reconnect, and isolated unload in reverse slot order.
Finish with all pistols and Lancaster empty, Carbine restored only to its new
post-shot balance, native aggregates equal to saved sums, lease 5/5, release
9/9, and no pending checkpoint.

Any deadlock, ambiguous debit, changed companion pool, aggregate mismatch, or
checkpoint warning stops the gate. Planned test grants establish starting stock;
they must not compensate for a missing or duplicated runtime round. No database
migration is required.

Live progress on 2026-10-05 established Volcanic Regular 9/Express 6, M1899
10/10, Carbine 7/8, and Lancaster 9/8, with native aggregates 19/16 and 16/16.
An isolated Volcanic Express shot changed only Volcanic Express to 5. The next
isolated M1899 Express shot changed only M1899 Express to 9 (loaded 7/reserve
2). All four items reported runtime agreement after each shot, and neither step
produced a deadlock or checkpoint warning. The following isolated Carbine
Express shot changed only Carbine Express from 8 to 7 (loaded 6/reserve 1),
again with all four items runtime-matched and no checkpoint error. The isolated
Lancaster Express shot then changed only Lancaster Express from 8 to 7. Carbine
remained 7 total while its holstered native reload moved it from loaded
6/reserve 1 to loaded 7/reserve 0. All four items remained runtime-matched, with
no deadlock or checkpoint warning. The four isolated-shot checkpoints passed.
For the pistol partial-reload check, three further isolated M1899 Express shots
changed its pool from 9 to 6 and produced loaded 5/reserve 1 while drawn. Every
companion pool remained unchanged and runtime-matched, with no checkpoint
error. Its subsequent native reload conserved 6 total and moved the state to
loaded 6/reserve 0. Every companion pool remained unchanged and runtime-matched,
so the partial pistol reload passed without a checkpoint error.
To establish a testable repeater reserve, three planned Express rounds were
granted and loaded into Carbine only. Its Express pool became 10 total, loaded
7/reserve 3; all companion pools remained unchanged and runtime-matched. This
was controlled test setup, not compensation for a missing runtime round.
Three isolated Carbine Express shots then produced the intended partial state:
7 total, loaded 4/reserve 3. Every companion pool stayed unchanged and
runtime-matched, with no checkpoint error. The corresponding reload remains to
be verified. Its subsequent native reload conserved 7 total and moved the state
to loaded 7/reserve 0. Every companion pool remained unchanged and
runtime-matched, so the partial repeater reload passed without a checkpoint
error.
After holstering all weapons, a `restart feather-weapons` preserved Volcanic
9/5, M1899 10/6, Carbine 7/7, and Lancaster 9/7. All four items rematerialized
with refreshed runtime generations and every pool reported runtime agreement;
no startup, deadlock, or checkpoint error appeared in the supplied evidence.
A normal reconnect then preserved the same Volcanic 9/5, M1899 10/6, Carbine
7/7, and Lancaster 9/7 balances with every pool runtime-matched. The lifecycle
portion passed; reverse-order isolated unloading remains.
The first reverse-order unload emptied Lancaster only and returned exactly 9
Regular/7 Express to Inventory. Lancaster reached zero in every pool while
Volcanic 9/5, M1899 10/6, and Carbine 7/7 remained unchanged and
runtime-matched.
The next isolated unload emptied M1899 only and returned exactly 10 Regular/6
Express to Inventory. M1899 reached zero in every pool while Volcanic 9/5 and
Carbine 7/7 remained unchanged and runtime-matched; Lancaster remained empty.
The final isolated unload emptied Volcanic only and returned exactly 9
Regular/5 Express, leaving Inventory at 19 Regular/11 Express for pistols.
Volcanic, M1899, and Lancaster were empty in every pool; Carbine alone retained
Regular 7/Express 7. Every reported pool was runtime-matched. Final runtime and
smoke checks remain.
The final client runtime inspection was idle with neither pair nor long-gun
checkpoint work pending or in flight. Both pistol native totals were zero;
repeater native totals were exactly 7 Regular/7 Express, matching Carbine alone.
Volcanic, M1899, and Lancaster local totals were zero and Carbine was loaded
7/reserve 0. The runtime lease smoke test then passed 5/5. The release-contract
smoke test passed 9/9 at catalog counts 49 weapons, 43 ammunition definitions,
and 38 attachment definitions. The four-funded-firearm contention gate passed
in full on 2026-10-05. No deadlock recurred after the checkpoint
mutual-exclusion fix, no companion pool changed ambiguously, and no database
migration was required. This does not make the unresolved full legacy
ammunition-suite equip fixture green, and death testing remains deferred.

## Single Semi-Automatic Pistol gate

The accepted four-funded-firearm gate permits one further allowlist expansion:
`pistol_semiauto`. Mauser remains excluded. Semi-Automatic is intentionally next
because its eight-round capacity matches the accepted M1899 and Volcanic
projections; the ten-round Mauser remains a separate later gate.

Start with Volcanic and M1899 empty, Lancaster empty, and Carbine retained at
Regular 7/Express 7. Equip one Semi-Automatic Pistol in a sidearm slot and first
prove that its local/native total and every persisted pool are zero. Fresh pool
metadata is sparse, so only the selected Regular zero key may be printed until
another compatible type is selected or funded; omitted compatible keys are
authoritative zero. Then use
the same controlled 10 Regular/10 Express sequence: load each type separately,
switch through the native wheel without firing, fire three Regular rounds and
reload, fire two Express rounds, and attempt one interruption without repeating
an uncontrolled outcome. Verify metadata after every transition.

Continue only if every companion weapon remains unchanged. Cover holster and
re-equip, `restart feather-weapons`, normal reconnect, isolated Express unload,
all-type unload, final `weaponruntime`, lease 5/5, and release 9/9. Expected
ownership is 10/10 -> 7/10 -> 7/8 -> 7/0 -> 0/0. No database migration is
required. If the weapon is not already owned, server console setup is
`grantweapon pistol_semiauto 1`. Once its empty baseline is proven, missing test
stock may be created in player chat with `/AddItems ammo_pistol_regular 10` and
`/AddItems ammo_pistol_express 10`; these are planned inputs, never compensation
for an unexplained loss. Stop on any deadlock, warning, aggregate mismatch,
companion mutation, or ambiguous debit.

The empty baseline passed on 2026-10-05 for primary item 637: selected Regular
was saved at zero, local total/loaded/reserve were all zero, and runtime matched.
The fresh sparse metadata correctly omitted never-used compatible zero keys.
M1899 and Lancaster remained empty and Carbine remained Regular 7/Express 7,
all runtime-matched.

Regular staging loaded all 19 available cartridges and then returned exactly 10
through ammunition management. This deliberately left Semi-Automatic Regular 9
(loaded 8/reserve 1) and Inventory Regular 10, preserving the combined total of
19. No shot or unexplained debit occurred. The remainder of this live run uses
the conserved 9 Regular/11 Express starting quantities rather than introducing
extra grants merely to force 10/10.
Loading all 11 available Express cartridges then produced simultaneous
Semi-Automatic ownership of Regular 9/Express 11. Express was selected at loaded
8/reserve 3. M1899 and Lancaster stayed empty, Carbine stayed 7/7, and every
reported pool was runtime-matched with no warning.
The first native-wheel switch selected Regular without firing and projected its
9 owned rounds as loaded 8/reserve 1. Express remained 11, every companion pool
was unchanged, and all reported pools remained runtime-matched.
The reverse native-wheel switch restored Express at 11 total, loaded 8/reserve
3, while Regular remained 9. No ammunition was consumed or transferred, all
companions stayed unchanged, and the bidirectional wheel-switch check passed.
After selecting Regular, three shots changed only that pool from 9 to 6 and
produced loaded 5/reserve 1. Express stayed 11 and all companion pools remained
unchanged and runtime-matched, with no checkpoint warning.
The following native reload conserved Regular 6 and moved its projection from
loaded 5/reserve 1 to loaded 6/reserve 0. Express remained 11 and every
companion pool stayed unchanged and runtime-matched.
After switching to Express, two shots changed only that pool from 11 to 9 and
produced loaded 6/reserve 3. Regular remained 6, all companions remained
unchanged and runtime-matched, and no checkpoint warning appeared.
The single interruption attempt completed the native Express reload despite the
holster action. Ownership remained Express 9/Regular 6, with Express projected
as loaded 8/reserve 1. Every companion pool remained unchanged and
runtime-matched; the attempt was not repeated.
Unequipping and re-equipping the same Semi-Automatic caused a clean sidearm
swap: item 637 moved from primary to offhand and the empty M1899 moved to
primary. Semi-Automatic Regular 6/Express 9 and its selected loaded 8/reserve 1
state were preserved, both sidearms remained runtime-matched, and Carbine 7/7
and empty Lancaster were unchanged.
A holstered `restart feather-weapons` preserved the swapped layout and every
balance: primary M1899 empty, offhand Semi-Automatic Regular 6/Express 9 with
Express loaded 8/reserve 1, Carbine 7/7, and Lancaster empty. Runtime
generations refreshed and all pools remained runtime-matched with no startup or
checkpoint warning.
A normal reconnect preserved all saved balances, but the cold native pair
restore emitted `native_pair_restore_failed` twice before succeeding on attempt
3. Logs showed the Semi-Automatic category resolving to the M1899 GUID on the
first two attempts; the existing bounded wait repeatedly wrote that stale GUID.
The restore loop now re-resolves the weapon GUID on every bounded type-selection
retry so a settling native inventory can recover in place. This reconnect is
not accepted; it must be repeated after deploying the fix.
After deploying the fix with `restart feather-weapons`, metadata preserved the
swapped layout and exact balances: empty primary M1899, offhand Semi-Automatic
6/9, Carbine 7/7, and empty Lancaster. Every pool was runtime-matched and the
supplied output contained no pair-restore failure. A clean normal reconnect
rerun remains required.
The clean reconnect rerun showed that re-resolving alone was insufficient: the
native category mapping stayed pinned to the M1899 GUID for both bounded waits
and again succeeded only on the third full restore attempt. The ineffective
loop change was removed. Pair creation now materializes the sole funded hand
first at its persisted attachment point when its companion is empty; both-funded
and both-empty pairs retain their established order. This targets the observed
empty-primary/funded-offhand cold-start race. Another clean reconnect is
required before acceptance.
Deploying the funded-first order without a transition made the next resource
restart fail closed after all three attempts; saved metadata remained intact but
the native pair was not restored. Both grants had still occurred in the same
native frame. A bounded 250 ms transition is now inserted after materializing
the funded offhand and before introducing its empty primary companion, allowing
the carried-weapons category map to establish the funded GUID first. This fix
requires a resource-restart recovery check before reconnect testing resumes.
The 250 ms transition also failed all three resource-restart attempts. The
funded-first restore-order experiment was therefore reverted completely to the
previous primary-then-offhand behavior that had passed the earlier resource
restart. Saved metadata and ammunition were unaffected. The remaining defect is
specifically the cold native mapping for an empty primary plus a funded Express
offhand; no further gate work proceeds until the known-good restore path is
recovered.
After the full rollback, the tester confirmed a good resource restart. This
recovers the previously accepted primary-then-offhand behavior and confirms the
failed experiment did not damage saved metadata. The empty-primary/funded-
offhand reconnect arrangement remains unaccepted; the next step removes the
empty M1899 and verifies supported promotion of the funded Semi-Automatic.
Unequipping the empty M1899 cleanly promoted Semi-Automatic item 637 to primary
at Regular 6/Express 9 with Express loaded 8/reserve 1. Offhand became empty,
Carbine remained 7/7, Lancaster remained empty, and every equipped pool was
runtime-matched. The reconnect will now be rerun through this stable
single-sidearm path; the separate empty-primary/funded-offhand arrangement is a
recorded unresolved native limitation, not accepted coverage.
The single-sidearm normal reconnect passed cleanly on attempt 1 with no restore
failure. Semi-Automatic remained primary at Regular 6/Express 9 with Express
loaded 8/reserve 1; offhand stayed empty, Carbine stayed 7/7, and Lancaster
stayed empty. Metadata was runtime-matched throughout. This accepts the
Semi-Automatic lifecycle only in the stable single-sidearm arrangement; it does
not erase the recorded empty-primary/funded-offhand cold-restore limitation.
Isolated Express unload returned exactly 9 cartridges to Inventory and changed
only the Semi-Automatic Express pool to zero. Regular remained 6, projected as
loaded 0/reserve 6 after selected-pool removal. Carbine stayed 7/7, Lancaster
stayed empty, and every equipped pool was runtime-matched.
Final all-type unload returned exactly 6 Regular cartridges, leaving Inventory
at 16 Regular/9 Express. Semi-Automatic reached zero in every pool, offhand and
Lancaster remained empty, and Carbine remained 7/7 with complete runtime
agreement. Final runtime and smoke checks remain.
The final client runtime snapshot was idle with no pair or long-gun checkpoint
pending or in flight. Semi-Automatic and all native pistol totals were zero;
Lancaster was zero; Carbine alone owned and exposed 7 Regular/7 Express. Lease
and release smoke tests remain.
The runtime lease smoke test passed 5/5. The release-contract smoke test remains.
The release-contract smoke test passed 9/9 at 49 weapon, 43 ammunition, and 38
attachment definitions. The Semi-Automatic single-sidearm sequence passed:
separate Regular/Express ownership, bidirectional wheel switching, isolated
consumption, partial reload, native-completed interruption attempt, re-equip,
resource restart, clean single-sidearm reconnect, exact isolated unloads, final
runtime, lease, and release checks all conserved ammunition.

Do not treat the model as broadly accepted yet. Re-equipping it into offhand
beside an empty primary M1899 exposed a reproducible cold-restore defect: RedM
resolved the funded Semi-Automatic category to the empty M1899 GUID and pair
restore failed twice before eventual recovery, while two attempted restore-order
fixes made resource restart fail closed and were fully reverted. Saved metadata
was never damaged. Keep Mauser excluded and do not expand the allowlist further
until empty-primary/funded-offhand restoration has a verified fix. The full
legacy ammunition-suite equip fixture remains unresolved, and death testing
remains deferred.

### Empty-primary/funded-offhand normalization fix

The Inventory promotion contract atomically removes an occupied primary
assignment and moves offhand into primary without changing item ownership. The
server reconciliation path now applies that existing contract before runtime
restoration when both sidearms are multi-pool, primary owns zero ammunition,
and offhand owns a positive total. The funded offhand becomes primary and the
empty former primary remains owned but unequipped, avoiding the native cold GUID
collision entirely. Auto-equip also rejects creating the same unsafe funded
offhand beside an empty multi-pool primary and instructs the player to unequip
the empty primary first. This is deliberately narrower than a general loadout
reordering policy. Static startup contracts and diff validation pass; live
normalization and rejection checks remain required before clearing the blocker.

The prevention half subsequently passed live. With empty M1899 primary and a
funded Semi-Automatic in Inventory, equipping the Semi-Automatic was rejected
with the new safe-promotion instruction and did not mutate the equipped state
or any ammunition pool. After following that instruction, the funded
Semi-Automatic equipped into empty primary with all 9 Express conserved. The
native wheel initially displayed zero, then hydrated to 9 on hover without a
click; the weapon held 0 loaded/9 reserve until drawing triggered a native
reload to loaded 8/reserve 1. A resource restart and normal reconnect both
completed restoration on attempt 1 and preserved Semi-Automatic Express 9,
Carbine Regular 7/Express 7, empty Lancaster, and an empty offhand. Runtime
lease passed 5/5 and release contract passed 9/9 at catalog counts 49/43/38.

The guard prevented recreating an already-persisted unsafe layout, so the
reconciliation fallback that normalizes legacy empty-primary/funded-offhand
records was not live-exercised in this sequence. Keep Mauser excluded until
that remaining coverage question is resolved deliberately. Do not claim the
full legacy ammunition suite green; its equip-fixture failure remains.
