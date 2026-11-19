# rsg-stables — Developer Docs

Technical reference for **rsg-stables**, the horse and stables resource for the RSG Framework (`rsg-core`). It covers the architecture, database, configuration, every export/event/callback, the data formats, the server-side validation rules and how to extend the resource.

- [Overview](#overview)
- [Architecture](#architecture)
- [Installation & database](#installation--database)
- [Configuration reference](#configuration-reference)
- [Admin panel](#admin-panel)
- [Client exports](#client-exports)
- [Events](#events)
- [Server callbacks](#server-callbacks)
- [NUI callbacks](#nui-callbacks)
- [Commands](#commands)
- [Usable items](#usable-items)
- [Data formats](#data-formats)
- [Gameplay systems](#gameplay-systems)
- [Security model](#security-model)
- [Extending the resource](#extending-the-resource)
- [Locales](#locales)
- [Troubleshooting](#troubleshooting)

---

## Overview

| | |
|---|---|
| Resource | `rsg-stables` |
| Framework | RSG Framework (`rsg-core`) |
| Dependencies | `rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory` |
| Not required | `ox_lib` (callbacks, notifications, locales and dialogs run on rsg-core and the resource's own NUI) |
| Lua | 5.4 (`lua54 'yes'`) |
| UI | Single NUI page (`html/index.html`) with `app.js`, `training.js`, `actions.js`, `horsecard.js` |
| Languages | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

---

## Architecture

```
rsg-stables/
├── fxmanifest.lua
├── shared/config.lua          # every setting, stables, breeds, tack, races
├── shared/foal.lua            # foal growth rules (FoalAdultSeconds, GetFoalState) used by client and server
├── server/
│   ├── server.lua             # DB install, horse CRUD, sessions, needs, breeding, selling, fence, races
│   ├── training.lua           # training XP, paid sessions, ride-XP ticks
│   └── versionchecker.lua     # GitHub version check
├── client/
│   ├── dataview.lua           # DataView helper for natives that need structs
│   ├── coat.lua               # coat tint application (metaped tints)
│   ├── client.lua             # stablehand NPCs, menus, spawn/whistle/store, needs, items, horse card
│   ├── horseinfo.lua          # native animal info card (Q prompt, SHOP_BROWSING UI app) for horses
│   ├── wildhorse.lua          # listens for EVENT_HORSE_BROKEN, registers broken wild horses
│   ├── foal.lua               # foal scale growth + ride block
│   ├── training.lua           # training NUI, attribute bonus ranks, ride ticks
│   ├── fence.lua              # horse fence NPCs
│   ├── actions.lua            # Horse Actions panel + /horse<action> commands
│   ├── spook.lua              # gunfire / explosion spooking
│   ├── salvage.lua            # search the saddlebags of a dead horse in the field
│   └── races.lua              # checkpoint races, HUD, /raceroute builder
├── html/                      # NUI
├── locales/*.json
└── installation/install.sql   # optional manual schema
```

**Server is authoritative.** Hunger, thirst, bonding, shoe wear, training XP and race timing are tracked in server-side *sessions*; the client only reports and renders. The client-side `CARE_COOLDOWN` is UX only, the server enforces the real limit.

**Callback style.** The server registers return-style handlers through a small wrapper over `RSGCore.Functions.CreateCallback`:

```lua
local function registerCallback(name, fn)
    RSGCore.Functions.CreateCallback(name, function(source, cb, ...) cb(fn(source, ...)) end)
end

registerCallback('rsg-stables:server:renameHorse', function(source, horseId, newName)
    -- ...
    return true            -- or: return false, locale('some_error')
end)
```

Callers use the rsg-core client callback API:

```lua
RSGCore.Functions.TriggerCallback('rsg-stables:server:renameHorse', function(ok, err)
    if not ok then
        RSGCore.Functions.Notify({ description = err, type = 'error' })
    end
end, horseId, 'Dusty')
```

Most state-changing callbacks return `success:boolean, payload_or_error_message`.

**Concurrency.** Mutating callbacks wrap their work in `withLock('citizen:<citizenid>', fn)` (and `withLock('stable:<name>', fn)` where capacity matters) so rapid duplicate requests cannot double-spend or double-insert.

---

## Installation & database

1. Ensure the dependencies start before the resource:

   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-target
   ensure rsg-inventory
   ensure rsg-stables
   ```

2. **Database is automatic.** On start the resource runs `CREATE TABLE IF NOT EXISTS` for every table (the `SCHEMA` list in `server/server.lua`) and adds any missing columns to `rsg_stables_horses` (`ALTER TABLE ... ADD COLUMN`, wrapped in `pcall`, so it is safe to restart repeatedly and upgrades older installs).
3. **Manual install is optional.** Import `installation/install.sql` yourself if you prefer — it is the same schema.
4. Add the items below to your RSG shared items, e.g. `horse_apple`, `horse_carrot`, `horse_brush`, `horse_stimulant`, `horse_medicine`, `horse_reviver`, `horse_lantern`, `fullbucket`.
5. Set the language in `server.cfg`:

   ```cfg
   setr rsg:locale "en"
   ```

### Tables

**`rsg_stables_horses`** — one row per owned horse

| Column | Type | Notes |
|---|---|---|
| `id` | INT PK | Horse id used by every callback |
| `citizenid` | VARCHAR(50) | Owner (indexed) |
| `stable` | VARCHAR(50) | `Config.Stables[].name` where it is kept (indexed) |
| `model` | VARCHAR(100) | Model hash as stored from `Config.Breeds[].model` |
| `breed_label` | VARCHAR(100) | Display label |
| `gender` | VARCHAR(6) | `male` / `female` |
| `breed_cooldown` | BIGINT | ms epoch; parent cannot breed again before this |
| `died_of_age` | TINYINT | `1` when the horse reached `lifespanDays` |
| `name` | VARCHAR(50) | Default `Unnamed Horse` |
| `outfit` | INT | Index into the breed's outfits |
| `tack` | TEXT | JSON `{ category = hash }` — see [Tack](#tack) |
| `shoe_wear` | FLOAT | Seconds of riding worn off the current shoes |
| `coat` | TEXT | JSON coat tints — see [Coat](#coat) |
| `health` `stamina` `hunger` `thirst` `bonding` | FLOAT | Cores / needs, 0–100 |
| `training` | TEXT | JSON XP per stat — see [Training data](#training-data) |
| `speed` `accel` `handling` `maxhealth` | INT | Base stats (default 50) |
| `alive` `insured` `active` | TINYINT | `active = 1` means the horse is currently out |
| `born` | TINYINT | `1` for horses born through breeding (these grow up as foals, see [Foal growth](#foal-growth)); added automatically to older databases |
| `pos_x` `pos_y` `pos_z` `pos_h` | FLOAT | Last saved position while out (persisted across relog) |
| `created_at` | TIMESTAMP | Age is `DATEDIFF(NOW(), created_at)` (`age_days`) and `TIMESTAMPDIFF(SECOND, ...)` (`age_seconds`, used for smooth foal growth) |

**`rsg_stables_breeding`** — `id`, `citizenid`, `stable`, `parent_a`, `parent_b`, `ready_at` (ms epoch), `collected`, `created_at`.

**`rsg_stables_races`** — personal bests, PK `(citizenid, race)`: `rider`, `horse`, `best_ms`, `updated_at`; index on `(race, best_ms)` for leaderboards.

---

## Configuration reference

All settings live in `shared/config.lua`. The tables below list the keys; defaults shown are the shipped values.

### General

| Key | Default | Description |
|---|---|---|
| `Config.MaxOwnedHorses` | `8` | Horses one player can own in total |
| `Config.MaxHorsesPerStable` | `20` | Horses one player can keep at a single stable |
| `Config.RenameCost` / `InsuranceCost` / `ReviveCost` | `15` / `25` / `40` | Service prices |
| `Config.StoreDistance` | `8.0` | Max distance from the stable to store a horse |
| `Config.PaymentAccount` | `'cash'` | `'cash'` or `'bank'` for every payment and payout |
| `Config.WhistleAnim` | `'WHISTLEHORSESHORT'` | Whistle sound/animation, `false` to disable |
| `Config.WhistleStopDistance` / `WhistleSpawnDistance` / `WhistleTeleportDistance` | `1.0` / `12.0` / `60.0` | Where a whistled horse stops, is placed, or teleports from |
| `Config.AllowTwoPlayersRide` | `false` | Allow a second rider |

### Active horse persistence — `Config.ActiveHorse`

`saveInterval`, `minMoveToSave`, `recallMaxDistance`, `respawnDistance`, `minSpawnDistance`, `notifyOnLogin`. While a horse is out its position is saved to `pos_*`; after a relog or resource restart the horse stays "out" and a whistle recalls it.

### Needs, feeding and care

```lua
Config.HorseFeedItems  = { { item = 'horse_apple',  label = 'Horse Apple',  health = 10, stamina = 10, hunger = 15 } }
Config.HorseDrinkItems = { { item = 'fullbucket', label = 'Water Bucket', thirst = 50, stamina = 10 } }

Config.HorseNeeds = {
    enabled = true, decayInterval = 60000,
    hungerDecayPerTick = 1, thirstDecayPerTick = 1,
    criticalThreshold = 15, healthDrainPerTick = 1,   -- starving/dehydrated -> damage
    wellFedThreshold = 50,  healthRegenPerTick = 1,   -- fed and watered -> slow heal
}
```

| Block | Purpose |
|---|---|
| `Config.HorseStimulant` | Stamina/speed boost item (`duration`, `speedMultiplier`, `staminaFloor`, `allowReuse`) |
| `Config.HorseMedicine` | Heals `healPercent` of max health, `cooldown` seconds between doses |
| `Config.HorseReviver` | Field revive within `window` seconds, `revivedHealth`, `bondingLoss` |
| `Config.HorseLantern` | Toggle a saddle lantern (`item`, `hash`, `category`) |
| `Config.HorseBrushItem`, `HorseBrushDistance`, `HorseBrushMounted` | Brushing |
| `Config.HorseBonding` | Bonding gain per feed / water / brush |
| `Config.HorseHitch` | Hitching-post props; natural needs are skipped while hitched |
| `Config.HorseNaturalDrink` | Rivers / lakes / troughs (`thirstThreshold`, `drinkDuration`, `cooldown`, `troughModels`) |
| `Config.HorseNaturalGraze` | Hay near the player (`hungerThreshold`, `searchRadius`, `hayModels`) |
| `Config.Horseshoes` | Shoe wear, unshod slow-down and stamina drain, `warnAt` thresholds |
| `Config.HorseInventory` | Saddlebag stash (`maxweight` grams, `slots`, `requireSaddlebags`, native cargo prompt, `openAnim` / `openAnimDelay` for the opening animation) |
| `Config.HorseFlee` | `fleeDelay`, `storeOnFlee` |
| `Config.HorseSpook` | Gunfire/explosion spooking (`baseChance`, `minChance`, `throwChance`, `bolt`) |
| `Config.HorseSalvage` | Dead uninsured horse stays `duration` seconds so its saddlebags can be searched |

### Horse actions — `Config.HorseActions`

```lua
Config.HorseActions = {
    enabled = true,
    command = 'horseaction',      -- opens the panel
    actionCommands = true,        -- /horserest /horsesleep /horsegraze ...
    stopCommand = 'horsestop',
    maxDistance = 6.0,
    rearKey = { enabled = true, control = `INPUT_SPECIAL_ABILITY_ACTION`, cooldown = 3000 },
    actions = {
        { id = 'rest', glyph = '\u{2726}', regen = true, anim = { dict = '...', base = 'base', enterDict = '...', enter = 'enter', exitDict = '...', exit = 'exit' } },
        { id = 'rear', glyph = '\u{2191}', horseAction = 5 },
        { id = 'follow', glyph = '\u{27A4}', follow = { offset = vector3(0.8, -2.5, 0.0), speed = 3.0 } },
    },
}
```

Each entry in `actions` produces a `/horse<id>` command and a panel button. Behaviour flags: `anim` (play enter/base/exit clips), `horseAction` (`TASK_HORSE_ACTION` id), `stay`, `lead`, `follow`, `regen` (refill stamina/health via `restRegen`).

### Ownership, breeding and life cycle

| Block | Key settings |
|---|---|
| `Config.WildHorse` | `claimFee`, `claimWindow` (s), `horseDistance` |
| `Config.Breeding` | `cost`, `time` (ms), `sameStableOnly`, `requireOppositeGender`, `lockParents`, `parentCooldown`, `statVariance`, `betterParentChance` |
| `Config.HorseAging` | `youngUntilDays` 7, `oldFromDays` 60, `lifespanDays` 90, `warnDays`, `oldMinStamina`, `checkInterval` |
| `Config.HorseGive` | `distance`, `fee`, `timeout`, `maxPrice` |
| `Config.HorseSell` | `percent`, `perTrainedLevel`, `minPrice`, `appraisal` (condition, bonding, stage multipliers, shod bonus) |
| `Config.HorseFence` | `account` (`bloodmoney`), `percent`, `cooldown`, `sellDistance`, `locations` |

### Foal growth — `Config.FoalGrowth`

```lua
Config.FoalGrowth = {
    enabled          = true,
    startScale       = 0.5,   -- size of a newborn foal (1.0 = full size)
    adultScale       = 1.0,   -- size once grown
    adultAfterDays   = nil,   -- real-life days until adult; nil = Config.HorseAging.youngUntilDays
    scaleByDay       = { [0] = 0.50, [1] = 0.58, [2] = 0.66, [3] = 0.74, [4] = 0.82, [5] = 0.90, [6] = 0.95 }, -- nil = smooth linear growth
    updateInterval   = 30000, -- ms between growth updates while the foal is out
    blockRiding      = true,  -- foals can't be ridden
    applyToPurchased = false, -- true = bought horses also start as foals (age counts from purchase)
    notifyGrown      = true,  -- notify the owner when the foal has grown up
}
```

See [Foal growth](#foal-growth) under Gameplay systems for how it works.

### Stables

```lua
Config.Stables = {
    {
        name          = 'mystable',                 -- unique id, stored in the DB
        label         = 'My Stable',
        pedModel      = `u_m_m_bwmstablehand_01`,
        pedCoords     = vector4(x, y, z, heading),  -- stablehand NPC
        storeCoords   = vector4(x, y, z, heading),  -- where stored/retrieved horses appear
        previewCoords = vector4(x, y, z, heading),  -- buy-menu preview spot
        blip = { sprite = 'blip_shop_horse', color = 'BLIP_MODIFIER_MP_COLOR_6', scale = 0.2 },
    },
}
```

Shipped stables: `valentine`, `blackwater`, `rhodes`, `saintdenis`, `strawberry`. **Never rename the `name` of a stable that already has horses**: the name is the foreign key in `rsg_stables_horses.stable`.

### Breeds

```lua
Config.BreedStatMax = 10
Config.BuyPriceBands = { { label = 'Under $150', min = 0, max = 149 }, { label = '$1000+', min = 1000 } }

Config.Breeds = {
    {
        model        = `a_c_horse_arabian_white`,
        label        = 'Arabian (White)',
        class        = 'Race Horse',     -- used by the Buy menu class filter
        breed        = 'arabian',        -- used by the breed filter
        price        = 1200,
        handling     = 'Elite',
        health = 4, stamina = 4, speed = 5, acceleration = 5, -- 1..Config.BreedStatMax
        description  = 'Shown in the buy menu.',
        -- outfits = n                    -- optional: number of coat variants (default 1)
    },
}
```

Only models listed here can be bought, bred or claimed as wild horses; the server rejects anything else (`invalid_breed`).

### Tack and coat

```lua
Config.Tack = { enabled = true }
Config.Coat = { enabled = true, price = 100, presets = { { label = 'Black', tint0 = 9 } } }
Config.TackCategories = { { key = 'saddle', label = 'Saddle' }, { key = 'horseshoe', label = 'Horseshoes' } --[[ ... ]] }
Config.TackItems = {
    saddle = {
        { label = 'Saddle Style 5', hash = 0x7092A211, price = 40, verified = true, bonus = { stamina = 2, speed = 1 } },
    },
}
Config.TackBonuses = {
    enabled = true,
    categoryDefaults = { saddle = { stamina = 1 }, stirrups = { accel = 1 }, horseshoe = { speed = 1 }, blanket = { health = 1 } },
}
```

A per-item `bonus` overrides the category default. Bonuses stack with training.

### Training — `Config.Training`

```lua
Config.Training = {
    enabled = true,
    stats = { health = { attribute = 0 }, stamina = { attribute = 1 }, speed = { attribute = 5 }, accel = { attribute = 6 }, courage = { attribute = 3 } },
    statOrder = { 'health', 'stamina', 'speed', 'accel', 'courage' },
    courageFromBonding = 25,                       -- +1 courage rank per 25 bonding
    levelXp = { 100, 250, 450, 700, 1000 },        -- total XP for level 1..n (n = max level)
    bonusPerLevel = 1,
    riding  = { enabled = true, interval = 60, metersPerXp = 100.0, maxXpPerTick = 12, maxSpeed = 22.0, split = { stamina = 0.6, speed = 0.4 } },
    session = { enabled = true, price = { health = 10, stamina = 10, speed = 15, accel = 15, courage = 10 },
                rounds = 5, roundMs = 2000, baseXp = 20, xpPerHit = 12, cooldown = 900, stableDistance = 25.0, horseDistance = 6.0 },
}
```

Levels are applied as `SET_ATTRIBUTE_BONUS_RANK` bonus ranks, so a breed's own base stats are never overwritten.

### Races — `Config.HorseRaces`

```lua
Config.HorseRaces = {
    enabled = true, routeCommand = 'raceroute', radius = 8.0, maxSpeed = 25.0,
    dismountTimeout = 10, leaderboardSize = 5,
    races = {
        {
            id = 'valentine_sprint', stable = 'valentine', label = 'Valentine Sprint',
            entryFee = 5, prize = 25, goalTime = 90, timeLimit = 240, cooldown = 600,
            checkpoints = { vector3(-300.0, 790.0, 118.0), vector3(-250.0, 820.0, 120.0) },
        },
    },
}
```

Races only appear at the stable named in `stable` and only if `checkpoints` is non-empty. See [Races](#races) for the route builder.

### Horse card

`Config.HorseCard = { command = 'horseinfo', maxDistance = 15.0 }` — set `command = false` to remove the command.

---

## Admin panel

`/horseadmin` (`Config.Admin.command`) opens an NUI panel for staff. It needs the rsg-core permission in `Config.Admin.permission` (default `admin`); the command, **every** callback below and every NUI action re-check `RSGCore.Functions.HasPermission(source, permission)` on the server, so closing the UI in the client proves nothing.

```lua
Config.Admin = { enabled = true, command = 'horseadmin', permission = 'admin' }
```

Flow: search a player (online by name / citizen ID / server ID, or any offline character by name / citizen ID) → their horses → one horse (edit form, actions, transfer, delete) or *Give horse*.

| Server callback | Arguments | Returns |
|---|---|---|
| `rsg-stables:server:admin:search` | `query` | `true, { { citizenid, name, online, horses } }` |
| `rsg-stables:server:admin:getOptions` | — | `true, { stables, breeds, statMax, lifespanDays }` |
| `rsg-stables:server:admin:getHorses` | `citizenid` | `true, { player, horses }` (each horse: id, name, breed, gender, stable, alive, active, insured, born, health, stamina, hunger, thirst, bonding, speed, accel, handling, maxhealth, ageDays, stage) |
| `rsg-stables:server:admin:updateHorse` | `horseId, changes` | `true, message` or `false, err` |
| `rsg-stables:server:admin:action` | `horseId, action` | `true, message` or `false, err` |
| `rsg-stables:server:admin:giveHorse` | `citizenid, model, name, gender, stable, ageDays, foal` | `true, message` or `false, err` |
| `rsg-stables:server:admin:transferHorse` | `horseId, targetCitizenid` | `true, message` or `false, err` |

`changes` may contain `name, gender, stable, insured, born, ageDays, health, stamina, hunger, thirst, bonding, handling` (0–100), `speed, accel, maxhealth` (1–`Config.BreedStatMax`). Every value is validated and clamped; unknown keys are ignored.

`action` is one of `forceStore, revive, resetShoes, resetCoat, resetTack, resetTraining, clearCooldown, openSaddlebags, delete`.

Rules enforced on the server:

- Editing, resetting, reviving and transferring require the horse to be **in its stable**. A horse that is out must be force-stored first (`forceStore`, which also removes it from the world on the owner's client with `rsg-stables:client:adminStoreHorse`). `forceStore`, `openSaddlebags` and `delete` work on a horse that is out.
- Work on a player's horses holds the same `citizen:<id>` lock as the normal gameplay callbacks (transfers lock both owners in a fixed order), so an admin action cannot race a purchase or a store.
- Setting an age at or above `Config.HorseAging.lifespanDays` on a living horse is refused. Reviving a horse that died of old age resets its age to `oldFromDays` so the next lifespan check does not kill it again.
- Deleting or transferring a horse cancels its uncollected breeding jobs, and a delete also removes the saddlebag stash.
- Every change is printed to the server console and sent to rsg-log (`rsgstables`, title `Horse Admin`) with the admin, the horse id and the owner. Online owners get a notification.
- The panel keeps push-to-talk working while it is open (`Config.AllowPushToTalkWhileOpen`, `Config.PushToTalkControls`).

`server/server.lua` exposes the helpers it shares with `server/admin.lua` in a global `StablesAPI` table (server only, not an export).

---

## Client exports

### GetActiveHorseNeeds
```lua
local needs = exports['rsg-stables']:GetActiveHorseNeeds()
-- needs = { entity = <ped handle>, hunger = 0-100, thirst = 0-100 }  or nil
```
Returns the live hunger/thirst of the player's currently active (spawned) horse, as tracked client-side and synced from the server session (`Config.HorseNeeds`). Returns `nil` when no horse is out. Compare `needs.entity` with `GetMount(PlayerPedId())` to check you're riding that horse — rsg-hud does this so borrowed or wild horses show nothing.

```lua
-- Show needs only while riding your own horse
CreateThread(function()
    while true do
        Wait(1000)
        local needs = exports['rsg-stables']:GetActiveHorseNeeds()
        if needs and GetMount(PlayerPedId()) == needs.entity then
            print(('Horse hunger %d / thirst %d'):format(needs.hunger, needs.thirst))
        end
    end
end)
```

### GetHorseBonusInfo
```lua
local info = exports['rsg-stables']:GetHorseBonusInfo()
-- info = { tack = { health=, stamina=, speed=, accel=, courage= }, training = <summary> }  or nil
```
Returns `nil` when no horse is out. `tack` holds the bonus ranks from fitted tack (plus the bonding-derived courage), `training` is the latest server summary (see [Training data](#training-data)).

```lua
local info = exports['rsg-stables']:GetHorseBonusInfo()
if info and info.training then
    local speed = info.training.stats.speed
    print(('Speed level %d (%d xp)'):format(speed.level, speed.xp))
end
```

---

## Events

### Client events you can listen to (local, `AddEventHandler`)

| Event | Arguments | When |
|---|---|---|
| `rsg-stables:client:horseSpawned` | `entity`, `horseRow` | An owned horse entity has been created and configured (`client/foal.lua` and `client/training.lua` hook it) |
| `rsg-stables:client:tackChanged` | `tack` | Tack changed while the horse is out (e.g. a thrown shoe) |
| `rsg-stables:client:openTraining` | — | Opens the training panel (checks the horse is dismounted and near a stable) |

```lua
AddEventHandler('rsg-stables:client:horseSpawned', function(entity, horseRow)
    print(('Horse %d (%s) spawned as entity %d'):format(horseRow.id, horseRow.name, entity))
    -- Owned horses carry a state bag flag:
    print(Entity(entity).state.rsgStablesOwned) --> true
end)
```

The spawned entity is flagged with the replicated state bag `rsgStablesOwned = true`. Foals also publish their current size on the `rsgFoalScale` state bag (see [Foal growth](#foal-growth)). The server uses it to refuse to fence owned horses and `wildhorse.lua` uses it to ignore them when detecting a broken wild horse. Use it in your own scripts to tell owned horses from wild ones.

### Net events received by the client (server → client)

| Event | Payload | Purpose |
|---|---|---|
| `rsg-stables:client:useFeed` | `itemName` | Feed item used from inventory |
| `rsg-stables:client:useBrush` | — | Brush item used |
| `rsg-stables:client:useLantern` | — | Lantern item used |
| `rsg-stables:client:useStimulant` | — | Stimulant used |
| `rsg-stables:client:useMedicine` | — | Medicine used |
| `rsg-stables:client:useReviver` | — | Reviver used |
| `rsg-stables:client:horseDiedOfAge` | `horseId`, `horseName` | Horse reached its lifespan |
| `rsg-stables:client:fieldCorpse` | `{ horseId, model, outfit, name, coords, heading, duration }` | A dead uninsured horse can be searched in the field |
| `rsg-stables:client:trainingUpdate` | `horseId`, `summary` | New training XP/levels |
| `rsg-stables:client:raceRoute` | `action` | Admin route builder (`add`, `print`, `clear`) |

These are server-driven: do not trigger them from other client scripts.

### Net events received by the server (client → server)

All of these revalidate everything server-side (ownership, distance, cooldowns); never trust their arguments.

| Event | Arguments | Notes |
|---|---|---|
| `rsg-stables:server:saveHorsePosition` | `horseId, x, y, z, h, health` | Throttled by `Config.ActiveHorse` |
| `rsg-stables:server:wildHorseBroken` | `netId` | Registers a broken wild horse for claiming (`Config.WildHorse.claimWindow`) |
| `rsg-stables:server:openHorseInventory` | `horseId, horseNetId` | Requires saddlebags if `requireSaddlebags` and proximity to the horse. The client plays `Interaction_LootSaddleBags` (via `TaskAnimalInteraction`) for `openAnimDelay` ms before sending it |
| `rsg-stables:server:openFieldSaddlebags` | `horseId` | Dead horse in the field, within `Config.HorseSalvage` |
| `rsg-stables:server:openDeadHorseInventory` | `horseId` | At the stable only |
| `rsg-stables:server:trainingRideTick` | `horseNetId` | Ride XP; measured on the horse entity, rate limited |

### rsg-core events used

`RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload` (client) and `RSGCore:Server:OnPlayerUnload` (server-only event, not a net event) end sessions and clean up.

---

## Server callbacks

Register-name → arguments → return. `ok, x` means `true, payload` on success or `false, errorMessage` on failure.

### Horse lifecycle

| Callback | Arguments | Returns |
|---|---|---|
| `rsg-stables:server:getStableHorses` | `stableName` | `table[]` — rows of horses stabled there (with `age_days`, `stage`) |
| `rsg-stables:server:buyHorse` | `stableName, model, horseName, outfit, gender` | `ok, newHorseId` |
| `rsg-stables:server:claimWildHorse` | `stableName, netId, horseName` | `ok, ...` |
| `rsg-stables:server:retrieveHorse` | `horseId` | `ok, horseRow` (marks `active = 1`, starts a session) |
| `rsg-stables:server:storeHorse` | `horseId, health, stamina` | `ok` (saves needs, clears `pos_*`) |
| `rsg-stables:server:fleeStoreHorse` | `horseId, health, stamina` | `ok` (store without requiring a stable) |
| `rsg-stables:server:restoreActiveHorse` | — | Row of a horse left out before relog, or nil |
| `rsg-stables:server:renameHorse` | `horseId, newName` | `ok` |
| `rsg-stables:server:insureHorse` | `horseId` | `ok` |
| `rsg-stables:server:reviveHorse` | `horseId` | `ok` (insured dead horse, `Config.ReviveCost`) |
| `rsg-stables:server:releaseHorse` | `horseId` | `ok` (horse must be **dead**, at its stable, not a parent of an uncollected foal, saddlebags empty; the row is deleted) |
| `rsg-stables:server:transferHorse` | `horseId, newStable` | `ok` (move a stabled horse to another stable; you must be at its current stable and the destination must have room) |
| `rsg-stables:server:getNearbyPlayers` | — | Players within `Config.HorseGive.distance` |
| `rsg-stables:server:giveHorse` | `horseId, targetId, price` | `ok` (target must accept within `timeout`) |
| `rsg-stables:server:getSellPrice` | `horseId` | `price, info` (`info` = `base, training, condition, bonding, stageMult, stage, shod, price`) or `nil` |
| `rsg-stables:server:sellHorse` | `horseId` | `ok, price` |
| `rsg-stables:server:fenceHorse` | `fenceIndex, netId` | `ok, ...` (unowned horses only) |
| `rsg-stables:server:horseDown` | `netId` | `true, secondsLeft` — starts the field-revive window (applies `bondingLoss` once) |
| `rsg-stables:server:reviveDownedHorse` | `netId` | `ok` — revive a downed horse in the field (consumes the reviver item) |
| `rsg-stables:server:horseDied` | `horseId, netId` | Marks the horse dead; insured horses return to the stable, uninsured ones leave a field corpse (`fieldCorpse` event). Returns `true, 'dead'` |

```lua
-- Buy a horse at Valentine (client)
RSGCore.Functions.TriggerCallback('rsg-stables:server:buyHorse', function(ok, result)
    if ok then
        print('Bought horse id', result)
    else
        RSGCore.Functions.Notify({ description = result, type = 'error' })
    end
end, 'valentine', `a_c_horse_americanpaint_overo`, 'Biscuit', 0, 'female')
```

### Care and consumables

| Callback | Arguments |
|---|---|
| `rsg-stables:server:feedHorse` | `preferredItem, horseNetId` |
| `rsg-stables:server:waterHorse` | `horseNetId` |
| `rsg-stables:server:brushHorse` | `horseNetId` |
| `rsg-stables:server:naturalDrink` / `naturalGraze` | `horseNetId` |
| `rsg-stables:server:useStimulant` | `horseNetId` |
| `rsg-stables:server:useMedicine` | `horseNetId` |
| `rsg-stables:server:toggleLantern` | — |
| `rsg-stables:server:getHorseshoeCondition` | — |
| `rsg-stables:server:wearHorseshoe` | `horseNetId, seconds` |

Feeding, watering and brushing share a 60 s per-player cooldown enforced on the server.

### Customisation and breeding

```lua
-- selections = { categoryKey = hash | false }, charged per changed category (Config.TackItems prices)
RSGCore.Functions.TriggerCallback('rsg-stables:server:applyHorseTack', function(ok, res)
end, horseId, { saddle = 0x7092A211, blanket = false })

-- coat = { tint0, tint1, tint2, mane, tail } or the string 'reset'
RSGCore.Functions.TriggerCallback('rsg-stables:server:applyHorseCoat', function(ok, res)
end, horseId, { tint0 = 9, tint1 = 255, tint2 = 255, mane = 9, tail = 9 })
```

| Callback | Arguments | Returns |
|---|---|---|
| `rsg-stables:server:applyHorseTack` | `horseId, selections` | `ok, newTack` |
| `rsg-stables:server:applyHorseCoat` | `horseId, coat \| 'reset'` | `ok` |
| `rsg-stables:server:startBreeding` | `stableName, idA, idB` | `ok, readyAtMs` |
| `rsg-stables:server:getBreedingJobs` | `stableName` | Jobs with `ms_left` and `ready` (server clock) |
| `rsg-stables:server:collectFoal` | `breedingId` | `ok, ...` |

### Training and races

| Callback | Arguments | Returns |
|---|---|---|
| `rsg-stables:server:getTraining` | — | Summary + `horseId`, `name`, `prices`, `cooldownLeft` |
| `rsg-stables:server:startTraining` | `stat, horseNetId` | `true, { token, rounds, roundMs }` or `false, err` |
| `rsg-stables:server:finishTraining` | `token, hits` | `true, { gain, stat, hits, training }` |
| `rsg-stables:server:getRaces` | `stableName` | Race list with `best`, `cooldownLeft`, `leaderboard` |
| `rsg-stables:server:startRace` | `raceId, horseNetId` | `true, { checkpoints, timeLimit, goalTime, radius }` |
| `rsg-stables:server:raceCheckpoint` | `idx` | `true, { finished=false, next }` or `true, { finished=true, ms, won, prize, newBest }` |
| `rsg-stables:server:abortRace` | — | `true` |

---

## NUI callbacks

Registered with `RegisterNUICallback` in the client scripts and called from the `html/*.js` files.

| Callback | File | Purpose |
|---|---|---|
| `select`, `close`, `inputSubmit`, `inputCancel`, `alertClose`, `statsClose` | `client.lua` | Menu navigation, name input, alert and stats dialogs |
| `rotateCam`, `zoomCam` | `client.lua` | Preview camera |
| `tackCycle`, `tackCategoryNav`, `coatUpdate`, `coatAction` | `client.lua` | Tack and coat editors |
| `horseCardAction`, `horseCardClose` | `client.lua` | Horse card (`/horseinfo`) |
| `actionsSelect`, `actionsClose` | `actions.lua` | Horse Actions panel |
| `trainingStart`, `trainingFinish`, `trainingClose` | `training.lua` | Training minigame |

Menu options can carry an optional `iconTone` (`young`, `adult`, `old`, `dead`) next to `icon`; `NuiRender` forwards it and `html/app.js` adds a `tone-<name>` class to the round icon (colours in `html/style.css`). The stable ledger uses `icon = 'mars' | 'venus'` for the sex and `iconTone` for the age stage.

NUI messages sent from Lua use `SendNUIMessage({ action = '...', ... })` — for example `trainingOpen` carries `data`, `order` and `strings` (localised labels built from the `training_*` locale keys).

> The NUI keeps keyboard focus on `SetNuiFocus(true, true)`. Keep the push-to-talk keep-alive pattern used across RSG scripts if you add new panels.

---

## Commands

| Command | Permission | Description |
|---|---|---|
| `/storehorse` | everyone | Store the active horse at the nearest stable |
| `/horseinfo` (`Config.HorseCard.command`) | everyone | Open the horse card |
| `/horseaction` (`Config.HorseActions.command`) | everyone | Open the actions panel |
| `/horse<id>` for each `Config.HorseActions.actions[].id` | everyone | e.g. `/horserest /horsesleep /horsegraze /horsewallow /horserear /horsestay /horsefollow /horselead` |
| `/horsestop` (`stopCommand`) | everyone | End the current action / release the reins |
| `/horseadmin` (`Config.Admin.command`) | **`Config.Admin.permission`** (admin) | Open the horse admin panel |
| `/raceroute add \| print \| clear` (`routeCommand`) | **admin** | Build a race route (server command registered with `RSGCore.Commands.Add`) |

Keys: whistle (`INPUT_WHISTLE`, H), Horse Cargo prompt (B) beside the horse, `INPUT_SPECIAL_ABILITY_ACTION` (Q) to rear while riding.

---

## Usable items

Created with `RSGCore.Functions.CreateUseableItem` from the `Config` item names.

| Config key | Default item | Behaviour |
|---|---|---|
| `Config.HorseFeedItems[].item` | `horse_apple`, `horse_carrot` | Feed (needs the horse within `HorseBrushDistance`) |
| `Config.HorseDrinkItems[].item` | `fullbucket` | Water the horse (via **Water Horse**) |
| `Config.HorseBrushItem` | `horse_brush` | Brush (not consumed) |
| `Config.HorseStimulant.item` | `horse_stimulant` | Boost, consumed |
| `Config.HorseMedicine.item` | `horse_medicine` | Heal, consumed |
| `Config.HorseReviver.item` | `horse_reviver` | Revive a downed horse, consumed |
| `Config.HorseLantern.item` | `horse_lantern` | Toggle lantern, **not** consumed, saved in tack |

Example shared-items entry:

```lua
horse_brush = { name = 'horse_brush', label = 'Horse Brush', weight = 200, type = 'item', image = 'horse_brush.png', unique = false, useable = true, shouldClose = true, description = 'Keeps your horse clean and bonded' },
```

---

## Data formats

### Tack
`rsg_stables_horses.tack` — JSON map of category key to the shop-item hash:

```json
{ "saddle": 1904169813, "horseshoe": 2147483647, "blanket": 123456 }
```
Hashes come from `Config.TackItems[category][].hash`. New purchased horses start with the first `horseshoe` item when `Config.Horseshoes.newHorsesShod` is true, otherwise `{}`.

### Coat
`rsg_stables_horses.coat` — JSON, every key required and range checked on the server:

| Key | Range |
|---|---|
| `tint0` (main) | 0–254 |
| `tint1` (markings) | 0–255 (255 = none) |
| `tint2` (nose) | 0–255 (255 = default) |
| `mane`, `tail` | 0–254 |

```json
{ "tint0": 9, "tint1": 255, "tint2": 255, "mane": 9, "tail": 9 }
```
Anything out of range is rejected (`invalid_coat`). Sending the string `'reset'` restores the natural coat for free.

### Training data
`rsg_stables_horses.training` — JSON:

```json
{ "stats": { "health": 0, "stamina": 142.5, "speed": 60, "accel": 0, "courage": 0 }, "lastSession": 1731660000 }
```
The summary sent to clients (`getTraining`, `trainingUpdate`, `GetHorseBonusInfo().training`):

```lua
{
    stats = { stamina = { xp = 142, level = 1, prevXp = 100, nextXp = 250 }, --[[ ... ]] },
    maxLevel = 5,
    lastSession = 1731660000,
}
```

### Foal state
`GetFoalState(row)` (shared, `shared/foal.lua`) takes a horse row that has `born` and `age_seconds` and returns `isFoal, scale, secondsLeft`:

```lua
local isFoal, scale, secondsLeft = GetFoalState({ born = 1, age_seconds = 3.5 * 86400 })
-- isFoal = true, scale = 0.74, secondsLeft = 302400   (default scaleByDay, 7 day Young stage: day 3 -> 0.74)
```
With `scaleByDay` set (the default, modelled on rsg-ranch's growth table) the size is the entry for the foal's current day of age; with `scaleByDay = nil` it is `startScale + (adultScale - startScale) * (age / adultSeconds)`, i.e. linear. The result is clamped to 0.1–2.0 like rsg-ranch. It returns `false, adultScale, 0` for adults, when `Config.FoalGrowth.enabled` is false, and for horses that weren't born at a stable unless `applyToPurchased` is true. The server's `AGE_SQL` adds `age_days` and `age_seconds` to every horse row it selects with `SELECT *, ' .. AGE_SQL`.

### Age stages
`young` (< `youngUntilDays`), `adult`, `old` (≥ `oldFromDays`); the horse dies at `lifespanDays`. Only adults can breed. Age is `DATEDIFF(NOW(), created_at)`.

### Sell price
```lua
base      = floor(breedPrice * Config.HorseSell.percent)
condition = (health + hunger + thirst) / 3                       -- 0..100
price     = base * (1 - conditionWeight * (1 - condition / 100))
                 * (1 + bondingBonus * bonding / 100)
                 * stage[youngOrAdultOrOld]                     -- Config.HorseSell.appraisal.stage
price     = max(minPrice, floor(price + perTrainedLevel * trainedLevels + shodBonus))  -- shodBonus only if shoes fitted
```
With `appraisal.enabled = false` only `base + training` is used. `getSellPrice` returns the price and the breakdown shown before the sale.

---

## Gameplay systems

### Horse sessions and needs
`retrieveHorse` starts a server session (`activeSessions[citizenid]`) holding hunger, thirst, bonding and model. Decay is applied lazily from elapsed time (`Config.HorseNeeds`) and persisted on store, drop or restart. `GetActiveHorseNeeds` mirrors it for HUDs.

### Persistence and recall
While out, the horse position is saved to `pos_x/y/z/h`. After a relog the horse is restored as *pending*; a whistle spawns it at the saved position (if within `recallMaxDistance`) or behind the player.

### Opening the saddlebags
Both entry points (the **Open Saddlebags** target option and the native Horse Cargo prompt, B) call the same client function in `client/client.lua`. It plays the game's saddlebag interaction on the horse, waits `Config.HorseInventory.openAnimDelay` ms, checks the horse is still the active one, then triggers `rsg-stables:server:openHorseInventory`; the server still validates ownership, distance and saddlebags. Set `openAnim = false` to open the stash instantly. The dead-horse salvage uses the same interaction.

### Death, insurance and salvage
`horseDown` opens a `Config.HorseReviver.window` for a field revive. If it dies: an insured horse returns to its stable for `reviveHorse`; an uninsured horse's body stays for `Config.HorseSalvage.duration` seconds so its saddlebags can be searched, and the stash can still be emptied at the stable afterwards.

### Breeding
The breed menu only lists horses that are living, stabled at that stable and adults (not Young, not Old). If you have two or more living horses but fewer than two adults, it explains why instead of `breed_need_two`: `breed_wait_to_grow` (with the days until enough young horses are adult) when waiting will fix it, otherwise `breed_not_enough_breeders` (old horses can't breed). `startBreeding` validates ownership, stage (adult only), both alive and stabled, same stable, opposite genders, no pending job, parent cooldowns, then charges `cost`. The foal is collected with `collectFoal` once `ready_at` passes; its stats are the parents' average ± `statVariance`, with `betterParentChance`% per stat to take the better parent's value.

### Foal growth
Horses created by `collectFoal` are stored with `born = 1`. While such a horse is younger than the adult age (`Config.FoalGrowth.adultAfterDays`, default the end of the Young stage) it is a *foal*:

- **Size.** `client/foal.lua` listens for `rsg-stables:client:horseSpawned`, sets the entity size with `SetPedScale` (`_SET_PED_SCALE`, `0x25ACFC650B65C538`, the same native rsg-ranch uses) and re-applies a slightly larger size every `updateInterval` ms while the foal is out. The owner also publishes the value on the entity state bag `rsgFoalScale`; every client has an `AddStateBagChangeHandler` for it, so other players see the same size. When the foal reaches adult age it is set to `adultScale` and the owner is notified.
- **No riding.** With `blockRiding` the foal gets ped config flag 136 (CannotBeMounted), and if a player ends up on it anyway they are dismounted with `TaskDismountAnimal` and notified. The flag is cleared when it grows up.
- **Server enforcement.** `rsg-stables:server:startRace` refuses a foal (`foal_cannot_ride`) and `trainingRideTick` gives no ride XP for one, using the same `GetFoalState` rules from the database age.

```lua
-- Another script: is this horse entity still a foal? (the bag is only set on horses that started as foals)
local scale = Entity(horseEntity).state.rsgFoalScale   -- nil, or the current size (reaches adultScale, 1.0 by default, when grown)
local isFoal = scale ~= nil and scale < 1.0
```

To make every bought horse start small as well, set `Config.FoalGrowth.applyToPurchased = true` (age then counts from the purchase date).

### Training
- **Ride XP**: the client sends `trainingRideTick` every `riding.interval` seconds; the server measures distance travelled by the horse entity (ignores teleports above `maxSpeed`, walking, trains and wagons).
- **Paid sessions**: `startTraining` charges the price, stamps the cooldown immediately and returns a one-time `token`; `finishTraining(token, hits)` grants `baseXp + hits × xpPerHit`. Finishing faster than 90 % of `rounds × roundMs` counts as tampering and gives 0 hits.
- Levels become bonus ranks via `SET_ATTRIBUTE_BONUS_RANK`.

### Races
Races are timed and validated on the server. Build a route in-game as an admin:

```
/raceroute add     -- at every checkpoint, in order
/raceroute print   -- prints `checkpoints = { vector3(x, y, z), ... },` to the F8 console
/raceroute clear
```

Paste the printed block into `Config.HorseRaces.races`, set `id`, `stable`, `label`, fees, `goalTime` and `timeLimit`. Each checkpoint must arrive in order, within radius, on the same horse, and not faster than `maxSpeed` allows (otherwise the run is cancelled). Personal bests are stored in `rsg_stables_races`.

---

## Security model

- Every server callback re-reads the player and the horse row and checks `citizenid` ownership; ids are sanitised with `toId()`.
- Distance checks (`isNearStable`, `nearStableByName`, `activeHorseNear`) are done with server-side coordinates.
- Net-event arguments are untrusted. Client-reported entity ids are verified (entity exists, model matches the owned horse, close to the player).
- Money moves through `chargePlayer(Player, amount)` using `Config.PaymentAccount`; failed inserts refund.
- Names are sanitised and truncated; coat and tack payloads are validated against `COAT_LIMITS` and `Config.TackItems`.
- The admin panel re-checks `Config.Admin.permission` in every callback, validates every field, takes the owner's lock and logs each change (see [Admin panel](#admin-panel)).
- Riding restrictions for foals are enforced on the server where the server can know about them (`startRace`, ride XP); the mount block itself is client-side (ped config flag plus dismount), as RedM has no server mount control.
- `RSGCore:Server:OnPlayerUnload` is a server-only event, intentionally not registered as a net event.

---

## Extending the resource

### Add a stable
Append a block to `Config.Stables` (see [Stables](#stables)), restart the resource. Blips and the stablehand NPC are created from the config; race and training distance checks use the same entries.

### Add a breed
Append to `Config.Breeds` (see [Breeds](#breeds)). Prices appear in the Buy menu price bands automatically.

### Add a horse action
```lua
-- Config.HorseActions.actions
{ id = 'bow', glyph = '\u{2193}', anim = {
    dict = 'my_dict@base', base = 'base',
    enterDict = 'my_dict@enter', enter = 'enter',
    exitDict = 'my_dict@exit', exit = 'exit',
} },
```
This creates `/horsebow` and a panel button. Add the label key to every `locales/*.json`.

### Add a feed item
```lua
Config.HorseFeedItems[#Config.HorseFeedItems + 1] =
    { item = 'horse_sugar', label = 'Sugar Cube', health = 5, stamina = 15, hunger = 10 }
```
Add the item to your shared items; the usable-item hook is created for every entry at start.

### Add a tack item
```lua
Config.TackItems.saddle[#Config.TackItems.saddle + 1] =
    { label = 'My Saddle', hash = 0x12345678, price = 60, verified = true, bonus = { speed = 1 } }
```

### Use the resource from another script
```lua
-- Is this ped an owned (stables) horse?
local function isOwnedHorse(ped) return Entity(ped).state.rsgStablesOwned == true end

-- Boost an NPC-less feature when the player rides a well-trained horse
local info = exports['rsg-stables']:GetHorseBonusInfo()
local fast = info and info.training and info.training.stats.speed.level >= 3
```

---

## Locales

Locale JSON files live in `locales/` and load through rsg-core (`@rsg-core/shared/locale.lua`):

```lua
locale('horse_enjoyed', 'Apple')   -- "Your horse enjoyed the Apple"
```

Foal keys: `foal_cannot_ride`, `foal_grown_up` (`%s` = horse name). When adding a key, add it to **all ten** files (`en, de, el, es, fr, ja, nl, pl, pt-br, ro`). Placeholders use `%s` / `%d`. Server functions return the localised string as the error value, so it reaches the player unchanged.

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Tables missing | Look for `[rsg-stables]` SQL errors in the console; confirm `oxmysql` starts first or import `installation/install.sql` |
| "Not close to the stable" | Server uses `pedCoords` / `storeCoords` of `Config.Stables`; check coordinates and `Config.StoreDistance` |
| Horse will not feed/water/brush | Set `Config.DebugHorseChecks = true` to print the failing server check |
| Training disappears at restart | Training XP is saved in `rsg_stables_horses.training`; check the horse row is not deleted |
| Race not listed | `stable` must match a `Config.Stables[].name` and `checkpoints` must not be empty |
| Race run cancelled | A leg was completed faster than `maxSpeed` allows (teleport/lag) or you left your horse for `dismountTimeout` seconds |
| Foal is full size / won't grow | Only horses collected from breeding after the update have `born = 1`; check `Config.FoalGrowth.enabled`, or set `applyToPurchased = true` |
| Other players see a foal full size | The owner's client publishes `rsgFoalScale` on the entity state bag; make sure the horse entity is networked and the other client has `client/foal.lua` running |
| Fence refuses a horse | Owned horses (state bag `rsgStablesOwned`) are never accepted; add locations to `Config.HorseFence.locations` |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, TrainingXP }`. At the end of `rsg-stables:server:finishTraining`, after the horse's training XP is saved, the server calls `AddXP(src, 'horsemanship', TrainingXP, 'horse training')`. The amount comes from config. The horsemanship `speed_bonus` perk is not applied by rsg-stables. Skipped when rsg-skills is not started.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-stables 3.6.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-target`, `oxmysql`, `rsg-inventory`

### Database

Tables: `rsg_stables_horses`, `rsg_stables_breeding`, `rsg_stables_races`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.MaxOwnedHorses` | `8` | max horses a single player can own across all stables |
| `Config.MaxHorsesPerStable` | `20` | max horses a single player can keep at one stable location |
| `Config.RenameCost` | `15` | $ cost to rename an owned horse |
| `Config.InsuranceCost` | `25` | $ cost to insure a horse |
| `Config.ReviveCost` | `40` | $ cost to revive/replace a dead insured horse |
| `Config.StoreDistance` | `8.0` | max distance player's mount can be from stable to store it |
| `Config.PaymentAccount` | `'cash'` | 'cash' or 'bank' |
| `Config.WhistleStopDistance` | `1.0` | whistled horse stops this many meters in front of the player (measured to the horse's nose) |
| `Config.WhistleAnim` | `'WHISTLEHORSESHORT'` | whistle sound + animation played on H ('WHISTLEHORSESHORT', 'WHISTLEHORSELONG', 'WHISTLEHORSEDOUBLE'), false t |
| `Config.WhistleSpawnDistance` | `12.0` | when moved closer, the horse is placed on open ground about this far away (preferring behind you) with a clear |
| `Config.WhistleTeleportDistance` | `60.0` | if the active horse is farther than this when whistled, it's moved near the player instead of walking/running  |
| `Config.AllowTwoPlayersRide` | `false` |  |
| `Config.ActiveHorse` | `table` | brings it back toward the player instead of it being returned to the stable. |
| `Config.HorseFeedItems` | `table` | ===================== FEEDING / NEEDS ===================== |
| `Config.HorseDrinkItems` | `table` |  |
| `Config.HorseStimulant` | `table` | ===================== HORSE STIMULANT ===================== |
| `Config.HorseNeeds` | `table` |  |
| `Config.HorseHitch` | `table` | while hitched so the horse doesn't pull itself off the post and wander. |
| `Config.HorseNaturalDrink` | `table` | ===================== NATURAL DRINKING (rivers / lakes / troughs) ===================== |
| `Config.HorseNaturalGraze` | `table` | ===================== NATURAL GRAZING (hay near the player) ===================== |
| `Config.HolsterStoresLongarms` | `true` | When false, the game default applies (any owned horse stores long guns). |
| `Config.Horseshoes` | `table` | worn they come off and the horse stays degraded until new shoes are fitted at a stable (tack menu -> Horseshoe |
| `Config.HorseLantern` | `table` |  |
| `Config.HorseBrushItem` | `'horse_brush'` | item required (not consumed) to Brush Horse; using it from the inventory brushes your horse |
| `Config.HorseBrushDistance` | `4.0` | how close you must be to your horse to use the brush or a feed item from the inventory (measured to the horse' |
| `Config.DebugHorseChecks` | `false` | prints why a feed/water/brush server check failed to the server console |
| `Config.HorseBrushMounted` | `true` | allow brushing from the saddle (Interaction_Brush, rdr3_discoveries tasks/TASK_ANIMAL_INTERACTION) |
| `Config.HorseBonding` | `table` | ===================== BONDING ===================== |
| `Config.HideNativeBrushFeed` | `true` | hide the game's own Brush / Feed horse prompts (rsg-target options are used instead) |
| `Config.HorseInventory` | `table` | ===================== HORSE INVENTORY ===================== |
| `Config.HorseFlee` | `table` | ===================== FLEE ===================== |
| `Config.HorseActions` | `table` | Horse action ids from rdr3_discoveries tasks/TASK_HORSE_ACTION |
| `Config.WildHorse` | `table` | "Claim Wild Horse" at the stable hand. Only breeds listed in Config.Breeds can be claimed. |
| `Config.Breeding` | `table` | ===================== BREEDING ===================== |
| `Config.HorseAging` | `table` | Age is counted in real-life days since the horse was bought (or born as a foal). |
| `Config.FoalGrowth` | `table` | with other players through the `rsgFoalScale` entity state bag. |
| `Config.Admin` | `table` | transfer to another player or delete. Every action is checked and logged on the server (rsg-log channel `rsgst |
| `Config.AllowPushToTalkWhileOpen` | `true` | While a stables NUI that supports it is open, block game controls but still allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.HorseGive` | `table` | ===================== GIVE HORSE TO ANOTHER PLAYER ===================== |
| `Config.Stables` | `table` | ===================== STABLES ===================== |
| `Config.BreedStatMax` | `10` | ===================== BREEDS ===================== |
| `Config.BuyPriceBands` | `table` | Price ranges shown in the Buy menu "Price" filter (max = nil means no upper limit) |
| `Config.Breeds` | `table` |  |
| `Config.Tack` | `table` | Lets players fit their horse with separate saddle, blanket, saddlebags, horn, stirrups, |
| `Config.Coat` | `table` | mane / tail = 0-254. Applied with SetMetaPedTag on the metaped_tint_horse palette. |
| `Config.TackSounds` | `table` | frontend sound played when cycling tack styles in the customisation menu |
| `Config.TackCategories` | `table` |  |
| `Config.TackItems` | `table` |  |
| `Config.HorseCard` | `table` | Live horse information panel (target "Horse Stats" on your horse, or the command below) |
| `Config.HorseMedicine` | `table` | Health counterpart to the stimulant (SP: CONSUMABLE_HORSE_CARE_PACKAGE / horse medicine) |
| `Config.HorseReviver` | `table` | in the field with the item before it counts as dead (insurance / death rules then apply as normal). |
| `Config.TackBonuses` | `table` | A per-item `bonus = { speed = 1 }` on any Config.TackItems entry overrides its category default. |
| `Config.HorseSell` | `table` | Sell a stabled horse back to the stablehand (Sell Horse in the horse menu) |
| `Config.HorseFence` | `table` | brain data, so add your own locations below (vector4 x, y, z, heading for the fence NPC). |
| `Config.Training` | `table` | Attribute IDs: rsg-redm-brain data/rdr3-native-enums/PedAttribute__AttributeType.md |
| `Config.HorseSpook` | `table` | from rdr3_discoveries tasks/TASK_ANIMAL_INTERACTION) or the timer runs out. |
| `Config.HorseSalvage` | `table` | The saddlebags can still be emptied at its stable afterwards. |
| `Config.HorseRaces` | `table` | Build routes in-game: /raceroute add (at each checkpoint), /raceroute print (prints the config to F8), /racero |
| `Config.Skills` | `table` | rsg-skills integration (optional). Needs the rsg-skills resource; does nothing when it is not started. |
| `Config.Enabled` | `true` |  |
| `Config.Skill` | `'horsemanship'` |  |
| `Config.TrainingXP` | `15` |  |

### Exports

**Client**

| Export | Arguments | File |
|---|---|---|
| `GetActiveHorseNeeds` | `` | `client/client.lua` |
| `GetHorseBonusInfo` | `` | `client/training.lua` |

```lua
-- example
local result = exports['rsg-stables']:GetActiveHorseNeeds()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-stables:client:confirmHorseGift` | client | `cb, giverName, horseName, breedLabel, price` | `client/client.lua` |
| `rsg-stables:client:isHorseDead` | client | `cb, netId` | `client/client.lua` |
| `rsg-stables:server:admin:search` | server | `source, query` | `server/admin.lua` |
| `rsg-stables:server:admin:getOptions` | server | `source` | `server/admin.lua` |
| `rsg-stables:server:admin:getHorses` | server | `source, citizenid` | `server/admin.lua` |
| `rsg-stables:server:admin:updateHorse` | server | `source, horseId, changes` | `server/admin.lua` |
| `rsg-stables:server:admin:action` | server | `source, horseId, action` | `server/admin.lua` |
| `rsg-stables:server:admin:giveHorse` | server | `source, citizenid, model, name, gender, stable, ageDays, foal` | `server/admin.lua` |
| `rsg-stables:server:admin:transferHorse` | server | `source, horseId, targetCitizenid` | `server/admin.lua` |
| `rsg-stables:server:getStableHorses` | server | `source, stableName` | `server/server.lua` |
| `rsg-stables:server:restoreActiveHorse` | server | `source` | `server/server.lua` |
| `rsg-stables:server:toggleLantern` | server | `source` | `server/server.lua` |
| `rsg-stables:server:useStimulant` | server | `source, horseNetId` | `server/server.lua` |
| `rsg-stables:server:feedHorse` | server | `source, preferredItem, horseNetId` | `server/server.lua` |
| `rsg-stables:server:waterHorse` | server | `source, horseNetId` | `server/server.lua` |
| `rsg-stables:server:naturalDrink` | server | `source, horseNetId` | `server/server.lua` |
| `rsg-stables:server:naturalGraze` | server | `source, horseNetId` | `server/server.lua` |
| `rsg-stables:server:brushHorse` | server | `source, horseNetId` | `server/server.lua` |
| `rsg-stables:server:buyHorse` | server | `source, stableName, model, horseName, outfit, gender` | `server/server.lua` |
| `rsg-stables:server:claimWildHorse` | server | `source, stableName, netId, horseName` | `server/server.lua` |
| `rsg-stables:server:retrieveHorse` | server | `source, horseId` | `server/server.lua` |
| `rsg-stables:server:storeHorse` | server | `source, horseId, health, stamina` | `server/server.lua` |
| `rsg-stables:server:fleeStoreHorse` | server | `source, horseId, health, stamina` | `server/server.lua` |
| `rsg-stables:server:horseDied` | server | `source, horseId, netId` | `server/server.lua` |
| `rsg-stables:server:horseDown` | server | `source, netId` | `server/server.lua` |
| `rsg-stables:server:reviveDownedHorse` | server | `source, netId` | `server/server.lua` |
| `rsg-stables:server:useMedicine` | server | `source, horseNetId` | `server/server.lua` |
| `rsg-stables:server:renameHorse` | server | `source, horseId, newName` | `server/server.lua` |
| `rsg-stables:server:insureHorse` | server | `source, horseId` | `server/server.lua` |
| `rsg-stables:server:reviveHorse` | server | `source, horseId` | `server/server.lua` |
| `rsg-stables:server:releaseHorse` | server | `source, horseId` | `server/server.lua` |
| `rsg-stables:server:transferHorse` | server | `source, horseId, newStable` | `server/server.lua` |
| `rsg-stables:server:getNearbyPlayers` | server | `source` | `server/server.lua` |
| `rsg-stables:server:giveHorse` | server | `source, horseId, targetId, price` | `server/server.lua` |
| `rsg-stables:server:getHorseshoeCondition` | server | `source` | `server/server.lua` |
| `rsg-stables:server:wearHorseshoe` | server | `source, horseNetId, seconds` | `server/server.lua` |
| `rsg-stables:server:applyHorseTack` | server | `source, horseId, selections` | `server/server.lua` |
| `rsg-stables:server:applyHorseCoat` | server | `source, horseId, rawCoat` | `server/server.lua` |
| `rsg-stables:server:startBreeding` | server | `source, stableName, idA, idB` | `server/server.lua` |
| `rsg-stables:server:getBreedingJobs` | server | `source, stableName` | `server/server.lua` |
| `rsg-stables:server:collectFoal` | server | `source, breedingId` | `server/server.lua` |
| `rsg-stables:server:getSellPrice` | server | `source, horseId` | `server/server.lua` |
| `rsg-stables:server:sellHorse` | server | `source, horseId` | `server/server.lua` |
| `rsg-stables:server:fenceHorse` | server | `source, fenceIndex, netId` | `server/server.lua` |
| `rsg-stables:server:getRaces` | server | `source, stableName` | `server/server.lua` |
| `rsg-stables:server:startRace` | server | `source, raceId, horseNetId` | `server/server.lua` |
| `rsg-stables:server:raceCheckpoint` | server | `source, idx` | `server/server.lua` |
| `rsg-stables:server:abortRace` | server | `source` | `server/server.lua` |
| `rsg-stables:server:getTraining` | server | `source` | `server/training.lua` |
| `rsg-stables:server:startTraining` | server | `source, stat, horseNetId` | `server/training.lua` |
| `rsg-stables:server:finishTraining` | server | `source, token, hits` | `server/training.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-stables:client:confirmHorseGift', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-stables:client:openAdmin` | client | `` | `client/admin.lua` |
| `rsg-stables:client:adminStoreHorse` | client | `` | `client/admin.lua` |
| `rsg-stables:client:useStimulant` | client | `` | `client/client.lua` |
| `rsg-stables:client:useFeed` | client | `item` | `client/client.lua` |
| `rsg-stables:client:useBrush` | client | `` | `client/client.lua` |
| `rsg-stables:client:useLantern` | client | `` | `client/client.lua` |
| `rsg-stables:client:horseDiedOfAge` | client | `horseId, horseName` | `client/client.lua` |
| `rsg-stables:client:useReviver` | client | `` | `client/client.lua` |
| `rsg-stables:client:useMedicine` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-stables:client:raceRoute` | client | `action` | `client/races.lua` |
| `rsg-stables:client:fieldCorpse` | client | `data` | `client/salvage.lua` |
| `rsg-stables:client:trainingUpdate` | client | `horseId, data` | `client/training.lua` |
| `rsg-stables:server:saveHorsePosition` | server | `horseId, x, y, z, h, health` | `server/server.lua` |
| `rsg-stables:server:wildHorseBroken` | server | `netId` | `server/server.lua` |
| `rsg-stables:server:openHorseInventory` | server | `horseId, horseNetId` | `server/server.lua` |
| `rsg-stables:server:openFieldSaddlebags` | server | `horseId` | `server/server.lua` |
| `rsg-stables:server:openDeadHorseInventory` | server | `horseId` | `server/server.lua` |
| `rsg-stables:server:trainingRideTick` | server | `horseNetId` | `server/training.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-stables:server:saveHorsePosition', horseId, x, y, z, h, health)
-- from a server script
TriggerClientEvent('rsg-stables:client:openAdmin', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/storehorse` |  | `client/client.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
