# Attachment compatibility worksheet

Only verified native mappings are promoted from this worksheet into the live
catalog. Cosmetic materials, engravings, varnishes, wraps, and tints remain out
of scope until their representation and conflict rules are designed.

| Weapon | Slot | Attachment | Native component | Catalog state | Live state |
| --- | --- | --- | --- | --- | --- |
| Cattleman Revolver | Barrel | Cattleman Long Barrel | `COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG` | Shipped | Passed full lifecycle |
| Cattleman Revolver | Sight | Cattleman Wide Sight | `COMPONENT_REVOLVER_CATTLEMAN_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Schofield Revolver | Barrel | Schofield Short Barrel | `COMPONENT_REVOLVER_SCHOFIELD_BARREL_SHORT` | Shipped | Passed full lifecycle |
| Schofield Revolver | Sight | Schofield Wide Sight | `COMPONENT_REVOLVER_SCHOFIELD_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| LeMat Revolver | Barrel | LeMat Long Barrel | `COMPONENT_REVOLVER_LEMAT_BARREL_LONG` | Shipped | Passed full lifecycle |
| LeMat Revolver | Sight | LeMat Wide Sight | `COMPONENT_REVOLVER_LEMAT_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Navy Revolver | Barrel | Navy Long Barrel | `COMPONENT_REVOLVER_NAVY_BARREL_LONG` | Shipped | Passed full lifecycle |
| Navy Revolver | Sight | Navy Wide Sight | `COMPONENT_REVOLVER_NAVY_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Double-Action Revolver | Barrel | Double-Action Long Barrel | `COMPONENT_REVOLVER_DOUBLEACTION_BARREL_LONG` | Shipped | Passed full lifecycle |
| Double-Action Revolver | Sight | Double-Action Wide Sight | `COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| M1899 Pistol | Barrel | M1899 Long Barrel | `COMPONENT_PISTOL_M1899_BARREL_LONG` | Shipped | Passed full lifecycle |
| M1899 Pistol | Sight | M1899 Wide Sight | `COMPONENT_PISTOL_M1899_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Volcanic Pistol | Barrel | Volcanic Long Barrel | `COMPONENT_PISTOL_VOLCANIC_BARREL_LONG` | Shipped | Passed full lifecycle |
| Volcanic Pistol | Sight | Volcanic Wide Sight | `COMPONENT_PISTOL_VOLCANIC_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Semi-Automatic Pistol | Barrel | Semi-Automatic Long Barrel | `COMPONENT_PISTOL_SEMIAUTO_BARREL_LONG` | Shipped | Passed full lifecycle |
| Semi-Automatic Pistol | Sight | Semi-Automatic Wide Sight | `COMPONENT_PISTOL_SEMIAUTO_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Mauser Pistol | Barrel | Mauser Long Barrel | `COMPONENT_PISTOL_MAUSER_BARREL_LONG` | Shipped | Passed full lifecycle |
| Mauser Pistol | Sight | Mauser Wide Sight | `COMPONENT_PISTOL_MAUSER_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Carbine Repeater | Sight | Carbine Wide Sight | `COMPONENT_REPEATER_CARBINE_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Lancaster Repeater | Sight | Lancaster Wide Sight | `COMPONENT_REPEATER_WINCHESTER_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Litchfield Repeater | Sight | Litchfield Wide Sight | `COMPONENT_REPEATER_HENRY_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Evans Repeater | Sight | Evans Wide Sight | `COMPONENT_REPEATER_EVANS_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Springfield Rifle | Sight | Springfield Wide Sight | `COMPONENT_RIFLE_SPRINGFIELD_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Bolt Action Rifle | Sight | Bolt Action Wide Sight | `COMPONENT_RIFLE_BOLTACTION_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Varmint Rifle | Sight | Varmint Wide Sight | `COMPONENT_REPEATER_PUMPACTION_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Elephant Rifle | Barrel | Elephant Long Barrel | `COMPONENT_RIFLE_ELEPHANT_BARREL_LONG` | Shipped | Passed full lifecycle |
| Elephant Rifle | Sight | Elephant Wide Sight | `COMPONENT_RIFLE_ELEPHANT_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Rolling Block Rifle | Sight | Rolling Block Wide Sight | `COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Carcano Rifle | Sight | Carcano Wide Sight | `COMPONENT_RIFLE_CARCANO_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Repeating Shotgun | Barrel | Repeating Shotgun Long Barrel | `COMPONENT_SHOTGUN_REPEATING_BARREL_LONG` | Shipped | Passed full lifecycle |
| Repeating Shotgun | Sight | Repeating Shotgun Wide Sight | `COMPONENT_SHOTGUN_REPEATING_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Pump-Action Shotgun | Barrel | Pump-Action Long Barrel | `COMPONENT_SHOTGUN_PUMP_BARREL_LONG` | Shipped | Passed full lifecycle |
| Pump-Action Shotgun | Sight | Pump-Action Wide Sight | `COMPONENT_SHOTGUN_PUMP_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Semi-Automatic Shotgun | Barrel | Semi-Auto Shotgun Long Barrel | `COMPONENT_SHOTGUN_SEMIAUTO_BARREL_LONG` | Shipped | Passed full lifecycle |
| Semi-Automatic Shotgun | Sight | Semi-Auto Shotgun Wide Sight | `COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Double-Barreled Shotgun | Barrel | Double-Barreled Long Barrel | `COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_LONG` | Shipped | Passed full lifecycle |
| Double-Barreled Shotgun | Sight | Double-Barreled Wide Sight | `COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_WIDE` | Shipped | Passed full lifecycle |
| Sawed-Off Shotgun | Sight | Sawed-Off Wide Sight | `COMPONENT_SHOTGUN_SAWED_SIGHT_WIDE` | Shipped | Passed full lifecycle |

## Wide Sight acceptance matrix

- Install consumes exactly one component item.
- Wide Sight and Long Barrel can coexist as independent slots.
- Ammunition, loaded count, condition, serial, item identity, and lease remain unchanged.
- Primary, offhand, holstered, logout/re-entry, resource restart, and server restart restore both components.
- Removal returns exactly one component item and preserves the Long Barrel.
- Duplicate installation, incompatible weapon, stale lease, and occupied sight slot fail without consumption.

Native mappings are cross-checked against the model-specific component table in
`femga/rdr3_discoveries/weapons/weapon_components.lua` and must still pass visual
verification in the target RedM build.

## Definition rules

Attachment definitions declare explicit `conflicts` and `prerequisites` arrays.
Startup rejects unknown or self-referential prerequisites, prerequisite cycles,
conflicting prerequisite pairs, same-slot prerequisites, and prerequisites that
the weapon cannot install. Installation validates the complete resulting set
before consuming the component item. Removal likewise validates the remaining
set, so a prerequisite cannot be removed while an installed component depends
on it. Current shipped Cattleman components are independent and therefore use
empty prerequisite lists.

Weapons may also label the native baseline for each supported slot through
`attachmentDefaults`. Defaults are presentation metadata, not installed item
instances: they consume nothing, are not written to weapon metadata, and cannot
be removed into Inventory. The Cattleman exposes `Standard Barrel` and
`Standard Sight`; installing an upgrade replaces that slot's displayed default,
and removing the upgrade reveals the native default again.

