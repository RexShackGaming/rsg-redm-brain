# Ammunition selection

Use an ammunition item in Inventory to select and load that type. The weapon
must be empty before changing types: unload its loaded rounds and reserve first.
Unloading returns the selected ammunition item, never the default as a substitute.
The selected type is saved in weapon metadata as ammo.type and restored on equip,
character login and resource restart. Existing untyped items use their definition's
default until a type is selected. No database schema change or crafting code is required.

Different-model sidearm pairs support shared or distinct ammunition types.
Use the slot-specific ammunition menu to inspect stock and load or unload the
selected weapon. Empty the weapon or shared pair before changing its type.
Matching weapon models are rejected. Distinct-type native pool and wheel
accounting still require live acceptance on the target build.
The weapon wheel is restricted to the approved type; choose another through Inventory.

Definitions use ammunitionType for the default and ammunitionTypes for the allowlist.
Validation rejects duplicate/unknown types and a default missing from the allowlist.
The existing LeMat shotgun-barrel mode is still outside this cylinder-only implementation.

## Automated checks

From the feather-weapons folder, run with Lua 5.4:

```text
lua tests/ammunition.lua
```

The suite exercises every catalog weapon/ammunition combination, exact-type unload,
restore, shot accounting, shared-pair selection, stale leases, incompatible requests,
and injected inventory failures. It mocks Inventory; it does not emulate RedM natives.

## In-game acceptance

1. Restart feather-weapons. Equip a weapon and unload all ammunition.
2. Use a compatible special-ammo item from Inventory, then run `weaponstate` in F8.
   Check the printed ammo type/native name and inventory count change.
3. Fire, reload, then unload. Verify only fired rounds are missing and returned items
   have the same type. Try using another type while loaded: it must reject without
   consuming inventory. Try an incompatible family: it must reject.
4. Load special ammo again, logout/rejoin, and restart the resource. Check that its
   type, total and condition survive. Check native special-ammo effects in game.
5. Repeat with Cattleman/Schofield pairs. Start with both empty,
   use the same ammo twice, fire both hands, unload both, then change types. Verify
   the shared total and the exact returned items. Test both equip orders.
   Confirm that a Cattleman/Cattleman pair is rejected before native state changes.
6. Repeat across pistol, repeater, rifle, shotgun, Varmint tranquilizer and Elephant.
   Native availability and special effects must be confirmed on the server's build.

Server-console regression commands (replace 1 with the player source):

```text
WeaponRuntimeLeaseSmokeTest 1
WeaponDualSlotContractSmokeTest 1
WeaponReleaseContractSmokeTest 1
```

Native signatures were verified against the public RedM native database:
https://github.com/alloc8or/rdr3-nativedb-data/blob/master/natives.json
The production implementation rejects matching weapon hashes.

## Distinct-type pair restore investigation

On a development server, enable `Config.DevMode` temporarily and prepare a
Cattleman with high velocity ammunition and a Schofield with regular ammunition.
Record each item's identity, selected type, total, loaded count, reserve, and
Inventory stock before restoring the pair. Use unequal totals so swapped or
combined pools are easy to detect.

Capture the `distinct pair pools` client log entries at `materialized`,
`offhand-normalized`, `primary-normalized`, and `settled`. Each stage reports
both item identities and generations, native weapon/ammo names, approved counts,
pool reads, clip validity, and pool-minus-approved delta. A failed clip read is
not evidence of an empty clip. These observations do not authorize ammo changes.

Compare the settled counts with `weaponstate` and the wheel for each hand.
Repeat with the weapons in opposite hands, partial clips, and one empty weapon.
Then fire each hand separately, reload, use each slot's Load/Unload actions,
holster/draw, logout/reselect, and restart the resource. Record counts after
each action. For each ammunition definition, initial Inventory plus weapon
rounds must equal final Inventory plus weapon rounds plus rounds fired.
Repeat with two players to check isolation.

For different-model sidearms, the inventory-GUID ammo readback is the readiness
authority because it identifies the specific weapon entry that was changed.
The weapon-hash ammo readback may remain on the model's regular/default type on
the target build and is diagnostic only. A GUID readback that does not match the
approved type still fails restore before either clip is populated.
Setting the existing GUID's ammo type must not be followed by GUID activation
for a different-hash production pair. The pair was already created at its native
attach points; live testing showed that reactivation can make both hashes
unavailable to the clip APIs.
For the same reason, distinct-sidearm aggregate totals do not use native
ammo-type pools or native per-GUID totals. Both can mirror one weapon's
materialized clip into the other type. Aggregate ownership is the approved item
escrow minus confirmed per-weapon clip consumption; mirrored native values are
presentation diagnostics only.
Immediately after the weapons are granted and before GUID selection or clip
materialization, restore pre-seeds each pool at its approved total minus every
loaded clip RedM's hash readback indicates it will credit to that pool. This
normalization exists only to make native wheel quantities agree with the owning
item; it does not authorize or persist ammunition.
Some models can materialize a readable clip without crediting that clip to the
ammo-type pool. After both clips are ready, restore adds only the measured
shortfall up to each approved total and requires exact pool equality. This
second normalization is also presentation-only and never changes item escrow.
An empty counterpart may still show the funded weapon's clip in its default
native pool. Because that item has zero approved rounds and fallback removes its
native weapon, the empty pool's presentation excess is tolerated; every funded
pool continues to require exact equality with its approved item total.
If a GUID readback transiently reverts during rapid consecutive menu mutations,
the bounded readiness loop reapplies that GUID's approved ammo type before the
next read. It never activates or moves the weapon and still fails closed if the
GUID does not converge before clip materialization.
An empty weapon does not require native ammo-type readiness because RedM may not
select a special type while its pool is zero. The persisted definition remains
selected, and the normal fail-closed GUID check runs again when ammunition is
loaded. With zero approved rounds and a zero clip, this exemption cannot convert
or create ammunition.
RedM may also omit the clip handle for an empty pistol. Pair restoration treats
that as ready only when both the approved total and approved loaded count are
zero; every nonempty weapon still requires an exact readable clip.

Keep live acceptance open if any pool, clip, wheel, or persisted count differs;
record the server build and the first stage that diverges. Restore
`Config.DevMode = false` after collecting evidence. The automated server suite
cannot validate native pool conventions or wheel presentation.
