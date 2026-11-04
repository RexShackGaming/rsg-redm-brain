# rsg-gizmo

The standard prop placement gizmo for the RSG Framework. Any script that needs a player or admin to put a prop in the world calls rsg-gizmo, gets back coords + rotation, and does its own saving.

**Version:** 3.0.0 · **Dependencies:** rsg-core · **Full API:** [DOCS.md](DOCS.md)

## Features
- One blocking export: `exports['rsg-gizmo']:Place(model, options)` → `{ coords, rotation, heading }` or `nil`
- `Edit(entity, options)` to move an already-spawned prop (restores it on cancel)
- Two modes: **Free** (prop follows where you look, sits on the surface) and **Fine** (nudge on X/Y/Z with keys, axis lines shown)
- Heading-only or full pitch/roll/yaw rotation, snap-to-ground, precision hold
- Coloured bounding box (green valid / red invalid) and a house-style NUI HUD (no focus, you keep the camera)
- Built-in rules (distance from player, water, interiors) plus your own `validate` callback
- Server helpers to validate returned coords and sanitise rotation
- Admin `/gizmotest [model]` prints coords for config work
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
| `Colours` | — | Box/axis colours |
| `Controls` | — | Key hashes (from rdr3_discoveries Controls) |
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

## Locales
en, de, el, es, fr, ja, nl, pl, pt-br, ro (`setr rsg:locale "en"`)

Support: https://buymeacoffee.com/rexshack

### Note
While placing, `LocalPlayer.state.gizmoActive` is `true` so other scripts (e.g. rsg-voice range cycling) can ignore input. See DOCS.md.
