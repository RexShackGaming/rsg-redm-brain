# rsg-fishing — Technical Docs

Version 3.2.0. For installation and player instructions see [README.md](README.md).

## Contents

1. [Files](#files)
2. [How a fishing session runs](#how-a-fishing-session-runs)
3. [Reeling mechanics](#reeling-mechanics)
4. [Minigame struct](#minigame-struct)
5. [Exports](#exports)
6. [Events](#events)
7. [Data formats](#data-formats)
8. [Security model](#security-model)
9. [Database](#database)
10. [How-tos](#how-tos)
11. [Troubleshooting](#troubleshooting)
12. [Journal, records and regions](#journal-records-and-regions)

## Files

```
client/client.lua     Session loop, minigame states, reeling, tension, HUD and bobber updates
client/client_js.js   Reads/writes the game's fishing task struct (needs JS for the data buffer)
server/server.lua     Usable bait items, catch validation, inventory, logging
server/journal.lua    Database, angler's journal, server records, top anglers, reputation
shared/regions.lua    Lookup sets built from Config.Regions
server/versionchecker.lua  Version check on start
html/index.html       Controls HUD, tension bar and bobber indicator (NUI, no focus taken)
locales/*.json        Translations (loaded by rsg-core)
shared/config.lua     Settings, baits, fish data
```

## How a fishing session runs

1. The player uses a bait item. The server item callback triggers `rsg-fishing:client:usebait`.
2. The client checks the rod is in hand and starts the session thread. When the bait is put on the rod (state 1) it asks the server to remove it (`rsg-fishing:server:removeBaitItem`).
3. Each tick the thread reads the game's fishing task struct and acts on its state (`f_0`):

| State | Meaning | Handler |
|---|---|---|
| 1 | Rod ready | bait is applied to the rod |
| 2 | Casting | cast distance set (25–30) |
| 6 | Line in the water | `handleWaiting`: reel lure (CTRL), attract fish, bite roll |
| 7 | Fish hooked | `handleHooked`: reeling, struggling, line tension |
| 12 | Fish in hand | `handleCaught`: keep (LMB) or throw back (RMB) |

4. The session ends when the fish is kept or thrown, the line snaps, the rod is holstered, or the player dies.

## Reeling mechanics

While a fish is hooked (state 7) it switches between two moods. Every 1–5 seconds the script rolls `Config.StruggleChance`:

- **Relaxed:** holding the reel key (`INPUT_GAME_MENU_OPTION`, SPACE) makes the fish swim to the player. The script gives the fish a `TaskGoToEntity` lasting `Config.Difficulty` ms at speed `Config.ReelInSpeed`, and re-issues it at 80% of that time for as long as the key is held. Letting go stops the pull when the current task runs out.
- **Struggling:** the fish flees and splashes. Holding the reel key raises the pull force and the line tension. If the force reaches 1.0 the fish escapes; if tension reaches 100% the line snaps (`Config.LineSnap`). Let go until the fish relaxes.

Other details:

- The reel key is read with both `IsControlPressed` and `IsDisabledControlPressed`, and the script tracks the key state itself, so holding the key through a struggle carries on reeling when the fish relaxes.
- Rod weight (`f_18`) is 4 while the key is held and 2 otherwise.
- The client requests network control of the hooked fish each tick until it has it. Tasks do not apply to an entity owned by another client.
- The fish is landed when the line distance (`f_2`) drops below 4.0.

## Minigame struct

`client_js.js` exposes the task struct as `f_0` … `f_27`. Fields used:

| Field | Type | Use |
|---|---|---|
| `f_0` | int | minigame state |
| `f_1` | float | cast distance |
| `f_2` | float | line distance |
| `f_5`, `f_6` | int | sub-state / transition request |
| `f_7` | int | hooked fish entity |
| `f_8` | float | fish weight (raw) |
| `f_11`, `f_12` | int | bobber / hook entity |
| `f_13`, `f_21` | float | fish pull force |
| `f_14` | float | line slack |
| `f_18` | int | rod weight |
| `f_22` | float | horizontal rod movement |

## Exports

Client only.

| Export | Parameters | Returns |
|---|---|---|
| `GET_TASK_FISHING_DATA_EXTRA` | none | `{ hasMinigameOn, intArray, floatArray }` (field `n` is at index `n * 2`) |
| `SET_TASK_FISHING_DATA_EXTRA` | `struct` table with keys `f_0` … `f_27` | nothing |

## Events

| Event | Side | Arguments | Notes |
|---|---|---|---|
| `rsg-fishing:client:usebait` | client | `bait` (item name) | Sent by the server when a bait item is used |
| `rsg-fishing:server:removeBaitItem` | server | `item` | Removes one bait and opens a 5 minute catch window tied to that bait |
| `rsg-fishing:server:catchFish` | server | `fishModel` (hash), `weight` (raw), `region`, `spot` | Stores the fish. `weight = 0` means a ground pickup. `region` is the region id under the hook and `spot` the legendary-spot zone name, both from the client |

| Callback | Side | Returns |
|---|---|---|
| `rsg-fishing:server:getJournal` | server | `{ species, found, total, records, anglers }` for the calling player (read only, 1 s throttle), or `nil` |

| Local event | Side | Arguments |
|---|---|---|
| `rsg-fishing:server:newRecord` | server | `src, family, kg, previousHolderName` (fired when a record is beaten) |

## Data formats

- `Config.Baits`: list of bait item names. Each is registered as a usable item.
- `Config.BaitsPerFish[bait]`: list of fish models the bait attracts.
- `Config.fishData[model]`: `{ display name, weight band, species family }` (`small`, `medium` or `large`, see `Config.WeightBands`). The item given is the model name in lower case, with `info.weight` set to the weight in KG (two decimals).
- Displayed weight = raw weight × `Config.FishWeightMultiplier`.

## Security model

The server checks, for every catch:

- the player exists and the model is in `Config.fishData`;
- the weight is a number, clamped to the weight band of that fish and to `Config.MaxRawFishWeight`;
- a minigame catch has a bait spent in the last 5 minutes, at least `Config.MinCatchTime` ago, and each bait pays for one catch;
- with `Config.Regions.Enabled`, the fish can live in the reported region and, for the legendary salmon, the reported spot is a legendary spot (and within `radius` of its `coords` when set). The region and spot come from the client, so this is a soft check; only the coords check is verified by the server;
- with `Config.EnforceBaitList`, the fish is one the bait attracts in `Config.BaitsPerFish`;
- `Config.CatchCooldown` has passed since the last accepted catch;
- `CanAddItem` passes before the fish is added.

Bait removal only accepts names in `Config.Baits`. Ground pickups (`weight = 0`) need no bait and cannot be verified by the server, so they are capped by `Config.GroundPickupLimit`; set `Config.GroundPickup = false` to refuse them. The server does not check that the player is near water.

## Database

Two tables, created on start when `Config.AutoDatabase = true` (identical to `install.sql`; set it to `false` to import the file manually).

| Table | Columns | Purpose |
|---|---|---|
| `rsg_fishing_journal` | `citizenid, species, name, caught, best_weight, first_caught, last_caught` (primary key `citizenid, species`) | one row per character and species family |
| `rsg_fishing_records` | `species, citizenid, name, weight, caught_at` (primary key `species`) | the server record per species family |

## Journal, records and regions

- **Regions:** the client reads the game's map zones under the hook (state, plus lake / river / swamp / ocean / creek / pond for legendary spots) once per second. A fish whose family is not in the state's `Config.Regions.Pools` entry is ignored (it neither bites nor is lured). A state with no entry has no limit.
- **Bite chance:** `Config.BiteChance` × time factor × weather factor × (1 + `bite_chance` perk / 100), kept between `MinChance` and `MaxChance`. The HUD shows Poor below `PoorBelow`, Good from `GoodFrom`, otherwise Fair. Weather comes from `exports['rsg-weather']:getWeather()`; with rsg-weather stopped the weather factor is 1.
- **Perks:** `bite_chance`, `line_strength` (scales the tension gain, never below 30%) and `rare_chance` (chance to roll the heavier half of the weight band) are read from rsg-skills on the client. They shape the minigame only; the server still clamps the weight to the fish's band.
- **Journal:** each fished fish (not ground pickups) is added to the character's row for its family. The first catch of a family logs it in the journal and applies `Config.Reputation.NewSpecies`; completing every family applies `Config.Reputation.Complete`.
- **Records:** the server keeps the heaviest fish per family. The first fish of a family sets the record quietly; beating it announces it (`Config.Records.Announce`), pays `Config.Records.Reward` cash, applies `Config.Reputation.Record` and fires `rsg-fishing:server:newRecord`.
- **Top anglers:** the `Config.Records.TopCount` characters with the most fish (cached for 30 seconds).
- **Opening the journal:** `Config.Journal.Command` and an optional rebindable key (`Config.Journal.Key`, through `RSGCore.Functions.RegisterKey`). Push-to-talk stays usable while it is open.

## How-tos

- **Make fish come in faster or slower:** change `Config.ReelInSpeed`.
- **Make fish struggle more:** raise `Config.StruggleChance`.
- **Make lines snap sooner:** raise `Config.LineSnap.Gain` or lower `Recover`.
- **Change the reel key:** change `INPUT_REEL` at the top of `client/client.lua`, then `Config.ControlKeys.ReelIn` (HUD label) and `Config.ControlInputs.ReelIn` (HUD highlight).
- **Add a bait:** add the item to rsg-core shared items, then to `Config.Baits` and `Config.BaitsPerFish`.

## Troubleshooting

| Problem | Check |
|---|---|
| SPACE does not reel the fish in | Hold the key, don't tap it. The fish only comes in while relaxed; during a struggle holding the key just adds tension. If the "Reel In" HUD row never lights up, SPACE is bound to something else: change `INPUT_REEL` |
| Fish escapes while reeling | You held the reel key through a struggle. Let go when the fish splashes |
| Line snaps too easily | Lower `Config.LineSnap.Gain` |
| Fish never bite | The bait must be in `Config.BaitsPerFish` for fish in that water, and a fish has to be within 1.6 of the hook |
| Fish not added to inventory | Missing fish item in shared items, full inventory, or more than 5 minutes since the bait was used |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, CatchXP }`. On a server-validated catch (`rsg-fishing:server:catchFish`, bait spent, weight above 0) the server calls `exports['rsg-skills']:AddXP(src, Config.Skills.Skill, Config.Skills.CatchXP, 'fishing catch')` when `GetResourceState('rsg-skills') == 'started'`. The XP amount comes from config, never from the client. The `fishing` skill and its perks (`rare_chance`, `sell_bonus`) are defined in rsg-skills; the `sell_bonus` perk is applied by rsg-fishmonger.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-fishing 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `oxmysql`. Optional: `rsg-weather`, `rsg-skills`, `rsg-reputation`, `rsg-log`.

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Difficulty` | `500` | ms each reel pull lasts; re-issued while the reel key is held (lower = fish stops sooner when you let go) |
| `Config.ReelInSpeed` | `1.5` | how fast a hooked fish swims towards you while reeling (higher = quicker catch) |
| `Config.ReelSpeed` | `0.025` | how fast the hook reels in towards the player |
| `Config.Debug` | `false` |  |
| `Config.StruggleChance` | `0.3` | chance (0.0-1.0) per tick that a hooked fish struggles |
| `Config.FishWeightMultiplier` | `54.25` | converts internal game weight units into displayed KG |
| `Config.CatchCooldown` | `3000` | ms a player must wait between accepted fish catches (anti-spam/anti-exploit) |
| `Config.MaxRawFishWeight` | `0.15` | sanity cap on the raw (pre-multiplier) weight value accepted from clients |
| `Config.GroundPickup` | `true` | picking a fish up off the ground stores it (no bait needed, weight 0). Set false to close this off |
| `Config.GroundPickupLimit` | `{ Max = 10, Window = 3600 }` | max ground pickups per player per Window seconds |
| `Config.MinCatchTime` | `8000` | ms between bait on the rod and an accepted catch |
| `Config.EnforceBaitList` | `true` | a fish only bites, and is only accepted, when listed for the bait in `Config.BaitsPerFish` |
| `Config.BiteChance` | `0.3` | chance (0.0-1.0) per second that a fish next to the hook bites |
| `Config.WeightBands` | `table` | `small` / `medium` / `large` raw weight range and fish size |
| `Config.WeightFactor` | `0.25` | factor applied to the rolled band weight |
| `Config.Log` | `true` | send catches to rsg-log ('fishing' channel) |
| `Config.LineSnap` | `table` | line tension / snapping: reeling while a fish struggles strains the line; at 100% it snaps (fish and bait lost |
| `Config.Enabled` | `true` |  |
| `Config.Gain` | `0.004` |  |
| `Config.Recover` | `0.006` |  |
| `Config.Sounds` | `table` | fishing sounds (soundset and names from RDR3 decompiled fishing_core.c, build 1436). Set a name to '' to mute  |
| `Config.Soundset` | `'MGFSH_Sounds'` |  |
| `Config.Names` | `table` |  |
| `Config.Rumble` | `table` | controller rumble { duration ms, frequency 0-255 } (SET_CONTROL_SHAKE) |
| `Config.Bite` | `{ 250, 180 }` |  |
| `Config.Struggle` | `{ 120, 90 }` |  |
| `Config.Snap` | `{ 500, 255 }` |  |
| `Config.Caught` | `{ 200, 120 }` |  |
| `Config.Music` | `table` | fishing music (music events from fishing_core.c) |
| `Config.Start` | `'BOB_FISHING_START'` |  |
| `Config.Stop` | `'BOB_FISHING_STOP'` |  |
| `Config.ControlKeys` | `table` | key labels shown in the top-left controls HUD (display only) |
| `Config.UseBait` | `'TAB'` |  |
| `Config.Prepare` | `'RMB'` |  |
| `Config.Cast` | `'LMB'` |  |
| `Config.Hook` | `'LMB'` |  |
| `Config.ResetCast` | `'SHIFT'` |  |
| `Config.ReelLure` | `'CTRL'` |  |
| `Config.ReelIn` | `'SPACE'` |  |
| `Config.KeepFish` | `'LMB'` |  |
| `Config.ThrowFish` | `'RMB'` |  |
| `Config.ControlInputs` | `table` | controls watched for the live "pressed" highlight in the HUD (hash or "INPUT_NAME") |
| `Config.BobberMarker` | `table` | bobber visibility (helps players see where their float is) |
| `Config.ScreenIcon` | `true` |  |
| `Config.ScreenIconSize` | `46` |  |
| `Config.Baits` | `table` | fishing baits |
| `Config.BaitsPerFish` | `table` | bait to catch fish |
| `Config.fishData` | `table` | fish data |
| `Config.Skills` | `table` | rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started. |
| `Config.Skill` | `'fishing'` |  |
| `Config.CatchXP` | `10` |  |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-fishing:client:usebait` | client | `bait` | `client/client.lua` |
| `rsg-fishing:server:removeBaitItem` | server | `item` | `server/server.lua` |
| `rsg-fishing:server:catchFish` | server | `fishModel, weight, region, spot` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-fishing:server:removeBaitItem', item)
-- from a server script
TriggerClientEvent('rsg-fishing:client:usebait', source, bait)
```

### Locales

Language files in `locales/`: `cs`, `de`, `el`, `en`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
