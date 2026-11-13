# rsg-legendary – Docs (v3.1.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Trappers, hunt flow, animals, prices, extras |
| `client/client.lua`, `client/main.js` | Trapper, trail, clues, animal, skinning |
| `server/server.lua` | Maps, hunts, cooldowns, rewards, trophies, groups |
| `server/sv_config.lua`, `server/webhooks.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI trapper shop and trophy board |
| `installation/install.sql` | Manual database install |
| `installation/shared_items.lua` | Items to add to `rsg-core/shared/items.lua` |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
1. **Buy a map** from the Legendary Trapper (rsg-target). Each legendary shows its price, or the time until it returns if you are on cooldown. Map purchase can require hunting XP (`XPRequirement`).
2. **Use the map** from your inventory. The hunting area and first tracks appear on the map.
3. **Follow the trail:** hold `E` at each set of tracks to inspect them. Each clue reveals the next; after the last (`ClueCount`) the legendary appears nearby.
4. **Kill and skin it** with normal skinning. If a model has no skin prompt, an rsg-target "Skin" option appears after `SkinFallbackDelay` seconds.
5. **Sell** pelts and trinkets back to the trapper. Each player can hunt each legendary once per `CooldownHours` (default 24).

Extras:
- **Kill quality:** kills with a bow, knife, throwing knives or varmint rifle (`Quality.PerfectWeapons`) are *perfect* and multiply trinket rewards.
- **Bonus trinket:** `BonusTrinketChance` chance of one extra.
- **Trophy board:** a Trophies tab shows the first hunter and fastest hunt per legendary, plus your own kills.
- **Group hunts:** the owner runs `/invitehunt <id>`; the invitee runs `/accepthunt`. Members see the trail, and rewards are shared with members within `ShareDistance` of the carcass.
- **Saved hunts** survive relogs and restarts until they expire (`SaveHunts`).
- **Cooldown telegrams** through rsg-telegram when a legendary is huntable again.

15 legendaries: bear, buck, boar, wolf, cougar, panther, big horn ram, moose, elk, fox, coyote, bull gator, beaver, pronghorn and Tatanka bison.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Trappers` | list | `id`, `model`, `coords`, `blip` |
| `TrapperInteractDistance` / `TrapperServerDistance` / `TrapperSpawnDistance` | `3.0` / `6.0` / `80.0` | Distances |
| `MapItem` | `'legendary_map'` | Map item |
| `HuntDuration` | `3600` | Seconds a hunt stays active |
| `ClueCount`, `ClueSpread`, `RouteToClue` | `3`, `120.0`, `true` | Trail |
| `ClueZoneDistance`, `ClueTargetDistance`, `CluePromptKey`, `CluePromptHold` | | Clue prompt |
| `ClueInspectDist`, `ClueInspectTime`, `ClueScenario` | `4.0`, `5000` | Inspection |
| `SpawnOffset`, `ActivateDistance` | `60.0`, `120.0` | Animal spawn |
| `SkinFallbackDelay`, `SkinTime`, `DeleteCarriedPelt`, `SkinMaxDistance` | `15`, `8000`, `true`, `6.0` | Skinning |
| `CooldownHours` | `24` | Per player, per legendary |
| `MoneyType` | `'cash'` | Payment account |
| `Quality` | table | `Enabled`, `PerfectWeapons`, `TrinketMult` (2) |
| `BonusTrinketChance` | `0.10` | Extra trinket chance |
| `Trophies`, `Group`, `SaveHunts`, `CooldownTelegram` | tables | Extras (`Group`: `MaxMembers` 3, `InviteDistance` 10, `InviteTimeout` 60, `ShareDistance` 30) |
| `XPRequirement` | table | `Enabled`, `DefaultMinXP` (1000), `RepName` (`hunting`) |
| `Animals` | table | Per animal: model, outfit preset, price, zone centre and radius, aggression, health multiplier, rewards, skin mode |
| `SellPrices` | table | Trapper's price per item |

Zone centres are approximate: stand where you want a hunt and update `zone` (x/y only). Use `/legendpreview` to pick outfit presets. Webhook URLs are in `server/sv_config.lua`.

## 4. Exports, events and commands
| Name | Side | Notes |
|---|---|---|
| `GetTrophies(citizenid)` | server export | A hunter's trophy data |
| `rsg-legendary:server:animalSpawned` | server event | `(netId)` register the legendary |
| `rsg-legendary:client:startHunt` | client event | `(data)` |
| `rsg-legendary:client:endHunt` | client event | End the hunt |
| `rsg-legendary:client:preview` | client event | `(key, preset)` outfit preview |

| Command | Who | What |
|---|---|---|
| `/abandonhunt` | everyone | Abandon the active hunt |
| `/invitehunt <id>` | hunt owner | Invite a nearby player (when groups are enabled) |
| `/accepthunt` | invitee | Accept the invite |
| `/legendpreview` | admin | Preview an animal's outfit presets |

## 5. Database
Created and upgraded automatically on start: `rsg_legendary_cooldowns`, `rsg_legendary_trophies`, `rsg_legendary_hunts`. `installation/install.sql` is the manual option. Add `installation/shared_items.lua` to your items file and the images to `rsg-inventory/html/images`.

## 6. Security
The server owns the hunt: map use, clue distance, animal registration, skin distance (`SkinMaxDistance`), cooldowns and rewards. Sales remove items first and refund on failure; inventory space is checked before giving items.

## 7. How-tos
- Move a hunt: edit the animal's `zone`.
- Remove the XP gate: `XPRequirement.Enabled = false`.
- Without rsg-hunting, the `hunting` rep is used for the XP check.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Can't buy a map | Cooldown, not enough XP, or not near the trapper |
| No skin prompt | Wait `SkinFallbackDelay` for the rsg-target Skin option |
| Hunt gone after restart | Check `SaveHunts` and the `rsg_legendary_hunts` table |
| Animal didn't appear | Get within `ActivateDistance` of the spawn point after the last clue |

Support the Project : https://rexshack.tebex.store/
