# rsg-treasure – Developer Docs

## Flow
1. Player uses `Config.MapItem` → server picks a free location, stores `hunts[citizenid] = { idx, centre }`, sends `rsg-treasure:client:startHunt(loc, centre)`.
2. Client draws the search circle and, while the detector is held inside it, drives the detector blackboard value, the NUI signal meter and the bleep.
3. At `Config.PinpointDistance` the [J] dig prompt appears (within `Config.DigDistance`).
4. Pressing [J] → callback `rsg-treasure:server:digStart` (checks hunt, distance, map, detector, tool; starts the server dig timer). Only on `true` does the anim scene play.
5. After the anim → callback `rsg-treasure:server:dig` pays out, then `rsg-treasure:client:endHunt`.

## Server security
- All rewards are rolled and given server-side; the client sends no arguments.
- Payout needs a `digStart` at least `Config.DigTime - 1500` ms earlier, a server-side distance check, and a per-player `Config.Cooldown`.
- Loot is rolled and `CanAddItem`-checked **before** the map is removed. If any item won't fit, nothing is taken.
- The map is removed before cash/items are given, so a payout can't be claimed twice.
- Known limitation: the client receives the exact dig coords (the detector needs them for distance). Cheaters could read them, but they still need the map, the detector, the full dig time and to be in range.

## Events / callbacks
| Name | Side | Purpose |
|---|---|---|
| `rsg-treasure:client:startHunt` | client | (loc, centre) start/redisplay a hunt |
| `rsg-treasure:client:endHunt` | client | clean up blips, chest, NUI |
| `rsg-treasure:server:resume` | server | resend the active hunt (on player loaded / resource start) |
| `rsg-treasure:server:digStart` | callback | pre-dig validation + timer → bool |
| `rsg-treasure:server:dig` | callback | payout → bool |

## Exports
- `exports['rsg-treasure']:SendLog(channel, title, description, color, src?, fields?)` (server)

## Config
See `shared/config.lua` (gameplay) and `server/sv_config.lua` (webhooks, server only).

## Changelog
### 3.1.0
- Removed ox_lib: rsg-core locales, notify and callbacks.
- Dig is validated before the animation (no more full dig then refusal).
- A full inventory no longer destroys loot: nothing is consumed and the player can retry.
- Hunts resume after relog / resource restart.
- Detector native only called when the value changes.
- Removed unused locale keys (`log_inv_full`, `log_loot_lost`, `log_no`) and the inventory-full log field.
