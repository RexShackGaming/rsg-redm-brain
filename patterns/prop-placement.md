# Prop placement: always use rsg-gizmo

Any resource that lets a player or admin put a prop in the world uses **rsg-gizmo**. Do not write ghost/raycast/rotate loops in individual scripts (older ones like rsg-beekeeper `client/placement.lua` and rsg-boats `client/placer.lua` predate it).

fxmanifest: add `'rsg-gizmo'` to `dependencies`.

```lua
-- client (Place is blocking: run it in a thread)
CreateThread(function()
    local res = exports['rsg-gizmo']:Place(Config.PropModel, {
        title = locale('place_title'),
        maxDistance = 5.0,
        rotation = 'z',              -- or 'all' for pitch/roll/yaw
        validate = function(coords, rot) return true end, -- optional, runs each frame
    })
    if not res then return end      -- cancelled
    TriggerServerEvent('rsg-<name>:server:place', res.coords, res.rotation)
end)

-- server
RegisterNetEvent('rsg-<name>:server:place', function(coords, rot)
    local src = source
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, 5.0) then return end
    rot = exports['rsg-gizmo']:SanitiseRotation(rot)
    -- check + remove item / money, limits, save to DB, spawn for everyone
end)
```

Result: `{ coords = vector3, rotation = vector3(pitch, roll, yaw), heading = number }` or `nil`.
Spawn with `SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, true)`.
Moving an existing prop: `exports['rsg-gizmo']:Edit(entity, opts)` (restores on cancel).
Other client exports: `IsActive()`, `Cancel()`. Full API: rsg-gizmo `DOCS.md`.
