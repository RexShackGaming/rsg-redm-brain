# rsg-herbalist – Developer & Server Owner Docs

Version 3.1.0 · Requires `rsg-core` (3.0.3+) and `rsg-inventory`. No ox_lib, no database tables.

## Contents
1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Exports](#exports)
4. [Events](#events)
5. [Usable items](#usable-items)
6. [Persistence](#persistence)
7. [Security model](#security-model)
8. [Server owner how-tos](#server-owner-how-tos)
9. [Troubleshooting](#troubleshooting)

## Architecture
| File | Side | Purpose |
|---|---|---|
| `shared/config.lua` | shared | Gameplay config, tonic recipes, mystery box |
| `shared/webhook_config.lua` | shared | Discord webhook categories |
| `shared/zones_data.lua` | shared | `Config.Zones` – herb zones (plant rotation + coords) |
| `shared/spawns.lua` | shared | `BuildHerbSpawns()` – deterministic spawn list used by both sides; `StripComposite()` |
| `client/exports.js` | client | `NativeCreateComposite` export (needs a JS buffer arg) |
| `client/controls.lua` | client | `IsPickupControlPressed()` shared by herbs + mystery box |
| `client/client.lua` | client | Herb streaming/gathering, crafting NUI, crafting anim/camera, tonic drinking |
| `client/mysterybox.lua` | client | Mystery box prop, prompt (rsg-core DrawText), open flow |
| `server/webhook.lua` | server | Queued Discord logger + anti-cheat violation counter (`Webhook.*`) |
| `server/server.lua` | server | Gather validation, regrowth, crafting, tonic use |
| `server/mysterybox.lua` | server | Box location, loot rolls, open validation |
| `server/versionchecker.lua` | server | GitHub version check (also logged to the `version` webhook) |
| `html/` | NUI | Tonic crafting menu (house leather & gold theme) |

Herb nodes are identified on the network by their integer index from `BuildHerbSpawns()` (zones sorted by id, coords in file order). Client and server **must** run the same `zones_data.lua`.

## Data formats
**Tonic recipe** (`Config.Tonics[n]`):
```lua
{ id = 'tonic_healing', label = 'locale_key', description = 'locale_key', image = 'tonic_healing.png',
  durationMs = 8000, ingredients = { { item = 'herb_yarrow', amount = 2 } },
  output = { item = 'tonic_healing', amount = 1 } }
```
**Tonic effect** (`Config.TonicEffects[itemName]`): `{ healthBoost = 0.0–1.0, staminaBoost = 0.0–1.0 }` – applied via `ENABLE_ATTRIBUTE_OVERPOWER` (0xF6A7C08DF2E28B28).

**Plant → item mapping**: the `toItem` table at the top of `server/server.lua`, keyed by the composite name without `COMPOSITE_LOOTABLE_` / `_INTERACTABLE`. Mappings to unregistered items are dropped (with a console warning) on start.

## Exports
| Export | Side | Params | Returns |
|---|---|---|---|
| `NativeCreateComposite(hash, x, y, z, onGround)` | client | composite hash, coords, bool | composite handle (internal use) |

There is intentionally no export/command to open the crafting menu – the `mortarpestle` item is the only entry point.

## Events
Client → server (all validated server-side):
| Event | Args | Validation |
|---|---|---|
| `rsg-herbalist:server:gathered` | `id` (number) | spawn exists, not already picked, cooldown, alive, distance ≤ `ScopeRangeGather`, CanAddItem |
| `rsg-herbalist:server:requestSync` | – | throttled 10 s |
| `rsg-herbalist:server:requestCraft` | `tonicId` (string) | enabled, alive, no pending craft, cooldown, job lock, recipe exists, ingredients |
| `rsg-herbalist:server:finishCraft` | – | pending craft exists, recipe time elapsed, ingredients re-checked, CanAddItem |
| `rsg-herbalist:server:cancelCraft` | – | clears pending craft |
| `rsg-herbalist:server:requestMysteryBox` | – | throttled 10 s |
| `rsg-herbalist:server:openMysteryBox` | – | box live, cooldown, alive, distance ≤ `scopeRangeGather`, free weight + CanAddItem |

Server → client: `client:SetSuppressed(id, suppressed, newPlant)`, `client:SyncState(ids, overrides)`, `client:ForceReload(id)`, `client:OpenTonicCrafting()`, `client:StartCraftProgress(durationMs)`, `client:ApplyTonicEffect(itemName)`, `client:SetMysteryBox(coord|nil)`.

## Usable items
- `mortarpestle` – opens the crafting menu (job lock checked on the server).
- Every key in `Config.TonicEffects` – drinks the tonic (shared `TonicUseCooldownMs`).

## Persistence
Nothing is stored in the database. Picked nodes, plant rotation and the box location live in server memory and reset on resource restart. Items are written through rsg-inventory exports (which also show the ItemBox and log with a reason: `rsg-herbalist:gather|craft|craft-refund|drink-tonic|mysterybox`).

## Security model
- The client only ever sends ids; items, amounts, recipes, durations and loot are decided from server config.
- Crafting removes ingredients only at `finishCraft`, after the server confirms the recipe duration elapsed – cancelling/disconnecting loses nothing and a client can't skip the timer.
- Rejected requests call `Webhook.FlagSuspicious`; a Discord alert fires once a player reaches `antiCheat.violationThreshold` in `violationWindowMs`. Nobody is auto-banned (single violations are often lag).
- Other scripts calling these events get no extra trust – the same checks apply.

## Server owner how-tos
- **Add a tonic**: add a recipe to `Config.Tonics`, its item to rsg-core items, an icon to the inventory images, label/description keys to all 11 locales, and optionally an entry in `Config.TonicEffects`.
- **Add herb spots**: add coords to a zone in `shared/zones_data.lua` (restart the resource; ids are rebuilt).
- **Job-lock crafting**: create `herbalist` via `/jobadmin`, set `Config.LockTonicCraftingToJob = true`.
- **Change language**: `setr rsg:locale de` in server.cfg.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `warning: item "x" ... is not registered` | Add the item to rsg-core items or fix the `toItem` mapping |
| `no item mapping for plant ...` | Add the composite to `toItem` in `server/server.lua` |
| Crafting icons missing | Copy `installation/images` into rsg-inventory images or change `Config.InventoryImagePath` |
| Webhooks silent | Set `Config.Webhook.enabled`, the category `enabled` and its `url` |
| Mystery box never appears | `Config.MysteryBox.enabled` and at least one entry in `coords` |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, GatherXP, ExtraYield }`. In `rsg-herbalist:server:gathered`, after the herb is added and the node suppressed, the server calls `AddXP(src, 'herbalism', GatherXP, ...)` and, when `ExtraYield` is on, rolls the `extra_yield` perk for one more herb (only if `CanCarry`). Server side only; skipped when rsg-skills is not started.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-herbalist 3.2.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` | leave off in production; verbose per-gather/per-craft tracing |
| `Config.InventoryImagePath` | `'nui://rsg-inventory/html/images/'` | Where the crafting UI loads item icons from (rsg-inventory's image folder). |
| `Config.ScopeRangeLoad` | `100.0` | distance at which a herb node starts streaming in |
| `Config.ScopeRangeUnload` | `120.0` | distance at which a loaded node streams back out |
| `Config.NearbyRange` | `15.0` | radius refreshed once/sec for interaction checks |
| `Config.PickupRange` | `3.0` | client-side distance within which a node can be picked |
| `Config.CompositeLoadTimeoutMs` | `10000` | max time to wait for a composite asset to stream in |
| `Config.GatherDurationMs` | `3000` | length of the gather progress bar |
| `Config.GatherProgressBarEnabled` | `false` | cancellable. |
| `Config.GatherCooldownMs` | `2500` | server-side minimum time between gather attempts per player |
| `Config.ScopeRangeGather` | `3.5` | server-side distance check before a gather is accepted |
| `Config.SuppressionWearoffSeconds` | `10 * 60` | how long a gathered node stays empty before it regrows |
| `Config.TonicCraftingEnabled` | `true` | master switch for the tonic crafting system |
| `Config.TonicCraftCooldownMs` | `1500` | server-side minimum time between craft requests per player |
| `Config.TonicCraftProgressBarEnabled` | `false` | always completes once that time passes. |
| `Config.TonicCraftAnim` | `table` | always use the generic standing scenario instead. |
| `Config.TonicCraftCamera` | `table` | the player is facing or where they are. |
| `Config.TonicAttributeIndex` | `table` | changes that ordering. value is 0.0-1.0 (fraction of the core topped up). |
| `Config.TonicDrinkAnim` | `table` | Deleted automatically once the clips finish. |
| `Config.TonicEffects` | `table` | tonic. Tonics not listed here do nothing extra when consumed. |
| `Config.TonicUseCooldownMs` | `5 * 60 * 1000` | 5 minutes |
| `Config.LockTonicCraftingToJob` | `false` | the database via rsg-core's /jobadmin (see installation/shared_jobs.lua for grades). |
| `Config.TonicCraftingJobName` | `'herbalist'` |  |
| `Config.MysteryBox` | `table` |  |
| `Config.Tonics` | `table` | output      { item = <inventory item name>, amount = <amount granted> } |
| `Config.Skills` | `table` | rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started. |
| `Config.Enabled` | `true` |  |
| `Config.Skill` | `'herbalism'` |  |
| `Config.GatherXP` | `5` |  |
| `Config.ExtraYield` | `true` |  |
| `Config.Webhook` | `table` |  |
| `Config.Zones` | `table` |  |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-herbalist:client:SetSuppressed` | client | `id, suppress, newPlant` | `client/client.lua` |
| `rsg-herbalist:client:SyncState` | client | `suppressedIds, plantOverrides` | `client/client.lua` |
| `rsg-herbalist:client:ForceReload` | client | `id` | `client/client.lua` |
| `RSGCore:Player:SetPlayerData` | client | `data` | `client/client.lua` |
| `rsg-herbalist:client:OpenTonicCrafting` | client | `` | `client/client.lua` |
| `rsg-herbalist:client:StartCraftProgress` | client | `durationMs` | `client/client.lua` |
| `rsg-herbalist:client:ApplyTonicEffect` | client | `itemName` | `client/client.lua` |
| `rsg-herbalist:client:SetMysteryBox` | client | `coord` | `client/mysterybox.lua` |
| `rsg-herbalist:server:requestMysteryBox` | server | `` | `server/mysterybox.lua` |
| `rsg-herbalist:server:openMysteryBox` | server | `` | `server/mysterybox.lua` |
| `rsg-herbalist:server:gathered` | server | `id` | `server/server.lua` |
| `rsg-herbalist:server:requestSync` | server | `` | `server/server.lua` |
| `rsg-herbalist:server:requestCraft` | server | `tonicId` | `server/server.lua` |
| `rsg-herbalist:server:finishCraft` | server | `` | `server/server.lua` |
| `rsg-herbalist:server:cancelCraft` | server | `` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-herbalist:server:requestMysteryBox')
-- from a server script
TriggerClientEvent('rsg-herbalist:client:SetSuppressed', source, id, suppress, newPlant)
```

### Useable items

`mortarpestle`

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
