# rsg-telephone — Developer & Server-Owner Documentation

Reference for **rsg-telephone 3.1.0** on RSG-Core (RedM). For installation, features and the config table, see [README.md](README.md).

## Contents

1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Exports](#exports)
4. [Events and callbacks](#events-and-callbacks)
5. [NUI callbacks](#nui-callbacks)
6. [Integration examples](#integration-examples)
7. [Persistence and saving](#persistence-and-saving)
8. [Security model](#security-model)
9. [Database schema](#database-schema)
10. [Server-owner how-tos](#server-owner-how-tos)
11. [Troubleshooting](#troubleshooting)
12. [Support](#support)

---

## Architecture

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Resource metadata, dependencies, script order, NUI page and locale files. Version `3.1.0`. |
| `shared/config.lua` | All tunable options. Runs after `@rsg-core/shared/locale.lua`, so model labels can use `locale()`. Ends with guards that clamp invalid values. |
| `client/client.lua` | Prop streaming, interior room assignment, rsg-target options, NUI phone screen, bell/audio positioning, Mumble voice line, placement through rsg-gizmo, admin panel NUI. |
| `server/server.lua` | Authoritative phone registry, database load/save, payphone money, call lifecycle and watchdog, job checks, ownership, admin callbacks, commands. |
| `server/versionchecker.lua` | Optional GitHub version check. Prints the result to the server console. No gameplay effect. |
| `html/index.html` | NUI markup: dialler, directory, payphone coin slot, placement form, confirm dialog and admin panel. |
| `html/style.css` | Leather-and-gold RDR2 styling for all NUI screens. |
| `html/script.js` | NUI logic, synthetic audio (bell, ringback, dial clicks), message bridge. No network access. |
| `locales/*.json` | Flat JSON locale tables loaded by rsg-core. 106 keys in every file. |
| `installation/install.sql` | Manual table creation for owners who disable `Config.AutoDatabase`. |
| `installation/shared_items.lua` | The `telephone` item entry for `rsg-core/shared/items.lua`. Not a standalone Lua file. |

Runtime flow:

1. On start the server creates/upgrades `rsg_telephones`, loads every row into either `Phones` (placed) or `Stored` (picked up), then broadcasts the placed list.
2. Each client keeps a copy of the placed list, streams props within `Config.SpawnDistance`, and attaches rsg-target options to each entity.
3. All call, money, ownership, job and admin decisions are made on the server. The client copy is only for display and interaction prompts.
4. Every registry mutation is written to MySQL before the in-memory state changes and before clients are notified.

---

## Data formats

### Item definition

```lua
telephone = {
    name = 'telephone', label = 'Telephone', weight = 1000, type = 'item',
    image = 'telephone.png', unique = true, useable = true, shouldClose = true,
    description = 'A telephone you can install anywhere', category = 'tools',
}
```

### Item metadata

A placed-then-picked-up phone stores its identity on the inventory item:

```lua
{
    phone_id = 12,        -- rsg_telephones.id (number)
    number   = '4821',    -- reserved phone number
    label    = 'My Phone',
}
```

`unique = true` keeps this metadata on an individual item. When the item is used again, the server verifies the item is still in the same slot and still carries the same `phone_id`.

### Public phone object (client copy)

Sent by `syncPhones`, `addPhone` and `updatePhone`:

```lua
{
    id      = 12,
    number  = '4821',
    label   = 'My Phone',
    model   = 's_phonewall01x',
    x = 123.4, y = -567.8, z = 20.1,
    heading = 90.0,
    room    = 0,             -- interior room key; 0 = derive from the player when possible
    job     = 'medic' or nil,
    owner   = 'citizenid' or nil,
    listed  = true,
}
```

The client caches `p.pos = vector3(x, y, z)` for the streaming and bell loops.

### Server call object

`Calls[callId]`:

```lua
{
    id        = 1,
    caller    = 3,           -- server source at dial time
    answerer  = 7 or nil,
    fromPhone = 12,          -- rsg_telephones.id
    toPhone   = 18,
    state     = 'ringing' or 'active',
    started   = 1730000000,  -- os.time(), reset when answered
    deposit   = 50,          -- cents inserted (nil for free calls)
    spent     = 10,          -- cents charged so far
    payer     = 'citizenid', -- who gets the refund (nil for free calls)
    paidUntil = 1730000060,  -- os.time() of the next minute charge
}
```

### Other server tables

| Table | Shape | Meaning |
|---|---|---|
| `Phones` | `[id] = phone` | Placed phones, authoritative copy. `phone.coords` is a `vector3`. |
| `Stored` | `[id] = phone` | Picked-up phones. Keeps the number reserved and the row in the DB (`stored = 1`). |
| `PhoneCall` | `[phoneId] = callId` | Marks a phone as ringing/in use. |
| `PlayerCall` | `[src] = callId` | Marks a player as ringing/in a call. |
| `Cooldown` | `[src] = os.time()` | Last dial attempt. |
| `PendingPlace` | `[src] = { slot, storedId, t }` | Item placement issued by `CreateUseableItem`; expires after 300 seconds. |

### Config structures

```lua
Config.Models = {
    { value = 's_phonewall01x',    label = locale('model_wall') },
    { value = 'p_phoneantique01x', label = locale('model_desk') },
}
```

Only models listed here are accepted by the server for new phones. Model changes for existing phones are applied by the admin panel.

---

## Exports

This resource **does not expose any exports of its own**. External resources should use the events and callbacks below, or query the database.

Exports consumed by rsg-telephone:

| Resource | Export | Called from | Returns |
|---|---|---|---|
| `rsg-gizmo` | `Place(model, opts)` | client | `{ coords = vector3, rotation = vector3, heading = number }` or `nil` |
| `rsg-gizmo` | `IsPlacementValid(src, coords, maxDistance)` | server | `boolean` |
| `rsg-gizmo` | `SanitiseRotation(rot)` | server | safe `vector3` |
| `rsg-inventory` | `CanAddItem(src, name, amount)` | server | `boolean` |
| `rsg-inventory` | `AddItem(src, name, amount, info, slot, reason)` | server | `boolean` |
| `rsg-inventory` | `RemoveItem(src, name, amount, slot, reason)` | server | `boolean` |
| `rsg-inventory` | `GetItemBySlot(src, slot)` | server | item table or `nil` |
| `rsg-target` | `addLocalEntity(entity, options)` | client | attaches interaction options to a local entity |
| `rsg-target` | `removeLocalEntity(entity)` | client | removes those options |

rsg-core APIs used: `GetCoreObject`, `Functions.Notify`, `Functions.GetPlayer`, `Functions.GetPlayerByCitizenId`, `Functions.GetPlayerJobs`, `Functions.GetJobDefinition`, `Functions.HasPermission`, `Functions.CreateCallback`, `Functions.CreateUseableItem`, `Functions.AwaitCallback`, `Functions.TriggerCallback`, `Commands.Add`.

---

## Events and callbacks

### Server → client events

These are triggered by the server. They are **not** a security boundary; the server never trusts a client reply.

| Event | Arguments | Purpose |
|---|---|---|
| `rsg-telephone:client:syncPhones` | `list` (array of public phone objects) | Replace the client's phone list. |
| `rsg-telephone:client:addPhone` | `phone` | Add or replace one phone. |
| `rsg-telephone:client:updatePhone` | `phone` | Update a phone; the client respawns the prop if the model changed. |
| `rsg-telephone:client:removePhone` | `id` | Remove a phone and its blip. |
| `rsg-telephone:client:setRinging` | `phoneId, state` | Broadcast bell on/off. `state = false` stops the bell for everyone. |
| `rsg-telephone:client:startVoice` | `partnerServerId` | Open the private Mumble line to that player. |
| `rsg-telephone:client:credit` | `leftCents, costCents` | Update the payphone credit display. |
| `rsg-telephone:client:callConnected` | `{ label, number }` | Tell the caller the remote phone answered. |
| `rsg-telephone:client:callEnded` | `reasonText` | Stop voice and show the end reason. |
| `rsg-telephone:client:openAdmin` | none | Open the Telephone Exchange (permission is re-checked by every callback). |
| `rsg-telephone:client:startPlacement` | `opts` | Open the placement form. `opts.item = true` and `opts.preset = { label, model, number }` for a picked-up phone. |

### Client → server events

| Event | Purpose |
|---|---|
| `rsg-telephone:server:hangUp` | End the sender's current call. No arguments. |
| `rsg-telephone:server:cancelPlace` | Clear the sender's pending item placement. No arguments. |

### rsg-core callbacks

All callbacks are registered on the server and reached with `TriggerCallback` / `AwaitCallback`. The first return value is success; the second is a payload or a locale error message.

| Callback | Arguments | Returns |
|---|---|---|
| `rsg-telephone:server:getPhones` | none | `phoneList, ringingIds` (two values) |
| `rsg-telephone:server:myJobs` | none | array of job names/types held by the character |
| `rsg-telephone:server:getDirectory` | none | `{ entries = { { id, label, number, listed } }, admin = boolean }` |
| `rsg-telephone:server:setListed` | `id, listed` | `true, entries` on success; `false, error` |
| `rsg-telephone:server:createPhone` | `data` | `true, number` on success; `false, error` |
| `rsg-telephone:server:pickupPhone` | `id` | `true` on success; `false, error` |
| `rsg-telephone:server:ownerUpdate` | `id, data` | `true` on success; `false, error` |
| `rsg-telephone:server:adminList` | none | `{ phones, calls, models }`; `false` without permission |
| `rsg-telephone:server:adminUpdate` | `id, data` | `true, adminList`; `false, error` |
| `rsg-telephone:server:adminDelete` | `id` | `true, adminList`; `false, error` |
| `rsg-telephone:server:adminEndCall` | `phoneId` | `true, adminList`; `false` |
| `rsg-telephone:server:startCall` | `phoneId, number, deposit` | `true, { label, number }`; `false, error` |
| `rsg-telephone:server:answer` | `phoneId` | `true, { label, number }`; `false, error` |

`createPhone` data:

```lua
{
    item = false,                 -- true = use the caller's pending item placement
    label = 'Bank Phone',
    model = 's_phonewall01x',     -- must be in Config.Models
    number = '1234',              -- optional; blank = generate
    listed = true,
    job = 'medic',                -- optional; ''/nil = anyone
    x = 123.4, y = -567.8, z = 20.1,
    heading = 90.0,
    rotation = vector3,           -- optional; sanitised server-side
    room = 0,
}
```

`adminUpdate` data:

```lua
{ label = 'Bank Phone', number = '1234', model = 's_phonewall01x', job = 'medic', listed = true }
```

`startCall` deposit is in **dollars** as a number; the server converts to whole cents and rejects non-finite values.

---

## NUI callbacks

These are internal to `html/script.js` and handled in `client/client.lua`. They are not intended for other resources.

| Callback | Payload | Purpose |
|---|---|---|
| `close` | none | Close the phone and hang up if in a call. |
| `hangUp` | none | End the current call. |
| `getDirectory` | none | Fetch the directory. |
| `setListed` | `{ id, listed }` | Admin directory show/hide. |
| `dial` | `{ number, deposit }` | Place a call from the current phone. |
| `placeForm` | form payload or `{ cancel = true }` | Resolve the placement/settings form. |
| `confirmResult` | `{ ok = boolean }` | Resolve the generic confirm dialog. |
| `adminClose` | none | Close the admin panel. |
| `adminRefresh` | none | Re-fetch the admin list. |
| `adminSave` | `{ id, label, number, model, job, listed }` | Save an edited phone. |
| `adminDelete` | `{ id }` | Delete a phone. |
| `adminEndCall` | `{ id }` | End the call on a phone. |
| `adminTeleport` | `{ id }` | Teleport to a placed phone. |
| `adminWaypoint` | `{ id }` | Set a GPS route to a placed phone. |
| `adminAdd` | none | Close the panel and open admin placement. |

---

## Integration examples

### Open the exchange panel from another admin menu

```lua
-- server
TriggerClientEvent('rsg-telephone:client:openAdmin', src)
```

Every admin callback re-checks `Config.AdminPermission`; opening the panel does not grant permission.

### Read the number stored on a picked-up phone item

```lua
-- server
local item = exports['rsg-inventory']:GetItemBySlot(src, slot)
local phoneId = item and item.info and tonumber(item.info.phone_id)
local number  = item and item.info and item.info.number
```

### Restrict the nearest phone to a job from another resource

Use the admin command or update the row directly, then restart the resource so the in-memory registry reloads:

```sql
UPDATE rsg_telephones SET job = 'medic' WHERE number = '1234';
```

The supported in-game path is `/phonejob medic`, which updates memory and clients immediately.

### Hand a phone to another player

Picked-up phones live on a unique inventory item. Give or trade the item normally; whoever places it becomes the new owner.

### Query phones and owners

```sql
SELECT id, number, label, owner, stored, job
FROM rsg_telephones
ORDER BY id;
```

---

## Persistence and saving

- **Startup:** `CREATE TABLE IF NOT EXISTS` (when `Config.AutoDatabase = true`), then `information_schema` checks add missing `room`, `job`, `owner`, `stored`, `created_by` and `created_at` columns on older tables. All rows are loaded and validated; rows with missing/non-finite coordinates are skipped and logged.
- **Authoritative state:** the server's `Phones` and `Stored` tables. The client copy is rebuilt from `syncPhones` and incremental events.
- **Write timing:** every mutation writes to MySQL before memory changes and before clients are notified:
  - create phone → `INSERT`
  - place picked-up phone → `UPDATE` coordinates/owner and `stored = 0`
  - pick up phone → `UPDATE stored = 1`, then inventory add; if the add fails the row and memory are restored
  - owner settings → `UPDATE label, listed`
  - admin edit → `UPDATE label, number, model, job, listed`
  - admin delete / `/removephone` → `DELETE`
  - directory show/hide → `UPDATE listed`
  - `/phonejob` → `UPDATE job`
- **Call state is not persisted.** A restart ends every call; payphone refunds are issued by `endCall` during `onResourceStop`.
- **Stored phones stay in the table** so their numbers cannot be reused. Deleting a stored phone from the admin panel frees the number; an existing item with that `phone_id` then places as a new phone.
- **Uniqueness:** the `number` column has a unique index and the server also checks placed + stored phones before inserting.

---

## Security model

The server never trusts client-supplied coordinates, numbers, money, labels, models or ownership. The following checks are applied:

| Area | Checks |
|---|---|
| Placement | `rsg-gizmo:IsPlacementValid(src, coords, Config.PlaceDistance)`; rotation passed through `SanitiseRotation`; model must be in `Config.Models`; labels trimmed and capped at 64 characters; numbers are digits only, 2–16 long, checked against placed and stored phones. |
| Admin actions | Every admin callback calls `HasPermission(src, Config.AdminPermission)` again; admin commands pass the permission to `RSGCore.Commands.Add`. Client-side visibility is never treated as permission. |
| Item placement | `CreateUseableItem` records the source, slot and stored phone ID; `pendingItem` verifies the same item is still in that slot within 300 seconds; the item is removed before the DB insert and refunded if the DB write fails. |
| Ownership | `pickupPhone` and `ownerUpdate` require the caller's `citizenid` to match the phone owner, and the player to be near the phone. |
| Job restriction | The server recomputes every job name and job type the character holds (`GetPlayerJobs` + `GetJobDefinition`); the client cache only hides the interaction. |
| Calling | Phone must exist, caller must be near it, the phone must not be busy, the target must exist and not be busy, the caller must not already be in a call, a cooldown must have elapsed, and job restrictions are re-checked. |
| Payphone money | Deposit is converted to whole cents with a finite-number check, clamped between one minute's cost and `MaxDeposit`, checked against the player's balance, and removed server-side before the call starts. Refunds are calculated from server-side `deposit`/`spent` only. |
| Call watchdog | Distance from both phones, maximum call length and payphone credit are enforced every 2 seconds on the server. |
| NUI | The page only displays data and posts intents. It cannot modify money, items, calls or the registry directly. |

Calling scripts must still protect their own systems. rsg-telephone does not authenticate external callers of its events/callbacks beyond the checks listed above, and the client events are only UI notifications.

---

## Database schema

Table `rsg_telephones`:

| Column | Type | Notes |
|---|---|---|
| `id` | `INT NOT NULL AUTO_INCREMENT` | Primary key, used as the phone ID. |
| `number` | `VARCHAR(16) NOT NULL` | Unique. Digits only, 2–16 characters. |
| `label` | `VARCHAR(64) NOT NULL DEFAULT 'Telephone'` | Display name; also the blip name. |
| `model` | `VARCHAR(64) NOT NULL` | Prop model from `Config.Models`. |
| `x`, `y`, `z` | `DOUBLE NOT NULL` | World coordinates. |
| `heading` | `DOUBLE NOT NULL DEFAULT 0` | Z rotation in degrees. |
| `listed` | `TINYINT(1) NOT NULL DEFAULT 1` | `1` = visible in the directory. |
| `room` | `BIGINT NOT NULL DEFAULT 0` | Interior room key; `0` = derive from the player where possible. |
| `job` | `VARCHAR(64) DEFAULT NULL` | Job name/type restriction; `NULL` = anyone. |
| `owner` | `VARCHAR(64) DEFAULT NULL` | Owner citizenid for player phones; `NULL` = admin/public phone. |
| `stored` | `TINYINT(1) NOT NULL DEFAULT 0` | `1` = picked up (number reserved, prop not spawned). |
| `created_by` | `VARCHAR(64) DEFAULT NULL` | Citizenid that created the row (admin or player). |
| `created_at` | `TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP` | Creation time. |

Indexes: `PRIMARY KEY (id)`, `UNIQUE KEY number (number)`.

Manual install: set `Config.AutoDatabase = false` and import `installation/install.sql`.

---

## Server-owner how-tos

### Add another prop model

1. Confirm the model exists in RedM/rdr3 and can be created as an object.
2. Add it to `Config.Models` in `shared/config.lua`:
   ```lua
   { value = 'your_model_name', label = 'Your Label' },
   ```
3. Restart the resource. The model appears in the admin/player prop picker.

### Change the payphone price or currency

Edit `Config.Payphone.CostPerMinute` and `Config.Payphone.MoneyType` (`cash`, `bank`, `gold`, `bloodmoney`). If `CostPerMinute` is greater than `MaxDeposit`, the guard raises `MaxDeposit` to one minute's cost so calls stay possible.

### Make every phone free

```lua
Config.Payphone.Enabled = false
```

Job phones are always free. Player-owned phones are free unless `Config.Item.Payphone = true`.

### Disable player-owned phones

```lua
Config.Item.Enabled = false
```

The item can stay in the inventory; it simply does nothing.

### Disable map blips

```lua
Config.Blip.Enabled = false
```

### Move a phone or change its prop

Use `/phoneadmin` → select the phone → edit the prop and save. Changing the model respawns the prop for every player. To move a phone without the panel, update `x`, `y`, `z` and `heading` in the database and restart the resource.

### Free a stored phone's number

Open `/phoneadmin`, select the **Picked up** phone and delete it. The number becomes available; any existing item with that `phone_id` will place as a brand-new phone.

### Reset all phones

```sql
TRUNCATE TABLE rsg_telephones;
```

Then restart the resource. This also invalidates the metadata on picked-up items.

### Back up or move the registry

```sql
-- backup
SELECT * FROM rsg_telephones;

-- restore (after creating the table)
INSERT INTO rsg_telephones
(number, label, model, x, y, z, heading, listed, room, job, owner, stored, created_by)
VALUES ('1234', 'Bank Phone', 's_phonewall01x', 1.0, 2.0, 3.0, 90.0, 1, 0, NULL, NULL, 0, NULL);
```

### Add a locale

Copy `locales/en.json` to `locales/<code>.json`, translate the values, keep every key and `%s` placeholder, then set `setr rsg:locale "<code>"`.

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| No phones appear | `Config.AutoDatabase` failed and the table is missing, or rows have invalid coordinates (check the server console). Confirm the player is within `Config.SpawnDistance`. |
| Props do not render inside a building | The phone was placed before room support or with `room = 0` and no player in the interior. Re-place it with rsg-gizmo while inside, or set `room` in the DB. |
| Cannot target a phone | `rsg-target` must be started. Increase `Config.UseDistance` if needed. |
| No voice on calls | `Config.Voice.Target` conflicts with another voice script; choose a free slot. If using pma-voice, set `Config.Voice.DefaultTarget = 1`. Check push-to-talk still works while the phone UI is open. |
| Phone does not ring | The destination must exist, be placed (`stored = 0`) and not already in a call. Ringing is only heard within `Config.RingDistance`. |
| Call ends when walking away | Increase `Config.MaxCallDistance`. The server checks distance every 2 seconds. |
| "Insert at least $X" but the player has money | The player needs the configured `Config.Payphone.MoneyType` (default `cash`), not just bank money. |
| "That number is already in use" | The number belongs to a placed **or picked-up** phone. Delete the stored phone in `/phoneadmin` to free it. |
| Placement fails immediately | `rsg-gizmo` must be started. Check `Config.PlaceDistance` and whether the surface/water/interior rules allow the spot. |
| Player placement says the item is missing | The item must still be in the slot it was used from, and the placement must complete within 5 minutes. |
| Admin panel is empty or commands do nothing | The player lacks `Config.AdminPermission`. Permissions are checked on the server. |
| UI shows the wrong language | Set `setr rsg:locale "xx"` in `server.cfg` and restart; the locale is loaded through `@rsg-core/shared/locale.lua`. |
| Version checker prints an HTTP error | It needs internet access to GitHub. This does not affect gameplay; remove `server/versionchecker.lua` from the manifest if unwanted. |

---

Support: https://buymeacoffee.com/rexshack
