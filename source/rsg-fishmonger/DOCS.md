# rsg-fishmonger – Docs (v3.0.0)

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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

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

Support the Project : https://rexshack.tebex.store/
