# rsg-drugs – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. Database
6. Discord logs
7. Security
8. Server owner how-tos
9. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Lab: NPC, items, packing, roles, hiring, XP |
| `shared/config_addiction.lua` | Addiction: substances, rehab, NPC selling |
| `shared/config_export.lua` | Brick export market |
| `client/client.lua`, `html/index.html`, `html/script.js`, `html/style.css` | Lab NUI |
| `client/export.lua`, `html/export.*` | Brick export NUI |
| `client/addiction.lua`, `html/addiction.*` | Addiction HUD and rehab countdown |
| `client/addiction_npc.lua` | NPC addicts: inspect, rehab, sell |
| `client/utils.lua` | NPC spawning helpers |
| `server/server.lua` | Labs, crew, work loop |
| `server/export.lua` | Brick market |
| `server/addiction.lua` | Dependency, craving, rehab, commands |
| `server/xp.lua` | Drug reputation |
| `server/discord.lua`, `server/config_discord.lua` | Discord logs (server-only config) |
| `server/versionchecker.lua` | GitHub version check |
| `installation/install.sql` | Database install |
| `installation/shared_items.lua` | Items to add to `rsg-core/shared/items.lua` |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
### Cannabis lab
- Talk to the processing NPC (rsg-target) to open the lab NUI. Bring fresh `weed`.
- Hire a crew (up to `MaxEmployees`): **dryers** (`weed` → `weed_dried`), **processors** (`weed_dried` → `weed_processed`) and **packers** (`weed_processed` → `weed_bag` or `weed_brick`). Employees need food and water.
- Work runs in shifts every `TickSeconds`. A packer adds their skill rate in work points each shift; a unit needs `Config.Packing[x].work` points and uses `uses` processed weed.
- Dryers have a `SeedChance` (2%) to find a `seedweed`, collected from Supplies.
- Stock held at the lab is capped by `MaxStorage`.

### Brick export (demand market)
- Players at **Distributor or higher** (`Config.Export.MinLevel`) sell `weed_brick` to a buyer NPC (*Talk business*).
- Price follows supply: an empty market pays `MaxPrice`, sliding to `MinPrice` as buyer stock nears `Saturation`. Stock drains over time and demand drifts between `DemandMin` and `DemandMax`.
- The market is shared by all players and saved in resource KVP (no SQL).
- Move the default buyer coords (`Config.Export.NPC.coords`) to your own location.

### Reputation (XP)
- Stored as rsg-core rep `drugs`. Production gives the lab owner XP per finished unit (bag 1, brick 50); each bag sold to an NPC gives 2 XP; each exported brick gives 60 XP.
- Levels: Street Kid → Peddler → Dealer → Supplier → Distributor → Kingpin (`Config.XP.Levels`).
- Brick packing needs the owner at `XP.BrickMinLevel` (5 = Distributor) or higher.
- Starting an rsg-prison sentence resets drug XP (`XP.ResetOnJail`).

### Addiction and rehab (alcohol and weed)
- Dependency (0–100) rises each time a configured item is used. Past the substance's `threshold` the player is **hooked**.
- While hooked, craving grows every `TickInterval` seconds and causes withdrawal effects unless the player feeds the habit. Using the substance resets craving but raises dependency.
- Not hooked: dependency decays by `decay` per tick.
- The cure is rehab (jail-style stint at Sisika): belongings are confiscated and returned on release; weapons are removed and re-equipped.
- Lawmen (`AllowedJobTypes`), medics (`AllowedJobs`) and admins can send players to rehab; players can also check in voluntarily. Officers earn a bonus per admission (`Reward`).
- NPC addicts can be inspected, sent to rehab or sold to (`Config.Addiction.Selling`).

## 3. Configuration
`shared/config.lua`:
| Option | Meaning |
|---|---|
| `NPC` | Processing NPC: `coords`, `model`, `spawnDistance`, `interactDistance`, `targetDistance` |
| `Items` | `raw`, `dried`, `processed`, `brick`, `bag`, `seed` item names |
| `SeedChance` | % per fresh weed dried |
| `Packing` | `bag` / `brick`: `uses`, `work` |
| `Food`, `Water` | Items employees can be given |
| `TickSeconds`, `MaxEmployees`, `MaxStorage` | Work loop |
| `Roles` | dryer, processor, packer |
| `HireFee`, `CandidateCount`, `CandidateRefreshMinutes` | Hiring |
| `XP` | `Enabled`, `BrickMinLevel`, `Levels`, per-item XP, `ResetOnJail` |

