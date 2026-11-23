# rsg-gizmo 3.1.0 — developer docs

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
| `shared/config.lua` | Defaults, colours, control hashes, key labels, snap/history/limits, test commands |
| `shared/group.lua` | `Gizmo.GroupTransform` (also exported as `GroupTransform`), used by client and server |
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
| `snap` | bool | Start with grid/angle snapping on (`Config.Snap`). Toggled in game with X |
| `showRange` | bool | Draw the `maxDistance` ring on the ground (default true) |
| `maxSlope` | number | Degrees. When set, surfaces steeper than this are invalid (`invalid_slope`). Free mode uses the ray's surface normal, fine mode a probe below the prop |
| `remember` | bool | Start from the last rotation, mode, snap (and fine-mode coords) used for this model by the calling resource. `false` always starts fresh. Master switch: `Config.Remember` |
| `moveSpeed`, `rotateSpeed`, `scrollRotate`, `scrollHeight`, `precision` | number | Feel |
| `validate` | `function(coords, rotation) -> ok, reason` | Runs every frame; return `false, 'text'` to block placement. Keep it cheap. Errors are caught and treated as invalid (enable `Config.Debug` to see them) |

## 3. Result format
```lua
{ coords = vector3, rotation = vector3(pitch, roll, yaw), heading = number }
```
Group placements (`PlaceMany`) add `items = { { model, coords, heading }, ... }`.

`nil` means cancelled, invalid model, player died, another session active, or `Cancel()` was called.
Spawn with `SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, true)` (rotation order 2) or `SetEntityHeading(obj, heading)` for heading-only props.

## 4. Client exports
| Export | Returns | Notes |
|---|---|---|
| `Place(model, options)` | result / nil | **Blocking** — call inside `CreateThread`. Spawns a local, non-networked ghost and deletes it afterwards |
| `Edit(entity, options)` | result / nil | Moves an existing entity in place; restores position, rotation, alpha, collision and frozen state on cancel (frozen state is also restored after a confirmed move). With `rotation = 'z'` the entity's existing pitch/roll are kept. Requests network control if networked (waits up to 1s, returns nil if not granted). The caller still syncs the final position to the server/DB |
| `PlaceMany(items, options)` | result / nil | **Blocking.** `items = { { model, offset = vector3, heading = number }, ... }`; item 1 is the anchor (its offset/heading are ignored), the others are placed relative to it. Groups are heading-only (`rotation` is forced to `'z'`), the result has `items` with world coords + heading for every item. `validate` receives the anchor only, use `GroupTransform` inside it to check the rest |
| `GroupTransform(items, coords, heading)` | list | Pure maths, also available on the server. Returns `{ { model, coords, heading }, ... }` |
| `IsActive()` | bool | Whether a session is running |
| `Cancel()` | — | Ends the current session (result `nil`) |

## 5. Server exports
| Export | Returns | Notes |
|---|---|---|
| `IsPlacementValid(src, coords, maxDistance?)` | `ok, reason` | Checks numbers are finite and the player ped is within `maxDistance + 2.0` (a non-number `maxDistance` falls back to `Config.Defaults.maxDistance`). Reasons: `bad_coords`, `out_of_bounds` (outside `Config.Limits.minZ/maxZ`), `no_player`, `too_far`. `maxDistance` is capped by `Config.Limits.maxDistance` |
| `IsGroupPlacementValid(src, items, coords, heading, maxDistance?)` | `ok, reason, placed` | Validates the anchor like `IsPlacementValid`, then rebuilds every item with `GroupTransform` on the server. **`items` must come from your server config.** `placed` = `{ { model, coords, heading }, ... }`. Extra reasons: `bad_items`, `out_of_bounds` |
| `GroupTransform(items, coords, heading)` | list | Same function as on the client |
| `SanitiseRotation(rot)` | vector3 | Converts client input to a safe vector3 (each axis `% 360`, bad values → 0) |

