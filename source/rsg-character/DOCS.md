# rsg-character — Server Owner & Developer Docs

This document explains how rsg-character works under the hood, so you can configure it confidently, troubleshoot problems and build other resources on top of it. For a quick install guide see [README.md](README.md).

**Version:** 3.3.0 · **Framework:** RSG-Core · **Lua:** 5.4

---

## Contents
1. [Resource layout](#1-resource-layout)
2. [Player flow](#2-player-flow)
3. [Database](#3-database)
4. [Security model](#4-security-model)
5. [Clothing store & wardrobe](#5-clothing-store--wardrobe)
6. [Clothing order](#clothing-order)
7. [Spawning](#7-spawning)
8. [Logout](#8-logout)
9. [Webhooks](#9-webhooks)
10. [Locales](#10-locales)
11. [Developer API](#11-developer-api)
12. [Common tasks](#12-common-tasks) (incl. admin commands, slots and names)
13. [Troubleshooting](#13-troubleshooting)
14. [Configuration reference](#14-configuration-reference)
15. [Changelog](#15-changelog)

---

## 1. Resource layout

```
rsg-character/
├── fxmanifest.lua
├── install.sql           -- manual table install (same schema as sv_database.lua)
├── shared/
│   ├── config.lua        -- all settings (RSG table)
│   └── functions.lua     -- birthdate check, clothing validation, price calculation (shared)
├── client/
│   ├── charselect.lua    -- in-world character select (ped lineup, camera, slot actions)
│   ├── creator.lua       -- character creator, ApplySkin, /loadskin, most exports
│   ├── clothes.lua       -- clothing store, clothing layer order, wardrobe/outfits
│   ├── functions.lua     -- shared client helpers (camera, prompts, components)
│   ├── spawn.lua         -- spawn select screen, ApplySkin event, spawn checks
│   ├── ui.lua            -- NUI bridge (loading screen, menus), NUI focus + push-to-talk whitelist
│   └── hashtocache.lua   -- builds hash lookup caches (loaded as a file)
├── server/
│   ├── sv_charselect.lua -- slots, select, delete, request create
│   ├── sv_appearance.lua -- routing buckets, creator sessions, SaveSkin, createCharacter, appearance callbacks
│   ├── sv_admin.lua      -- /charinfo, /resetskin, /changename
│   ├── sv_clothing.lua   -- buy outfit, wear/delete outfit, outfit callbacks, DB migration
│   ├── sv_database.lua   -- builds playerskins / playeroutfit tables (RSG.AutoDatabase)
│   ├── sv_logout.lua     -- /logout command
│   ├── webhook.lua       -- Discord webhook queue
│   └── versionchecker.lua
├── data/                 -- features, overlays, hair and clothing hash lists
├── html/                 -- NUI (index.html, css, js, spawn images)
├── img/                  -- menu icons and skin tone swatches
└── locales/              -- en, de, el, es, fr, ja, nl, pl, pt-br, ro
```

Data files in `data/` are large hash tables loaded on demand with rsg-core's `require` (`@rsg-core/shared/require.lua`).

---

## 2. Player flow

```
Connect
  └─► client asks server for slots ──► server puts player in a private routing bucket
        └─► Character Select (ped lineup)
              ├─ Play existing ─► server verifies license owns citizenid ─► RSGCore.Player.Login
              │     ├─ has skin ─► ApplySkin ─► reset bucket ─► spawn at last position
              │     │                                        (or spawn select if no valid position)
              │     └─ no skin  ─► Creator opened by server (appearance only)
              ├─ Create (empty slot) ─► server checks slot free ─► Creator session opened
              │     └─ identity form ─► createCharacter (validated) ─► Login + starter items
              │           └─ SaveSkin ─► skin + protected Default outfit saved ─► Spawn Select
              └─ Delete ─► ownership check ─► character, skin and outfits removed
```

Key points:
- **Character select only works for logged-out players.** All charselect server events return early if the source already has a Player object.
- **The creator is server-driven.** The client can't open a saving creator session itself; only `RSG.OpenCreatorFor(src, data)` on the server creates one.
- **New characters always see spawn select.** Returning characters with a valid saved position (not 0,0,0) spawn straight there.
- A new character is given a full heal on first spawn.

---

## 3. Database

The script uses two tables alongside rsg-core's `players` table.

### `playerskins`
| Column | Type | Notes |
|---|---|---|
| `id` | INT, PK | |
| `citizenid` | VARCHAR(255) | Indexed |
| `skin` | LONGTEXT | JSON: body, face features, overlays, hair, `sex` (`1` male, `2` female) |
| `clothes` | LONGTEXT | JSON: clothing per category (`{ hats = { model = n, texture = n }, ... }`) |

One row per character. If more than one row exists, the newest (`ORDER BY id DESC`) is used.

### `playeroutfit`
| Column | Type | Notes |
|---|---|---|
| `id` | INT, PK | Outfit id used by wear/delete |
| `citizenid` | VARCHAR(255) | Indexed |
| `name` | VARCHAR(255) | Player-entered (trimmed to 40 chars) or auto-generated |
| `clothes` | LONGTEXT | Same JSON format as `playerskins.clothes` |
| `is_default` | TINYINT(1) | `1` = the protected Default outfit |

### Automatic setup and migration
On `MySQL.ready` the script:
0. When `RSG.AutoDatabase = true`, runs the `CREATE TABLE IF NOT EXISTS` statements from `server/sv_database.lua` (printing a green "database tables ready" or a red error). Set it to `false` and import `install.sql` to install manually.
1. Adds `is_default` to `playeroutfit` if missing.
2. Creates a Default outfit for every character that has clothes but no Default yet, and prints how many it created.

This runs on every start and is safe to repeat.

### What deleting a character removes
`RSGCore.Player.DeleteCharacter` (players row and rsg-core data) plus that citizenid's rows in `playerskins` and `playeroutfit`.

---

## 4. Security model

rsg-character assumes the client can't be trusted. Server-side protections:

| Area | Protection |
|---|---|
| Character select | Only for logged-out players. Selecting a citizenid the license doesn't own **drops the player** (exploit attempt). |
| Slot creation | `cid` must be a whole number between 1 and `MaxCharacterSlots`, and free for that license. |
| Creator | Server-owned `CreatorSessions[src]`. `SaveSkin` and `createCharacter` are ignored without a session; a new character can only be created once per session and must match the session's `cid`. |
| Identity | First/last name: 2–20 chars, pattern `^%u%l+$` (e.g. `Arthur`), not in `ProfanityWords`. Nationality must match a configured nationality in any locale. Birth date must be inside `RSG.Birthdate`. |
| Gender | Taken from the character record, never from the client. |
| Skin data | Max 150 keys, string keys ≤ 32 chars, number values (or tables of numbers). Encoded JSON capped at 32 KB. |
| Clothing | `ValidateClothesData` checks every item against the real clothing list for the character's gender. Price is recalculated on the server (`CalculatePrice`) from what changed. |
| Store location | Buying and entering the fitting-room bucket require being within 10 m of a store. |
| Wardrobe | Wearing an outfit requires being near a cloakroom, unless `WardrobeTarget.enabled` (props can't be checked server-side; outfits are already paid for). Outfits are re-validated before being applied. |
| Cooldowns | Buy 2 s, wear/delete 1 s, delete character 3 s, `/logout` configurable. |
| Routing buckets | The script only resets a bucket **it** assigned, and restores the bucket the player was in before (never blindly bucket 0), so it can't be used to escape jail or other instances. |
| Double requests | Selecting a character is ignored while a login is running; `/logout` is ignored while a logout is running. Rejected or failed requests send `CharSelectFailed` so the client never hangs on the loading screen. |
| Character slots | Slots are `RSG.MaxCharacterSlots` plus the best matching `RSG.SlotRules` ACE rule, resolved on the server for every slot list and create request. |
| Unique names | `RSG.NameExists` is checked by the `isNameAvailable` callback (creator session only) and again in `createCharacter`. |
| Outfit sharing | Server checks ownership, same body type, distance (re-checked after the prompt), per-player cooldown, one pending offer per receiver and the 30-outfit limit. The receiver must accept (client callback with timeout); the copy is re-validated with `ValidateClothesData`. |
| Admin commands | Registered with rsg-core's permission level (`RSG.AdminCommands.Permission`); every action can be logged to the `admin_action` webhook. |
| Outfit names | HTML/control characters are stripped, max 40 chars; the client also escapes names before showing them. |

---

## 5. Clothing store & wardrobe

> **Outfit sharing:** in the wardrobe, pick an outfit and choose *Share Outfit*. The nearest player (within `RSG.OutfitSharing.MaxDistance`) gets a confirm dialog; if they accept, a copy is added to their wardrobe. Only same body type, and only if they have room.

### Store flow
1. Player stands at `promtcoords` and presses `RSG.OpenKey`.
2. Server moves them into a private routing bucket and they're placed at `fittingcoords`.
3. Menus are built from `RSG.MenuElements`; each category label comes from `RSG.Label`.
4. On confirm, the client checks cash, asks for an outfit name and sends `rsg-character:server:saveOutfit`.
5. The server validates, charges `cash`, updates `playerskins.clothes` and inserts a new `playeroutfit` row (max **30** non-default outfits; past that the purchase still applies but isn't saved as an outfit and the player is told).
6. Player is placed at `quitcoords` and returned to bucket 0.

### Pricing
`RSG.Price[category]` is charged for each category that differs from what the player is currently wearing. Unchanged categories are free. Setting a category to `0` makes it free.

### Wardrobe
- **Cloakrooms:** `RSG.Cloakroom` locations with blips and a prompt.
- **Props:** with `RSG.WardrobeTarget.enabled = true`, every model in `models` gets an rsg-target option that opens the outfits menu. Add any prop model you like (e.g. MLO furniture).
- The Default outfit is listed first and can't be deleted (enforced in SQL: `AND is_default = 0`).

### Store doors
`RSG.SetDoorState` sets each store door's state on start (`0` open, `1` locked). If you use rsg-doorlock for these doors, remove them here to avoid fighting over the state.

---

## Clothing order

Clothing is applied in a fixed order defined by `CLOTHING_ORDER` at the top of `client/clothes.lua`:

1. Base body parts (upper/lower) for any area not covered by clothing.
2. Categories in `CLOTHING_ORDER` order (inner → middle → outer → equipment/accessories).
3. Any category not listed, alphabetically.

Use the helper anywhere in client code to walk a clothes table in the same order:
```lua
for category, data in OrderedClothes(clothes) do
    -- applied in layer order
end
```
If a new clothing category clips, add it to `CLOTHING_ORDER` in the right layer.

---

## 7. Spawning

- `RSG.SpawnLocations` builds the spawn cards. Card `image` paths are relative to `html/`.
- The spawn screen shows for **new characters** and for characters whose saved position is invalid. With `RSG.SpawnMenuWithLastLocation = true` it also shows for returning characters, with a **Last Location** card first.
- `RSG.SpawnChecks` is a safety net on `RSGCore:Client:OnPlayerLoaded`: anyone loading within `Radius` of a `badSpawn` point (by default the character select lineup) is moved to `moveTo`. Add more groups if players end up somewhere they shouldn't:

```lua
RSG.SpawnChecks = {
    ["Character Creation"] = {
        badSpawn = { vector3(4234.78, -717.32, 50.12) },
        moveTo   = { vector3(-169.47, 629.38, 113.03) },
        Radius   = 200,
    },
}
```

If you move `RSG.CharSelectLocation`, update `badSpawn` to match.

---

## 8. Logout

`/logout` (name set by `RSG.Logout.Command`) is registered through `RSGCore.Commands.Add`:
1. Blocked during a creator session, during the cooldown, and (if `BlockWhenDead`) when `metadata.isdead` or `metadata.inlaststand` is set.
2. Client fades out (`rsg-character:client:BeginLogout`).
3. `Player.Functions.Save()` then `RSGCore.Player.Logout(src)`.
4. `character_logout` webhook is sent and character select opens.

Set `RSG.Logout.Enabled = false` to remove the command.

---

## 9. Webhooks

`RSG.SendWebhook(category, embed)` (server) posts a Discord embed if `RSG.Webhooks[category].enabled` and a real URL is set. Requests are queued one at a time and respect Discord's `429 Retry-After`, so a busy server won't get rate-limited.

| Category | Fired when |
|---|---|
| `character_created` | New character created (name, citizenid, gender, nationality, birth date) |
| `character_deleted` | Character deleted |
| `character_selected` | Character selected at character select |
| `character_logout` | `/logout` used |
| `appearance_saved` | Creator saved |
| `outfit_purchased` | Clothing bought (price, outfit name) |

Every embed also includes the player's identity fields (name and identifiers). Other server files in this resource can call `RSG.SendWebhook` with their own categories after adding them to `RSG.Webhooks`.

---

## 10. Locales

- All text is in `locales/<lang>.json`, loaded by rsg-core's locale loader.
- Pick the server language with `setr rsg:locale <lang>` (`ox:locale` still works as a fallback).
- Supported: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. When adding a key, add it to **every** file.
- Nationality validation accepts the nationality name from any locale file, so a player whose client language differs from the server can still create a character.

---

## 11. Developer API

Everything other resources may rely on is listed here. Anything not listed (the net events in 11.7, `RSG.*` helpers, global functions) is internal and may change.

### 11.1 Client exports

| Export | Returns | Description |
|---|---|---|
| `ApplySkin()` | - | Reloads the local player's saved skin and clothes from the server. Blocks until done. |
| `ApplySkinMultiChar(skinData, ped, clothesData)` | - | Applies a skin + clothes table to any ped (used for the select lineup). |
| `SetFaceOverlays(ped, data)` | - | Applies overlay data (scars, makeup, etc.). |
| `SetHair(ped, data)` / `SetBeard(ped, data)` | - | Applies hair / beard. |
| `GetComponentId(name)` | number | Current creator component id by name. |
| `GetBodyComponents()` | table | Body component table. |
| `GetBodyCurrentComponentHash(name)` | number | Current body component hash. |
| `GetComponentsMax(name)` | number | Max option count for a component. |
| `GetMaxTexturesForModel(category, model, isClothing)` | number | Texture count for a model. |
| `GetClothesCache(name)` | table | Current clothing cache (whole cache). |
| `GetClothesComponentId(name)` | table/nil | Current clothing cache entry for a category. |
| `GetClothesCurrentComponentHash(name)` | number | Current clothing hash (`0` when nothing is worn). |
| `IsCothingActive()` | boolean | `true` while the player is in the clothing store. (Spelling kept for compatibility.) |
| `IsInCreator()` | boolean | `true` while the character creator is open (new character or appearance-only). |
| `IsInCharacterSelect()` | boolean | `true` while the character select lineup is on screen. |
| `OpenWardrobe()` | boolean | Opens the saved-outfits menu. Returns `false` (and does nothing) in the clothing store or character select. |

```lua
-- do not open your own UI while the player is in a store, creator or character select
local function playerIsBusy()
    return exports['rsg-character']:IsCothingActive()
        or exports['rsg-character']:IsInCreator()
        or exports['rsg-character']:IsInCharacterSelect()
end
```

```lua
-- reapply appearance after your script changed the ped model (jail, transformation...)
exports['rsg-character']:ApplySkin()
```

```lua
-- add a "Wardrobe" entry to your own menu or command
RegisterCommand('wardrobe', function()
    exports['rsg-character']:OpenWardrobe()
end, false)
```

### 11.2 Client events

**You can trigger**

| Event | Description |
|---|---|
| `rsg-character:client:ApplySkin` (`skin`, `clothes`) | Applies the given skin and clothes to the local player. |
| `rsg-character:client:ApplyClothes` (`clothes`, `ped?`) | Applies a clothes table (`{ [category] = { hash = n } }`) to `ped` (default: the local player). Prefer the server export `SetClothes`, which validates first. |
| `rsg-character:client:outfits` | Opens the wardrobe menu (same as `OpenWardrobe`). |
| `rsg-character:client:OpenCharSelect` | Opens character select. Only works for logged-out players (see 11.8). |
| `rsg-character:client:OpenSpawnSelect` (`lastPos`, `isNew`) | Opens spawn select, or teleports to `lastPos` if given (unless `RSG.SpawnMenuWithLastLocation`). |
| `rsg-character:client:OpenCreator` | Opens the creator UI. Saves are only accepted when the server opened the session, so start the flow from the server instead. |

**You can listen to**

| Event | Fired when |
|---|---|
| `rsg-character:client:skinApplied` | The local player's skin and clothes finished applying (after login, `/loadskin`, `ApplySkin()`). |
| `RSGCore:Client:OnPlayerLoaded` | Standard rsg-core event; fired after the spawn select completes. |

```lua
AddEventHandler('rsg-character:client:skinApplied', function()
    -- re-attach props, re-apply a mask, refresh your HUD...
end)
```

### 11.3 Player state (`LocalPlayer.state`, local only)

| Key | Meaning |
|---|---|
| `inCharacterSelect` | `true` while the lineup is shown. |
| `inClothingStore` | `true` while the player is in a fitting room. |
| `isLoadingSkin` | `true` while a skin reload swaps the ped (other resources such as rsg-medic ignore the temporary death state). |

### 11.4 Server exports

Called from another server script: `exports['rsg-character']:Name(...)`.

| Export | Returns | Description |
|---|---|---|
| `GetMaxSlots(src)` | number | Slots this player may use: `RSG.MaxCharacterSlots` plus the best matching `RSG.SlotRules` entry. |
| `IsInCreator(src)` | boolean | `true` while the player has a server-opened creator session. |
| `IsNameAvailable(first, last)` | boolean | `true` when no character uses that name (always `true` if `RSG.UniqueNames = false`). |
| `GetAppearance(citizenid)` | `{ skin, clothes }` or `nil` | Saved appearance of any character, online or offline. |
| `GetOutfits(citizenid)` | `{ id, name, clothes, is_default }[]` | Saved outfits, Default first. |
| `SetClothes(src, clothes, save?)` | `ok, reason` | Validates and wears `clothes` on an online player. `save = true` also stores them as the current clothes (free). Reasons: `no_player`, `invalid_clothes`, `too_large`. |
| `AddOutfit(citizenid, name, clothes)` | `id` or `nil, reason` | Adds a wardrobe outfit (online or offline character). Reasons: `no_character`, `invalid_clothes`, `limit_reached` (30 non-default outfits). |
| `ResetAppearance(citizenid)` | boolean | Deletes the saved skin and Default outfit; the creator opens on the next login. |
| `ChangeCharacterName(citizenid, first, last)` | `ok, reason` | Renames a character (online or offline) with the creator's name rules and uniqueness check. Reasons: `invalid_name`, `name_taken`, `not_found`. |
| `LogoutToCharacterSelect(src)` | boolean | Saves, logs out and opens character select; ignores the `/logout` cooldown and dead check. Returns `false` if the player isn't logged in. |

`clothes` is `{ [category] = { hash = <number> } }` using the hashes from `data/clothing.lua` / `data/hairs_list.lua`; every hash is validated against the character's body type.

### 11.5 Server hook events

These are **local server events** (not net events, clients cannot trigger them). Listen with `AddEventHandler`:

| Event | Arguments | Fired when |
|---|---|---|
| `rsg-character:server:characterSelected` | `src, citizenid` | A character was selected and logged in. |
| `rsg-character:server:characterCreated` | `src, citizenid, cid` | A new character was created (appearance is saved afterwards). |
| `rsg-character:server:characterDeleted` | `src, citizenid` | A character was deleted from character select. |
| `rsg-character:server:characterLoggedOut` | `src, citizenid` | `/logout` or `LogoutToCharacterSelect` finished. |
| `rsg-character:server:appearanceSaved` | `src, citizenid, isNew` | The creator saved a skin. |
| `rsg-character:server:appearanceReset` | `citizenid` | `ResetAppearance` / `/resetskin` ran. |
| `rsg-character:server:nameChanged` | `citizenid, first, last` | `ChangeCharacterName` / `/changename` ran. |
| `rsg-character:server:outfitPurchased` | `src, citizenid, price, outfitName` | A clothing purchase completed. |
| `rsg-character:server:outfitShared` | `src, targetSrc, outfitId` | An outfit share was accepted and copied. |

```lua
-- give a welcome item and a bank account to every new character
AddEventHandler('rsg-character:server:characterCreated', function(src, citizenid, cid)
    exports['rsg-inventory']:AddItem(src, 'bread', 1, nil, nil, 'new-character')
end)
```

### 11.6 Callbacks (rsg-core)

| Name | Side | Returns |
|---|---|---|
| `rsg-character:server:getAppearance` | server | `{ skin, clothes }` for the caller, or `nil`. |
| `rsg-multicharacter:server:getAppearance` | server | Same, `{ skin = {}, clothes = {} }` when none. Legacy name for older resources. |
| `rsg-character:server:getOutfits` | server | The caller's saved outfits (see `GetOutfits`). |
| `rsg-character:server:LoadClothes` | server | The caller's current clothes table. |
| `rsg-character:server:wearOutfit` (`id`) | server | Clothes of that outfit (re-validated), or `nil`. Needs a cloakroom nearby unless `WardrobeTarget.enabled`. |
| `rsg-character:server:isNameAvailable` (`first`, `last`) | server | boolean. Only answers during a new-character creator session. |
| `rsg-character:client:confirmShare` (`fromName`, `outfitName`) | client | boolean; asked of the receiver of an outfit share. |

```lua
-- client of another resource
local appearance = RSGCore.Functions.AwaitCallback('rsg-character:server:getAppearance')
if appearance then print(appearance.skin.sex == 1 and 'male' or 'female') end
```

### 11.7 Net events handled by this resource (internal, do not call)

Listed for auditing and anti-cheat rules. Every one validates `source`, arguments and state on the server.

| Event | Validation |
|---|---|
| `rsg-character:server:RequestCharacterSlots` | Logged-out players only. |
| `rsg-character:server:SelectCharacterSlot` (`citizenid`) | Logged-out, license must own the citizenid (else the player is dropped), one login at a time. |
| `rsg-character:server:DeleteCharacterSlot` (`citizenid`) | Logged-out, ownership, 3 s cooldown. |
| `rsg-character:server:RequestCreateCharacterSlot` (`cid`, `sex`) | Logged-out, `cid` within `GetMaxSlots`, slot free. |
| `rsg-multicharacter:server:createCharacter` (`data`) | Needs a server-opened creator session; name, nationality, birth date, uniqueness and `cid` re-validated. Event name kept for compatibility. |
| `rsg-character:server:SaveSkin` (`skin`, `clothes`) | Needs a creator session; schema, size and clothing hashes validated; gender taken from the character record. |
| `rsg-character:server:SetPlayerBucket` | Must be logged in and within 10 m of a store; only undoes buckets this resource set. |
| `rsg-character:server:saveOutfit` (`clothes`, `_`, `name`) | Near a store, 2 s cooldown, clothes validated, price computed server-side. |
| `rsg-character:server:DeleteOutfit` (`id`) | Own, non-default outfits only. |
| `rsg-character:server:ShareOutfit` (`id`, `targetSrc`) | Ownership, distance, same body type, cooldown, receiver must accept. |

Internal client events (NUI bridge and scene control, not part of the API): `rsg-character:client:ReceiveCharacterSlots`, `CharSelectFailed`, `BeginLogout`, `CharInfoPlay`, `CharInfoDelete`, `CharInfoGenderChange`, `CameraMoveStart`, `CameraMoveStop`, `CameraReset`.

### 11.8 Examples

```lua
-- send a player back to character select (e.g. from your own admin menu)
exports['rsg-character']:LogoutToCharacterSelect(targetSrc)
```

```lua
-- jail uniform: wear it, but don't overwrite what they own
local ok, reason = exports['rsg-character']:SetClothes(src, {
    shirts_full = { hash = 123456789 }, -- use a real hash from data/clothing.lua
}, false)
if not ok then print('uniform failed: ' .. reason) end
```

```lua
-- registry office: paid name change
RSGCore.Functions.CreateCallback('myres:server:rename', function(src, cb, first, last)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Player.Functions.RemoveMoney('cash', 25, 'rename') then return cb(false, 'no_money') end
    local ok, reason = exports['rsg-character']:ChangeCharacterName(Player.PlayerData.citizenid, first, last)
    if not ok then Player.Functions.AddMoney('cash', 25, 'rename-refund') end
    cb(ok, reason)
end)
```

```lua
-- read a character's saved look from another resource (works offline too)
local look = exports['rsg-character']:GetAppearance(citizenid)
if look then print(('sex=%s'):format(look.skin.sex)) end
```

```lua
-- hand out a themed outfit to a character's wardrobe
local id, reason = exports['rsg-character']:AddOutfit(citizenid, 'Sunday Best', clothesTable)
```

---

## 12. Common tasks

**Change slot count** — set `RSG.MaxCharacterSlots`. Characters in slots above the new limit stay in the DB but won't show.

**Move the character select scene** — change `RSG.CharSelectLocation.coords` (and the heading). Tune `spacing` and `camera.height` / `fov`; `camera.back` is a minimum, the script pushes the camera back to fit all slots. Update `RSG.SpawnChecks` `badSpawn` too.

**Change starting gear** — edit `RSG.StarterItems`. Items must exist in `RSGCore.Shared.Items`.

**Make clothing free** — set every `RSG.Price` value to `0`.

**Hide a clothing category from stores** — remove it from its `RSG.MenuElements` section (players can still wear it if it's already in an outfit).

**Add a nationality** — add a key to `RSG.Nationalities` and a `nationalities.<key>` entry to every locale file.

**Add wardrobe props** — add model names to `RSG.WardrobeTarget.models`.

**Turn off a store blip** — `showblip = false` on that `RSG.Zones1` entry.

---

## 12b. Admin commands, extra slots and unique names

- `/charinfo [id]`, `/resetskin [id]`, `/changename [id] [first] [last]` (names and permission in `RSG.AdminCommands`). `/resetskin` deletes `playerskins` rows and the Default outfit; the player must `/logout` (or reconnect) so the creator opens.
- Extra slots: `RSG.SlotRules = { { slots = 6, ace = 'rsgchar.slots6' } }` and `add_ace group.vip rsgchar.slots6 allow`. Characters stored in a slot above the player's current allowance are hidden, not deleted.
- `RSG.UniqueNames` compares first + last name against `players.charinfo` (case-insensitive with the default collation).

## 13. Troubleshooting

| Problem | Likely cause / fix |
|---|---|
| Black screen or stuck on character select | Another multicharacter/appearance resource is running, or `rsg-character` starts before `rsg-core`/`oxmysql`. Check F8 and server console. |
| "Table doesn't exist" errors | `RSG.AutoDatabase` is `false` or the database user can't create tables — import `install.sql` manually. |
| Can't talk while a menu is open | Check `RSG.AllowPushToTalkWhileOpen = true` and that your push-to-talk control hash is in `RSG.PushToTalkControls`. |
| Players naked or wrong body after login | Old/legacy skin row. Ask them to use `/loadskin`; if still wrong, delete their `playerskins` row so the creator opens on next select. |
| Clothing clips | Category missing from `CLOTHING_ORDER` or in the wrong layer. |
| Webhook warning in console | Category enabled but URL still the placeholder. Add a URL or set `enabled = false`. |
| Can't create a character: "missing info" | Name doesn't match the rules (capital first, letters only, 2–20) or birth date out of range. |
| Kicked when selecting a character | The citizenid doesn't belong to that license (exploit protection) — often caused by license changes (e.g. Steam vs Rockstar). |
| Creator says the name is taken | Another character already uses that first + last name. Set `RSG.UniqueNames = false` to allow duplicates. |
| Extra slots not showing | The ACE isn't granted to the player (`add_ace ... rsgchar.slotsN allow`), or `RSG.SlotRules` has a different ACE name. |
| Wardrobe prop does nothing | rsg-target not started, or `WardrobeTarget.enabled = false`. |
| Spawn card image blank | Image path wrong or missing from `html/img/spawn/`. |
| Spawn at character select scene | Add/adjust `RSG.SpawnChecks`. |
| No rain after selecting a character | Fixed: the select scene sets the rain level to 0.0 (`_SET_RAIN` 0x193DFC0526830FD6); `EndScene` now resets it to -1.0 so weather controls rain again. |

Enable `RSG.Debug = true` for extra client console output.

---

Support development: https://buymeacoffee.com/rexshack

---

## 14. Configuration reference

All options live in `shared/config.lua` (`RSG` table). Texts come from `locales/*.json`.

| Option | Default | Description |
|---|---|---|
| `Debug` | `false` | Extra client console output. |
| `AutoDatabase` | `true` | Create `playerskins` / `playeroutfit` on start; `false` = import `install.sql` manually. |
| `AllowPushToTalkWhileOpen` | `true` | Block game controls while a NUI is open, except `PushToTalkControls`. |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | Control hashes that stay enabled while the NUI has focus. |
| `ProfanityWords` | table | Lowercase words rejected as first/last name. |
| `MaxCharacterSlots` | `4` | Base slots per license. |
| `SlotRules` | `{}` | `{ slots = n, ace = 'name' }` entries; highest allowed wins. |
| `UniqueNames` | `true` | One character per first + last name. |
| `SpawnMenuWithLastLocation` | `false` | Show the spawn menu (with Last Location) for returning characters. |
| `AdminCommands` | table | `Enabled`, `Permission`, `CharInfo`, `ResetSkin`, `ChangeName`. |
| `OutfitSharing` | table | `Enabled`, `MaxDistance` (m), `Cooldown` (s), `AcceptTimeout` (s). |
| `Birthdate` | table | `Min`, `Max`, `Default` (`YYYY-MM-DD`). |
| `Logout` | table | `Enabled`, `Command`, `Cooldown` (s), `BlockWhenDead`. |
| `Nationalities` | list | Locale keys under `nationalities`. |
| `StarterItems` | list | `{ item, amount }` given once to a new character. |
| `CharSelectLocation` | table | `coords` (vector4), `spacing`, `camera = { back, height, fov }`. |
| `Webhooks` | table | Per category (`character_created`, `character_deleted`, `character_selected`, `character_logout`, `admin_action`, `appearance_saved`, `outfit_purchased`): `enabled`, `url`, `name`, `avatar`, `color`. |
| `SpawnLocations` | list | `label`, `coords` (vector4), `image` (path under `html/`). |
| `SpawnChecks` | table | `badSpawn` points, `moveTo`, `Radius`. |
| `Prompt` | table | Control hashes used by the creator (gender, confirm, camera, rotate, zoom). |
| `OpenKey` / `Keybind` | hash / string | Key that opens the clothing store / cloakroom. |
| `BlipSprite`, `BlipSpriteCloakRoom`, `BlipScale` | numbers | Map blip settings. |
| `SetDoorState` | list | Store door hashes and state (`0` open, `1` locked). |
| `Zones1` | list | Stores: `location`, `blipcoords`, `fittingcoords`, `quitcoords`, `promtcoords`, `epromtcoords?`, `showblip`. |
| `Cloakroom` | list of vector3 | Cloakroom locations. |
| `WardrobeTarget` | table | rsg-target wardrobe props: `enabled`, `distance`, `icon`, `label`, `models`. |
| `MenuElements` | table | Which clothing categories appear in each store menu section. |
| `Price` | table | Cash price per clothing category. |
| `Texts`, `Label` | tables | Locale-driven UI strings (edit `locales/*.json`, not these). |

---

## 15. Changelog

See [CHANGELOG.md](CHANGELOG.md).

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-character 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`

### Database

Tables: `playerskins`, `playeroutfit`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `GetMaxSlots` | `src` | `server/sv_api.lua` |
| `IsInCreator` | `src` | `server/sv_api.lua` |
| `IsNameAvailable` | `firstname, lastname` | `server/sv_api.lua` |
| `GetAppearance` | `citizenid` | `server/sv_api.lua` |
| `ResetAppearance` | `citizenid` | `server/sv_api.lua` |
| `ChangeCharacterName` | `citizenid, firstname, lastname` | `server/sv_api.lua` |
| `LogoutToCharacterSelect` | `src` | `server/sv_api.lua` |
| `SetClothes` | `src, clothes, save` | `server/sv_clothing.lua` |
| `AddOutfit` | `citizenid, name, clothes` | `server/sv_clothing.lua` |
| `GetOutfits` | `citizenid` | `server/sv_clothing.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `IsInCharacterSelect` | `` | `client/charselect.lua` |
| `IsCothingActive` | `` | `client/clothes.lua` |
| `GetClothesCache` | `name` | `client/clothes.lua` |
| `GetClothesComponentId` | `name` | `client/clothes.lua` |
| `GetClothesCurrentComponentHash` | `name` | `client/clothes.lua` |
| `OpenWardrobe` | `` | `client/clothes.lua` |
| `ApplySkinMultiChar` | `` | `client/creator.lua` |
| `GetComponentId` | `name` | `client/creator.lua` |
| `GetBodyComponents` | `` | `client/creator.lua` |
| `GetBodyCurrentComponentHash` | `name` | `client/creator.lua` |
| `SetFaceOverlays` | `target, data` | `client/creator.lua` |
| `SetHair` | `target, data` | `client/creator.lua` |
| `SetBeard` | `target, data` | `client/creator.lua` |
| `GetComponentsMax` | `name` | `client/creator.lua` |
| `GetMaxTexturesForModel` | `category, model, isClothing` | `client/creator.lua` |
| `ApplySkin` | `` | `client/creator.lua` |
| `IsInCreator` | `` | `client/creator.lua` |

```lua
-- example
local result = exports['rsg-character']:GetMaxSlots(src)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-character:client:confirmShare` | client | `cb, fromName, outfitName` | `client/clothes.lua` |
| `rsg-character:server:getAppearance` | server | `src, cb` | `server/sv_appearance.lua` |
| `rsg-multicharacter:server:getAppearance` | server | `src, cb` | `server/sv_appearance.lua` |
| `rsg-character:server:isNameAvailable` | server | `src, cb, firstname, lastname` | `server/sv_appearance.lua` |
| `rsg-character:server:wearOutfit` | server | `src, cb, id` | `server/sv_clothing.lua` |
| `rsg-character:server:LoadClothes` | server | `src, cb` | `server/sv_clothing.lua` |
| `rsg-character:server:getOutfits` | server | `src, cb` | `server/sv_clothing.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-character:client:confirmShare', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-character:client:ReceiveCharacterSlots` | client | `slots` | `client/charselect.lua` |
| `rsg-character:client:CharSelectFailed` | client | `` | `client/charselect.lua` |
| `rsg-character:client:OpenCharSelect` | client | `` | `client/charselect.lua` |
| `rsg-character:client:BeginLogout` | client | `` | `client/charselect.lua` |
| `rsg-character:client:ApplyClothes` | client | `` | `client/clothes.lua` |
| `rsg-character:client:outfits` | client | `` | `client/clothes.lua` |
| `rsg-character:client:OpenCreator` | client | `data, empty` | `client/creator.lua` |
| `rsg-character:client:ApplySkin` | client | `skin, clothes` | `client/spawn.lua` |
| `rsg-character:client:OpenSpawnSelect` | client | `lastPos, isNewCharacter` | `client/spawn.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/spawn.lua` |
| `rsg-character:server:SetPlayerBucket` | server | `_, random` | `server/sv_appearance.lua` |
| `rsg-character:server:SaveSkin` | server | `skin, clothes` | `server/sv_appearance.lua` |
| `rsg-multicharacter:server:createCharacter` | server | `newData` | `server/sv_appearance.lua` |
| `rsg-character:server:RequestCharacterSlots` | server | `` | `server/sv_charselect.lua` |
| `rsg-character:server:SelectCharacterSlot` | server | `citizenid` | `server/sv_charselect.lua` |
| `rsg-character:server:DeleteCharacterSlot` | server | `citizenid` | `server/sv_charselect.lua` |
| `rsg-character:server:RequestCreateCharacterSlot` | server | `cid, selectedSex` | `server/sv_charselect.lua` |
| `rsg-character:server:saveOutfit` | server | `newClothes, _, outfitName` | `server/sv_clothing.lua` |
| `rsg-character:server:DeleteOutfit` | server | `id` | `server/sv_clothing.lua` |
| `rsg-character:server:ShareOutfit` | server | `outfitId, targetSrc` | `server/sv_clothing.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-character:server:SetPlayerBucket', _, random)
-- from a server script
TriggerClientEvent('rsg-character:client:ReceiveCharacterSlots', source, slots)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/loadskin` |  | `client/creator.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
