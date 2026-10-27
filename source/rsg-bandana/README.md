# rsg-bandana

Raise and lower your bandana on RSG Framework (RedM). Works for male and female characters, on foot or mounted, using the same wearable-state system as RDR2 story mode.

## Features
- `/bandana` pulls the bandana over your face or drops it back round your neck
- RDR2 hand-to-face animation (right hand on foot, left hand when mounted)
- Optional useable inventory item (`Config.UseItem`)
- Blocked while dead, ragdolled, swimming, hogtied, cuffed or in a vehicle; re-checked after the animation so it can't finish if you're downed mid-way
- Only works once the character is fully logged in
- Per-toggle cooldown
- Lowers the bandana cleanly if the resource is restarted

## For other scripts
- Export (client): `exports['rsg-bandana']:IsWearingBandana()` - reads the ped's real clothing state, so it stays correct after wardrobe changes. Use this for anything that matters (witness / lawman checks).
- Statebag: `Player(src).state.bandana` (server) / `LocalPlayer.state.bandana` (client). Convenient for display, but it is set by the client, so don't trust it for anything a cheater would want to spoof.

## Requirements
- rsg-core, ox_lib
- The player must be wearing bandana-type neckwear (e.g. from rsg-wardrobe)

## Install
1. Drop `rsg-bandana` into your resources and `ensure rsg-bandana` after rsg-core and ox_lib.
2. (Optional) set `Config.UseItem = true` and add a `bandana` item to rsg-core items.

## Changelog
- **3.0.1** - blocked toggling before login (statebag `isLoggedIn` nil was treated as logged in), animation is cancelled if the toggle is aborted, small allocation clean-up in the neckwear scan.

## Languages
en, de, el, es, fr, ja, nl, pl, pt-br, ro. ox_lib picks the language from the `ox:locale` convar, e.g. `setr ox:locale de` in server.cfg.

## Config
| Option | Default | Description |
|---|---|---|
| `Config.Command` | `bandana` | Chat command |
| `Config.UseItem` / `Config.ItemName` | `false` / `bandana` | Also toggle from an inventory item |
| `Config.Cooldown` | `2500` | ms between toggles |
| `Config.PlayAnim` / `Config.AnimTime` | `true` / `1200` | Animation and ms before the state swaps |

Wearable state, category and animation hashes come from the RDR3 decompiled scripts and femga/rdr3_discoveries; don't change them.

Support: https://buymeacoffee.com/rexshack
