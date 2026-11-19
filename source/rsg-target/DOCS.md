# rsg-target – Developer Docs

Technical reference for server owners and developers. For a short overview see [README.md](README.md).

## Contents
1. [Overview](#overview)
2. [Files and architecture](#files-and-architecture)
3. [Installation and dependencies](#installation-and-dependencies)
4. [Configuration](#configuration)
5. [Controls](#controls)
6. [Option reference](#option-reference)
7. [Exports](#exports)
8. [Zones](#zones)
9. [Handler payload](#handler-payload)
10. [Sub-menus](#sub-menus)
11. [Events and callbacks](#events-and-callbacks)
12. [NUI messages](#nui-messages)
13. [Legacy (qb-target style) exports](#legacy-qb-target-style-exports)
14. [Code examples](#code-examples)
15. [Security model](#security-model)
16. [Performance notes](#performance-notes)
17. [Locales](#locales)
18. [Troubleshooting](#troubleshooting)
19. [Changelog](#changelog)
20. [ox_lib removed](#ox_lib-removed)

---

## Overview
rsg-target is the targeting system for the RSG Framework. While the target key is held (or toggled) it raycasts from the camera, finds the entity or zone you are aiming at, filters the registered options (`groups`, `items`, `distance`, `canInteract`, ...) and shows the remaining ones in a NUI list. It also highlights nearby interactable things with eye icons.

It is a rewrite of ox_target in the RSG resource layout. The resource `provide`s `ox_target`, so `exports.ox_target:*` calls from older scripts keep working, and it also exposes the legacy qb-target export names.

## Files and architecture
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Resource definition. `provide 'ox_target'`; client modules are listed under `files` because they are loaded with `require` (from `@rsg-core/shared/require.lua`) |
| `shared/config.lua` | All settings (see [Configuration](#configuration)) |
| `client/client.lua` | Key listener, targeting loop, option filtering, NUI callbacks, `/targethighlight` command |
| `client/api.lua` | All exports and the option storage (peds, vehicles, objects, players, models, networked entities, local entities, global options, zones) |
| `client/highlight.lua` | Scans nearby peds/vehicles/objects/zones that have usable options and draws eye markers through the NUI |
| `client/utils.lua` | Zone sprites, item checks, shared filter (`passesFilters`), cooldown helper, warnings |
| `client/framework.lua` | rsg-core bridge: keeps player data, item counts and held jobs in sync for `groups` / `items` / `requiresDuty` |
| `client/state.lua` | Active / NUI-focus / disabled flags |
| `client/debug.lua` | `rsg-target:client:debug` handler and (with `Config.Debug`) demo zones and global options |
| `client/compat/rsg-target.lua` | Legacy qb-target style exports (`AddBoxZone`, `AddTargetModel`, ...) converted to the current option format |
| `client/compat/ox_target.lua` | Answers `exports.ox_target:*` calls (the resource also `provide`s `ox_target`) |
| `server/server.lua` | Flags networked entities that have options, tells clients to drop options for deleted entities, answers the `getJobs` callback |
| `server/versionchecker.lua` | Compares `version` in the manifest with `Rexshack-RedM/rsg-versioncheckers` on GitHub |
| `html/` | NUI: `index.html`, `style.css`, `js/main.js`, `js/fetchNui.js`, `assets/*.png` |
| `locales/*.json` | 10 languages (`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`) |

### Targeting loop (client.lua)
1. Target key pressed → `startTargeting()` sets the state active and starts a render thread (`Wait(0)`: zone sprites, eye markers, control blocking, focus handling, quick select).
2. The main loop runs every 50 ms (aiming at something) or 100 ms: camera raycast (`RSGCore.Functions.RaycastCamera`), alternating the flag between world (30) and world+entities (-1) when nothing is hit, resolves the entity type/model, finds zones containing the hit point.
3. When the entity, zones or menu changed it asks `api.getTargetOptions` to collect option lists (`__global`, `globalTarget`, `model`, `entity`, `localEntity`) and every option is run through `shouldHide`.
4. If anything changed it sends `setTarget` to the NUI with the option lists and zone options.
5. When the key is released, the pause menu or map opens, a progress bar or the inventory opens, or an option is chosen, targeting stops and everything is reset (`options:wipe()`, menu history, NUI hidden).

### Option storage and lookup order
| List | Filled by | Matches |
|---|---|---|
| `__global` | `addGlobalOption` | any target |
| `globalTarget` | `addGlobalPed/Vehicle/Object/Player` | by entity type (ped = 1, vehicle = 2, object = 3; players use the player list) |
| `model` | `addModel` | by model hash |
| `entity` | `addEntity` | by network id |
| `localEntity` | `addLocalEntity` | by local handle |
| zones | `addBoxZone/SphereZone/PolyZone` | when the aimed point is inside the zone |

The NUI renders the lists in this order: `__global`, `entity`, `globalTarget`, `localEntity`, `model`, then zones. Options are then stably sorted by `priority` (higher first).

## Installation and dependencies
- Dependencies: `rsg-core` (client zones, raycast, nearby scans, progress check, locale/require/table includes). `rsg-inventory` is not needed directly: item counts come from player data.
- Start order: `ensure rsg-core`, then `ensure rsg-target`, then every resource that registers targets.
- Stop or remove `ox_target`; rsg-target replaces it.
- No database tables are used.

```cfg
ensure rsg-core
ensure rsg-target
ensure my-resource
```

## Configuration
`shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.Debug` | `false` | Spawns demo zones next to the player and global options on peds/vehicles/objects; selecting prints the payload |
| `Config.Toggle` | `false` | `true` = press the target key to open/close, `false` = hold |
| `Config.DefaultDistance` | `7.0` | Interact distance for options without `distance` |
| `Config.RaycastDistance` | `20.0` | Camera raycast reach |
| `Config.CleanupInterval` | `10000` | (ms) server loop that clears deleted networked entities |
| `Config.Keys.Target` | `0x8AAA0AD4` | Left Alt, hold/toggle targeting |
| `Config.Keys.Focus` | `0x07B8BEAF` | Left Mouse, focus the option list |
| `Config.Keys.Close` | `0x53296B75` | Right Mouse, close while focused |
| `Config.QuickSelect.Enabled` | `true` | Quick select key |
| `Config.QuickSelect.Key` | `0xCEFD9220` | E (`INPUT_CONTEXT`) |
| `Config.QuickSelect.Label` | `'E'` | Text shown on the top option |
| `Config.UI.KeyboardNav` | `true` | Arrows / Enter / 1-9 while the menu is focused |
| `Config.UI.Gamepad` | `true` | D-pad / A / B while the menu is focused (experimental) |
| `Config.MultiJob` | `true` | `groups` also matches every job the player holds |
| `Config.DrawSprite` | `24` | Max zone sprites per frame (0 = off, limit 32). Only used when the highlighter or its zones are off |
| `Config.SpriteColour` / `Config.SpriteHover` | grey / white | Zone sprite colours `{ r, g, b, a }` |
| `Config.Highlight.Enabled` | `true` | Default for the nearby eye icons (players can override with the command) |
| `Config.Highlight.Command` | `'targethighlight'` | Player command that toggles the icons, `false` to remove it |
| `Config.Highlight.Radius` | `10.0` | Scan radius |
| `Config.Highlight.ScanInterval` | `500` | (ms) rescan interval |
| `Config.Highlight.MaxDrawn` | `16` | Max markers (game limit is 32 draws per frame) |
| `Config.Highlight.Peds/Vehicles/Objects/Zones` | `true` | Which kinds are scanned. `Zones` replaces the normal zone sprites |
| `Config.Highlight.IncludeGlobal` | `false` | Also mark things that only have global options (e.g. every ped) |
| `Config.Highlight.RequireLineOfSight` | `true` | Only mark entities you can see |
| `Config.Highlight.HeightOffset` | `0.15` | Marker height above the entity |
| `Config.Highlight.Size` / `Pulse` | `22` / `true` | Eye size (px) and pulse animation |
| `Config.Highlight.Colour` / `HoverColour` | `#c8c8c8` / `#6fbf73` | Normal and aimed-at (usable) colours |

## Controls
| Input | Action |
|---|---|
| Hold / press `Config.Keys.Target` (Left Alt) | Start targeting |
| Aim at a target and press `Config.QuickSelect.Key` (E) | Run the top option without opening the menu |
| Left Mouse | Focus the option list (cursor appears) |
| Click an option | Run it |
| Up / Down + Enter, or 1-9 (menu focused) | Keyboard selection |
| D-pad up/down + A, B (menu focused) | Gamepad selection / close (experimental) |
| Right Mouse or Esc (menu focused) | Close |
| `/targethighlight` | Toggle the nearby eye icons, saved per player (KVP key `rsg-target:highlight`) |

Targeting closes automatically for the pause menu, map, inventory (`LocalPlayer.state.invOpen`) and progress bars, and will not start while any NUI has focus.

## Option reference
Every `add*` export takes one option table or an array of them.

| Field | Type | Notes |
|---|---|---|
| `name` | string | Identifier. Unique per resource: adding the same name again replaces the old option (a warning is printed) and `remove*` uses it |
| `label` | string or function | Shown in the menu. A function `function(entity, distance, coords, name) return 'text' end` is re-evaluated while targeting |
| `icon` | string | Font Awesome class, e.g. `fa-solid fa-hand` (default) |
| `iconColor` | string | CSS colour for the icon |
| `distance` | number | Max distance from the player to the hit point. Default `Config.DefaultDistance`. Global options use distance 0 |
| `groups` | string / string[] / `{ [name] = minGrade }` | Job, gang or citizenid. With `Config.MultiJob` every held job counts. A hash needs `grade >= minGrade` |
| `items` | string / string[] / `{ [item] = amount }` | Items the player must carry (all of them, unless `anyItem`) |
| `anyItem` | boolean | Only one of `items` is required |
| `requiresDuty` | boolean | Active job must be `onduty` |
| `cooldown` | number (ms) | After use the option is hidden for this long. Per option, client side |
| `priority` | number | Higher first (default 0). The top option is the quick select target |
| `canInteract` | function | `function(entity, distance, coords, name) return boolean end`, errors count as `false` |
| `offset` | vector3 | Restrict to a spot on the model (fraction of the bounding box unless `absoluteOffset`) |
| `absoluteOffset` | boolean | Treat `offset` as an offset in metres from the entity |
| `offsetSize` | number | Radius around the offset point (default 1.0) |
| `openMenu` | string | Opens a sub-menu with this name (`'home'` goes to the top) |
| `menuName` | string | Only visible inside this sub-menu |
| `onSelect` | function | Called with the [payload](#handler-payload) |
| `export` | string | Calls `exports[<your resource>][export](nil, payload)` |
| `event` | string | `TriggerEvent(event, payload)` |
| `serverEvent` | string | `TriggerServerEvent(serverEvent, payload)` (entity is sent as a net id) |
| `command` | string | `ExecuteCommand(command)` |

Action precedence when several are set: `onSelect` → `export` → `event` → `serverEvent` → `command`.

The checks run in this order: sub-menu → distance → `requiresDuty` → cooldown → `groups` → `items` → `offset` → `canInteract`. `groups`, `items`, `requiresDuty`, `cooldown` and `canInteract` are **client side visibility checks only** (see [Security model](#security-model)).

Callbacks run in `pcall`; if one errors the console shows `[rsg-target] option "<name>" (<resource>) failed: <error>` and targeting closes normally.

## Exports
Available as `exports['rsg-target']:<name>(...)` and, through `provide`, as `exports.ox_target:<name>(...)`. All are client side.

| Export | Arguments | Returns | Description |
|---|---|---|---|
| `addBoxZone` | `data` | zone id | Box zone, see [Zones](#zones) |
| `addSphereZone` | `data` | zone id | Sphere zone |
| `addPolyZone` | `data` | zone id | Polygon zone |
| `zoneExists` | `id` (number or zone name) | boolean | |
| `removeZone` | `id` (number or zone name), `suppressWarning?` | | Name removal removes every zone with that name |
| `addModel` | `model \| model[]` (hash or name), `options` | | Options for every entity with that model |
| `removeModel` | `model \| model[]`, `names?` | | Without `names` removes the model completely |
| `addEntity` | `netId \| netId[]`, `options` | | Networked entities. Also flags the entity on the server |
| `removeEntity` | `netId \| netId[]`, `names?` | | |
| `addLocalEntity` | `entity \| entity[]`, `options` | | Local handles (peds/objects you spawned) |
| `removeLocalEntity` | `entity \| entity[]`, `names?` | | Call it when you delete the entity |
| `addGlobalPed` / `removeGlobalPed` | `options` / `names` | | Every non-player ped |
| `addGlobalVehicle` / `removeGlobalVehicle` | | | Vehicles, wagons, boats |
| `addGlobalObject` / `removeGlobalObject` | | | Every object |
| `addGlobalPlayer` / `removeGlobalPlayer` | | | Other players |
| `addGlobalOption` / `removeGlobalOption` | | | Shown on every target |
| `disableTargeting` | `boolean` | | `true` closes targeting and blocks it until `false` |
| `isActive` | | boolean | Targeting currently open |
| `getTargetOptions` | `entity?, type?, model?` | table | Internal option lookup (used by the highlighter) |

Options are stored per resource: when a resource stops, its options (including global options) and zones are removed automatically (`onClientResourceStop`). Local entity entries are also cleaned every 60 s if the entity no longer exists.

## Zones
Zones come from `@rsg-core/client/zones.lua`. Fields used by rsg-target:

| Field | Applies to | Notes |
|---|---|---|
| `name` | all | Optional, lets you `removeZone('name')` |
| `coords` | box, sphere | vec3 centre |
| `size` | box | vec3 (x width, y length, z height) |
| `rotation` | box | heading in degrees |
| `radius` | sphere | |
| `points`, `thickness` | poly | `points` is a list of vec3 |
| `debug` | all | Draws the zone (a warning is printed) |
| `drawSprite` | all | `false` hides the sprite / eye marker for this zone |
| `options` | all | option table or array |

Check rsg-core's `zones.lua` for the complete list of zone fields.

## Handler payload
`onSelect`, `export` and `event` receive a table, `serverEvent` receives the same with `entity` as a network id (0 when not networked):

| Field | Description |
|---|---|
| `entity` | Entity handle the player aimed at (0 if none) |
| `coords` | World position the camera ray hit |
| `distance` | Distance from the player to `coords` |
| `zone` | Zone id when the option came from a zone |
| `name`, `label`, `resource`, `distance`, ... | Copy of the option's own plain fields |

`icon`, `groups`, `items`, `canInteract`, `onSelect`, `export`, `event`, `serverEvent`, `command`, `cooldownEnd` and `labelFn` are removed from the payload. Options added through the legacy qb-target exports (`qtarget = true`) receive only the entity handle in `onSelect`.

## Sub-menus
Give the opening option `openMenu = 'name'` and the child options `menuName = 'name'`. A **Go back** entry (priority 1000, translated with `go_back`) is added automatically; nested menus keep a history. The menu resets to the top when targeting closes.

```lua
exports['rsg-target']:addLocalEntity(npc, {
    { name = 'shop:open',  label = 'Shop', icon = 'fa-solid fa-store', openMenu = 'shop' },
    { name = 'shop:buy',   label = 'Buy',  menuName = 'shop', onSelect = function() end },
    { name = 'shop:sell',  label = 'Sell', menuName = 'shop', onSelect = function() end },
})
```

## Events and callbacks
| Name | Side | Description |
|---|---|---|
| `rsg-target:server:setEntityHasOptions` (net event, `netId`) | server | Flags a networked entity (`hasTargetOptions` state bag) so clients can be told when it is deleted. Validated: positive integer netId, entity exists, within 500 units of the player, max 30 requests / 5 s per player |
| `rsg-target:client:removeEntity` (net event, `netIds[]`) | client | Sent to everyone when flagged entities no longer exist; removes their options |
| `rsg-target:client:debug` (event) | client | Prints the payload as JSON (with `archetype` and `model` for entities). Used by the debug options |
| `rsg-target:server:getJobs` (rsg-core callback) | server | Returns `{ [jobName] = grade }` from `exports['rsg-core']:GetPlayerJobs(source)` (wrapped in `pcall`). Used for multi-job `groups` |
| `RSGCore:Client:OnPlayerLoaded`, `OnPlayerUnload`, `RSGCore:Player:SetPlayerData`, `RSGCore:Client:OnJobUpdate` | client | Listened to keep player data, items and jobs current |

```lua
-- await the held jobs yourself (client)
local jobs = RSGCore.Functions.AwaitCallback('rsg-target:server:getJobs', 5000)
```

## NUI messages
Lua → NUI (`SendNuiMessage`)

| `event` | Payload |
|---|---|
| `visible` | `state` boolean, shows/hides the menu |
| `setTarget` | `options` (lists), `zones`, `quick` (label or nil), `keyboard`, `gamepad` |
| `leftTarget` | aimed target lost, eye turns grey |
| `markers` | `markers` `{ x, y, a }[]` in screen coordinates (`a` = aimed at), `style` (sent once) |

NUI → Lua (`RegisterNUICallback`)

| Callback | Data | Description |
|---|---|---|
| `select` | `[listKey, optionId, zoneIndex?]` | Runs an option. Validated as a table with a numeric id, list must exist |
| `close` | none | Releases focus and closes targeting |

The NUI follows the RSG house style (Roboto, monochrome leather & gold, no vignette).

## Legacy (qb-target style) exports
Registered on `rsg-target` for older scripts. Options are converted: `job`/`gang`/`citizenid` → `groups` (with grades), `item` → `items`, `action` → `onSelect`, `type = 'server'/'command'` → `serverEvent`/`command`.

| Export | Notes |
|---|---|
| `AddBoxZone(name, center, length, width, options, targetoptions)` | `minZ`/`maxZ` are world heights; box is centred between them unless `useZ` |
| `AddPolyZone(name, points, options, targetoptions)` | |
| `AddCircleZone(name, center, radius, options, targetoptions)` | |
| `RemoveZone(id)` | |
| `AddTargetEntity(entities, options)` / `RemoveTargetEntity(entities, labels)` | Networked entities use `addEntity`, others `addLocalEntity` |
| `AddTargetModel(models, options)` / `RemoveTargetModel(models, labels)` | |
| `AddGlobalPed/Vehicle/Object/Player(options)` and `Remove...(labels)` | |
| `AddTargetBone(bones, options)` | Bones are not supported: options are added to **all vehicles** and a warning is printed |
| `AddEntityZone`, `RemoveTargetBone` | Not supported (warning only) |

## Code examples

### Local entity (spawned NPC)
```lua
local ped = CreatePed(model, coords.x, coords.y, coords.z, heading, false, false)

exports['rsg-target']:addLocalEntity(ped, {
    {
        name = 'trader:talk',
        icon = 'fa-solid fa-comments',
        label = locale('talk'),
        distance = 2.0,
        onSelect = function(data)
            TriggerEvent('my-resource:client:talk', data.entity)
        end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exports['rsg-target']:removeLocalEntity(ped)
    DeleteEntity(ped)
end)
```

### Zone with job, duty and items
```lua
local zone = exports['rsg-target']:addSphereZone({
    name = 'sheriff:armory',
    coords = Config.ArmoryCoords,
    radius = 1.5,
    options = {
        {
            name = 'sheriff:armory:open',
            icon = 'fa-solid fa-gun',
            label = locale('open_armory'),
            distance = 2.0,
            groups = { sheriff = 1, deputy = 0 }, -- sheriff grade 1+, or any deputy
            requiresDuty = true,
            items = 'badge',
            serverEvent = 'sheriff:server:openArmory',
        },
    },
})
```

### Dynamic label, cooldown and priority
```lua
exports['rsg-target']:addModel('p_chair01x', {
    {
        name = 'chair:sit',
        icon = 'fa-solid fa-chair',
        priority = 10,           -- shown first and used by quick select
        cooldown = 3000,         -- hidden for 3 s after use
        label = function(entity, distance)
            return ('%s (%.1fm)'):format(locale('sit'), distance)
        end,
        onSelect = function(data) TriggerEvent('my-resource:client:sit', data.entity) end,
    },
})
```

### Server event (validate on the server!)
```lua
-- client option
{ name = 'shop:buy', label = locale('buy'), serverEvent = 'my-resource:server:buy' }

-- server
RegisterNetEvent('my-resource:server:buy', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- never trust data.entity / data.coords / data.distance: re-check distance, job and items here
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - Config.ShopCoords) > 3.0 then return end
    if Player.PlayerData.job.name ~= 'trader' then return end

    -- ... then do the purchase with server-side prices
end)
```

### Global options and cleanup
```lua
exports['rsg-target']:addGlobalPlayer({
    { name = 'player:give', icon = 'fa-solid fa-hand-holding', label = locale('give'), distance = 2.0,
      onSelect = function(data) TriggerEvent('my-resource:client:give', data.entity) end },
})
-- removed automatically when your resource stops; manual removal:
exports['rsg-target']:removeGlobalPlayer('player:give')
```

### Temporarily disable targeting
```lua
exports['rsg-target']:disableTargeting(true)   -- e.g. during a cutscene
-- ...
exports['rsg-target']:disableTargeting(false)

if exports['rsg-target']:isActive() then end
```

### Entity restricted to a part of the model
```lua
exports['rsg-target']:addModel('p_door01x', {
    { name = 'door:knock', label = locale('knock'), offset = vec3(0.5, 0.0, 0.5), offsetSize = 0.6,
      onSelect = function() end },
})
```

### Sub-menu
See [Sub-menus](#sub-menus).

### Update the label without re-registering
`label` as a function is the supported way: the text is recomputed whenever the target is re-evaluated, no re-adding needed.

## Security model
- `groups`, `items`, `requiresDuty`, `cooldown`, `distance`, `offset` and `canInteract` only decide what the **client shows**. A modified client can call your `serverEvent` directly.
- Every `serverEvent` handler must resolve the player with `RSGCore.Functions.GetPlayer(source)`, re-check job/grade, items, cooldowns and distance on the server, and use server-side prices and rewards. The payload (`entity` netId, `coords`, `distance`) is client supplied.
- rsg-target itself only has one client-to-server event, `rsg-target:server:setEntityHasOptions`. It cannot give items or money and is rate limited and distance checked.
- NUI callbacks (`select`, `close`) only act on options already registered in the local client; invalid input is ignored.
- Labels are inserted with `textContent` in the NUI (no HTML injection).

## Performance notes
- Idle cost is one `Wait(0)` thread polling the target key.
- While targeting: one raycast (two when nothing is hit) every 50-100 ms, zone checks against every registered zone each loop, one NUI message only when the options changed.
- The highlighter rescans every `ScanInterval` ms (line-of-sight raycasts only for usable entities) and only sends NUI updates when a marker moved.
- Reduce load by lowering `Config.Highlight.Radius`/`MaxDrawn`, turning off `Peds`/`Objects`, and keeping `IncludeGlobal = false`.
- Prefer `addModel`/`addLocalEntity`/zones over many `addGlobal*` options.

## Locales
`locales/*.json`, loaded by rsg-core (`locale('key')`). All 10 languages carry the same keys.

| Key | Used for |
|---|---|
| `go_back` | Sub-menu back entry |
| `notify_title`, `highlight_on`, `highlight_off` | `/targethighlight` notification |
| `debug_box`, `debug_sphere`, `debug_ped`, `debug_vehicle`, `debug_object` | Debug options (`Config.Debug`) |

Set the language with the `rsg:locale` convar, e.g. `setr rsg:locale de`.

## Troubleshooting
| Problem | Cause / fix |
|---|---|
| Nothing happens on Left Alt | Check the resource started after `rsg-core`, no NUI has focus, and the console for client errors |
| Scripts using `exports.ox_target` fail | Make sure the real `ox_target` is stopped/removed and `rsg-target` is started before them |
| Option never shows | Distance too small, `groups`/`items`/`requiresDuty` fail, option on cooldown, or `canInteract` returns false/errors. Turn on `Config.Debug` to test |
| Job option hidden for a second job | Needs `Config.MultiJob = true` and rsg-core `GetPlayerJobs`; the list refreshes on load / job change |
| Quick select does nothing | Another script consumes E, or no option is visible. Change `Config.QuickSelect.Key` |
| Eye icons missing | `/targethighlight` toggled off, `Config.Highlight.Enabled = false`, entity has only global options (`IncludeGlobal`), or no line of sight |
| Options stay after a script restarts | They are removed on `onClientResourceStop`; make sure the script re-adds them on start |
| `[rsg-target] option ... failed` | The callback of that option errored; fix it in the named resource |
| Console warning "Replacing existing target option" | Same `name` added twice by one resource; harmless, the latter wins |
| Version check fails | The server cannot reach GitHub or `rsg-versioncheckers` has no entry for this resource |

## Changelog
### 3.1.0
- **Multi job `groups`**: options now also match jobs the player holds but is not currently using (`Config.MultiJob`).
- **New option fields**: `requiresDuty`, `cooldown`, `priority`, and `label` as a function.
- **Quick select** key (default E) runs the top option without focusing; the NUI shows the key on that option.
- **Menu navigation**: keyboard (arrows, Enter, 1-9) and experimental gamepad (D-pad, A, B) while focused.
- **Highlighter toggle**: `/targethighlight`, saved per player.
- New locale keys `notify_title`, `highlight_on`, `highlight_off` in all 10 languages.

### 3.0.2
- **Fixed** a syntax error in `client/client.lua` (`\~=`) that stopped the whole client script loading.
- **Fixed** global options (`addGlobalOption`) from a stopped resource staying registered.
- **Fixed** a broken `onSelect` / `event` / `export` in another resource leaving targeting stuck open; actions run in `pcall`.
- **Fixed** the NUI `select` callback erroring when handed a non-table option list.
- **Security** `rsg-target:server:setEntityHasOptions` is rate limited (30 per 5 s per player) and requires the entity to be within 500 units of the player.
- **Optimised** highlighter only sends marker updates when a marker moved; server cleanup loop skips work while nothing is tracked.
- **Cleaned** blocked controls are one table + loop; removed the `exportHandler` wrapper, unused variables and the `escapeHtml` helper.
- **UX** option list scrolls (max 60% screen height); debug zones spawn next to the player.

### 3.0.1
- Fixed legacy exports dropping jobs/gangs/citizenids and keeping job grades; legacy `AddBoxZone` height/centre; sub-menu state reset on close; Esc closes the focused menu; `removeTarget` repeated-name bug; zone sprite limit off-by-one; netId validation on the server.

## ox_lib removed
- Zones: `@rsg-core/client/zones.lua`. Raycast: `RSGCore.Functions.RaycastCamera`. Nearby scans: `RSGCore.Functions.GetNearby*`. Progress check: `RSGCore.Functions.IsProgressActive`.
- Locales, `require` and table helpers come from the `@rsg-core/shared/*.lua` includes.
- The context-menu close check was removed (rsg-core has no context menu). Targeting still closes for the inventory and progress bars, and won't open while any NUI has focus.

Support: https://rexshack.tebex.store

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-target 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` | spawns debug zones/options (see client/debug.lua) |
| `Config.Toggle` | `false` | true: press key to open/close \| false: hold key |
| `Config.DefaultDistance` | `7.0` | default interact distance when an option has none |
| `Config.RaycastDistance` | `20.0` | how far the camera raycast reaches |
| `Config.CleanupInterval` | `10000` | (ms) server cleanup of deleted networked entities |
| `Config.Keys` | `table` |  |
| `Config.Target` | `0x8AAA0AD4` |  |
| `Config.Focus` | `0x07B8BEAF` |  |
| `Config.Close` | `0x53296B75` |  |
| `Config.QuickSelect` | `table` |  |
| `Config.Enabled` | `true` |  |
| `Config.Key` | `0xCEFD9220` |  |
| `Config.Label` | `'E'` |  |
| `Config.UI` | `table` |  |
| `Config.KeyboardNav` | `true` |  |
| `Config.Gamepad` | `true` |  |
| `Config.MultiJob` | `true` |  |
| `Config.DrawSprite` | `24` | max zone sprites drawn per frame (0 = disabled, limit 32) |
| `Config.SpriteColour` | `{ 155, 155, 155, 175 }` | r, g, b, a |
| `Config.SpriteHover` | `{ 255, 255, 255, 255 }` | r, g, b, a when looking at zone |
| `Config.Highlight` | `table` |  |
| `Config.Command` | `'targethighlight'` |  |
| `Config.Radius` | `10.0` |  |
| `Config.ScanInterval` | `500` |  |
| `Config.MaxDrawn` | `16` |  |
| `Config.Peds` | `true` |  |
| `Config.Vehicles` | `true` |  |
| `Config.Objects` | `true` |  |
| `Config.Zones` | `true` |  |
| `Config.IncludeGlobal` | `false` |  |
| `Config.RequireLineOfSight` | `true` |  |
| `Config.HeightOffset` | `0.15` |  |
| `Config.Size` | `22` |  |
| `Config.Pulse` | `true` |  |
| `Config.Colour` | `'#c8c8c8'` |  |
| `Config.HoverColour` | `'#6fbf73'` |  |

### Exports

**Client**

| Export | Arguments | File |
|---|---|---|
| `AddBoxZone` | `name, center, length, width, options, targetoptions` | `client/compat/rsg-target.lua` |
| `AddPolyZone` | `name, points, options, targetoptions` | `client/compat/rsg-target.lua` |
| `AddCircleZone` | `name, center, radius, options, targetoptions` | `client/compat/rsg-target.lua` |
| `RemoveZone` | `id` | `client/compat/rsg-target.lua` |
| `AddTargetBone` | `_, options` | `client/compat/rsg-target.lua` |
| `AddTargetEntity` | `entities, options` | `client/compat/rsg-target.lua` |
| `RemoveTargetEntity` | `entities, labels` | `client/compat/rsg-target.lua` |
| `AddTargetModel` | `models, options` | `client/compat/rsg-target.lua` |
| `RemoveTargetModel` | `models, labels` | `client/compat/rsg-target.lua` |
| `AddGlobalPed` | `options` | `client/compat/rsg-target.lua` |
| `RemoveGlobalPed` | `labels` | `client/compat/rsg-target.lua` |
| `AddGlobalVehicle` | `options` | `client/compat/rsg-target.lua` |
| `RemoveGlobalVehicle` | `labels` | `client/compat/rsg-target.lua` |
| `AddGlobalObject` | `options` | `client/compat/rsg-target.lua` |
| `RemoveGlobalObject` | `labels` | `client/compat/rsg-target.lua` |
| `AddGlobalPlayer` | `options` | `client/compat/rsg-target.lua` |
| `RemoveGlobalPlayer` | `labels` | `client/compat/rsg-target.lua` |
| `AddEntityZone` | `` | `client/compat/rsg-target.lua` |
| `RemoveTargetBone` | `` | `client/compat/rsg-target.lua` |

```lua
-- example
local result = exports['rsg-target']:AddBoxZone(name, center, length, width, options, targetoptions)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-target:server:getJobs` | server | `source, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-target:server:getJobs', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-target:client:removeEntity` | client | `arr` | `client/api.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/framework.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/framework.lua` |
| `RSGCore:Client:OnJobUpdate` | client | `` | `client/framework.lua` |
| `RSGCore:Player:SetPlayerData` | client | `val` | `client/framework.lua` |
| `rsg-target:server:setEntityHasOptions` | server | `netId` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-target:server:setEntityHasOptions', netId)
-- from a server script
TriggerClientEvent('rsg-target:client:removeEntity', source, arr)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
