# rsg-moonshine 3.7.1 — Developer Docs

RSG Framework (rsg-core 3.x) · Lua 5.4 · NUI · no ox_lib

## Contents
1. [Overview and file layout](#1-overview-and-file-layout)
2. [Dependencies](#2-dependencies)
3. [Installation](#3-installation)
4. [How a still works](#4-how-a-still-works)
5. [Data formats](#5-data-formats)
6. [Server callbacks](#6-server-callbacks)
7. [NUI actions](#7-nui-actions)
8. [Events](#8-events)
9. [Exports](#9-exports)
10. [Commands](#10-commands)
11. [Items](#11-items)
12. [Configuration reference](#12-configuration-reference)
13. [Webhooks](#13-webhooks)
14. [Integration with other scripts](#14-integration-with-other-scripts)
15. [Database](#15-database)
16. [Security model](#16-security-model)
17. [Locales](#17-locales)
18. [How-tos with examples](#18-how-tos-with-examples)
19. [Troubleshooting](#19-troubleshooting)

---

## 1. Overview and file layout

Players use a `moonshine_still` item to place a copper still. They load ingredients and fuel through a NUI menu, wait for batches to brew in real time, then bottle the output into empty jugs. Bottles carry a quality and an optional custom label and can be sold to bootleggers. Law can raid stills. Map stills (props already in the world) work too.

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest, version, dependencies, NUI files, locale files |
| `shared/config.lua` | All options and recipes. Also builds `Config.BuyerSpots` (client and server read it) |
| `server/sv_config.lua` | `SvConfig.Webhooks` — server only, so webhook URLs are never sent to clients |
| `server/webhooks.lua` | Discord webhook queue. Globals: `WebhookLog(event, src, title, desc, extra)` and `CoordsField(coords)` |
| `server/server.lua` | Still state, brewing simulation, callbacks, NUI actions, placing, raiding, bootlegger sales |
| `server/versionchecker.lua` | Compares the manifest version with the rsg-versioncheckers repo |
| `client/client.lua` | Prop streaming, particle effects, NUI, placement (rsg-gizmo), buyer targets |
| `client/teleport.lua` | Speakeasy hatch teleports (hold prompt) |
| `html/` | The menu (`index.html`, `style.css`, `script.js`) |
| `locales/*.json` | 11 languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |
| `installation/rsg-moonshine.sql` | Manual database install |
| `installation/shared_items.lua` | Items to add to `rsg-core/shared/items.lua` |

## 2. Dependencies

| Resource | Use |
|---|---|
| `rsg-core` | Locales, notify, callbacks, progress bar, player data |
| `rsg-inventory` | Items (`GetItemCount`, `GetItemsByName`, `AddItem`, `RemoveItem`, `CanAddItem`) |
| `rsg-target` | Targets on still props, map still models and buyer zones |
| `rsg-gizmo` | Still placement preview, with server side `IsPlacementValid` |
| `oxmysql` | Database |
| `rsg-skills` *(optional)* | Moonshining skill, level and xp (`Config.UseSkills`) |
| `rsg-reputation` *(optional)* | Honor changes on sales and raids (`Config.Reputation`) |

Optional resources are only used while they are `started`; the script falls back cleanly.

## 3. Installation

1. Add the items in `installation/shared_items.lua` to `rsg-core/shared/items.lua` (skip any that already exist) and copy matching images to `rsg-inventory/html/images/`.
2. Start order: `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `oxmysql`, then `rsg-moonshine`.
3. The table is created automatically. For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-moonshine.sql`.
4. Optional: put webhook URLs in `server/sv_config.lua`.

## 4. How a still works

**Lazy, restart-safe brewing.** Brewing is simulated from `(saved state, last_tick)` rather than a running timer per still:

```
simulate(still, now):
  elapsed = now - last_tick
  loop (at most 100 steps):
    no distilling and wash > 0, fuel > 0, tank room?  -> wash -= 1, batch_left = recipe.time
    no fermenting and a full batch in the hopper and wash < Ferment.maxWash? -> consume ingredients, ferment_left = recipe.ferment or Ferment.time
    step = min(elapsed, ferment_left / ferm_rate, min(work_left / heat.speed, fuel / (heat.burn * env.burn)))
    fermenting always advances (ferm_rate = weather factor); distilling or a second run only advance while there is fuel
    batch finished?  -> output += recipe amount, weighted quality and proof, roll explosion risk (x heat.risk)
    second run finished? -> output = volume * Rerun.yield, proof * Rerun.proofMult, quality + Rerun.quality, roll explosion risk
```

**Pipeline (3.4.0).** hopper → ferment (wash, no fuel) → distil (fuel, heat) → tank → optional second run → cut when bottling → optional oak cask.

**Fermentation.** A full batch of ingredients leaves the hopper and ferments for `recipe.ferment` (default `Config.Ferment.time`) seconds, then becomes wash. Up to `Config.Ferment.maxWash` batches wait for the still. Recipes can set `ferment = seconds`.

**Heat.** `Config.Heat` lists the levels (`key`, `speed`, `burn`, `quality`, `proof`, `risk`, `smoke`). The owner or a trusted person picks one with the `setHeat` action; it is saved per still. `speed` scales distilling, `burn` the fuel use, `quality`/`proof` shift each finished batch, `risk` multiplies the explosion chance and `smoke` scales the smoke particles and the smell radius.

**Proof.** A first run has `Config.Proof.first ± variance` (plus the heat shift). `rerun` takes the tank, runs it again for `Config.Rerun.time` seconds (needs fuel) and returns `yield` of the volume at `proofMult` times the proof, capped at `Proof.max`. Mixing fresh batches into the tank allows another run. Bottles carry `info.proof`; the sale price is multiplied by `clamp(proof / Proof.priceRef, minPriceMult, maxPriceMult)`.

**Cuts.** When bottling the player picks `tight`, `normal` or `loose` (`Config.Cuts.options`): `yield` is the share of the tank that is kept, `quality` shifts the bottle quality and `taint` is the percent chance the whole bottling is toxic at level 1. The chance falls to 0 at `Cuts.safeLevel`. Toxic bottles carry `info.meta.tainted = true` (nested, so the inventory does not show it, they look like normal bottles) and the bootlegger refuses them with a notification. Other scripts read it with `GetBottleInfo(...).tainted`.

**Oak cask.** With `Config.Cask.enabled`, an owner fits a `moonshine_cask` item (`installCask`), moves up to `capacity` bottles of the tank into it (`age`) and bottles it later (`collectCask`, same cuts). Every `stepTime` seconds adds `qualityPerStep` quality (max `maxBonus`) and evaporates `evaporation` of the volume (max `maxLoss`). Opening the cask freezes the result. Packing up the still returns the cask item, but only when the cask is empty.

**Materials.** `Config.Materials[key] = { item, quality, wear, risk }`. `copper` is the default (and what every older still is); `tin` uses `moonshine_still_tin`. The use handler for each item asks the client to place a still of that material; the server re-checks the material and consumes the matching item. `quality` shifts every batch (half for a second run), `wear` multiplies grime added and `risk` multiplies the explosion chance. Packing up returns the item of the still's material.

**Ingredient quality.** Loading takes items stack by stack and averages their `info.quality` (missing = `Config.Ingredients.default`) into `mash_q`. When a batch starts fermenting it moves `mash_q → ferment_q → wash_q` (weighted average of the wash waiting) `→ batch_q` when distilling starts. The finished batch gets `(batch_q - default) * weight` quality. Wash drawn from a barrel carries `info.quality = wash_q`, and pouring it into a still merges it back in.

**Law inspection.** The target option `Inspect Still` is shown to on duty law (`Config.Inspect.time` ms progress). The server event `rsg-moonshine:server:inspect(id)` re-checks distance, throttle and the law job and sends a read only report (material, grime, fire, running or cold, tank size; a barrel reports its wash). It never changes the still. Webhook event `inspect` (off by default).

**Wear.** `Config.Wear`: a finished batch adds `perBatch` wear (second run `rerun`), max 100. Quality is reduced by `wear / 100 * maxQualityLoss` and the explosion chance multiplied by `1 + wear / 100 * (maxRiskMult - 1)`. The `clean` action sets wear to 0 using `cleanAmount` of `cleanItem`, and only when no batch or second run is running.

**Cooling water.** `Config.Cooling`: the `addWater` action adds `seconds` of cooling per `item` (max `max`). Distilling and second runs use `use` cooling seconds per real second. When the tank is empty while running, `dry` accumulates (work seconds). At the end of the run `dryFrac = dry / run time`: yield is reduced by `dryYieldLoss * dryFrac`, quality by `dryQuality * dryFrac` and the explosion chance multiplied by `1 + dryRisk * dryFrac`.

**Taste test.** `Config.Taste`: the `sample` action (`{ cut }`, needs `minVolume` in the tank) removes `cost` spirit, rolls the poison chance for that cut and stores the result on the still. Bottling with that same cut uses the stored result instead of rolling again. The result is stored per cut (`sample = { tight = false, loose = true }`) and sampling the same cut again costs nothing and does not re-roll. Any change to the tank (new batch, second run, bottling, cask) clears it. The cask has no sample.

**Fermenting barrels.** `Config.Barrel` adds a second kind of placeable (`kind = 'barrel'`, stored in the same table). A barrel runs only the fermentation step: it holds `Barrel.maxWash` batches and has no fuel, tank or heat. `collectWash` turns the wash into `Barrel.washItem` items (`info = { recipe = key }`, one item per batch); `loadWash` at a still with that recipe selected removes matching items and adds them to the still's wash (up to `Ferment.maxWash`). The menu hides the firebox, tank, cuts and cask for barrels, and only these actions work on one: `selectRecipe, clearRecipe, load, unload, collectWash, trust, untrust, pickup`. Barrels share the access rules, trust list, raid/destroy and pick up behaviour of stills, and use `Barrel.minDist` instead of `MinStillDist`.

**Weather and night.** The server reads `GlobalState.rsgWeather.weather` and `GlobalState.rsgTime.time` from rsg-weather (neutral if it is not running). `Config.Environment` sets fermentation speed (cold/wet/sunny), fuel burn (cold/wet) and the smoke and smell range (wet, cold and night shrink it). The menu shows a hint when the weather matters.

A background tick (`Config.TickInterval`) keeps stills advancing in memory and syncs the brewing flag (smoke and fire effects) to nearby players. The database is only written on player actions and on resource stop, so a server crash replays the time correctly from the last save.

**Quality.** Each finished batch has quality `Quality.base + op_level * Quality.perLevel ± Quality.variance` (1–100). `op_level` is the level of the last person who loaded ingredients. The tank holds a weighted average. Bottles collected from the still carry `info.quality` (and `info.label` when set).

**Explosion risk.** When a batch finishes, `Config.Risk` rolls `baseChance * (1 - (op_level - 1) / (safeLevel - 1))` percent, so new moonshiners risk more and level `safeLevel` and above are safe. A blown still is deleted with its hopper and tank. Map stills never explode.

**Access.** With `Config.OwnerOnly = true` only the owner and trusted people can use a still. Map stills are open to everyone. Only the owner can trust people, remove them or pack up the still.

**Visibility.** The server only tells a player about stills within `Config.SyncDist`. The client asks again every 6 seconds and spawns props within `Config.SpawnDist`.

## 5. Data formats

Server still (`Stills[id]`):

```lua
{
    id = 12, kind = 'still',                   -- 'still' or 'barrel'
    citizenid = 'ABC12345',                    -- 'world' for map stills
    coords = vector3(x, y, z), heading = 90.0,
    recipe = 'moonshine',                      -- recipe key or nil
    material = 'copper', mash_q = 62.5, ferment_q = 60, wash_q = 58, batch_q = 55,   -- ingredient quality, nil when empty
    wear = 24, water = 900, dry = 0,           -- grime, cooling seconds, dry seconds in the current run
    wash = 1, ferment_left = 900,              -- fermented batches waiting, seconds left on the fermenting batch or nil
    heat = 'medium', proof = 90, reran = false, -- fire heat, tank proof (nil when empty), true after a second run
    rerun_left = nil, rerun_vol = 0,           -- second run seconds left and the volume in the pot
    cask = true, cask_recipe = 'moonshine', cask_vol = 10, cask_q = 60, cask_proof = 120, cask_start = 1732450000,
    hopper = { corn = 5, water = 2 },          -- item = count loaded
    output = 10, fuel = 600,                   -- bottles in the tank, seconds of fuel
    batch_left = 300,                          -- seconds left on the running batch or nil
    last_tick = 1732450000,                    -- os.time() the state is valid for
    quality = 62, op_level = 3,                -- tank quality, level of the last loader
    trusted = { { cid = 'DEF67890', name = 'John Marston' } },
    label = "Granny's Best",                   -- bottle label or nil
}
```

Public still (sent to clients): `{ id, coords, heading, brewing = bool, kind = 'still'|'barrel', heat = 'low'|'medium'|'high', world = true|nil }`.

Bottle item (what `rsg-inventory` stores):

```lua
{ name = 'moonshine_apple', amount = 5, info = { quality = 62, proof = 140, label = "Granny's Best", meta = { tainted = true } } }  -- meta only when toxic
```

The inventory shows `quality` as a bar and lists the other `info` values in the item panel.

NUI state (`getState` / `action` result): `id, kind, material, ingQ, burnRate, wear, water, maxWater, waterStep, waterHave, cleanHave, dry, sample, taste, washHave, washItem, isOwner, canUse, recipe, output, outputCap, maxBatches, hopperEmpty, fuel, maxFuel, xp, level, levelXp, nextXp, quality, label, labelMax, ownerOnly, trusted, trustedMax, jugs, heat, heats[], proof, proofMax, wash, maxWash, reran, weather, night, cuts[], cask, ferment, rerun, fuels[], recipes[], queued, batch, status`. `status` is one of `idle, fermenting, brewing, rerun, waiting, full, nofuel`.

## 6. Server callbacks

All use `RSGCore.Functions.CreateCallback`. Every handler validates the player and distance on the server.

| Name | Args | Returns |
|---|---|---|
| `rsg-moonshine:server:getStills` | — | public stills within `Config.SyncDist` (empty list if the player has no character) |
| `rsg-moonshine:server:getState` | `id` | NUI state, or `nil` when too far, throttled (250 ms) or the still is gone |
| `rsg-moonshine:server:action` | `id, action, data` | NUI state after the action, or `nil` (rejected, too far, still gone or packed up) |
| `rsg-moonshine:server:getWorldStill` | `coords` (vector3) | public data for a map still; creates the saved row on first use (cap, cooldown and optional allow-list apply) |
| `rsg-moonshine:server:sell` | `index` (buyer spot) | `true` after a sale, otherwise `nil` |

Client example:

```lua
local state = RSGCore.Functions.AwaitCallback('rsg-moonshine:server:getState', 5000, stillId)
if state then print(state.status, state.output .. '/' .. state.outputCap) end
```

## 7. NUI actions

The menu posts `action` to the client, which forwards `rsg-moonshine:server:action(id, action, data)`. Actions are throttled to one per 300 ms per player.

| Action | `data` | Who | Effect |
|---|---|---|---|
| `selectRecipe` | `{ recipe }` | can use | Needs the level, and an empty still |
| `clearRecipe` | — | can use | Back to the recipe list (still must be empty) |
| `load` | `{ item, amount }` | can use | Moves ingredients into the hopper (capped by space and what you carry) |
| `loadFuel` | `{ item, amount }` | can use | Adds fuel seconds (capped by `Config.MaxFuel`) |
| `unload` | `{ item }` | can use | Takes an ingredient back out of the hopper |
| `collect` | `{ cut }` | can use | Bottles the tank with the chosen cut (`tight`, `normal`, `loose`, default `normal`). One empty jug per bottle; bottles carry quality, proof, label and maybe `meta.tainted`; gives xp |
| `clean` | — | can use | Scrubs the still clean (uses `Config.Wear.cleanItem`) |
| `addWater` | `{ amount }` | can use | Pours cooling water (uses `Config.Cooling.item`) |
| `sample` | `{ cut }` | can use | Tests a sample of the tank for the cut |
| `collectWash` | — | can use (barrels) | Takes all wash out of a barrel as wash items |
| `loadWash` | — | can use (stills) | Pours carried wash of the still's recipe into the still |
| `setHeat` | `{ heat }` | can use | Sets the fire heat (`low`, `medium`, `high`) |
| `rerun` | — | can use | Puts the tank back in the pot for a second run (once per tank, no batch running) |
| `installCask` | — | can use | Fits a `moonshine_cask` item to the still |
| `age` | — | can use | Moves the tank (up to the cask capacity) into the cask and starts ageing |
| `collectCask` | `{ cut }` | can use | Ends ageing and bottles the cask with the chosen cut |
| `setLabel` | `{ label }` | can use (not map stills) | Sets or clears the bottle label (empty string clears) |
| `trust` | — | owner | Trusts the nearest other player within `Config.TrustDist` |
| `untrust` | `{ cid }` | owner | Removes a trusted person |
| `pickup` | — | owner | Returns the still item and leftover fuel (still must be empty) |

Client NUI callbacks: `opened`, `close`, `uiError`, `action`.

## 8. Events

| Event | Side | Args | Notes |
|---|---|---|---|
| `rsg-moonshine:server:placeStill` | server (net) | `coords, heading, kind, material` | `kind` is `still` or `barrel`, `material` is a `Config.Materials` key (stills only, default `copper`). Needs the matching item, distance, limits, zones and `rsg-gizmo:IsPlacementValid` |
| `rsg-moonshine:server:inspect` | server (net) | `id` | Law inspection. Needs a law job, distance and waits `Config.Inspect.time` between inspections. Read only |
| `rsg-moonshine:server:destroy` | server (net) | `id` | Law raid. Needs a law job (and duty if `LawRequireDuty`), distance, and waits `DestroyTime` between raids |
| `rsg-moonshine:client:placeStill` | client | `kind, material` | Starts the gizmo placement (fired by using the still, tin still or barrel item) |
| `rsg-moonshine:client:syncStill` | client | `still` | Public still data for a nearby still |
| `rsg-moonshine:client:removeStill` | client | `id` | Still deleted (packed up, raided or exploded) |
| `rsg-moonshine:client:explode` | client | `coords` | Visual and sound only, no damage |

## 9. Exports

All exports are server side: `exports['rsg-moonshine']:Name(...)`. They never hand out the live still table, only copies.

| Export | Returns | Notes |
|---|---|---|
| `GetBottleInfo(src, slot)` | `{ item, quality, proof, tainted, label, price }` or `nil` | A moonshine bottle in the player's inventory slot. `quality` defaults to `Config.Quality.defaultSold` for old stock; `price` is the bootlegger price before any skill bonus |
| `GetBottlePrice(item, quality?, proof?)` | number or `nil` | Price per bottle (recipe price × quality multiplier × proof multiplier when `proof` is given). `nil` when the item is not moonshine |
| `GetStillAt(coords, radius?)` | still data or `nil` | Nearest still within `radius` (default `2.0`). `coords` must be a `vector3` |
| `GetStills(citizenid?)` | list of still data | Stills owned by that citizen, or every still (map stills included) when `nil` |
| `DestroyStill(id, reason?)` | `true`, or `false, reason` | Reasons: `invalid`, `not_found`, `world` (map stills cannot be removed). Deletes the still, its hopper and tank, updates every client and logs the `destroy` webhook with your reason |
| `GetSkillLevel(src)` | number or `nil` | Moonshiner level from rsg-skills, or the built-in rep xp when rsg-skills is not running |

Still data: `{ id, kind, material, owner, world, coords, heading, recipe, brewing, output, quality, proof, heat, wash, cask, caskVolume, label, fuel, trusted }` (`owner` is a citizenid or `'world'`, `trusted` is the number of trusted people). It can be up to `Config.TickInterval` seconds old.

```lua
-- consume script: stronger effect for better moonshine
local info = exports['rsg-moonshine']:GetBottleInfo(src, slot)
if info then
    local strength = info.quality / 100
    print(('%s "%s" strength %.2f'):format(info.item, info.label or '-', strength))
end

-- shop or trader: pay the same rate as the bootlegger
local unit = exports['rsg-moonshine']:GetBottlePrice('moonshine_apple', 80)   -- e.g. 9.6 for a recipe price of 8

-- MDT / raid list: where does a suspect have stills?
for _, still in ipairs(exports['rsg-moonshine']:GetStills(citizenid)) do
    print(still.id, still.coords, still.recipe, still.brewing)
end

-- what is at this spot?
local still = exports['rsg-moonshine']:GetStillAt(GetEntityCoords(GetPlayerPed(src)), 3.0)

-- admin or gang script: remove a still cleanly
local ok, why = exports['rsg-moonshine']:DestroyStill(12, 'turf war')
if not ok then print('could not destroy still:', why) end

-- job board: only offer a contract to level 5+
if (exports['rsg-moonshine']:GetSkillLevel(src) or 1) >= 5 then --[[ offer it ]] end
```

## 10. Commands

| Command | Permission | Description |
|---|---|---|
| `/moonshine_unfocus` | none (client) | Emergency release if the cursor is ever stuck on screen |

## 11. Items

| Item | Purpose |
|---|---|
| `moonshine_still` | Useable. Places a copper still |
| `moonshine_still_tin` | Useable. Places a tin still (`Config.Materials.tin.item`) |
| `moonshine_jug_empty` | One is used per bottle collected (`Config.EmptyJug`) |
| `moonshine`, `moonshine_apple`, `moonshine_blackberry`, `moonshine_raspberry`, `moonshine_peach`, `moonshine_plumb`, `moonshine_wildcider`, `moonshine_currant`, `moonshine_applepie`, `moonshine_orange`, `moonshine_alaskan`, `moonshine_american` | Recipe outputs |
| `corn`, `sugarcane`, `yeast`, `water`, `apple`, `blackberry`, `raspberry`, `peach`, `orange`, `lemon`, `herb_creek_plum`, `herb_wild_mint`, `herb_black_current`, `herb_golden_currant`, `herb_vanilla_orchid`, `herb_wintergreen_berry` | Ingredients |
| `resource_wood`, `resource_coal` | Fuel |
| `moonshine_barrel` | Useable. Places a fermenting barrel (`Config.Barrel.item`) |
| `moonshine_wash` | One fermented batch, `info.recipe` is the recipe key (`Config.Barrel.washItem`) |
| `moonshine_cask` | Charred oak cask, fitted to a still for ageing (`Config.Cask.item`); returned when the still is packed up |

## 12. Configuration reference

### General (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `AutoDatabase` | `true` | Create and upgrade the table on start. `false` = import the SQL yourself |
| `StillItem` | `'moonshine_still'` | Useable item that places a still |
| `StillProp` | `` `mp001_p_mp_still02x` `` | Prop model |
| `MaxStills` | `2` | Stills per character |
| `MinStillDist` | `10.0` | Minimum distance between any two stills |
| `InteractDist` | `3.0` | Server side max distance for actions |
| `PlaceDist` | `5.0` | Max distance between player and placement |
| `SpawnDist` | `120.0` | Props spawn within this distance |
| `SyncDist` | `200.0` | Stills farther than this are never sent to the player |
| `OwnerOnly` | `true` | Only owner and trusted people can use a placed still |
| `TrustedMax` / `TrustDist` | `5` / `6.0` | People an owner can trust; how close they must stand |
| `MaxBatches` | `10` | Hopper holds this many batches of each ingredient |
| `EmptyJug` | `'moonshine_jug_empty'` | Jug used per bottle |
| `OutputCap` | `50` | Bottles the tank holds before brewing pauses |
| `TickInterval` | `15` | Seconds between server ticks |
| `ImagePath` | `'nui://rsg-inventory/html/images/'` | Item images in the menu |
| `AllowPushToTalkWhileOpen` / `PushToTalkControls` | `true` / `{ 0x4BC9DABB }` | Keep push-to-talk usable while the menu is open |

### World stills
`Config.WorldStills = { enabled = true, models = {...}, distance = 2.5, maxTotal = 150, locations = {} }`. Map stills get a saved row the first time someone uses them. `maxTotal` stops database flooding; `locations` is an optional allow-list of `vector3` (empty = any spot near a model).

### Fuel and effects
```lua
Config.Fuels = { { item = 'resource_wood', burnTime = 300 }, { item = 'resource_coal', burnTime = 900 } }  -- seconds per item
Config.MaxFuel = 7200
Config.BrewFx = { enabled = true, dict = 'core', effects = { { name, offset = vector3, scale } } }
Config.BlockedZones = { { name = 'Valentine', coords = vector3(...), radius = 150.0 }, ... }  -- no placing here
```

### Progression
| Option | Default | Description |
|---|---|---|
| `UseSkills` / `SkillName` | `true` / `'moonshining'` | Use rsg-skills (registers the skill, imports old rep xp, `sell_bonus` perk) |
| `XpName` / `XpPerBottle` / `Levels` | `'moonshiner'` / `2` / `{0,100,250,500,1000,2000}` | Built-in rep xp, used when rsg-skills is not running |
| `Reputation` | `{ enabled = true, sell = -1, raid = 2 }` | rsg-reputation honor changes |

### Quality, label, risk, smell
```lua
Config.Quality = { enabled = true, base = 40, perLevel = 3, variance = 8, defaultSold = 50, minPriceMult = 0.6, maxPriceMult = 1.4 }
Config.Label   = { enabled = true, maxLength = 24, blocked = {} }          -- blocked: lower case words
Config.Risk    = { enabled = true, baseChance = 3.0, safeLevel = 6 }       -- % per finished batch at level 1
Config.Smell   = { enabled = true, distance = 80.0, cooldown = 120 }
```

### Realism (3.4.0)
```lua
Config.Ferment     = { time = 1800, maxWash = 2 }                        -- seconds per batch, batches that can wait for the still
Config.Environment = { cold = {...}, wet = {...}, sunny = {...}, fermentCold = 0.5, fermentWet = 0.9, fermentSunny = 1.15,
                       burnWet = 1.25, burnCold = 1.1, smokeWet = 0.6, smokeNight = 0.6, nightFrom = 21, nightTo = 5 }
Config.Heat        = { { key = 'low', speed = 0.6, burn = 0.55, quality = 6, proof = 4, risk = 0.4, smoke = 0.6 }, ... }
Config.Proof       = { first = 90, variance = 6, max = 190, priceRef = 100, minPriceMult = 0.6, maxPriceMult = 1.6 }
Config.Rerun       = { time = 600, yield = 0.8, proofMult = 1.45, quality = 8, minVolume = 2 }
Config.Cuts        = { safeLevel = 8, order = {...}, options = { tight = { yield = 0.75, quality = 8, taint = 0 }, ... } }
Config.Cask        = { enabled = true, item = 'moonshine_cask', capacity = 20, stepTime = 1800, qualityPerStep = 1, maxBonus = 20, evaporation = 0.01, maxLoss = 0.25 }
```
Add `ferment = seconds` to a recipe to override `Config.Ferment.time` for it. Set `Config.Cask.enabled = false` to remove the cask feature, or make every cut safe with `taint = 0`.

Upkeep defaults: `Config.Wear = { enabled = true, perBatch = 8, rerun = 4, maxQualityLoss = 20, maxRiskMult = 2.0, cleanItem = 'fullbucket', cleanAmount = 1 }`, `Config.Cooling = { enabled = true, item = 'fullbucket', seconds = 600, max = 2400, use = 0.5, dryYieldLoss = 0.5, dryQuality = 15, dryRisk = 2.0 }`, `Config.Taste = { enabled = true, cost = 1, minVolume = 2 }`. Set `enabled = false` in any of them to turn that feature off.

Add the barrel with `Config.Barrel = { enabled = true, item = 'moonshine_barrel', washItem = 'moonshine_wash', prop = `p_barrel01ax`, max = 3, minDist = 2.0, maxWash = 4 }` (set `enabled = false` to turn barrels off).

```lua
-- example: refuse a toxic bottle in your own shop script
local info = exports['rsg-moonshine']:GetBottleInfo(src, slot)
if info and info.tainted then return end
```

### Buyers
```lua
Config.Buyers = {
    enabled = true, atSpeakeasies = true,
    extra = { { name = 'Bootlegger', coords = vector3(0.0, 0.0, 0.0) } },
    distance = 2.5, sellDist = 4.0, maxPerSale = 50, lawAlertChance = 10,
}
```
Price per bottle = recipe `price` × (`minPriceMult` … `maxPriceMult` by quality) × (1 + skill `sell_bonus` / 100).

### Recipes
```lua
{
    key = 'moonshine_apple', label = 'Apple Moonshine',   -- label is the fallback for locale key recipe_<key>
    level = 2, xpPerBottle = 3, time = 900, price = 8,    -- seconds per batch; $ per bottle at quality 50
    ingredients = { { item = 'apple', amount = 5 }, { item = 'water', amount = 2 } },
    output = { item = 'moonshine_apple', amount = 5 },
}
```

### Law and speakeasies
`LawJobs` (`{ 'vallaw', 'rholaw', ... }`), `LawRequireDuty = true`, `DestroyTime = 10000` ms, `DestroyReward = 15` cash. `Config.Speakeasy = { enabled, promptKey, holdTime, dist, fadeTime, locations = { { name, outside = vector4, inside = vector4 } } }`.

## 13. Webhooks

`SvConfig.Webhooks` in `server/sv_config.lua`: `enabled`, `username`, `avatar`, `footer`, `maxQueue` (100), `mirrorRsgLog`, `default` url, and `events`. Each event has `enabled`, `url` (blank = default) and `color`.

| Event | Default | Fired when |
|---|---|---|
| `place` / `pickup` | on | A still is placed / packed up |
| `destroy` | on | Law raid |
| `collect` | on | Bottles collected |
| `load` / `fuel` / `unload` | off (noisy) | Hopper and fuel changes |
| `recipe` | on | Recipe selected |
| `levelup` | on | Moonshiner level up |
| `explosion` | on | A still blew up |
| `sell` | on | Bootlegger sale |
| `suspicious` | on | Failed server checks (rate limited to once per 30 s per player for range alerts) |

Sending your own log from another server file (globals are shared inside this resource only):

```lua
WebhookLog('sell', src, 'Title', 'Description', { { 'Field', 'value' }, CoordsField(coords) })
```

## 14. Integration with other scripts

**Read the quality and label of every bottle a player carries (server, without the export):**

```lua
for _, item in ipairs(exports['rsg-inventory']:GetItemsByName(src, 'moonshine')) do
    local quality = item.info.quality or 50
    local label = item.info.label            -- nil when the brewer set none
    print(item.slot, item.amount, quality, label)
end
```

**Make drinking depend on quality** (in your own consume script): use `GetBottleInfo` (section 9).

**Add a recipe:** append an entry to `Config.Recipes` (section 12), add the output item to `rsg-core/shared/items.lua`, and add a `recipe_<key>` locale key to every language file.

**Add a buyer:** add `{ name = 'Cabin Buyer', coords = vector3(x, y, z) }` to `Config.Buyers.extra`. Each entry gets an rsg-target sphere zone and the server validates against the same list.

**Refuse or reward by proof, quality and poison (server, your own shop or consume script):**

```lua
local info = exports['rsg-moonshine']:GetBottleInfo(src, slot)
if not info then return end                      -- not moonshine
if info.tainted then
    -- toxic bottle: it looks normal in the inventory, so this is where you apply your own effect
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = 'Moonshine', description = 'That batch was poisonous!', type = 'error' })
    return
end
local strength = (info.proof or 100) / 100        -- 1.0 = 100 proof
```

**Feed ingredient quality from your own script** (server): give the ingredient item an `info.quality` (0-100) and moonshine will use it.

```lua
exports['rsg-inventory']:AddItem(src, 'corn', 10, { quality = 85 }, nil, 'my-farm-harvest')
```

**Check what a map or player still is (server):**

```lua
local still = exports['rsg-moonshine']:GetStillAt(coords, 3.0)
if still then print(still.kind, still.material, still.heat, still.wash, still.proof) end
```

**Reputation and skills:** with `rsg-skills` running, level and xp come from the `moonshining` skill; with `rsg-reputation` running, a sale changes honor by `Config.Reputation.sell` and a raid by `Config.Reputation.raid`.

## 15. Database

Table `rsg_moonshine_stills` (created and upgraded automatically; nothing is dropped):

| Column | Type | Notes |
|---|---|---|
| `id` | INT, auto increment | Primary key |
| `citizenid` | VARCHAR(50) | Owner, or `world` for map stills |
| `x`, `y`, `z`, `heading` | FLOAT | Position |
| `recipe` | VARCHAR(50) | Recipe key |
| `hopper` | LONGTEXT | JSON `{ item = count }` |
| `output`, `fuel` | INT | Bottles in the tank, seconds of fuel |
| `batch_left`, `last_tick` | INT | Running batch seconds, simulation time |
| `quality`, `op_level` | INT | Tank quality, level of the last loader |
| `trusted` | LONGTEXT | JSON `[ { cid, name } ]` |
| `label` | VARCHAR(100) | Bottle label |
| `material` | VARCHAR(10) | `copper` or `tin` |
| `mash_q`, `ferment_q`, `wash_q`, `batch_q` | INT, nullable | Ingredient quality of the hopper, the fermenting batch, the wash waiting and the running batch |
| `wear`, `water`, `dry` | INT | Grime (0-100), cooling seconds left, seconds run without cooling in the current run |
| `kind` | VARCHAR(10) | `still` or `barrel` |
| `wash`, `ferment_left` | INT | Fermented batches waiting, seconds left on the fermenting batch |
| `heat` | VARCHAR(10) | `low`, `medium` or `high` |
| `proof`, `reran` | INT, TINYINT | Tank proof (0 = empty), second run done |
| `rerun_left`, `rerun_vol` | INT | Second run seconds left and volume in the pot |
| `cask`, `cask_recipe`, `cask_vol`, `cask_q`, `cask_proof`, `cask_start` | TINYINT / VARCHAR / INT | Oak cask fitted, contents, quality, proof and the time ageing started |

Upgrade by hand on MySQL 8 with `auto database` off: see the commented `ALTER TABLE` lines in `installation/rsg-moonshine.sql`.

## 16. Security model

What the script checks (all on the server):

- Every callback and net event resolves the player first and refuses if there is no character.
- Distance to the still is checked with the server side ped position (`InteractDist`, `PlaceDist`, buyer `sellDist`), never with client coordinates.
- Ingredient, fuel and sale amounts are clamped to what the player carries and the space available. Prices, rewards and quality come from the server config, never from the client.
- Items are removed before anything is given; failed hand-overs are refunded.
- Placement uses `rsg-gizmo:IsPlacementValid`, item cost, zone blocklist, per-player limit and minimum distance. Law raids need a law job and wait `DestroyTime` between raids.
- Per player throttles: actions 300 ms, state 250 ms, inspections `Inspect.time`, map still creation 5 s, sales 2 s. Map still creation is also capped by `WorldStills.maxTotal`.
- Labels are cleaned (control characters, markup and invisible characters removed, length limited, blocked words rejected) before they are stored. The inventory escapes them when it renders.
- Webhook queue is capped and range alerts are rate limited.
- Only stills near a player are ever sent to that player.
- Cuts, taint rolls, proof, quality, wear, cooling water and heat are all decided on the server. The client only sends the action name and a cut or heat key, which are looked up in the config and ignored when unknown.
- Poison cannot be re-rolled: a taste sample rolls once per cut for as long as the tank stays the same, and bottling with that cut uses the result.
- Toxic bottles are marked in `info.meta` (not shown by the inventory) and the bootlegger removes none of them from the player: they are refused, not bought.
- Wash items are only created by the server (`info.recipe` and `info.quality` cannot be set by players), and a still only accepts wash of the recipe it is brewing.
- Law inspection is read only, needs a law job and cannot be spammed (throttled for `Config.Inspect.time`).

What other scripts must check: nothing here grants items outside the checks above. If you add your own buyer or consumer, validate the player, distance and amounts yourself.

## 17. Locales

All text is in `locales/<lang>.json` (en master, plus de, el, es, fr, ja, nl, pl, pt-br, ro, ru), loaded by rsg-core. Set the language with `setr rsg:locale "de"`. Prefixes: `cl_` client, `sv_` server notifications, `ui_` menu (the list sent to the NUI is `UiLocale` in `client/client.lua`), `wh_` webhooks, `recipe_<key>` recipe names. When you add a key, add it to all 11 files with the same `%s` order.

## 18. How-tos with examples

**Stop explosions:** `Config.Risk.enabled = false`.

**Add another still material:** add an entry to `Config.Materials`, for example `iron = { item = 'moonshine_still_iron', quality = -4, wear = 1.2, risk = 1.2 }`, add the item to `shared/items.lua` and `shared_items.lua`, and add a `ui_material_iron` locale key to all 11 files.

**Rename the water item used for cleaning and cooling:** `Config.Wear.cleanItem = 'water_bucket'` and `Config.Cooling.item = 'water_bucket'`.

**Make moonshine safe:** set every `Config.Cuts.options[...].taint` to `0`.

**Turn off ageing:** `Config.Cask.enabled = false`.

**Let anyone use any still (old behaviour):** `Config.OwnerOnly = false`.

**Block words in labels:** `Config.Label.blocked = { 'badword', 'another' }`.

**Limit map stills to known spots:**

```lua
Config.WorldStills.locations = { vector3(1234.5, -678.9, 100.0), vector3(-300.0, 700.0, 115.0) }
```

**Change prices:** edit `price` on each recipe; `Quality.minPriceMult` / `maxPriceMult` scale it.

## 19. Troubleshooting

| Problem | Fix |
|---|---|
| Menu does not open, console says NUI did not respond | Check `html/` files are on the server, then `refresh` and `ensure rsg-moonshine` |
| Cursor stuck on screen | `/moonshine_unfocus` |
| Menu text is English | Add the missing key to the language file and check `rsg:locale` |
| Placement preview does nothing | `rsg-gizmo` must be started before this script |
| "Not your still" | `Config.OwnerOnly` is on; ask the owner to trust you from the menu |
| Item image missing in the menu | Add the image to `rsg-inventory/html/images/` or change `Config.ImagePath` |
| Table errors on MySQL 8 | Set `Config.AutoDatabase = false` and run the ALTER lines in the SQL file |
| Bootlegger target missing | `Config.Buyers.enabled`, and speakeasy locations present in `Config.Speakeasy` |
| Barrel or tin still item does nothing | Add `moonshine_barrel`, `moonshine_wash` and `moonshine_still_tin` to `rsg-core/shared/items.lua` (see `installation/shared_items.lua`) and restart rsg-core |
| Barrel looks wrong or is missing | Change `Config.Barrel.prop` to a barrel model that exists on your server |
| "You need a Filled Water Bucket" | Cleaning and cooling use `fullbucket`; change `Config.Wear.cleanItem` and `Config.Cooling.item` if your item is named differently |
| Bootlegger refuses bottles | They are poisonous (loose cut, low level). Use a tighter cut, test a sample first or level up |
| Weather or night has no effect | rsg-weather must be running (`GlobalState.rsgWeather` and `rsgTime`); without it the values are neutral |
| Label not shown on bottles | It is saved on the still and applied at collection; bottles collected earlier keep their old label |

Support: https://rexshack.tebex.store
