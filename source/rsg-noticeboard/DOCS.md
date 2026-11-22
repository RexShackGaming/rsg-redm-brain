# rsg-noticeboard 3.3.0 – Developer Docs

## Dependencies
- `rsg-core` (locales, notify, callbacks, model loading)
- `rsg-target` (board interaction)
- `rsg-gizmo` (admin board placement and server-side placement checks)
- `oxmysql`

ox_lib is **not** used (migrated in v3.1.0).

## Structure
| File | Purpose |
|---|---|
| `shared/config.lua` | Main config (boards, durations, categories, towns) |
| `client/client.lua` | Board spawning (diffed on sync), blips, target, NUI focus + push-to-talk, rsg-gizmo placement, expiry renew prompt |
| `server/server.lua` | Notices, fees, expiry, admin actions, callbacks |
| `server/sv_config.lua` / `webhooks.lua` | Server-only config and Discord logs |
| `html/` | NUI (board, admin panel, modals) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## Callbacks (server, `RSGCore.Functions.CreateCallback`)
Registered through a local `registerCallback(name, fn)` wrapper that calls `cb(fn(source, ...))`, so handlers simply `return` their value. Client side uses `RSGCore.Functions.AwaitCallback(name, 10000, ...)`.

`getBoards`, `getBoardData`, `createNotice`, `renewNotice`, `deleteOwnNotice`, `getAdminData`, `saveBoard`, `renameBoard`, `deleteBoard`, `adminDeleteNotice`, `adminExtendNotice` (all prefixed `rsg-noticeboard:server:`). Admin callbacks check `Config.AdminPermission` server-side.

## Events
- `rsg-noticeboard:client:syncBoards` – placed board list
- `rsg-noticeboard:client:openAdmin` – open admin panel
- `rsg-noticeboard:client:expiryWarning` – notice about to expire; shows a notify and opens the NUI `expiryRenew` prompt (confirm → duration picker → `renewNotice`)
- Server notifications use `RSGCore:Client:Notify`

## NUI actions
`openBoard`, `openAdmin`, `expiryRenew`. NUI callbacks: `close`, `getNotices`, `getNotice`, `getMyNotices`, `editNotice`, `featureNotice`, `setPin`, `toggleReminder`, `reportNotice`, `setWaypoint`, `adminDismissReports`, `adminRemoveReported`, `adminBanPoster`, `adminUnban`, `refreshAdmin`, `createNotice`, `renewNotice`, `deleteOwnNotice`, `adminDeleteNotice`, `adminExtendNotice`, `adminDeleteBoard`, `adminRenameBoard`, `adminTeleport`, `adminPlaceBoard`.

## Push-to-talk
While the NUI has focus, `SetNuiFocusKeepInput(true)` is used and every game control except `Config.PushToTalkControls` is blocked each frame, so voice chat keeps working. Set `Config.AllowPushToTalkWhileOpen = false` to fall back to plain focus.

## Placement
`adminPlaceBoard` closes the UI and calls `exports['rsg-gizmo']:Place(Config.PlacedBoardModel, { rotation = 'z', maxDistance = Config.PlaceMaxDistance })`. The result is sent to `saveBoard`, which re-checks it with `rsg-gizmo:IsPlacementValid` and `SanitiseRotation`.

## Security model
3.3.0 additions: every new callback validates its arguments on the server; paging, search (LIKE characters escaped) and sorting use a whitelist; the map pin uses the server-side player position, never client coordinates; reports are one per character per notice with a daily limit and cooldown; bans and honor checks are enforced on the server before posting; fees paid to the treasury happen after the charge succeeds.

- Prices, durations and categories come from the config; the client only sends text and ids. Ids are validated as whole numbers.
- Posting needs a recent board session and the player still near where it was opened, a per-character cooldown, the notice limit, and a per-player lock. The fee is taken last.
- Known limit: the server cannot know where the game's own (map) bounty boards are, so a modified client can open a board session from anywhere. It still pays the fee and obeys every limit above.
- Text is stripped of control / zero-width / direction-override characters; invalid UTF-8 is rejected.
- Image links: https only, no quotes, brackets or spaces, optional host list (`Config.AllowedImageHosts`, exact host match). Every viewer's client loads the image, so set the host list on public servers to stop IP-logging links.
- Expiry deletes only rows that are still expired at delete time.

## Language
`setr rsg:locale "de"` (falls back to `ox:locale`, then `en`). `ui_*` keys are sent to the NUI.

