# rsg-drugs – Docs (v3.4.0)

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
| `shared/config_addiction.lua` | Addiction: substances, rehab, NPC addicts |
| `shared/config_corner.lua` | Corner selling: items, customers, haggle rules, handover animation, law alert |
| `shared/config_export.lua` | Brick export market |
| `client/client.lua`, `html/index.html`, `html/script.js`, `html/style.css` | Lab NUI |
| `client/export.lua`, `html/export.*` | Brick export NUI |
| `client/addiction.lua`, `html/addiction.*` | Addiction HUD and rehab countdown |
| `client/addiction_npc.lua` | NPC addicts: inspect, rehab, law alert blip |
| `client/corner.lua`, `html/corner.*` | Corner selling: picks and walks up customers, haggle NUI |
| `client/utils.lua` | NPC spawning, handover animation with the package prop (`DrugsHandover(ped, frozen, prop)`), ambient-ped check (`DrugsIsAmbient`), NUI focus helper (`DrugsNuiFocus`, push-to-talk whitelist) and panel auto-close (`DrugsWatchPanel`) |
| `server/utils.lua` | Shared server helpers: `DrugsCallback` wrapper and `DrugsEnsureDatabase()` (builds both tables once) |
| `server/integrations.lua` | Guarded rsg-skills, rsg-reputation and rsg-economy calls (`DrugsSkills`, `DrugsRep`, `DrugsEcon`) |
| `server/server.lua` | Labs, crew, work loop, potency, heat and raids |
| `server/export.lua` | Brick market |
| `server/addiction.lua` | Dependency, craving, rehab, commands, NPC addict state (`DrugsNpc`) and the law alert (`DrugsAlertLaw`) |
| `server/corner.lua` | Corner selling: sessions, the haggle, payouts, `/corner` |
| `server/xp.lua` | Drug reputation |
| `server/board.lua` | Dealer leaderboard (`DrugsBoard.Record`, `DrugsBoard.Top`), persisted in `rsg_drugs_state` key `board` |
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
- The market is shared by all players and saved in the `rsg_drugs_state` table (no resource KVP, so no server `db` folder).
- Move the default buyer coords (`Config.Export.NPC.coords`) to your own location.

### Reputation (XP)
- Stored as rsg-core rep `drugs`. Production gives the lab owner XP per finished unit (bag 1, brick 50); each bag sold to an NPC gives 2 XP; each exported brick gives 60 XP.
- Levels: Street Kid → Peddler → Dealer → Supplier → Distributor → Kingpin (`Config.XP.Levels`).
- Brick packing needs the owner at `XP.BrickMinLevel` (5 = Distributor) or higher.
- Starting an rsg-prison sentence resets drug XP (`XP.ResetOnJail`).

### Potency, heat and raids
- **Potency** is 0-100 per stock type (`lab.q`). Output potency = `InputWeight` x input potency + (1 - `InputWeight`) x the working crew's average `CrewPotency[skill]`, then averaged into what is already in stock. Withdrawn items get `info.potency` (rounded to `Config.Quality.Step`, so stacks of the same potency still merge in rsg-inventory). Items without potency count as `Config.Quality.Default`. Price multiplier = `PriceMin` + (`PriceMax` - `PriceMin`) x potency / 100. Bricks are exported best potency first and you are paid for exactly what left your inventory.
- **Heat** is stored on the lab (`lab.heat`, 0-`Max`). Sources: bricks/bags finished by the crew, corner sales, exported bricks, buyers who report you (`Config.Heat`). It only counts for players who have a lab with crew or stock. Each shift it decays by `Decay`. Above `RaidThreshold` there is a `RaidChance`% chance per shift of a raid, if at least `MinLaw` on-duty law (`Bribe` (`Enabled`, `Base`, `PerHeat`, `SuccessChance`, `HeatAfterBribe`, `FailHeat`, `HeatCut`, `MinHeat`, `CooldownMinutes`, `MoneyType`), `LawJobTypes` / `LawJobs`) are online and the lab is not on cooldown. The law gets `rsg-drugs:client:raidAlert` (blip around the lab NPC for `RaidWindowMinutes`), the owner gets a warning.
- **Raid:** an on-duty officer uses the *Raid Lab* target on the processing NPC (`rsg-drugs:server:raid`). The server takes the oldest pending raid, destroys `SeizePercent` of every stock type (nothing is handed to anyone), sets heat to `HeatAfterRaid`, starts the raid cooldown, pays `OfficerReward` (not for your own lab) and tells the owner (or leaves a notice for the next time they open the lab). If nobody raids in time heat drops to `HeatAfterEscape`.
- **Wage chest warning:** `Config.Payroll.WarnShifts` / `WarnCooldownMinutes`.

