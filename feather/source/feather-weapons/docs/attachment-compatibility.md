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
