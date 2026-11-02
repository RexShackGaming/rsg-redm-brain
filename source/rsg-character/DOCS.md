# rsg-character — Server Owner & Developer Docs

This document explains how rsg-character works under the hood, so you can configure it confidently, troubleshoot problems and build other resources on top of it. For a quick install guide see [README.md](README.md).

**Version:** 3.1.1 · **Framework:** RSG-Core · **Lua:** 5.4

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
12. [Common tasks](#12-common-tasks)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Resource layout

```
rsg-character/
├── fxmanifest.lua
├── shared/
│   ├── config.lua        -- all settings (RSG table)
│   └── functions.lua     -- birthdate check, clothing validation, price calculation (shared)
├── client/
│   ├── charselect.lua    -- in-world character select (ped lineup, camera, slot actions)
│   ├── creator.lua       -- character creator, ApplySkin, /loadskin, most exports
│   ├── clothes.lua       -- clothing store, clothing layer order, wardrobe/outfits
│   ├── functions.lua     -- shared client helpers (camera, prompts, components)
│   ├── spawn.lua         -- spawn select screen, ApplySkin event, spawn checks
│   ├── ui.lua            -- NUI bridge (loading screen, menus)
│   └── hashtocache.lua   -- builds hash lookup caches (loaded as a file)
├── server/
│   ├── sv_charselect.lua -- slots, select, delete, request create
│   ├── sv_appearance.lua -- routing buckets, creator sessions, SaveSkin, createCharacter, appearance callbacks
│   ├── sv_clothing.lua   -- buy outfit, wear/delete outfit, outfit callbacks, DB migration
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

### Automatic migration
On `MySQL.ready` the script:
1. Adds `is_default` to `playeroutfit` if missing.
2. Creates a Default outfit for every character that has clothes but no Default yet, and prints how many it created.

This runs on every start and is safe to repeat. The two tables themselves are **not** created automatically — use the SQL in the README if they don't exist.

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
| Routing buckets | The script only resets a bucket **it** assigned, so it can't be used to escape jail or other instances. |

---

## 5. Clothing store & wardrobe

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
- The spawn screen shows for **new characters** and for characters whose saved position is invalid.
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

### Client exports
| Export | Description |
|---|---|
| `ApplySkin()` | Reloads the local player's saved skin and clothes from the server. |
| `ApplySkinMultiChar(skinData, ped, clothesData)` | Applies a skin + clothes table to any ped (used for the select lineup). |
| `SetFaceOverlays(ped, data)` | Applies overlay data (scars, makeup, etc.). |
| `SetHair(ped, data)` | Applies hair. |
| `SetBeard(ped, data)` | Applies beard. |
| `GetComponentId(name)` | Current creator component id by name. |
| `GetBodyComponents()` | Body component table. |
| `GetBodyCurrentComponentHash(name)` | Current body component hash. |
| `GetComponentsMax(name)` | Max option count for a component. |
| `GetMaxTexturesForModel(category, model, isClothing)` | Texture count for a model. |
| `GetClothesCache(name)` | Current clothing cache entry (or whole cache). |
| `GetClothesComponentId(name)` | Current clothing component id. |
| `GetClothesCurrentComponentHash(name)` | Current clothing hash. |
| `IsCothingActive()` | `true` while the player is in the clothing store. (Spelling kept for compatibility.) |

Example — stop your script's UI opening while the player is in a store:
```lua
if exports['rsg-character']:IsCothingActive() then return end
```

Example — reapply appearance after your script changes the ped model (e.g. after a jail or animal transform):
```lua
exports['rsg-character']:ApplySkin()
```

### Client events you can trigger
| Event | Description |
|---|---|
| `rsg-character:client:ApplySkin` (`skin`, `clothes`) | Applies given skin and clothes to the player. |
| `rsg-character:client:outfits` | Opens the outfits/wardrobe menu (server still checks location unless wardrobe props are enabled). |
| `rsg-character:client:OpenCharSelect` | Opens character select. Only works for logged-out players (use after `RSGCore.Player.Logout`). |
| `rsg-character:client:OpenSpawnSelect` (`lastPos`, `isNew`) | Opens spawn select, or teleports to `lastPos` if given. |
| `rsg-character:client:OpenCreator` | Opens the creator UI. Saves are only accepted when the server opened the session, so trigger the flow from the server instead. |

### Server
| Name | Type | Description |
|---|---|---|
| `rsg-character:server:getAppearance` | callback | `{ skin, clothes }` for the caller's character, or `nil`. |
| `rsg-multicharacter:server:getAppearance` | callback | Same, returns `{ skin = {}, clothes = {} }` when none. Legacy name for older resources. |
| `rsg-character:server:getOutfits` | callback | Saved outfits: `{ id, name, clothes, is_default }[]`, Default first. |
| `rsg-character:server:LoadClothes` | callback | Current clothes table. |
| `rsg-character:server:wearOutfit` (`id`) | callback | Applies outfit and returns its clothes, or `nil`. |
| `RSG.OpenCreatorFor(src, nil)` | function (this resource) | Opens an appearance-only creator for a logged-in player (e.g. a barber/surgeon feature added inside this resource). |

```lua
-- client, from another resource
local appearance = RSGCore.Functions.AwaitCallback('rsg-character:server:getAppearance')
if appearance then
    print(appearance.skin.sex == 1 and 'male' or 'female')
end
```

### Sending a player back to character select (server, another resource)
```lua
local Player = RSGCore.Functions.GetPlayer(src)
Player.Functions.Save()
RSGCore.Player.Logout(src)
TriggerClientEvent('rsg-character:client:OpenCharSelect', src)
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

## 13. Troubleshooting

| Problem | Likely cause / fix |
|---|---|
| Black screen or stuck on character select | Another multicharacter/appearance resource is running, or `rsg-character` starts before `rsg-core`/`oxmysql`. Check F8 and server console. |
| "Table doesn't exist" errors | `playerskins` / `playeroutfit` missing — run the SQL in the README. |
| Players naked or wrong body after login | Old/legacy skin row. Ask them to use `/loadskin`; if still wrong, delete their `playerskins` row so the creator opens on next select. |
| Clothing clips | Category missing from `CLOTHING_ORDER` or in the wrong layer. |
| Webhook warning in console | Category enabled but URL still the placeholder. Add a URL or set `enabled = false`. |
| Can't create a character: "missing info" | Name doesn't match the rules (capital first, letters only, 2–20) or birth date out of range. |
| Kicked when selecting a character | The citizenid doesn't belong to that license (exploit protection) — often caused by license changes (e.g. Steam vs Rockstar). |
| Wardrobe prop does nothing | rsg-target not started, or `WardrobeTarget.enabled = false`. |
| Spawn card image blank | Image path wrong or missing from `html/img/spawn/`. |
| Spawn at character select scene | Add/adjust `RSG.SpawnChecks`. |

Enable `RSG.Debug = true` for extra client console output.

---

Support development: https://buymeacoffee.com/rexshack
