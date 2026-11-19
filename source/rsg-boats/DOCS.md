# rsg-boats – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Admin panel
5. Events and commands
6. Database
7. Discord webhooks
8. Security
9. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory` |
| `shared/config.lua` | Yard, limits, dock, transfer, storage, placer, defaults |
| `client/client.lua` | Yard NPCs, shop NUI, launch, dock storing, boat storage |
| `client/placer.lua` | Ghost-boat spawn placer (Spawn Assistant) |
| `server/server.lua` | Buy, launch, store, sell, transfer, storage, admin callbacks |
| `server/database.lua` | Automatic table creation and upgrade |
| `server/sv_config.lua`, `server/webhooks.lua` | Webhook settings and Discord embeds |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI shop and admin panel |
| `install.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- **Multiple boat yards:** each has an NPC (rsg-target), blip, launch point, dock zone and list of allowed boats.
- **Shop** (target the dock foreman, *Browse Boats*): *For Sale* buys boats this yard sells (cash). *My Boats* launches, sells back (`SellBackRate`), gives a boat to another player, or stores the boat on the water.
- **Dock storing:** drive into a yard's dock zone (white ring) and hold `E` on *Store Boat*; you are placed back on the dock.
- **Boats stay where you leave them** (`LockToYard`): a boat can only be launched or sold at the yard it's stored at. Store it at another dock to move it.
- **Boat storage:** each owned boat has its own rsg-inventory stash `boat_<id>`; target the boat and choose *Boat Storage*, or open your inventory while in it.
- **Give a boat:** *Give* in *My Boats*, then the player's server ID. They must be nearby and accept the popup before it times out.
- Shop and admin windows can be dragged and positions are remembered per player.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Console debug |
| `Yard` | table | First yard: `defaultName`, `coords`, `npcModel`, `blip`, `targetDistance`, `npcSpawnDistance` |
| `FallbackSpawnOffset` | `(0, 8, -1)` | Launch point if none is set |
| `MaxBoats` | `0` | Boats per character (0 = unlimited) |
| `LockToYard` | `true` | Boats tied to the yard they're stored at |
| `MoneyType` / `SellBackRate` | `'cash'` / `0.5` | Payment and sell-back share |
| `ActionRadius` / `MaxPointDistance` / `StoreRadius` | `15.0` / `300.0` / `60.0` | Distances |
| `Dock` | table | `radius`, `minRadius`, `maxRadius`, `promptKey` (E), `holdTime`, `showMarker` |
| `Transfer` | table | Enable, max distance, require accept, accept timeout |
| `Storage` | table | Enable, default/max slots and weight (grams), target distance, show in inventory while in boat |
| `AdminCommand` / `AdminPermission` | `'boatadmin'` / `'admin'` | Admin panel |
| `Placer`, `Keys` | tables | Spawn Assistant speeds and controls |
| `AutoInstallDB` | `true` | Create/update tables on start |
| `DefaultBoats` | list | Boats added on first install (rowboat) |

## 4. Admin panel
`/boatadmin` opens two tabs.
- **Yards:** pick a yard, then *Rename*; *Move To My Position* (moves NPC and blip, resets launch point and dock); *Launch Point* (pick a boat, *Spawn Assistant*: arrow keys move, Q/E rotate, PgUp/PgDn height, Shift fast, Enter save, Backspace cancel); *Dock & Store Zone* (*Set Dock At My Position*, *Save Radius*); *Boats Sold & Stored Here* (all boats or ticked models); *Delete Yard*; *New Yard At My Position*. Moving or deleting a yard is blocked while a player has a boat out from it.
- **Boat Models:** add, edit or remove models (model name, label, price, for sale, storage slots, max weight in kg, description). The model name is verified in game as a real vehicle.

## 5. Events and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-boats:server:launched` | server event | `(netId)` boat spawned |
| `rsg-boats:server:launchFailed` | server event | Release the launch |
| `rsg-boats:server:inBoatInventory` | server event | `(netId)` open storage from inside |
| `rsg-boats:client:yards` | client event | Yard list sync |
| `rsg-boats:client:openAdmin` | client event | Open the admin panel |

| Command | Who | What |
|---|---|---|
| `/boatadmin` | `AdminPermission` | Admin panel |
| `/boatwebhooktest` | server console only | Send a test Discord embed for every event |

