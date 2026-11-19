# rsg-noticeboard – Developer Docs

## Dependencies
- `rsg-core` (locales, notify, callbacks, model loading)
- `rsg-target` (board interaction)
- `oxmysql`

ox_lib is **not** used (migrated in v3.1.0).

## Structure
| File | Purpose |
|---|---|
| `shared/config.lua` | Main config (boards, durations, categories, towns) |
| `client/client.lua` | Board spawning, blips, target, NUI bridge, expiry renew prompt |
| `client/placer.lua` | Admin ghost placer for new boards |
| `server/server.lua` | Notices, fees, expiry, admin actions, callbacks |
| `server/sv_config.lua` / `webhooks.lua` | Server-only config and Discord logs |
| `html/` | NUI (board, admin panel, modals) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## Callbacks (server, `RSGCore.Functions.CreateCallback`)
Registered through a local `registerCallback(name, fn)` wrapper that calls `cb(fn(source, ...))`, so handlers simply `return` their value. Client side uses `RSGCore.Functions.AwaitCallback(name, 10000, ...)`.

`getBoards`, `getBoardData`, `createNotice`, `renewNotice`, `deleteOwnNotice`, `getAdminData`, `saveBoard`, `renameBoard`, `deleteBoard`, `adminDeleteNotice`, `adminExtendNotice` (all prefixed `rsg-noticeboard:server:`). Admin callbacks check `Config.AdminPermission` server-side.

## Events
- `rsg-noticeboard:client:syncBoards` – placed board list
- `rsg-noticeboard:client:openAdmin` – open admin panel
- `rsg-noticeboard:client:expiryWarning` – notice about to expire; shows a notify and opens the NUI `expiryRenew` prompt (confirm → duration picker → `renewNotice`)
- Server notifications use `RSGCore:Client:Notify`

## NUI actions
`openBoard`, `openAdmin`, `expiryRenew`. NUI callbacks: `close`, `refresh`, `refreshAdmin`, `createNotice`, `renewNotice`, `deleteOwnNotice`, `adminDeleteNotice`, `adminExtendNotice`, `adminDeleteBoard`, `adminRenameBoard`, `adminTeleport`, `adminPlaceBoard`.

## Language
`setr rsg:locale "de"` (falls back to `ox:locale`, then `en`). `ui_*` keys are sent to the NUI.

## Changelog
- **3.1.0** – Removed ox_lib: rsg-core locales/notify/callbacks/RequestModel, `cache.ped` → `PlayerPedId()`, ox_target → rsg-target, renew alert/context menu moved into the NUI.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-noticeboard 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `oxmysql`

### Database

Tables: `rsg_noticeboard_boards`, `rsg_noticeboard_notices`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.BoardModels` | `table` |  |
| `Config.PlacedBoardModel` | `'mp005_p_mp_bountyboard02x'` | model admins place with the gizmo |
| `Config.TargetDistance` | `2.5` |  |
| `Config.SpawnDistance` | `120.0` | placed boards spawn when player is within this range |
| `Config.ShowBlips` | `true` |  |
| `Config.BlipSprite` | ``blip_job_board`` |  |
| `Config.BlipScale` | `0.2` |  |
| `Config.SeparateTowns` | `true` |  |
| `Config.Towns` | `table` |  |
| `Config.MoneyType` | `'cash'` | cash / bank / bloodmoney |
| `Config.MaxNoticesPerPlayer` | `5` |  |
| `Config.PostCooldown` | `30` | seconds between posts per character |
| `Config.SessionTimeout` | `600` | seconds a player can stay in the board UI and still post |
| `Config.SessionDistance` | `10.0` | max distance from where the board was opened when posting |
| `Config.TitleMaxLength` | `60` |  |
| `Config.BodyMaxLength` | `1500` |  |
| `Config.RequireImage` | `false` |  |
| `Config.AllowedImageHosts` | `{}` | image links must start with one of these (leave empty table to allow any https link) |
| `Config.Durations` | `table` | durations: seconds OR months = 1 (calendar month) |
| `Config.Categories` | `table` |  |
| `Config.WarnBeforeExpiry` | `60 * 60 * 6` | warn the poster 6 hours before expiry |
| `Config.CheckInterval` | `60` | seconds between expiry checks |
| `Config.PlacerKeys` | `table` |  |
| `Config.PlacerRotateSpeed` | `1.5` | degrees per frame |
| `Config.PlacerHeightSpeed` | `0.01` | metres per frame |
| `Config.PlacerMaxDistance` | `15.0` | how far from the camera the board can be placed |
| `Config.AdminPermission` | `'admin'` |  |
| `Config.AdminCommand` | `'noticeadmin'` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-noticeboard:server:getBoards` | server | `` | `server/server.lua` |
| `rsg-noticeboard:server:getBoardData` | server | `source` | `server/server.lua` |
| `rsg-noticeboard:server:createNotice` | server | `source, data` | `server/server.lua` |
| `rsg-noticeboard:server:renewNotice` | server | `source, noticeId, durationId` | `server/server.lua` |
| `rsg-noticeboard:server:deleteOwnNotice` | server | `source, noticeId` | `server/server.lua` |
| `rsg-noticeboard:server:getAdminData` | server | `source` | `server/server.lua` |
| `rsg-noticeboard:server:saveBoard` | server | `source, data` | `server/server.lua` |
| `rsg-noticeboard:server:renameBoard` | server | `source, id, label` | `server/server.lua` |
| `rsg-noticeboard:server:deleteBoard` | server | `source, id` | `server/server.lua` |
| `rsg-noticeboard:server:adminDeleteNotice` | server | `source, id` | `server/server.lua` |
| `rsg-noticeboard:server:adminExtendNotice` | server | `source, id, durationId` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-noticeboard:server:getBoards', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-noticeboard:client:syncBoards` | client | `` | `client/client.lua` |
| `rsg-noticeboard:client:openAdmin` | client | `` | `client/client.lua` |
| `rsg-noticeboard:client:expiryWarning` | client | `n` | `client/client.lua` |

```lua
-- from a server script
TriggerClientEvent('rsg-noticeboard:client:syncBoards', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