### Integrations
All calls go through `server/integrations.lua`, are wrapped in `pcall` and skipped when the resource is not started.
- **rsg-skills** (`Config.Skills`): registers the skill `Config.Skills.Key` (default `drugs`) on start and when rsg-skills announces itself. Every `DrugsXP.Add` also calls `AddXP` (scaled by `XPScale`). Perks read with `GetPerk`: `sell_bonus` (corner street price and brick payout, %) and `speed_bonus` (crew output, %, kept on the lab for when the owner is offline). Drug XP resets on jail also set the skill XP to 0 when `ResetOnJail` is true. The perk names in the skills panel come from rsg-skills' locale keys `perk_sell_bonus` and `perk_speed_bonus`.
- **rsg-reputation** (`Config.Reputation.Events`): `sale`, `refused`, `export`, `rehab`, `raid` each give honor and/or standing (standing in the town found with rsg-economy `GetRegionAt`). `IsHostile` for the town makes most buyers ignore you (`HostileBuyMult` is the share that still deal).
- **rsg-economy** (`Config.Economy`): The street price of a corner sale is multiplied by `GetMarketMultiplier(item, region)` and the sale is reported with `RecordTrade(item, region, qty, 'sell')`.

### Addiction and rehab (alcohol and weed)
- Dependency (0–100) rises each time a configured item is used. Past the substance's `threshold` the player is **hooked**.
- While hooked, craving grows every `TickInterval` seconds and causes withdrawal effects unless the player feeds the habit. Using the substance resets craving but raises dependency.
- Not hooked: dependency decays by `decay` per tick.
- The cure is rehab (jail-style stint at Sisika): belongings are confiscated and returned on release; weapons are removed and re-equipped.
- Lawmen (`AllowedJobTypes`), medics (`AllowedJobs`) and admins can send players to rehab; players can also check in voluntarily. Officers earn a bonus per admission (`Reward`).
- NPC addicts can be inspected and sent to rehab. Buyers get hooked through corner sales (see below).
- Substances: alcohol (via rsg-consume), weed (`weed_joint`), opium (`opium_resin`, for your own gathering or crafting script) and tobacco (rsg-smoking calls `AddUse(src, 'tobacco', amount)`).

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
| `Payroll` | `WarnShifts`, `WarnCooldownMinutes` |
| `Quality` | `Enabled`, `Default`, `InputWeight`, `Step`, `CrewPotency`, `PriceMin`, `PriceMax` |
| `Heat` | `Enabled`, `Max`, `Decay`, `PerBrick`, `PerBag`, `PerExportBrick`, `PerSale`, `PerRefusal`, `RaidThreshold`, `RaidChance`, `MinLaw`, `RaidWindowMinutes`, `SeizePercent`, `HeatAfterRaid`, `HeatAfterEscape`, `CooldownMinutes`, `OfficerReward`, `MoneyType`, `AlertRadius`, `LawJobTypes`, `LawJobs` |
| `Skills` | `Enabled`, `Key`, `XPScale`, `ResetOnJail`, `Definition` (label, maxLevel, perks) |
| `Reputation` | `Enabled`, `HostileBuyMult`, `Events` |
| `Economy` | `Enabled` |
| `AllowPushToTalkWhileOpen`, `PushToTalkControls` | Keep push-to-talk working while a panel has NUI focus (all other controls are blocked) |

