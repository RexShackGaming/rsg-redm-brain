# Weapon catalog

## Current accepted checkpoint — v0.15.0

The agreed catalog expansion is complete: 49 weapon/equipment, 43 ammunition and
38 attachment definitions. Hammer, Improved Binoculars (native label Refined
Binoculars), Metal Detector and Fishing Rod passed their equipment live gates.
All 25 equipped carriers appeared in the final server/client snapshot, with lease
5/5 and release 9/9. The tester confirmed all requested manual lifecycle checks.
Five melee and eight utility persistence positions coexist with ten throwable
positions; one Lasso at a time remains the policy. Cameras, detecting and fishing
feature logic remain optional add-on scope. Counts and candidate statuses below
are historical where superseded by this checkpoint.


The catalog contains 24 standard firearms: four pistols, five revolvers,
four repeaters, six rifles (including scoped rifles and the Elephant Rifle),
and five shotguns. It also contains the standard Bow as the first
ammunition-using special weapon plus the standard Knife, Machete, Cleaver, and
Hatchet and Hammer as ammunition-free melee weapons. Named story-character and special
cosmetic variants are not included.

Melee weapons use distinct persistent logical positions while sharing RedM's
single melee-wheel category. Live testing confirmed that the Knife and Machete
coexist and can be selected by cycling within that wheel category. The Knife is
visible while holstered. The Machete becomes visible only when selected and uses
its native cross-draw presentation. The Cleaver also coexists in that category,
cycles normally, and remains usable. Although its metadata is ammunition-free,
RedM requires one native grant unit to materialize this recoverable throwable
weapon in the wheel. The Hatchet is the fourth coexistence slice and uses the
same bounded native-grant rule. Live testing confirmed all four models remain
native-owned and selectable together; the Hatchet uses the same native draw
presentation as the Machete and Cleaver.

Throwing Knives begin the dedicated throwable catalog. The unique carrier uses
its own persistent throwable position while regular knives are Inventory-backed
ammunition mapped to `AMMO_THROWING_KNIVES`. Each native throw must reduce the
approved escrow rather than the unique carrier item. The target RedM build
clamps the native pool to eight, so excess knives remain in Inventory. Live
testing confirmed that two throws commit a reduction from eight to six. Picking
up those same world objects spends the recovery credit created by the committed
throws, restores the carrier escrow, and keeps the wheel and later unload in
agreement. Recovery cannot exceed the number previously thrown by that active
runtime lease, so unrelated native pickups cannot mint authoritative ownership.
Cross-player recovery is deferred: transferring a thrown knife to another
character requires a server-owned projectile/pickup ledger that identifies the
physical knife, consumes its entitlement exactly once, and credits the picker
without leaving recovery credit available to the thrower.

The standard Tomahawk is a completed throwable validation slice. Its unique
carrier maps to `WEAPON_THROWN_TOMAHAWK`, and regular Inventory-backed
tomahawks map to `AMMO_TOMAHAWK`. Live testing confirmed that the target RedM
build accepts and preserves a three-Tomahawk native pool, with metadata and the
ammunition-management UI reporting one readied and two in reserve. A second
persistent throwable position allows the Tomahawk carrier and Throwing Knives
carrier to coexist. Live testing confirmed both remain natively owned and can
be selected by cycling within RedM's shared throwable-wheel category, while
their distinct `AMMO_TOMAHAWK` and `AMMO_THROWING_KNIVES` pools remain
independent. Metadata inspection passed with seven active persistent slots;
runtime lease, release, and multi-slot contracts passed `5/5`, `9/9`, and
`17/17` respectively.
Subsequent metadata inspections confirmed that one Tomahawk throw persisted a
reduction from three to two, and same-player pickup restored the total to
three. Both checkpoints matched the active runtime; the co-equipped Throwing
Knives carrier remained at six throughout. Manual validation confirmed exact
return of three Tomahawks on unload, reload, and restoration of both carriers
after a Weapons resource restart. Post-restart metadata and native pools agreed
at three Tomahawks and six Throwing Knives, with runtime lease `5/5` and release
contract `9/9` passing. Cross-player pickup transfer remains deferred for both
families pending the server-owned projectile/pickup ledger described above.

