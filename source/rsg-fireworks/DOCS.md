# RSG Fireworks — Technical Documentation

Server-owner and developer reference for `rsg-fireworks` 2.0.1.

---

## Contents

1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Exports](#exports)
4. [Events](#events)
5. [Integration examples](#integration-examples)
6. [Persistence and saving](#persistence-and-saving)
7. [Security model](#security-model)
8. [Database schema](#database-schema)
9. [Server owner how-tos](#server-owner-how-tos)
10. [Troubleshooting](#troubleshooting)
11. [Support](#support)

---

## Architecture

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Resource manifest. Loads the rsg-core locale loader, config, client and server scripts. |
| `shared/config.lua` | All tunables: durations, fuse, placement distance, sound, anti-abuse limits and display definitions. |
| `client/client.lua` | `rsg-gizmo` placement, particle/explosion playback, prop spawning, display command registration and cleanup. |
| `server/server.lua` | Usable-item handling, pending placement tokens, `rsg-gizmo` validation, item removal, broadcast validation, permission checks and rate limits. |
| `server/versionchecker.lua` | Optional startup check against the RexShack version-checker repository. |
| `locales/en.json` | Player-facing strings. |
| `installation/shared_items.lua` | Paste-in item definitions for `rsg-core/shared/items.lua`. Not a standalone script. |

Prop placement is delegated to `rsg-gizmo`; this resource never implements its own ghost, raycast or rotation loop.

Flow when a player uses an item:

1. `rsg-core` calls the registered `CreateUseableItem` handler in `server/server.lua`.
2. The server validates the player and item, then stores a short-lived pending placement token. The item is **not** removed yet.
3. The client runs the blocking `exports['rsg-gizmo']:Place(...)` export. On confirm it reports the coordinates and rotation to the server; on cancel it notifies the server and the token is cleared.
4. The server re-validates the coordinates with `exports['rsg-gizmo']:IsPlacementValid`, sanitises the rotation with `SanitiseRotation`, removes one item through `rsg-inventory`, and consumes the token.
5. The server tells the placer client to spawn the prop and ignite it. After `Config.FuseTime` the server broadcasts the particle effect to all clients.
6. The placer runs the explosion loop locally and deletes the prop afterwards; other clients play the particle effect.

---

## Data formats

### Items

| Item | Label | Weight | Useable |
|---|---|---:|---|
| `firework_big` | Big Firework | 1000 | `true` |
| `firework_small` | Small Firework | 500 | `true` |

Both items are non-unique and carry no metadata.

### Display definition

```lua
{
    name = 'Valentine Display',        -- unique, used by the server to validate
    command = 'valfireworkdisplay',    -- unique chat command
    fireworks = {
        {
            type = 'small',            -- 'small' | 'big'
            coords = vector3(x, y, z),
            delay = 0,                 -- milliseconds
        },
    },
}
```

### Firework type table (client)

`FireworkTypes` in `client/client.lua` defines the prop model, particle asset, effect name, scale, explosion type, vertical offset and duration for each `type` value. Both firework types use the `s_firework01x` model.

---

## Exports

This resource exposes no exports.

---

## Events

### Client events

| Event | Direction | Parameters | Description |
|---|---|---|---|
| `rsg-fireworks:client:firework_big` | server → client | none | Start the big-firework placement flow. |
| `rsg-fireworks:client:firework_small` | server → client | none | Start the small-firework placement flow. |
| `rsg-fireworks:client:ignite` | server → placer | `item: string`, `coords: vector3`, `rot: vector3` | Spawn the validated prop, run the fuse and firework explosions. |
| `rsg-fireworks:client:big_fireworks_players` | server → all clients | `coords: vector3` | Play the networked big-firework particle effect. |
| `rsg-fireworks:client:small_fireworks_players` | server → all clients | `coords: vector3` | Play the networked small-firework particle effect. |
| `rsg-fireworks:client:display` | server → all clients | `displayName: string` | Run a configured display sequence. |
| `rsg-fireworks:client:display_big_firework` | client (internal) | `coords: vector3` | Play one big firework with explosions. |
| `rsg-fireworks:client:display_small_firework` | client (internal) | `coords: vector3` | Play one small firework with explosions. |

### Server events

| Event | Direction | Parameters | Description |
|---|---|---|---|
| `rsg-fireworks:server:place` | client → server | `item: string`, `coords: vector3`, `rot: vector3` | Confirm an `rsg-gizmo` placement. Requires a pending item use and passes `IsPlacementValid`. |
| `rsg-fireworks:server:cancel` | client → server | `item: string` | Report a cancelled placement and clear the pending token without consuming the item. |
| `rsg-fireworks:server:display` | client → server | `displayName: string` | Request an admin display. Permission-checked. |

All incoming events validate argument types and reject invalid payloads silently. Player-facing failures use rsg-core notifications.

---

## Integration examples

### Trigger a display from a trusted server resource

```lua
TriggerClientEvent('rsg-fireworks:client:display', -1, 'Valentine Display')
```

This bypasses the admin command check, so only call it from resources you control.

### Grant a firework item

```lua
exports['rsg-inventory']:AddItem(source, 'firework_big', 1, nil, nil, 'event-reward')
```

### React to a validated firework placement

```lua
AddEventHandler('rsg-fireworks:server:place', function(item, coords, rot)
    print(('Firework %s placed at %.1f, %.1f, %.1f'):format(item, coords.x, coords.y, coords.z))
end)
```

---

## Persistence and saving

The resource stores no persistent data. Pending tokens and cooldown tables live in server memory and are cleared when a player drops. All firework state is transient.

---

## Security model

### What the resource enforces

- **Item removal is server-side** — `exports['rsg-inventory']:RemoveItem` is called only after the player, the item definition and the `rsg-gizmo` placement have all been validated. Cancelling a placement never consumes the item.
- **No item, no firework** — a pending token is created by a successful item use and is required by `rsg-fireworks:server:place`; it is consumed on valid placement and expires after `Config.PendingFireworkTimeout`.
- **Item type match** — the reported item must match the token issued for that player.
- **Server-side placement validation** — `exports['rsg-gizmo']:IsPlacementValid(source, coords, Config.PlacementDistance)` re-checks that the coordinates are finite and within range of the player's ped, regardless of what the client reports.
- **Outdoor only** — `rsg-gizmo` is called with `allowInterior = false` (unless `Config.AllowInteriorPlacement` is enabled), so placement is rejected while the player or the prop is inside an interior. A guarded server-side interior re-check is also applied where the RedM build exposes the interior natives.
- **Rotation sanitising** — `exports['rsg-gizmo']:SanitiseRotation(rot)` converts untrusted rotation input into a safe `vector3`.
- **Rate limits** — `Config.BroadcastCooldown` per player and `Config.DisplayCooldown` per admin.
- **Permission check** — display requests require `RSGCore.Functions.HasPermission(source, 'admin')` or an ACE allowance for `command`.
- **Argument validation** — coordinates must be `vector3`, item and display names must be strings, and display names must exist in `Config.Displays`.
- **Cleanup** — `playerDropped` clears per-player state; `onResourceStop` removes tracked particles and objects.

### What calling resources must check

If another resource triggers `rsg-fireworks:client:display` directly, it is responsible for its own permission checks. The client event itself is a visual broadcast and intentionally does not re-check permissions because it may be triggered for events, cutscenes or scheduled shows.

---

## Database schema

None. This resource does not query the database.

---

## Server owner how-tos

### Change how long a firework lasts

Set `Config.BigFireworkTime` or `Config.SmallFireworkTime` in `shared/config.lua` (seconds).

### Disable firework sound

Set `Config.EnableSound = false`.

### Make fireworks stricter

- Lower `Config.PlacementDistance` to reduce how far from the player a firework may be placed.
- Raise `Config.BroadcastCooldown` to slow repeated ignitions.
- Raise `Config.DisplayCooldown` to limit admin display spam.
- Lower `Config.PendingFireworkTimeout` to shorten the window between item use and placement.

### Change the fuse

Set `Config.FuseTime` in `shared/config.lua` (milliseconds). The server uses the same value to delay the particle broadcast to other clients.

### Allow or block indoor placement

`Config.AllowInteriorPlacement` defaults to `false`, which uses the `rsg-gizmo` interior rule and rejects placement while the player or the prop is inside an interior. Set it to `true` only if you want fireworks usable inside buildings.

### Add a display command

Add an entry to `Config.Displays` with a unique `name` and `command`, then restart the resource. The command is registered automatically for every client.

### Change who can run display commands

Edit the permission check in `server/server.lua`:

```lua
if not (RSGCore.Functions.HasPermission(source, 'admin') or IsPlayerAceAllowed(source, 'command')) then
```

For example, restrict it to a specific ACE:

```lua
if not IsPlayerAceAllowed(source, 'rsg-fireworks.display') then
```

Then grant it in `server.cfg`:

```cfg
add_ace group.admin rsg-fireworks.display allow
```

### Translate the resource

Included locales: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the active locale in `server.cfg`:

```cfg
setr rsg:locale "de"
```

To add another language, copy `locales/en.json` to `locales/<code>.json`, translate the values (leave the keys unchanged), and set `setr rsg:locale "<code>"` in `server.cfg`.

### Adjust explosion effects

The particle asset, effect name, scale, explosion type and vertical offset are defined per type in `FireworkTypes` at the top of `client/client.lua`. Change them only after verifying the asset names against the RedM particle asset lists.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Item does nothing | Item not registered in `rsg-core`, or `rsg-inventory` not started | Add the definitions from `installation/shared_items.lua`; ensure `rsg-inventory` starts before this resource. |
| `attempt to index a nil value (field 'Shared')` | `rsg-core` is not started or the resource name is wrong | Ensure `rsg-core` starts first and the folder is named `rsg-core`. |
| Firework appears for the user but not others | Placement rejected by the server | Check the player stayed within `Config.PlacementDistance`; confirm `Config.PendingFireworkTimeout` is long enough to finish placing. |
| Placement tool does not open | `rsg-gizmo` is not started or not installed | Ensure `rsg-gizmo` is installed and starts before this resource. |
| Placement stays red indoors | Interior placement is blocked | This is expected with `Config.AllowInteriorPlacement = false`. Move outside; set it to `true` to allow indoor placement. |
| Display command says "Command Failed!" | Missing permission | Grant `admin` or an ACE allowed to use `command`. |
| Display command does nothing | Command not registered or display name mismatch | Check `Config.Displays` for a unique `command` and exact `name`; restart the resource. |
| "Please wait for your current firework to finish" | Previous firework is still pending | Finish or cancel the current placement, or let `Config.PendingFireworkTimeout` expire. |
| No sound | Sound disabled or game audio muted | Set `Config.EnableSound = true` and check client audio settings. |
| Version checker prints a 404 warning | Upstream folder renamed | The checker falls back to the original `rex-fireworks` folder; update `server/versionchecker.lua` when the upstream repository is renamed. |
| Particles remain after restart | Resource stopped before cleanup | Restart the resource; `onResourceStop` clears tracked effects on a clean stop. |

Enable client/server console output and check the server console for `[rsg-fireworks]` lines when diagnosing version-checker issues.

---

## Support

- Support the Project : https://rexshack.tebex.store/
