# rsg-mapping – Developer & Server Owner Docs

## Contents
1. Architecture
2. Data formats
3. Exports
4. Events and callbacks
5. Persistence
6. Security model
7. Database schema
8. How-tos
9. Troubleshooting

## 1. Architecture
| File | Side | Purpose |
|---|---|---|
| `shared/config.lua` | shared | All settings (`Config.*`). |
| `shared/imaps.lua` | client | `ImapData`: ~8,000 IMAPs `{ hash, name, x, y, z }` from femga/rdr3_discoveries. Entries with `x = y = -1.0` have no known coords. |
| `client/client.lua` | client | Scanning, NUI bridge, 3D labels, highlight, view camera, waypoint, saved-state sync, commands. |
| `client/defaultimap.lua` | client | Default `RequestImap` / `RemoveImap` list run on load (de-duplicated in 3.1.0). |
| `client/interiors.lua` | client | Activates interior entity sets by interior ID. |
| `server/server.lua` | server | Permission checks, DB load/save, sync to clients. |
| `server/versionchecker.lua` | server | GitHub version check. |
| `html/*` | NUI | Finder list + details window. |

Load order on the client: `imaps.lua` → `client.lua` → `defaultimap.lua` → `interiors.lua`. Saved DB states are fetched ~1s after start, so they override the defaults.

## 2. Data formats
Scan entry (returned by the export and sent to NUI):
```lua
{ hash = -1378517036, name = 'a_03_', x, y, z, dist, active = bool, label = string|nil, saved = 1|0|nil, global = bool?, nocoords = bool? }
```
Saved entry: `{ hash, label = string|nil, state = 1|0|nil }` (`nil` state = game default).

## 3. Exports
Client:
| Export | Params | Returns |
|---|---|---|
| `GetNearbyImaps(radius)` | radius (clamped 1–`Config.MaxRadius`) | array of scan entries sorted by distance |

## 4. Events and callbacks
| Name | Type | Notes |
|---|---|---|
| `rsg-mapping:server:canUse` | rsg-core callback | returns `true` if the player passes the admin check |
| `rsg-mapping:server:getSaved` | rsg-core callback | returns the saved entry list |
| `rsg-mapping:server:setLabel(hash, name, label)` | net event | admin only, 250ms cooldown, label trimmed to 100 chars |
| `rsg-mapping:server:setState(hash, name, state)` | net event | admin only; `true`/`false`/`nil` (nil = forget) |
| `rsg-mapping:client:syncAll(list)` | client event | full list after DB load |
| `rsg-mapping:client:update(hash, entry\|false)` | client event | single change broadcast to everyone |

## 5. Persistence
Labels and states live in `rsg_imaps`. On start the server loads all rows and broadcasts them. Each change is upserted (or deleted when both label and state are empty) and broadcast to all clients, who apply `RequestImap`/`RemoveImap`. Forgetting a state does not revert it live (the game default isn't known), it takes effect on next restart / reconnect.

## 6. Security model
- Every write checks the player exists, has `Config.AdminPerm` via `RSGCore.Functions.HasPermission`, passes a 250ms per-source cooldown, and sends a valid int32 hash.
- 3.1.0 removed the `IsPlayerAceAllowed(src, 'command')` fallback: the `command` ace is often granted widely and let non-admins write global map state.
- No money or items are involved.
- `Config.OnlyAdmins = false` lets **any** player change the map for **everyone**. Only use that on a dev server.

## 7. Database schema
```sql
CREATE TABLE IF NOT EXISTS `rsg_imaps` (
  `hash` INT NOT NULL,
  `name` VARCHAR(128) NULL,
  `label` VARCHAR(100) NULL,
  `state` TINYINT(1) NULL COMMENT '1 = enabled, 0 = disabled, NULL = game default',
  `updated_by` VARCHAR(64) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`hash`)
);
```
Created automatically when `Config.AutoDatabase = true`; same schema is in `installation/rsg-imap.sql`.

## 8. How-tos
- **Hard-code a change:** open the IMAP, press Copy Lua, paste into `client/defaultimap.lua`.
- **Use from another script:** `exports['rsg-mapping']:GetNearbyImaps(30.0)`.
- **Change language:** `setr rsg:locale de`.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| "No permission" | Give the player the `Config.AdminPerm` rsg-core permission. |
| `invalid interior` warnings in F8 | Interior IDs in `interiors.lua` can change between game builds; look the interior up with `GetInteriorAtCoords` and update the ID. |
| Saved state not applied | Check the server console for `database tables ready` and the loaded entry count. |
| Waypoint/View greyed out | That IMAP has no known coordinates in the data. |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-mapping 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`

### Database

Tables: `rsg_imaps`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-imap.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | create the rsg_imaps table on start (set false to import installation/rsg-imap.sql manually) |
| `Config.Command` | `'imaps'` | /imaps [radius]  open the nearby IMAP menu |
| `Config.DrawCommand` | `'imapdraw'` | /imapdraw [radius] toggle 3D labels in the world |
| `Config.DefaultRadius` | `50.0` |  |
| `Config.MaxRadius` | `500.0` |  |
| `Config.MaxResults` | `200` | max rows rendered in the UI |
| `Config.OnlyAdmins` | `true` | require rsg-core 'admin' permission |
| `Config.AdminPerm` | `'admin'` |  |
| `Config.DrawDistance` | `60.0` | labels farther than this are hidden |
| `Config.DrawRefresh` | `1000` | ms between re-scans while labels are on |
| `Config.HighlightSize` | `3.0` | ring diameter around the selected IMAP |
| `Config.HighlightBeam` | `40.0` | height of the beam above the selected IMAP |
| `Config.PersistToggles` | `true` | enabling/disabling in the UI is saved to the DB and synced to all players |
| `Config.ViewDistance` | `25.0` | view camera distance from the IMAP |
| `Config.ViewHeight` | `15.0` | view camera height above the IMAP |
| `Config.ViewOrbitSpeed` | `0.25` | orbit speed (radians/sec), 0 = static |

### Exports

**Client**

| Export | Arguments | File |
|---|---|---|
| `GetNearbyImaps` | `radius` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-mapping']:GetNearbyImaps(radius)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-mapping:server:canUse` | server | `source, cb` | `server/server.lua` |
| `rsg-mapping:server:getSaved` | server | `_, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-mapping:server:canUse', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-mapping:client:syncAll` | client | `` | `client/client.lua` |
| `rsg-mapping:client:update` | client | `hash, e` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `rsg-mapping:server:setLabel` | server | `hash, name, label` | `server/server.lua` |
| `rsg-mapping:server:setState` | server | `hash, name, state` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-mapping:server:setLabel', hash, name, label)
-- from a server script
TriggerClientEvent('rsg-mapping:client:syncAll', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
