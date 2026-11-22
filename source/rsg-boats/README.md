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
- **Hire boats**: yards with boats for hire show a *Hire* tab. Pay a fee, get the boat for `Config.Rental.minutes` minutes (the clock starts when it is on the water). Hire boats have no storage and aren't owned; hand one back at any dock or it is taken back when time runs out, with a warning first. Admins set a hire price per model (0 = not for hire).
- **Storage upgrades**: *Upgrades* on each owned boat (while it is docked at the yard) buys extra storage slots and extra carry weight in levels (`Config.Upgrades`). Totals are capped by `Config.Storage.maxSlots` / `maxWeight`.
- **Fair sell-back**: the sell-back price is based on what you actually paid (purchase plus upgrades), not the model's current price. Boats bought before this update use the current model price.
- **Boat limit counter**: the shop shows boats owned / `Config.MaxBoats`, and buying is disabled at the limit.
- **Auto database install**: tables are created and upgraded on start.
- **Push-to-talk stays on**: all other game controls are blocked while a boat panel is open, but voice keeps working (`Config.AllowPushToTalkWhileOpen`).

## Install
1. Requires `rsg-core`, `rsg-target`, `rsg-gizmo`, `oxmysql`, `rsg-inventory`. ox_lib is **not** needed.
2. Add `ensure rsg-boats` after them in your server.cfg.
3. Start the server. The tables are created automatically (`Config.AutoDatabase = true`). To install by hand instead, set it to `false` and run `install.sql`.
4. The first start creates yard #1 (`Config.Yard.defaultName` at `Config.Yard.coords`) with a rowboat for sale.

## Admin: `/boatadmin`
**Yards tab**: choose a yard from the dropdown.
- *Rename*.
- *Move To My Position*: moves the NPC and blip to where you stand, facing your direction. This resets the yard's launch point and dock.
- *Launch Point*: pick a boat and press *Spawn Assistant*. A ghost boat appears and is moved with rsg-gizmo (the controls are shown on its HUD); the ghost turns red when it is out of range. Confirm to save, cancel to abort.
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
| `Config.Upgrades` | Enable, and the levels for `slots` and `weight` (each level: `price`, `add`; weight in grams) |
| `Config.Rental` | Enable, hire `minutes`, `warnSeconds` before the boat is taken back |
| `Config.Placer` | Spawn Assistant: start distance, max distance from the admin, ghost alpha |
| `Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls` | Keep push-to-talk working while the shop, admin panel or transfer popup is open |
| `Config.AutoDatabase`, `Config.DefaultBoats` | Auto install and the boats added on first install |
| `Config.Debug` | Console debug output |

All text is in `locales/`: player notifications, prompts, target labels, the whole NUI (`ui_*` keys) and Discord webhook embeds (`wh_*` keys). Included languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro and ru. Locales load through rsg-core (`@rsg-core/shared/locale.lua`); set the language with `setr rsg:locale "de"` in server.cfg (falls back to `ox:locale`, then `en`).

