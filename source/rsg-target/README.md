# rsg-target

Targeting system for the RSG Framework (RedM), rebuilt from ox_target into the standard RSG resource layout, with an RSG-style NUI and a nearby-target highlighter.

## Features
- Hold **Left Alt** (or toggle) to target peds, horses/wagons, objects and zones
- **Nearby highlighter** – eyeball icons over everything around you that you can interact with; the eye turns **green** when the target you're aiming at can be used (in range, job/gang, items and `canInteract` all pass)
- Option checks: `groups` (job / gang / citizenid with grades via rsg-core), `items` (rsg-inventory), `distance`, `offset`, `canInteract`
- Sub-menus (`openMenu` / `menuName`) with a built-in Go back option
- Option actions: `onSelect`, `export`, `event`, `serverEvent`, `command`
- Drop-in replacement: existing `exports.ox_target` and legacy rsg-target exports keep working

## Install
1. **Stop / remove `ox_target`** – rsg-target replaces it (it `provide`s `ox_target`).
2. Put `rsg-target` in your resources and `ensure rsg-target` after `ox_lib` and `rsg-core`.
3. Run `refresh` and restart the server (scripts register their targets when they start).
4. Adjust `shared/config.lua`.

## Config (`shared/config.lua`)
| Setting | Description |
|---|---|
| `Config.Debug` | Spawns debug options on peds/vehicles/objects and prints selections |
| `Config.Toggle` | `true` press to open/close, `false` hold to target |
| `Config.DefaultDistance` | Interact distance for options without `distance` |
| `Config.RaycastDistance` | How far the camera ray reaches |
| `Config.Keys` | `Target`, `Focus`, `Close` control hashes |
| `Config.DrawSprite` / `SpriteColour` / `SpriteHover` | Classic zone sprites (used when the highlighter is off) |
| `Config.Highlight` | Radius, scan interval, max markers, which entity types, line of sight, global options, eye size, pulse, colours |

## API
All ox_target exports, on either resource name:
```lua
exports['rsg-target']:addLocalEntity(ped, {
    {
        name = 'talk_to_trader',
        icon = 'fa-solid fa-comments',
        label = 'Talk',
        distance = 2.0,
        groups = { trader = 0 },        -- optional
        items = 'trade_licence',        -- optional
        canInteract = function(entity, distance, coords, name) return true end,
        onSelect = function(data) end,  -- or event / serverEvent / export / command
    }
})
```
`addBoxZone`, `addSphereZone`, `addPolyZone`, `removeZone`, `zoneExists`, `addModel`, `removeModel`, `addEntity`, `removeEntity`, `addLocalEntity`, `removeLocalEntity`, `addGlobalPed`, `addGlobalVehicle`, `addGlobalObject`, `addGlobalPlayer`, `addGlobalOption` (+ matching removes), `disableTargeting`, `isActive`, `getTargetOptions`.

Legacy exports (`AddBoxZone`, `AddCircleZone`, `AddTargetModel`, `AddTargetEntity`, `AddGlobalPed`, …) are still provided for older scripts.

> Never trust option data on the server: anything sent with `serverEvent` comes from the client and must be validated in your own resource.

## Structure
```
client/   client.lua (targeting loop), api.lua, highlight.lua, utils.lua, state.lua, framework.lua, debug.lua, compat/
server/   server.lua, versionchecker.lua
shared/   config.lua
html/     index.html, style.css, js/, assets/
locales/  *.json
```

## Credits
Based on [ox_target](https://github.com/overextended/ox_target) by Overextended (MIT).

Support: https://buymeacoffee.com/rexshack