## Wide Sight live result

The Wide Sight consumed and returned exactly one Inventory item, applied and
removed visibly, and preserved the Cattleman's identity, lease, ammunition, and
condition. It coexisted with the Long Barrel through resource restart, logout,
and full server restart in both primary and offhand roles. Duplicate installation
was unavailable without consuming the extra item, and an equipped Mauser exposed
no incompatible installation action.

## Schofield live result

The native Schofield baseline is the long barrel, so the initial Long Barrel
candidate was rejected during visual validation and replaced with the visibly
distinct Short Barrel. The Short Barrel and Wide Sight installed independently,
coexisted visibly, survived a Weapons resource restart, and removed selectively
with exact item returns. Removing the Short Barrel restored the standard long
barrel. Throughout the lifecycle the weapon identity, runtime lease, ammunition,
and condition remained aligned.

## LeMat live result

The Long Barrel and Wide Sight installed independently, coexisted visibly,
survived a Weapons resource restart, and removed selectively with exact item
returns. Removing the Long Barrel restored the standard shorter barrel while
preserving the Wide Sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Navy live result

The Navy native baseline uses the short-barrel component despite its long visual
profile. The Long Barrel and Wide Sight installed independently, coexisted
visibly, survived a Weapons resource restart, and removed selectively with exact
item returns. Removing the Long Barrel restored the standard shorter barrel.
The weapon identity, runtime lease, ammunition, and condition remained aligned.

## Double-Action live result

The native Double-Action baseline uses the short barrel. The Long Barrel and
Wide Sight installed independently, coexisted visibly, survived a Weapons
resource restart, and removed selectively with exact item returns. Removing the
Long Barrel restored the standard short barrel. The weapon identity, runtime
lease, ammunition, and condition remained aligned.

## M1899 live result

The native M1899 baseline uses the short barrel. The Long Barrel and Wide Sight
installed independently, coexisted visibly, survived a Weapons resource restart,
and removed selectively with exact item returns. Removing the Long Barrel
restored the standard short barrel. The weapon identity, runtime lease,
ammunition, and condition remained aligned.

## Volcanic live result

The native Volcanic baseline uses the short barrel. The Long Barrel and Wide
Sight installed independently, coexisted visibly, survived a Weapons resource
restart, and removed selectively with exact item returns. Removing the Long
Barrel restored the standard short barrel. The weapon identity, runtime lease,
ammunition, and condition remained aligned.

## Semi-Automatic live result

The native Semi-Automatic baseline uses the short barrel. The Long Barrel and
Wide Sight installed independently, coexisted visibly, survived a Weapons
resource restart, and removed selectively with exact item returns. Removing the
Long Barrel restored the standard short barrel. The weapon identity, runtime
lease, ammunition, and condition remained aligned.

## Mauser live result

The native Mauser baseline uses the short barrel. The Long Barrel and Wide Sight
installed independently, coexisted visibly, survived a Weapons resource restart,
and removed selectively with exact item returns. Removing the Long Barrel
restored the standard short barrel while preserving the Wide Sight. The weapon
identity, runtime lease, ammunition, and condition remained aligned throughout
the lifecycle.

## Carbine Repeater live result

The Wide Sight installed visibly in the shoulder slot, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Lancaster Repeater live result

The Wide Sight installed visibly in the shoulder slot, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Litchfield Repeater live result

The Wide Sight installed visibly in the shoulder slot, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Evans Repeater live result

The Wide Sight installed visibly in the shoulder slot, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Springfield Rifle live result

The Wide Sight installed visibly in the shoulder slot, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Bolt Action Rifle live result

The Wide Sight installed visibly in the shoulder slot, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Varmint Rifle live result

The unusually named `COMPONENT_REPEATER_PUMPACTION_SIGHT_WIDE` mapping produced
the correct visible Wide Sight on the Varmint Rifle. It survived a Weapons
resource restart and removed with an exact item return, restoring the standard
narrow sight. The weapon identity, runtime lease, ammunition, and condition
remained aligned throughout the lifecycle.

## Elephant Rifle live result

The native Elephant Rifle baseline uses the short barrel. The Long Barrel and
Wide Sight installed independently, coexisted visibly in the shoulder slot,
survived a Weapons resource restart, and removed selectively with exact item
returns. Removing the Long Barrel restored the standard short barrel while
preserving the Wide Sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Rolling Block Rifle live result

The Wide Sight was visibly present on the held scoped rifle, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Carcano Rifle live result

The Wide Sight was visibly present on the held scoped rifle, survived a Weapons
resource restart, and removed with an exact item return. Removal restored the
standard narrow sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Repeating Shotgun live result

The native Repeating Shotgun baseline uses the short barrel. The Long Barrel
and Wide Sight installed independently, coexisted visibly in the shoulder slot,
survived a Weapons resource restart, and removed selectively with exact item
returns. Removing the Long Barrel restored the standard short barrel while
preserving the Wide Sight. The weapon identity, runtime lease, ammunition, and
condition remained aligned throughout the lifecycle.

## Pump-Action Shotgun live result

The native Pump-Action Shotgun baseline uses the short barrel. The Long Barrel
and Wide Sight installed independently, coexisted visibly in the shoulder slot,
survived a Weapons resource restart, and removed selectively with exact item
returns. Removing the Long Barrel restored the standard short barrel while
preserving the Wide Sight. Removing the Wide Sight restored the standard narrow
sight. The weapon identity, runtime lease, ammunition, and condition remained
aligned throughout the lifecycle.

## Semi-Automatic Shotgun live result

The native Semi-Automatic Shotgun baseline uses the short barrel. The Long
Barrel and Wide Sight installed independently, coexisted visibly in the shoulder
slot, survived a Weapons resource restart, and removed selectively with exact
item returns. Removing the Long Barrel restored the standard short barrel while
preserving the Wide Sight. Removing the Wide Sight restored the standard narrow
sight. The weapon identity, runtime lease, ammunition, and condition remained
aligned throughout the lifecycle.

## Double-Barreled Shotgun live result

The native Double-Barreled Shotgun baseline uses the short barrels. The Long
Barrel and Wide Sight installed independently, coexisted visibly in the shoulder
slot, survived a Weapons resource restart, and removed selectively with exact
item returns. Removing the Long Barrel restored the standard short barrels while
preserving the Wide Sight. Removing the Wide Sight restored the standard narrow
sight. The weapon identity, runtime lease, ammunition, and condition remained
aligned throughout the lifecycle.

## Sawed-Off Shotgun live result

The Wide Sight installed visibly in the primary sidearm slot, survived a
Weapons resource restart, and removed with an exact item return. Removal
restored the standard narrow sight. The weapon identity, runtime lease,
ammunition, and condition remained aligned throughout the lifecycle.


## Same-model native restoration (2026-11-05)

Pair reconstruction now projects and restores each copy independently. Cattleman barrel/sight support uses the saved-attachments and GUID ownership runtime switches without DevMode. Worn pairs initialize permanent wear through the multiple-copy creation native and verify each copy independently. Mocked automated coverage passes; live worn/customized pair acceptance is pending. No saved metadata is rewritten to bypass restoration. See the framework master plan for current test gates.


