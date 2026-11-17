# Regular Tomahawk quantity acceptance — 2026-11-15

Companion changes: [Weapons #50](https://github.com/FeatherFramework/feather-weapons/pull/50)
and [Inventory #70](https://github.com/FeatherFramework/feather-inventory/pull/70).
The framework Weapons and Inventory master plans remain the authoritative record.

Runtime cleanup follow-up (live-confirmed 2026-11-15): the normal manifest now excludes
45 retired experiment entries. shared/throwable_mode.lua owns the supported
quantity opt-in, and shop_config.lua supplies the ammunition price/pack size.
Focused startup/catalog/own recovery passed on this slimmer composition: Shops
9/9, retired throwable action refused without a loan, and quantity 3->2->3 at
revisions 61/62 with capacity permissions correct. Earlier broader gates below
predate the cleanup; they were not all repeated. Offline sources and the historical manifest
are preserved under the documented research boundary, never loaded as a fallback.

## Live-confirmed scope

| Gate | Result |
| --- | --- |
| Paid load/unload; empty-inventory ammunition access | Passed |
| Capacity UI and pre-dispatch refusal | Passed; Load disabled at 3/3, concise localized reason |
| Own, shared and repeated native recovery | Passed |
| Three outstanding paid throws | Passed |
| Full native holder | Passed; pickup suppressed at three, re-enabled after unload, suppressed again on recovery to three |
| Multi-unit pickup | Passed; zero to three across two acknowledged pickup transactions, so at least one credited multiple units |
| Reconnect and full-server restart | Passed; loaded/unloaded quantities preserved |
| Death/admin revive | Passed; automatic seal, cleanup and fresh-epoch restoration |
| Return to Selection; Save and Quit | Passed on subsequent controlled runs |
| Prepared resource stop/start | Passed with exact cleanup and restored saved counts |
| Settled unprepared resource stop | Cleanup/release correctly refused; inspector confirmed native remnants; full RedM exit and resource restart/rejoin restored saved balance |
| Expiry rejection | Passed using a five-second test allowance; no credit, native excess removed, runtime active |
| Distance rejection | Passed using a test allowance recorded 100 metres away; no player/entity move |
| Bucket rejection | Passed with allowance bucket 1 and actual bucket 0; no player routing change |

Final observed Jane state: active, saved/native Tomahawks three at revision 60,
revolver regular 100, firearm and five melee assignments retained, Tomahawk drawable.
Historical serialized items were not converted, refunded or deleted.

## Controlled rejection diagnostics

These are console-only, default-off one-shot diagnostics. They share one current
session/epoch/revision reservation, expire if not used within 60 seconds, and
affect only the next single paid throw. They do not issue replacement ammunition
or edit balances. Each rejected recovery spends a real paid test unit.

| Console command (replace player ID) | Required temporary server convar | Test allowance |
| --- | --- | --- |
| `WeaponQuantityExpiryTest arm <id>` | `set feather_quantity_expiry_test 1` | Lifetime five seconds |
| `WeaponQuantityDistanceTest arm <id>` | `set feather_quantity_distance_test 1` | Recorded position shifted 100 metres on x; normal lifetime |
| `WeaponQuantityBucketTest arm <id>` | `set feather_quantity_bucket_test 1` | Recorded in the next bucket; maximum bucket wraps to zero |

Each command also supports `status <id>` and `cancel <id>`. Save status before
cancelling. Disable all three test convars afterward; never persist them in
server.cfg. Ordinary allowances remain at 180 seconds, 50 metres and the actual
server-recorded bucket. A test switch alone does not alter normal throws.
Unused distance/bucket test allowances expire naturally after 180 seconds.

## Limits of the evidence

Natural long-delay collection was inconclusive because the engine despawned the
object first. Controlled tests exercise actual server predicates and normal
native compensation, not physical projectile movement or live player bucket
migration. The precise sizes/order of the two observed pickup transactions were
not logged separately. SQL rollback/race coverage is modeled, not a contention
certification. Literal process crash, in-flight SQL crash and in-place hot restart
over retained native copies are not accepted by these results.

An earlier logout checkpoint refusal was not reproduced after a fresh session;
its original cause remains unproven. The added client diagnostic exposes the
original refusal without changing the checkpoint result or retrying writes.

Quantity recovery intentionally accepts bounded nearby claims rather than exact
serialized projectile ownership. A modified client can consume an available
allowance, but cannot save more recovered units than confirmed paid throws supplied.
Knives, physical holder items and historical-item migration are outside
this regular Tomahawk acceptance scope.
Regular arrows passed the separate current-runtime integration gate on Jane in
the shoulder slot; see regular-arrow-integration.md for evidence and remaining scope.

2026-11-15 ammunition purchase-limit follow-up IMPLEMENTED / LOCAL PASS, live pending:
Single-unit ammunition offers now use maximumUnits (default10, configurable1..100), independently of maximumBoxes (still2 for multi-round packs). Existing operator shop_config.lua files receive default10 without replacement. Tomahawk loaded capacity remains3; purchase price, pack sizes, Inventory delivery limits and server quote checks unchanged. Invalid explicit limits refuse catalog configuration. Weapons runtime syntax and304 isolated Lua suites passed (ammunition-purchase-limit-tests.log), including default/custom/legacy unit limits, invalid settings, and unchanged two50-round-box limit. Deploy only server/services/gun_store_catalog.lua with orderly Weapons stop and Shops restart; no manifest/schema/convar changes or refresh required. Live Jane gate pending: buy5 loose regular Tomahawks for$7.50, verify Inventory delta+5, loaded quantity unchanged, and shop smoke9/9. No commit/push/PR actions performed.

2026-11-15 ammunition purchase-limit LIVE PASS: user confirmed all posted manual checks passed. Jane purchased5 individual regular Tomahawks for$7.50, Inventory gained5 loose units, and loaded quantity remained unchanged. Shops release smoke9/9 passed. Single-unit purchase default10 is live accepted; boxed ammunition maximum2 and loaded Tomahawk capacity3 remain unchanged. No further deployment required for this gate. User handles commits/pushes/PRs.

2026-11-16 bow/arrow continuation: user approved regular arrows first and correctly pointed out prior arrow acceptance. Recovered 2026-09-30 special-weapon checkpoint (this plan section Special-weapon catalog checkpoint): standard Bow and Regular/Small Game/Poison/Fire/Dynamite routes completed live validation; Improved excluded after native pool stayed zero. Phase2/3 and docs/weapon-catalog.md preserve equip/firing/ammo/lifecycle coverage under the earlier runtime. Current native-first CharacterAmmoCatalog/Item admit firearm families only, and quantity allowance implementation explicitly targets Tomahawks. Treat prior bow/native ammo compatibility as established; do not request a fresh broad bow/type matrix or infer historical escrow tests prove new character-ledger recovery. Next work is porting regular-arrow admission to current GUID/character-ledger lifecycle and type-separated bounded recovery, with focused integration checks on Jane only. No new runtime changes, grants, deployments or repeated live tests performed in this continuation/research pass. Specialty expansion deferred by user choice; previously excluded Improved remains excluded.