Improved Tomahawk ammunition failed live validation on the target build.
After loading it into the standard carrier, the weapon disappeared from the
wheel and `AMMO_TOMAHAWK_IMPROVED` remained at zero. Runtime synchronization
persisted a zero ammunition total despite no successful throw. Lease and
release smoke tests still passed; those checks do not establish native ammo
support. Switching the test carrier back to Regular restored agreement at
three Tomahawks in metadata and the native pool, while co-equipped Throwing
Knives remained at six. The experimental definition, carrier compatibility,
and recipe seed were removed. Improved Tomahawks are excluded from release
on this build.
After removing the route and restarting Weapons, metadata inspection confirmed
both carriers restored at three regular Tomahawks and six Throwing Knives with
runtime matches. Runtime lease passed `5/5` and release contract passed `9/9`
with `weapon=31 ammunition=34 attachment=38`, completing rollback validation.

Homing Tomahawk ammunition also failed live validation through the standard
carrier on the target build. The wheel behavior matched the Improved test,
`AMMO_TOMAHAWK_HOMING` stayed at zero, and runtime synchronization persisted
zero ammunition without a successful throw. Co-equipped Throwing Knives stayed
at six; lease and release smoke tests passed `5/5` and `9/9`. This route is not
accepted for release. Returning to Regular restored metadata/native agreement
at three Tomahawks while Throwing Knives remained at six. The Homing definition,
carrier compatibility, and recipe seed were removed after that recovery.
Post-removal Weapons restart restored both carriers at those same totals with
all seven equipped slots matching runtime. Runtime lease passed `5/5` and
release contract passed `9/9` with `weapon=31 ammunition=34 attachment=38`,
completing Homing rollback validation.

Throwable consumption tracking now waits for the selected native pool to match
the approved escrow balance after restore or ammunition application. Until
that initial verification succeeds, checkpoints preserve the saved balance and
the owner can unload the exact selected ammunition type. A diagnostic identifies
the mismatch. This guard does not make
the excluded Improved or Homing routes supported. Regular Tomahawk regression
passed throw, self-recovery, and exact unload checks, with a final zero escrow
and unchanged six-knife balance. Lease and release checks passed `5/5` and `9/9`.
The DevMode-only `weaponthrowablepoolfailure <slot>` command simulates a fresh
native application by overriding the verification read to zero while preserving
the approved escrow and the real native pool. The fault belongs to the current
local observation and clears on unload/reconciliation or resource restart.
Do not throw while the fault is active. `weaponruntime` reports the real pool
separately from `simulatedFailure` and verification readiness.
Live fault-injection validation produced `approved=3 native=0` at the guard,
with `ready=false simulatedFailure=true`. Metadata inspection retained all
three escrowed Tomahawks while the simulated mismatch was active. Subsequent
unload left the carrier at zero; Throwing Knives remained at six throughout.
Runtime lease and release contract passed `5/5` and `9/9`. The real native pool
remained three during this synthetic test, so this proves handling of the
injected verification mismatch rather than native support for excluded types.
Manual confirmation verified that exactly three regular Tomahawks returned to
Inventory on unload, completing the injected-failure conservation check.

Ancient Tomahawk is a completed live-test slice with a separate unique carrier
and `WEAPON_THROWN_TOMAHAWK_ANCIENT` / `AMMO_TOMAHAWK_ANCIENT` mapping. Its
one-item escrow ceiling matches the target-build native carrying limit.
It uses the existing throwable category with a third persistent position,
`throwable_tertiary`, allowing all three distinct carriers to coexist.
Native usability, recovery, conservation, and resource-restart restoration
passed live validation.
Initial live testing confirmed native ownership and wheel cycling with standard
Tomahawk and Throwing Knives in all three throwable positions. Ancient metadata
and `AMMO_TOMAHAWK_ANCIENT` both reported one, with verification ready; standard
Tomahawk and Throwing Knives retained three and six respectively. All eight
equipped slots matched runtime. Lease, release, and multi-slot contracts passed
`5/5`, `9/9`, and `17/17` with `weapon=32 ammunition=35 attachment=38`.
One loaded Ancient Tomahawk proves usability at one, not the maximum native pool.
The one-item lifecycle manual checks passed: throwing removed Ancient from the
wheel, same-player pickup restored one, unloading returned one item, and reload
plus Weapons restart restored all three carriers. Final metadata and native
pools agreed at one Ancient Tomahawk, three standard Tomahawks, and six Throwing
Knives, with eight runtime-matching slots, lease `5/5`, and release `9/9`.
Subsequent post-throw metadata inspection confirmed Ancient persisted
`total=0 loaded=0 reserve=0` with a runtime match, while standard Tomahawk and
Throwing Knives remained at three and six. The one-item consumption checkpoint
is accepted. The read-only `weaponthrowablecapacity` query subsequently reported
successful `GetMaxAmmo` results of one Ancient Tomahawk, three standard
Tomahawks, and eight Throwing Knives. The latter two match prior live pool
tests, confirming the configured one-item Ancient ceiling on the target build.