## 6. Events
| Event | Side | Args |
|---|---|---|
| `rsg-gizmo:client:place` | client (local `TriggerEvent`) | `model, options, cb(result)` — non-blocking alternative to the export |
| `rsg-gizmo:client:placeMany` | client (local `TriggerEvent`) | `items, options, cb(result)` |
| `rsg-gizmo:client:test` | client (from server) | `model` — used by `/gizmotest` |
| `rsg-gizmo:client:testgroup` | client (from server) | none — used by `/gizmotestgroup` |

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
- `/gizmotest` and `/gizmotestgroup` are gated by rsg-core command permission (`Config.TestCommand.permission`).
- `Config.Limits` caps any `maxDistance` a script asks for and rejects coords outside the world height range, so a bad call cannot widen the placement radius.
- For groups, never accept child positions from the client: use `IsGroupPlacementValid` with items from your own config.

## 10. Database
No tables.

## 11. How-tos
- **Get coords for a config:** `/gizmotest p_chair05x`, place it, copy the line from F8.
- **Change keys:** edit `Config.Controls` with hashes from `data/rdr3_discoveries/Controls/README.md`, and `Config.KeyLabels` so the HUD shows the right captions.
- **Heading-only props (signs, tents):** leave `rotation = 'z'`. **Props on slopes:** use `rotation = 'all'` and press G.

## 12. Troubleshooting
| Problem | Fix |
|---|---|
| Export returns nil immediately | Another session is active, or the model name is invalid (notify shows "Invalid model") |
| Freezes calling code | `Place` blocks — call it inside `CreateThread` |
| Prop floats/sinks | Model origin is unusual; use fine mode + wheel, or set `snapToGround = false` |
| Prop goes under the map in free mode | Aim at solid ground; ray only moves the prop on a hit |
| Edit returns nil on a networked prop | Network control wasn't granted within 1s; spawn it client-side or move it server-side from the result |
| Prop lands on my horse | The ray skips you and your mount; wagons and other entities are not skipped yet |
| Z / V / X / C do nothing | Another resource may block those keys, or `Config.Controls` was changed. Captions come from `Config.KeyLabels` |
| rsg-gizmo restarted mid-placement | The ghost is deleted and an edited entity is put back where it was automatically |

Support the Project : https://rexshack.tebex.store/

## Blocking other resources while placing

While a session runs the gizmo disables `Config.BlockControls` (now including the mouse-wheel aliases and rsg-voice's range key) and sets the local state bag `LocalPlayer.state.gizmoActive = true`.
Resources that read input through key mappings / commands (which `DisableControlAction` cannot block) should check it, e.g. in rsg-voice:

```lua
if LocalPlayer.state.gizmoActive then return end
```

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-gizmo 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` |  |
| `Config.Defaults` | `table` | Defaults (every one can be overridden per call through the options table) |
| `Config.Colours` | `table` | Draw colours (r, g, b, a) |
| `Config.Controls` | `table` | Control hashes: data/rdr3_discoveries/Controls/README.md |
| `Config.Snap` | `table` | Snap grid (m) and angle step (deg) |
| `Config.Remember` | `true` | Placement memory master switch |
| `Config.History` / `Config.HistoryDelay` | `30` / `350` | Undo steps / idle ms per step |
| `Config.Limits` | `table` | Max distance cap and world height range |
| `Config.KeyLabels` | `table` | Key captions shown in the HUD (display only) |
| `Config.InputGrace` | `250` | Ms after a session opens where confirm/cancel are ignored |
| `Config.BlockControls` | `table` | Extra controls blocked while placing |
| `Config.TestCommand` | `{ enabled = true, name = 'gizmotest', permission = 'admin', model = 'p` | Admin test command: /gizmotest [model] |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `IsPlacementValid` | `` | `server/server.lua` |
| `IsGroupPlacementValid` | `` | `server/server.lua` |
| `GroupTransform` | `` | `shared/group.lua` |
| `SanitiseRotation` | `` | `server/server.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `Place` | `` | `client/client.lua` |
| `PlaceMany` | `` | `client/client.lua` |
| `Edit` | `` | `client/client.lua` |
| `IsActive` | `` | `client/client.lua` |
| `Cancel` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-gizmo']:IsPlacementValid()
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-gizmo:client:test` | client | `model` | `client/client.lua` |

```lua
-- from a server script
TriggerClientEvent('rsg-gizmo:client:test', source, model)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