## 6. Database
Created and upgraded automatically on start (`AutoInstallDB`); import `install.sql` if you set it to `false`.
- `rsg_boats_models`: `model`, `label`, `description`, `price`, `enabled`, `slots`, `weight`.
- `rsg_boats_owned`: `citizenid`, `model`, `label`, `purchased`, `yard`.
- `rsg_boats_yards`: `name`, `coords`, `spawn`, `dock`, `models`.
- `rsg_boats_settings`: `k`, `v`.

## 7. Discord webhooks
Set URLs in `server/sv_config.lua` (server only). `default` sends everything to one channel, or give each event its own `url`. Events: `buy`, `sell`, `launch`, `store`, `transfer`, `storage` (off by default, noisy), `admin` and `exploit`. Embeds include character name, citizen ID, server ID and identifiers (`showIdentifiers`); `mentionOnExploit` pings a staff role. Posts are queued with rate limiting and retry on Discord 429.

## 8. Security
The server owns purchases, ownership, launching, storing and transfers. It checks distance to the yard, allowed models, ownership and one pending offer. Admin callbacks are permission-checked and rejected claims are logged as `exploit`.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| Can't launch | The boat is stored at another yard (`LockToYard`) |
| Can't store | Drive into the dock zone ring and hold `E` |
| Give fails | Target must be nearby and accept in time |
| Admin edits blocked | A player has a boat out from that yard |
| No tables | Set `AutoInstallDB = true` or import `install.sql` |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-boats 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`

### Database

Tables: `rsg_boats_models`, `rsg_boats_owned`, `rsg_boats_yards`, `rsg_boats_settings`.

For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` |  |
| `Config.Yard` | `table` | Boat yard |
| `Config.FallbackSpawnOffset` | `vector3(0.0, 8.0, -1.0)` | Fallback launch point if no admin has set one yet (offset in front of the NPC) |
| `Config.MaxBoats` | `0` | max boats one character can own (0 = unlimited) |
| `Config.LockToYard` | `true` | boats can only be launched/sold at the yard they are stored at |
| `Config.MoneyType` | `'cash'` |  |
| `Config.SellBackRate` | `0.5` | 50% refund when selling a boat back |
| `Config.ActionRadius` | `15.0` | server: max distance from the yard to buy / launch / sell |
| `Config.MaxPointDistance` | `300.0` | launch point / dock must be within this distance of their yard |
| `Config.StoreRadius` | `60.0` | shop 'Store Boat' button: boat must be this close to the yard |
| `Config.Dock` | `table` | Dock / store zone (defaults to the yard NPC position; admins set position + radius per yard in /boatadmin) |
| `Config.Cooldown` | `2000` | ms between shop actions per player |
| `Config.WarpIntoBoat` | `true` |  |
| `Config.Transfer` | `table` | Transfer ownership to another player (My Boats tab) |
| `Config.Storage` | `table` | Boat storage (rsg-inventory stash per owned boat; slots/weight set per model in /boatadmin) |
| `Config.AdminCommand` | `'boatadmin'` | Admin |
| `Config.AdminPermission` | `'admin'` |  |
| `Config.Placer` | `table` | Ghost placer |
| `Config.Keys` | `table` | Controls: femga Controls/README.md |
| `Config.AutoInstallDB` | `true` | create/update tables automatically on resource start (set false to use install.sql manually) |
| `Config.DefaultBoats` | `table` | boats added on first install only (rowboat: femga/rdr3_discoveries vehicles_list 0x9FD6BA58) |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-boats:client:transferOffer` | client | `cb, fromName, label, yardName` | `client/client.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-boats:client:transferOffer', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-boats:client:yards` | client | `` | `client/client.lua` |
| `rsg-inventory:client:open` | client | `_, other` | `client/client.lua` |
| `rsg-boats:client:openAdmin` | client | `` | `client/client.lua` |
| `rsg-boats:server:launched` | server | `netId` | `server/server.lua` |
| `rsg-boats:server:launchFailed` | server | `` | `server/server.lua` |
| `rsg-boats:server:inBoatInventory` | server | `netId` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-boats:server:launched', netId)
-- from a server script
TriggerClientEvent('rsg-boats:client:yards', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/boatwebhooktest` |  | `server/webhooks.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
