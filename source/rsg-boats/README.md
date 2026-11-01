# rsg-boats

Boat yards for the RSG Framework. Players buy boats at a yard, launch them, store them at any yard's dock and keep items in each boat's own storage. Admins create and manage every yard in game from an NUI panel. No config editing is needed after install.

## Features
- **Multiple boat yards**: each has its own NPC (rsg-target), map blip, launch point, dock zone and list of allowed boats.
- **Shop** (target the dock foreman, *Browse Boats*):
  - *For Sale*: buy boats this yard sells (cash).
  - *My Boats*: launch, sell back (`Config.SellBackRate`), give to another player, or store the boat that's on the water.
- **Dock storing**: drive into a yard's dock zone (white ring) and hold **E** on *Store Boat*. The boat is put away and you're placed back on the dock.
- **Boats stay where you leave them**: a boat can only be launched or sold at the yard it's stored at (`Config.LockToYard`). Store it at another dock to move it there.
- **Boat storage**: every owned boat has its own rsg-inventory stash (`boat_<id>`). Target your boat and choose *Boat Storage*, or open your inventory while sitting in it to see the storage in the right-hand panel. Slots and weight are set per model.
- **Give a boat**: *Give* in *My Boats*, then the other player's server ID. They must be nearby and accept the popup (with a countdown) before it times out. Only one offer per player can be open at a time. The boat keeps its storage and yard.
- **Movable windows**: drag the title area to move the shop or admin window; double-click it to reset. Positions are remembered per player.
- **Auto database install**: tables are created and upgraded on start.

## Install
1. Requires `rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`. ox_lib is **not** needed.
2. Add `ensure rsg-boats` after them in your server.cfg.
3. Start the server. The tables are created automatically (`Config.AutoInstallDB = true`). To install by hand instead, set it to `false` and run `install.sql`.
4. The first start creates yard #1 (`Config.Yard.defaultName` at `Config.Yard.coords`) with a rowboat for sale.

## Admin: `/boatadmin`
**Yards tab**: choose a yard from the dropdown.
- *Rename*.
- *Move To My Position*: moves the NPC and blip to where you stand, facing your direction. This resets the yard's launch point and dock.
- *Launch Point*: pick a boat and press *Spawn Assistant*. Arrow keys move (camera-relative), Q/E rotate, PgUp/PgDn height, Shift fast, Enter save, Backspace cancel.
- *Dock & Store Zone*: stand on the dock spot players return to and press *Set Dock At My Position*. *Save Radius* changes only the zone size.
- *Boats Sold & Stored Here*: *All boats*, or tick the models this yard sells and accepts at its dock.
- *Delete Yard*: boats stored there can then be collected at any yard.
- *New Yard At My Position*: creates a yard where you stand.

Moving or deleting a yard is blocked while a player has a boat out from it.

**Boat Models tab**: add, edit or remove models (model name, label, price, for sale, storage slots, max weight in kg, description). The model name is checked in game to be a real vehicle before saving.

## Config (`shared/config.lua`)
| Setting | What it does |
|---|---|
| `Config.Yard` | First yard's name and coords, NPC model, blip, target and NPC spawn distance |
| `Config.MaxBoats` | Max boats one character can own, including boats received by transfer (0 = unlimited) |
| `Config.LockToYard` | Boats can only be launched/sold at the yard they're stored at |
| `Config.MoneyType`, `Config.SellBackRate` | Payment type and sell-back percentage |
| `Config.ActionRadius`, `Config.StoreRadius`, `Config.MaxPointDistance` | Shop range, shop "store" range, max launch/dock distance from the yard |
| `Config.Dock` | Default radius, radius limits, prompt key/hold time, zone ring |
| `Config.Transfer` | Enable, max distance, require accept, accept timeout |
| `Config.Storage` | Enable, default and maximum slots/weight (grams), target distance, show in inventory while in boat |
| `Config.Placer`, `Config.Keys` | Spawn Assistant speeds and controls |
| `Config.AutoInstallDB`, `Config.DefaultBoats` | Auto install and the boats added on first install |
| `Config.Debug` | Console debug output |

