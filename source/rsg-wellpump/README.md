# rsg-wellpump

Well pumps for the **RSG Framework** (rsg-core 3). Players place a pump, fill empty buckets with water and pack the pump up again. The same resource owns the **water bucket**: a filled `fullbucket` carries a number of uses, and other scripts (farming, ranch, gangs) call rsg-wellpump instead of carrying their own bucket code.

Full developer reference: [DOCS.md](DOCS.md)

**Version:** 1.1.0

---

## Dependencies

- rsg-core
- rsg-inventory
- rsg-target
- rsg-gizmo
- oxmysql

No ox_lib and no ox_target are needed.

## Features

- Place a pump anywhere with the standard rsg-gizmo placement tool; it is saved to the database and survives restarts.
- **Fill Bucket**: turns an empty `bucket` into a `fullbucket` with full uses.
- **Drink Water**: restores thirst. The server picks the amount and enforces a cooldown, and the option is hidden when you are not thirsty.
- **Pack Up Well Pump**: gives the item back (owner only by default).
- Limits per player, minimum spacing between pumps, props streamed by distance.
- Limited-use buckets: each use takes one charge and the last one gives back an empty bucket. The uses left show in the item description.
- Exports for other resources: fill a bucket, use a bucket, read its uses (see [DOCS.md](DOCS.md)).
- Imports pumps placed by the old rsg-farming and rsg-ranch pumps automatically, once.
- Fully localised in 11 languages (en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru).
- Server-side checks on everything: distance, ownership, inventory space and action timers that stop players skipping animations. Citizenids are never sent to clients.

## Installation

1. Put the `rsg-wellpump` folder in your resources folder.
2. Add it to `server.cfg` **before** the scripts that use it (rsg-farming, rsg-ranch, rsg-gangs):
   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-target
   ensure rsg-gizmo
   ensure rsg-wellpump
   ensure rsg-farming
   ensure rsg-ranch
   ensure rsg-gangs
   ```
3. **Database:** nothing to import. The tables `rsg_wellpumps` and `rsg_wellpump_migrations` are created automatically on first start. To install manually, set `Config.AutoDatabase = false` and import `install.sql`.
4. **Items:** make sure these exist in `rsg-core/shared/items.lua` (they do on a default RSG install): `tool_wellpump`, `bucket`, `fullbucket`. `fullbucket` must be `unique = true`, because each bucket stores its own uses left. The server prints a warning on start for any that are missing.
5. **Upgrading from the old pumps:** on first start the pumps in `rsg_farming_wellpumps` and `rsg_ranch_wellpumps` are copied into `rsg_wellpumps` (once per source; the old tables are left untouched). Players can keep using `ranch_wellpump` items; they place a pump through rsg-wellpump.
6. Restart the server.

## How to use

1. Use the `tool_wellpump` item and place the pump with the gizmo (left mouse / Enter to place, right mouse / Backspace to cancel).
2. Target the pump and choose **Fill Bucket** while carrying an empty `bucket`.
3. Choose **Drink Water** to drink straight from the pump (thirst goes up; there is a cooldown between drinks).
4. Choose **Pack Up Well Pump** to take it back.

## Configuration (`shared/config.lua`)

| Option | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Print debug lines to the server console |
| `Config.AutoDatabase` | `true` | Create the tables on start; `false` = import `install.sql` manually |
| `Config.Item` | `tool_wellpump` | Item that places a pump, and what packing gives back |
| `Config.ExtraItems` | `{ 'ranch_wellpump' }` | More items that also place a pump |
| `Config.EmptyItem` | `bucket` | Needed to fill; handed back when a bucket runs out |
| `Config.FullItem` | `fullbucket` | Given after filling |
| `Config.BucketUses` | `5` | Uses a filled bucket starts with |
| `Config.Prop` | `p_wellpumpnbx01x` | Pump model |
| `Config.FillTime` / `PackTime` | `6000` / `4000` | Durations in ms (enforced by the server) |
| `Config.FillScenario` / `PackScenario` | scenarios | Animations |
| `Config.MaxPerPlayer` | `2` | Pumps per character |
| `Config.MinDistance` | `2.0` | Minimum distance between pumps (m) |
| `Config.InteractDist` | `2.0` | Target distance (m) |
| `Config.PlaceMaxDistance` | `6.0` | How far from the player the gizmo can place |
| `Config.RenderDistance` | `60.0` | Prop spawn / despawn distance |
| `Config.OwnerOnlyPackup` | `true` | Only the placer can pack a pump up |
| `Config.TargetIcons` | droplet / box / glass | Target icons (`fill`, `pack`, `drink`) |
| `Config.Sprinkler` | enabled | `Enabled`, `Capacity` (400 water units per pump), `RefillPerMinute` (40), `MaxLinkDistance` (60.0). Reservoir for sprinklers and irrigation (in memory, refills over time) |
| `Config.Drink` | enabled | `enabled`, `time` (10000 ms), `cooldown` (20000 ms), `thirst` (`min` 40, `max` 70), `notThirstyAbove` (95), `scenarioMale`, `scenarioFemale` |
| `Config.Migration` | enabled | One-time import from old pump tables |

## For developers

Water supply (v3.1.0), for sprinklers and irrigation: `GetPump(id)`, `GetNearestPump(coords, maxDistance?)`, `GetPumpWater(id)` and `DrawWater(id, amount)` (server). See DOCS.md section 4.

```lua
-- server: fill a bucket (you check access and distance first)
local ok, msg = exports['rsg-wellpump']:FillBucket(src)

-- server: use one charge of the player's full bucket
local ok, usesLeft = exports['rsg-wellpump']:UseBucket(src)

-- server: let a player drink (cooldown and amount are handled for you)
local ok, msg, amount = exports['rsg-wellpump']:Drink(src)
```

See [DOCS.md](DOCS.md) for every export, including the take / commit / refund version used when your own work might fail.

## Locales

`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale de`.

Support: https://rexshack.tebex.store
