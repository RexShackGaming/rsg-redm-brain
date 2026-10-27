# rsg-ambush

Random gang ambushes for RSG Framework.

While a player is riding outside of towns, every `Config.CheckInterval` seconds there's a `Config.TriggerChance`% roll. If it hits (and the server cooldown allows), a gang (O'Driscolls, Lemoyne Raiders, Murfree Brood or Skinner Brothers) spawns ahead of the player, partly on horseback, and attacks. Kill them and search the bodies (ox_target) for cash, paid out by the server.

## Values taken from the decompile
- Gang ped models and relationship groups: `ambush_odr_*`, `ambush_exc_*`, `ambush_inb_*`, `ambush_sav_*`
- Horse models: the most-used `A_C_HORSE_*` across `ambush_*.c`
- Accuracy / shoot rate ranges: difficulty switch in `ambush_odr_road_robbery.c`
- `SET_PED_COMBAT_MOVEMENT(ped, 2)`: `ambush_bnd_cliff1.c`
- Enemy blip `BLIP_STYLE_ENEMY` via `BLIP_ADD_FOR_ENTITY`, `TASK_COMBAT_PED`, config flag 6: `ambush_odr_road_robbery.c`

## Install
1. Drop `rsg-ambush` into your resources and `ensure rsg-ambush` after rsg-core, ox_lib and ox_target.
2. Tune `shared/config.lua` (chance, cooldown, gangs, loot).
3. Set `Config.Debug = true` to test with `/testambush` (admin).

No database needed.

## Dependencies
rsg-core, rsg-inventory, ox_lib, ox_target.

## Config highlights
| Option | What it does |
|---|---|
| `CheckInterval` / `TriggerChance` | How often a roll happens and the % chance it hits |
| `RequireMounted`, `MinPlayerSpeed`, `BlockInTowns` | Only ambush moving riders outside towns |
| `PlayerCooldown` | Seconds between ambushes per character (server enforced) |
| `MaxDuration`, `CorpseTime`, `DespawnDistance` | When an ambush is cleaned up |
| `Gangs` | Models, weapons, group size, mounted %, accuracy and fire rate per gang |
| `LootCash`, `LootItems` | Per-body loot, rolled and paid by the server |

## Languages
All player text, gang names, Discord log text and the command help live in `locales/`: en, de, el, es, fr, ja, nl, pl, pt-br, ro. Set the language with `setr ox:locale "de"` in your server.cfg.

## Discord logs
Paste webhook URLs into `server/sv_config.lua` (server only, never sent to clients):
- `Ambush`: ambush started, ended (gang, duration, bodies looted, cash paid), player left mid-ambush
- `Loot`: every body searched with cash and items
- `Security`: rejected requests (double registration, looting players or non-bandit peds, looting from too far away), throttled per player
- Empty channels fall back to `Default`; leave everything empty or set `Enabled = false` to turn logging off.

Messages are queued and sent about once a second, with a retry when Discord rate-limits (429). Each embed includes the player name, server ID, character, citizen ID, license and coords.

## Security
- The server decides whether an ambush happens, which gang, and the cooldown.
- Bandits are registered once per ambush; loot is only paid for a registered, dead, non-player ped of that gang's models, within range, once per body.
- Ambush state expires on the server after `MaxDuration + CorpseTime`, so it can't be kept alive or farmed.

Support: https://buymeacoffee.com/rexshack