2026-11-05: The earlier multiple-copy model-grant method is superseded. GUID-options activation and native inventory field17 initialization passed temporary-copy live tests (0.1 and0.25, exact readback/cleanup). Normal worn-pair creation now uses that method and passes automated checks; normal equipment/reconnect and combined attachment live acceptance remain pending.


2026-11-06 Cattleman live acceptance completed: unequal permanent wear in both carry roles and across reconnect; different Long Barrel/Wide Sight on separate copies; customized reconnect restoration; independent removal and exact component returns; wear and ammo preserved. Final231 revision2 pristine,128 revision10 permanent wear0.1. Other models and death/concurrency with customized pairs are not certified by this sequence.

2026-11-06 sidearm controls: paired guns can Swap hands; selected Primary can Unequip both sidearms in one sealed equipment transaction. Per-instance attachments/wear stay with the item; no ammo mutation or chained UI requests. Lone Primary explains the Offhand dependency. Automated policy/authority/CAS/rollback/final-wear tests pass; live button, drawing and reconnect checks remain pending. This does not extend attachment model coverage beyond the accepted Cattleman pair.

2026-11-06 user accepted the initial sidearm buttons live, then requested a simpler Primary removal. Updated behavior (automatically tested, LIVE PENDING): Primary — Unequip removes only that gun and promotes the existing Offhand gun to Primary atomically, preserving instance metadata; replaces the earlier Unequip both action. Swap hands remains. Panel explains the promotion through player locale text/English fallback. Final-wear identity changes, stale assignments and insert/session failures refuse/roll back the operation. No migration or new runtime file. Preserve feather_native_guid_ownership=1 at server startup for worn same-model pairs.

2026-11-06 Primary removal/Offhand promotion LIVE ACCEPTED: user confirmed all requested checks worked. Primary — Unequip leaves the removed gun in inventory and promotes the existing Offhand to Primary; re-equipping the other gun restores two drawable Cattlemans. Final Jane runtime ACTIVE ownedCopies2, idle/non-quiescing/non-receiving, no pending/closing/deathClosing; epoch3e84efcc-da1a-11f1-9f05-e0d55eaa2deb:1793994260:262267:3. Maintenance128 rev10 retains permanent/degradation/damage0.10000000149011 and dirt/soot0;231 rev2 remains pristine. Ammo ledger35 unchanged, repeater regular1 and remaining pools0. This accepts the revised single-action Primary removal/promotion and re-equip sequence in the observed unequal-wear Cattleman pair. Earlier Swap hands live acceptance remains valid. No further deployment or repeated test required to record this gate; commits/PRs remain deferred. Broader model, customized-pair death and concurrency acceptance remain outside this result.

2026-11-06 cleanup update (automated, live restart pending): GUID ownership defaults1 consistently; explicit0 still refuses worn pairs. Temporary pair-options diagnostic is test-support-only and absent from runtime manifest. Use docs/equipment-installation.md for current scope; older commands/default0 notes above are historical. Configs and saved reports are preserved by the paired prepared batch. Accepted Cattleman/controls results remain valid; only fresh missing-convar startup and drawing require live confirmation.

2026-11-06 fresh-start GUID default LIVE ACCEPTED: user explicitly confirmed both Cattlemans draw and the restart completed without a feather_native_guid_ownership console command or startup entry. Jane ACTIVE ownedCopies2, idle/non-quiescing/non-receiving, ammo active with no pending/closing/deathClosing; new session f7852ffe-da27-11f1-9f05-e0d55eaa2deb, epoch1794000076:171756:1. Item128 revision10 preserves permanent/degradation/damage0.10000000149011 and dirt/soot0;231 revision2 remains pristine. Ledger35/repeater regular1 and all other pools0 unchanged. This completes the requested cleanup/default live startup and drawing gate for the observed pair. Earlier accepted equipment and attachment tests need not repeat. No additional deployment/restart/test requested; commits, version bumps and PRs remain deferred. Probe exclusion is verified by manifest/source tests; user supplied no separate live probe-command absence check, and none is needed for this startup/draw gate.

2026-11-06 lifecycle-wear-enabled live shot/swap gate ACCEPTED from supplied runtime/maintenance evidence. After user changed server NativeAlphaLifecycleWearEnabled=true and restarted Weapons, baseline restored231rev2 pristine/128rev10 permanent-degradation-damage0.10000000149011, ammoledger38/regular0/repeater1. User loaded2 rounds and fired Primary231 once then swapped: ledger40/regular1;231rev3 retained degradation0.00333333341404/soot0.00499999988824, permanent-damage-dirt0;128rev10 unchanged. User fired newly Primary128 once and swapped again: ledger41/regular0/repeater1;128rev11 retained degradation0.10333333164453/soot0.00499999988824, permanent-damage0.10000000149011/dirt0;231rev3 previous wear unchanged. Both runtime checks ACTIVE ownedCopies2, no busy/quiescing/receiving/pending/closing/deathClosing; same session5c0906e5-da5d-11f1-9f05-e0d55eaa2deb, finalepoch1794028151:6415081:3. This accepts per-instance native shot-wear separation and persistence through ordinary swaps, expected one revision advancement per changed item, and two-shot shared ammunition conservation in the observed pair. It does not certify dual-wield firing (both rounds initially load Primary), customized-pair firing or reconnect after these shots. Next is normal client quit/reconnect, same revisions/metadata/ammo and both drawing; no file deployment, config change, server restart or additional ammunition needed. Local defaulttrue fix remains uncommitted on fix/lifecycle-wear-defaults; previously lost wear from the disabled period was not backfilled.

2026-11-06 post-shot client reconnect DATA gate PASSED: new Jane sessioncfc7fc8f-da6b-11f1-9f05-e0d55eaa2deb, epoch1794029215:7479185:4, ped147202; ACTIVE ownedCopies2, no busy/quiescing/receiving/pending/closing/deathClosing. Item231 revision3 retains degradation0.00333333341404/soot0.00499999988824 with damage/permanent/dirt0. Item128 revision11 retains degradation0.10333333164453/soot0.00499999988824, damage/permanent0.10000000149011/dirt0. Ledger41/revolver regular0/repeater regular1/other pools0 unchanged. Confirms saved per-instance shot wear, revisions and shared ammo survive the observed full-client reconnect. User has not yet separately confirmed both guns draw after this reconnect, so visual completion remains pending; no repeat data capture, file changes or restart needed. This does not add dual-wield/customized firing acceptance.

2026-11-06 post-shot reconnect visual COMPLETE: user explicitly confirmed both Cattlemans select and draw after the new-session readback. Combined observed gate now accepts separate Primary firing of each copy after Swap hands, exact two-shot shared-ammo consumption, independent wear saving across swaps and preservation/drawing across full-client reconnect. Final231rev3/128rev11 wear and ledger41 unchanged as recorded above. Next live scope is simultaneous dual-wield ammunition distribution and firing; that remains untested by this separate-primary sequence. No further reconnect repetition required.