## Discord webhooks
Set these in `server/sv_config.lua`. It is server only, so webhook URLs are never sent to players.
- `default`: one channel for everything, or give each event its own `url`.
- Events: `buy`, `sell`, `launch`, `store`, `transfer`, `rent` (hire boats taken and returned), `upgrade`, `storage` (off by default, it's noisy), `admin` (yards, docks, launch points, allowed boats, models) and `exploit` (rejected boat claims, admin callbacks without permission).
- Each post is an embed with the details, the character name, citizen ID, server ID and license/Discord identifiers (`showIdentifiers`).
- `mentionOnExploit`: ping a staff role on exploit alerts.
- Posts are queued with built-in rate limiting and retries when Discord asks to wait (429), so busy servers don't lose logs.
- Test from the server console with `boatwebhooktest`.

## Database
- `rsg_boats_yards`: yards (coords, launch point, dock, allowed models)
- `rsg_boats_models`: boats for sale, their storage size and hire price
- `rsg_boats_owned`: owned boats, the yard each is stored at, the price paid and the bought upgrades
- `rsg_boats_settings`: only read once to migrate the old single-yard setup
- Boat storage is in rsg-inventory's `inventories` table (`boat_<id>`)

## Security
- Money, ownership, storage and transfers are handled only on the server, with ownership re-checked in the same SQL statement that changes it.
- Every shop, store and boat-storage action checks that the player is at that yard, has a cooldown, and checks the stored yard.
- Transfers re-check after the other player accepts: a boat launched while the offer was open can't be given away, and the receiver's boat limit is checked again.
- A launch the client never confirms is released after 30 seconds, so the player isn't stuck with a phantom boat out.
- The client's report of the launched boat is only accepted once, for the right model, near the launch point and not already claimed by another player. A modified client can't claim or delete someone else's entity.
- Admin callbacks check permission (`Config.AdminPermission` or the `command` ACE). Positions are read from the admin's ped on the server.
- A boat can't be sold while its storage holds items, so nothing is destroyed silently.
- Rejected-request (`exploit`) webhooks are limited to one per player and reason every 30 seconds and the webhook queue is capped, so a modified client can't flood Discord or server memory.

## Changelog
- **3.2.0**: hire boats (per-model hire price, time limit, warning, return at any dock); storage upgrades (extra slots and carry weight in levels); sell-back is now based on the price paid (new `price_paid` column); boats owned / limit counter in the shop; new `rent` and `upgrade` webhook events; admin models form has a hire price field; 29 new locale keys in all 11 languages. Boat speed upgrades were left out because no verified RedM native exists for boat speed.
- **3.1.1**: fixed *Set Dock* / *Save Radius* never saving (the dock request was sent with a stray argument); fixed a script error when closing the shop while a transfer offer was open; the Spawn Assistant now uses rsg-gizmo (custom placer, its HUD, `Config.Keys` and 5 locale keys removed); push-to-talk works while a boat panel is open; the shop closes when you die or walk away; selling a boat is refused while its storage still holds items, and its stash row is deleted afterwards; a failed purchase insert refunds the money; transfers re-check distance after the receiver accepts; exploit webhooks are rate limited and the webhook queue is capped; the server stops loading if the database install fails; Enter confirms popups; player ID must be a whole number; `Config.AutoInstallDB` renamed to `Config.AutoDatabase`.
- **3.1.0**: removed the ox_lib dependency (rsg-core callbacks, notify and locale loader); the transfer accept popup is now part of the boat NUI with a countdown; fixed the giver's request timing out after 10 seconds while the receiver still had time to accept; a player can only have one transfer offer open at a time; boat storage opening has a cooldown; dock ring uses the monochrome house style; dock loop stops checking other yards after storing.
- **1.1.1**: switched to rsg-target; fixed a transfer race that could duplicate a boat; stale launches now time out; store action has a cooldown; model labels and descriptions are sanitised; boats that sink no longer leave a stale storage target; shop can't be opened twice; remaining hard-coded UI text moved to locales; removed unused code and config.

## Data sources
- `rowboat`: femga/rdr3_discoveries vehicles/vehicles_list.lua (0x9FD6BA58)
- NPC `a_m_m_sddockforeman_01`: femga peds/peds_list.lua (0x44BCB3C8)
- Blip `blip_canoe` (62421675) and `BLIP_STYLE_SHOP`: femga useful_info_from_rpfs
- Prompt key `INPUT_CONTEXT_Y` (0xD51B784F, works in vehicles): femga Controls/README.md
- `_UI_PROMPT_SET_PRIORITY` (0xCA24F528D0D16289) / `PP_High`: brain natives/db and rdr3-native-enums
- Draw marker cylinder (0x94FDAE17) / `DRAW_MARKER` (0x2A32FAA57B937173): femga graphics / natives db

Support the Project : https://rexshack.tebex.store/
