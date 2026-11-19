# rsg-reputation developer and server owner documentation

## Contents
- [How it works](#how-it-works)
- [Files](#files)
- [Honor, standing and tiers](#honor-standing-and-tiers)
- [Actions](#actions)
- [Server exports](#server-exports)
- [Client exports](#client-exports)
- [Events and callbacks](#events-and-callbacks)
- [Integration examples](#integration-examples)
- [Persistence and decay](#persistence-and-decay)
- [Commands](#commands)
- [Security model](#security-model)
- [Database schema](#database-schema)
- [Server owner how-tos](#server-owner-how-tos)
- [Troubleshooting](#troubleshooting)

## How it works
Each character has one honor number and one standing number per region. Both live in an in-memory cache while the player is online, are loaded from the database the first time they are needed and are written back in batches. Only the server changes them. Other scripts report events through server exports; the client holds a read-only mirror that is refreshed after every change.

Regions are plain ids (`valentine`, `new_hanover`, ...) chosen by the calling script. The resource does not detect where the player is.

## Files
| File | Purpose |
| --- | --- |
| `shared/config.lua` | All settings, tiers, regions and actions. |
| `server/database.lua` | Table creation, cache, loading, decay, saving. |
| `server/reputation.lua` | Tiers, changing and reading values, exports, panel callback. |
| `server/commands.lua` | Admin commands. |
| `client/client.lua` | Read-only mirror and client exports. |
| `client/ui.lua` | Panel open/close, NUI focus with push-to-talk. |
| `html/` | The NUI panel (`index.html`, `style.css`, `script.js`). |
| `locales/*.json` | The 10 languages. |
| `install.sql` | Manual install of the tables. |

## Honor, standing and tiers
- Honor: `Config.Honor.Min` to `Max` (default -1000 to 1000), starting at `Start`.
- Standing: `Config.Standing.Min` to `Max` (default -100 to 100). Below 0 is infamy, above 0 is fame.
- A tier is the entry with the highest `min` that the value has reached. Fields: `min`, `label` (locale key or plain text), and for standing tiers `priceModifier` (fraction added to prices, `0.10` = 10% dearer) and `hostile`.
- Tier tables returned by exports: `{ index, labelKey, label, min, priceModifier, hostile }`. `label` is already translated.
- Spill-over: a change in a town also moves its `parent` state by `Standing.ParentSpill` of the change, rounded toward zero. Spill-over never chains further. Pass `noSpill = true` to skip it.
- Values are always whole numbers and are clamped to the range.

## Actions
`Config.Actions` maps an action name to `{ honor = n, standing = n }`. `ApplyAction(src, name, region)` applies the honor part always and the standing part only when a region is given. Add your own entries freely; scripts only need the name.

| Action | Honor | Standing |
| --- | --- | --- |
| `theft` | -8 | -8 |
| `robbery` | -15 | -15 |
| `murder` | -40 | -30 |
| `bounty_delivered` | 5 | 5 |
| `outlaw_killed` | 8 | 6 |
| `helped_lawman` | 5 | 4 |
| `revive` | 5 | 3 |
| `donation` | 3 | 5 |
| `delivery` | 0 | 2 |

## Server exports
`src` is the player's server ID. Calls that need the player's data wait (inside a thread or event handler) while it is loaded from the database the first time. They return `nil` when the player is not online, a value is not a finite number, or a region is unknown.

### Changing
| Export | Returns | Description |
| --- | --- | --- |
| `AddHonor(src, amount, reason?, quiet?)` | new honor | Add (or subtract) honor. One call is capped by `MaxChangePerCall`. |
| `SetHonor(src, value, reason?, quiet?)` | new honor | Set honor to an exact value (clamped). |
| `AddStanding(src, region, amount, reason?, quiet?, noSpill?)` | new standing of `region` | Add standing; spill-over to the parent state unless `noSpill`. |
| `SetStanding(src, region, value, reason?, quiet?)` | new standing | Set standing exactly. No spill-over. |
| `ApplyAction(src, action, region?)` | `true` / `false` | Apply a named action. `false` for an unknown action. |
| `ResetReputation(src)` | `true` / `false` | Honor and all standing back to the starting values. |

`reason` is passed to the events. `quiet = true` suppresses the notifications for that call.

### Reading
| Export | Returns |
| --- | --- |
| `GetHonor(src)` | honor number |
| `GetHonorTier(src)` | tier table |
| `HasHonor(src, min)` | `true` if honor >= `min` |
| `GetStanding(src, region)` | standing number |
| `GetStandingTier(src, region)` | tier table |
| `HasStanding(src, region, min)` | `true` if standing >= `min` |
| `GetPriceModifier(src, region)` | fraction to add to prices, `0.0` when unknown |
| `IsHostile(src, region)` | `true` when the standing tier is hostile |
| `GetHonorByCitizenId(citizenid)` | honor of an online or offline character |
| `GetRegions()` | the `Config.Regions` table |

## Client exports
Read-only mirror of the local player. Never use it to decide anything that matters on the server.

| Export | Returns |
| --- | --- |
| `GetHonor()` | honor number |
| `GetHonorTier()` | tier table |
| `GetStanding(region)` | standing number (nil for an unknown region) |
| `GetStandingTier(region)` | tier table |
| `GetPriceModifier(region)` | fraction, `0.0` when unknown |
| `IsHostile(region)` | boolean |

## Events and callbacks
| Name | Side | Arguments | Purpose |
| --- | --- | --- | --- |
| `rsg-reputation:server:ready` | server | none | Database is ready. |
| `rsg-reputation:server:honorChanged` | server | `src, new, old, reason` | Honor changed. |
| `rsg-reputation:server:standingChanged` | server | `src, region, new, old, reason` | Standing changed. |
| `rsg-reputation:server:tierChanged` | server | `src, kind, region, oldTier, newTier` | A tier boundary was crossed. `kind` is `'honor'` or `'standing'`; `region` is `nil` for honor. |
| `rsg-reputation:client:sync` | client | `{ honor, standing }` | Server pushes the mirror. Used internally. |
| `rsg-reputation:client:changed` | client | `honor` | Fired locally after a sync so UIs can refresh. |
| `rsg-reputation:client:open` | client | none | Opens the panel. |
| `rsg-reputation:server:getReputation` | callback | none | Panel data. Read only, throttled to one call per second. |
| `rsg-reputation:server:requestSync` | callback | none | Loads the player and pushes the mirror. |

## Integration examples
### Report a delivered bounty (e.g. rsg-bountyhunter)
```lua
-- after the server has verified the delivery and paid the reward
exports['rsg-reputation']:ApplyAction(src, 'bounty_delivered', 'valentine')
```

### Charge more to disliked players (any shop script)
```lua
local mod = exports['rsg-reputation']:GetPriceModifier(src, shop.region)
local price = math.floor(basePrice * (1 + mod) + 0.5)
```

### Lawman reactions
```lua
if exports['rsg-reputation']:IsHostile(src, 'blackwater') then
    -- refuse service, alert the law, spawn guards...
end
```

### Gate a job or item by honor
```lua
if not exports['rsg-reputation']:HasHonor(src, 400) then
    return TriggerClientEvent('RSGCore:Client:Notify', src, { title = 'Reputation', description = 'Not trusted enough', type = 'error' })
end
```

### React to tier changes
```lua
AddEventHandler('rsg-reputation:server:tierChanged', function(src, kind, region, oldTier, newTier)
    if kind == 'standing' and newTier.hostile then
        -- the town has turned on this player
    end
end)
```

## Persistence and decay
- Changed values are written every `SaveInterval` seconds, on logout (`RSGCore:Server:OnPlayerUnload`, `playerDropped`) and when the resource stops. A failed write is kept and retried on the next save.
- Each character has a `decayed` timestamp. For every full day since it, honor and standing move toward 0 by `Decay.PerDay` (when `Decay.Enabled`). The timestamp moves forward by whole days only, so partial days are not lost. Decay runs when a player loads and every 30 minutes for online players; it also covers time spent offline.
- Standing never crosses 0 through decay.

## Commands
See the table in [README.md](README.md). Admin commands also work from the server console (source 0) and answer in the console. All use `Config.AdminPermission`.

## Security model
- Clients cannot change a reputation: there is no client-to-server event that changes values. The only client-callable entries (`getReputation`, `requestSync`) are read-only (they load and send the player's own data).
- Server exports trust their caller. Only call them after your own checks have passed (distance, job, item, cooldown), and never forward client-supplied amounts. Prefer `ApplyAction` so the numbers come from config.
- Amounts must be finite numbers; `NaN`, infinity, strings and unknown regions are rejected. Single calls are capped by `MaxChangePerCall`.
- The panel callback is throttled per player.
- Client exports are for display and convenience only.

## Database schema
Created automatically (`Config.AutoDatabase`), or import `install.sql`.

`rsg_reputation`
| Column | Type | Notes |
| --- | --- | --- |
| `citizenid` | VARCHAR(50) | Primary key |
| `honor` | INT | |
| `decayed` | INT UNSIGNED | Unix time of the last decay |
| `updated` | TIMESTAMP | Updated automatically |

`rsg_reputation_standing`
| Column | Type | Notes |
| --- | --- | --- |
| `citizenid` | VARCHAR(50) | Primary key (part 1) |
| `region` | VARCHAR(50) | Primary key (part 2) |
| `standing` | INT | |

## Server owner how-tos
- **Add a region:** add an entry to `Config.Regions` (`label`, `type`, `parent`, `order`). The panel and commands pick it up. Use the same id in the scripts that report to it.
- **Change a tier:** edit the `Honor.Tiers` or `Standing.Tiers` list. Keep `min` values distinct; they are sorted automatically.
- **Make infamy cost more in shops:** raise `priceModifier` on the negative standing tiers.
- **Turn decay on or off:** `Honor.Decay.Enabled` and `Standing.Decay.Enabled`.
- **Tune an action:** edit `Config.Actions`; scripts that use `ApplyAction` follow automatically.
- **Wipe a player:** `/resetreputation [id]`.

## Troubleshooting
| Problem | Check |
| --- | --- |
| "could not create database tables" in the console | oxmysql is running and the database user may create tables, or set `AutoDatabase = false` and import `install.sql`. |
| Exports return `nil` | The player is not online, the region id is not in `Config.Regions`, or the value is not a number. |
| Panel does not open | Resource started after `rsg-core`? Another resource using NUI focus may hold it. `Config.Command` must not be empty. |
| Changes do not show in the panel | The panel loads when opened; reopen it. |
| A locale shows a raw key | The key is missing from that language file; tier and UI keys must exist in all files. |
| Push-to-talk does not work with the panel open | `Config.AllowPushToTalkWhileOpen` and `PushToTalkControls`. |

---
Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-reputation 3.0.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`oxmysql`, `rsg-core`

### Database

Tables: `rsg_reputation`, `rsg_reputation_standing`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | Tables are created automatically on start. Set to false to import install.sql manually. |
| `Config.AllowPushToTalkWhileOpen` | `true` | While the NUI is open, block game controls but allow push-to-talk. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.Command` | `'reputation'` | Chat command that opens the reputation panel ('' to disable) |
| `Config.AdminPermission` | `'admin'` | Permission level needed for the admin commands |
| `Config.NotifyChanges` | `true` | Small "+5 Honor" / "-8 Valentine standing" notifications on every change (a new one replaces the old one) |
| `Config.NotifyTierChange` | `true` | Notification when a player moves into a new honor or standing tier |
| `Config.SaveInterval` | `60` | Seconds between database saves of changed reputations (also saved on logout) |
| `Config.MaxChangePerCall` | `200` | Safety cap on the size of a single change made through AddHonor / AddStanding |
| `Config.Honor` | `table` |  |
| `Config.Min` | `-1000` |  |
| `Config.Max` | `1000` |  |
| `Config.Start` | `0` |  |
| `Config.Decay` | `{ Enabled = false, PerDay = 5 }` | pulls the score back toward 0 by PerDay for every full day (works while the player is offline too) |
| `Config.Tiers` | `table` |  |
| `Config.Standing` | `table` |  |
| `Config.ParentSpill` | `0.5` | a change in a town also moves its state by this fraction (0 = never), rounded toward zero |
| `Config.Regions` | `table` |  |
| `Config.Actions` | `table` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `AddHonor` | `` | `server/reputation.lua` |
| `SetHonor` | `` | `server/reputation.lua` |
| `GetHonor` | `` | `server/reputation.lua` |
| `GetHonorTier` | `` | `server/reputation.lua` |
| `HasHonor` | `src, min` | `server/reputation.lua` |
| `AddStanding` | `` | `server/reputation.lua` |
| `SetStanding` | `` | `server/reputation.lua` |
| `GetStanding` | `` | `server/reputation.lua` |
| `GetStandingTier` | `` | `server/reputation.lua` |
| `HasStanding` | `src, region, min` | `server/reputation.lua` |
| `GetPriceModifier` | `` | `server/reputation.lua` |
| `IsHostile` | `` | `server/reputation.lua` |
| `ApplyAction` | `` | `server/reputation.lua` |
| `ResetReputation` | `` | `server/reputation.lua` |
| `GetHonorByCitizenId` | `` | `server/reputation.lua` |
| `GetRegions` | `` | `server/reputation.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `GetHonor` | `` | `client/client.lua` |
| `GetHonorTier` | `` | `client/client.lua` |
| `GetStanding` | `region` | `client/client.lua` |
| `GetStandingTier` | `region` | `client/client.lua` |
| `GetPriceModifier` | `region` | `client/client.lua` |
| `IsHostile` | `region` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-reputation']:AddHonor()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-reputation:server:getReputation` | server | `source, cb` | `server/reputation.lua` |
| `rsg-reputation:server:requestSync` | server | `source, cb` | `server/reputation.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-reputation:server:getReputation', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-reputation:client:sync` | client | `data` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-reputation:client:open` | client | `` | `client/ui.lua` |

```lua
-- from a server script
TriggerClientEvent('rsg-reputation:client:sync', source, data)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
