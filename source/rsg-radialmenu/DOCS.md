# rsg-radialmenu – Developer Docs

## Contents
1. [Dependencies](#dependencies)
2. [File overview](#file-overview)
3. [Menu entries](#menu-entries-configlua)
4. [Exports](#exports)
5. [Events](#events)
6. [Walk styles](#walk-styles)
7. [Security model](#security-model)
8. [Language](#language)
9. [Troubleshooting](#troubleshooting)
10. [Changelog](#changelog)

## Dependencies
- `rsg-core` only (no ox_lib). Locales via `@rsg-core/shared/locale.lua`, notifications via `RSGCore.Functions.Notify`.
- Default entries call other resources and are simply ignored if those are missing: `rsg-stables`, `rsg-telegram`, `rsg-lawman`, `rsg-medic` (`/medic` field menu), `rsg-wardrobe` (clothing commands), `loadskin` / `info` / `myjobs` / `searchplayer` commands.
- No database tables.

## File overview
| File | Purpose |
|---|---|
| `config.lua` | Settings, walk styles, default menu tree, job menus |
| `client/main.lua` | Open/close, menu tree building, NUI callbacks, emergency alerts, exports |
| `client/walkstyles.lua` | Applies synced walk styles to every nearby player |
| `server/server.lua` | Validates + stores walk styles (state bag + character metadata) |
| `server/versionchecker.lua` | Console version check |
| `html/` | NUI (SVG radial menu, Font Awesome icons) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## Menu entries (config.lua)
- `cmd(id, label, icon, command)` – runs a command (`ExecuteCommand`)
- `cl(id, label, icon, event)` – triggers a client event
- `walk(key, label)` – applies a walk style (validated server-side, synced via the `walkstyle` player state bag)
- A table with `items = { ... }` is a submenu. Default Clothing menu: Dress, Undress, Hat, Vest, Boots, Pants, Gun Belt, Mask, **Shirt** (on/off, `/sleeve`, `/collar1`, `/collar2`) and **Coats** (Coat, Closed Coat).
- Keep a menu level to roughly 10 entries or fewer; labels get cramped on busy rings, so group extras into submenus.

| Field | Description |
|---|---|
| `id` | Unique id (used to match NUI selections) |
| `title` | Label, use `locale('key')` |
| `icon` | Font Awesome 6 name or full class |
| `type` | `client`, `server`, `command`, `rsgcommand` |
| `event` | Event / command name |
| `shouldClose` | `false` keeps the menu open after selecting |
| `items` | Makes the entry a submenu |
| `canOpen` | Function evaluated every time the menu opens; empty submenus are hidden |
| `action` | Function run instead of `type`/`event` |

## Exports
Client side:
- `exports['rsg-radialmenu']:AddOption(data, id)` → returns the id. Passing an existing id replaces that option and keeps its slot; new options are appended in the order they were added.
- `exports['rsg-radialmenu']:RemoveOption(id)`

## Events
| Event | Side | Description |
|---|---|---|
| `rsg-radialmenu:client:onRadialmenuOpen` | client | Fired when the menu opens |
| `rsg-radialmenu:client:onRadialmenuClose` | client | Fired when the menu closes (also when it closes itself) |
| `rsg-radialmenu:client:setWalkstyle` | client | `TriggerEvent(..., 'angry')` or `{ walkstyle = 'angry' }`; client cooldown mirrors the server |
| `rsg-radialmenu:client:reapplyWalkstyle` | client | Re-apply own walk style (call after skin reloads / wardrobe changes) |
| `rsg-radialmenu:client:noPlayers` | client | "No one nearby" notification |
| `rsg-radialmenu:client:SendLawmanEmergencyAlert` / `SendMedicEmergencyAlert` | client | Emergency button (job check + `Config.EmergencyCooldown`) |
| `rsg-radialmenu:server:setWalkstyle` | server | Validated against `Config.Walkstyles` + `Config.WalkstyleCooldown` |

## Walk styles
Stored in the player state bag `walkstyle` (replicated) and character metadata `walkstyle`. The key is restored on character load and for everyone online on resource restart. A character without a saved style clears the state bag, so styles never carry over between characters.

## Security model
- The NUI only sends `{ id, event }`; the client looks that pair up in its own menu tree and ignores anything else, so a modified UI cannot run arbitrary events.
- `type = 'server'` entries send only plain data (no functions) – **the target server event must validate everything itself** (job, distance, cooldown); this resource cannot protect it.
- Walk styles: server rejects unknown keys and enforces a cooldown per player.
- The emergency alert cooldown is client-side. The receiving events (`rsg-lawman:server:lawmanAlert`, `rsg-medic:server:medicAlert`) must check the caller's job and rate limit, and should build the message server-side instead of trusting the text sent by the client.
- Menu cannot be opened (and selections are ignored) while dead, handcuffed or in the pause menu.

## Language
`setr rsg:locale "<code>"` (falls back to `ox:locale`, then `en`). Supported: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru. Menu labels are read when `config.lua` loads, so restart the resource after changing language.

## Troubleshooting
| Problem | Fix |
|---|---|
| Menu never opens, red console error on start | `Config.Keybind` is not a key in `RSGCore.Shared.Keybinds` |
| Menu stays open after releasing the key | Hold mode matches the key name from `Config.Keybind` (e.g. `F6`, `Q`); use a key listed in `KEY_ALIASES` in `html/js/main.js` or add yours |
| Icons missing | Font Awesome loads from cdnjs; host it locally (see README) |
| A command entry does nothing | The command's resource (e.g. rsg-wardrobe) is not started |
| Walk style resets after clothing/skin change | Trigger `rsg-radialmenu:client:reapplyWalkstyle` from that resource |

## Changelog
- 3.2.1 – Removed the Name Horse entry (no `/sethorsename` command exists).
- 3.2.1 – Medic menu now matches the reworked rsg-medic: Revive / Heal Wounds (events that no longer exist) replaced by a Field Menu entry that runs `/medic`; removed the call to the non-existent `rsg-medic:server:medicAlert`.
- 3.2.0 – Shirt states (`/sleeve`, `/collar1`, `/collar2`) in a Shirt submenu and Coats submenu (keeps rings readable); menu closes on death/cuff/pause; hold-to-open only closes on the keybind release (Enter no longer closes the menu after opening a submenu); clicks use the clicked sector; stable order for dynamic options; plain-data payloads for server entries; invalid keybind guard; walk style no longer leaks between characters; client walk style cooldown; first-minute emergency cooldown bug; removed unused locale keys.
- 3.1.0 – Removed ox_lib dependency (locales and notify now from rsg-core).

Support: https://rexshack.tebex.store

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-radialmenu 3.2.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.Keybind` | `'F6'` |  |
| `Config.HoldToOpen` | `true` | true: hold key, release to close \| false: tap to open |
| `Config.EmergencyCooldown` | `60` | seconds between emergency button presses |
| `Config.WalkstyleCooldown` | `2` | seconds between walkstyle changes (server enforced) |
| `Config.LawJobs` | `{ vallaw = true, rholaw = true, blklaw = true, strlaw = true, stdenlaw` |  |
| `Config.MedicJobs` | `{ medic = true }` |  |
| `Config.Walkstyles` | `table` | key = { clipset, motion type }  (server only accepts keys listed here) |
| `Config.MenuItems` | `table` |  |
| `Config.JobInteractions` | `table` |  |

### Exports

**Client**

| Export | Arguments | File |
|---|---|---|
| `AddOption` | `` | `client/main.lua` |
| `RemoveOption` | `` | `client/main.lua` |

```lua
-- example
local result = exports['rsg-radialmenu']:AddOption()
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-radialmenu:client:noPlayers` | client | `` | `client/main.lua` |
| `rsg-radialmenu:client:SendLawmanEmergencyAlert` | client | `` | `client/main.lua` |
| `rsg-radialmenu:client:SendMedicEmergencyAlert` | client | `` | `client/main.lua` |
| `rsg-radialmenu:client:setWalkstyle` | client | `data` | `client/walkstyles.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/walkstyles.lua` |
| `rsg-radialmenu:client:reapplyWalkstyle` | client | `` | `client/walkstyles.lua` |
| `rsg-radialmenu:server:setWalkstyle` | server | `key` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-radialmenu:server:setWalkstyle', key)
-- from a server script
TriggerClientEvent('rsg-radialmenu:client:noPlayers', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