2026-11-06 dual-wield firing/swap readback PASSED in observed Cattleman pair: after requested12-round load/two-shot dual-wield/holster/Swap hands sequence, user supplied ACTIVE ownedCopies2 settled status. Shared revolver regular10, repeater regular1, remaining pools0, ledger44. Item128 revision12 (was11) degradation0.10666666179895/soot0.00999999977648, permanent+damage0.10000000149011/dirt0. Item231 revision4 (was3) degradation0.00666666682809/soot0.00999999977648, permanent+damage+dirt0. Each gained one further shot's wear and one item revision, supporting independent per-copy wear persistence through the dual-wield/swap path and two-round shared-pool decrement. Final session927a9dee-da74-11f1-9f05-e0d55eaa2deb/epoch1794033534:11799038:6/ped2640386; session differs from prior reconnect evidence, so do not claim an uninterrupted session. No independent loose-round count or explicit visual narration accompanied this output; do not infer more than requested sequence and matching wear/ammo evidence. Next is ordinary UI unload of remaining10 rounds with10loose/0carried and same item revisions/wear/repeater1; no files/config/restart required. Does not certify customized firing or death/crash during firing.

2026-11-06 ordinary UI unload DATA readback PASSED: same Jane session927a9dee-da74-11f1-9f05-e0d55eaa2deb/epoch1794033534:11799038:6 ACTIVE settled ownedCopies2; revolver regular10->0, ledger44->45, repeater regular1 unchanged. Item128rev12 degradation0.10666666179895/soot0.00999999977648/permanent+damage0.10000000149011/dirt0;231rev4 degradation0.00666666682809/soot0.00999999977648/permanent+damage+dirt0 unchanged. Carried-ammo decrement and item conservation match expected unload. User has not yet explicitly confirmed10loose rounds returned; full round-trip conservation remains pending that inventory observation. No repeat F8 capture, deployment/config/restart needed for this confirmation.

2026-11-06 ordinary unload inventory observation CONFIRMED: user explicitly reports10regular revolver rounds back in inventory. Combined current pass COMPLETE in observed Cattleman pair: initial separate-primary two-shot ammo consumption, corrected lifecycle-wear-enabled per-instance shot wear saving across swaps, saved wear/ammo/revisions after full-client reconnect and both drawing, subsequent12-round load/two-shot dual-wield/matched wear increase, and remaining10-round unload with unchanged gun metadata/revisions and repeater1. Final ledger45/revolver0,10loose returned,128rev12 and231rev4 as recorded. Initial disabled-feature wear loss remains historical and was not backfilled. Local fix/lifecycle-wear-defaults defaulttrue change and regression tests remain uncommitted/unreleased; next recommended release work is a small Weapons patch to ship this default and prevent the same fresh-install wear-loss behavior. No additional live ammo matrix repetition needed. Separate future gap: customized same-model pair death/doctor recovery; broader firearm models, concurrency and arbitrary crash outcomes remain unclaimed.

2026-11-08 customized-pair death/recovery preparation: missing attachment options were resolved by enabling existing replicated saved_attachments and attachment_transactions switches and using normal bench/material policy (no new code/default change). User installed Long Barrel on231 and Wide Sight on128 and explicitly confirmed all requested manual visual/material checks passed. Both copies ACTIVE settled in Jane session669571d7-dbe7-11f1-9f05-e0d55eaa2deb/epoch1794192342:236062:3/ped156930. Item128revision13 (was12), saved damage/permanent0.10000000149011,degradation0.10666666179895,soot0.00999999977648,dirt0;231revision5 (was4),degradation0.00666666682809,soot0.00999999977648,damage/permanent/dirt0. Ledger45/revolver0/repeater1/other pools0 unchanged. This accepts attachment installation/consumption/visual separation on the fired-wear pair, not death recovery yet. Next load a small known balance using existing10 loose rounds (no grants), capture carried baseline, then ordinary admin death and MedicalRespawn recovery with attachment/wear/ammo/readback comparison. No file deployment/restart or diagnostic flags required.

2026-11-08 customized funded pair death/recovery FAILED despite visual observations passing. Before death: Jane128rev13 WideSight/wear0.10666666179895/permanent+damage0.10000000149011/soot0.00999999977648 and231rev5 LongBarrel/wear0.00666666682809/soot0.00999999977648; user loaded4regular revolver rounds, ledger46/repeater1. User says manual visual/inventory checks passed; Medical deadrevision23 then authorized doctor recovery/aliverevision24. Weapons stayed NOT ACTIVE/frozen, ownedCopies2/cleanupCompletefalse, oldepoch669571d7-dbe7-11f1-9f05-e0d55eaa2deb:1794192342:236062:3; ammo deathClosing/closingtrue, client reason dispatch_CheckpointAndSeal_failed, baseline still active/revision46/revolver4/repeater1. Maintenance owner not settled. Do not mark full recovery accepted or infer durable commit from client baseline. Generic dispatcher intentionally freezes on any failed service result; actual root refusal/commit outcome not established. Requested server console lines, especially WeaponNativeCheckpointAndSeal REFUSED and Inventory errors, asynchronously. Asked user to keep Jane idle and client/resources running to preserve evidence; no retries, restart, data edits or recovery repair requested. Current branchfix/lifecycle-wear-defaults has only prior resource-local checkpoint doc changes; no death fix implemented yet. Independent source review in progress; next step depends on detailed server refusal evidence.

2026-11-08 patched DevMode=false customized funded pair death/doctor recovery LIVE ACCEPTED: user supplied Medical deadrevision25, authorized doctor recovery and aliverevision26, then explicitly confirmed all requested manual checks passed (both drawable,231LongBarrel/128WideSight retained,6loose regular rounds). Weapons ACTIVE ownedCopies2, idle/non-quiescing/non-receiving; ammo active/no pending/closing/deathClosing; fresh epoch79f32aa5-dbeb-11f1-9f05-e0d55eaa2deb:1794194341:514638:2 replacing1794194003:176883:1 in same session/ped137218, deathRecovery references oldepoch. Ledger46/revolver regular4/repeater regular1/other pools0 unchanged. Item128rev13 retains degradation0.10666666179895,permanent+damage0.10000000149011,soot0.00999999977648,dirt0;231rev5 retains degradation0.00666666682809,soot0.00999999977648,permanent+damage+dirt0. Accepts observed differently customized unequal-wear Cattleman pair death/doctor reconstruction and ammunition/inventory conservation with Inventory normal-mode final-wear gate fix. No separate server death-seal message supplied; do not claim independently captured provider commit log, changed-wear-at-death or arbitrary crash/concurrency coverage. No further recovery test/deployment needed for this accepted gate. Inventory fix/native-death-wear remains uncommitted; next recommended work is Inventory patch version/PR preparation to ship ordinary death persistence with DevModefalse. Weapons runtime needs no companion code change for this fix.

2026-11-08 customized pair NEW SHOT -> DEATH -> doctor recovery LIVE ACCEPTED with Inventory normal-mode fix. User fired Primary128 once without swap/unequip, then invoked existing AdminDevKillSelf helper (normal permission/audit route), Medical deadrevision27 and aliverevision28, and explicitly confirmed requested manual checks passed (attachments/draw and6loose rounds). Runtime ACTIVE ownedCopies2 settled, new epoch79f32aa5-dbeb-11f1-9f05-e0d55eaa2deb:1794195200:1373944:3 from prior1794194341:514638:2, same session/ped137218, deathRecovery references oldepoch. Ledger47/revolver regular3/repeater regular1/other pools0. Item128revision14 (was13) saved degradation0.10999999195337/soot0.01499999966472, permanent+damage0.10000000149011/dirt0;231revision5 unchanged (degradation0.00666666682809/soot0.00999999977648/permanent+damage+dirt0). Confirms newly acquired per-gun shot wear survives the death final-save path, companion isolation and expected one-shot ammo consumption with customized same-model pair. No server final-seal/provider log supplied; this does not establish whether ordinary ammo checkpoint preceded death or prove simultaneous pending-shot+wear COMMIT timing. User used optional Admin selfkill diagnostic; instruct disabling feather_admin_dev_selfkill0 after this gate. No repeat death/data capture or deployment needed. Inventory fix remains uncommitted pending end-of-session PR; no new runtime change introduced by this accepted test.

