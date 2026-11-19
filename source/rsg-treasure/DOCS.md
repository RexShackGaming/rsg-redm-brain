# rsg-treasure – Developer Docs

## Flow
1. Player uses `Config.MapItem` → server picks a free location, stores `hunts[citizenid] = { idx, centre }`, sends `rsg-treasure:client:startHunt(loc, centre)`.
2. Client draws the search circle and, while the detector is held inside it, drives the detector blackboard value, the NUI signal meter and the bleep.
3. At `Config.PinpointDistance` the [J] dig prompt appears (within `Config.DigDistance`).
4. Pressing [J] → callback `rsg-treasure:server:digStart` (checks hunt, distance, map, detector, tool; starts the server dig timer). Only on `true` does the anim scene play.
5. After the anim → callback `rsg-treasure:server:dig` pays out, then `rsg-treasure:client:endHunt`.

## Server security
- All rewards are rolled and given server-side; the client sends no arguments.
- Payout needs a `digStart` at least `Config.DigTime - 1500` ms earlier, a server-side distance check, and a per-player `Config.Cooldown`.
- Loot is rolled and `CanAddItem`-checked **before** the map is removed. If any item won't fit, nothing is taken.
- The map is removed before cash/items are given, so a payout can't be claimed twice.
- Known limitation: the client receives the exact dig coords (the detector needs them for distance). Cheaters could read them, but they still need the map, the detector, the full dig time and to be in range.

## Events / callbacks
| Name | Side | Purpose |
|---|---|---|
| `rsg-treasure:client:startHunt` | client | (loc, centre) start/redisplay a hunt |
| `rsg-treasure:client:endHunt` | client | clean up blips, chest, NUI |
| `rsg-treasure:server:resume` | server | resend the active hunt (on player loaded / resource start) |
| `rsg-treasure:server:digStart` | callback | pre-dig validation + timer → bool |
| `rsg-treasure:server:dig` | callback | payout → bool |

## Exports
- `exports['rsg-treasure']:SendLog(channel, title, description, color, src?, fields?)` (server)

## Config
See `shared/config.lua` (gameplay) and `server/sv_config.lua` (webhooks, server only).

## Changelog
### 3.1.0
- Removed ox_lib: rsg-core locales, notify and callbacks.
- Dig is validated before the animation (no more full dig then refusal).
- A full inventory no longer destroys loot: nothing is consumed and the player can retry.
- Hunts resume after relog / resource restart.
- Detector native only called when the value changes.
- Removed unused locale keys (`log_inv_full`, `log_loot_lost`, `log_no`) and the inventory-full log field.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-treasure 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.MapItem` | `'treasure_map'` | usable item that starts a hunt |
| `Config.RequiredItem` | `nil` | e.g. 'shovel' to require a tool, nil = none |
| `Config.Detector` | ``WEAPON_KIT_METAL_DETECTOR`` | femga weapons/weapons.lua |
| `Config.DetectorItem` | `'weapon_kit_metal_detector'` | inventory item name (server check) |
| `Config.DetectRange` | `40.0` | detector starts picking up signal at this distance |
| `Config.PinpointDistance` | `2.5` | signal maxes out & strongbox can be dug here |
| `Config.Bleep` | `table` | Bleep (played via NUI so volume can scale with distance) |
| `Config.SearchRadius` | `120.0` | size of the search circle on the map |
| `Config.DigKey` | `0xF3830D8E` | [J] INPUT_OPEN_JOURNAL |
| `Config.DigDistance` | `3.0` | server-checked max distance to dig |
| `Config.DigTime` | `10000` | ms (length of the dig-up-chest anim scene) |
| `Config.ChestRevealDelay` | `3000` | ms into the dig before the strongbox becomes visible |
| `Config.Cooldown` | `10` | seconds between digs per player (anti-spam) |
| `Config.ChestModel` | ``p_strongbox_muddy_01x`` | femga objects/object_list.lua |
| `Config.DigAnim` | `{ dict = 'script@mech@treasure_hunting@chest', playlist = 'PBL_CHEST_0` | anim scene (old rsg-treasure) |
| `Config.BlipSprite` | ``BLIP_RC_TREASURE_HUNTER`` | 1491.50 treasure_hunter.c |
| `Config.Cash` | `{ min = 15, max = 60 }` | Cash reward (server rolls this) |
| `Config.Rewards` | `table` | Item rewards: each has its own chance (0-100) |
| `Config.Locations` | `table` | Possible treasure spots (exact dig points; the blip circle is offset so it isn't given away) |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `SendLog` | `` | `server/webhook.lua` |

```lua
-- example
local result = exports['rsg-treasure']:SendLog()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-treasure:server:digStart` | server | `src, cb` | `server/server.lua` |
| `rsg-treasure:server:dig` | server | `src, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-treasure:server:digStart', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-treasure:client:startHunt` | client | `loc, centre` | `client/client.lua` |
| `rsg-treasure:client:endHunt` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-treasure:server:resume` | server | `` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-treasure:server:resume')
-- from a server script
TriggerClientEvent('rsg-treasure:client:startHunt', source, loc, centre)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