`shared/config_addiction.lua`: `Config.Addiction` with `TickInterval`, `UseCooldown`, `Substances` (alcohol, weed: `items`, `threshold`, `decay`, `cravingRate`, scenarios), `Rehab` (`DefaultMinutes`, `MaxMinutes`, `VoluntaryMinutes`, `Centre`, `Spawns`, `Release`, `AllowedJobTypes`, `AllowedJobs`, `AdminPermission`, `MaxAdmitDistance`, `Reward` (`Amount`, `MoneyType`, `NpcCooldown`, `PlayerCooldown`), `Confiscate`) and `NPC` (visual addicts).

`shared/config_corner.lua`: `Config.Corner` (`Command`, `MoneyType`, `BlockLaw`, `Items` (`price`, `maxQty`, `addicts`), `Market` (`Enabled`, `Window`, `MinSales`), `Spot.LeaveRadius`, `Approach` (`FirstSeconds`, `EverySeconds`, `Source`, `Debug`, `Radius`, `IgnoreSeconds`, `SpawnMin`, `SpawnMax`, `LeaveDistance`, `LeaveSpeed`, `LeaveTimeout`, `DespawnDistance`, `Models`, `StopDistance`, `Speed`, `Timeout`), `Towns` (`Enabled`, `Default`, `List[regionId]` with `price`, `ceiling`, `heat`, `sting`), `Regulars` (`Enabled`, `Max`, `Recruit`, `FairMult`, `Return`, `CooldownMinutes`, `PerLevel`, `MaxLevel`, `CeilingBonus`, `QtyBonus`, `Names`), `Buyers` (`regular`, `cheap`, `bigspender`, `undercover`: `weight`, `ceiling`, `qty`, `patience`), `Sting` (`Enabled`, `MinLaw`, `CeilingMin/Max`, `OpenMin/Max`, `Heat`), `Rank` (`Enabled`, `Levels`), `Demand` (`Enabled`, `Capacity`, `MaxDrop`, `Recover`), `Haggle` (`CeilingMin/Max`, `OpeningMin/Max`, `PatienceMin/Max`, `ConcedeMin/Max`, `StubbornMin/Max`, `CloseEnough`, `InsultMult`, `InsultPatience`, `CallLawChance`, `MaxAskMult`, `Step`, `ShowStreetPrice`, `OfferCooldown`, `DealSeconds`, `MinInterval`, `MaxDealsPerHour`), `AddictRebuyMinutes`, `Anim` (`Dict`, `Player`, `Ped`, `Prop` (`Enabled`, `Model`, `Bone`, `BoneId`, `HandoffAt`, `Player`, `Ped`)), `Alert` (`JobTypes`, `Jobs`, `Duration`, `Radius`, `Offset`, `ShrinkStep`, `MinRadius`, `ExactRadius`)).

`shared/config.lua` also has `Config.Upgrades` (`MoneyType`, `List`, per upgrade `label`, `desc`, `levels` of `cost` and `bonus`), `Config.Events` (`Enabled`, `Chance`, `TheftWeight`, `TheftPercent`, `FirePercent`) and `Config.Board` (`Enabled`, `Rows`). `Config.Addiction.NPC.AmbientPopTypes` is the optional server check that a buyer is a real ambient ped (`false` = off).

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
| `IsCornerSelling(src)` | server export | true while the player is working the corner |
| `StopCorner(src)` | server export | End the player's corner session |
| `NpcSoldWeedBag(ped)` | client export | Tell the addiction system an NPC bought a bag (visual only) |
| `rsg-drugs:client:open` / `exportOpen` / `openUI` | client events | Open lab, export or addiction UI |
| `rsg-consume:server:consumed` | server event (from rsg-consume 3.3.0+) | `(src, itemName, category, data, meta)` |
| `rsg-drugs:server:npcRehab` | server event | `(netId)` |
| `rsg-drugs:server:cornerStop` / `cornerWalk` | server events | Client ends its own corner session / walks away from the open haggle (both only ever affect the sender) |
| `rsg-drugs:server:cornerApproach` / `cornerOffer` / `cornerAccept` | server callbacks | A buyer arrived `(netId)` / the player names a price `(price)` / the player takes the last counter. All state lives on the server |
| `rsg-drugs:client:cornerState` | client event (server to player) | `(on, pos)` session started or stopped |
| `rsg-drugs:client:cornerDealEnd` | client event (server to player) | The server dropped the open haggle |
| `rsg-drugs:client:npcBought` | client event | `(ped, hooked)` after a corner sale: starts the visual addict behaviour |
| `rsg-drugs:server:raid` | server event | no arguments; on-duty law at the processing NPC raids the oldest reported lab |
| `rsg-drugs:client:raidAlert` | client event (server to law) | `(minutes)`; blip around the lab NPC and a notification |