2026-11-08 customized firearm storage round-trip LIVE ACCEPTED: user followed Primary128 unequip/promotion of231, deposit128 into existing storage, retrieval128 and Offhand equip, and explicitly confirmed all requested manual checks passed (128 left inventory/wheel while stored, WideSight retained, both draw,6loose revolver rounds). Final ACTIVE ownedCopies2 settled epoch79f32aa5-dbeb-11f1-9f05-e0d55eaa2deb:1794195928:2102301:5. Item128revision16 (was14, consistent with two storage moves), degradation0.10999999195337/soot0.01499999966472/permanent+damage0.10000000149011/dirt0 unchanged. Companion231revision5/degradation0.00666666682809/soot0.00999999977648/permanent+damage+dirt0 unchanged. Ledger47/revolver regular3/repeater regular1/other pools0 unchanged. Confirms observed customized firearm metadata/wear continuity through ordinary storage and character-owned ammo isolation. No independent immutable serial/provenance SQL comparison supplied; do not extend this to all transfer/ownership/crash paths. No files/config/restart or repeated round-trip needed. Inventory normal-mode death-wear fix remains pending end-of-session PR; storage test introduced no additional runtime changes.

2026-11-08 customized firearm cleaning/repair LIVE ACCEPTED. User enabled existing server NativeAlphaRepairEnabledtrue (DevModefalse retained), performed orderly Weapons-only restart, granted exactly1gun_oil through normal Admin inventory path, and cleaned128WideSight once. User explicitly confirms requested manual checks passed: oil consumed, WideSight retained, both guns draw. ACTIVE ownedCopies2 settled session5bc27192-dbf3-11f1-9f05-e0d55eaa2deb/epoch1794197718:3891959:2/ped119298. Item128revision17 (was16), degradation0.10000000149011/permanent+damage0.10000000149011,dirt0,soot0 (was0.01499999966472): repairable degradation removed while permanent wear retained. Companion231rev5/degradation0.00666666682809/soot0.00999999977648/permanent+damage+dirt0 unchanged. Ammoledger47/revolver regular3/repeater regular1/other pools0 unchanged. Accepts observed customized Cattleman repair cost/permanent floor/attachment isolation and companion/ammo conservation; no independent material SQL count supplied beyond user confirmation. No source default change made for repair (optional setting remainsfalse locally), no additional deployment or repeated cleaning needed. Pending code work remains Inventory normal-mode death-wear fix for end-of-session PR; no new runtime defect found by storage or repair tests.

2026-11-08 normal attachment/cleaning defaults IMPLEMENTED and AUTOMATED, fresh-start live gate PENDING. User authorized removing remaining setup friction and preserving explicit disables. Both repositories now on local feat/customization-defaults with previous session changes preserved/uncommitted. Weapons NativeAlphaRepairEnabled defaulttrue, with existing field cleaning/material/permanent-floor behavior; lifecycletrue/devfalse/periodicfalse unchanged. Production saved-attachment consumers (client factory, materialization, Cattleman mapping and server transition) use missing-convar default1; server attachment transaction and Inventory commit admission use matchingdefault1. Explicit replicated0 values override; transaction-only disable retains reconstruction, saved reconstruction0 refuses customized loadouts without stripping; explicit repairfalse disables cleaning. No new Config fields/locale selector or runtime script. Cattleman components and already-proved Carbine mapping admitted; Schofield/catalog/LeMat experimental gates stay closed. Normal bench/authorization/material/session/ownership checks retained; repair retains field-use policy. New real-shipped-config/default-switch/server-options test exercises actual attachment station/authorization and canonical policy, missing material, distance, configured permission, independent disables, saved reconstruction and no read-preview mutations. Existing native factory/manual diagnostic test explicitly disables saved reconstruction only for its manual probe; actual default-on projection is tested separately. Inventory export regression now tests DevModefalse/missing switch and explicit0 refusal. FullWeapons233Lua+7JS, fullInventoryLua+41Python pass, diff checks pass; UI unchanged. Prepared6-file combined batch at C:/coding/deployments/customization-defaults-2026-11-08, includes previous tested normal-mode death-save fix, preserves configs/reports and excludes tests/UI/manifests. WindowsPowerShell5 installer validated/installed5deltas from reconstructed previous-live baseline and readback all6content hashes, configs/report preserved; idempotent validation0deltas. All installer tests local C:/coding/deployment-checks only. No server changes, commits, version bumps, pushes or PRs. Existing server repair setting alreadytrue from accepted repair check; preserve it. One full-server fresh-start/no attachment console overrides, customized drawing/status and bench UI availability check pending. Do not repeat accepted death/storage/payment matrix. End-of-session PR bundling remains user preference.


### 2026-11-08 session release checkpoint

User confirmed a fresh server start without either attachment startup convar. Jane restored two customized Cattlemans, and the Equipment panel offered Remove Long Barrel and Clean / repair. No customization mutation was requested in this final defaults check. Ammo remained revision 47 with 3 regular revolver rounds and 1 regular repeater round. Item #231 remained revision 5 with degradation 0.00666666682809 and soot 0.00999999977648; #128 remained revision 17 at its permanent wear floor 0.10000000149011 with zero soot. This completes the previously pending missing-convar live check. Earlier accepted attachment, cleaning, death/doctor recovery, storage and reconnect checks remain recorded above.

Prepared patch versions: Weapons 0.21.2 and Inventory 0.14.1. Scope is default customization availability and normal DevMode=false death wear persistence; experimental model gates and periodic sampling remain unchanged. No commits, publication or additional server deployment are implied by this checkpoint.


### 2026-11-09 recorded firearm attachment catalog promotion

User confirmed the previously completed all-firearm sight/barrel testing; the compatibility worksheet already records 38 mappings and their live results. Production mapping admission now exposes the 36 non-LeMat entries with DevMode=false and no representative/catalog flags, using the existing saved-attachment/GUID switches and unchanged bench, permission, payment and ownership checks. LeMat's two tested components remain recorded but excluded from native reconstruction because dual-ammunition runtime policy is separate; visual component acceptance does not resolve that policy. No component/item names or native slot mappings changed.

Automated mapping coverage checks all admitted entries and component tampering; the actual saved-component factory/cleanup suite now runs with DevMode=false and no diagnostic flags. Full 233 Lua specs/runtime syntax passed. This is promotion of existing recorded visual evidence, not a claim of new live runtime tests for every model. A single production UI smoke check remains pending deployment; no repeat visual matrix is requested. Runtime delta is only shared/definitions/attachments.lua. No manifest, dependency, configuration, database or UI changes; no refresh required. No commits, pushes or release version bump yet.


