# rsg-fortuneteller

Coin-operated fortune teller machines for **RSG-Core** (RedM). Pay at the machine, hand over your cash, and the machine reads you a random fortune using RDR2's own `FTELL` voice lines. Players nearby hear the reading too.

## Features
- Configured machines spawn and stream in/out by distance. Machines already on the map can be used too (optional).
- 72 game fortune lines, plus optional intro lines and your own `.ogg` files.
- Players are only charged after the voice and animations have loaded. If anything fails, they keep their money.
- Payment is checked on the server: the machine key is worked out on the server, distance is checked when the reading is requested and again before charging, and there is a per-player anti-spam cooldown.
- Per-machine busy lock and an optional cooldown between readings.
- Hand-over animation with a cash pouch prop, a glow on the machine and the machine's own prop animation.
- Interaction with **ox_target**, falling back to a native prompt (G).
- Notifications through ox_lib. All player-facing text is in ox_lib locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target) (optional; a native prompt is used without it)

## Installation
1. Drop `rsg-fortuneteller` into your resources folder.
2. Add `ensure rsg-fortuneteller` to your `server.cfg` after `ox_lib`, `rsg-core` and `ox_target`.
3. Adjust `shared/config.lua` and restart.

No SQL is required.

### Language
The language follows ox_lib's locale setting, e.g. `setr ox:locale de` in `server.cfg`. Locale files are in `locales/`; copy `en.json` to add another language.

## Configuration
| Option | Description |
|---|---|
| `Config.Price` | Cash cost per reading (`0` = free) |
| `Config.CooldownSeconds` | Per-machine cooldown after a reading |
| `Config.RequestCooldown` | Per-player anti-spam delay in seconds |
| `Config.Interaction` | `'auto'`, `'target'` or `'prompt'` |
| `Config.HearingDistance` | How far away other players hear the reading |
| `Config.UseConfiguredMachines` | Spawn/use the machines in `Config.Machines` |
| `Config.AutoDetectExistingProps` | Allow machines already placed on the map |
| `Config.Handover` | Hand-over animation and pouch prop |
| `Config.Light` | Glow drawn on the machine during a reading |
| `Config.Voices` | Ambient voice names tried for the `FTELL` bank |
| `Config.IntroLines` | Lines always played before the random fortune |
| `Config.CustomLines` | Your own `.ogg` files from `ui/sounds/` |

### Adding a machine
Stand where the machine should go, run `/fortunecoords` and copy the `vector4` from F8 into `Config.Machines`:
```lua
{ id = 'machine_4', enabled = true, spawn = true, coords = vector4(x, y, z, heading) },
```
Set `spawn = false` if the map already has a machine at that spot.

### Custom audio
Put `.ogg` files in `ui/sounds/`, add them to `Config.CustomLines` with `enabled = true` and set `duration` to the clip length in seconds.

## Commands
| Command | Description |
|---|---|
| `/fortunecoords` | Prints your position as a `vector4` in F8 |
| `/fortunetest <id>` | Plays one line from `shared/lines.lua` (only when `Config.Debug = true`) |
| `/fortunespeech` | Plays a known ambient line to test the speech native (only when `Config.Debug = true`) |

## Notes
- The fortune voice plays from each listener's own ped with `SET_AMBIENT_VOICE_NAME`. That changes the ped's ambient voice until something else sets it again.
