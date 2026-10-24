# rsg-targetpractise

Placeable archery and throwing-knife practice targets for **RSG-Core** on RedM. Players place a target from their inventory, shoot it with a bow or throwing knives, and compete on a live session leaderboard. All placement, pickup and scoring is checked on the server.

## Features

- **Placeable targets:** use the `target` item to place a frame and face anywhere on the ground. You get a ghost preview you can rotate and raise or lower.
- **Placement panel:** a NUI panel in the top left shows the controls with live key presses, heading, height, a ground check and a countdown.
- **Ring scoring:** bullseye, 4 rings and a distance bonus for long shots. A simple "hit" mode (1 point per hit) is also available.
- **Bows and throwing knives:** arrows and knives are tracked separately for stats and records.
- **Bullseye announcement:** a large on-screen banner showing the weapon used and the distance.
- **Live leaderboard:** shows points, hits, bullseyes, arrows, knives, best hit, average and online status.
- **Range records:** the furthest arrow and furthest knife hit of the session.
- **Personal hit map:** your last 80 hits plotted on a target face.
- **Persistent targets:** saved to `data/targets.json` and restored on restart.
- **Ownership:** only the owner or an admin can pack a target up. Packing it up returns the item.
- **Admin tools:** item-free admin targets, calibration debug rings and a diagnostics report.
- **Security:** item add/remove happens only on the server, with checks on owner, distance, routing bucket and spam rate. Every shot has to match one fired from a weapon the player owns, and points are calculated by the server.
- **Fully localised (ox_lib):** en, de, el, es, fr, ja, nl, pl, pt-br, ro.

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- OneSync enabled

## Installation

1. Drop the `rsg-targetpractise` folder into your resources directory.
2. Add the item to `rsg-core/shared/items.lua` (also in `installation/items.lua`):

   ```lua
   target = { name = 'target', label = 'Target Practice', weight = 100, type = 'item', image = 'target.png', unique = false, useable = true, shouldClose = true, description = 'A placeable target and frame for bow and throwing-knife practice.', category = 'general', level = 0 },
   ```

