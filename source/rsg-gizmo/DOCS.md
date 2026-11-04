# rsg-gizmo — developer docs

## Contents
1. Architecture
2. Options table
3. Result format
4. Client exports
5. Server exports
6. Events
7. Integration examples
8. Persistence
9. Security model
10. Database
11. How-tos
12. Troubleshooting

## 1. Architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on rsg-core only |
| `shared/config.lua` | Defaults, colours, control hashes, test command |
| `client/client.lua` | Ghost spawning, placement loop, raycast, drawing, exports |
| `server/server.lua` | `IsPlacementValid`, `SanitiseRotation`, `/gizmotest` |
| `html/*` | HUD (no NUI focus): mode, validity, coords, rotation, key list |
| `locales/*.json` | All player-facing text |

rsg-gizmo never saves anything. It only returns where the player put the prop; the calling script owns items, money, database and spawning.

## 2. Options table (all optional; defaults from `Config.Defaults`)
| Key | Type | Description |
|---|---|---|
| `title` | string | HUD title (default locale `hud_title`) |
| `rayDistance` | number | Free-mode ray length |
| `maxDistance` | number | Max player ↔ prop distance |
| `rotation` | `'z'`/`'all'` | Heading only or full rotation |
| `snapToGround` | bool | Lift model so its base sits on the hit surface |
| `allowInterior` / `allowWater` | bool | Built-in rules. Interior blocks if the prop **or** the player is inside an interior |
| `alpha` | number | Ghost alpha |
| `startMode` | `'free'`/`'fine'` | `Edit` defaults to `'fine'` |
| `startCoords` | vector3 | Initial position |
| `startRotation` | vector3 | Initial pitch, roll, yaw |
| `moveSpeed`, `rotateSpeed`, `scrollRotate`, `scrollHeight`, `precision` | number | Feel |
| `validate` | `function(coords, rotation) -> ok, reason` | Runs every frame; return `false, 'text'` to block placement. Keep it cheap. Errors are caught and treated as invalid (enable `Config.Debug` to see them) |

## 3. Result format
```lua
{ coords = vector3, rotation = vector3(pitch, roll, yaw), heading = number }
```
`nil` means cancelled, invalid model, player died, another session active, or `Cancel()` was called.
Spawn with `SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, true)` (rotation order 2) or `SetEntityHeading(obj, heading)` for heading-only props.

## 4. Client exports
| Export | Returns | Notes |
|---|---|---|
| `Place(model, options)` | result / nil | **Blocking** — call inside `CreateThread`. Spawns a local, non-networked ghost and deletes it afterwards |
| `Edit(entity, options)` | result / nil | Moves an existing entity in place; restores position, rotation, alpha and collision on cancel. Requests network control if networked (waits up to 1s, returns nil if not granted). The caller still syncs the final position to the server/DB |
| `IsActive()` | bool | Whether a session is running |
| `Cancel()` | — | Ends the current session (result `nil`) |

## 5. Server exports
| Export | Returns | Notes |
|---|---|---|
| `IsPlacementValid(src, coords, maxDistance?)` | `ok, reason` | Checks numbers are finite and the player ped is within `maxDistance + 2.0`. Reasons: `bad_coords`, `no_player`, `too_far` |
| `SanitiseRotation(rot)` | vector3 | Converts client input to a safe vector3 (each axis `% 360`, bad values → 0) |

## 6. Events
| Event | Side | Args |
|---|---|---|
| `rsg-gizmo:client:place` | client (local `TriggerEvent`) | `model, options, cb(result)` — non-blocking alternative to the export |
| `rsg-gizmo:client:test` | client (from server) | `model` — used by `/gizmotest` |

## 7. Integration examples
Item-based placement:
```lua
-- server
RSGCore.Functions.CreateUseableItem('shopsign', function(source)
    TriggerClientEvent('rsg-stores:client:placeSign', source)
end)
RegisterNetEvent('rsg-stores:server:placeSign', function(coords, rot)
    local src = source
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, 6.0) then return end
    rot = exports['rsg-gizmo']:SanitiseRotation(rot)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not exports['rsg-inventory']:RemoveItem(src, 'shopsign', 1) then return end
    -- insert into DB, then broadcast spawn
end)

-- client
RegisterNetEvent('rsg-stores:client:placeSign', function()
    local res = exports['rsg-gizmo']:Place(Config.SignModel, {
        title = locale('place_sign'), maxDistance = 6.0,
        validate = function(c) if IsPointNearRoad(c) then return false, locale('too_close_road') end return true end,
    })
    if res then TriggerServerEvent('rsg-stores:server:placeSign', res.coords, res.rotation) end
end)
```
(`IsPointNearRoad` above is a placeholder for your own rule.)

Admin moving an existing prop:
```lua
local res = exports['rsg-gizmo']:Edit(obj, { rotation = 'all' })
if res then TriggerServerEvent('my-script:server:moveProp', propId, res.coords, res.rotation) end
```

## 8. Persistence
None. Callers store the result.

## 9. Security model
- The client result is **untrusted**. Always run `IsPlacementValid` (or your own distance check) on the server.
- Calling scripts must check items, money, job/permission, zone rules and per-player limits themselves.
- `/gizmotest` is gated by rsg-core command permission (`Config.TestCommand.permission`).

## 10. Database
No tables.

## 11. How-tos
- **Get coords for a config:** `/gizmotest p_chair05x`, place it, copy the line from F8.
- **Change keys:** edit `Config.Controls` with hashes from `data/rdr3_discoveries/Controls/README.md`.
- **Heading-only props (signs, tents):** leave `rotation = 'z'`. **Props on slopes:** use `rotation = 'all'` and press G.

## 12. Troubleshooting
| Problem | Fix |
|---|---|
| Export returns nil immediately | Another session is active, or the model name is invalid (notify shows "Invalid model") |
| Freezes calling code | `Place` blocks — call it inside `CreateThread` |
| Prop floats/sinks | Model origin is unusual; use fine mode + wheel, or set `snapToGround = false` |
| Prop goes under the map in free mode | Aim at solid ground; ray only moves the prop on a hit |
| Edit returns nil on a networked prop | Network control wasn't granted within 1s; spawn it client-side or move it server-side from the result |
| rsg-gizmo restarted mid-placement | The ghost is deleted and an edited entity is put back where it was automatically |

Support: https://buymeacoffee.com/rexshack

## Blocking other resources while placing

While a session runs the gizmo disables `Config.BlockControls` (now including the mouse-wheel aliases and rsg-voice's range key) and sets the local state bag `LocalPlayer.state.gizmoActive = true`.
Resources that read input through key mappings / commands (which `DisableControlAction` cannot block) should check it, e.g. in rsg-voice:

```lua
if LocalPlayer.state.gizmoActive then return end
```