| Command | Who | What |
|---|---|---|
| `/corner` | everyone | Start or stop corner selling (`Config.Corner.Command`) |
| `/addiction` | everyone | Show your addiction status |
| `/rehab [id] [minutes]` | lawmen, medics, admins | Send a player to rehab |
| `/clearaddiction [id]` | admin | Clear a player's addiction |
| `/setaddiction [id] [substance] [level]` | admin | Set a dependency level |

Example, reward XP from a delivery script:
```lua
exports['rsg-drugs']:AddXP(src, 25, 'delivery')
```

## 5. Database
`rsg_drugs_labs`: `citizenid` (primary key), `data` (LONGTEXT JSON for the lab).
`rsg_drugs_state`: `key` (primary key, currently `market`), `value` (LONGTEXT JSON of the export market: stock, demand, price history).

Both tables are created automatically (`Config.AutoDatabase`). To install manually set it to `false`, import `installation/install.sql`, and add `installation/shared_items.lua` to your items file. Addiction and XP live in player metadata; the export market lives in `rsg_drugs_state`.

## 6. Discord logs
Set URLs in `server/config_discord.lua` (`ConfigDiscord.Webhooks` per category, or `ConfigDiscord.Default` for one channel; `false` turns a category off). Categories: `lab`, `sales`, `export`, `xp`, `rehab`, `admin`, `security`. Logs are queued and batched (up to 10 embeds per message every `FlushSeconds`) with back-off on Discord rate limits. `MinDeposit` / `MinWithdraw` filter small transactions.

## 7. Security
All XP, payouts and prices come from config on the server; clients can't send amounts. Every NUI action checks distance to the NPC. Export sales check buyer distance, level, item count and cooldown. Officers can't send their own customers to rehab for the bonus (logged under `security`), and player admissions pay one bonus per `Reward.PlayerCooldown` per officer. The lab payload and its supplies list come from one server callback, so the client never asks for inventory data separately. Panels close on the client when you walk away or die, and the server still rejects any action from too far away. A raid needs an on-duty law job, distance to the NPC, a pending raid created by the server's own heat roll (the client cannot start one) and a 3 second cooldown; seized stock is destroyed, and raiding your own lab pays nothing. Potency and prices are worked out on the server from the stack's `info.potency` and config. The only price the client ever sends is the one the player typed into a corner haggle: the server clamps it to `0.01` - `MaxAskMult` x street price, ignores NaN/infinite/non-numeric values, rate-limits offers (`OfferCooldown`) and haggles (`MinInterval`), allows one open haggle per player and per NPC, keeps each buyer's limit and patience private, re-checks distance, the NPC and the stock on every offer, and pays only for items it really removed.

