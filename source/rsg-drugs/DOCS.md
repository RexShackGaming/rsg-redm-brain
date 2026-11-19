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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

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

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-drugs 3.1.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Database

Tables: `rsg_drugs_labs`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.NPC` | `table` |  |
| `Config.Items` | `table` |  |
| `Config.SeedChance` | `2.0` | chance (%) per fresh weed dried that a seed is found; collect them from the Supplies tab |
| `Config.Packing` | `table` | a packer adds their skill rate in work points each shift (e.g. Skilled = 1.5 per shift) |
| `Config.Food` | `{ bread = 1, cooked_meat = 2 }` | food and drink employees can be given (item = how many 'meals' it gives) |
| `Config.Water` | `{ water = 1 }` |  |
| `Config.TickSeconds` | `60` | one work shift tick |
| `Config.MaxEmployees` | `6` |  |
| `Config.MaxStorage` | `5000` | max of each stock type held at the lab (must be >= a brick's uses) |
| `Config.HungerDrain` | `8` | per tick |
| `Config.ThirstDrain` | `12` | per tick |
| `Config.MealRestore` | `50` | hunger restored per food unit |
| `Config.DrinkRestore` | `50` | thirst restored per water unit |
| `Config.AutoFeedBelow` | `50` | staff eat/drink from the pantry under this value |
| `Config.UnpaidStrikeTicks` | `3` | missed paydays before going on strike |
| `Config.Skill` | `table` | skill 1-5: production per tick and wage per tick |
| `Config.Roles` | `table` |  |
| `Config.HireFee` | `5.0` | one-off signing fee |
| `Config.CandidateCount` | `6` |  |
| `Config.CandidateRefreshMinutes` | `30` |  |
| `Config.FirstNames` | `{ 'Amos','Bill','Cyrus','Dutch','Eli','Floyd','Gus','Hattie','Ida','Je` |  |
| `Config.LastNames` | `{ 'Barlow','Cobb','Dawes','Fenwick','Grady','Holt','Kincaid','Mercer',` |  |
| `Config.XP` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.RepName` | `'drugs'` |  |
| `Config.Notify` | `true` |  |
| `Config.BrickMinLevel` | `5` |  |
| `Config.ResetOnJail` | `true` |  |
| `Config.Produce` | `table` | If the owner is offline it is banked and paid the next time they open the lab. |
| `Config.Sell` | `table` | XP per completed sale |
| `Config.Levels` | `table` | level thresholds (total XP needed) |
| `Config.Addiction` | `{}` |  |
| `Config.Addiction.TickInterval` | `60` | seconds between server addiction ticks (craving growth / natural decay) |
| `Config.Addiction.UseCooldown` | `5` | seconds, per player anti-spam on reported uses |
| `Config.Addiction.Substances` | `table` |  |
| `Config.Addiction.ShakeName` | `'DRUNK_SHAKE'` |  |
| `Config.Addiction.Stages` | `table` |  |
| `Config.Addiction.EffectInterval` | `15000` | ms between stumble/stress rolls on the client |
| `Config.Addiction.StumbleOnlyMoving` | `true` |  |
| `Config.Addiction.Rehab` | `table` |  |
| `Config.Addiction.NPC` | `table` |  |
| `Config.Addiction.Selling` | `table` |  |
| `Config.Export` | `table` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `AddUse` | `` | `server/addiction.lua` |
| `GetAddiction` | `src` | `server/addiction.lua` |
| `IsInRehab` | `src` | `server/addiction.lua` |
| `ReturnRehabItems` | `src` | `server/addiction.lua` |
| `DiscordLog` | `category, title, src, fields, description` | `server/discord.lua` |
| `AddXP` | `src, amount, reason` | `server/xp.lua` |
| `ResetXP` | `src` | `server/xp.lua` |
| `GetXP` | `src` | `server/xp.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `NpcSoldWeedBag` | `` | `client/addiction_npc.lua` |

```lua
-- example
local result = exports['rsg-drugs']:AddUse()
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-drugs:client:useSubstance` | client | `key` | `client/addiction.lua` |
| `rsg-consume:client:consume` | client | `itemName` | `client/addiction.lua` |
| `rsg-drugs:client:teleport` | client | `pos` | `client/addiction.lua` |
| `rsg-drugs:client:disarm` | client | `` | `client/addiction.lua` |
| `rsg-drugs:client:reequip` | client | `list` | `client/addiction.lua` |
| `rsg-drugs:client:openUI` | client | `` | `client/addiction.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/addiction.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/addiction_npc.lua` |
| `RSGCore:Client:OnJobUpdate` | client | `job` | `client/addiction_npc.lua` |
| `RSGCore:Client:SetDuty` | client | `onDuty` | `client/addiction_npc.lua` |
| `RSGCore:Player:SetPlayerData` | client | `data` | `client/addiction_npc.lua` |
| `rsg-drugs:client:sellAlert` | client | `coords` | `client/addiction_npc.lua` |
| `rsg-drugs:client:refresh` | client | `data` | `client/client.lua` |
| `rsg-drugs:server:consumed` | server | `itemName` | `server/addiction.lua` |
| `rsg-drugs:server:npcRehab` | server | `netId` | `server/addiction.lua` |
| `rsg-drugs:server:checkIn` | server | `` | `server/addiction.lua` |
| `rsg-drugs:server:closed` | server | `` | `server/server.lua` |
| `rsg-prison:server:startSentence` | server | `` | `server/xp.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-drugs:server:consumed', itemName)
-- from a server script
TriggerClientEvent('rsg-drugs:client:useSubstance', source, key)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/addiction` | locale('cmd_addiction') | `server/addiction.lua` |
| `/rehab` | locale('cmd_rehab') | `server/addiction.lua` |
| `/clearaddiction` | locale('cmd_clear') | `server/addiction.lua` |
| `/setaddiction` | locale('cmd_set') | `server/addiction.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
