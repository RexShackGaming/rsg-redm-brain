# rsg-railroad — Developer Docs

Technical reference for server owners and developers. For a feature overview and install steps see [README.md](README.md). Version **3.3.0**.

## Contents
1. [Dependencies](#dependencies)
2. [File overview](#file-overview)
3. [Installation](#installation)
4. [Gameplay rules](#gameplay-rules)
5. [Configuration reference](#configuration-reference)
6. [Database schema](#database-schema)
7. [Server API (globals and `DB.*`)](#server-api)
8. [Events (client to server)](#events-client-to-server)
9. [Callbacks](#callbacks)
10. [Client API, NUI and locales](#client-api-nui-and-locales)
11. [Feature internals](#feature-internals)
12. [Code examples](#code-examples)
13. [Security model](#security-model)
14. [Troubleshooting](#troubleshooting)

---

## Dependencies
`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`. **No ox_lib.**
Optional: `rsg-telegram` (owner notices) and `rsg-weather` (weather speed caps). Both are detected at runtime; the features are skipped if the resource is not started.

| Feature | Implementation |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` in `shared_scripts`; `locale('key', ...)`; convar `rsg:locale` (> `ox:locale` > `en`). The NUI receives the full table from `GetLocaleTable()` |
| Server callbacks | `RegisterCallback(name, function(source, ...) return value end)` (`server/db.lua`) wraps `RSGCore.Functions.CreateCallback` and lets handlers `return` |
| Client callbacks | `RSGCore.Functions.AwaitCallback(name, nil, ...)` (default 10 s timeout, `nil` on timeout) |
| Notify | client `Notify(msg, type, duration)` -> `RSGCore.Functions.Notify`; server `NotifyPlayer(src, text, type, duration)` -> `RSGCore:Client:Notify` |
| Progress | `RSGCore.Functions.ProgressBar({...})` |
| Targeting | `exports['rsg-target']:addLocalEntity / removeLocalEntity` |
| Money | `Player.Functions.AddMoney / RemoveMoney('cash', amount, reason)` only (cash is an item when `EnableMoneyItems` is on) |

## File overview
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Load order. `server/sv_config.lua` loads before `server/db.lua` |
| `shared/config.lua` | All gameplay configuration (sent to clients: no secrets) |
| `server/sv_config.lua` | Server-only config: Discord webhook URLs and options |
| `server/db.lua` | `DB.*` queries, `RegisterCallback`, automatic table install (`DB.EnsureTables`) |
| `server/webhook.lua` | `Webhook.Send` / `Webhook.SendFields` |
| `server/telegram.lua` | `SendOwnerTelegram`, `CheckLowSupply` (rsg-telegram notices) |
| `server/storage.lua` | Per-deployment train stash (`TrainStorage.OnSpawn / OnPutAway`) |
| `server/main.lua` | Train buy/sell, deploy/park tracking (`ActiveTrains`), state sync, maintenance items, ticket revenue, helpers (`HasActiveTrain`, `ClearActiveTrain`, `IsAtStation`, `RequireStation`, `GetCompanyRole`, `NotifyPlayer`, `CompanyLabel`) |
| `server/companies.lua` | `AddCompanyXP` (membership, rank-up, rank reward) |
| `server/missions.lua` | Mission leg sessions, payout split (register / driver wage), railwayman milestone rewards |
| `server/company_ownership.lua` | Buy/sell/rename company, withdraw, wage percent, stats callbacks |
| `server/employees.lua` | Applications, approve/reject/fire |
| `server/supplies.lua` | Company supply store (add/take) |
| `server/upgrades.lua` | Company train upgrades |
| `server/ticketsserver.lua` | Ticket check when boarding as a passenger |
| `server/ambient.lua` | Ambient NPC train ownership and admin commands |
| `server/robbery.lua` | Robbery sessions and consequences |
| `client/utils.lua` | `Notify`, `ApplyNuiFocus`, `ShowInfoMenu`, `ConfirmDialog`, `GetLocaleTable`, helpers |
| `client/main.lua` | Station prompts/blips, `OpenStationHUD`, NUI callbacks |
| `client/train_spawn.lua` | Spawn/park/despawn, fuel/water/condition loops, `SetupTrainTarget` |
| `client/train_control.lua` | Engine, cruise, brake, `GetMaxTrainSpeed` |
| `client/train_hud.lua`, `train_switches.lua`, `train_ambient.lua` | HUD, junctions, ambient route trains |
| `client/missions.lua`, `cargo.lua` | Delivery and maintenance legs, barrel carry/load/unload |
| `client/passengers.lua`, `tickets.lua` | Boarding NPC passengers, ticket check |
| `client/preview.lua` | Train preview camera |
| `client/train_robbery.lua` | Outlaws, engine pressure, ambient robberies |
| `html/index.html`, `script.js`, `style.css` | NUI (station panel, train HUD, pressure HUD, dialogs) |
| `locales/*.json` | `en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru` (identical keys) |
| `install/rsg_railroad_full.sql` | All tables (`CREATE TABLE IF NOT EXISTS`); used by auto-install and manual import |
| `install/shared_items.lua` | Item snippets to paste into your shared items |
| `install/images/` | Item icons |

## Installation
1. Add `oilcan` and `trainticket` to your items (see `install/shared_items.lua`); copy `install/images/*` to your inventory images. Fuel/water items default to `resource_coal` and `fullbucket`.
2. Database: with `Config.AutoInstallDatabase = true` the tables are created on start and the `wage_percent` column is added to older databases. For a manual install set it to `false` and import `install/rsg_railroad_full.sql`.
3. `ensure rsg-railroad` after `rsg-core`, `rsg-inventory`, `rsg-target` and `oxmysql`.
4. Put your Discord webhook URLs in `server/sv_config.lua`.

## Gameplay rules
| Rule | Detail |
|---|---|
| Ranks | `Config.Ranks` 1 Brakeman (0 XP) to 5 Foreman (1000 XP). Rank and XP are per company and stored in `railroad_companies` |
| Company | Bought for `Config.CompanyPurchasePrice`, sold back for `CompanySellPercent`. The owner has a cash register (`cash_register`) |
| Employees | Apply at a station; the owner approves/rejects/fires. Approved drivers use company trains |
| Company trains | Defined in `Config.Trains` (`company`, `requiredRank`, `maxSpeed` ...). They have no database row (id 0) and use the company's upgrades |
| Personal trains | Bought with `buyTrain`, stored in `railroad_trains`, limited by `Config.MaxTrainsPerPlayer` |
| Delivery pay | `pay = floor((basePay + destination.pay) * cargo.weight)`; XP = `delivery.xpReward`. Maintenance pay = `maintenance.basePay` |
| Mission split | If `Config.DriverWages` is enabled: `wage = floor(pay * wage_percent / 100)` goes to the driver in cash, `pay - wage` to the register |
| Speed | `GetMaxTrainSpeed()`: train maxSpeed + upgrade bonus (native cap 30), times the condition multiplier (`0.25 + 0.75 * condition%`), times the weather multiplier, capped to `RobberySlowSpeed` during a robbery |
| Fuel / water / condition | Decrease on timers (`Config.Fuel / Water / Condition`); refilled with the configured items; a stopped boiler cannot run |
| Tickets | A passenger uses a `trainticket` (credited to the register at `Config.TicketPrice`) or pays `Config.MarkupPrice` in cash. Owners ride free |
| Passenger revenue | Stopping at a station with NPC passengers pays `passengers * PassengerSystem.TicketPrice`; `CompanyShare` goes to the register, the rest to the driver |

## Configuration reference
Gameplay options are in `shared/config.lua`. Only the keys most often changed are listed; every block is commented in the file.

| Key | Default | Description |
|---|---|---|
| `Config.AutoInstallDatabase` | `true` | Create/verify tables on start |
| `Config.MaxTrainsPerPlayer` | `5` | Personal train cap |
| `Config.ServerInteractRadius` | `25.0` | Server-side station distance for menu actions |
| `Config.TrainDespawnDist` | `250` | Auto-despawn distance from the player |
| `Config.TicketItem / TicketPrice / MarkupPrice` | `trainticket / 20 / 25` | Ticket economics |
| `Config.CompanyPurchasePrice / CompanySellPercent` | `50000 / 0.5` | Company market |
| `Config.SupplyItems` | coal, bucket, oil | Items the company store accepts |
| `Config.Fuel / Water / Condition` | see file | Item, refill amount, decrease interval/amount |
| `Config.Ranks` | 5 ranks | `label`, `xpRequired`, `payMultiplier` |
| `Config.Companies` | 4 companies | `label`, `shortLabel`, `blipColor`, `description` |
| `Config.Trains` | list | `model, label, company, cost, sellPrice, maxFuel, maxWater, maxCondition, maxSpeed, requiredRank, upgradeable, hasPassengerCars` |
| `Config.Stations` | list | `id, label, company, coords, spawnCoords, passengerSpawn, hasWaterTower, waterTowerCoords, hasMaintenanceDepot, depotCoords` |
| `Config.Upgrades` | speed/fuel/water/durability tiers | `label, cost, itemCost = { item, amount }, bonus` |
| `Config.Missions` | see file | `MinLegSeconds`, `delivery` (basePay, xpReward, jobLegs, cargoTypes), `maintenance` (basePay, xpReward, requiredRank, locations) |
| `Config.DeliveryDestinations` | list | `coords, label, pay, isWest, radius` |
| `Config.CargoDelivery` | see file | Barrel prop, platform positions, carry offsets (several values still marked PLACEHOLDER in the file) |
| `Config.TrainStorage` | see file | Slots/weight per train model, wipe-on-put-away warnings |
| `Config.PassengerSystem` | see file | Boarding counts, ticket price/XP, `CompanyShare` |
| `Config.RailwaymanRewards` | list | One-time milestones: `id, label, condition (trains_owned / total_miles / missions_completed), threshold, cashReward, xpReward` |
| `Config.CompanyRankRewards` | by rank | Cash on rank-up |
| `Config.DriverWages` | see below | Wage split |
| `Config.Telegram` | see below | Owner notices |
| `Config.WeatherSpeedCaps` | see below | Weather multipliers |
| `Config.TrainRobbery` | see below | Robbery tuning |
| `Config.AllowPushToTalkWhileOpen / PushToTalkControls` | `true / { 0x4BC9DABB }` | Push-to-talk while a NUI has focus |

```lua
Config.DriverWages = {
    Enabled = true, DefaultPercent = 0, MaxPercent = 60, OwnerEarnsWage = false,
}
Config.Telegram = {
    Enabled = true, LowSupplyThreshold = 5, LowSupplyCooldown = 3600,
}
Config.WeatherSpeedCaps = {
    Enabled = true,
    Multipliers = { shower = 0.9, rain = 0.85, thunderstorm = 0.7, hurricane = 0.5,
                    fog = 0.8, snow = 0.8, blizzard = 0.55, whiteout = 0.5, sandstorm = 0.6 },
}
```

`Config.TrainRobbery` keys: `Enabled`, `AmbientEnabled`, `AmbientCheckInterval`, `AmbientChance`, `AmbientFollowMs`, `AmbientMaxPlayerDist`, `PlayerChance`, `SafeZoneRadius`, `ManualStopRobRadius`, `TrainStopSpeed`, `RobberySlowSpeed`, `BoardTrain`, `BoardDistance`, `BoardSideOffset`, `EscapeTimeMs`, `InitialMessageDelay`, `SpawnAheadDistance`, `SpawnMultiplier`, `OutlawCount {min,max}`, `OutlawAccuracy`, `OutlawModels`, `HorseModels`, `OutlawWeapons`, `PressureDecayInterval`, `PressureDecayPerOutlaw`, `PressureAttackRadius`, `PressureRecoveryInterval`, `PressureRecoveryAmount`, `PressureRepairAmount`, `PressureRepairTime`, `RobberyTakePercent`, `RobberyTakeMin`, `RobberyTakeMax`, `CompanyCooldown`, `StartCooldown`, `MinSeconds`.

`Config.TrackSwitches` and `Config.TrackModels` are data only and not read by the scripts.

Server-only (`server/sv_config.lua`):
```lua
Config.Webhooks = {
    Enabled = true, BotName = 'RSG Railroad', BotAvatar = '',
    URLs = { economy = '', robbery = '', employees = '', admin = '' },
    Colors = { success = 3066993, error = 15158332, info = 3447003, warn = 15105570 },
    LogMissionCompletions = false,
}
```

## Database schema
All tables are in `install/rsg_railroad_full.sql`.

| Table | Purpose | Key columns |
|---|---|---|
| `railroad_trains` | Personal trains | `citizenid, company_id, train_model, label, fuel, water, condition, upgrade_speed/fuel_cap/water_cap/durability, total_miles, is_parked, parked_station, parked_direction` |
| `railroad_companies` | Per-player membership per company | `citizenid, company_id, rank, xp, missions_completed, total_earnings`; unique `(citizenid, company_id)` |
| `railroad_rewards` | Claimed milestone rewards | unique `(citizenid, reward_id)` (claim uses `INSERT IGNORE`) |
| `railroad_companies_owned` | Owned companies | `company_id` (unique), `owner_citizenid, owner_name, company_name, cash_register, wage_percent, purchased_at` |
| `railroad_employees` | Applications and staff | `company_id, citizenid, firstname, lastname, status (pending / approved / rejected), xp, rank, missions_completed, total_earnings`; unique `(company_id, citizenid)` |
| `railroad_company_upgrades` | Company upgrades per train model | `company_id, train_model, upgrade_speed/fuel_cap/water_cap/durability`; unique `(company_id, train_model)` |
| `railroad_company_supplies` | Company store stock | `company_id, item_name, quantity`; unique `(company_id, item_name)` |

`wage_percent` is added automatically to existing installs by `DB.EnsureTables()` (checked through `INFORMATION_SCHEMA`, never destructive). Train storage uses rsg-inventory stashes, not these tables.

## Server API
This resource registers **no exports**. Its server functions are globals shared between its own server files; they are not callable from other resources. To integrate from another resource, use the callbacks and the database (see examples).

### Helpers
| Function | Returns / does |
|---|---|
| `RegisterCallback(name, handler)` | Registers an rsg-core callback; the handler's return value is sent to the client |
| `NotifyPlayer(src, text, type, duration)` | rsg-core notification to a player |
| `CompanyLabel(companyId)` | Display label of a company |
| `GetCompanyRole(companyId, citizenid)` | `'owner' \| 'driver' \| nil`, ownership row, employee row |
| `HasActiveTrain(src)` | `true` when the server tracks a deployed train for the player |
| `ClearActiveTrain(src)` | Forgets the train, wipes its stash, drops mission and robbery sessions |
| `GetPlayerCoordsServer(src)` | Server-side ped coordinates (OneSync) |
| `GetNearbyStation(src, radius)` | Closest `Config.Stations` entry within `radius` |
| `IsAtStation(src, companyId, radius?)` / `RequireStation(src, companyId)` | Distance check (default `Config.ServerInteractRadius`); `RequireStation` also notifies |
| `AddCompanyXP(src, citizenid, companyId, xp)` | Adds XP, handles rank-up and rank reward |
| `CheckRailwaymanRewards(src, citizenid, companyId)` | Pays any newly met milestone once |
| `SendOwnerTelegram(companyId, subject, message)` | rsg-telegram message to the company owner (no-op if disabled/not running) |
| `CheckLowSupply(companyId, item, label)` | Telegram the owner when stock <= `LowSupplyThreshold` (rate limited) |
| `Webhook.SendFields(category, title, { {name, value}, ... }, type, description?)` | Discord embed; categories `economy / robbery / employees / admin`; types `success / error / info / warn` |
| `ClearMissionSession(src)` / `ClearRobberySession(src)` | Drop in-flight sessions |

### `DB.*` (server/db.lua, oxmysql, parameterised)
Companies: `GetCompanyOwnership, GetAllOwnedCompanies, GetOwnedCompaniesByCitizen, GetOwnedCompanyCount, PurchaseCompany, SellCompany, SetCompanyName, SetWagePercent, GetCashRegister, AddToCashRegister, WithdrawFromCashRegister` (atomic: only succeeds when the register holds enough, returns affected rows).
Members: `GetCompanyMembership, EnsureCompanyMembership, JoinCompany, AddCompanyXP, SetCompanyRank, IncrementMissions, AddEarnings`.
Employees: `ApplyAsDriver, ApproveEmployee, RejectEmployee, FireEmployee, GetEmployeeByIds, GetEmployeeById, GetEmployeesByCompany, GetPendingApplications, GetPlayerEmployment, IncrementEmployeeMissions, AddEmployeeEarnings, DeleteEmployeesByCompany`.
Trains: `InsertTrain, GetOwnedTrains, GetTrainById, GetCompanyTrains, CountTrains, DeleteTrain, ParkTrain, UnparkTrain, UpdateTrainState/Fuel/Water/Condition, AddMiles`.
Upgrades: `GetCompanyUpgrades, GetCompanyTrainUpgrade, UpsertCompanyUpgrade, DeleteUpgradesByCompany`.
Supplies: `GetCompanySupplies, GetSupplyItem, AddSupplyItem, TakeSupplyItem` (atomic), `DeleteSuppliesByCompany`.
Rewards: `HasClaimedReward, ClaimReward` (atomic, `INSERT IGNORE`).
Setup: `EnsureTables`.

## Events (client to server)
Every handler resolves `source`, re-checks the player and validates all arguments. Arguments are untrusted.

| Event | Arguments | Server checks |
|---|---|---|
| `rsg-railroad:buyTrain` | `trainIndex` | At a station of the train's company, rank, personal limit, cash |
| `rsg-railroad:sellTrain` | `trainId` | At a station, ownership, parked, atomic delete |
| `rsg-railroad:setTrainSpawned` | `spawned, trainId, model` | At a station, known model, ownership for personal trains, one train per player |
| `rsg-railroad:parkTrain` | `trainId, _, fuel, water, condition` | Only the player's deployed personal train; station derived from server position |
| `rsg-railroad:updateTrainState(trainId, fuel, water, condition)`, `updateFuel / updateWater / updateCondition(trainId, value)` | ids and values | Deployed personal train only, clamped to the train's maxima |
| `rsg-railroad:addMiles` | `trainId, miles` | Throttled (min 5 s), capped by elapsed time and max speed |
| `rsg-railroad:useMaintenanceItem` | `type, trainId` (trainId ignored, the cached deployment is used) | Item chosen by the server; removed through rsg-inventory |
| `rsg-railroad:missionLegStarted` | `type, label` | Active train; stores a leg session |
| `rsg-railroad:completeMission` | `type, destination, cargo, companyId` | Company role, session, `MinLegSeconds`, server position at the destination, 15 s cooldown; pay from config |
| `rsg-railroad:ticketRevenue` | `companyId, passengers` | Role, active train, real station, 30 s cooldown, new station each time, count capped |
| `rsg-railroad:buyCompany / sellCompany(companyId)`, `renameCompany(companyId, newName)`, `withdrawFunds(companyId, amount)` | `companyId, ...` | At the company's station, owner checks, atomic SQL; rename 3-50 chars sanitised |
| `rsg-railroad:setWagePercent` | `companyId, percent` | Owner, at the station, integer within `0..MaxPercent` |
| `rsg-railroad:applyAsDriver / approveDriver / rejectDriver / fireDriver` | `companyId, employeeId?` | At the station; owner only except apply |
| `rsg-railroad:addSupply / takeSupply` | `companyId, item, qty` | At the station, role, item whitelist, qty cap, atomic stock |
| `rsg-railroad:purchaseUpgrade` | `companyId, trainModel, upgradeType` | At the station; owner or approved driver rank 3+ |
| `rsg-railroad:openTrainStorage` | none | Active train with a stash |
| `rsg-railroad:robberyStarted` | `companyId` | Robbery enabled, company role, active train, outside `SafeZoneRadius` of all stations, `StartCooldown` |
| `rsg-railroad:robberyOccurred / robberyDefeated` | `companyId` | Needs an open robbery session older than `MinSeconds`; company cooldown; take clamped by config |
| `rsg-railroad:ambientDespawned` | none | Only the ambient owner |

Server to client: `rsg-railroad:refreshStationData(companyId)`, `rsg-railroad:client:trainpos`, `rsg-railroad:client:setjunction(args)`.

Admin commands (`admin` permission): `/trainpos`, `/setjunction <trackName> <junctionIndex> <0|1>`. Client debug command (only with `Config.Debug = true`): `/trainrobbery`.

## Callbacks
All are registered with `RegisterCallback` and called from the client with `RSGCore.Functions.AwaitCallback`.

| Callback | Arguments | Returns |
|---|---|---|
| `rsg-railroad:getCompanyOwnership` | `companyId` | Ownership row (includes `wage_percent`); `cash_register` and `owner_citizenid` only for the owner; `nil` if unowned |
| `rsg-railroad:getPlayerRole` | `companyId` | `'owner' \| 'driver' \| 'pending' \| 'visitor' \| 'unowned'` |
| `rsg-railroad:getMyEmployeeData` | `companyId` | Employee row with rank/xp from `railroad_companies` |
| `rsg-railroad:getMyCompanyMembership` | `companyId` | Membership row |
| `rsg-railroad:getMyEmployment` | none | Player's employments |
| `rsg-railroad:getEmployees`, `getPendingApplications` | `companyId` | Owner only, else `{}` |
| `rsg-railroad:getCompanyStats` | `companyId` | Owner only |
| `rsg-railroad:getAllCompanyStats` | none | Public leaderboard-style stats |
| `rsg-railroad:getCompanyTrains` | `companyId` | Company train list |
| `rsg-railroad:getCompanySupplies` | `companyId` | Role-gated supply stock |
| `rsg-railroad:getCompanyUpgrades`, `getTrainModelUpgrade` | `companyId[, model]` | Upgrade rows |
| `rsg-railroad:getOwnedTrains`, `getTrainById` | `[trainId]` | Caller's personal trains |
| `rsg-railroad:canSpawnTrain` | none | `true` when no train is deployed |
| `rsg-railroad:getTrainStorageState` | none | `{ active, stacks }` |
| `rsg-railroad:server:useTicket` | `companyId` | `'has_ticket' \| 'bought_ticket' \| 'no_ticket'` (10 s repeat cooldown) |
| `rsg-railroad:shouldSpawnAmbient` | none | `true` for the first client only (ambient ownership) |
| `rsg-railroad:getAmbientState` | none | `true` while no company is owned |

## Client API, NUI and locales
Client globals (shared between this resource's client files): `Notify`, `LoadModel`, `LoadTrainCars`, `GetDistanceBetween`, `DebugPrint`, `GetNearestStation`, `FindTrainConfig`, `GetLocaleTable`, `ApplyNuiFocus`, `ShowInfoMenu`, `ConfirmDialog`, train state (`ActiveTrain`, `ActiveTrainConfig`, `ActiveTrainData`, `EngineRunning`, `TrainFuel`, `TrainWater`, `TrainCondition`), controls (`ToggleEngine`, `EmergencyBrake`, `ToggleCruiseForward/Backward`, `GetMaxTrainSpeed`, `GetCurrentSpeed`), and robbery hooks (`IsEnginePressureDamaged`, `IsRobberySpeedCapActive`, `IsTrainUnderAttackOrRecovering`, `FixEnginePressure`, `TriggerTrainRobbery`).

- `ApplyNuiFocus(enable)`: the only place NUI focus is set. Uses `SetNuiFocusKeepInput` and a per-frame control whitelist so push-to-talk keeps working.
- `ShowInfoMenu(title, { { title, description }, ... })`: read-only NUI list.
- `ConfirmDialog({ header, content, labels = { confirm, cancel } })` -> `true/false`.

NUI messages (Lua -> JS): `openStation, closeStation, openTrainHUD, closeTrainHUD, updateHUD, openInfoMenu, openDialog, showPressureHUD, updatePressureHUD, hidePressureHUD`.
NUI callbacks (JS -> Lua): `closeStation, buyTrain, sellTrain, spawnTrain, parkTrain, despawnTrain, purchaseUpgrade, startMission, buyCompany, sellCompany, renameCompany, setWagePercent, withdrawFunds, applyAsDriver, approveDriver, rejectDriver, fireDriver, addSupply, takeSupply, buyCompanyTrain, previewTrain, closeInfoMenu, dialogResult`.
Every NUI callback only forwards to a server event that re-validates; the UI is not trusted.

Locales: `locales/en.json` is the master and every other language has the same keys with the same `%s/%d` placeholders. NUI texts use `t('key', 'fallback')` and are filled from `GetLocaleTable()`. Server notifications use `locale()` too, so the server language follows `rsg:locale`.

## Feature internals

### Missions and pay
`missionLegStarted` records `{ type, label, startedAt }`. `completeMission` requires the same type/label, at least `MinLegSeconds`, the server position within `radius + 60 m` of the destination (delivery) or `10 + 60 m` (maintenance), and clears the session after payout (one payout per leg). XP goes through `AddCompanyXP`, then `CheckRailwaymanRewards` pays each milestone once.

### Driver wages
`wage = floor(pay * pct / 100)` with `pct = min(wage_percent, Config.DriverWages.MaxPercent)`. Owners earn no wage unless `OwnerEarnsWage`. The wage is paid with `AddMoney('cash', wage, 'railroad-driver-wage')` and `pay - wage` goes to the register. The owner sets the percent in the station panel (`setWagePercent`).

### Telegram notices
`SendOwnerTelegram` calls `exports['rsg-telegram']:SendTelegram(ownerCitizenId, subject, message, { senderName = companyLabel })` inside `pcall`, only when `Config.Telegram.Enabled` and rsg-telegram is `started`. Triggers: a driver application, and a supply take that leaves stock at or below `LowSupplyThreshold` (one message per company+item per `LowSupplyCooldown`).

### Weather speed caps
`GetMaxTrainSpeed()` multiplies the speed by `Config.WeatherSpeedCaps.Multipliers[weather]`, where `weather` is the lowercase string from `exports['rsg-weather']:getWeather()` (client export). Unlisted weather is unchanged. The new value is used the next time the engine loop re-reads the max speed.

### Train robbery
1. Every 3 to 5 minutes the client rolls `20%` while the driver is in the seat, the engine is running, speed >= 5 and the train is further than `SafeZoneRadius` from all stations. `TriggerTrainRobbery(force)` can also be called by other client code.
2. The client sends `robberyStarted(companyId)`. The server checks role, active train, station safe zone and `StartCooldown`, then opens a one-shot session.
3. Outlaws spawn mounted beside the train, ride at it and shoot. Each living outlaw within `PressureAttackRadius` drains `PressureDecayPerOutlaw` engine pressure per tick. The train is slowed to `RobberySlowSpeed`.
4. Outcomes: all outlaws killed -> `robberyDefeated` (company XP, no cash); train stopped with an outlaw within `ManualStopRobRadius`, pressure at zero, or driver killed with an outlaw close -> `robberyOccurred` (register cut `RobberyTakePercent`, clamped to `RobberyTakeMin..Max`, atomic, then `CompanyCooldown`).
5. Afterwards the engine cannot start until pressure recovers or the player repairs it with the "Repair Engine Pressure" train target.
Ambient robberies are visual only and spawn for ambient trains within `AmbientMaxPlayerDist` of the player.

### Train storage
Each deployed train gets an rsg-inventory stash sized by `Config.TrainStorage.Models[model]`. The stash id is regenerated per deployment and cleared whenever the train leaves the world (park, despawn, yard, auto-despawn, death, disconnect, restart). Reverse Direction recreates the entity but keeps the load.

### Ambient train
Only one client at a time owns the ambient NPC train (`shouldSpawnAmbient`). It is released through `ambientDespawned` or when that player leaves.

## Code examples

### Read a company's state from another client script
```lua
local RSGCore = exports['rsg-core']:GetCoreObject()

local role = RSGCore.Functions.AwaitCallback('rsg-railroad:getPlayerRole', nil, 'heartlands_express')
if role == 'owner' then
    local o = RSGCore.Functions.AwaitCallback('rsg-railroad:getCompanyOwnership', nil, 'heartlands_express')
    print(('Register: $%s, wage share: %s%%'):format(o.cash_register, o.wage_percent))
end
```

### Read railroad data from another server resource (database)
```lua
-- Rank and XP of a player in a company (read only)
local row = MySQL.single.await(
    'SELECT `rank`, xp FROM railroad_companies WHERE citizenid = ? AND company_id = ?',
    { citizenid, 'heartlands_express' })
```
Write through this resource's events/callbacks instead of editing tables directly, so the validation and webhooks run.

### Add a new company train
```lua
-- shared/config.lua -> Config.Trains
{ model = 'engine_config', label = 'Valentine Switcher', company = 'heartlands_express',
  cost = 300, sellPrice = 180, maxFuel = 110, maxWater = 110, maxCondition = 100,
  maxSpeed = 20, requiredRank = 2, upgradeable = true, hasPassengerCars = false },
```
Add a matching entry in `Config.TrainStorage.Models` if it should have its own capacity.

### Add a station
```lua
-- shared/config.lua -> Config.Stations
{
    id = 'my_station', label = 'My Station', company = 'lemoyne_central',
    coords = vector3(0.0, 0.0, 0.0), spawnCoords = vector3(0.0, 0.0, 0.0),
    passengerSpawn = vector3(0.0, 0.0, 0.0),
    hasWaterTower = false, hasMaintenanceDepot = false,
},
```
For delivery cargo also add `Config.CargoDelivery.PlatformOverrides.my_station = vector4(x, y, z, heading)`.

### Add a delivery destination or a supply item
```lua
-- Config.DeliveryDestinations
{ coords = vector3(1521.84, 428.44, 90.68), label = 'Emerald Siding', pay = 18, isWest = false, radius = 25 },

-- Config.SupplyItems (the item must exist in rsg-inventory)
{ item = 'resource_iron_bar', label = 'Iron Bar', icon = 'wrench' },
```

### Change a wage or weather rule
```lua
Config.DriverWages.MaxPercent = 40
Config.WeatherSpeedCaps.Multipliers.rain = 0.7
Config.WeatherSpeedCaps.Enabled = false -- no weather effect
```

### Send the owner a custom telegram from this resource
```lua
-- inside any server file of rsg-railroad
SendOwnerTelegram(companyId, locale('tg_subject_lowstock'), locale('tg_body_lowstock', 'Coal', 3))
```

### Add a Discord log line
```lua
Webhook.SendFields('economy', 'Custom Event', {
    { 'Player', GetPlayerFullName(Player) .. ' (' .. Player.PlayerData.citizenid .. ')' },
    { 'Company', CompanyLabel(companyId) },
}, 'info')
```

### Add a locale key (all 11 languages)
Add the same key to every file in `locales/`, keep placeholders in order, then use it:
```lua
NotifyPlayer(src, locale('my_new_key', amount), 'success')   -- server
Notify(locale('my_new_key', amount), 'success')              -- client
```
```js
t('my_new_key', 'Fallback text')   // NUI (script.js)
```

### Write a safe server event (pattern used throughout)
```lua
RegisterNetEvent('rsg-railroad:myAction', function(companyId, qty)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if not GetCompanyRole(companyId, Player.PlayerData.citizenid) then return end
    if not RequireStation(src, companyId) then return end   -- server-side distance
    qty = math.floor(tonumber(qty) or 0)
    if qty < 1 or qty > 50 then return end
    -- ... atomic SQL, then reward
end)
```

## Security model
- The client never decides money, items, prices or pay: everything is computed from config on the server.
- Position checks use the server-side ped position (OneSync), never client-sent coordinates.
- Fuel, water and condition of **personal** trains are reported by the client and clamped; company trains (id 0) have no database row and are client-authoritative by design.
- Money-moving SQL is atomic (`WithdrawFromCashRegister`, `TakeSupplyItem`, `ClaimReward`, train delete).
- `getCompanyOwnership` hides `cash_register` and `owner_citizenid` from everyone except the owner; staff and application callbacks are role-gated.
- Mission payouts need a server-seen leg, a minimum travel time and the server position at the destination. Robbery payouts need a server-opened session.
- Webhook URLs live in `server/sv_config.lua`, which is never sent to clients.
- Known limits: ticket revenue and fuel/water/condition for company trains rely on client reports within the checks above; per-driver supply withdrawal limits do not exist.

## Troubleshooting
| Problem | Check |
|---|---|
| "You need to be at a company station" | Server position is further than `Config.ServerInteractRadius` from a station of that company |
| Mission finished but nothing paid | Leg took less than `Config.Missions.MinLegSeconds`, or no active train / company role |
| Train cannot be deployed | Not at a station, or the server still thinks a train is out (park or send to yard first) |
| Webhooks silent | URLs must be set in `server/sv_config.lua` (not `shared/config.lua`) |
| Tables missing / SQL errors | `Config.AutoInstallDatabase = true` and the DB user can `CREATE TABLE`/`ALTER TABLE`; or import `install/rsg_railroad_full.sql` |
| Driver wage always 0 | Owner has not set a percent (`DefaultPercent` is 0), the player is the owner, or `Config.DriverWages.Enabled = false` |
| No telegram to owner | `rsg-telegram` not started, `Config.Telegram.Enabled = false`, or the owner's citizenid has no character |
| Weather does not slow the train | `rsg-weather` not started, or the weather name is not in `Multipliers` (names are lowercase) |
| No robberies | `Config.TrainRobbery.Enabled`, driving far from all stations (`SafeZoneRadius`), engine running, speed >= 5, and the 3 to 5 minute roll; use `/trainrobbery` with `Config.Debug = true` to test |
| Outlaws do not spawn | Check the F8 console for model load warnings; verify `OutlawModels` / `HorseModels` exist on your build |
| Barrels float or clip on the flatbed | Tune `Config.CargoDelivery.TrainAttachOffsets` / `PlatformOverrides` in game |
| NUI will not release focus | Close with Escape/back; `ApplyNuiFocus(false)` runs on close and on resource stop |

Support: https://rexshack.tebex.store

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-railroad 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`

### Database

Tables: `railroad_trains`, `railroad_companies`, `railroad_rewards`, `railroad_companies_owned`, `railroad_employees`, `railroad_company_upgrades`, `railroad_company_supplies`.

For a manual install set `Config.AutoDatabase = false` and import `install/rsg_railroad_full.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AllowPushToTalkWhileOpen` | `true` | While the NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.Debug` | `false` |  |
| `Config.AutoInstallDatabase` | `true` | automatically creates/verifies all required MySQL tables on resource start (from install/rsg_railroad_full.sql |
| `Config.MaxTrainsPerPlayer` | `5` | max trains a single player can personally own |
| `Config.ServerInteractRadius` | `25.0` | server-side: how close (m) to a company station a player must be for buy/sell/manage actions |
| `Config.TrainDespawnDist` | `250` | despawn if player is far from their train |
| `Config.StationInteractRadius` | `3.0` | how close to station marker to interact |
| `Config.TicketItem` | `'trainticket'` |  |
| `Config.TicketPrice` | `20.00` |  |
| `Config.MarkupPrice` | `25.00` |  |
| `Config.PassengerSystem` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.MaxBoardPerStop` | `10` |  |
| `Config.MinBoardPerStop` | `1` |  |
| `Config.SearchRadius` | `120.0` |  |
| `Config.TicketXP` | `5` |  |
| `Config.DisembarkChance` | `50` |  |
| `Config.MinBoardedToKeep` | `1` |  |
| `Config.BoardingWindowMs` | `38000` |  |
| `Config.BoardWalkSpeed` | `5.0` |  |
| `Config.BoardDistance` | `5.0` |  |
| `Config.StationStopRadius` | `135.0` |  |
| `Config.TrainStopSpeed` | `1.5` |  |
| `Config.CompanyShare` | `0.50` |  |
| `Config.Ranks` | `table` |  |
| `Config.CompanyPurchasePrice` | `50000` |  |
| `Config.CompanySellPercent` | `0.50` |  |
| `Config.SupplyItems` | `table` |  |
| `Config.Fuel` | `table` |  |
| `Config.Water` | `table` |  |
| `Config.Condition` | `table` |  |
| `Config.Companies` | `table` |  |
| `Config.Upgrades` | `table` |  |
| `Config.Trains` | `table` |  |
| `Config.Stations` | `table` |  |
| `Config.TrackSwitches` | `table` |  |
| `Config.TrainSetup` | `table` |  |
| `Config.RouteOneTrainSwitches` | `table` |  |
| `Config.RouteOneTrainStops` | `table` |  |
| `Config.RouteThreeTrainSwitches` | `table` |  |
| `Config.RouteThreeTrainStops` | `table` |  |
| `Config.TrackModels` | `table` |  |
| `Config.WeatherSpeedCaps` | `table` |  |
| `Config.Multipliers` | `table` |  |
| `Config.Telegram` | `table` |  |
| `Config.LowSupplyThreshold` | `5` |  |
| `Config.LowSupplyCooldown` | `3600` |  |
| `Config.DriverWages` | `table` |  |
| `Config.DefaultPercent` | `0` |  |
| `Config.MaxPercent` | `60` |  |
| `Config.OwnerEarnsWage` | `false` |  |
| `Config.Missions` | `table` |  |
| `Config.MinLegSeconds` | `20` |  |
| `Config.DeliveryDestinations` | `table` |  |
| `Config.CargoDelivery` | `table` |  |
| `Config.PropModel` | `'p_barrel010x'` |  |
| `Config.MaxSimultaneous` | `3` |  |
| `Config.RequiredTrainModel` | `'appleseed_config'` |  |
| `Config.FlatbedCarModel` | `'privateflatcar01x'` |  |
| `Config.PlatformOverrides` | `table` | needed (e.g. move it away from doorways/props, face it properly, etc.). |
| `Config.PlatformFallbackCoords` | `vector4(-164.49, 636.65, 114.03, 111.05)` | Used only if a mission is somehow started without a station reference. |
| `Config.PlatformBarrelOffsets` | `table` | barrels don't spawn stacked on top of each other. |
| `Config.TrainAttachOffsets` | `table` | are clipped into the flatbed deck or float above it. |
| `Config.CarryOffset` | `{ x = 0.0, y = 0.7, z = -0.2 }` | Proven values from mack-oilcompany's Config.CarryOffsets.barrel (CP_BeltFront attach point). |
| `Config.CarryAnim` | `{ dict = 'mech_carry_box', name = 'walk_heavy' }` | Proven barrel carry animation from mack-oilcompany's AttachBarrelToPlayer. |
| `Config.CarryMoveRate` | `0.7` |  |
| `Config.PickupRequiresStopped` | `true` |  |
| `Config.MaxTrainSpeedToPickup` | `1.5` |  |
| `Config.DropRadius` | `4.0` |  |
| `Config.AbandonDistance` | `100.0` |  |
| `Config.MinMoveDistance` | `15.0` | must move at least this far from that spot before "Unload Cargo" appears again. |
| `Config.TrainStorage` | `table` |  |
| `Config.DefaultSlots` | `20` | Used for any train model not listed in Models below. |
| `Config.DefaultMaxWeight` | `150000` |  |
| `Config.Models` | `table` | Per-model capacity: bigger engines haul more. |
| `Config.WarnOnFirstOpen` | `true` | Warn the player once per deployment, the first time they open storage. |
| `Config.ConfirmOnPutAway` | `true` | that would destroy a non-empty stash. Never blocks the action. |
| `Config.DistanceWarnPercent` | `0.7` | carrying cargo, since the auto-despawn is the most common cause of loss. |
| `Config.DistanceWarnInterval` | `15000` |  |
| `Config.TrainPreview` | `table` |  |
| `Config.ShowFullConsist` | `true` | false = show a single car only, chosen by CarIndex below |
| `Config.CarIndex` | `0` | Used only when ShowFullConsist = false. 0 is the locomotive. |
| `Config.MaxCars` | `12` | can't spawn dozens of vehicles at once. |
| `Config.CarGap` | `0.4` | Coupling gap between cars, in metres. |
| `Config.HeightOffset` | `90.0` | How far above the player the preview is staged. |
| `Config.OrbitRadiusMult` | `0.60` | reads much more impressive than framing the whole thing small and distant. |
| `Config.MinOrbitRadius` | `15.0` |  |
| `Config.CameraHeightMult` | `0.20` |  |
| `Config.MinCameraHeight` | `4.5` |  |
| `Config.RotateSpeed` | `0.25` | Degrees per frame the camera orbits. 0 gives a static side-on view. |
| `Config.ExitControl` | `0xCEFD9220` | than bound to guessed A/D control hashes. |
| `Config.LoadTimeout` | `5000` | Safety cap on waiting for each model to stream in (ms). |
| `Config.RailwaymanRewards` | `table` |  |
| `Config.CompanyRankRewards` | `table` |  |
| `Config.Blips` | `table` |  |
| `Config.TrainRobbery` | `table` |  |
| `Config.AmbientEnabled` | `true` |  |
| `Config.AmbientCheckInterval` | `300000` |  |
| `Config.AmbientChance` | `25` |  |
| `Config.AmbientFollowMs` | `45000` |  |
| `Config.PlayerChance` | `20` |  |
| `Config.SafeZoneRadius` | `500.0` |  |
| `Config.ManualStopRobRadius` | `15.0` |  |
| `Config.RobberySlowSpeed` | `8.0` |  |
| `Config.BoardTrain` | `true` |  |
| `Config.BoardSideOffset` | `1.2` |  |
| `Config.EscapeTimeMs` | `15000` |  |
| `Config.InitialMessageDelay` | `4000` |  |
| `Config.SpawnAheadDistance` | `80.0` |  |
| `Config.SpawnMultiplier` | `3.0` |  |
| `Config.OutlawCount` | `{ min = 2, max = 4 }` |  |
| `Config.OutlawAccuracy` | `35` |  |
| `Config.OutlawModels` | `{ 'g_m_m_unibanditos_01', 'g_m_m_uniduster_01', 'g_m_m_unicriminals_01` | Model names checked against rdr3_discoveries peds_list.lua / weapons list: |
| `Config.HorseModels` | `{ 'a_c_horse_kentuckysaddle_black' }` |  |
| `Config.OutlawWeapons` | `{ 'WEAPON_REPEATER_WINCHESTER', 'WEAPON_REVOLVER_CATTLEMAN' }` |  |
| `Config.PressureDecayInterval` | `4000` |  |
| `Config.PressureDecayPerOutlaw` | `4` |  |
| `Config.PressureAttackRadius` | `40.0` |  |
| `Config.PressureRecoveryInterval` | `2000` |  |
| ... | | 10 more options in the config files |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-railroad:shouldSpawnAmbient` | server | `source` | `server/ambient.lua` |
| `rsg-railroad:getCompanyOwnership` | server | `source, companyId` | `server/company_ownership.lua` |
| `rsg-railroad:getPlayerRole` | server | `source, companyId` | `server/company_ownership.lua` |
| `rsg-railroad:getMyEmployeeData` | server | `source, companyId` | `server/company_ownership.lua` |
| `rsg-railroad:getCompanyStats` | server | `source, companyId` | `server/company_ownership.lua` |
| `rsg-railroad:getAllCompanyStats` | server | `source` | `server/company_ownership.lua` |
| `rsg-railroad:getCompanyTrains` | server | `source, companyId` | `server/company_ownership.lua` |
| `rsg-railroad:getEmployees` | server | `source, companyId` | `server/employees.lua` |
| `rsg-railroad:getPendingApplications` | server | `source, companyId` | `server/employees.lua` |
| `rsg-railroad:getMyEmployment` | server | `source` | `server/employees.lua` |
| `rsg-railroad:getOwnedTrains` | server | `source` | `server/main.lua` |
| `rsg-railroad:getTrainById` | server | `source, trainId` | `server/main.lua` |
| `rsg-railroad:canSpawnTrain` | server | `source` | `server/main.lua` |
| `rsg-railroad:getAmbientState` | server | `` | `server/main.lua` |
| `rsg-railroad:getMyCompanyMembership` | server | `source, companyId` | `server/main.lua` |
| `rsg-railroad:getTrainStorageState` | server | `source` | `server/storage.lua` |
| `rsg-railroad:getCompanySupplies` | server | `source, companyId` | `server/supplies.lua` |
| `rsg-railroad:server:useTicket` | server | `source, companyId` | `server/ticketsserver.lua` |
| `rsg-railroad:getCompanyUpgrades` | server | `source, companyId` | `server/upgrades.lua` |
| `rsg-railroad:getTrainModelUpgrade` | server | `source, companyId, trainModel` | `server/upgrades.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-railroad:shouldSpawnAmbient', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-railroad:refreshStationData` | client | `companyId` | `client/main.lua` |
| `rsg-railroad:setAmbientState` | client | `active` | `client/train_ambient.lua` |
| `rsg-railroad:client:trainpos` | client | `` | `client/train_ambient.lua` |
| `rsg-railroad:client:setjunction` | client | `args` | `client/train_ambient.lua` |
| `rsg-railroad:maintenanceResult` | client | `mType, success` | `client/train_spawn.lua` |
| `rsg-railroad:ambientDespawned` | server | `` | `server/ambient.lua` |
| `rsg-railroad:buyCompany` | server | `companyId` | `server/company_ownership.lua` |
| `rsg-railroad:sellCompany` | server | `companyId` | `server/company_ownership.lua` |
| `rsg-railroad:renameCompany` | server | `companyId, newName` | `server/company_ownership.lua` |
| `rsg-railroad:setWagePercent` | server | `companyId, pct` | `server/company_ownership.lua` |
| `rsg-railroad:withdrawFunds` | server | `companyId, amount` | `server/company_ownership.lua` |
| `rsg-railroad:applyAsDriver` | server | `companyId` | `server/employees.lua` |
| `rsg-railroad:approveDriver` | server | `companyId, employeeId` | `server/employees.lua` |
| `rsg-railroad:rejectDriver` | server | `companyId, employeeId` | `server/employees.lua` |
| `rsg-railroad:fireDriver` | server | `companyId, employeeId` | `server/employees.lua` |
| `rsg-railroad:buyTrain` | server | `trainIndex` | `server/main.lua` |
| `rsg-railroad:sellTrain` | server | `trainId` | `server/main.lua` |
| `rsg-railroad:ticketRevenue` | server | `companyId, passengerCount` | `server/main.lua` |
| `rsg-railroad:setTrainSpawned` | server | `spawned, trainId, model` | `server/main.lua` |
| `rsg-railroad:parkTrain` | server | `trainId, _, fuel, water, condition` | `server/main.lua` |
| `rsg-railroad:updateTrainState` | server | `trainId, fuel, water, condition` | `server/main.lua` |
| `rsg-railroad:updateFuel` | server | `trainId, fuel` | `server/main.lua` |
| `rsg-railroad:updateWater` | server | `trainId, water` | `server/main.lua` |
| `rsg-railroad:updateCondition` | server | `trainId, condition` | `server/main.lua` |
| `rsg-railroad:addMiles` | server | `trainId, miles` | `server/main.lua` |
| `rsg-railroad:useMaintenanceItem` | server | `mType, trainId` | `server/main.lua` |
| `rsg-railroad:missionLegStarted` | server | `missionType, label` | `server/missions.lua` |
| `rsg-railroad:completeMission` | server | `missionType, destination, cargo, companyId` | `server/missions.lua` |
| `rsg-railroad:robberyStarted` | server | `companyId` | `server/robbery.lua` |
| `rsg-railroad:robberyOccurred` | server | `companyId` | `server/robbery.lua` |
| `rsg-railroad:robberyDefeated` | server | `companyId` | `server/robbery.lua` |
| `rsg-railroad:openTrainStorage` | server | `` | `server/storage.lua` |
| `rsg-railroad:addSupply` | server | `companyId, itemName, quantity` | `server/supplies.lua` |
| `rsg-railroad:takeSupply` | server | `companyId, itemName, quantity` | `server/supplies.lua` |
| `rsg-railroad:purchaseUpgrade` | server | `companyId, trainModel, upgradeType` | `server/upgrades.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-railroad:ambientDespawned')
-- from a server script
TriggerClientEvent('rsg-railroad:refreshStationData', source, companyId)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/trainrobbery` |  | `client/train_robbery.lua` |
| `/trainpos` | Show train locations (admin) | `server/ambient.lua` |
| `/setjunction` | Set a train track junction (admin) | `server/ambient.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
