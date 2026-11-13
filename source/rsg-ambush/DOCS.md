# rsg-ambush – Docs (v3.0.1)

## Contents
1. Files
2. How it works
3. Configuration
4. Events and commands
5. Security
6. Server owner how-tos
7. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target` |
| `shared/config.lua` | Triggering, spawning, gangs, loot |
| `client/client.lua` | Rolls, spawning gang peds, blips, loot targets, cleanup |
| `server/server.lua` | Ambush approval, cooldowns, loot rewards |
| `server/logs.lua`, `server/sv_config.lua` | Logging and webhook settings |
| `server/versionchecker.lua` | GitHub version check |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- While a player rides outside towns, every `CheckInterval` seconds there is a `TriggerChance`% roll. If it hits and the server cooldown allows, a gang ambushes them.
- Gangs: O'Driscolls, Lemoyne Raiders, Murfree Brood and Skinner Brothers (weighted random). Models, relationship groups, weapons, horses and accuracy/shoot rates follow the single-player `ambush_*` scripts.
- The ambush spawns ahead of the player (`SpawnDistance`), with red enemy blips. It ends when the bandits are dead, the player rides `DespawnDistance` away, or `MaxDuration` passes.
- Bodies stay for `CorpseTime` seconds. Loot them with rsg-target for cash and items.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Enables `/testambush` and forces 100% chance |
| `CheckInterval` | `60` | Seconds between rolls |
| `TriggerChance` | `6` | % per roll |
| `RequireMounted` | `true` | Only ambush riders |
| `BlockInTowns` | `true` | No ambushes in towns |
| `PlayerCooldown` | `1800` | Seconds per player (server enforced) |
| `MinPlayerSpeed` | `2.0` | m/s needed to be ambushed |
| `SpawnDistance` | `{60, 90}` | m ahead of the player |
| `SpawnSpread` | `12.0` | m between bandits |
| `DespawnDistance` | `350.0` | Ambush ends beyond this |
| `MaxDuration` | `600` | Seconds before cleanup |
| `CorpseTime` | `240` | Seconds bodies stay |
| `UseBlips` | `true` | Enemy blips |
| `Horses` | list | Bandit horse models |
| `Gangs` | table | Per gang: `weight`, `relGroup`, models, weapons, accuracy, shoot rate (display names are locale `gang_<key>`) |
| `LootDistance` / `LootTime` | `3.0` / `3000` | Loot range and progress bar |
| `LootCash` | `{1, 8}` | Dollars per body |
| `LootItems` | list | Item drops with chances |

## 4. Events and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-ambush:server:requestAmbush` | callback | Server approves a roll (cooldown, limits) |
| `rsg-ambush:server:registerPeds` | server event | `(id, netIds)` |
| `rsg-ambush:server:finish` | server event | `(id)` |
| `rsg-ambush:server:loot` | callback | `(id, netId)` pays loot once per body |
| `rsg-ambush:client:force` | client event | Force an ambush (debug) |

| Command | Who | What |
|---|---|---|
| `/testambush` | admin, only with `Config.Debug` | Trigger an ambush now |

## 5. Security
The server enforces the per-player cooldown, tracks the ambush and its peds, and pays loot only for registered bodies, once each, within `LootDistance`. Inventory space is checked before items are given.

## 6. How-tos
- Make ambushes rarer: lower `TriggerChance` or raise `PlayerCooldown`.
- Test: set `Debug = true`, then `/testambush`.
- Tune gang odds with each gang's `weight`.

## 7. Troubleshooting
| Problem | Fix |
|---|---|
| Never ambushed | Must be mounted, moving, outside towns and off cooldown |
| Peds don't fight | Check `relGroup` for the gang |
| Can't loot | Move within `LootDistance`; each body pays once |
| Bandits linger | They clean up after `MaxDuration` or `DespawnDistance` |

Support the Project : https://rexshack.tebex.store/