Inventory names use the weapon_ prefix. Catalog IDs remain independent;
Lancaster maps to WEAPON_REPEATER_WINCHESTER and Litchfield to
WEAPON_REPEATER_HENRY. Scoped rifles use the WEAPON_SNIPERRIFLE natives.

All new entries inherit the existing condition policy: 100 maximum condition,
native RedM maintenance determines wear, and one gun_oil restores up to 25
condition without crossing the permanent-wear floor. New inventory rows use the
existing weapon defaults (weight 2, maximum quantity 20).
Configured attachment slots cover the live-validated standard firearm models.
The Bow currently declares no functional attachment slots.

The Varmint Rifle uses ammo_varmint. The Elephant Rifle uses
ammo_rifle_elephant (AMMO_RIFLE_ELEPHANT). The Bow uses
ammo_arrow_regular (AMMO_ARROW), Small Game Arrows (AMMO_ARROW_SMALL_GAME),
Poison Arrows (AMMO_ARROW_POISON), Fire Arrows (AMMO_ARROW_FIRE), and Dynamite
Arrows (AMMO_ARROW_DYNAMITE), bringing ammunition definitions to 32.
Regular and Small Game Arrows have a definition-level 40-arrow escrow ceiling;
Poison, Fire, and Dynamite Arrows use the native eight-arrow
special-ammunition ceiling.
Improved Arrows are intentionally excluded: live testing with the standard Bow
accepted the Inventory transfer but the native `AMMO_ARROW_IMPROVED` pool
remained at zero, so exposing that route would consume Inventory without making
the arrows usable.
Nitro Express has a definition-level 20-round escrow ceiling, so loading from a
larger Inventory stack moves at most 20 cartridges into the Elephant Rifle.
Regular ammunition is the default. Each weapon also declares its supported
ammunitionTypes: regular, express, high velocity, split point and explosive
for pistols/revolvers/repeaters/ordinary rifles; regular, slug, incendiary and
explosive shells for shotguns; regular and tranquilizer for Varmint; Nitro
Express only for Elephant. See ammunition-types.md for selection and testing.

LeMat capacity describes its nine-round revolver cylinder only. Secondary
shotgun-barrel ammunition selection is not implemented. Sawed-off is classified
as a sidearm, but existing offhand family policy still controls dual wield.
Adding longguns does not create additional equipment slots.

## Installation and verification

Run sql/install_items.sql with Inventory and Weapons stopped, then start both.
Existing installations using the old inventory names must first run
sql/rename_weapon_item_names.sql as described in the README.

Run WeaponReleaseContractSmokeTest 1; expected counts are
weapon=32 ammunition=36 attachment=38.

Live-test each new model: grant, equip, refill, fire, reload, unload, repair,
logout/rejoin, and verify native clip capacity against the configured capacity.
The catalog expansion itself does not establish that all native behaviors have
passed those tests. In particular, check LeMat mode changes and longgun holstering.

Poison Throwing Knife ammunition is a pending live-test route using the
existing carrier and `AMMO_THROWING_KNIVES_POISON`. Its initial one-item ceiling
was conservative. Live testing showed Poison available in the native wheel and
usable for a throw. After same-player pickup, the wheel displayed Regular while
the selected Poison metadata and native pool remained zero. This does not
establish authoritative Regular recovery. Follow-up diagnostics confirmed
`AMMO_THROWING_KNIVES_POISON=0` and unselected `AMMO_THROWING_KNIVES=1`
after pickup, with the carrier's selected Poison escrow still zero. Native
pickup therefore supplies Regular ammunition through this tested path;
Feather does not credit it as Poison or mint Regular ownership. Poison pickup
recovery, maximum capacity, and full lifecycle acceptance remain open.
The carrier now opts into separate Regular and Poison escrow pools. Simultaneous
load/select/unload, independent native-pool consumption, and restart restoration
passed the reported six-Regular/one-Poison manual checks, including independent
consumption and exact unload conservation. Poison now has an eight-item test
ceiling whose reported capacity/lifecycle checks passed, followed by metadata,
lease 5/5 and release 9/9. Improved Throwing Knife ammunition is excluded:
its one-item test left saved ownership at one but native count at zero and
verification false, with no wheel entry. Regular5/Poison8 remained intact;
post-unload metadata showed Improved0 and Regular selected. Only this retired
zero key is normalized away; nonzero retired ownership is never erased.
Pickup recovery is disabled for this multi-type carrier:
native increases are not credited to either saved pool. Standard and Ancient
Tomahawk single-type recovery is unchanged. See throwing-knife-multi-ammo.md.