## Changelog
- **3.3.0** – search, sort, paging, edit, featured, treasury, reports and bans, reputation, map pin and reminders (see CHANGELOG.md).
- **3.2.0** – rsg-gizmo placement, push-to-talk support, HTML drop-downs, security hardening and cleanup (see CHANGELOG.md).
- **3.1.0** – Removed ox_lib: rsg-core locales/notify/callbacks/RequestModel, `cache.ped` → `PlayerPedId()`, ox_target → rsg-target, renew alert/context menu moved into the NUI.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-noticeboard 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `rsg-gizmo`, `oxmysql`. Optional: `rsg-economy` (`DepositTreasury`), `rsg-reputation` (`AddHonor` / `HasHonor`), `rsg-telegram` (`SendTelegram`).

### Database

Tables: `rsg_noticeboard_boards`, `rsg_noticeboard_notices` (3.3.0 adds `featured`, `edited_at`, `hidden` and pin columns), `rsg_noticeboard_reports`, `rsg_noticeboard_reminders`, `rsg_noticeboard_bans`. Existing tables get the new columns added safely on start.

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
| `Config.AllowedImageHosts` | `{}` | allowed image hosts, e.g. `{ 'i.imgur.com' }` (empty = any https link) |
| `Config.Durations` | `table` | durations: seconds OR months = 1 (calendar month) |
| `Config.Categories` | `table` |  |
| `Config.WarnBeforeExpiry` | `60 * 60 * 6` | warn the poster 6 hours before expiry |
| `Config.CheckInterval` | `60` | seconds between expiry checks |
| `Config.ExpiryPopup` | `true` | open the renew popup when a notice is about to expire (false = notification only) |
| `Config.PlaceMaxDistance` | `8.0` | how far from the admin a board may be placed (checked on the server too) |
| `Config.AllowPushToTalkWhileOpen` | `true` | block game controls but keep push-to-talk while the UI is open |
| `Config.PushToTalkControls` | `table` | controls left enabled while the UI is open |
| `Config.PageSize` | `12` | notices per page |
| `Config.SearchMaxLength` | `40` | search box length |
| `Config.AdminListLimit` | `300` | notices shown in the admin panel |
| `Config.AllowEdit` | `true` | posters may edit their own notice for free |
| `Config.AllowPins` | `true` | posters may pin their position; viewers get "Show on map" |
| `Config.Featured` | `{ Enabled = true, Price = 10.00, MaxPerTown = 3 }` | featured notices |
| `Config.Reminders` | `{ Enabled = true, Before = 3600, MaxPerPlayer = 20 }` | telegram reminders |
| `Config.Economy` | `table` | `Enabled`, `Share`, `Regions`: fee share paid to the town treasury |
| `Config.Reports` | `table` | `Enabled`, `HideAt`, `MaxPerDay`, `Cooldown`, `BanDays`, `Reasons` |
| `Config.Reputation` | `table` | `Enabled`, `MinHonorToPost`, `AbusePenalty` (only online posters can be penalised) |
| `Config.AdminPermission` | `'admin'` |  |
| `Config.AdminCommand` | `'noticeadmin'` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-noticeboard:server:getBoards` | server | `` | `server/server.lua` |
| `rsg-noticeboard:server:getBoardData` | server | `source` | `server/server.lua` |
| `rsg-noticeboard:server:getNotices` | server | `source, query` (`category`, `search`, `sort`, `page`) | `server/server.lua` |
| `rsg-noticeboard:server:getNotice` | server | `source, id` (full text, pin, reminder state) | `server/server.lua` |
| `rsg-noticeboard:server:getMyNotices` | server | `source` | `server/server.lua` |
| `rsg-noticeboard:server:editNotice` | server | `source, id, data` | `server/server.lua` |
| `rsg-noticeboard:server:featureNotice` | server | `source, id` | `server/server.lua` |
| `rsg-noticeboard:server:setPin` | server | `source, id, enable` | `server/server.lua` |
| `rsg-noticeboard:server:toggleReminder` | server | `source, id` | `server/server.lua` |
| `rsg-noticeboard:server:reportNotice` | server | `source, id, reason` | `server/server.lua` |
| `rsg-noticeboard:server:adminDismissReports` | server | `source, id` | `server/server.lua` |
| `rsg-noticeboard:server:adminRemoveReported` | server | `source, id, ban` | `server/server.lua` |
| `rsg-noticeboard:server:adminBanPoster` | server | `source, id` | `server/server.lua` |
| `rsg-noticeboard:server:adminUnban` | server | `source, citizenid` | `server/server.lua` |
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

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
