# rsg-housing – Developer & Server Owner Docs

Monthly house rentals for the RSG Framework (RedM). This file documents everything: installation, configuration, the public API other scripts can use, the internal callbacks, the database, and the security model. For a player-facing overview see `README.md`; for what changed between versions see `CHANGELOG.md`.

## Contents
1. [Requirements](#requirements)
2. [File layout](#file-layout)
3. [Installation and upgrading](#installation-and-upgrading)
4. [How it works](#how-it-works)
5. [Configuration reference](#configuration-reference)
6. [Server API (exports)](#server-api-exports)
7. [Hook events](#hook-events)
8. [Client API](#client-api)
9. [Commands and permissions](#commands-and-permissions)
10. [Internal callbacks and events](#internal-callbacks-and-events)
11. [Database](#database)
12. [Security model](#security-model)
13. [Locales](#locales)
14. [NUI](#nui)
15. [Troubleshooting](#troubleshooting)

## Requirements
| Resource | Needed for |
|---|---|
| `rsg-core` | Framework, locales (`@rsg-core/shared/locale.lua`), notify, callbacks, commands, cron (`RSGCore.Functions.CreateCron`) |
| `oxmysql` | Database |
| `rsg-inventory` | House storage stashes |
| `rsg-target` | Move / remove options on placed furniture |
| `rsg-gizmo` | Placing and moving furniture |
| `rsg-telegram` (optional) | Rent telegrams and the house mailbox (`Config.TelegramResource`) |
| `rsg-wardrobe` / `rsg-character` (optional) | Wardrobe at the house (`Config.WardrobeResource`) |
| `rsg-bossmenu` (optional) | Only when `Config.EnableGovernor = true` |
| `rsg-log` (optional) | Admin and eviction logs |

There is **no ox_lib dependency**. Everything comes from rsg-core:

| Feature | Used |
|---|---|
| Locales | `@rsg-core/shared/locale.lua` + `locale('key')`, language from the `rsg:locale` convar |
| Notify (client) | `RSGCore.Functions.Notify({...})` |
| Notify (server) | `TriggerClientEvent('RSGCore:Client:Notify', src, {...})` |
| Callbacks (server) | `RSGCore.Functions.CreateCallback` through the local `registerCallback(name, handler)` wrapper: handlers `return` values and the wrapper passes them to `cb(...)` |
| Callbacks (client) | `RSGCore.Functions.AwaitCallback(name, nil, ...)` (10 s timeout, `nil` on timeout) |
| Assets | `RSGCore.Functions.RequestModel` / `RequestAnimDict` |
| Rent check | `RSGCore.Functions.CreateCron(Config.RentCheckCronJob, job)` – a standard 5-field cron expression |

## File layout
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest and dependencies |
| `shared/config.lua` | All settings, the house list (`Config.Houses`), door list (`Config.HouseDoors`), furniture list (`Config.DecorProps`) |
| `server/server.lua` | Database setup, rent logic, keys, storage, doors, props, admin panel, rent check, **public API** |
| `server/versionchecker.lua` | Prints a console notice when a newer version exists |
| `client/client.lua` | Blips, door prompt and key animation, house menu prompt `[J]`, NUI bridge, admin panel bridge, `/myhouse`, **client API** |
| `client/props.lua` | Furniture streaming, spawning, move / remove targets, placement with rsg-gizmo |
| `html/` | NUI (`index.html`, `style.css`, `app.js`) |
| `locales/*.json` | 11 languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |
| `installation/rsg-housing.sql` | Schema (the script also builds it automatically) |

## Installation and upgrading
1. Put `rsg-housing` in your resources folder and `ensure rsg-housing` **after** its dependencies.
2. Start the server. With `Config.AutoDatabase = true` (default) the tables, missing columns, the widened `houseid` columns and the indexes are created on start. Nothing is ever dropped or rewritten.
3. Manual install: set `Config.AutoDatabase = false` and import `installation/rsg-housing.sql` (it uses `CREATE TABLE IF NOT EXISTS` and `INSERT IGNORE`, so re-importing is safe).
4. Set each house's rent in `/houseadmin`, or run `UPDATE rsg_housing SET rent = 50;`.

**Adding a house.** Add an entry to `Config.Houses` (and its doors to `Config.HouseDoors`):
```lua
{
    name       = 'House 49',
    houseid    = 'house49',            -- unique, up to 20 characters
    region     = 'newhanover',         -- gets the database row automatically (optional: rent = 50)
    menucoords = vector3(0.0, 0.0, 0.0), -- where [J] opens the panel (server checks distance to this)
    blipcoords = vector3(0.0, 0.0, 0.0),
    showblip   = true
},
```
Without `region` the console warns that the house has no row and cannot be rented until one exists.

**Door ids** in `Config.HouseDoors` are door hashes (`doorid`) with the position of the door (`doorcoords`) and the owning `houseid`. Vacant houses stay unlocked so players can view them.

**Upgrading.** Replace the folder and restart. Existing guests keep full access; new columns get safe defaults.

## How it works
- **Renting.** At the house menu spot press `[J]`. The first month is paid up front in cash. The update is conditional (`WHERE rented = 0`), so two players can't rent the same house, and the money is refunded if the house was taken. `Config.MaxHousesPerPlayer` limits houses per character.
- **Rent cycle.** Rent is due on the same calendar day each month (`DATE_ADD(rent_due, INTERVAL 1 MONTH)`). A tenant can pay when due within one month, never further ahead. The hourly rent check (`Config.RentCheckCronJob`) sends one reminder per period (`Config.ReminderDays` before) and evicts tenants more than `Config.GracePeriodDays` past due. Tenants are also reminded at login (`Config.LoginRentReminder`).
- **Keys and permissions.** The tenant has a key (`guest = 0`) with every permission. Guests (`guest = 1`) get `doors`, `storage`, `wardrobe`, `mailbox` individually (`Config.GuestDefaultPermissions` at first). A key can have an expiry (`Config.GuestDurations`). At most `Config.MaxGuests` guests per house.
- **Doors.** Hold `[ENTER]` near a door. The server checks distance (3 m), the key and the `doors` permission, then broadcasts the new state to everyone. Without a key, `Config.AllowKnock` makes the visitor knock and notifies the tenant. State lives in memory: rented houses lock on restart, vacant houses stay open.
- **Storage.** An rsg-inventory stash `house_<houseid>` sized by the tenant's tier (`Config.StorageTiers`). Upgrades cost the price difference and last for the tenancy. The stash is always emptied when a tenancy ends.
- **Belongings.** When a tenancy ends by eviction, by an admin without "delete storage", or by the tenant when `Config.PurgeStorageOnLeave = false`, the items are moved to a retrieval stash `houseret_<citizenid>_<houseid>`. The old tenant opens it with `/housebelongings` at the old house for `Config.RetrievalDays` days. `RetrievalDays = 0` deletes storage immediately.
- **Decorating.** Tenants place furniture from `Config.DecorProps` with rsg-gizmo. The client only sends a prop `key`; model and price come from the server config. Placement is checked on the server (tenant, key exists, within `Config.PropPlaceRadius` of the menu spot, gizmo validity, cash, `Config.MaxPropsPerHouse` counted inside the INSERT). Furniture is stored in `rsg_housing_props`, spawned locally for players within `Config.PropStreamDistance`, and deleted when the tenancy ends.
- **At Home.** In-memory flag that changes the house blip for everyone; cleared automatically when the tenant logs off or moves `Config.HomeAutoAwayDistance` away.
- **Governor income.** With `Config.EnableGovernor`, rent and storage upgrades are paid to the rsg-bossmenu job of the house's region (`Config.GovernorJobs`).
- **Push-to-talk.** Every open/close of a panel goes through `applyNuiFocus(enable)`. With `Config.AllowPushToTalkWhileOpen`, `SetNuiFocusKeepInput` is on and all controls on groups 0–2 are disabled except `Config.PushToTalkControls`.

## Configuration reference
Single-value options in `shared/config.lua` (defaults are generated from the file):

| Option | Default | Description |
|---|---|---|
| `Debug` | `false` | extra server console output for the rent check and admin actions |
| `AutoDatabase` | `true` | create/update the tables on start; set false to import installation/rsg-housing.sql manually |
| `MaxHousesPerPlayer` | `1` | how many houses a player can rent at once |
| `GracePeriodDays` | `3` | days after the due date before the tenant is evicted |
| `ReminderDays` | `3` | send a reminder telegram this many days before rent is due |
| `RentCheckCronJob` | `'0 * * * *'` | how often to check for due / overdue rent (every hour on the hour) |
| `MaxRent` | `1000000` | highest rent an admin can set in /houseadmin |
| `AdminPermission` | `'admin'` | rsg-core permission needed for /houseadmin |
| `InteractDistance` | `5.0` | max distance (server checked) from the house menu for renting, paying and storage |
| `MenuPromptDistance` | `1.5` | how close to the house menu spot the [J] prompt appears |
| `HouseNameMin` | `3` | shortest custom house name a tenant can set |
| `HouseNameMax` | `30` | longest custom house name (max 30, the database column size) |
| `GuestSearchMin` | `2` | characters typed before the guest search runs |
| `GuestSearchResults` | `6` | max players shown in the guest search |
| `MaxGuests` | `8` | max guests (keys) a tenant can give out per house |
| `GuestSearchScope` | `'nearby'` | who the guest search finds: 'nearby' (online players close to the tenant), 'online' (any online player) or 'all' (every character, searches the whole players table) |
| `GuestSearchDistance` | `25.0` | 'nearby' range in metres |
| `GuestDurations` | `{ 0, 24, 168 }` | key lengths a tenant can choose in hours (0 = until removed) |
| `AllowKnock` | `true` | visitors without a key knock instead of getting an error; the tenant is told if online |
| `KnockCooldown` | `20` | seconds between knocks per player |
| `LoginRentReminder` | `true` | remind tenants about rent that is due soon or overdue when they log in |
| `WardrobeResource` | `'rsg-wardrobe'` |  |
| `TelegramResource` | `'rsg-telegram'` |  |
| `MailboxMax` | `50` | telegrams shown in the house mailbox |
| `AllowPushToTalkWhileOpen` | `true` |  |
| `HomeAutoAwayDistance` | `75.0` | tenant is set to 'away' automatically past this distance from the house (0 = never) |
| `HomeCheckInterval` | `15` | seconds between automatic 'away' checks (also clears tenants who log off) |
| `OwnedHouseBlips` | `false` | when true, only your own rented house shows a blip |
| `PurgeStorageOnLeave` | `true` | true: storage is deleted when a tenant moves out. false: it is kept for Config.RetrievalDays (see below) |
| `RetrievalDays` | `3` | days an evicted / departed tenant can collect their belongings with /housebelongings at the house (0 = delete straight away) |
| `EndTenancyRefundPercent` | `0` | % of the unused rent refunded when a tenant ends the tenancy early (0 = no refund) |
| `EnableGovernor` | `false` | when true, rent and storage upgrades are paid into the region's governor boss account (rsg-bossmenu). The old name Config.EnableGovenor still works |
| `Decorating` | `true` |  |
| `MaxPropsPerHouse` | `25` |  |
| `PropPlaceRadius` | `40.0` | furniture must be within this distance of the house menu spot (server checked) |
| `PropStreamDistance` | `80.0` | furniture spawns for a player this close to the house |
| `PropRefundPercent` | `50` | % of the price refunded when a tenant removes an item |

Structured options:

**`Config.GuestDefaultPermissions`** – what a new guest can use: `{ doors = true, storage = true, wardrobe = true, mailbox = true }`.

**`Config.Blips`** – blip look per state: `vacant`, `mine`, `rented`, `home`, each `{ sprite = '...', colour = '...' }`.

**`Config.StorageTiers`** – list of `{ key, slots, weight, price }`. `weight` is in grams like rsg-inventory. Tier 1 is included with the tenancy; `key` also selects the locale `storage_tier_<key>`. rsg-inventory caps stashes at its own `Config.Stash.MaxSlots` / `MaxWeight`.

**`Config.GovernorJobs`** – `region -> rsg-bossmenu job`. The regions are the `region` values in `rsg_housing`.

**`Config.DecorProps`** – list of `{ key, label, model, price }`. `key` is stored in the database, so don't rename it once used. Models were checked against `femga/rdr3_discoveries` `objects/object_list.lua`; add your own after checking the model name.

**`Config.PushToTalkControls`** – list of control hashes left enabled while a panel has focus (default `0x4BC9DABB`).

**`Config.Houses` / `Config.HouseDoors`** – see [Installation](#installation-and-upgrading).

## Server API (exports)
All are server-side: `exports['rsg-housing']:Name(...)`. They trust the calling script (the checks a player action goes through are *not* repeated), so only call them from server code you control. House ids that don't exist return `nil` / `false` / empty.

| Export | Returns | Description |
|---|---|---|
| `GetHouse(houseid)` | house table or `nil` | One house, see below |
| `GetHouses()` | list of house tables | Every configured house (one query) |
| `IsHouseRented(houseid)` | boolean | From the in-memory cache, no query |
| `GetTenant(houseid)` | `citizenid, fullname` or `nil` | From the cache |
| `GetPlayerHouses(citizenid)` | list of house ids | Houses the character rents |
| `GetHouseAccess(citizenid, houseid)` | `'tenant'`, `'guest'` or `nil` | Active keys only (expired keys don't count) |
| `HasHouseAccess(citizenid, houseid, perm?)` | boolean | `perm` = `'doors'`, `'storage'`, `'wardrobe'`, `'mailbox'`; without `perm`, any access. Tenants have every permission |
| `GetHouseAt(coords, radius?)` | `houseid, distance` or `nil` | Closest house menu spot within `radius` (default `Config.InteractDistance`) |
| `GetHouseByDoor(doorid)` | houseid or `nil` | Door hash to house |
| `GetDoorState(doorid)` | `true` locked / `false` unlocked / `nil` unknown | |
| `SetHouseDoors(houseid, locked)` | boolean | Lock or unlock every door of a house and sync to all players |
| `GetHouseGuests(houseid)` | list | `{ citizenid, name, perms = {doors,storage,wardrobe,mailbox}, expires_text }` |
| `AddGuest(houseid, citizenid, opts?)` | `ok, reason` | `opts = { hours = 0, perms = { doors = true, ... } }`. Reasons: `invalid_house`, `not_rented`, `invalid_player`, `is_tenant`, `exists`, `limit`. `hours` is not limited to `Config.GuestDurations` here |
| `RemoveGuest(houseid, citizenid)` | boolean | |
| `SetHouseRent(houseid, rent)` | boolean | `0 .. Config.MaxRent`; applies from the next payment |
| `EvictTenant(houseid, opts?)` | boolean | `opts = { purge = false }`; sends the tenant a telegram/notification; belongings are kept for retrieval unless `purge = true` |
| `OpenHouseStorage(src, houseid)` | boolean | Opens the house stash for a player **without** a permission check |
| `GetHouseProps(houseid)` | list | `{ id, key, model, coords = {x,y,z}, rot = {x,y,z} }` |

**House table** (`GetHouse` / `GetHouses`):
```lua
{
    houseid = 'house1', name = 'House 1', customName = nil, region = 'newhanover',
    rent = 50, rented = true, citizenid = 'ABC12345', tenant = 'John Marston',
    due = '18/12/2026 14:00', overdue = false, storageTier = 1, home = false,
    coords = vector3(220.0, 984.5, 190.8)   -- house menu spot
}
```
`citizenid`, `tenant` and `due` are `nil` for vacant houses.

**Examples**
```lua
local housing = exports['rsg-housing']

-- 1. Let tenants and guests with the storage permission use your own stash at a house
RSGCore.Functions.CreateCallback('myres:server:cellar', function(source, cb, houseid)
    local Player = RSGCore.Functions.GetPlayer(source)
    cb(Player and housing:HasHouseAccess(Player.PlayerData.citizenid, houseid, 'storage') or false)
end)

-- 2. Which house is the player standing at?
local houseid, dist = housing:GetHouseAt(GetEntityCoords(GetPlayerPed(src)), 10.0)

-- 3. Tax office: list overdue tenants
for _, h in ipairs(housing:GetHouses()) do
    if h.rented and h.overdue then print(('%s owes rent on %s (due %s)'):format(h.tenant, h.name, h.due)) end
end

-- 4. Lawman raid: unlock every door of the house and open its storage
housing:SetHouseDoors(houseid, false)
housing:OpenHouseStorage(src, houseid)   -- you decide who may call this

-- 5. Quest reward: give a character a 24 hour key without storage access
local ok, reason = housing:AddGuest(houseid, citizenid, { hours = 24, perms = { storage = false } })
if not ok then print('could not add guest: ' .. reason) end

-- 6. Evict a wanted tenant and delete their belongings
housing:EvictTenant(houseid, { purge = true })

-- 7. All houses a character rents
for _, id in ipairs(housing:GetPlayerHouses(citizenid)) do print(id) end
```

## Hook events
Server-side events fired by rsg-housing. They are plain `TriggerEvent`s (not net events), so clients can't fire or spoof them. Listen with `AddEventHandler`.

| Event | Arguments | Fired when |
|---|---|---|
| `rsg-housing:server:houseRented` | `houseid, citizenid, rent` | A tenant rents a house (after the cache and doors are updated) |
| `rsg-housing:server:rentPaid` | `houseid, citizenid, rent` | A tenant pays a month |
| `rsg-housing:server:tenancyEnded` | `houseid, citizenid, reason` | Any tenancy ends. `reason` = `'left'` (tenant), `'evicted'` (unpaid rent), `'admin'` (/houseadmin), `'api'` (`EvictTenant`) |
| `rsg-housing:server:guestAdded` | `houseid, citizenid, hours` | A key is given (`hours = 0` means until removed) |
| `rsg-housing:server:guestRemoved` | `houseid, citizenid` | A guest key is removed by hand (expired keys are cleaned silently) |

```lua
AddEventHandler('rsg-housing:server:tenancyEnded', function(houseid, citizenid, reason)
    if reason == 'evicted' then
        print(('%s was evicted from %s'):format(citizenid, houseid))
        -- e.g. remove a stash your own script created for that house
    end
end)

AddEventHandler('rsg-housing:server:houseRented', function(houseid, citizenid, rent)
    -- e.g. give a welcome item with rsg-inventory
end)
```

## Client API
`exports['rsg-housing']:Name(...)` on the client.

| Export | Returns | Description |
|---|---|---|
| `IsHouseRented(houseid)` | boolean | Anyone rents it |
| `IsMyHouse(houseid)` | boolean | The local player rents it |
| `GetMyHouses()` | list of house ids | |
| `GetHouseName(houseid)` | string or `nil` | The tenant's custom name, otherwise the config name |
| `GetNearestHouse(coords?, maxDist?)` | `houseid, distance` or `nil` | Defaults: the player's position, 50.0 |
| `OpenHouseMenu(houseid)` | boolean | Opens the panel as if `[J]` was pressed (the server still checks distance on every action) |
| `IsHouseMenuOpen()` | boolean | A house or admin panel has focus |

Local client event: `rsg-housing:client:housesUpdated (myHouses)` fires whenever the set of houses changes (`myHouses = { [houseid] = true }`).

```lua
-- radial menu / command: open the panel of the nearest house
RegisterCommand('housemenu', function()
    local houseid = exports['rsg-housing']:GetNearestHouse(nil, 3.0)
    if houseid then exports['rsg-housing']:OpenHouseMenu(houseid) end
end)

-- react when the player rents or loses a house
AddEventHandler('rsg-housing:client:housesUpdated', function(myHouses)
    for houseid in pairs(myHouses) do print('I rent', houseid) end
end)
```

## Commands and permissions
| Command | Who | Description |
|---|---|---|
| `/houseadmin` | `Config.AdminPermission` (rsg-core permission, default `admin`) | Admin panel: every house, rent, due date, storage tier, doors, evict, teleport, open storage, rename reset, guests. Every admin action is re-checked on the server and logged to rsg-log (`rsghousing`) |
| `/myhouse` | everyone | GPS route to the house you rent; run again to clear |
| `/housebelongings` | former tenants | Open the belongings kept after a tenancy ended (stand within `Config.InteractDistance + 10` of the old house) |

Admin panel actions (server callback `rsg-housing:server:admin`): `list`, `house`, `setRent`, `shiftDue`, `setDue`, `setStorage`, `resetName`, `removeGuest`, `doors`, `evict`, `teleport`, `storage`.

## Internal callbacks and events
These are the plumbing between the NUI, client and server. They are not a stable API (use the exports above), but are listed for debugging and auditing. Every one validates its arguments on the server.

**Server callbacks** (all prefixed `rsg-housing:server:`):
`getState()`, `getHouseStatus(houseid)`, `rentHouse(houseid)`, `payRent(houseid)`, `setHome(houseid, on)`, `upgradeStorage(houseid, level)`, `renameHouse(houseid, name)`, `endTenancy(houseid)`, `addGuest(houseid, citizenid, hours)`, `setGuestPermission(houseid, citizenid, perm, allowed)`, `searchPlayers(houseid, query)`, `removeGuest(houseid, citizenid)`, `outfits(houseid, action, id)`, `mailbox(houseid, action, id)`, `toggleDoor(doorid)`, `getProps(houseid)`, `prePlaceProp(houseid, key)`, `placeProp(houseid, key, coords, rot)`, `moveProp(houseid, id, coords, rot)`, `removeProp(houseid, id)`, `admin(action, houseid, data)`.

**Server net events:** `rsg-housing:server:openStorage (houseid)`, `rsg-housing:server:loginCheck ()` (rate limited; sends the login rent reminder).

**Client events (server to client):** `SyncOwnedHouses (owned, mine)`, `SyncDoors (states)`, `SetDoorState (doorid, state)`, `openAdmin`, `propAdded`, `propMoved`, `propRemoved`, `propsCleared` (all `rsg-housing:client:`).

All state-changing callbacks return `{ ok, msg, type }`, which the NUI shows as a toast.

## Database
| Table | Purpose |
|---|---|
| `rsg_housing` | One row per house: `region`, `houseid` (unique), tenant `citizenid` / `fullname`, `rented`, `rent`, `rent_due`, `reminder_sent`, `custom_name`, `storage_tier` |
| `rsg_housekeys` | Keys: the tenant (`guest = 0`) and guests (`guest = 1`) with `perm_doors`, `perm_storage`, `perm_wardrobe`, `perm_mailbox`, optional `expires` |
| `rsg_housing_props` | Placed furniture: `houseid`, `model_key`, position (`x,y,z`) and rotation (`rx,ry,rz`) |
| `rsg_housing_retrieval` | Belongings waiting for an old tenant: `houseid`, `citizenid`, `expires` (unique per house and character) |

Stashes live in rsg-inventory's `inventories` table: `house_<houseid>` and `houseret_<citizenid>_<houseid>`. The mailbox reads `rsg_telegrams` (rsg-telegram); the wardrobe reads `playeroutfit` (rsg-character). `houseid` columns are `varchar(20)`.

## Security model
- **Nothing is trusted from the client.** Prices, rent, storage sizes, furniture models and prices come from the database/config. Clients send ids, never amounts.
- **Every action** checks: the player exists, the key / tenancy (and the guest permission for that feature), distance to the house menu spot or door, and a per-player cooldown. Admin actions re-check the rsg-core permission on every call.
- **Money** is removed before goods are granted and refunded if the conditional database update loses a race (renting, paying, upgrading, placing furniture).
- **Limits** are enforced in the database statement where it matters (one tenant per house; furniture count inside the INSERT) and by `Config.MaxGuests`, `Config.MaxPropsPerHouse`, `Config.MaxHousesPerPlayer`.
- **Privacy.** The guest search only returns logged-in players near the tenant by default (`Config.GuestSearchScope`); `'all'` scans every character.
- **NUI.** Every player-controlled string (house names, character names, telegram text) is HTML-escaped before it is rendered.
- **API.** Exports are server-side and trust the caller. Hook events are server-only `TriggerEvent`s, so clients can't spoof them.
- **For other scripts:** a script that lets players act on a house must check `HasHouseAccess` (and distance) itself on the server. `OpenHouseStorage` and `SetHouseDoors` do not.

## Locales
All text comes from `locales/<lang>.json` (en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru; the same keys in every file). The language follows rsg-core: `setr rsg:locale de`. To add a language copy `en.json`, translate the values, keep every `%s` / `%d` in the same order and keep `**bold**` markers and `~e~` / `~t6~` / `~q~` colour codes. NUI strings are listed in `UI_STRINGS` / `ADMIN_STRINGS` in `client/client.lua` and sent to the NUI when it opens; a new NUI string needs adding to that list too.

## NUI
`html/index.html` + `style.css` + `app.js`: the leather-and-gold house panel (rent card, guests with permission chips and key length, storage tiers, decorating list, wardrobe, mailbox) and the admin panel. The panel is draggable (position is remembered; double-click the header to reset). No native `<select>` or `<datalist>` is used. NUI callbacks are `close`, `action`, `searchPlayers`, `outfits`, `mailbox`, `admin`, `adminClose`; each is re-validated by the server callback behind it.

## Troubleshooting
| Problem | Fix |
|---|---|
| "Table doesn't exist" on start | Check oxmysql starts before rsg-housing and the database user can `CREATE` and `ALTER`; or set `Config.AutoDatabase = false` and import the SQL |
| Console: "has no row in rsg_housing" | Add `region = '...'` to the house in `Config.Houses`, or insert the row |
| Can't rent a house | The house has no row (see above), it's already rented, the player is farther than `Config.InteractDistance` from `menucoords`, or `MaxHousesPerPlayer` is reached |
| Panel blocks push-to-talk | `Config.AllowPushToTalkWhileOpen = true` and the control in `Config.PushToTalkControls` |
| Furniture doesn't appear | `rsg-gizmo` / `rsg-target` must be started; the model must exist; the player must be within `Config.PropStreamDistance` |
| Mailbox / wardrobe unavailable | rsg-telegram / rsg-wardrobe isn't started or `Config.TelegramResource` / `Config.WardrobeResource` don't match the folder names |
| `/houseadmin` does nothing | The player needs `Config.AdminPermission` in rsg-core |
| `/myhouse` shows no route | The GPS route uses `StartGpsMultiRoute`; check the client console for native errors |
| Items missing after an eviction | They were moved to the retrieval stash: the old tenant uses `/housebelongings` at the house within `Config.RetrievalDays` |

## Not included
Per-house upgrades such as a bath or stable need interior coordinates per MLO. Tenancy transfer between players needs a consent flow for the receiving player.

## rsg-economy integration

`Config.Economy = { Enabled, ReplaceGovernor }`. `payGovernor(region, amount, houseid, reason)` first calls `payTreasury`, which finds the town with `GetRegionAt(house menucoords)` and calls `DepositTreasury(region, amount, reason, 'rsg-housing')`. When that succeeds and `ReplaceGovernor` is true it stops; otherwise the existing governor payout (`Config.EnableGovernor`, `Config.GovernorJobs`) runs as before. Called for new rentals, monthly rent payments and storage upgrades. Refunds do not take money back out of the treasury. Skipped when rsg-economy is not started or the house is outside every town's region radius.


Support: https://rexshack.tebex.store

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-housing 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`, `rsg-inventory`, `rsg-target`, `rsg-gizmo`

### Database

Tables: `rsg_housing`, `rsg_housekeys`, `rsg_housing_props`, `rsg_housing_retrieval`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-housing.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Debug` | `false` |  |
| `Config.AutoDatabase` | `true` | create/update the tables on start; set false to import installation/rsg-housing.sql manually |
| `Config.MaxHousesPerPlayer` | `1` | how many houses a player can rent at once |
| `Config.GracePeriodDays` | `3` | days after the due date before the tenant is evicted |
| `Config.ReminderDays` | `3` | send a reminder telegram this many days before rent is due |
| `Config.RentCheckCronJob` | `'0 * * * *'` | how often to check for due / overdue rent (every hour on the hour) |
| `Config.MaxRent` | `1000000` | highest rent an admin can set in /houseadmin |
| `Config.AdminPermission` | `'admin'` | rsg-core permission needed for /houseadmin |
| `Config.InteractDistance` | `5.0` | max distance (server checked) from the house menu for renting, paying and storage |
| `Config.MenuPromptDistance` | `1.5` | how close to the house menu spot the [J] prompt appears |
| `Config.HouseNameMin` | `3` | shortest custom house name a tenant can set |
| `Config.HouseNameMax` | `30` | longest custom house name (max 30, the database column size) |
| `Config.GuestSearchMin` | `2` | characters typed before the guest search runs |
| `Config.GuestSearchResults` | `6` | max players shown in the guest search |
| `Config.MaxGuests` | `8` | max guests (keys) a tenant can give out per house |
| `Config.GuestSearchScope` | `'nearby'` | who the guest search finds: 'nearby' (online players close to the tenant), 'online' (any online player) or 'al |
| `Config.GuestSearchDistance` | `25.0` | 'nearby' range in metres |
| `Config.GuestDurations` | `{ 0, 24, 168 }` | key lengths a tenant can choose in hours (0 = until removed) |
| `Config.AllowKnock` | `true` | visitors without a key knock instead of getting an error; the tenant is told if online |
| `Config.KnockCooldown` | `20` | seconds between knocks per player |
| `Config.LoginRentReminder` | `true` | remind tenants about rent that is due soon or overdue when they log in |
| `Config.GuestDefaultPermissions` | `table` | what a newly added guest can use (the tenant can change each guest from the guest list) |
| `Config.WardrobeResource` | `'rsg-wardrobe'` |  |
| `Config.TelegramResource` | `'rsg-telegram'` |  |
| `Config.MailboxMax` | `50` | telegrams shown in the house mailbox |
| `Config.AllowPushToTalkWhileOpen` | `true` | While the NUI has focus, game controls are blocked but push-to-talk keeps working. |
| `Config.PushToTalkControls` | `table` |  |
| `Config.HomeAutoAwayDistance` | `75.0` | tenant is set to 'away' automatically past this distance from the house (0 = never) |
| `Config.HomeCheckInterval` | `15` | seconds between automatic 'away' checks (also clears tenants who log off) |
| `Config.Blips` | `table` | blip look per house state (sprite + colour modifier) |
| `Config.StorageTiers` | `table` |  |
| `Config.OwnedHouseBlips` | `false` | when true, only your own rented house shows a blip |
| `Config.PurgeStorageOnLeave` | `true` | true: storage is deleted when a tenant moves out. false: it is kept for Config.RetrievalDays (see below) |
| `Config.RetrievalDays` | `3` | days an evicted / departed tenant can collect their belongings with /housebelongings at the house (0 = delete  |
| `Config.EndTenancyRefundPercent` | `0` | % of the unused rent refunded when a tenant ends the tenancy early (0 = no refund) |
| `Config.EnableGovernor` | `false` | when true, rent and storage upgrades are paid into the region's governor boss account (rsg-bossmenu). The old  |
| `Config.GovernorJobs` | `table` | region (rsg_housing.region) -> rsg-bossmenu job that receives the money |
| `Config.Decorating` | `true` |  |
| `Config.MaxPropsPerHouse` | `25` |  |
| `Config.PropPlaceRadius` | `40.0` | furniture must be within this distance of the house menu spot (server checked) |
| `Config.PropStreamDistance` | `80.0` | furniture spawns for a player this close to the house |
| `Config.PropRefundPercent` | `50` | % of the price refunded when a tenant removes an item |
| `Config.DecorProps` | `table` | models checked against femga/rdr3_discoveries objects/object_list.lua |
| `Config.Houses` | `table` | house config |
| `Config.HouseDoors` | `table` | door config |
| `Config.Economy` | `table` | Rent and storage upgrade payments are deposited into the treasury of the town nearest to the house. |
| `Config.Enabled` | `true` |  |
| `Config.ReplaceGovernor` | `false` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `GetHouse` | `houseid` | `server/server.lua` |
| `GetHouses` | `` | `server/server.lua` |
| `IsHouseRented` | `houseid` | `server/server.lua` |
| `GetTenant` | `houseid` | `server/server.lua` |
| `GetPlayerHouses` | `citizenid` | `server/server.lua` |
| `GetHouseAccess` | `citizenid, houseid` | `server/server.lua` |
| `HasHouseAccess` | `citizenid, houseid, perm` | `server/server.lua` |
| `GetHouseAt` | `coords, radius` | `server/server.lua` |
| `GetHouseByDoor` | `doorid` | `server/server.lua` |
| `GetDoorState` | `doorid` | `server/server.lua` |
| `SetHouseDoors` | `houseid, locked` | `server/server.lua` |
| `GetHouseGuests` | `houseid` | `server/server.lua` |
| `AddGuest` | `houseid, citizenid, opts` | `server/server.lua` |
| `RemoveGuest` | `houseid, citizenid` | `server/server.lua` |
| `SetHouseRent` | `houseid, rent` | `server/server.lua` |
| `EvictTenant` | `houseid, opts` | `server/server.lua` |
| `OpenHouseStorage` | `src, houseid` | `server/server.lua` |
| `GetHouseProps` | `houseid` | `server/server.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `IsHouseRented` | `houseid` | `client/client.lua` |
| `IsMyHouse` | `houseid` | `client/client.lua` |
| `GetMyHouses` | `` | `client/client.lua` |
| `GetHouseName` | `houseid` | `client/client.lua` |
| `GetNearestHouse` | `coords, maxDist` | `client/client.lua` |
| `OpenHouseMenu` | `houseid` | `client/client.lua` |
| `IsHouseMenuOpen` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-housing']:GetHouse(houseid)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-housing:server:getState` | server | `source` | `server/server.lua` |
| `rsg-housing:server:getHouseStatus` | server | `source, houseid` | `server/server.lua` |
| `rsg-housing:server:rentHouse` | server | `src, houseid` | `server/server.lua` |
| `rsg-housing:server:payRent` | server | `src, houseid` | `server/server.lua` |
| `rsg-housing:server:setHome` | server | `src, houseid, on` | `server/server.lua` |
| `rsg-housing:server:upgradeStorage` | server | `src, houseid, level` | `server/server.lua` |
| `rsg-housing:server:renameHouse` | server | `src, houseid, value` | `server/server.lua` |
| `rsg-housing:server:endTenancy` | server | `src, houseid` | `server/server.lua` |
| `rsg-housing:server:addGuest` | server | `src, houseid, targetCid, hours` | `server/server.lua` |
| `rsg-housing:server:setGuestPermission` | server | `src, houseid, targetCid, perm, allowed` | `server/server.lua` |
| `rsg-housing:server:searchPlayers` | server | `src, houseid, query` | `server/server.lua` |
| `rsg-housing:server:removeGuest` | server | `src, houseid, targetCid` | `server/server.lua` |
| `rsg-housing:server:outfits` | server | `src, houseid, action, id` | `server/server.lua` |
| `rsg-housing:server:mailbox` | server | `src, houseid, action, id` | `server/server.lua` |
| `rsg-housing:server:toggleDoor` | server | `source, doorid` | `server/server.lua` |
| `rsg-housing:server:getProps` | server | `src, houseid` | `server/server.lua` |
| `rsg-housing:server:prePlaceProp` | server | `src, houseid, key` | `server/server.lua` |
| `rsg-housing:server:placeProp` | server | `src, houseid, key, coords, rot` | `server/server.lua` |
| `rsg-housing:server:moveProp` | server | `src, houseid, id, coords, rot` | `server/server.lua` |
| `rsg-housing:server:removeProp` | server | `src, houseid, id` | `server/server.lua` |
| `rsg-housing:server:admin` | server | `src, action, houseid, data` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-housing:server:getState', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `rsg-housing:client:SyncOwnedHouses` | client | `owned, mine` | `client/client.lua` |
| `rsg-housing:client:SyncDoors` | client | `doors` | `client/client.lua` |
| `rsg-housing:client:SetDoorState` | client | `doorid, state` | `client/client.lua` |
| `rsg-housing:client:openAdmin` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-housing:client:propAdded` | client | `houseid, prop` | `client/props.lua` |
| `rsg-housing:client:propMoved` | client | `houseid, id, coords, rot` | `client/props.lua` |
| `rsg-housing:client:propRemoved` | client | `houseid, id` | `client/props.lua` |
| `rsg-housing:client:propsCleared` | client | `houseid` | `client/props.lua` |
| `rsg-housing:client:placeProp` | client | `houseid, key` | `client/props.lua` |
| `rsg-housing:server:openStorage` | server | `houseid` | `server/server.lua` |
| `rsg-housing:server:loginCheck` | server | `` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-housing:server:openStorage', houseid)
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerLoaded', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/myhouse` |  | `client/client.lua` |
| `/housebelongings` | locale('retrieval_help') | `server/server.lua` |
| `/houseadmin` | locale('admin_command_help') | `server/server.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
