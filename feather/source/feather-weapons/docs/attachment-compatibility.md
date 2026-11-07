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