## 8. How-tos
- Start: `ensure rsg-drugs` after rsg-core, rsg-inventory, rsg-target; run `install.sql`; add the items.
- Optional integrations: rsg-consume (alcohol), rsg-hud (stress relief), rsg-weapons (re-equip after rehab), rsg-farming (weed seeds).
- Language: `setr rsg:locale "de"` in server.cfg; config labels use `cfg_*` locale keys.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| Can't switch packers to bricks | Owner level is below `BrickMinLevel` |
| No export option | Player below `Export.MinLevel` or the buyer NPC isn't where you expect |
| Items missing | Add `installation/shared_items.lua` to your items (includes `opium_resin`) |
| No raids ever happen | Heat must reach `RaidThreshold`, at least `MinLaw` on-duty law must be online and the lab needs crew or stock |
| Standing never changes | rsg-reputation and rsg-economy must both be started (the town comes from rsg-economy `GetRegionAt`) |
| Town settings never apply | `Config.Corner.Towns.List` keys must match the rsg-economy region id in lower case. Set `Config.Corner.Approach.Debug = true` and read the printed region |
| Regulars never come back | They need `Regulars.Return` luck, are away for `CooldownMinutes` after each deal and are saved in the character metadata `cornerregulars` |
| Buyers are never hooked after enabling `AmbientPopTypes` | Your build uses other population type numbers: set `Config.Corner.Approach.Debug = true`, sell to a real ambient ped and copy the printed type into `AmbientPopTypes` |
| `/corner` does nothing | You need at least one item from `Config.Corner.Items`; on-duty law, jailed, dead and in-rehab players are blocked |
| Nobody walks up | Set `Approach.Debug = true` and read the F8 console. `Source = 'both'` uses ambient peds first and spawns one if none arrive. Spawned customers are `SpawnMin`-`SpawnMax` m away and need a walkable spot within 8 m of your height; steep or water-heavy spots can fail and retry. Check the `Models` names and that the customer can reach you within `Timeout` seconds |
| Corner session ends by itself | You moved more than `Spot.LeaveRadius` from your spot, died, or ran out of stock |
| Rehab bonus not paid | Job must be in `AllowedJobTypes`/`AllowedJobs`; NPC rewards have a cooldown |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-drugs 3.4.0**. Names, arguments and defaults below are read straight from the code.

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
| `Config.Export` | `table` |  |
| `Config.Corner` | `table` | corner selling: `Command` (`/corner`), `Items`, `Market`, `Buyers`, `Sting`, `Rank`, `Demand`, `Spot`, `Approach`, `Haggle`, `AddictRebuyMinutes`, `Anim`, `Alert` |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `AddUse` | `` | `server/addiction.lua` |
| `GetAddiction` | `src` | `server/addiction.lua` |
| `IsInRehab` | `src` | `server/addiction.lua` |
| `ReturnRehabItems` | `src` | `server/addiction.lua` |
| `IsCornerSelling` | `src` | `server/corner.lua` |
| `StopCorner` | `src` | `server/corner.lua` |
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
| `rsg-drugs:client:cornerState` | client | `on, pos` | `client/corner.lua` |
| `rsg-drugs:client:cornerDealEnd` | client | `` | `client/corner.lua` |
| `rsg-drugs:client:npcBought` | client | `ped, hooked` | `client/addiction_npc.lua` |
| `rsg-drugs:server:cornerStop` | server | `reason` | `server/corner.lua` |
| `rsg-drugs:server:cornerWalk` | server | `` | `server/corner.lua` |
| `rsg-consume:server:consumed` | server (local) | `src, itemName, category, data, meta` | `server/addiction.lua` |
| `rsg-drugs:server:npcRehab` | server | `netId` | `server/addiction.lua` |
| `rsg-drugs:server:checkIn` | server | `` | `server/addiction.lua` |
| `rsg-drugs:server:closed` | server | `` | `server/server.lua` |
| `rsg-prison:server:startSentence` | server | `` | `server/xp.lua` |

```lua
-- fired by rsg-consume on the server after a real consumption
AddEventHandler('rsg-consume:server:consumed', function(src, itemName, category, data, meta) end)
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
| `/corner` | locale('cmd_corner') (name from `Config.Corner.Command`) | `server/corner.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