2026-11-09 production-menu smoke check CONFIRMED: user screenshot of equipped Schofield shows Install — Schofield Short Barrel and Install — Schofield Wide Sight, alongside ordinary hand controls. This confirms the requested menu availability check after catalog promotion. No install/remove transaction, material consumption, fresh reconstruction, or per-model lifecycle retest is inferred from this screenshot. Existing recorded component visual results remain the basis for promotion. No further deployment or repeated firearm matrix is needed for this menu check.


### 2026-11-09 LeMat dual-pool implementation candidate (live pending)

Inspection found the current native host already reads/restores every character-owned ammunition type, including zero/unselected pools, and never persists clip counts. The old archived client had a LeMat clip-drop workaround; it is deliberately not copied into the current host, which does not infer expenditure from clip counts. Removed the exact LeMat registry/item rejection and added only ammo_shotgun_regular to its existing five revolver types. No new ammo IDs, pool ceilings, aliases, item quantities, native mode setters, database columns or migration. Mode selection remains the game's native control. Existing shared shotgun totals are shared with ordinary shotguns, not a private LeMat credit.

Both recorded LeMat components are now admitted in the candidate. Actual native factory projection/child cleanup tests cover all 38 mappings in DevMode=false. New LeMat composition checks actual catalog/item/materialization/native-pool/observe/transfer code with mocked native totals: distinct pools, mode no-op, independent shotgun/revolver spend, increase refusal, exact restoration, independent load/unload and unrelated-pool preservation. These checks do not prove engine behavior for mode switches, firing, reconnect or dual LeMats. Candidate must pass focused live single-LeMat mode readback before release; same-model dual-LeMat engine behavior remains unclaimed. No remote changes, commits, version bump or publication performed. Runtime files required for the combined candidate: shared/definitions/attachments.lua, shared/definitions/weapons.lua, shared/character_ammunition_catalog.lua, shared/character_ammunition_item.lua. No manifest/config/SQL/UI change or refresh required.

2026-11-09 LeMat candidate verification: full Weapons 234 isolated Lua specs/runtime syntax, 7 JavaScript checks and paired Inventory Lua regression suite passed. Native-pool composition is mocked; live LeMat mode behavior remains pending. No Inventory runtime changes are required. Awaiting whether Jane has an existing canonical LeMat before choosing the live fixture path; generic item grants are not substituted for canonical issuance metadata.

2026-11-09 live fixture preparation: Jane has no LeMat. Prepared deployment-only additive $25 Valentine shop offer (ID ending103) so normal paid checkout creates a canonical serial/metadata item with DevMode=false. No permanent Shops repository/catalog change. C:/coding/deployments/lemat-test-2026-11-09 includes four runtime files, payload hashes and Install-LeMatTest.ps1. Windows PowerShell5 validation/install/copy readback and resulting shop Lua syntax/three-offer prices passed against a local fixture; backups moved outside deployment payload. Installer preserves existing shop text and refuses unexpected multiple offer lists/IDs. No remote install or weapon purchase occurred.

2026-11-09 LeMat live baseline: paid checkout confirmed order29af31ef-dc90-11f1-9f05-e0d55eaa2deb / transaction2b0a3ed4-dc90-11f1-9f05-e0d55eaa2deb total2500 dollars. Jane equipped canonical LeMat263 revision0: ACTIVE one copy, settled runtime, all wear0. Ledger47 retains revolver regular3, shotgun regular0, repeater regular1. Screenshot shows revolver regular6loose/3carried and shotgun regular0loose/0carried in LeMat ammunition menu. Draw confirmation and firing/mode behavior not yet supplied. No consumption or lifecycle proof inferred.

2026-11-09 LeMat mode/spend LIVE CONFIRMED: user reports draw and native mode switching (including switching to load shotgun shell). Loading2regular shotgun rounds advanced ledger47->48 with revolver3/repeater1 unchanged. One shotgun shot advanced48->49, shotgun2->1, revolver3/repeater1 unchanged; LeMat263 native soot0.00499999988824/degradation0.00333333341404. User then confirms one revolver shot; final ledger50/revolver2/shotgun1/repeater1, native soot0.00999999977648/degradation0.00666666682809, otherwear0. One intervening unchanged status49 does not establish a tracking fault or its cause; final output confirms intended separate-pool expenditure. Item revision remains0 before a lifecycle wear seal. Reconnect/persisted wear recovery remains pending; no repeat shots needed.

2026-11-09 LeMat wear seal/full-client reconnect LIVE PASSED: following requested unequip/re-equip and reconnect, user confirms draw. New session93b93d2f-dc92-11f1-9f05-e0d55eaa2deb, ACTIVE1copy settled; ledger50/revolver2/shotgun1/repeater1 unchanged. LeMat263 revision1 with soot0.00999999977648/degradation0.00666666682809, dirt/damage/permanent0, matching pre-reconnect native wear. Confirms observed single-LeMat persistent restoration of both funded pools and sealed wear. No attachment mutation or dual-LeMat engine evidence inferred.

2026-11-09 single-LeMat funded death/doctor recovery LIVE PASSED: user confirms draw after MedicalRespawn/alive medicalrevision30. New runtime epoch93b93d2f-dc92-11f1-9f05-e0d55eaa2deb:1794266117:1694636:8 with previous epoch recorded in deathRecovery; ACTIVE1copy, runtimeBusy/quiescing/receiving/pending/closing/deathClosing false. Ledger50 unchanged with revolver regular2, shotgun regular1, repeater regular1. LeMat263 revision1 unchanged, soot0.00999999977648/degradation0.00666666682809/otherwear0. Completes focused observed single-LeMat draw, mode switching, independent funded firing, wear seal, full-client reconnect, and funded death recovery checks. Existing attachment visual matrix is not repeated. Dual-LeMat and mixed-sidearm engine mode behavior remains untested; no broad dual-mode pair certification inferred. No new deployment or commands required for this completed gate.

2026-11-09 mixed LeMat263 Primary/Cattleman231 Offhand LIVE firing checks PASSED: user confirms earlier individual/dual draw checks. Starting ledger50/revolver2/shotgun1/repeater1. One individual Cattleman shot ->ledger51/revolver1/shotgun1/repeater1; only231 nativewear increased to soot0.01499999966472/degradation0.00999999977648, LeMat stayed soot0.00999999977648/degradation0.00666666682809. One individual LeMat shotgun shot ->ledger52/revolver1/shotgun0/repeater1; only263 nativewear increased to soot0.01499999966472/degradation0.00999999977648,231 unchanged. Bothcopies active/settled; current revisions263=1/231=5 before final wear seal. Confirms observed shared revolver accounting and alternate-pool/per-copy wear isolation with mixed sidearms; dual-wield simultaneous firing, reversed roles, dual-LeMat and post-seal mixed-pair restoration remain unclaimed.

2026-11-09 mixed pair reversed carry roles LIVE PASSED: user confirms bothdraw after Swap hands. Cattleman231 Primary revision6 and LeMat263 Offhand revision2, both saved soot0.01499999966472/degradation0.00999999977648/otherwear0. Fresh active epochending2287188:10, two copies settled; ledger52 unchanged/revolver1/shotgun0/repeater1. Confirms mixed-pair wear seal and reverse-role draw. Offhand LeMat alternate-mode firing not yet tested.

