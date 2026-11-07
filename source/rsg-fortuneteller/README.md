# rsg-fortuneteller

Coin-operated fortune teller machines for **RSG Framework** (RedM). Pay at the machine, hand over cash, and the machine reads a random fortune using RDR2 `FTELL` voice lines. Nearby players hear the reading too.

## Features
- Configured machines stream in/out by distance; map-placed machines can also be used
- 72 game fortune lines, optional intro lines, and custom `.ogg` files
- Charged only after voice/animations load — failures never take money
- Server-authoritative: machine key, distance, price, cooldowns
- Per-machine busy lock and optional post-reading cooldown
- Hand-over animation with pouch prop, machine glow, prop animation
- Interaction via **rsg-target** (falls back to native G prompt)
- Notifications via **rsg-core**; locales via rsg-core shared locale loader

## Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-target](https://github.com/Rexshack-RedM/rsg-target)

## Installation
1. Place `rsg-fortuneteller` in your resources folder.
2. `ensure rsg-fortuneteller` in `server.cfg` after `rsg-core` and `rsg-target`.
3. Adjust `shared/config.lua` and restart.

No SQL required.

### Language
Uses `setr rsg:locale "en"` (falls back to `ox:locale`, then `en`). Locale files live in `locales/`.

## Configuration (main options)
| Option | Description |
|---|---|
| `Config.Price` | Cash per reading (`0` = free) |
| `Config.CooldownSeconds` | Per-machine cooldown after a reading |
| `Config.RequestCooldown` | Per-player anti-spam delay (seconds) |
| `Config.Interaction` | `'auto'`, `'target'` or `'prompt'` |
| `Config.HearingDistance` | How far others hear the reading |
| `Config.UseConfiguredMachines` | Use/spawn `Config.Machines` |
| `Config.AutoDetectExistingProps` | Allow map-placed machines |
| `Config.Handover` | Hand-over animation / pouch prop |

## Commands
| Command | Description |
|---|---|
| `/fortunecoords` | Print your `vector4` for `Config.Machines` (F8) |
| `/fortunetest` | Debug only — play one line |
| `/fortunespeech` | Debug only — speech tests |

## Security notes
- Price comes from config only; client never sets the amount
- Machine key is resolved on the server from configured ids or rounded world coords
- Distance checked on request and again before charging
- `RemoveMoney` result is verified; charge happens only after client reports ready

## Support
RexShack Gaming / RSG Framework
