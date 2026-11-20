# rsg-gangs documentation

For server owners and developers. Version 3.1.1.

## Contents

1. [Overview and architecture](#1-overview-and-architecture)
2. [Files](#2-files)
3. [Configuration reference](#3-configuration-reference)
4. [Database](#4-database)
5. [Ranks and permissions](#5-ranks-and-permissions)
6. [The gang wagon](#6-the-gang-wagon)
7. [Camp equipment, crafting and the strongbox](#7-camp-equipment-crafting-and-the-strongbox)
8. [Territories, raids, upkeep and other features](#8-territories-raids-upkeep-and-other-features)
9. [Server exports](#9-server-exports)
10. [Events and callbacks](#10-events-and-callbacks)
11. [Staff admin panel](#11-staff-admin-panel)
12. [Integration examples](#12-integration-examples)
13. [Security model](#13-security-model)
14. [Server owner how-tos](#14-server-owner-how-tos)
15. [Troubleshooting](#15-troubleshooting)

---

## 1. Overview and architecture

rsg-gangs keeps all gang state on the server (`RSGGangs.Gangs` in `server/main.lua`) and mirrors it to the database. The NUI and the client scripts only send requests; every request is validated again on the server (membership, rank permission, distance, amounts, cooldown).

```
 NUI (html/)  ->  client/*.lua  ->  server net event / callback  ->  validation  ->  memory + database
                                                                         |
                                                       RSGGangs.BroadcastGangUpdate -> client:setState -> NUI
```

Props and the wagon are created by a **player's client** (not the server), and the server keeps a registry of them:

| Thing | Spawned by | Server keeps | Removed by |
|---|---|---|---|
| Wagon | nearest player within `Config.RespawnProximityRadius` | one registry entry per gang, kept alive by heartbeats | clients, when the server sends `despawnGangWagon` |
| Camp equipment | nearest player within `Config.RespawnProximityRadius` | `equipmentEntities[gang][item][instance] = netId` | server `DeleteEntity` plus the owning client on stop |

Dependencies: `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`, `rsg-wellpump`, `oxmysql`. Optional integrations: `rsg-log`, `rsg-reputation`, `rsg-bountyhunter`. No ox_lib and no ox_target.

---

## 2. Files

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Resource manifest and dependencies |
| `shared/config.lua` | All settings |
| `server/main.lua` | Gang state, database setup, ranks, bank, membership, exports, the shared `RSGGangs` helper table (cooldowns, grants, distance checks) |
| `server/commands.lua` | Player and admin chat commands |
| `server/wagon.lua` | Wagon registry, heartbeats, parking-spot saving, spawn and despawn streaming |
| `server/equipment.lua` | Camp equipment placement, packing and proximity streaming |
| `server/crafting.lua` | Crafting at deployed stations and well pump bucket filling |
| `server/stash.lua` | Strongbox stash and tier upgrades |
| `server/features.lua` | Territories, raids, upkeep, activity log, member blips, honor, bounties, rivalries, tags, leaderboard, webhook |
| `server/admin.lua` | Staff panel callback `rsg-gangs:server:admin` and `/gangadmin` |
| `server/sv_config.lua` | Server-only settings (Discord webhook) |
| `server/versionchecker.lua` | Optional update check |
| `client/main.lua` | NUI focus (with push-to-talk), state, NUI callbacks that forward to the server |
| `client/vehicle.lua` | Wagon spawn, wagon target, heartbeats, driving restriction, leftover-wagon sweep |
| `client/equipment.lua` | Prop spawn, rsg-gizmo placement, rsg-target options for stations, the well pump and the strongbox |
| `client/crafting.lua` | Opens the crafting view |
| `client/features.lua` | Territory and member blips, log and territory NUI callbacks |
| `client/admin.lua` | Opens the staff panel and relays NUI calls to the server callback |
| `html/` | NUI: `index.html`, `style.css`, `app.js` (gang menu) and `admin.css`, `admin.js` (staff panel). All text comes from the locale files |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (identical keys) |
| `installation/rsg-gangs.sql` | Manual schema (kept identical to the automatic one) |

---

## 3. Configuration reference

Everything is in `shared/config.lua` unless stated.

| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Create tables on start. `false` = import `installation/rsg-gangs.sql` yourself |
| `Config.VersionCheck` | `true` | Print a console message when a newer version exists |
| `Config.Command` | `'setupgang'` | Command that opens the gang menu |
| `Config.Admin` | enabled | `enabled`, `command` (`'gangadmin'`), `permission` (`'admin'`), `logLines` (100) |
| `Config.CreateGangCost` | `5000` | Cash cost to found a gang |
| `Config.MinNameLength` / `MaxNameLength` | `3` / `20` | Gang name length |
| `Config.MaxMembers` | `15` | Member limit (`0` = unlimited) |
| `Config.MaxBankBalance` | `2000000000` | Largest bank balance (database column is a signed 32-bit int) |
| `Config.InviteExpireSeconds` | `120` | How long an invite stays valid |
| `Config.Ranks` | 5 ranks | `name`, `label`, `weight`, `permissions`, `isLeader` |
| `Config.DefaultLeaderRank` / `DefaultJoinRank` | `'leader'` / `'recruit'` | Rank of the founder and of new members |
| `Config.GangColors` | 10 hex colours | Colours a gang can pick |
| `Config.Notify.duration` | `5000` | Notification length in ms |
| `Config.Logging` | disabled | `enabled`, `channel` (needs rsg-log) |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk usable while the UI is open |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left active while the UI is open |
| `Config.WagonInteractDistance` | `40.0` | Max distance from the wagon for equipment actions and wagon reset |
| `Config.StationInteractDistance` | `6.0` | Max distance from a crafting station, the well pump or the strongbox |
| `Config.GangVehicle` | see below | Wagon model, spawn search, driving restriction, target menu |
| `Config.RespawnProximityRadius` | `80.0` | A saved wagon or prop is only spawned when a player is this close |
| `Config.DespawnProximityRadius` | `100.0` | A spawned wagon or prop is removed when nobody is this close |
| `Config.ProximityCheckInterval` | `5000` | ms between streaming checks |
| `Config.DebugWagon` | `false` | Print wagon spawn, save and despawn steps to the server console |
| `Config.GangEquipment` | 7 items (tent, torch, hitchingpost, campfire, crafttable, wellpump, strongbox) | `id`, `label`, `prop`, `initialDistance`, `maxPlacementDistance`, `maxDeployed` |
| `Config.WellPump` | enabled | Well pump targets on the `wellpump` equipment: `equipmentId`, `targetIcon`, `drink`, `drinkIcon`, `requirePermission`. Bucket items, uses, fill time and drinking are in rsg-wellpump |
| `Config.Crafting` | enabled | Stations and recipes |
| `Config.GangStash` | enabled | Strongbox, `minWeight`, storage tiers |
| `Config.ActivityLog` | enabled | `keep` (200), `show` (50), `minWeight` (2) |
| `Config.MemberBlips` | enabled | `interval` ms (3000) |
| `Config.Upkeep` | enabled | `intervalHours` (168), `cost` (2500), `maxMissed` (3) |
| `Config.Territories` | enabled | `maxPerGang`, `incomeIntervalMinutes`, `requireOnlineMember`, `list` |
| `Config.Reputation` | enabled | `claimAction`, `refreshMinutes` (needs rsg-reputation) |
| `Config.Bounties` | enabled | `minReward`, `maxReward`, `maxActive`, `expireHours`, `targetPlayers`, `targetGangs` (needs rsg-bountyhunter 3.4.0+) |
| `Config.Rivalry` | enabled | `pairCooldownSeconds` (300) |
| `Config.Raids` | enabled | `minAttackers`, `holdSeconds`, `durationSeconds`, `cooldownMinutes`, `protectMinutes`, `requireDefenderOnline` |
| `Config.Tags` | enabled | `minLength`, `maxLength` |
| `Config.Leaderboard` | enabled | `size`, `turfPoints`, `killPoints`, `monthlyReset` |
| `SvConfig.Webhook` | disabled | In `server/sv_config.lua`: `Enabled`, `Url`, `Name`, `Actions` |

`Config.GangVehicle`:

```lua
Config.GangVehicle = {
    enabled = true,
    model = 'chuckwagon002x',
    spawnDistance = 6.0,   -- metres in front of the founder to try first
    checkRadius = 3.0,     -- area around the spawn point that must be clear
    maxAttempts = 6,       -- how many times the spawn point is pushed further out
    attemptStep = 2.5,     -- metres added per retry
    restrictDriving = true,
    useTargetMenu = true,  -- open the gang menu from a target on the wagon instead of the chat command
}
```

The server prints configuration warnings on start (duplicate rank names, missing items in recipes, unknown equipment ids). It never stops the resource for them.

---

## 4. Database

Tables are created on start when `Config.AutoDatabase = true`. `ensureDatabase` in `server/main.lua` runs the same statements as `installation/rsg-gangs.sql` and adds missing columns (`rsg_gang_members.name`, `rsg_gangs.upkeep_due`, `upkeep_missed`, `tag`) with non-destructive `ALTER TABLE` statements after checking `INFORMATION_SCHEMA`. Keep the two schemas identical when you change one.

| Table | Columns |
|---|---|
| `rsg_gangs` | `name` (key), `label`, `color`, `bank`, `owner`, `created_at`, `wagon_x/y/z/heading`, `stash_tier`, `stash_id`, `upkeep_due` (unix time), `upkeep_missed`, `tag` |
| `rsg_gang_members` | `citizenid` (key), `gang_name`, `rank`, `name`, `joined_at` |
| `rsg_gang_equipment` | `id`, `gang_name`, `item_id`, `x`, `y`, `z`, `heading`, `created_at` |
| `rsg_gang_logs` | `id`, `gang_name`, `citizenid`, `actor`, `action`, `detail`, `created_at` |
| `rsg_gang_rivals` | `gang_name`, `rival_name`, `kills` (kills by the first gang against the second) |
| `rsg_gang_bounties` | `id`, `gang_name`, `reward`, `target_type` (`player` or `gang`), `target_id` (citizenid or gang name), `target_name`, `created_at` (escrow ledger) |
| `rsg_gang_territories` | `territory_id` (key), `gang_name`, `claimed_at` |

Members, equipment, logs and territories are removed automatically when their gang row is deleted (foreign keys with `ON DELETE CASCADE`). The strongbox lives in rsg-inventory under `rsg_gang_stash_<stash_id>`; rsg-inventory keeps that inventory after a gang is disbanded.

The wagon's saved parking spot is `rsg_gangs.wagon_x/y/z/heading`.

---

## 5. Ranks and permissions

Ranks are in `Config.Ranks` (`name`, `label`, `weight`, `isLeader`, `permissions`). Weights must be consecutive from 0 because promote and demote step by one.

| Permission | Allows |
|---|---|
| `invite` | Invite players |
| `kick` | Kick lower-ranked members |
| `promote`, `demote` | Change the rank of lower-ranked members |
| `deposit`, `withdraw` | Gang bank |
| `upgrade` | Strongbox upgrades, claim, abandon and raid territories |
| `bounty` | Post gang bounties |
| `rename` | Rename the gang and set its tag |
| `setcolor` | Change the gang colour |
| `disband` | Disband the gang |
| `equipment` | Wagon reset, set up and pack away camp equipment, crafting |

Rules enforced on the server:

- You can only kick, promote or demote members of a lower weight than your own, and a promotion can never reach your own weight.
- The leader cannot leave while others remain; use leadership transfer first. The last member leaving removes the gang, its wagon and its equipment.
- Opening the strongbox needs `Config.GangStash.minWeight`.

Example of a custom rank:

```lua
{ name = 'quartermaster', label = 'Quartermaster', weight = 2,
  permissions = { 'withdraw', 'deposit', 'equipment', 'upgrade' } },
```

---

## 6. The gang wagon

The wagon is the gang's base: the "manage outfit" target opens the menu, and equipment is placed relative to it.

### Lifecycle

1. **Creation.** When a gang is founded the server issues the founder two single-use grants (`spot:<gang>` and `wagon:<gang>`) and sends `rsg-gangs:client:findGangVehicleSpot`. The client finds a clear spot, reports it (`gangVehicleSpotFound`, validated against the player's real position), and spawns the wagon.
2. **Registration.** The spawning client reports the net id (`gangWagonSpawned`). The server accepts it only with the grant, checks model and type only when it can see the entity, and creates the registry entry. The client also tags the entity with the `rsgGangWagon` state bag.
3. **Heartbeats.** Every client within 120 m of the wagon sends `rsg-gangs:server:wagonHeartbeat` every 4 seconds. Any nearby client keeps the entry alive. Heartbeats from a **member of the owning gang** also update the live position, and when the wagon is standing still and no camp equipment is deployed, the new parking spot is written to the database.
4. **Despawn.** When nobody is within `Config.DespawnProximityRadius`, the server drops the entry and broadcasts `rsg-gangs:client:despawnGangWagon`. Clients that have the entity delete it (asking for network control first).
5. **Respawn.** When no entry exists and a player comes within `Config.RespawnProximityRadius` of the saved spot, the server grants that player the right to register a wagon and asks them to spawn it. The same happens when heartbeats stop for 20 seconds (destroyed wagon).
6. **Restart.** On stop each client deletes the wagons it controls and removes the wagon target. The position was already saved by the heartbeats. On start, clients delete any wagon carrying the `rsgGangWagon` state bag that is not in the current registry (it must be seen that way on two checks in a row). The streaming loop then spawns a fresh one at the saved spot.

The server never needs to see the wagon entity, which is why saving and cleanup keep working even when server-side entity lookups of client-spawned vehicles fail.

### The target

The "manage outfit" option is registered once on the wagon **model** with `exports['rsg-target']:addModel`. Every client gets it, and it survives respawns and restarts. `canInteract` only shows it to members of the gang that owns that wagon (looked up by net id in the registry).

### Restrictions

- `restrictDriving`: players outside the owning gang are forced out of the driver seat.
- A gang member cannot drive the wagon while camp equipment is deployed (pack it away first), because equipment stays at its own position.
- Camp equipment is never moved with the wagon. The parking spot is not saved while equipment is deployed.

### Admin tools

`/setgangwagon <gang>` (or the staff panel) saves your position as the wagon spot and removes the current wagon so it respawns there. The staff panel can also clear the spot.

### Debugging

Set `Config.DebugWagon = true`. Typical log for a restart:

```
[rsg-gangs:wagon] asked 1 to spawn the wagon of rex_gang
[rsg-gangs:wagon] registered wagon of rex_gang net id 74
[rsg-gangs:wagon] saved parking spot for rex_gang -155.69 541.06 114.81
```

---

## 7. Camp equipment, crafting and the strongbox

### Equipment

`Config.GangEquipment` lists the items a gang can set up. `id` is the stable key used in the database and the recipe/stash links, so never rename an `id` that is in use.

```lua
{
    id = 'torch',
    label = 'Camp Torch',
    prop = 'p_torchpost01x',          -- prop model
    initialDistance = 2.0,            -- metres in front of the player where the ghost starts
    maxPlacementDistance = 10.0,      -- final spot must be within this of the wagon (server-enforced)
    maxDeployed = 5,                  -- how many can be out at once (server-enforced)
},
```

Placement flow (every step is checked on the server):

1. `deployEquipment(itemId)`: member with `equipment`, within `Config.WagonInteractDistance` of the wagon, below `maxDeployed`, no other placement in progress for that gang and item. The server issues a placement grant and tells the client to start rsg-gizmo.
2. `equipmentPlaced(itemId, coords, heading)`: consumes the grant, re-validates the spot (close to the wagon and to the player), inserts the row and asks a nearby client to spawn the prop.
3. `equipmentSpawned(...)`: the spawning client registers the prop with a single-use grant.
4. `packEquipment(itemId)`: removes the most recently placed instance.

Props only exist while a player is within `Config.RespawnProximityRadius`.

### Crafting

Stations are `Config.Crafting.stations`, each tied to an equipment id:

```lua
{
    id = 'campfire_cook',
    equipmentId = 'campfire',
    label = 'Campfire',
    targetLabel = 'Cook',
    targetIcon = 'fas fa-fire',
    intro = 'Cook food over the fire using ingredients from your own saddlebag.',
    recipes = {
        {
            id = 'cooked_meat',
            label = 'Cooked Meat',
            ingredients = { { item = 'raw_meat', amount = 1 } },
            output = { item = 'cooked_meat', amount = 1 },
        },
    },
},
```

The server checks permission, that the gang has the station deployed, that the player is next to it, the ingredients, and `CanAddItem` for the output. Ingredients are refunded if the reward cannot be given.

### Well pump

The `wellpump` equipment item (`p_wellpumpnbx01x`) gets **Fill Bucket** and **Drink Water** targets. Only members of the gang that owns the pump see it. The bucket logic lives in **rsg-wellpump** (a required dependency): it plays the animation, swaps the items and sets the uses on the filled bucket, so the bucket works the same in every resource. Which items, how many uses and how long the fill takes are set in rsg-wellpump's `Config.EmptyItem`, `Config.FullItem`, `Config.BucketUses` and `Config.FillTime`.

`Config.WellPump` in rsg-gangs:

```lua
Config.WellPump = {
    enabled = true,
    equipmentId = 'wellpump',    -- the Config.GangEquipment id
    targetIcon = 'fa-solid fa-droplet',
    drink = true,                -- also show Drink Water
    drinkIcon = 'fa-solid fa-glass-water',
    requirePermission = false,   -- true = only ranks with 'equipment'
}
```

Flow: the target calls `exports['rsg-wellpump']:PlayFill()` on the client (checks for an empty bucket, plays the progress bar), then fires `rsg-gangs:server:fillBucket`. The server checks the rate limit (80% of rsg-wellpump's fill time), gang membership, the optional `equipment` permission, that the gang has a pump deployed and that the player is next to it. Only then does it call `exports['rsg-wellpump']:FillBucket(src)`.

Drinking works the same way: the client calls `exports['rsg-wellpump']:PlayDrink()` (checks thirst, plays the animation), then fires `rsg-gangs:server:drinkWater`. After the same gang and distance checks the server calls `exports['rsg-wellpump']:Drink(src)`, which enforces rsg-wellpump's drink cooldown, picks the thirst amount and raises thirst on the client.

### Strongbox

`Config.GangStash` ties the stash to the `strongbox` equipment. Tiers (`slots`, `maxWeight`, `upgradeCost`) are bought with gang bank money by members with `upgrade`. The upgrade charges the bank and sets the tier in one SQL statement.

---

## 8. Territories, raids, upkeep and other features

- **Activity log.** `RSGGangs.AddLog(gang, citizenid, action, ...)` stores a row; the UI renders it with the `log_<action>` locale key, filling `%s` from the `|`-separated detail. Readable from `Config.ActivityLog.minWeight`. Rows are pruned to `keep` every 30 minutes.
- **Territories.** `claimTerritory(id)` and `abandonTerritory(id)` need `upgrade`. A claim checks the config entry, that the player is inside the radius (server position), the per-gang limit, that the turf is free and the bank balance. The row is inserted with `INSERT IGNORE` first so two gangs cannot both win. Income is paid every `incomeIntervalMinutes` (only while a member is online when `requireOnlineMember` is true). Turf is freed when a gang is destroyed.
- **Raids.** `startRaid(id)` needs `upgrade`, an owned unprotected territory of another gang, the caller inside it, `minAttackers` raiders inside, a defender online (if configured), and no active raid or cooldown. Every 5 seconds the server counts members inside (server positions); time counts toward `holdSeconds` only while attackers out-number defenders. Reaching it transfers ownership and starts protection; running out `durationSeconds` first defends it.
- **Upkeep.** Checked every minute. When `upkeep_due` passes, the cost is taken from the bank. A failed payment adds to `upkeep_missed`; at `maxMissed` the gang is disbanded.
- **Member blips.** The server sends each member only the positions of the other online members of their own gang, plus the live wagon position. Positions come from the server. Each player can hide themselves (client KVP, sent with `setBlips`).
- **Reputation.** Gang honor is the rounded average of `exports['rsg-reputation']:GetHonorByCitizenId` over the members, refreshed every `Config.Reputation.refreshMinutes`. A territory claim calls `ApplyAction(src, claimAction, region)`.
- **Rivalries.** Listens to the server-only `RSGCore:Server:OnPlayerKilled`. A kill between members of two different gangs adds 1 to `rsg_gang_rivals`; the same killer and victim count once per `pairCooldownSeconds`.
- **Bounties.** A bounty always names a target: one online player, or a rival gang. In the gang UI the member enters the amount, picks Player or Rival gang, and chooses the target from an HTML dropdown filled by the `rsg-gangs:server:bountyTargets` callback (players are listed by character name and sent back as server ids, gangs by label and sent back as gang names; the callback needs `bounty`). `postBounty(amount, targetType, targetId)` needs `bounty` and checks, on the server: the amount range, that the target still exists, that it is not the player themselves or anyone in the posting gang, that the gang has no bounty on that target already, `maxActive`, and the bank balance. Posts from one gang are serialised so two members cannot slip past `maxActive`. The amount moves from the bank into escrow (`rsg_gang_bounties`) and `rsg-bountyhunter:PostBounty` is called inside a `pcall` with `targetCitizenid` (player) or `targetGang` (gang), `targetName` and `sponsorGang`; if it fails the escrow is returned. A hunter follows a moving search area on the map and brings the target (or, for a gang bounty, any online member of that gang) to a sheriff's office dead, hogtied or cuffed. Members of the posting gang cannot take their own bounty, and a hunter cannot take a bounty on their own gang. When the poster closes, rsg-bountyhunter fires the server-only event `rsg-bountyhunter:server:posterClosed(ref, reason, paid)`: on `completed` the unpaid remainder returns to the bank, otherwise the full amount does. Escrow left over from a restart is refunded on start. rsg-bountyhunter reads gang membership through the `GetPlayerGang` and `GetGangOnlineSources` exports.
- **Tags.** `setTag(tag)` needs `rename`; it upper-cases, strips non-alphanumerics and checks `minLength`..`maxLength`.
- **Leaderboard.** Score = turf x `turfPoints` + rival kills x `killPoints`. With `monthlyReset`, the first check in a new calendar month clears `rsg_gang_rivals` (season stored in a server KVP).
- **Webhook.** `server/sv_config.lua` is server-only so the URL never reaches players. Messages are queued (one per 1.5 s, 50 max) and sent with `allowed_mentions = { parse = {} }`, so gang names cannot ping anyone. Only actions listed in `SvConfig.Webhook.Actions` are sent.

---

## 9. Server exports

| Export | Returns |
|---|---|
| `GetPlayerGang(citizenid)` | `{ name, label, color, rank }` or `nil` |
| `GetGangData(gangName)` | Full gang payload (label, color, bank, members, equipment, stash tiers, territories, ...) or `nil` |
| `IsGangLeader(citizenid)` | boolean |
| `HasGangPermission(citizenid, permission)` | boolean |
| `GetGangMembers(gangName)` | List of `{ citizenid, name, rank, rankLabel, weight, online }` or `nil` |
| `GetGangBank(gangName)` | Balance or `nil` |
| `AddGangBank(gangName, amount, reason?)` | `true` on success (whole positive amount, capped by `Config.MaxBankBalance`) |
| `RemoveGangBank(gangName, amount, reason?)` | `true` on success (fails when funds are short) |
| `GetGangTag(serverId)` | The player's gang tag or `nil` |
| `GetGangOnlineSources(gangName)` | List of server ids of the gang's online members (empty if the gang does not exist); used by rsg-bountyhunter for gang bounties |

```lua
-- Who is this player, and are they allowed to do the thing?
local Player = RSGCore.Functions.GetPlayer(src)
local citizenid = Player.PlayerData.citizenid

local gang = exports['rsg-gangs']:GetPlayerGang(citizenid)
if gang and exports['rsg-gangs']:HasGangPermission(citizenid, 'withdraw') then
    print(('%s is in %s as %s'):format(citizenid, gang.label, gang.rank))
end
```

```lua
-- Spend gang money, hand over the goods only when it worked
local ok = exports['rsg-gangs']:RemoveGangBank('delobo', 250, 'ammo order')
if ok then
    exports['rsg-inventory']:AddItem(src, 'ammo_rifle', 20, nil, nil, 'gang-ammo-order')
end
```

Other scripts that move gang money must do their own distance and permission checks first.

---

## 10. Events and callbacks

Client-to-server events are internal. They are all validated and rate limited, and other resources should use the exports instead.

### Server net events (`rsg-gangs:server:*`)

| Event | Arguments | Needs |
|---|---|---|
| `requestState` | none | in game |
| `createGang` | `label` | cash, not in a gang |
| `disbandGang` | none | `disband` |
| `invitePlayer` | `serverId` | `invite` |
| `acceptInvite`, `declineInvite` | none | a pending invite |
| `kickMember`, `promoteMember`, `demoteMember`, `transferLeadership` | `citizenid` | `kick` / `promote` / `demote` / leader |
| `leaveGang` | none | member |
| `depositMoney`, `withdrawMoney` | `amount` | `deposit` / `withdraw` |
| `renameGang`, `setColor`, `setTag` | `label` / `color` / `tag` | `rename` / `setcolor` / `rename` |
| `deployEquipment`, `packEquipment` | `itemId` | `equipment`, near the wagon |
| `equipmentPlaced`, `equipmentPlacementCancelled`, `equipmentSpawned` | placement data | server grant |
| `requestEquipmentRegistry` | none | cooldown |
| `craftItem` | `stationId`, `recipeId` | `equipment`, near the station |
| `openGangStash`, `upgradeGangStash` | none | `Config.GangStash.minWeight` / `upgrade` |
| `resetWagon` | none | `equipment`, near the wagon, 30 s cooldown |
| `gangVehicleSpotFound`, `gangVehicleSpotFailed`, `gangWagonSpawned` | wagon data | server grant |
| `wagonHeartbeat` | `gang`, `netId`, `coords`, `heading`, `stationary` | nearby client |
| `gangWagonMoved` | `gang`, `coords`, `heading` | nearby gang member |
| `requestWagonRegistry` | none | cooldown |
| `claimTerritory`, `abandonTerritory`, `startRaid` | `territoryId` | `upgrade` |
| `requestTerritories`, `requestLogs`, `requestLeaderboard` | none | member / rank |
| `postBounty` | `amount`, `targetType` (`player` or `gang`), `targetId` (server id or gang name) | `bounty` |
| `setBlips` | `enabled` | cooldown |

### Server to client events (`rsg-gangs:client:*`)

| Event | Purpose |
|---|---|
| `setState(state)` | Full UI state for the player |
| `openMenu`, `closeMenu`, `openCraftMenu(stationId)`, `openAdmin` | UI control |
| `requestAccept`, `requestDecline` | Chat command relays |
| `findGangVehicleSpot(gang)`, `spawnGangWagonAt(gang, wagon)`, `despawnGangWagon(gang, netId)` | Wagon spawn control |
| `wagonRegistered`, `wagonUnregistered`, `wagonRegistrySync` | Wagon registry |
| `spawnEquipmentAt`, `startEquipmentPlacement`, `equipmentRegistered`, `equipmentUnregistered`, `equipmentRegistrySync` | Equipment control |
| `territories`, `memberBlips`, `logs`, `leaderboard` | Map and tab data |
| `adminTeleport(x, y, z)` | Staff teleport |

### Callbacks (rsg-core)

| Callback | Direction | Purpose |
|---|---|---|
| `rsg-gangs:server:admin(action, payload)` | client to server | Staff panel (see section 11) |

### State bag

`Entity(wagon).state.rsgGangWagon = <gangName>` marks a wagon spawned by this resource.

### NUI callbacks

`close`, `refresh`, `createGang`, `disbandGang`, `invitePlayer`, `kickMember`, `leaveGang`, `promoteMember`, `demoteMember`, `transferLeadership`, `depositMoney`, `withdrawMoney`, `renameGang`, `setColor`, `deployEquipment`, `packEquipment`, `upgradeGangStash`, `resetWagon`, `craftItem`, `declineInvite`, `setBlips`, `requestLeaderboard`, `startRaid`, `setTag`, `requestLogs`, `postBounty`, `bountyTargets`, `claimTerritory`, `abandonTerritory`, `adminCall`, `adminClose`. Each one only forwards to the matching server event; `bountyTargets` instead awaits the `rsg-gangs:server:bountyTargets` callback and returns its list to the dropdown.

---

## 11. Staff admin panel

Opened with `/gangadmin` (`Config.Admin.command`, permission `Config.Admin.permission`, default `admin`). All traffic goes through the rsg-core callback `rsg-gangs:server:admin(action, payload)`, which returns `{ ok = true, ... }` or `{ ok = false, error = <localised text> }`. The server re-checks the permission on every call, rate limits (150 ms reads, 500 ms writes) and runs the handler under `pcall`.

| Action | Payload | Effect |
|---|---|---|
| `snapshot` | none | Stats, all gangs, territories, ranks, stash tiers, colours and limits |
| `gang` | `name` | Gang detail (members, equipment, territories, upkeep) plus recent log |
| `players` | none | Online players with their gang |
| `createGang`, `deleteGang`, `renameGang`, `setTag`, `setColor` | `name`, `label`/`tag`/`color` | Gang lifecycle and look |
| `bank` | `name`, `mode` (`add`/`remove`/`set`), `amount` | Bank change, capped by `Config.MaxBankBalance` |
| `setStash` | `name`, `tier` | Set the strongbox tier |
| `resetUpkeep` | `name` | Clear missed cycles and reschedule |
| `addMember`, `removeMember`, `setRank`, `transferLeader` | `name`, `citizenid`/`id`, `rank` | Membership and ranks |
| `setWagonHere`, `clearWagon`, `packEquipment`, `clearRivals` | `name` | Assets and rivalry data |
| `setTerritory` | `id`, `gang` or none | Assign or free turf (also ends a raid and clears protection) |
| `teleport` | `kind` (`wagon`/`territory`), `name`/`id` | Staff member goes to the spot |

Each change adds an `admin` entry to the gang's activity log and an rsg-log entry.

---

## 12. Integration examples

### Pay a gang from a heist script

```lua
-- server side of your heist resource
RegisterNetEvent('myheist:server:finish', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- your own checks first: did this player really finish the heist, are they near the vault, cooldown...
    local gang = exports['rsg-gangs']:GetPlayerGang(Player.PlayerData.citizenid)
    if gang then
        exports['rsg-gangs']:AddGangBank(gang.name, 1500, 'bank heist')
    end
end)
```

### Show the gang tag in a chat or name resource

```lua
local tag = exports['rsg-gangs']:GetGangTag(source) -- 'DLB' or nil
local name = tag and ('[%s] %s'):format(tag, playerName) or playerName
```

### Gate a feature on a gang permission

```lua
local function canUseGangArmoury(citizenid)
    return exports['rsg-gangs']:HasGangPermission(citizenid, 'equipment')
end
```

### Open the gang menu from another script

```lua
-- client side: the menu is a normal client event
TriggerEvent('rsg-gangs:client:openMenu')
```

### Webhook setup (`server/sv_config.lua`)

```lua
SvConfig.Webhook = {
    Enabled = true,
    Url = 'https://discord.com/api/webhooks/...',
    Name = 'rsg-gangs',
    Actions = { created = true, raid_won = true, raid_lost = true, territory_claim = true },
}
```

---

## 13. Security model

- Every action re-checks rank, permission and gang membership on the server. The NUI only sends requests.
- Amounts must be whole, positive, finite and within limits. Bank changes update memory first and the database with a delta, so overlapping updates cannot overwrite each other. Deposits and withdrawals refund on failure.
- Names, tags and labels are cleaned (control characters and markup removed) and length checked. The NUI escapes all text before inserting it. The Discord webhook sends `allowed_mentions = { parse = {} }`.
- Per-player cooldowns on every action (`RSGGangs.OnCooldown`), cleared when the player leaves.
- **Grants.** The server issues single-use, time-limited grants (`RSGGangs.Grant` / `ConsumeGrant`) for things a client may report once: the wagon or prop it was asked to spawn, a placement it was approved to start. A client cannot invent these reports.
- **Wagon.** A wagon registration needs the grant. Heartbeats and parking reports must come from a player within 150 m of the reported position, and only members of the owning gang can change the saved spot.
- **Equipment.** Placement needs the player at the wagon, a server grant, a spot within `maxPlacementDistance`, and respects `maxDeployed`.
- Filling a bucket needs the player next to the gang's own deployed well pump; the server rate-limits it to the fill time, and rsg-wellpump checks the empty bucket and refunds it if the full one cannot be added.
- Crafting and the stash need the player next to the gang's own deployed station; `CanAddItem` is checked and ingredients are refunded if the reward cannot be given.
- The staff panel is server-gated by an rsg-core permission on every call.
- Invites expire and are cleared when a gang is disbanded.
- Territory ownership is reserved in memory before the database write, so two gangs cannot claim the same turf.
- Bounty escrow is returned if rsg-bountyhunter errors.

---

## 14. Server owner how-tos

- **Add equipment:** add an entry to `Config.GangEquipment` with a unique `id`, a `prop`, `maxPlacementDistance` and `maxDeployed`.
- **Change what the pump gives:** edit `Config.EmptyItem`, `Config.FullItem` and `Config.BucketUses` in rsg-wellpump; both items must exist in your rsg-core items.
- **Add a recipe:** add it to a station in `Config.Crafting.stations`; its items must exist in your rsg-core items. The server prints a warning on start for missing items.
- **Add a territory:** add `{ id, label, coords, region, radius, claimCost, income }` to `Config.Territories.list`. Entries with bad coordinates or duplicate ids are ignored with a console warning.
- **Change the language:** `setr rsg:locale <code>`.
- **Move a wagon:** stand where it should be and run `/setgangwagon <gang>`, or drive it there and leave it (the spot is saved after it has stood still for a few seconds, as long as no camp equipment is deployed).
- **Push-to-talk while the UI is open:** `Config.AllowPushToTalkWhileOpen` and `Config.PushToTalkControls`.
- **Logging:** set `Config.Logging.enabled = true` and a `channel` that exists in rsg-log.
- **Manual database install:** `Config.AutoDatabase = false`, then import `installation/rsg-gangs.sql`.

---

## 15. Troubleshooting

| Problem | Fix |
|---|---|
| "Failed to load gangs" in the console | Tables are missing: enable `Config.AutoDatabase` or import the SQL |
| Wagon has no target | `rsg-target` must start before `rsg-gangs`; you must be in the gang that owns the wagon |
| Wagon never appears | Check `Config.GangVehicle.enabled`; stand within `Config.RespawnProximityRadius` of the saved spot; use `/setgangwagon` if the spot is bad; turn on `Config.DebugWagon` |
| Wagon returns to its old spot after a restart | Camp equipment is deployed (the spot is not saved then); pack it away, move the wagon, wait a few seconds |
| An old wagon is left standing after a restart | A wagon spawned by an older version has no tag; remove it once by hand or restart the server |
| Two wagons for one gang | Should not happen; turn on `Config.DebugWagon` and send the console lines |
| No "Fill Bucket" option on the well pump | Deploy the pump (`wellpump`) first; be in the gang that owns it; `Config.WellPump.enabled` must be `true`; `rsg-target` and `rsg-wellpump` must start before `rsg-gangs` |
| Placement does nothing | `rsg-gizmo` must be started; stay within the placement range of the wagon |
| Config warning about an item | Add the item to your items list or fix the recipe |
| `/gangadmin` says no permission | Give the player the rsg-core permission in `Config.Admin.permission` |
| Staff panel text missing | Locale keys `admin_*`, `ui_adm_*` must exist in the active language file |
| Ranks cannot upgrade storage | Add `'upgrade'` to that rank's permissions |
| Ranks cannot post bounties | Add `'bounty'` to that rank's permissions |
| Bounty dropdown is empty | No other player is online (player bounties) or no other gang exists (gang bounties); `Config.Bounties.targetPlayers` / `targetGangs` can also be off |
| Bounty board shows no gang bounties | rsg-bountyhunter must be 3.4.0+ and started; older versions ignore the target fields |
| Upgrading: `rsg_gang_bounties` has no target columns | They are added automatically on start. For a manual install run `ALTER TABLE rsg_gang_bounties ADD COLUMN target_type varchar(10) NOT NULL DEFAULT 'player', ADD COLUMN target_id varchar(50) DEFAULT NULL, ADD COLUMN target_name varchar(100) DEFAULT NULL;` |

Support: https://rexshack.tebex.store
