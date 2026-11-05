# Native weapon instance coordinator

## Purpose

Feather weapon items are unique server-owned instances. RedM weapon hashes only
identify a model and cannot reliably preserve two equipped copies through every
wheel, holster, and restore transition. Production therefore rejects matching
hash pairs. The remaining coordinator owns restore preparation and bounded
native ammunition windows.

## Boundaries

- `FeatherGuidWeapons` remains a development probe and entitlement helper; it
  does not create production matching pairs.
- `FeatherNativeWeaponCoordinator` owns restore preparation and ammo windows.
- The existing client service continues to own ammunition observation, reload,
  condition checkpoints, attachments, reconciliation and presentation.
- Character emits `feather-character:client:runtime-ready.v1`; Weapons then
  requires the same carried-weapons parent GUID to remain stable across
  consecutive frames before restoring instances.

## Lifecycle

`idle -> preparing -> idle`

Failures enter `failed`. A release clears all coordinator-owned GUID records and
returns the coordinator to `idle`. Every creation or release advances an epoch
so later asynchronous work can reject stale operations.

## Integration phases

1. Reject matching native hashes at the server equipment-policy boundary.
2. Treat RedM ammunition totals as bounded runtime windows. Authoritative
   ownership remains the sum of Feather item escrows; confirmed per-GUID shots
   reduce it and the coordinator replenishes the native window from reserves.
3. Add isolated inspection for item ID, GUID slot, native model and entity.
4. Move distinct sidearms and long guns under the same identity registry.
5. Add one serialized restore transaction with explicit provisioning, ammo,
   activation and presentation stages.
6. Remove the legacy restoration path only after the complete live test matrix
   passes.

## Required live matrix

- Matching pairs rejected without removing either Inventory item.
- Distinct revolver/pistol pairs and different ammo families.
- Fresh join, resource restart, logout/login, death and player-ped replacement.
- Draw, fire, asymmetric depletion, reload, holster and weapon-wheel selection.
- Shoulder/back weapons using both shared and distinct native ammunition pools.