2026-11-09 Offhand LeMat shotgun firing LIVE PASSED: following one shotgun-round load and one requested individual Offhand LeMat shot, ledger52->54, final revolver1/shotgun0/repeater1. Cattleman231 revision6 wear unchanged soot0.01499999966472/degradation0.00999999977648. Only LeMat263 nativewear increased to soot0.01999999955296/degradation0.01333333365619, revision2 before next seal. Two active settledcopies. Observed mixed-pair carry roles, separate-pool accounting and per-copy wear isolation now pass; simultaneous dual-mode firing and two-LeMat engine behavior remain unclaimed.

2026-11-09 dual-LeMat initial creation/draw LIVE PASSED: user confirms bothdraw; ACTIVE2copies/settled fresh epochending2716861:11. Maintenance order indicates new LeMat267 Primary revision0/cleanwear and LeMat263 Offhand revision3 retaining soot0.01999999955296/degradation0.01333333365619/otherwear0. Ledger54/revolver1/shotgun0/repeater1 unchanged. Confirms observed same-model dual-LeMat creation with unequal saved wear; firing/mode attribution and restored dual-pair lifecycle not yet tested.

2026-11-09 same-model dual-LeMat individual shotgun shots LIVE PASSED: load2shells and one Primary267 shot produced ledger56/revolver1/shotgun1/repeater1; only267 nativewear increased from0 to soot0.00499999988824/degradation0.00333333341404. Subsequent individual Offhand263 shotgun shot produced ledger57/revolver1/shotgun0/repeater1; only263 nativewear increased to soot0.02499999850988/degradation0.0166666675359,267 unchanged. Current revisions267=0/263=3 before wear seal; both copies active and settled. Confirms observed per-copy native wear identity and shared alternate-pool spending with two LeMats. Saved dual-pair reconnect/restoration and simultaneous dual firing remain untested.

2026-11-09 dual-LeMat reconnect BLOCKED: after requested Swap hands/full-client reconnect, user reports pair_creation_failed at native creation line286 holster_entities_not_settled. Status frozen epochdc1a924e-dc96-11f1-9f05-e0d55eaa2deb:1794267613:3191021:13, ownedCopies0/sessioncopies0/ammo closed/notpending, cleanupCompletefalse. Do not equate zero owned firearm copies with aggregate cleanupComplete. No database readback or retained setup-resource cleanup independently confirmed. No automatic retry or fixture repair requested.

Targeted candidate fix: zero-permanent LeMat pairs now use the existing explicit GUID/options Primary-then-Offhand activation and per-copy permanent0 readback path used for permanent-worn pairs. Previously both LeMats had permanent0 and therefore used legacy inventory-slot activation despite nonzero ordinary degradation. Other zero-permanent models keep their accepted path, and worn pairs keep existing behavior. Timeout unchanged, no fallback/model regrant/automatic retry, no ammo/clip/mode/economic writes. Added zero-permanent LeMat GUID point-bound activation regression (fails old path), distinct identities and compensation/uncertainty tests. This is a candidate for the observed settlement failure, not proof of its exact engine cause. Live reconnect retry pending installation. Runtime patch only client/character_ammunition_creation_native.lua; no manifest/config/SQL changes or refresh required.


### 2026-11-09 automated GUID creation validation IMPLEMENTED; RedM run pending

User requested automated engine validation before replacing the remaining model-grant/legacy paths. Added a validation-only guid_candidate_v1 factory policy: exact GUID inventory insertion, preserved record update/readback, explicit carry-point options activation, distinct GUID capture, permanent/ordinary wear readback, attachment reconstruction and exact cleanup for singles, mixed pairs and matching pairs. Gameplay does not select this policy; accepted production creation remains unchanged apart from the previously prepared LeMat reconnect candidate. The production PairOptions API stays hand-point restricted; separate candidate GuidOptions accepts2/3/9/10. Partial single-creation uncertainty now propagates through attachment binding and the executor instead of being silently dropped.

Generated matrix: 24 firearms, 1800 deterministic cases. Every valid carry position and ordered pair is covered using clean and customized/per-copy unequal wear profiles; Offhand includes a required Primary anchor. Cross hand/longgun cases and representative four-slot loadouts are included. This is pairwise coverage, not exhaustive permutations of every four-firearm combination. Case readbacks verify exact point GUID/entity identity, distinct copies, full wear, component manager success, unchanged native pools, unchanged temporary plans and no residual firearm models after cleanup. No native mode/clip/ammo total writes are added by the runner. No saved equipment/item grants/purchases/metadata writes are requested. In-game draw animations/appearance still need a short final visual check.

Console WeaponGuidAcceptance run [current-server-id] requires explicit feather_native_guid_suite=1; missingID discovers exactly one active player. It runs in DevMode=false, supports arbitrary current player identity, uses challenged client evidence and the normal coordinator dry-run seal/release, holds rebuild until validation cleanup is confirmed, then restores original loadout to a fresh epoch. Before/after Inventory snapshots and restored client views must match. Initial unsaved native wear is refused with guidance to seal first; the suite does not backfill or repair it. Inventory extends only the trusted SELECT-only audit to a single current actor under the new opt-in; legacy two-character developer audit remains gated. New run blocks unresolved reports; explicit archive only preserves evidence and clears the diagnostic report, never runtime holds. Cancel stops case progression; uncertainty or deadline retains the report and blocks restoration. No automatic retries or fixture repair.

Limits:15seconds per case (native helper waits remain bounded),30minutes overall; 31minute reserved coordinator timeout only for this suite. Progress every10cases and detailed report native-guid-acceptance-report.json in Weapons. Default disabled/reset off at resource start. Console status/cancel/visual pass|fail/archive commands. Only confirmed-clean failures may restore the original loadout; unknown native ownership remains held. Server/client source/ticket/session/candidate/snapshot/cleanup and matrix tests pass with mocked natives; these are not RedM engine acceptance.

Verification:237 Weapons isolated Lua specs/runtime syntax,7JS; Inventory Lua suite and41Python checks pass. Prepared C:/coding/deployments/guid-acceptance-2026-11-09 with13runtimefiles acrossWeapons/Inventory and configuration/report-preserving SHA256/baseline installer. Weapons manifest lists3newruntime files (shared/client/server), so refresh required. No SQL migration/config/UI/build or permanent Shops change. Local WindowsPowerShell5 validation/install/hash readback/idempotence tested; remote run remains pending. No commits, version bumps, pushes or PRs.

2026-11-09 GUID suite final hardening: each inserted candidate GUID is tracked through creation/compensation and independently checked unreadable after acknowledged removal, including already-compensated failure attempts. A disappearing model alone is insufficient; unknown absence stays held. Native activation point/expected GUID/output GUID/return/call-completion evidence is included in failure/success case observations. Optional throwable registry entries are excluded from the firearm matrix. The finalized matrix remains24firearms/1800cases; the earlier commentary count1320 was preliminary/incorrect and is superseded. Offline237Lua/7JS and InventoryLua/41Python passed; actual engine suite not run.

2026-11-09 GUID suite live run NOT STARTED: production dual-LeMat cold restore refused pair_options_activation_failed at creationline344. Console suite correctly refused because no active native owner existed; supplying a serverID is not a bypass. Exact failed activation point/return was not exposed by that build. No matrix cases or original-loadout suite release occurred.