`shared/config_addiction.lua`: `Config.Addiction` with `TickInterval`, `UseCooldown`, `Substances` (alcohol, weed: `items`, `threshold`, `decay`, `cravingRate`, scenarios), `Rehab` (`DefaultMinutes`, `MaxMinutes`, `VoluntaryMinutes`, `Centre`, `Spawns`, `Release`, `AllowedJobTypes`, `AllowedJobs`, `AdminPermission`, `MaxAdmitDistance`, `Reward`, `Confiscate`) and `Selling`.

`shared/config_export.lua`: `Config.Export` (`MinLevel`, `NPC`, `MaxPrice`, `MinPrice`, `Saturation`, `TickMinutes`, `DrainPerHour`, `DemandMin`, `DemandMax`, `MaxPerSale`, `Cooldown`).

## 4. Exports, events and commands
| Name | Side | Notes |
|---|---|---|
| `AddXP(src, amount, reason)` | server export | Add drug XP; add a `xp_reason_<reason>` locale key for a label |
| `GetXP(src)` | server export | `{ xp, level, label, from, to }` |
| `ResetXP(src)` | server export | Returns XP removed |
| `AddUse(...)` | server export | Register a substance use |
| `GetAddiction(src)` | server export | Addiction state |
| `IsInRehab(src)` | server export | bool |
| `ReturnRehabItems(src)` | server export | Return confiscated items |
| `DiscordLog(category, title, src, fields, description)` | server export | Write to the drug log channels |
| `NpcSoldWeedBag(ped)` | client export | Tell the addiction system an NPC bought a bag |
| `rsg-drugs:client:open` / `exportOpen` / `openUI` | client events | Open lab, export or addiction UI |
| `rsg-drugs:server:consumed` | server event | `(itemName)` from rsg-consume |
| `rsg-drugs:server:npcRehab` | server event | `(netId)` |

| Command | Who | What |
|---|---|---|
| `/addiction` | everyone | Show your addiction status |
| `/rehab [id] [minutes]` | lawmen, medics, admins | Send a player to rehab |
| `/clearaddiction [id]` | admin | Clear a player's addiction |
| `/setaddiction [id] [substance] [level]` | admin | Set a dependency level |

Example, reward XP from a delivery script:
```lua
exports['rsg-drugs']:AddXP(src, 25, 'delivery')
```

## 5. Database
`rsg_drugs_labs`: `citizenid` (primary key), `data` (LONGTEXT JSON for the lab). Import `installation/install.sql`, and add `installation/shared_items.lua` to your items file. Addiction and XP live in player metadata; the export market lives in resource KVP.

## 6. Discord logs
Set URLs in `server/config_discord.lua` (`ConfigDiscord.Webhooks` per category, or `ConfigDiscord.Default` for one channel; `false` turns a category off). Categories: `lab`, `sales`, `export`, `xp`, `rehab`, `admin`, `security`. Logs are queued and batched (up to 10 embeds per message every `FlushSeconds`) with back-off on Discord rate limits. `MinDeposit` / `MinWithdraw` filter small transactions.

## 7. Security
All XP, payouts and prices come from config on the server; clients can't send amounts. Every NUI action checks distance to the NPC. Export sales check buyer distance, level, item count and cooldown. Officers can't send their own customers to rehab for the bonus (logged under `security`).

## 8. How-tos
- Start: `ensure rsg-drugs` after rsg-core, rsg-inventory, rsg-target; run `install.sql`; add the items.
- Optional integrations: rsg-consume (alcohol), rsg-hud (stress relief), rsg-weapons (re-equip after rehab), rsg-farming (weed seeds).
- Language: `setr rsg:locale "de"` in server.cfg; config labels use `cfg_*` locale keys.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| Can't switch packers to bricks | Owner level is below `BrickMinLevel` |
| No export option | Player below `Export.MinLevel` or the buyer NPC isn't where you expect |
| Items missing | Add `installation/shared_items.lua` to your items |
| Rehab bonus not paid | Job must be in `AllowedJobTypes`/`AllowedJobs`; NPC rewards have a cooldown |

Support the Project : https://rexshack.tebex.store/
