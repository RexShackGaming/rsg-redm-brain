# rsg-deliveries — Technical Documentation

Version 3.1.1. For installation and the full configuration tables see [README.md](README.md).

## Contents

1. [Architecture](#architecture)
2. [Delivery flow](#delivery-flow)
3. [Events and callbacks](#events-and-callbacks)
4. [Shared helpers](#shared-helpers)
5. [Data formats](#data-formats)
6. [Security model](#security-model)
7. [Persistence](#persistence)
8. [Server owner how-tos](#server-owner-how-tos)
9. [Troubleshooting](#troubleshooting)

## Architecture

| File | Side | Purpose |
|------|------|---------|
| `shared/config.lua` | shared | All settings, hubs and routes (`Config`) |
| `shared/functions.lua` | shared | `GetRouteDistance`, `CalculateCashReward` (client uses them for the UI preview, server for the payout) |
| `client/npcs.lua` | client | Foreman NPCs (rsg-target), NUI contract board |
| `client/client.lua` | client | Hub blips, wagon spawn, delivery loop (timer, marker, wagon health, arrival), `/canceldelivery` |
| `server/server.lua` | server | Start validation, wagon registration, completion checks, rewards, webhook |
| `server/sv_config.lua` | server | `SvConfig.Webhook` (never sent to clients) |
| `server/versionchecker.lua` | server | Version check against GitHub |
| `html/` | NUI | Contract board |
| `locales/*.json` | shared | en, de, el, es, fr, ja, nl, pl, pt-br, ro (loaded by rsg-core) |

The resource has no database tables and no exports.

## Delivery flow

1. Player targets a foreman → the NUI board opens with every route from that hub.
2. NUI `start` → client loads the wagon model and awaits the `rsg-deliveries:server:startdelivery` callback with the hub and route **indexes** only.
3. Server validates (see [Security model](#security-model)), stores the active delivery and returns `true`.
4. Client spawns the networked wagon, waits for it to be networked and sends its net id with `rsg-deliveries:server:setwagon`.
5. Server waits up to 10 seconds for that entity to exist server-side, checks its model and distance to the player, and stores the net id.
6. Client loop runs until the wagon is within `Config.CompleteDistance` of the drop-off (and the player within that + 5m), then sends `rsg-deliveries:server:completedelivery` with the wagon net id and deletes its wagon 3 seconds later.
7. Server checks expiry, player position, travel time and the wagon, then pays cash, rolls the item reward and deletes the wagon.

The client fails the contract itself (`faildelivery`) on timeout, lost wagon, death or an undriveable wagon.

## Events and callbacks

### Server callback

| Name | Arguments | Returns |
|------|-----------|---------|
| `rsg-deliveries:server:startdelivery` | `hubIndex`, `destIndex` | `true` if the delivery was started, otherwise `false` |

### Server events (sent by the client)

| Event | Arguments | Description |
|-------|-----------|-------------|
| `rsg-deliveries:server:setwagon` | `netId` | Registers the spawned wagon for the active delivery. Accepted once per delivery. |
| `rsg-deliveries:server:completedelivery` | `netId` | Requests completion. The net id is only used if no wagon was registered at the start, and is fully re-validated. |
| `rsg-deliveries:server:canceldelivery` | none | Cancels the active delivery (cooldown applies, wagon deleted) |
| `rsg-deliveries:server:faildelivery` | `reason` | `timeout`, `damaged_wagon`, `wagon_lost` or `player_died` (cooldown applies, wagon deleted) |

There are no client net events; the server only sends `RSGCore:Client:Notify`.

### NUI callbacks

| Callback | Data | Description |
|----------|------|-------------|
| `close` | none | Closes the board |
| `start` | `{ index }` | Starts the route at that index for the hub that was opened |

## Shared helpers

```lua
-- distance in metres from the hub's cart spawn to the drop-off (straight line)
local distance = GetRouteDistance(location, destination)

-- cash reward for a route and whether it hit Config.MaxRewardAmount
local cash, capped = CalculateCashReward(location, destination)
```

These are globals inside the resource only, not exports.

## Data formats

Active delivery (server memory, keyed by player source):

```lua
{
    destination = <route table from Config>,
    cash        = 120,          -- worked out at the start
    distance    = 2150.4,       -- metres
    startedAt   = os.time(),
    expiry      = os.time() + Config.DefaultDeliveryTime * 60,
    netId       = 1234,         -- set once the wagon is registered
}
```

Hub and route tables are described in the README under *Delivery Locations*.

## Security model

What the server checks:

- **Start:** valid indexes, no active delivery, cooldown (`Config.DeliveryCooldown`), player within 30m of the hub's cart spawn.
- **Wagon registration:** entity exists on the server, model matches the route's `wagonModel`, within 30m of the player.
- **Completion:**
  - the delivery is consumed on the first call, so the event cannot be replayed
  - not expired
  - player within 20m of the drop-off
  - elapsed time at least `distance / Config.MaxAverageSpeed` (teleport check)
  - with `Config.RequireWagonAtDestination`: the registered wagon exists and is within 20m of the drop-off. If no wagon was registered, the net id sent with the completion is accepted only if the entity has the route's model, was created by that player and is within 20m of the drop-off.
- **Rewards:** cash and items come from the config on the server, cash is capped at `Config.MaxRewardAmount`, `CanAddItem` is checked before `AddItem`.

Every rejected completion prints a line to the server console with the reason.

## Persistence

Nothing is saved. Active deliveries and cooldowns live in server memory and are cleared when the player drops or the resource restarts. Restarting the resource deletes all delivery wagons.

## Server owner how-tos

- **Add a route or hub:** copy an existing entry in `Config.DeliveryLocations` (README has the field list).
- **Change payouts:** `Config.RewardPerDistance`, `Config.BaseReward`, each route's `multiplier` / `price`, and the `Config.MaxRewardAmount` cap.
- **Turn off the wagon check:** `Config.RequireWagonAtDestination = false` (for servers without OneSync).
- **Discord logs:** set `SvConfig.Webhook.url` in `server/sv_config.lua`.
- **Rename a wagon in the UI:** add it to `Config.WagonLabels`.

## Troubleshooting

| Problem | Cause / fix |
|---------|-------------|
| "You need to bring the wagon to the drop-off" while in the wagon, no reward | Fixed in 3.1.1 (the wagon was never registered with the server). If it still happens, the server console prints `delivery rejected, wagon check failed (<reason>)`; check OneSync is on. |
| Console: `delivery wagon ... was not registered` | The wagon never synced to the server within 10 seconds. The delivery can still complete through the arrival check. |
| Delivery silently does nothing at the drop-off, console says "possible teleport" | Completed faster than `distance / Config.MaxAverageSpeed`. Raise `Config.MaxAverageSpeed`. |
| "Something is blocking the wagon spawn!" | A vehicle is within `Config.SpawnVehDistance` of the hub's `cartSpawn` |
| "The wagon could not be prepared" | The route's `wagonModel` failed to load or spawn |
| Item reward never given | The item is missing from rsg-core shared items (console prints a warning), or the inventory was full |
| No webhook messages | `SvConfig.Webhook.url` is empty |

## Support

https://buymeacoffee.com/rexshack
