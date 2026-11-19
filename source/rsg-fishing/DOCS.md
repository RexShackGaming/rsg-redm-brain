# rsg-fishing — Technical Docs

Version 3.1.0. For installation and player instructions see [README.md](README.md).

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

## Files

```
client/client.lua     Session loop, minigame states, reeling, tension, HUD and bobber updates
client/client_js.js   Reads/writes the game's fishing task struct (needs JS for the data buffer)
server/server.lua     Usable bait items, catch validation, inventory, logging
server/versionchecker.lua  Version check on start
html/index.html       Controls HUD, tension bar and bobber indicator (NUI, no focus taken)
locales/*.json        Translations (loaded by rsg-core)
shared/config.lua     Settings, baits, fish data
```

## How a fishing session runs

1. The player uses a bait item. The server item callback triggers `rsg-fishing:client:usebait`.
2. The client checks the rod is in hand, asks the server to remove the bait (`rsg-fishing:server:removeBaitItem`) and starts the session thread.
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
| `rsg-fishing:server:removeBaitItem` | server | `item` | Removes one bait and opens a 5 minute catch window |
| `rsg-fishing:server:catchFish` | server | `fishModel` (hash), `weight` (raw) | Stores the fish. `weight = 0` means a ground pickup |

There are no callbacks.

## Data formats

- `Config.Baits`: list of bait item names. Each is registered as a usable item.
- `Config.BaitsPerFish[bait]`: list of fish models the bait attracts.
- `Config.fishData[model]`: `[1]` is the display name. The item given is the model name in lower case, with `info.weight` set to the weight in KG (two decimals).
- Displayed weight = raw weight × `Config.FishWeightMultiplier`.

## Security model

The server checks, for every catch:

- the player exists and the model is in `Config.fishData`;
- the weight is a number and is capped at `Config.MaxRawFishWeight`;
- a minigame catch has a bait spent in the last 5 minutes, and each bait pays for one catch;
- `Config.CatchCooldown` has passed since the last accepted catch;
- `CanAddItem` passes before the fish is added.

Bait removal only accepts names in `Config.Baits`. Ground pickups (`weight = 0`) need no bait; set `Config.GroundPickup = false` to refuse them. The server does not check that the player is near water.

## Database

None. The script stores nothing of its own.

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

