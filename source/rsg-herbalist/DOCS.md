# rsg-herbalist – Developer & Server Owner Docs

Version 3.5.5 · Requires `rsg-core` (3.0.3+), `rsg-inventory` and `oxmysql`. No ox_lib.

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
| `server/webhook_config.lua` | server | Discord webhook categories (server-only so the URLs are never sent to clients) |
| `server/utils.lua` | server | Shared helpers `Herbalist.Notify` / `Herbalist.IsDead` |
| `shared/zones_data.lua` | shared | `Config.Zones` – herb zones (plant rotation + coords) |
| `shared/spawns.lua` | shared | `BuildHerbSpawns()` – deterministic spawn list used by both sides; `StripComposite()` |
| `client/exports.js` | client | `NativeCreateComposite` export (needs a JS buffer arg) |
| `client/controls.lua` | client | `IsPickupControlPressed()` shared by herbs + mystery box |
| `client/client.lua` | client | Herb streaming/gathering, crafting NUI, crafting anim/camera, tonic drinking |
| `client/mysterybox.lua` | client | Mystery box prop, prompt (rsg-core DrawText), open flow |
| `server/webhook.lua` | server | Queued Discord logger + anti-cheat violation counter (`Webhook.*`) |
| `server/database.lua` | server | `Herbalist.LoadState` / `Herbalist.SaveState` (`rsg_herbalist_state`) |
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
Server state is stored in `rsg_herbalist_state` (`key` VARCHAR(50) primary key, `value` LONGTEXT JSON), created on start while `Config.AutoDatabase = true`, otherwise import `installation/install.sql`. No resource KVP is used, so the server creates no `db` folder. Gathering and buyer placement are ignored until the saved state has loaded. Regrow timers and regrown plants are saved in the row `nodes_v1` (written every minute when changed, and on stop) and restored on start; saved state is ignored if the number of spawn nodes changed, because ids are list positions. To reset every node, stop the resource and delete that row. The box location lives in server memory and resets on restart. Nodes whose plant has no registered item are re-pointed to a gatherable plant of the same zone at start, or disabled if the zone has none (a console warning lists them). Items are written through rsg-inventory exports (which also show the ItemBox and log with a reason: `rsg-herbalist:gather|craft|craft-refund|drink-tonic|mysterybox`).

## Tonic quality and field guide (3.4.0)
- **Quality:** on `finishCraft` the server reads the crafter's herbalism level (`rsg-skills:GetLevel`), picks the tier from `Config.TonicQuality` and stores it as `info.tonic_tier` on the item (not `info.quality`, which rsg-inventory uses for decay). Tiers stack separately. When a tonic is used the server removes the exact slot used, reads its tier and sends `boost` to the client, which multiplies the boost (capped at a full core). `Config.Tonics[n].minLevel` is enforced in `requestCraft`; the menu only greys recipes out. If rsg-skills is off, there is no level gating and every tonic is the lowest tier.
- **Field guide:** `Herbalist.RecordFound(src, Player, item, amount)` (server) adds to the character metadata `herbalist_guide` (`{ [item] = count }`) after every successful gather, extra-yield herb and mystery box reward; the first time an item appears the player is notified and gets `Config.FieldGuide.DiscoveryXP`. The `/<Config.FieldGuide.Command>` command asks the server callback `rsg-herbalist:server:getGuide` for the herb list and the player's counts; the client only displays them.

## Drying, teas and the herb buyer (3.5.0)
- **Recipes:** drying and tea recipes live in `Config.Tonics` with `category = 'drying'|'tea'` and share the whole craft pipeline (server timer, ingredient check, level gate, refunds). `quality = false` keeps dried herbs out of the quality system. A recipe whose items aren't registered is skipped (`HerbalistRecipeValid`).
- **Effects:** `Config.TonicEffects[item]` accepts `thirstBoost` (HUD thirst points, applied client-side with `hud:client:UpdateThirst`), plus `group` and `cooldownMs`. Cooldowns are tracked per group, so a tea never blocks a tonic.
- **Buyer:** `server/buyer.lua`. Locations are `Config.Buyer.locations` plus admin-placed ones saved in the `rsg_herbalist_state` row `buyers_v1` (`/addherbbuyer`, `/removeherbbuyer`, permission `Config.Buyer.AdminPermission`). The client opens the menu through the callback `rsg-herbalist:server:getBuyerStock` and sells with the event `rsg-herbalist:server:sell(slot, amount)`. The server validates the cooldown, the player's distance to a buyer, that the slot holds a sellable item, and caps the amount; the price comes from `Config.Buyer.prices` times the tier's `priceMult` (and rsg-economy when running). Items are removed first and returned if the payout fails. Sales can be logged with the `sales` webhook category.

## Security model
- The client only ever sends ids; items, amounts, recipes, durations and loot are decided from server config.
- Crafting removes ingredients only at `finishCraft`, after the server confirms the recipe duration elapsed – cancelling/disconnecting loses nothing and a client can't skip the timer.
- Crafting requests are rejected unless the player holds a `mortarpestle`; a pending craft that is never finished expires after its duration + 15 s.
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

Generated from the source of **rsg-herbalist 3.5.5**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | Create `rsg_herbalist_state` on start; `false` = import `installation/install.sql`. |
| `Config.Debug` | `false` | leave off in production; verbose per-gather/per-craft tracing |
| `Config.InventoryImagePath` | `'nui://rsg-inventory/html/images/'` | Where the crafting UI loads item icons from (rsg-inventory's image folder). |
| `Config.ScopeRangeLoad` | `100.0` | distance at which a herb node starts streaming in |
| `Config.ScopeRangeUnload` | `120.0` | distance at which a loaded node streams back out |
| `Config.NearbyRange` | `15.0` | radius refreshed once/sec for interaction checks |
| `Config.PickupRange` | `3.0` | client-side distance within which a node can be picked |
| `Config.CompositeLoadTimeoutMs` | `10000` | max time to wait for a composite asset to stream in |
| `Config.GatherDurationMs` | `3000` | length of the gather progress bar |
| `Config.GatherProgressBarEnabled` | `false` | cancellable. |
| `Config.Buyer` | see config | herb buyer NPC settings and price list |
| `Config.TonicQuality` | see config | tier list `{ key, level, boost, label }` |
| `Config.Tonics[n].minLevel` | per recipe | herbalism level required to brew |
| `Config.FieldGuide` | `Enabled = true`, `Command = 'herbguide'`, `DiscoveryXP = 10` | field guide switch, command name, first-discovery XP |
| `Config.PickupControls` | `{0xF6BB7378}` | controls that count as pick up (the herb prompt control; R is excluded) |
| `Config.LockAllowAnyHeldJob` | `true` | job lock accepts any held rsg-core multi-job job |
| `Config.AllowPushToTalkWhileOpen` | `true` | block game controls but keep push-to-talk while the crafting UI is open (`Config.PushToTalkControls`) |
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