3. Copy `installation/target.png` to `rsg-inventory/html/images/`.
4. Add it to `server.cfg` after its dependencies:

   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-inventory
   ensure ox_target
   ensure rsg-targetpractise
   ```

5. Optional: pick a language with `setr ox:locale en`.
6. Make sure the server can write to `data/targets.json`, then restart the server.

When the resource starts, F8 should show `[rsg-targetpractise] DETECTOR READY code=3.0.1 mode=rings`.

## How to use

### Placing a target

1. Get a `target` item and use it from your inventory.
2. A ghost preview appears in front of you and the placement panel opens in the top left.
3. Line it up and press **Enter**. The item is removed and the target appears for everyone.

| Key | Action |
| --- | --- |
| Enter | Place the target (only when ground is found) |
| Backspace | Cancel |
| ← / → | Rotate |
| ↑ / ↓ | Raise / lower (±1 m) |
| W A S D | Walk to move the preview |

The panel shows your heading, height offset, whether ground was found, and the time left (placement cancels after 120 seconds).

### Shooting

Equip a **bow**, **improved bow** or **throwing knives** and hit the target face. Each hit shows a notification with points, distance from centre and your session totals. A bullseye triggers the big on-screen announcement.

Default ring scoring:

| Zone | Radius | Points |
| --- | --- | --- |
| Bullseye | 0.06 m | 10 |
| Ring 1 | 0.12 m | 8 |
| Ring 2 | 0.20 m | 6 |
| Ring 3 | 0.30 m | 4 |
| Ring 4 | 0.40 m | 2 |

**Distance bonus:** beyond 5 m you earn +1 point for every full 5 m, up to +20. Shots closer than 2 m don't score in ring mode.

### Leaderboard

Use the **View Leaderboard** target option on any target, or type `/targetboard`. Close it with the × button or **Esc**. Scores, records and hit maps last for the session and reset when the resource restarts.

### Packing up

Use the **Pack Up Target** target option (owner or admin only), or stand next to it and type `/targetremove`. Player targets return the item to your inventory, if you have room. Admin targets are simply removed.

## Commands

| Command | Access | Purpose |
| --- | --- | --- |
| `/targetboard` | Everyone | Open the leaderboard |
| `/targetscore` | Everyone | Show your session total |
| `/targetremove` | Everyone | Pack up the nearest target you own |
| `/targetdiag` | Everyone | Run a 10-second detection diagnostic (`/targetdiag report`, `/targetdiag off`) |
| `/admintarget` | `admin` | Place a target without using an item |
| `/targetdebug` | `admin` | Toggle calibration rings and impact markers |

## Configuration

All settings are in `shared/config.lua`.

| Option | Default | Description |
| --- | --- | --- |
| `Config.Item` | `'target'` | Inventory item that places a target |
| `Config.AdminPermission` | `'admin'` | Permission for admin commands and removing any target |
| `Config.FrameModel` / `FaceModel` | `p_targetframe01x` / `p_targetarchery02x` | Props used |
| `Config.Placement.distance` | `2.5` | Preview distance in front of the player (m) |
| `Config.Placement.maxDistance` | `6.0` | Max distance between player and placed target (server check) |
| `Config.Placement.heightRange` | `1.0` | Max raise/lower offset (m) |
| `Config.Placement.rotationSpeed` / `heightSpeed` | `65.0` / `0.4` | Rotate (°/s) and height (m/s) speed |
| `Config.Placement.maxPerPlayer` | `5` | Targets per character |
| `Config.Placement.maxTotal` | `100` | Targets server-wide |
| `Config.Placement.minimumSpacing` | `1.5` | Minimum gap between targets (m) |
| `Config.Placement.timeoutSeconds` | `120` | Placement auto-cancel time |
| `Config.StreamDistance` | `120.0` | Distance at which target props spawn on clients |
| `Config.RemoveDistance` | `3.0` | Interaction / pack-up distance |
| `Config.LeaderboardRefreshMs` | `2000` | Leaderboard refresh rate while it is open |
| `Config.PersistTargets` | `true` | Save targets to disk (required for player-placed targets) |
| `Config.StorageFile` | `'data/targets.json'` | Save file |
| `Config.Scoring.mode` | `'rings'` | `'rings'` for ring points, `'hit'` for 1 point per hit |
| `Config.Scoring.bullseyeRadius` / `bullseyePoints` | `0.06` / `10` | Bullseye size and value |
| `Config.Scoring.rings` | see table above | Ring radii and points |
| `Config.Scoring.distanceBonus` | 5 m start, +1 per 5 m, max 20 | Long-range bonus |
| `Config.Scoring.minDistance` / `maxDistance` | `2.0` / `80.0` | Allowed shooting range |
| `Config.Scoring.shotCooldownMs` | `450` | Minimum time between scored shots |
| `Config.Weapons` | bow, improved bow, throwing knives | Weapons that score (value = locale key for the name) |
| `Config.WeaponKinds` | arrow / knife | Groups weapons for leaderboard stats |
| `Config.RequireWeaponItem` | `true` | Only count shots if the player owns the weapon item |
| `Config.Controls` | Enter, Backspace, arrows | Placement key hashes |
| `Config.Debug` | `false` | Debug output for everyone by default |

**Advanced:** `Config.Source`, `Config.Scoring.center`, `depthTolerance`, the `impact*` values and `Config.Projectiles` handle prop geometry and hit detection. Only change them if you are recalibrating, and use `/targetdebug` to check the result.

## Locales

Included languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Choose one with `setr ox:locale <code>`. To add a language, copy `locales/en.json` to a new file named with the language code, translate the values and keep the keys unchanged.

## Data and storage

- Placed targets live in `data/targets.json`. Back it up before updating.
- If the file is missing or corrupt, or a save fails, placement and pickup are **disabled**, so items are never lost or duplicated. Fix or restore the file, then restart the resource.
- Scores, records and hit maps are kept in memory only, for the session.

## Developer hook

Every accepted hit fires a **server-only** event you can use for rewards or logging:

```lua
AddEventHandler('rsg-targetpractise:server:acceptedHit', function(data)
    -- data.source, data.citizenid, data.targetId, data.weaponKind, data.points,
    -- data.bullseye, data.distance, data.distanceBonus, data.scoringMode, data.timestamp
end)
```

Never register this as a net event.

## Troubleshooting

- **Hits not scoring:** run `/targetdiag` near a target, take a few shots and read the report. Check that you have the weapon item when `RequireWeaponItem` is on.
- **"Storage error" when placing:** check that `data/targets.json` exists, is valid JSON and is writable.
- **Rings look off-centre:** an admin can run `/targetdebug` to see the scoring rings drawn on the target.
