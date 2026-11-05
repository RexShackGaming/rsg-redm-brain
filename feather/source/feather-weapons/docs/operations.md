# Feather Weapons Operations

## Ownership model

Inventory is authoritative for weapon ownership, unique item identity, serials,
native maintenance state, attachments, and accepted ammunition. RedM owns the live weapon,
draw/fire/reload behavior, animation, and contextual controls. Feather creates a
native weapon only for the currently equipped Inventory instance.

Client reports may decrease the active ammunition budget or redistribute its
loaded/reserve split. They cannot increase persisted ammunition, create an item,
change the item instance, or reuse a stale lease generation. Inventory
transactions and metadata revisions remain authoritative.

RedM's ammo-type value is the combined total after clip initialization. Restore
must clear the type, set the clip, and then set the approved total exactly once;
setting the total before the clip duplicates the loaded rounds.

Shot consumption and native maintenance are observed on the client because RedM
does not provide a trusted server-side ledger. A modified client can waste its
own ammunition or worsen its own weapon status by reporting increases in wear,
but cannot use this contract to gain
persistent ammunition or Inventory items. Treat anomaly logs as diagnostics,
not automatic proof of cheating.

## Installation and startup

Start Core, Character, Inventory, and Menu before Weapons. Use the recipe seed
for a clean installation, or run `sql/install_items.sql` after Inventory has
created its schema. Incompatible contracts and missing definitions always fail
startup closed; there is no partial-start option.

Weapons also validates every required Inventory definition at startup. The
Cattleman must be a usable unique weapon; revolver ammunition and gun oil
must be usable stacks; the Long Barrel must be a non-usable stack because it is
installed through the gunsmith menu. Missing names, duplicates, or mismatched
types/modes abort startup instead of disabling only part of the system.

Production defaults disable `DevMode` and the native probe. Enable them only on
a controlled development server, then disable them again before release.

## Recovery

Run `WeaponMetadataInspect [serverId]` from the server console first. It validates
the persisted equipped instance and reports its serial, ammunition, condition,
attachments, and whether the runtime references the same item.

If the runtime is inconsistent, run `WeaponReconcile [serverId]`. Reconciliation
invalidates the current lease generation, clears the native representation, and
restores the last accepted Inventory snapshot. It deliberately discards native
changes that were never accepted by the server.

Do not edit weapon metadata manually while a character is online. Restore the
database from backup for database corruption; reconciliation is not a schema or
data-repair tool.

## Integration

Trusted server resources issue unique weapons through:

```lua
local result = exports['feather-weapons']:IssueWeapon(request, context)
```

Use the named export at call time instead of retaining functions returned by
`initiate()` across a Weapons restart. Admin follows this rule for issuance and
re-resolves the catalog API whenever it is used.

Character logout uses an owner-scoped named checkpoint export. Character waits
for final maintenance and ammunition checkpoints before beginning Core session
teardown; the later logout event performs native cleanup only. Abrupt disconnects
and F8 quits cannot complete a final client request, so maintenance is committed
periodically while connected and `playerDropped` retains the latest accepted
server snapshot.

## Expected boundaries

- Logout waits for a final acknowledged checkpoint.
- Death checkpoints immediately and retains the active lease through revive.
- Hard disconnect restores the last already accepted bounded checkpoint.
- Character switching clears the old native weapon before restoring another
  character's persisted instance.
- Weapons restart clears native state and rehydrates active Core sessions.
- Server restart rehydrates only persisted Inventory state.
