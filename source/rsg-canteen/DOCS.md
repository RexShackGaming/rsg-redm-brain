# rsg-canteen – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Setup
4. Configuration
5. Events, callbacks, exports and commands
6. Integrations
7. Security
8. Database
9. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Canteen tiers, timings, pumps, river fill, dirty water, purify, share, weather, pump verification, fee, animations, prop |
| `client/client.lua` | Targets (pump, fire, player), river fill prompt, animations and prop, sickness effect, admin pump registration |
| `server/server.lua` | Useable items, canteen metadata, all validation, thirst, pump registry, commands, exports |
| `server/versionchecker.lua` | GitHub version check |
| `install.sql` | `rsg_canteen_pumps` table (only for a manual install) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- **Tiers:** every item in `Config.Canteens` is a canteen with its own `maxUses` and `thirst`. Uses live in the item metadata (`info.uses`); `info.quality` mirrors the fill level so the inventory shows a bar; `info.dirty` marks unsafe water.
- **Fill:** target a pump (`PumpModels`) or hold `G` in shallow water. Filling tops up your emptiest canteen. Pump water is clean; river/lake water is dirty (`DirtyWater.Enabled`).
- **Drink:** using the item asks the server, which checks the canteen, uses and thirst, then the client plays the animation. After the minimum time the server consumes one use and writes thirst through `rsg-hud`. Weather and dirty water scale the amount. Dirty water can make the player sick (health loss, never below `MinHealth`).
- **Purify:** target a fire prop (`Purify.Models`) with a dirty canteen; after `Purify.Time` every dirty canteen becomes clean.
- **Give a drink:** target another player within `Share.Distance`; one use is taken from your best canteen (clean first, then fullest) and the other player's thirst rises. A dirty canteen can make them sick.
- **Weather:** `WeatherThirst.Multipliers` (rsg-weather type -> multiplier) scales thirst per drink.
- **Blocked states:** drinking, filling, purifying and sharing are refused while mounted, swimming, in a vehicle or dead.

## 3. Setup
Add the items to `rsg-core/shared/items.lua`. They **must** be `unique = true`:
```lua
canteen       = { name = 'canteen',       label = 'Canteen',       weight = 100, type = 'item', image = 'canteen.png',       unique = true, useable = true, shouldClose = true, description = 'Water Canteen',       category = 'tools' },
canteen_large = { name = 'canteen_large', label = 'Large Canteen', weight = 150, type = 'item', image = 'canteen_large.png', unique = true, useable = true, shouldClose = true, description = 'Large Water Canteen', category = 'tools' },
```
Add the images to `rsg-inventory/html/images/` and `ensure rsg-canteen` after its dependencies. A tier whose item is missing from shared items is skipped with a console warning.

### Pump verification (optional)
1. Stand next to each map pump and run `/canteenaddpump` (needs `Config.PumpVerify.Permission`). The nearest pump model from `PumpModels` within 3 m is saved.
2. `/canteenremovepump` deletes the nearest saved pump within 5 m.
3. Set `Config.PumpVerify.Enabled = true`. Pumps placed with rsg-wellpump are accepted automatically (`UseWellpump`).

### Pump fee (optional)
Set `Config.PumpFee.Enabled = true`. It only works with `PumpVerify.Enabled = true`; otherwise the server prints a warning and ignores the fee. The fee is charged when a pump fill completes, not for river fills.

## 4. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `AutoDatabase` | `true` | Create the table on start; `false` to import `install.sql` |
| `Canteens` | `canteen` 10 uses / 25 thirst, `canteen_large` 20 / 25 | Item -> `maxUses`, `thirst` |
| `MaxThirst` | `100` | Thirst cap |
| `FillTime` / `DrinkTime` | `5000` / `3000` | Progress bar ms |
| `TargetDistance` | `2.0` | Target range |
| `PumpModels` | 2 models | Pump props to target |
| `WaterFill` | table | `Enabled`, `Key` (G), `CheckEvery`, `AllowedZones` (empty = any water) |
| `DirtyWater` | `Enabled`, `SickChance 0.6`, `Damage 15`, `MinHealth 40`, `ThirstFactor 0.5` | Dirty water rules |
| `Purify` | `Enabled`, `Time 8000`, `Models { 'p_campfirecombined01x' }` | Purify at fire props |
| `Share` | `Enabled`, `Distance 3.0`, `Time 3000` | Give a drink |
| `WeatherThirst` | `Enabled`, `Multipliers { highpressure 0.85, sandstorm 0.8 }` | Weather scaling (rsg-weather names) |
| `PumpVerify` | `Enabled false`, `Radius 3.0`, `UseWellpump true`, `Permission 'admin'` | Server-side pump check |
| `PumpFee` | `Enabled false`, `Price 0.25`, `Account 'cash'` | Fee per pump fill |
| `FillAnim` / `DrinkAnim` | tables | `dict`, `clip` |
| `CanteenProp`, `PropBone`, `PropOffset`, `PropRotation` | | Held prop |

