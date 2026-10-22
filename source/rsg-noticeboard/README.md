# rsg-noticeboard

Town notice boards for the RSG Framework (RedM). Players use ox_target on a bounty board to read notices and pin their own: events, wanted posters, items for sale and more.

## Features
- **ox_target** on `mp005_p_mp_bountyboard01x` and `mp005_p_mp_bountyboard02x`, covering the game's own boards and admin-placed ones
- **Separate boards per town**: every board, including ones out in the wilds, shows the notices of its nearest town (`Config.Towns`)
- **Full NUI**: category tabs, a tile grid (poster image and title), and a parchment poster view
- **Posting**: title, body text, https image link with live preview, category and display period
- **Paid periods**: 1 day, 3 days, 1 week, 2 weeks or 1 calendar month, each with its own price (all configurable)
- **Expiry and renewal**: the poster is warned before a notice expires (also on login) and can renew it from a popup or from **My Notices**. Expired notices are deleted automatically
- **Admin tools** (`/noticeadmin`): place new boards with a gizmo (saved to the database, they survive restarts), then teleport to, rename or delete them. View, extend for free or delete any notice, filtered by town
- **Blips** for placed boards, and boards only spawn when players are within range

## Requirements
`rsg-core`, `ox_lib`, `ox_target`, `oxmysql`

## Installation
1. Put `rsg-noticeboard` in your resources folder.
2. Add `ensure rsg-noticeboard` after rsg-core, ox_lib, ox_target and oxmysql.
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
| `Config.PlacerKeys` | Keybinds for the admin placement gizmo |
| `Config.AdminPermission` / `Config.AdminCommand` | Who can manage boards and the command name |

## Placing boards
`/noticeadmin` → **Place New Board** → enter a name → aim to move the board. Left/Right rotates it, Up/Down changes the height, LMB places it and RMB cancels. All keys can be changed in `Config.PlacerKeys`.

## Security
- All fees, prices, durations and categories are checked on the server. The client only sends text and IDs from the config
- Posting requires the player to have opened a board recently and still be standing near it, with a per-character cooldown between posts
- Board data requests are throttled to stop players spamming database queries
- The town is worked out from the player's position on the server, never from client data
- A per-player lock stops double-charging and spamming past the notice limit
- Text is length-checked on the server (UTF-8 aware), image links must be https, and everything is escaped in the UI
- Admin callbacks check `RSGCore.Functions.HasPermission`

## Languages
Includes translations for **en, de, el, es, fr, ja, nl, pl, pt-br, ro**. Every player message, the whole NUI, category and duration names, the placement help text and the Discord webhook embeds come from `locales/<lang>.json`.

Set the language with the ox_lib convar in `server.cfg`:
```
setr ox:locale "de"
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
