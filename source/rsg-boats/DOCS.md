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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

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
