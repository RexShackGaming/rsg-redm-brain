# rsg-canteen – Docs (v3.0.5)

## Contents
1. Files
2. How it works
3. Setup
4. Configuration
5. Events and callbacks
6. Security
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target` |
| `shared/config.lua` | Item, uses, timings, pumps, river fill, animations, prop |
| `client/client.lua` | Pump targets, river fill prompt, fill/drink animations and prop |
| `server/server.lua` | Useable item, canteen metadata, fill/drink validation |
| `server/versionchecker.lua` | GitHub version check |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Target a water pump (`p_waterpump01x`, `p_wellpumpnbx01x`) with rsg-target to fill. The option only shows if you carry a canteen.
- Or stand in shallow river/lake water and hold `G` to fill (optionally limited to `AllowedZones`).
- A full canteen has `MaxUses` (10) uses. Each drink restores `ThirstAmount` (25), capped at `MaxThirst`.
- Uses are stored per canteen in item metadata; filling tops up your emptiest canteen first.
- Progress bars can be cancelled; nothing is used or filled if cancelled.
- A canteen prop is held while drinking.

## 3. Setup
Add the item to `rsg-core/shared/items.lua`. It **must** be `unique = true` so each canteen keeps its own uses:
```lua
canteen = { name = 'canteen', label = 'Canteen', weight = 500, type = 'item', image = 'canteen.png', unique = true, useable = true, shouldClose = true, description = 'A metal canteen for carrying water' },
```
Add `canteen.png` to `rsg-inventory/html/images/` and `ensure rsg-canteen` after its dependencies.

## 4. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `CanteenItem` | `'canteen'` | Item name |
| `MaxUses` | `10` | Uses after filling |
| `ThirstAmount` | `25` | Thirst per drink |
| `MaxThirst` | `100` | Thirst cap |
| `FillTime` / `DrinkTime` | `5000` / `3000` | Progress bar ms |
| `TargetDistance` | `2.0` | Pump target range |
| `PumpModels` | list | Pump props to target |
| `WaterFill` | table | `Enabled`, `Key` (G), `CheckEvery`, `AllowedZones` (empty = any water) |
| `FillAnim` / `DrinkAnim` | tables | `dict`, `clip` |
| `CanteenProp`, `PropBone`, `PropOffset`, `PropRotation` | | Held prop |

## 5. Events and callbacks
| Name | Side | Notes |
|---|---|---|
| `rsg-canteen:server:startFill` | callback | `(pumpCoords, fromWater)`; checks item and distance |
| `rsg-canteen:server:finishFill` | server event | `(completed)`; checks minimum fill time |
| `rsg-canteen:client:drink` | client event | Start drinking (sent after item use) |
| `rsg-canteen:server:finishDrink` | server event | `(completed)`; checks minimum drink time |
| `rsg-canteen:client:addThirst` | client event | `(amount)` |

## 6. Security
The server checks fill distance, minimum fill and drink time, and only accepts a drink after the item was used, so events cannot be spammed or triggered remotely. Stale actions expire, so a crash mid-drink never locks a player.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| No fill option at pumps | Carry a canteen; check the item name and rsg-target is running |
| Uses reset or stack | Item must be `unique = true` |
| River fill does nothing | Stand in shallow water; check `WaterFill.Enabled` and `AllowedZones` |
| Thirst not changing | Check your HUD handles thirst changes |

Support the Project : https://rexshack.tebex.store/
