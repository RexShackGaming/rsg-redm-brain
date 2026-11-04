# rsg-target – Developer Docs

## How it works
- `client/client.lua` – key listener + targeting loop. While the Target key is held (or toggled) it raycasts from the camera every 50–100 ms, resolves entity/zone options, filters them (`shouldHide`) and sends the visible list to the NUI.
- `client/api.lua` – all exports (ox_target-compatible). Options are stored per type: global peds/vehicles/objects/players, models, networked entities (by netId), local entities (by handle), global options and zones (`@rsg-core/client/zones.lua`).
- `client/highlight.lua` – every `Config.Highlight.ScanInterval` ms scans nearby peds/vehicles/objects/zones that have usable options and draws eye markers via NUI.
- `client/framework.lua` – rsg-core bridge that keeps player job/gang/citizenid and item counts in sync for `groups` / `items` checks.
- `client/compat/rsg-target.lua` – legacy qb-target style exports (`AddBoxZone`, `AddTargetModel`, …) converted to the new format.
- `client/compat/ox_target.lua` – answers `exports.ox_target:*` calls (resource also `provide`s `ox_target`).
- `server/server.lua` – flags networked entities that have options (`hasTargetOptions` state bag) and tells clients to drop options for deleted entities.

## Option fields
| Field | Type | Notes |
|---|---|---|
| `name` | string | Unique per resource; re-adding the same name replaces it |
| `label`, `icon`, `iconColor` | string | Shown in the menu |
| `distance` | number | Default `Config.DefaultDistance` |
| `groups` | string / string[] / `{ [name] = minGrade }` | job, gang or citizenid |
| `items`, `anyItem` | string / string[] / `{ [item] = amount }` | client-side check only |
| `canInteract` | function(entity, distance, coords, name) | return true to show |
| `offset`, `absoluteOffset`, `offsetSize` | vector3 / bool / number | restrict to part of a model |
| `openMenu` / `menuName` | string | sub-menus; Go back is added automatically |
| `onSelect` / `export` / `event` / `serverEvent` / `command` | | action, first match wins |

## Controls
- Target: `Config.Keys.Target` (Left Alt). Focus the list: Left Mouse. Close: Right Mouse or **Esc**.

## Security
`groups`/`items`/`canInteract` are client-side visibility checks only. Every `serverEvent` handler in your own resource must re-check the player, job, items and distance on the server; the payload (`entity` netId, `coords`, `distance`) is client-supplied.

## Changelog (this audit)
- Fixed legacy exports dropping jobs/gangs/citizenids (`table.unpack` truncation) and keeping job grades; no more mutating the options table while iterating it.
- Fixed legacy `AddBoxZone` height/centre (box was placed hundreds of metres too high / with wrong height when `useZ` was set); nil-safe zone options.
- `AddTargetBone` now warns that bones are unsupported.
- `RSGCore:Client:OnPlayerLoaded` is now registered as a net event, so job/item data refreshes on character load.
- Sub-menu state is reset when targeting closes (no longer reopens inside an old sub-menu).
- Esc now closes the focused menu.
- `removeTarget` no longer removes extra options when names repeat.
- Zone sprite limit off-by-one fixed; `shouldHide` always returns a boolean.
- Highlighter: option check before the line-of-sight raycast; marker style sent once instead of every frame.
- Server: netId validated as a positive integer.
- Removed FiveM-only entity outline native and other dead code.

## ox_lib removed
- Zones: `@rsg-core/client/zones.lua`. Raycast: `RSGCore.Functions.RaycastCamera`. Nearby scans: `RSGCore.Functions.GetNearby*`. Progress check: `RSGCore.Functions.IsProgressActive`.
- Locales, `require` and table helpers come from the `@rsg-core/shared/*.lua` includes.
- The context-menu close check was removed (rsg-core has no context menu). Targeting still closes for the inventory and progress bars, and won't open while any NUI has focus.