## 5. Events, callbacks, exports and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-canteen:server:startFill` | callback | `(pumpCoords, fromWater)`; checks distance, optional pump verification, canteen, fee funds |
| `rsg-canteen:server:finishFill` | server event | `(completed)`; minimum time, distance, charges the fee, writes the canteen |
| `rsg-canteen:server:startPurify` | callback | `(fireCoords)`; checks distance and that a dirty canteen exists |
| `rsg-canteen:server:finishPurify` | server event | `(completed)`; cleans every dirty canteen |
| `rsg-canteen:server:startShare` | callback | `(targetId)`; checks target online, distance, canteen, target thirst |
| `rsg-canteen:server:finishShare` | server event | `(completed)`; re-checks everything, consumes one use, applies the drink to the target |
| `rsg-canteen:server:finishDrink` | server event | `(completed)`; only accepted for a pending drink after the minimum time |
| `rsg-canteen:server:addPump` | server event | `(coords, model)`; admin only, saves a pump |
| `rsg-canteen:client:drink` | client event | Start drinking (sent by the server after item use and checks) |
| `rsg-canteen:client:sick` | client event | `(damage, minHealth)`; sent by the server for dirty water |
| `rsg-canteen:client:addPump` | client event | Sent by `/canteenaddpump` |
| `/canteenaddpump`, `/canteenremovepump` | commands | Need `Config.PumpVerify.Permission` |
| `exports['rsg-canteen']:ConsumeUse(src)` | server export | Takes one use from the player's best canteen; returns `true` on success |

## 6. Integrations
- **rsg-hud:** thirst is written with `exports['rsg-hud']:SetNeed(src, 'thirst', value)` (falls back to `hud:client:UpdateThirst`).
- **rsg-stables:** add `{ item = 'canteen', label = 'Canteen', thirst = 30, stamina = 5, canteen = true }` to `Config.HorseDrinkItems`; Water Horse then calls `ConsumeUse`.
- **rsg-wellpump:** its placed pumps are accepted by pump verification (`exports['rsg-wellpump']:GetPumps()`).
- **rsg-cooking:** its campfire prop (`p_campfirecombined01x`) is the default purify fire. Add other fire models to `Purify.Models`.

## 7. Security
- Drinking only starts from the server (item use). `finishDrink` is accepted only for a pending drink after the minimum drink time. Use counts, thirst, weather, dirty-water and sickness are all decided on the server; the client never sends an amount.
- Thirst is written by the server through `rsg-hud` (not capped or reverted like a client-side write).
- Fill, purify and share each use a start callback plus a finish event with a minimum time and a server-side distance check; a player can only have one pending action, and stale actions expire.
- Share: the target must be a real online player within `Share.Distance` (server positions), different from the giver, and not at full thirst. No item or money is created.
- Fee: funds are checked at start and the fee is charged with `RemoveMoney` on completion; nothing is filled if the charge fails.
- **Known limits:** without `PumpVerify`, pump and water positions come from the client, so a modified client can fill anywhere (water is free, so the impact is low); the server cannot see water at all, so river fills are always client-claimed. Purify has the same limit for fire positions. Turn on `PumpVerify` before enabling a fee. The fee never applies to river fills.
- Admin commands and `addPump` check `Config.PumpVerify.Permission` on the server.

## 8. Database
| Table | Purpose |
|---|---|
| `rsg_canteen_pumps` | Registered map pumps (`id`, `x`, `y`, `z`, `model`, `added_by`, `added_at`) |

Created automatically on start (`Config.AutoDatabase = true`). For a manual install set it to `false` and import `install.sql`.

## 9. Troubleshooting
| Problem | Fix |
|---|---|
| No fill option at pumps | Carry a canteen; check the item names in `Config.Canteens` and that rsg-target is running |
| `item "x" is not in rsg-core shared items, skipping` | Add the item to `rsg-core/shared/items.lua` |
| Uses reset or stack | Items must be `unique = true` |
| No water bar in the inventory | The bar comes from `info.quality`; older canteens get it on their next fill or drink |
| River fill does nothing | Stand in shallow water; check `WaterFill.Enabled` and `AllowedZones` |
| "This pump is out of order" | `PumpVerify` is on and the pump is not registered; use `/canteenaddpump` |
| Fee not charged | `PumpFee` needs `PumpVerify.Enabled = true` (see the server console warning) |
| Thirst not changing | Make sure `rsg-hud` is started, or that your HUD handles `hud:client:UpdateThirst` |
| "You can't do that right now" | Dismount, leave the vehicle or water first |
| Purify option missing | You need a dirty canteen, and the fire model must be in `Purify.Models` |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Names, arguments and defaults below follow **rsg-canteen 3.1.0**.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-canteen:server:startFill` | server | `source, cb, pumpCoords, fromWater` | `server/server.lua` |
| `rsg-canteen:server:startPurify` | server | `source, cb, fireCoords` | `server/server.lua` |
| `rsg-canteen:server:startShare` | server | `source, cb, targetId` | `server/server.lua` |

```lua
-- client side
local ok = RSGCore.Functions.AwaitCallback('rsg-canteen:server:startFill', 5000, pumpCoords, fromWater)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-canteen:client:drink` | client | `` | `client/client.lua` |
| `rsg-canteen:client:sick` | client | `damage, minHealth` | `client/client.lua` |
| `rsg-canteen:client:addPump` | client | `` | `client/client.lua` |
| `rsg-canteen:server:finishDrink` | server | `completed` | `server/server.lua` |
| `rsg-canteen:server:finishFill` | server | `completed` | `server/server.lua` |
| `rsg-canteen:server:finishPurify` | server | `completed` | `server/server.lua` |
| `rsg-canteen:server:finishShare` | server | `completed` | `server/server.lua` |
| `rsg-canteen:server:addPump` | server | `coords, model` | `server/server.lua` |

### Exports

| Export | Side | Arguments | Returns |
|---|---|---|---|
| `ConsumeUse` | server | `src` | `boolean` |

```lua
-- from a server script
local ok = exports['rsg-canteen']:ConsumeUse(source)
```

### Commands

| Command | Permission | Description |
|---|---|---|
| `canteenaddpump` | `Config.PumpVerify.Permission` | Register the pump you are standing next to |
| `canteenremovepump` | `Config.PumpVerify.Permission` | Remove the nearest registered pump |

### Items

`canteen`, `canteen_large` (see `Config.Canteens`)

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