All text is in `locales/`: player notifications, prompts, target labels, the whole NUI (`ui_*` keys) and Discord webhook embeds (`wh_*` keys). Included languages: en, de, el, es, fr, ja, nl, pl, pt-br and ro. Locales load through rsg-core (`@rsg-core/shared/locale.lua`); set the language with `setr rsg:locale "de"` in server.cfg (falls back to `ox:locale`, then `en`).

## Discord webhooks
Set these in `server/sv_config.lua`. It is server only, so webhook URLs are never sent to players.
- `default`: one channel for everything, or give each event its own `url`.
- Events: `buy`, `sell`, `launch`, `store`, `transfer`, `storage` (off by default, it's noisy), `admin` (yards, docks, launch points, allowed boats, models) and `exploit` (rejected boat claims, admin callbacks without permission).
- Each post is an embed with the details, the character name, citizen ID, server ID and license/Discord identifiers (`showIdentifiers`).
- `mentionOnExploit`: ping a staff role on exploit alerts.
- Posts are queued with built-in rate limiting and retries when Discord asks to wait (429), so busy servers don't lose logs.
- Test from the server console with `boatwebhooktest`.

## Database
- `rsg_boats_yards`: yards (coords, launch point, dock, allowed models)
- `rsg_boats_models`: boats for sale and their storage size
- `rsg_boats_owned`: owned boats and the yard each is stored at
- `rsg_boats_settings`: only read once to migrate the old single-yard setup
- Boat storage is in rsg-inventory's `inventories` table (`boat_<id>`)

## Security
- Money, ownership, storage and transfers are handled only on the server, with ownership re-checked in the same SQL statement that changes it.
- Every shop, store and boat-storage action checks that the player is at that yard, has a cooldown, and checks the stored yard.
- Transfers re-check after the other player accepts: a boat launched while the offer was open can't be given away, and the receiver's boat limit is checked again.
- A launch the client never confirms is released after 30 seconds, so the player isn't stuck with a phantom boat out.
- The client's report of the launched boat is only accepted once, for the right model, near the launch point and not already claimed by another player. A modified client can't claim or delete someone else's entity.
- Admin callbacks check permission (`Config.AdminPermission` or the `command` ACE). Positions are read from the admin's ped on the server.

## Changelog
- **3.1.0**: removed the ox_lib dependency (rsg-core callbacks, notify and locale loader); the transfer accept popup is now part of the boat NUI with a countdown; fixed the giver's request timing out after 10 seconds while the receiver still had time to accept; a player can only have one transfer offer open at a time; boat storage opening has a cooldown; dock ring uses the monochrome house style; dock loop stops checking other yards after storing.
- **1.1.1**: switched to rsg-target; fixed a transfer race that could duplicate a boat; stale launches now time out; store action has a cooldown; model labels and descriptions are sanitised; boats that sink no longer leave a stale storage target; shop can't be opened twice; remaining hard-coded UI text moved to locales; removed unused code and config.

## Data sources
- `rowboat`: femga/rdr3_discoveries vehicles/vehicles_list.lua (0x9FD6BA58)
- NPC `a_m_m_sddockforeman_01`: femga peds/peds_list.lua (0x44BCB3C8)
- Blip `blip_canoe` (62421675) and `BLIP_STYLE_SHOP`: femga useful_info_from_rpfs
- Prompt key `INPUT_CONTEXT_Y` (0xD51B784F, works in vehicles): femga Controls/README.md
- `_UI_PROMPT_SET_PRIORITY` (0xCA24F528D0D16289) / `PP_High`: brain natives/db and rdr3-native-enums
- Draw marker cylinder (0x94FDAE17) / `DRAW_MARKER` (0x2A32FAA57B937173): femga graphics / natives db

Support: https://buymeacoffee.com/rexshack
