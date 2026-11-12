# rsg-fishing — Technical Docs

Version 3.0.4. For installation and player instructions see [README.md](README.md).

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

Support: https://buymeacoffee.com/rexshack
