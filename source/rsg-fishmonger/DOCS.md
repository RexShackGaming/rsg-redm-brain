# rsg-fishmonger – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Events, callbacks and commands
5. Security
6. Server owner how-tos
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target` |
| `shared/config.lua` | NPC, locations, hours, demand, bonus, stock, shop, fish prices |
| `shared/utils.lua` | Shared helpers |
| `client/client.lua` | NPC spawning, blips, targets, NUI bridge |
| `server/server.lua` | Menu data, checkout, daily demand and stock, shop |
| `server/sv_config.lua`, `server/webhook.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI cart menu |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
- 8 fishmonger NPCs: Saint Denis, Blackwater, Valentine, Rhodes, Annesburg, Van Horn, Tumbleweed and the river trading post, each with an optional blip.
- Use rsg-target on the NPC to open a cart menu. **Sell** fish for money (`cash`, `bank` or `bloodmoney`) or **process** them into fillets (`raw_fish` by default).
- **Daily demand:** each town rolls a price multiplier every real day (80%–125%).
- **Seller bonus:** extra pay from fishing rep (earned per fish traded) and optional per-job bonuses.
- **Daily stock:** each town only buys a set number of fish per day; the count survives restarts. Processing is not limited.
- **Supplies shop:** buy bait and lures from the same NPC (an rsg-inventory shop per town).
- **Fillet types:** any fish can give its own fillet item.
- **Opening hours** (optional) use the rsg-weather in-game clock.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `NpcModel` | `cs_fishcollector` | NPC model |
| `SpawnDistance` | `50.0` | NPC spawn/despawn range |
| `TargetDistance` | `2.5` | rsg-target range |
| `MaxUseDistance` | `5.0` | Server-side distance check |
| `Cooldown` | `2000` | ms between checkouts |
| `MoneyType` | `'cash'` | `cash`, `bank` or `bloodmoney` |
| `FilletItem` | `'raw_fish'` | Default fillet item |
| `Blip` | table | `enabled`, `sprite`, `style` |
| `Locations` | list | `{ key, coords, hours?, demand?, stock? }`; display name comes from locale `loc_<key>` |
| `OpeningHours` | table | `enabled`, `open` (6), `close` (22); wraps past midnight; per-location `hours` override |
| `Demand` | table | `enabled`, `min` 0.80, `max` 1.25; `demand = false` on a location for base price |
| `Bonus` | table | `jobs` (job → fraction) and `rep` (`name`, `perPoint`, `max` 0.15, `gainPerFish`) |
| `DailyStock` | table | `enabled`, `perLocation` (200); per-location `stock` (0 = unlimited) |
| `Shop` | table | `enabled`, `persistentStock`, `items` (`name`, `price`, `amount`) |
| `Fish` | table | fish model → `{ price, fillets, fillet? }` |

Example, a fish with its own fillet:
```lua
['a_c_fishsalmonsockeye_01_lg'] = { price = 2.75, fillets = 3, fillet = 'salmon_fillet' },
```
Webhook URLs are in `server/sv_config.lua`.

## 4. Events, callbacks and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-fishmonger:server:getMenuData` | callback | `(locationIndex)` prices, stock, owned fish |
| `rsg-fishmonger:server:checkout` | callback | `(locationIndex, mode, cart)` sell or process |
| `rsg-fishmonger:server:openShop` | server event | `(locationIndex)` supplies shop |

| Command | Who | What |
|---|---|---|
| `/fishmonger_webhooktest` | admin | Send a test webhook |

## 5. Security
The server checks distance to the NPC, opening hours, cooldown, that the fish are accepted and owned, daily stock, and computes prices itself (demand, bonus). The cart from the client only lists items and amounts.

## 6. How-tos
- Add a fish: add its model to `Config.Fish` and make sure the item exists.
- Stop daily stock limits: `DailyStock.enabled = false`.
- Bait item names should match rsg-fishing's baits.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| NPC closed | `OpeningHours.enabled` and rsg-weather's clock |
| "Town stock full" | Wait for the next real day or raise `perLocation` |
| Shop items missing | Item must exist in rsg-core items |
| Fish not listed | Missing from `Config.Fish` |

## rsg-skills integration

`Config.Bonus.skill = { enabled, name, perk }`. `bonusFor(Player)` reads `exports['rsg-skills']:GetPerk(src, name, perk)` on the server (a percent, so `10` becomes `+0.10`) and adds it to the job and rep bonus. It is applied on the server for the payout and for the bonus sent to the UI. Skipped when rsg-skills is not started.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-fishmonger 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.NpcModel` | ``cs_fishcollector`` |  |
| `Config.SpawnDistance` | `50.0` | npc spawns / despawns at this range |
| `Config.TargetDistance` | `2.5` | rsg-target interaction distance |
| `Config.MaxUseDistance` | `5.0` | server-side distance check to the npc |
| `Config.Cooldown` | `2000` | ms between checkouts per player (anti-spam) |
| `Config.MoneyType` | `'cash'` | 'cash' \| 'bank' \| 'bloodmoney' |
| `Config.FilletItem` | `'raw_fish'` |  |
| `Config.ImagePath` | `'nui://rsg-inventory/html/images/'` |  |
| `Config.Blip` | `table` |  |
| `Config.Locations` | `table` |  |
| `Config.OpeningHours` | `table` |  |
| `Config.Demand` | `table` |  |
| `Config.Bonus` | `table` |  |
| `Config.DailyStock` | `table` |  |
| `Config.Shop` | `table` |  |
| `Config.Fish` | `table` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-fishmonger:server:getMenuData` | server | `source, cb, locationIndex` | `server/server.lua` |
| `rsg-fishmonger:server:checkout` | server | `source, cb, locationIndex, mode, cart` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-fishmonger:server:getMenuData', function(result)
    -- use result
end, locationIndex)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-fishmonger:server:openShop` | server | `locationIndex` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-fishmonger:server:openShop', locationIndex)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/fishmonger_webhooktest` | locale('cmd_webhooktest_help') | `server/webhook.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
