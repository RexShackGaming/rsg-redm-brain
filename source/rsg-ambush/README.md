# rsg-ambush

Version 3.2.1 · Random gang ambushes for RSG Framework · [Full docs](DOCS.md)

While a player is riding outside of towns, every `Config.CheckInterval` seconds the server rolls a chance for an ambush. If it hits (and the cooldown allows), a warning sounds, then a gang (O'Driscolls, Lemoyne Raiders, Murfree Brood or Skinner Brothers) appears ahead of the player, partly on horseback, and attacks. Beat them for a bounty, honor and skill XP, and search the bodies (rsg-target) for loot.

## Features
- **Server-side roll:** the server decides if, when and which gang. Chance is shaped by the player's honor (rsg-reputation) and the nearby town (rsg-economy).
- **Safe spawn points:** bandits never spawn in water, on steep ground or inside interiors.
- **Gang behaviour:** hurt bandits can flee or surrender; the Raiders put a sniper on high ground; some gangs call in reinforcements from behind.
- **Rewards:** a bounty per killed bandit (doubled for on-duty lawmen), honor and town standing (rsg-reputation), skill XP (rsg-skills), per-body loot, per-gang loot tables and a rare strongbox.
- **Warning:** a sound and a notice a few seconds before the attack.
- **Fair endings:** if the player dies the gang rides off and the ambush is removed after a short delay.
- **Safe by design:** see Security below.

## Values taken from the decompile
- Gang ped models and relationship groups: `ambush_odr_*`, `ambush_exc_*`, `ambush_inb_*`, `ambush_sav_*`
- Horse models: the most-used `A_C_HORSE_*` across `ambush_*.c`
- Accuracy / shoot rate ranges: difficulty switch in `ambush_odr_road_robbery.c`
- `SET_PED_COMBAT_MOVEMENT(ped, 2)`: `ambush_bnd_cliff1.c`
- Enemy blip `BLIP_STYLE_ENEMY` via `BLIP_ADD_FOR_ENTITY`, `TASK_COMBAT_PED`, config flag 6: `ambush_odr_road_robbery.c`

## Install
1. Drop `rsg-ambush` into your resources and `ensure rsg-ambush` after rsg-core and rsg-target (and after rsg-reputation, rsg-skills and rsg-economy if you use them).
2. Tune `shared/config.lua` (chance, cooldown, gangs, rewards, loot).
3. Set `Config.Debug = true` to test with `/testambush` (admin). Turn it off again: debug mode ignores the cooldown.

No database needed.

## Dependencies
rsg-core, rsg-inventory, rsg-target. No ox_lib.
Optional (used only when started, never an error when missing): rsg-reputation, rsg-skills, rsg-economy.

## Config highlights
| Option | What it does |
|---|---|
| `CheckInterval` / `TriggerChance` / `RequestThrottle` | How often a check happens, the base % chance (server rolled) and the minimum seconds between two checks |
| `RequireMounted`, `MinPlayerSpeed`, `BlockInTowns` | Only ambush moving riders outside towns |
| `PlayerCooldown` | Seconds between ambushes per character (server enforced) |
| `WarningSeconds`, `WarningSound` | Warning before the bandits appear |
| `SpawnChecks` | Safe-ground rules (water depth, steepness, interiors, tries) |
| `MaxDuration`, `CorpseTime`, `DespawnDistance`, `DeathCleanupDelay` | When an ambush is cleaned up |
| `LowHealth`, `SurrenderTime`, `FleeEscapeDistance` | When hurt bandits flee or surrender, and when a runner has escaped |
| `Gangs` | Models, weapons, group size, mounted %, accuracy, fire rate, `fleeChance`, `surrenderChance`, `sniper`, `reinforcements`, `bounty`, `loot` per gang |
| `Hooks.Honor` / `Hooks.Scaling` | Honor changes the chance (rsg-reputation); skill level adds bandits (rsg-skills) |
| `Zones` | Per-town chance and gang weights (rsg-economy) |
| `Bounty`, `Rewards` | Cash per kill with job multipliers; honor, standing, mercy honor and skill XP for winning |
| `LootCash`, `LootItems`, `Strongbox` | Per-body loot and the rare strongbox, rolled and paid by the server |

## How it plays
1. A check passes on the server and a warning sounds: you have a few seconds.
2. The gang appears ahead of you. Some bandits are mounted, a Raider sniper may take the high ground.
3. Hurt bandits may run or put their hands up. Reinforcements may ride in from behind.
4. When enough of them are down you get the "fought them off" notice and the server pays the bounty, honor and XP.
5. Search the bodies with rsg-target for cash and items; one body may carry a strongbox.

## Languages
All player text, gang names, Discord log text and the command help live in `locales/`: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru. Locales load through rsg-core's shared loader; set the language with `setr rsg:locale "de"` in your server.cfg (falls back to `ox:locale`).

## Discord logs
Paste webhook URLs into `server/sv_config.lua` (server only, never sent to clients):
- `Ambush`: ambush started, ended (gang, duration, bodies looted, cash paid), gang defeated (killed, left alive, bounty), player left mid-ambush
- `Loot`: every body searched with cash and items (and the strongbox)
- `Security`: rejected requests (double registration, registering or looting non-bandit entities, looting from too far away), throttled per player
- Empty channels fall back to `Default`; leave everything empty or set `Enabled = false` to turn logging off.

Messages are queued and sent about once a second, with a retry when Discord rate-limits (429). Each embed includes the player name, server ID, character, citizen ID, license and coords.

## Security
- The server rolls the chance, picks the gang and the group size, enforces the cooldown and a request throttle, and refuses dead or jailed players.
- Bandits are registered once per group (a second time only for reinforcements the server planned); the server waits for them to exist and only accepts non-player peds of the gang's models owned by that player, near them, and not claimed by another ambush.
- The bounty, honor, standing and XP are paid by the server, once per ambush, only after it sees enough dead bandits.
- Loot is only paid for a registered, dead, non-player ped of that gang's models, within range, once per body. The strongbox is chosen by the server.
- A body is only marked as searched once the server accepts the loot, so a rejected or timed-out search can be retried.
- Ambush state expires on the server after `MaxDuration + CorpseTime`, so it can't be kept alive or farmed.
- If a player crashes or disconnects mid-ambush, or an ambush expires, the server deletes the bandits and horses it registered.
- `Config.LootCash`, `Config.LootItems`, `Config.Gangs`, `Config.Strongbox` and `Config.Bounty` are validated when the server starts; bad entries are skipped with a console warning.
- Keep `Config.Debug = false` on a live server: debug mode ignores the cooldown and always rolls a hit.

## Changelog
### 3.2.1
- rsg-deliveries hook (optional): ambushes are likelier while a delivery contract is active, and two local server events (`ambushStarted`, `ambushWon`) let other resources react.

### 3.2.0
- Safe spawn points, server-side roll, warning cue, death delay
- Optional hooks: honor (rsg-reputation), skill scaling and XP (rsg-skills), per-town chance and gangs (rsg-economy)
- Bounty (doubled for lawmen), mercy honor, per-gang loot tables, strongbox
- Gang behaviour: flee, surrender, sniper, reinforcements
- See CHANGELOG.md

### 3.1.0
- Fixed a race that could end an ambush mid-spawn and error in the spawn code, and a re-entrancy bug in cleanup
- Server now validates bandit registration and removes bandits left behind by crashes, disconnects and expired ambushes
- Config validation at start, jailed players skipped, per-bandit blip removal, gang relationship restored after the ambush

### 3.0.1
- ox_lib removed completely (progress bar now uses rsg-core); ox_target → rsg-target, ox_lib callbacks/notify → rsg-core, locales via `@rsg-core/shared/locale.lua`

Support the Project : https://rexshack.tebex.store/