Native identifiers were cross-checked against:
- https://github.com/femga/rdr3_discoveries/blob/master/weapons/weapons.lua
- https://github.com/femga/rdr3_discoveries/blob/master/weapons/ammo_types.lua

## Current catalog gate

Toxic Moonshine (internal Poison Bottle) passed reported manual checks at 39 weapons / 43 ammunition / 38 attachments and ten logical throwable positions. Native capacity eight and wheel naming are confirmed; smoke tests passed 5/5, 17/17 and 9/9. See [Toxic Moonshine live checks](poison-bottle-live-gate.md).

Standard Dynamite and Fire Bottle passed manual lifecycle checks. Current accepted catalog: 38 weapons / 42 ammunition / 38 attachments, nine logical throwable positions. Fire Bottle capacity eight, throw/unload conservation, and two successive resource restarts are verified; smoke tests passed 5/5, 17/17 and 9/9. See [Fire Bottle checks](fire-bottle-live-gate.md).

Gravesend (internal Ironspiked) and Brookstone (internal Intertwined) passed manual testing. Current accepted catalog: 36 weapons / 40 ammunition / 38 attachments, with seven logical throwable positions. Brookstone wheel naming and native capacity three are confirmed, and the release contract passed 9/9. See [Brookstone live checks](brookstone-bolas-live-gate.md). Historical counts above describe earlier gates, not the current catalog. Next: standard Dynamite, followed by Fire Bottle; Improved ammunition and cosmetics remain deferred.


## Standard Lasso accepted

Standard Lantern is retired from the active catalog and fresh-install seeds after failed wheel testing. Existing owned instances are preserved, not converted. Davy Lantern is the supported Lantern.

Reinforced Lasso and the one-equipped-Lasso policy passed reported manual checks on 2026-10-02. Both carriers may be owned, but only one Lasso-family carrier may be equipped at a time: the native wheel suppressed Regular when Reinforced was equipped. Final metadata confirms one Lasso and all ten throwables; lease checks passed 5/5 and release checks 9/9. Current accepted catalog: 41 weapons / 43 ammunition / 38 attachments. See [Reinforced Lasso live gate](reinforced-lasso-live-gate.md). Standard Lasso acceptance below describes the previous gate.

Lasso (`WEAPON_LASSO`) uses the independent `utility` slot and unique `weapon_lasso` item, with no ammunition. Manual checks passed on 2026-10-02; server metadata confirms coexistence with all ten throwable carriers and zero Lasso ammunition. Utility lease checks passed 5/5 and release checks 9/9; see [Lasso live gate](lasso-live-gate.md). Current accepted catalog: 40 weapons, 43 ammunition and 38 attachments.


Davy Lantern is a separate follow-up candidate (utility_davy_lantern / WEAPON_MELEE_DAVY_LANTERN).
Standard Lantern has native ownership but no observed wheel entry, including without Lasso.
Davy Lantern passed reported manual checks on 2026-10-02; screenshot confirms Light / Lantern wheel entry alongside Lasso. Metadata and client native ownership match; lease checks passed 5/5 and release checks 9/9 with 14 active slots. Standard Lantern remains unaccepted. After retiring Standard Lantern, the active catalog contains 42 weapon definitions, 43 ammunition and 38 attachments.
Existing Standard Lantern ownership and native mapping are preserved.

Standard Lantern has since been retired from the active catalog; owned carriers remain untouched.
Binoculars is the next candidate, using WEAPON_KIT_BINOCULARS and a third utility slot.
Candidate counts: 43 weapons / 43 ammunition / 38 attachments.
The live gate includes all four prior melee carriers alongside Lantern, one Lasso and throwables.
Logical slot names do not force wheel placement; tester observed Lasso bottom-left and Lantern bottom-right.
See [combined Binoculars/melee checks](binoculars-live-gate.md).

Binoculars and combined four-melee/three-utility manual checks passed on 2026-10-02.
Screenshot confirms Kit / Binoculars on the Items wheel. Metadata/runtime match for
all seven carriers; native ownership true. Lease 5/5, release 9/9, 19 active slots.
Current accepted catalog: 43 weapons / 43 ammunition / 38 attachments.

Standard Camera is the next candidate (utility_camera / WEAPON_KIT_CAMERA),
in a fourth logical utility position. Candidate catalog: 44 weapons / 43 ammunition / 38 attachments.
No photo storage integration is added; native view/exit and photo behavior require separate verification.
See [Camera live gate](camera-live-gate.md).

