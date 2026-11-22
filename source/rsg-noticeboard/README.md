# rsg-noticeboard

Version 3.3.0 · full reference in [DOCS.md](DOCS.md)

Town notice boards for the RSG Framework (RedM). Players use rsg-target on a bounty board to read notices and pin their own: events, wanted posters, items for sale and more.

## Features
- **rsg-target** on `mp005_p_mp_bountyboard01x` and `mp005_p_mp_bountyboard02x`, covering the game's own boards and admin-placed ones
- **Separate boards per town**: every board, including ones out in the wilds, shows the notices of its nearest town (`Config.Towns`)
- **Full NUI**: category tabs, a tile grid (poster image and title), and a parchment poster view
- **Posting**: title, body text, https image link with live preview, category and display period
- **Paid periods**: 1 day, 3 days, 1 week, 2 weeks or 1 calendar month, each with its own price (all configurable)
- **Expiry and renewal**: the poster is warned before a notice expires (also on login) and can renew it from a popup or from **My Notices**. Expired notices are deleted automatically
- **Admin tools** (`/noticeadmin`): place new boards with the rsg-gizmo placement tool (saved to the database, they survive restarts), then teleport to, rename or delete them. View, extend for free or delete any notice, filtered by town
- **Search, sort and paging**: find notices by text, sort by newest, expiring soon or title; one page is loaded at a time
- **Edit** your own notices for free, **feature** them for a fee, and **pin** your position so viewers can show it on the map
- **Reminders**: viewers can ask for a telegram before an event notice expires (rsg-telegram, optional)
- **Reports and bans**: a report button, auto-hide after several reports, and an admin Reports/Bans panel with posting bans (rsg-reputation penalty optional)
- **Town treasury**: a share of the fees goes to the town through rsg-economy (optional)
- **Blips** for placed boards, and boards only spawn when players are within range

## Requirements
Optional: `rsg-economy` (town treasury), `rsg-reputation` (honor limit and penalty), `rsg-telegram` (reminders). Each feature quietly turns off when its resource is not running.

`rsg-core`, `rsg-target`, `rsg-gizmo`, `oxmysql` (no ox_lib needed)

## Installation
1. Put `rsg-noticeboard` in your resources folder.
2. Add `ensure rsg-noticeboard` after rsg-core, rsg-target, rsg-gizmo and oxmysql.
3. The database tables are created and upgraded automatically on start. `install.sql` is included if you prefer to run it yourself.
4. Adjust `shared/config.lua` to suit your server.

## Configuration highlights
| Option | Purpose |
|---|---|
| `Config.Durations` | Display periods and prices (`seconds = ...` or `months = 1` for a calendar month) |
| `Config.Categories` | Notice categories shown as tabs |
| `Config.SeparateTowns` / `Config.Towns` | Per-town boards and the town centre coordinates |
| `Config.MoneyType` | `cash`, `bank` or `bloodmoney` |
| `Config.MaxNoticesPerPlayer` | Active notice limit per character |
| `Config.PostCooldown` | Seconds between posts per character |
| `Config.AllowedImageHosts` | Restrict image links to certain hosts (empty = any https link) |
| `Config.WarnBeforeExpiry` | How long before expiry the poster is warned |
| `Config.SessionTimeout` / `Config.SessionDistance` | Anti-exploit: posting only works while at a board |
| `Config.PlaceMaxDistance` | How far from the admin a board may be placed (checked on the server too) |
| `Config.ExpiryPopup` | Open the renew popup when a notice is about to expire (`false` = notification only) |
| `Config.AllowPushToTalkWhileOpen` / `Config.PushToTalkControls` | Keep push-to-talk working while the UI is open |
| `Config.PageSize` / `Config.SearchMaxLength` | Notices per page and the search box length |
| `Config.AllowEdit` / `Config.AllowPins` | Let posters edit notices and pin their position |
| `Config.Featured` | `Enabled`, `Price`, `MaxPerTown` for featured notices |
| `Config.Reminders` | `Enabled`, `Before` (seconds), `MaxPerPlayer` |
| `Config.Economy` | `Enabled`, `Share`, `Regions` (town to rsg-economy region) |
| `Config.Reports` | `HideAt`, `MaxPerDay`, `Cooldown`, `BanDays`, `Reasons` |
| `Config.Reputation` | `MinHonorToPost`, `AbusePenalty` (rsg-reputation) |
| `Config.AdminPermission` / `Config.AdminCommand` | Who can manage boards and the command name |

## Placing boards
`/noticeadmin` → **Place New Board** → enter a name → place the board with rsg-gizmo (the controls are shown on screen; they are set in rsg-gizmo's config). The server checks you are standing within `Config.PlaceMaxDistance` of the board before it is saved.

## Security
- All fees, prices, durations and categories are checked on the server. The client only sends text and IDs from the config
- Posting requires the player to have opened a board recently and still be standing near it, with a per-character cooldown between posts
- Board data requests are throttled to stop players spamming database queries
- The town is worked out from the player's position on the server, never from client data
- A per-player lock stops double-charging and spamming past the notice limit
- Text is length-checked on the server (UTF-8 aware) and stripped of control, zero-width and text-direction characters; image links must be plain https links (optionally from `Config.AllowedImageHosts`), and everything is escaped in the UI
- Admin callbacks check `RSGCore.Functions.HasPermission`

## Languages
Includes translations for **en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru**. Every player message, the whole NUI, category and duration names, the Discord webhook embeds come from `locales/<lang>.json`.

Set the language with the rsg-core locale convar in `server.cfg` (falls back to `ox:locale`, then `en`):
```
setr rsg:locale "de"
```
Missing keys fall back to English. To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values. Keep the `%s`, `%d` and `%.2f` placeholders and the `~e~`/`~q~` colour codes as they are.

Category and duration labels use the keys `cat_<id>` and `dur_<id>`. If you add a new category or duration in the config, add a matching key to each locale file. Otherwise the `label` from the config is used.

## Discord Webhooks
Webhooks are set in `server/sv_config.lua`. This file is loaded on the server only, so the URLs are never sent to players.

1. In Discord, go to Channel Settings → Integrations → Webhooks → New Webhook and copy the URL.
2. Paste it into `SvConfig.Webhooks.Default` to send every event to one channel, or into an event's own `url` to split them across channels.
3. Set `enabled = false` on any event you don't want to log.

| Event | Sent when |
|---|---|
| `noticePosted` | A player pins a notice (with poster image, fee, town and expiry) |
| `noticeRenewed` | A player renews their notice |
| `noticeRemoved` | A player takes down their own notice |
| `noticeExpired` | Notices expire (one summary message per check) |
| `adminDelete` / `adminExtend` | An admin deletes or extends a notice |
| `boardPlaced` / `boardRenamed` / `boardDeleted` | An admin manages boards |
| `exploit` | A post is blocked because it didn't come from a board (optional role ping, rate limited per player) |

Messages are queued per webhook and sent about one per second. Discord rate limits (429) are retried automatically, so busy periods never drop logs or get the webhook blocked. Player embeds can include license and Discord IDs (`IncludeIdentifiers`).

## Support
https://buymeacoffee.com/rexshack

## Database

Tables (`rsg_noticeboard_boards`, `rsg_noticeboard_notices`) are created automatically on first start while `Config.AutoDatabase = true` (default); the database user needs `CREATE` permission. To install manually, set `Config.AutoDatabase = false` in the config and import `install.sql` once.