Prepared targeted readiness/diagnostic candidate in client/character_ammunition_creation_native.lua: for LeMat and validation-only GUID pairs, after Primary activation is accepted, select unarmed and use the existing bounded wait to observe the exact inserted Primary GUID/entity at point2 before activating Offhand. Does not replay either native activation, lengthen existing timeout, adopt a foreign GUID, alter ammunition/metadata or broaden normal Cattleman behavior. All explicit GUID activations now preserve native return/expectedGUID/outputGUID/point in the failure message. Delayed-Primary mocked regression fails before and passes after; foreign Primary GUID times out without attempting Offhand. This addresses a plausible cold-start readiness race; exact live cause/fix remains unconfirmed until updated startup output. No repeat weapon matrix or report reset needed because suite never started. Single runtime-file patch; no refresh/config/SQL required.


### 2026-11-09 GUID native matrix completed; final report transport failure

Live console reached1800/1800 lastcasefour-slot:shotgun_sawedoff:customized. Original client increments progress only after each case and cleanup pass, so all1800 native cases completed on the client. The run did NOT complete end-to-end: CFX reported packet serialization failure and the server never obtained a usable final cleanup/report result; normal restoration was correctly held with guid_suite_cleanup_unconfirmed. User F8 independently shows normal owner CLOSED/quiescing, cleanupCompletetrue/ownedCopies0. Historical server cleanupCompletefalse means missing final acknowledgement, not an observation of retained guns. No saved-item/ammo mutation or fixture repair is inferred from the diagnostic hold (commitOutcomeconfirmed/committedfalse). Old client build did not persist the full result beyond its final send, so detailed per-case data is unavailable; preserve the1800-pass progress and original failure report. Do not retroactively mark the original suite complete.

Implemented bounded report transport v2: JSON-string chunks<=6000bytes/<=50rows, ordered source/ticket/session-bound receipts, byte-identical duplicate handling, compact summary, file-readback before final acknowledgement, cached client results/packets and report-only retransmission. Ack retries never rerun native creation or economic mutations. Capped3attempts/packet and3minute report-delivery window; normal native matrix cap30minutes, reserved server deadline adjusted to allow delivery/restore (34m20s). Lost final acknowledgement can be answered from a bounded completed receipt, including a late acknowledgement. Client resend reuses identical cached bytes. No whole1800-row table is sent as a single net event.

Added console recover: ONLY original character in a fresh active session, a prior1800/1800 run without final native report, exact unchanged durable snapshot, and matched actual restored client state qualify. Native wear-only float roundtrip tolerance1e-6; saved metadata/revisions/ammo/assignments remain exact. Archives original failure evidence and records recovered_transport_failure/restoredtrue without clearing historical unknown cleanup or claiming detailed native evidence. This performs reads/evidence writes only, never replays native cases or changes SQL/runtime reservations. Refuses any changed durable data without repair.

Added console transport: sends1800 synthetic four-observation report rows via the actual new client/server packet protocol with no native creation/removal/release/equipment change. Kindreport_transport_only / phasetransport_complete distinguish this from engine certification. Intended next live sequence is one three-file patch, fresh client/server start, recover original saved loadout, then transport-only check; no repeat weapon creation matrix is requested now. New in-memory client report caching helps future sends but cannot recover the old discarded report retroactively.

Offline validation:238WeaponsLua/runtime syntax and7JS pass. New>1MB/1800-row packet test produces450bounded packets plus compact summary; source/stale ticket/duplicate/lost/no acknowledgement, retained client data, no native replay, zero-native transport-only orchestration, changed-snapshot refusal and fresh-session read-only recovery covered. Native packet delivery and operational recovery remain LIVE PENDING. Three-file patch: shared/native_guid_acceptance.lua,client/native_guid_acceptance.lua,server/services/native_guid_acceptance.lua. No new manifest/config/SQL/Inventory/UI changes and no refresh required. No commits/versions/PRs.

2026-11-09 report recovery and bounded transport LIVE PASSED: user console recover reports recoveryconfirmed / phaserecovered_transport_failure / restoredtrue,1800historical passes, automaticMutationRetries0. This proves current saved Inventory/ammunition/metadata/equipment matched original snapshot and the fresh active original loadout matched the original client view (native wear rounding tolerance only). Historical cleanupCompletefalse/reason remain original missing-final-report evidence, not current retained-copy evidence. Original native run is not retroactively marked complete and its detailed old client report remains unavailable.

Subsequent transport-only live check: phasetransport_complete,kindreport_transport_only,receivedCases1800/total1800/passed1800,cleanupCompletetrue,reportDeliveryRetries0,automaticMutationRetries0,visualnot_applicable. Confirms actual RedM delivery of all1800synthetic detailed case rows through bounded JSON chunks/acknowledgements without weapon creation/release/equipment edits. No repeat native matrix occurred. Next implementation gate is deliberate production GUID-path consolidation using the observed1800native-case client completion plus separate recovery/transport proof; do not mislabel transport-only rows as new native tests or an end-to-end native run. No additional deployment/retest requested by this result.


2026-11-09 production consolidation: all firearm creation now shares the GUID inventory/point-activation factory, including clean/worn matching pairs and mixed loadouts. No model-grant or legacy slot-activation fallback remains in this factory. The runner now exercises that production implementation; 239Lua and7JS offline checks pass, including all supported component reconstructions. Final unattended1800-case production engine run and restored-loadout visual check remain pending. See docs/guid-creation-validation.md and the framework master plan for current evidence; prior historical candidate notes above are preserved.


### 2026-11-09 unified production GUID engine acceptance LIVE PASSED

User supplied actual native_creation run completion: passed1800/total1800/receivedCases1800, phasecomplete, cleanupCompletetrue, restoredtrue, reportDeliveryRetries0, automaticRetries0 and automaticMutationRetries0. The normal equipment dry-run also reports final seal/owned cleanup/server release/fresh same-session restore PASS with no equipment/ammo economic writes. User recorded visualpass and status retained complete/1800/restored/cleanuptrue. This closes the final end-to-end production creation matrix, bounded report delivery, original-loadout restore/comparison and short visual gate. It is a new native_creation result, separate from the historical transport failure and synthetic transport-only proof; those records remain preserved. The detailed report remains native-guid-acceptance-report.json in the server Weapons resource; this documentation records supplied console evidence, not a locally retrieved report.

Post-run F8 confirms Jane ACTIVE with2ownedcopies, idle/nonquiescing/nonreceiving runtime, active ammo with pending/closing/deathClosingfalse. Character6a2fd060-c46f-11f1-9ae2-e0d55eaa2deb, session45318af3-dcb5-11f1-9f05-e0d55eaa2deb, epochending1794280675:2912132:1. Ledger57 unchanged: revolverregular1, repeaterregular1, shotgunregular0, allotherpools0. Normal runtime cleanupCompletefalse is expected while the restored loadout owns2copies; the test report cleanupCompletetrue describes temporary suite copies. No further deployment, restart, SQL or repeated matrix is needed for this accepted gate.

Scope remains24firearms/1800pairwise and representative four-slot clean/customized cases, plus a final original-loadout draw check; this does not claim exhaustive four-way permutations or visual animation inspection of every temporary case. Commit/version/PR preparation remains separate and has not been performed by recording this result.
