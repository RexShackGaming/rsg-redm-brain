# rsg-ambush – Docs (v3.2.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Integrations (rsg-reputation, rsg-skills, rsg-economy)
5. Events, callbacks and commands
6. Security
7. Server owner how-tos
8. Troubleshooting
9. Technical reference

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target` (rsg-reputation, rsg-skills, rsg-economy are optional) |
| `shared/config.lua` | Triggering, spawning, gangs, hooks, zones, rewards, loot |
| `client/client.lua` | Checks, warning, safe spawning, gang behaviour, blips, loot targets, cleanup |
| `server/server.lua` | The roll, approval, cooldowns, registration checks, bounty and rewards, loot |
| `server/logs.lua`, `server/sv_config.lua` | Logging and webhook settings |
| `server/versionchecker.lua` | GitHub version check |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
1. **Check.** Every `CheckInterval` seconds the client checks that the player is mounted (`RequireMounted`), moving (`MinPlayerSpeed`), outside towns (`BlockInTowns`) and in control, then asks the server.
2. **Roll (server).** The server refuses dead or jailed players, applies the per-player `RequestThrottle` and `PlayerCooldown`, then rolls `TriggerChance` times the honor multiplier (`Hooks.Honor`) and the area multiplier (`Zones`). On a hit it picks the gang (weights shaped by the area), the group size (plus `Hooks.Scaling` bandits for veteran riders) and whether reinforcements are planned.
3. **Warning.** A sound and a notice play, then `WarningSeconds` pass.
4. **Spawn (client).** A safe centre is found ahead of the player (water, steep ground and interiors are rejected, `SpawnChecks`). Every bandit gets a safe point of its own, some are mounted, and the Raiders may place one sniper on high ground. If no safe centre exists the ambush is cancelled and the cooldown is not used up.
5. **Fight.** Hurt bandits (below `LowHealth` of their health) may flee (`fleeChance`) or surrender (`surrenderChance`). A fleeing bandit that gets `FleeEscapeDistance` away has escaped and is removed. A surrendered bandit drops its weapons and puts its hands up for `SurrenderTime`, then runs. If the first group is nearly beaten, or `delay` seconds pass, planned reinforcements ride in from behind.
6. **Win.** When no bandit is left fighting the client reports it; the server checks that at least `Rewards.MinKilledPct` of the bandits are dead, then pays the bounty, honor, standing and XP once.
7. **Loot.** Bodies stay for `CorpseTime` seconds and can be searched with rsg-target (per-gang loot, global loot, and one body may carry the strongbox).
8. **End.** The ambush ends when the bandits are beaten and the corpse time passes, the player rides `DespawnDistance` away, `MaxDuration` passes, or the player dies (the gang rides off and the ambush is removed after `DeathCleanupDelay`).

Gangs: O'Driscolls, Lemoyne Raiders, Murfree Brood and Skinner Brothers. Models, relationship groups, weapons, horses and accuracy/shoot rates follow the single-player `ambush_*` scripts.

## 3. Configuration
`shared/config.lua`:

### Triggering and spawning
| Option | Default | Meaning |
|---|---|---|
| `Debug` | `false` | Enables `/testambush`, 100% chance, no cooldown or throttle. Never on a live server |
| `CheckInterval` | `60` | Seconds between checks on the client |
| `TriggerChance` | `6` | Base % per check, rolled by the server before the multipliers |
| `RequireMounted` | `true` | Only ambush riders |
| `BlockInTowns` | `true` | No ambushes in towns (checked by the client) |
| `PlayerCooldown` | `1800` | Seconds per character (server enforced) |
| `RequestThrottle` | `20` | Minimum seconds between two checks of one player (server enforced) |
| `MinPlayerSpeed` | `2.0` | m/s needed to be ambushed |
| `WarningSeconds` | `4` | Seconds between the warning and the bandits appearing (0 = no warning) |
| `WarningSound` | `{ name = 'Wanted_Spotted', ref = 'HUD_Wanted_Sounds' }` | Frontend sound for the warning, `nil` for silence |
| `SpawnDistance` | `{60, 90}` | m ahead of the player |
| `SpawnSpread` | `12.0` | m between bandits |
| `SpawnChecks` | table | `Attempts` (8), `MinNormalZ` (0.80, 1.0 is flat), `MaxWaterDepth` (0.4 m), `AvoidInteriors` (true) |
| `DespawnDistance` | `350.0` | Ambush ends beyond this |
| `MaxDuration` | `600` | Seconds before cleanup |
| `CorpseTime` | `240` | Seconds bodies stay after the fight |
| `DeathCleanupDelay` | `15` | Seconds the ambush lingers after the player dies |
| `UseBlips` | `true` | Enemy blips; each one disappears when its bandit dies, flees or surrenders |
| `Horses` | list | Bandit horse models |

### Gang behaviour
| Option | Default | Meaning |
|---|---|---|
| `LowHealth` | `0.30` | Fraction of max health below which a bandit may flee or surrender |
| `SurrenderTime` | `20` | Seconds a surrendered bandit holds its hands up before running |
| `FleeEscapeDistance` | `120.0` | A fleeing bandit this far from the player has escaped |

`Config.Gangs[key]` fields: `weight`, `relGroup`, `models`, `weapons`, `count = { min, max }`, `mountedChance`, `accuracy`, `shootRate`, and optionally:

| Field | Meaning |
|---|---|
| `fleeChance`, `surrenderChance` | % of bandits that run / give up when badly hurt (0 = fight to the death). They are rolled against one dice, so keep their sum <= 100 |
| `reinforcements = { chance, count = { min, max }, delay }` | A second group rides in from behind. Planned by the server |
| `sniper = { chance, weapon }` | One bandit takes high ground with this weapon |
| `bounty = { min, max }` | Cash per killed bandit, instead of `Config.Bounty.PerBandit` |
| `loot = { cash = { min, max }, items = { ... } }` | Replaces the global loot for this gang |

Display names are locale keys `gang_<key>`.

### Rewards and loot
| Option | Default | Meaning |
|---|---|---|
| `Bounty` | `Enabled`, `PerBandit {4,8}`, `JobMultipliers { leo = 2.0, bountyhunter = 1.5 }` | Cash per kill. Multipliers match the job name first, then the job type, only while on duty |
| `Rewards.MinKilledPct` | `50` | % of the bandits that must be dead for the win to count |
| `Rewards.Honor` / `Standing` | `4` / `3` | rsg-reputation honor, and standing in the nearby town |
| `Rewards.MercyHonor` / `MercyMax` | `1` / `3` | Extra honor per bandit left alive, up to `MercyMax` |
| `Rewards.Skill` | `{ name = 'horsemanship', xp = 20 }` | rsg-skills XP (`nil` to disable) |
| `LootDistance` / `LootTime` | `3.0` / `3000` | Loot range and progress bar |
| `LootCash` | `{1, 8}` | Dollars per body |
| `LootItems` | list | Item drops `{ item, min, max, chance }` |
| `Strongbox` | `Enabled`, `Chance 5`, `Cash {40,120}`, `Items {}` | % per ambush that one bandit carries extra loot |

## 4. Integrations
Each integration is skipped silently when its resource is not started. Server owners can start any subset.

| Resource | What rsg-ambush uses | Config |
|---|---|---|
| rsg-reputation | `GetHonor` (chance), `AddHonor`, `AddStanding` (rewards) | `Hooks.Honor`, `Rewards.Honor/Standing/MercyHonor` |
| rsg-skills | `GetLevel` (group size), `AddXP` (reward) | `Hooks.Scaling`, `Rewards.Skill` |
| rsg-economy | `GetRegionAt` (area for chance, gangs and standing) | `Zones` |

- `Hooks.Honor.Chance` entries use `maxHonor` (honor at or below) or `minHonor` (at or above) and a `mult`; the first matching entry wins, so list the most extreme first.
- `Zones.Areas[region].chance` multiplies the chance; `.gangs[key]` multiplies that gang's weight (0 = never there). Region ids are the rsg-economy town ids. `Zones.Radius` is how far the nearest town may be.
- Honor and standing go through rsg-reputation's own exports, so its caps and notifications apply.

## 5. Events, callbacks and commands
| Name | Side | Notes |
|---|---|---|
| `rsg-ambush:server:requestAmbush` | callback | `(force?)` -> `{ id, gang, count, wave, region }` or `false`. `force` is honoured only with `Config.Debug` |
| `rsg-ambush:server:registerPeds` | server event | `(id, netIds, horseNetIds, batch)`; batch 1 = first group, 2 = reinforcements |
| `rsg-ambush:server:claimWin` | server event | `(id)`; the server verifies the bodies before paying |
| `rsg-ambush:server:finish` | server event | `(id, aborted)`; ends the ambush and removes leftover bandits. `aborted` returns the cooldown if nothing was registered |
| `rsg-ambush:server:loot` | callback | `(id, netId)` pays loot once per body |
| `rsg-ambush:client:force` | client event | Force an ambush (debug) |

| Command | Who | What |
|---|---|---|
| `/testambush` | admin, only with `Config.Debug` | Trigger an ambush now |

## 6. Security
The server rolls the chance, enforces the cooldown and request throttle, decides the gang and group size, tracks the ambush and its peds, and pays everything.

- **Registration:** the client reports the network ids of its bandits and horses once per group (reinforcements only if the server planned them, and not sooner than 5 seconds in). The server waits up to 6 seconds for them to replicate, then accepts only non-player peds of the gang's (or `Config.Horses`) models that are owned by that player, within `DespawnDistance` of them and not claimed by another ambush. A resolved entity of the wrong type or model is logged as a security event.
- **Win:** the server counts the registered bandits' health itself (retrying for a few seconds for sync lag) and pays only when at least `MinKilledPct` are dead; a second claim pays nothing.
- **Loot:** only registered, dead, non-player peds of the gang's models, within `LootDistance + 2`, once per body. The strongbox carrier is chosen by the server and never sent to the client.
- **Cleanup:** when the ambush ends, the player disconnects, the ambush expires (`MaxDuration + CorpseTime + 30`) or the resource stops, the server deletes the bandits and horses it registered.
- **Config validation:** at start the server checks `LootCash`, `LootItems`, `Gangs`, `Strongbox` and `Bounty`; invalid entries are skipped with a console warning, and loot items missing from the shared items are reported once.
- **Not ambushed:** dead or jailed players.
- **Known limits:** "mounted", "moving" and "in town" are checked by the client only, but the server's roll, request throttle and cooldown bound how often a modified client can start an ambush. The server cannot see which player killed a bandit.
- **Debug:** `Config.Debug = true` disables the cooldown and throttle and always rolls a hit. Never leave it on for a live server.

## 7. How-tos
- **Make ambushes rarer:** lower `TriggerChance`, raise `PlayerCooldown`, or lower an area's `chance` in `Zones`.
- **Make a gang fight to the death:** set its `fleeChance` and `surrenderChance` to `0`.
- **Disable a feature:** remove `reinforcements` / `sniper` from a gang, set `Bounty.Enabled = false`, `Strongbox.Enabled = false`, `Hooks.Honor.Enabled = false`, `Hooks.Scaling.Enabled = false`, `Zones.Enabled = false`, `WarningSeconds = 0`.
- **Pay lawmen or bounty hunters more:** edit `Bounty.JobMultipliers` (job name or job type).
- **Keep a gang out of an area:** set the gang to `0` in that area's `gangs`.
- **Add valuable loot:** add items to a gang's `loot.items` or `Strongbox.Items`; names must exist in your shared items.
- **Test:** set `Debug = true`, then `/testambush`.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Never ambushed | Must be mounted, moving, outside towns, off cooldown and not jailed. The base chance is only 6% per check |
| No warning sound | `WarningSound` must be a valid frontend sound/soundset pair, or `nil` |
| Bandits seem to appear late | That is `WarningSeconds` |
| Peds don't fight | Check `relGroup` for the gang |
| Can't loot | Move within `LootDistance`; each body pays once; surrendered or fleeing bandits are alive and can't be searched |
| No bounty / honor after winning | At least `Rewards.MinKilledPct` of the bandits must be dead; honor, XP and zones need rsg-reputation, rsg-skills and rsg-economy started |
| Bandits linger | They clean up after `MaxDuration` or `DespawnDistance`; the server also deletes them if the player crashes or disconnects |
| Console warning about `Config.*` | An entry is invalid or an item doesn't exist in your shared items; fix it, it is skipped until then |
| "You can't search that body right now" | The server rejected the search (too fast, too far, not a registered bandit); step closer and try again |
| Ambush cancelled right after the warning | No safe ground was found (water, steep slope or interior); the cooldown is returned |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## 9. Technical reference

Generated from the source of **rsg-ambush 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target` (optional: `rsg-reputation`, `rsg-skills`, `rsg-economy`)

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-ambush:server:requestAmbush` | server | `src, cb, force` | `server/server.lua` |
| `rsg-ambush:server:loot` | server | `src, cb, id, netId` | `server/server.lua` |

```lua
-- client side
local data = RSGCore.Functions.AwaitCallback('rsg-ambush:server:requestAmbush', 10000)
-- data = { id, gang, count, wave = { count, delay } | nil, region } or false
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-ambush:client:force` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-ambush:server:registerPeds` | server | `id, netIds, horseNetIds, batch` | `server/server.lua` |
| `rsg-ambush:server:claimWin` | server | `id` | `server/server.lua` |
| `rsg-ambush:server:finish` | server | `id, aborted` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-ambush:server:registerPeds', id, netIds, horseNetIds, 1)
-- from a server script
TriggerClientEvent('rsg-ambush:client:force', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/testambush` | locale('cmd_testambush_help') | `server/server.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