Generated from the source of **rsg-fishing 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`

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
| `Config.A_C_FISHBLUEGIL_01_MS` | `{ "Blue Gil (Medium)", "PROVISION_FISH_BLUEGILL", "PROVISION_BLUEGILL_` |  |
| `Config.A_C_FISHBLUEGIL_01_SM` | `{ "Blue Gil (Small)", "PROVISION_FISH_BLUEGILL", "PROVISION_BLUEGILL_D` |  |
| `Config.A_C_FISHBULLHEADCAT_01_MS` | `{ "Bullhead Cat (Medium)", "PROVISION_FISH_BULLHEAD_CATFISH", "PROVISI` |  |
| `Config.A_C_FISHBULLHEADCAT_01_SM` | `{ "Bullhead Cat (Small)", "PROVISION_FISH_BULLHEAD_CATFISH", "PROVISIO` |  |
| `Config.A_C_FISHCHAINPICKEREL_01_MS` | `{ "Chain Pickerel (Medium)", "PROVISION_FISH_CHAIN_PICKEREL", "PROVISI` |  |
| `Config.A_C_FISHCHAINPICKEREL_01_SM` | `{ "Chain Pickerel (Small)", "PROVISION_FISH_CHAIN_PICKEREL", "PROVISIO` |  |
| `Config.A_C_FISHCHANNELCATFISH_01_LG` | `{ "Channel Catfish (Large)", "PROVISION_FISH_CHANNEL_CATFISH", "PROVIS` |  |
| `Config.A_C_FISHCHANNELCATFISH_01_XL` | `{ "Channel Catfish (Extra Large)", "PROVISION_FISH_CHANNEL_CATFISH", "` |  |
| `Config.A_C_FISHLAKESTURGEON_01_LG` | `{ "Lake Sturgeon (Large)", "PROVISION_FISH_LAKE_STURGEON", "PROVISION_` |  |
| `Config.A_C_FISHLARGEMOUTHBASS_01_LG` | `{ "Large Mouth Bass (Large)", "PROVISION_FISH_LARGEMOUTH_BASS", "PROVI` |  |
| `Config.A_C_FISHLARGEMOUTHBASS_01_MS` | `{ "Large Mouth Bass (Medium)", "PROVISION_FISH_LARGEMOUTH_BASS", "PROV` |  |
| `Config.A_C_FISHLONGNOSEGAR_01_LG` | `{ "Long Nose Gar (Large)", "PROVISION_FISH_LONGNOSE_GAR", "PROVISION_L` |  |
| `Config.A_C_FISHMUSKIE_01_LG` | `{ "Muskie (Large)", "PROVISION_FISH_MUSKIE", "PROVISION_MUSKIE_DESC" }` |  |
| `Config.A_C_FISHNORTHERNPIKE_01_LG` | `{ "Northern Pike (Large)", "PROVISION_FISH_NORTHERN_PIKE", "PROVISION_` |  |
| `Config.A_C_FISHPERCH_01_MS` | `{ "Perch (Medium)", "PROVISION_FISH_PERCH", "PROVISION_PERCH_DESC" }` |  |
| `Config.A_C_FISHPERCH_01_SM` | `{ "Perch (Small)", "PROVISION_FISH_PERCH", "PROVISION_PERCH_DESC" }` |  |
| `Config.A_C_FISHRAINBOWTROUT_01_LG` | `{ "Rainbow Trout (Large)", "PROVISION_FISH_STEELHEAD_TROUT", "PROVISIO` |  |
| `Config.A_C_FISHRAINBOWTROUT_01_MS` | `{ "Rainbow Trout (Medium)", "PROVISION_FISH_STEELHEAD_TROUT", "PROVISI` |  |
| `Config.A_C_FISHREDFINPICKEREL_01_MS` | `{ "Red Fin Pickerel (Medium)", "PROVISION_FISH_REDFIN_PICKEREL", "PROV` |  |
| `Config.A_C_FISHREDFINPICKEREL_01_SM` | `{ "Red Fin Pickerel (Small)", "PROVISION_FISH_REDFIN_PICKEREL", "PROVI` |  |
| `Config.A_C_FISHROCKBASS_01_MS` | `{ "Rock Bass (Medium)", "PROVISION_FISH_ROCK_BASS", "PROVISION_ROCKBAS` |  |
| `Config.A_C_FISHROCKBASS_01_SM` | `{ "Rock Bass (Small)", "PROVISION_FISH_ROCK_BASS", "PROVISION_ROCKBASS` |  |
| `Config.A_C_FISHSALMONSOCKEYE_01_LG` | `{ "Salmon Sockeye (Large)", "PROVISION_FISH_SOCKEYE_SALMON_LEGENDARY",` |  |
| `Config.A_C_FISHSALMONSOCKEYE_01_ML` | `{ "Salmon Sockeye (Medium-Large)", "PROVISION_FISH_SOCKEYE_SALMON", "P` |  |
| `Config.A_C_FISHSALMONSOCKEYE_01_MS` | `{ "Salmon Sockeye (Medium)", "PROVISION_FISH_SOCKEYE_SALMON", "PROVISI` |  |
| `Config.A_C_FISHSMALLMOUTHBASS_01_LG` | `{ "Small Mouth Bass (Large)", "PROVISION_FISH_SMALLMOUTH_BASS", "PROVI` |  |
| `Config.A_C_FISHSMALLMOUTHBASS_01_MS` | `{ "Small Mouth Bass (Medium)", "PROVISION_FISH_SMALLMOUTH_BASS", "PROV` |  |
| `Config.Skills` | `table` | rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started. |
| `Config.Skill` | `'fishing'` |  |
| `Config.CatchXP` | `10` |  |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-fishing:client:usebait` | client | `bait` | `client/client.lua` |
| `rsg-fishing:server:removeBaitItem` | server | `item` | `server/server.lua` |
| `rsg-fishing:server:catchFish` | server | `fishModel, weight` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-fishing:server:removeBaitItem', item)
-- from a server script
TriggerClientEvent('rsg-fishing:client:usebait', source, bait)
```

### Locales

Language files in `locales/`: `cs`, `de`, `el`, `en`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