Camera equipment and wheel coexistence passed reported testing on 2026-10-02;
screenshot confirms Kit / Camera on the Items wheel alongside Binoculars.
User confirmed no default camera controls and scoped photography to a separate
optional add-on. Weapons retains only carrier ownership/equip/persistence responsibilities.
No camera controls or photo storage are implemented. Camera-specific lifecycle and
smoke results were not included in the initial submission. Follow-up source=3 metadata
confirms Camera item 133/serial FW-CAME-6AC097F2-28FAEF-0001 restored with runtimeMatch=true.
Lease checks passed 5/5; release checks passed 9/9 with 20 active slots.
Current accepted equipment catalog: 44 weapons / 43 ammunition / 38 attachments.

Advanced Camera is the next equipment-only candidate (utility_camera_advanced / WEAPON_KIT_CAMERA_ADVANCED),
using a fifth logical utility slot. Candidate counts: 45 weapons / 43 ammunition / 38 attachments.
Native wheel coexistence with Standard Camera remains unverified; photography belongs in a separate optional add-on.
See [Advanced Camera live gate](advanced-camera-live-gate.md).

Advanced Camera screenshot and supplied metadata/runtime confirm wheel access and both Camera carriers
owned/equipped simultaneously; lease 5/5 and release 9/9. Photography remains external.
Electric Lantern is the next separate candidate, with a sixth logical utility position.
Candidate counts: 46 weapons / 43 ammunition / 38 attachments; wheel and lighting unverified.
See [Electric Lantern live gate](electric-lantern-live-gate.md).


Electric Lantern retired on 2026-10-03 after nativeOwned=false and failed wheel access.
Removed from active catalog and fresh-install seeds; existing owned items remain untouched.
Stable utility_senary position retained. Davy is the supported Lantern.
Current active catalog: 45 weapons / 43 ammunition / 38 attachments.
See [Electric Lantern retirement](electric-lantern-live-gate.md).


Electric Lantern retirement fully confirmed: owned retired item retained/unusable,
slot cleared and release checks 9/9. Torch is the next candidate (utility_torch / WEAPON_MELEE_TORCH),
using the free sixth utility slot. Candidate counts: 46 weapons / 43 ammunition / 38 attachments.
See [Torch live gate](torch-live-gate.md); native wheel/light/melee behavior remains unverified.


Torch retired on 2026-10-03: native drop on holster/switch, native ownership lost
while saved carrier remained equipped, and Davy wheel suppression reported.
Removed from active catalog/fresh seeds; owned holders preserved, usable definition disabled by migration.
Current active catalog: 45 weapons / 43 ammunition / 38 attachments.
See [Torch retirement](torch-live-gate.md).

Hammer is the next agreed candidate (melee_hammer / WEAPON_MELEE_HAMMER),
with a fifth persistent melee position so all four previous models can coexist.
Candidate counts: 46 weapons / 43 ammunition / 38 attachments.
See [Hammer live gate](hammer-live-gate.md). Improved Binoculars, Metal Detector
and Fishing Rod follow. Hammer has now passed all user manual checks and its metadata/lease/release checks.

## Improved Binoculars candidate

utility_binoculars_improved / WEAPON_KIT_BINOCULARS_IMPROVED is ammunition-free unique equipment.
The existing utility_senary position provides a sixth utility carrier without a slot migration.
Candidate counts: 47 weapons / 43 ammunition / 38 attachments.
Native wheel visibility, controls and coexistence with standard Binoculars remain live-test gates;
native ownership alone does not prove wheel availability. No unlock writes or custom controls added.
See [Improved Binoculars live gate](improved-binoculars-live-gate.md).
Metal Detector and Fishing Rod remain after this gate; no commits are created automatically.

## Metal Detector candidate

Improved Binoculars passed manual checks, metadata and smoke gates; the native label is Refined Binoculars.
Metal Detector (utility_metal_detector / WEAPON_KIT_METAL_DETECTOR) uses the new seventh utility carrier.
Candidate counts: 48 weapons / 43 ammunition / 38 attachments. Equipment lifecycle only;
detection, collectibles and rewards belong to an add-on. Fishing Rod remains after this gate.
See [Metal Detector live gate](metal-detector-live-gate.md).

## Fishing Rod candidate

Metal Detector passed its equipment-only live gate. Fishing Rod (utility_fishing_rod /
WEAPON_FISHINGROD) is the final agreed catalog candidate and uses the eighth utility carrier.
Candidate counts: 49 weapons / 43 ammunition / 38 attachments. Bait, controls, catches and
rewards remain add-on scope. See [Fishing Rod live gate](fishing-rod-live-gate.md).
