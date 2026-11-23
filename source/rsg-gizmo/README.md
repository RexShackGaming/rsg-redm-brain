# rsg-gizmo

The standard prop placement gizmo for the RSG Framework. Any script that needs a player or admin to put a prop in the world calls rsg-gizmo, gets back coords + rotation, and does its own saving.

**Version:** 3.1.0 · **Dependencies:** rsg-core · **Full API:** [DOCS.md](DOCS.md)

## Features
- One blocking export: `exports['rsg-gizmo']:Place(model, options)` → `{ coords, rotation, heading }` or `nil`
- `Edit(entity, options)` to move an already-spawned prop (restores it on cancel)
- Two modes: **Free** (prop follows where you look, sits on the surface) and **Fine** (nudge on X/Y/Z with keys, axis lines shown)
- Heading-only or full pitch/roll/yaw rotation, snap-to-ground, precision hold
- Coloured bounding box (green valid / red invalid) and a house-style NUI HUD (no focus, you keep the camera)
- Built-in rules (distance from player, water, interiors) plus your own `validate` callback
- Roll control, grid/angle snapping, undo/redo, optional slope limit and a range ring on the ground
- Works while mounted (the camera ray looks through you and your horse)
- `PlaceMany(items, options)` places a group of props together; the server can rebuild every item's position
- Remembers the last rotation/mode/snap per resource and model
- Server helpers to validate returned coords and sanitise rotation, plus hard limits (max distance, world height)
- Admin `/gizmotest [model]` and `/gizmotestgroup` print coords for config work
- No database, no ox_lib

## Installation
1. Drop `rsg-gizmo` in `[framework]`.
2. `ensure rsg-gizmo` after `rsg-core` and before any script that uses it.
3. Add `rsg-gizmo` to the `dependencies` of scripts that call it.

No database tables are needed.

## Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `Defaults.rayDistance` | `12.0` | Camera ray length in free mode |
| `Defaults.maxDistance` | `10.0` | Max distance between player and prop |
| `Defaults.alpha` | `170` | Ghost transparency |
| `Defaults.rotation` | `'z'` | `'z'` heading only, `'all'` pitch/roll/yaw |
| `Defaults.snapToGround` | `true` | Free mode sits the model's base on the surface |
| `Defaults.allowInterior` | `true` | Allow placing inside interiors |
| `Defaults.allowWater` | `false` | Allow props in water |
| `Defaults.moveSpeed` | `1.5` | m/s in fine mode |
| `Defaults.rotateSpeed` | `90.0` | deg/s with arrows |
| `Defaults.scrollRotate` / `scrollHeight` | `7.5` / `0.05` | Per wheel tick |
| `Defaults.precision` | `0.2` | Speed multiplier while holding Ctrl |
| `Defaults.startMode` | `'free'` | Mode the session opens in |
| `Defaults.snap` | `false` | Start with snapping on |
| `Defaults.showRange` | `true` | Draw the max-distance ring on the ground |
| `Defaults.maxSlope` | `nil` | Degrees; blocks steeper surfaces when set |
| `Defaults.remember` | `true` | Start from the last rotation/mode/snap used for this model |
| `Snap` | `grid 0.25, angle 15` | Snapping step (metres / degrees) |
| `Remember` | `true` | Master switch for the placement memory |
| `History` / `HistoryDelay` | `30` / `350` | Undo steps kept / idle ms before an edit becomes a step |
| `Limits` | `30.0, -250..1500` | Cap on any `maxDistance` (client and server) and world height range checked on the server |
| `Colours` | — | Box/axis colours |
| `Controls` | — | Key hashes (from rdr3_discoveries Controls) |
| `KeyLabels` | — | Key captions shown in the HUD (display only) |
| `InputGrace` | `250` | Ms after opening where confirm/cancel are ignored, so the opening key can't place/cancel instantly |
| `TestCommand` | enabled, `admin` | `/gizmotest` settings |

## How to use (controls)
| Key | Action |
|---|---|
| LMB / Enter | Place |
| RMB / Backspace | Cancel |
| R | Switch Free / Fine mode |
| Mouse wheel | Free: turn · Fine: height |
| Arrows | Free: ←/→ turn · Fine: move relative to camera |
| Shift (hold) | Rotate with arrows/wheel (↑/↓ tilts when rotation = `all`) |
| Ctrl (hold) | Precision |
| G | Snap to ground (also aligns tilt when rotation = `all`) |
| Q | Reset tilt |
| C (hold) | Roll with arrows/wheel (rotation = `all`) |
| X | Toggle snapping (grid + angle step) |
| Z / V | Undo / Redo |

Command: `/gizmotest [model]` (admin) — place a test prop and print its coords to F8.

## Developer example
```lua
-- client
CreateThread(function()
    local res = exports['rsg-gizmo']:Place('p_campfire01x', { maxDistance = 5.0 })
    if not res then return end -- cancelled
    TriggerServerEvent('my-script:server:placeCampfire', res.coords, res.heading)
end)

-- server
RegisterNetEvent('my-script:server:placeCampfire', function(coords, heading)
    local src = source
    local ok = exports['rsg-gizmo']:IsPlacementValid(src, coords, 5.0)
    if not ok then return end
    -- check/remove item, save to DB, spawn for everyone...
end)
```

Group example:
```lua
local items = { { model = 'p_chair05x' }, { model = 'p_chair05x', offset = vector3(1.0, 0.0, 0.0) } }
local res = exports['rsg-gizmo']:PlaceMany(items, { maxDistance = 6.0 })
if res then TriggerServerEvent('my-script:server:placeSet', res.coords, res.heading) end
-- server: build the items from YOUR config and let rsg-gizmo rebuild the positions
local ok, _, placed = exports['rsg-gizmo']:IsGroupPlacementValid(src, Config.Set, coords, heading, 6.0)
```

Commands: `/gizmotest [model]` and `/gizmotestgroup` (admin).

## Locales
en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (`setr rsg:locale "en"`)

Support the Project : https://rexshack.tebex.store/

### Note
While placing, `LocalPlayer.state.gizmoActive` is `true` so other scripts (e.g. rsg-voice range cycling) can ignore input. See DOCS.md.
