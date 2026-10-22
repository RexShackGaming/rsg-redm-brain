# rsg-backpacks

Wearable backpacks with persistent stashes and belt/back attachments for **RedM** on **RSG-Core**.

This resource merges and replaces:

- `hdrp-backpack` (backpacks, stashes)
- `bln_belt_attachments` (lanterns, lasso, machete, quiver)

> Stop both old resources before starting `rsg-backpacks`.

---

## Features

- **Wearable backpacks**: 7 backpack types, each with its own stash size and prop position.
- **Persistent stashes**: each backpack has a unique serial, and its stash is `backpack_<serial>`.
- **No nested backpacks**: a backpack can't be stored inside another backpack (or itself).
- **Belt/back attachments**: shows owned but unequipped items on the character:
  - lanterns, Davy lantern, metal detector
  - lasso, reinforced lasso
  - machete
  - bow quiver
- **ox_lib**: notifications and locales.
- **Locales (ox_lib JSON)**: en, de, el, es, fr, ja, nl, pl, pt-br, ro.

---

## Requirements

| Resource | Purpose |
| --- | --- |
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Items and stashes |
| [ox_lib](https://github.com/overextended/ox_lib) | Notifications, locales |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |

---

## Installation

Everything you need to copy elsewhere is in the [`install`](install) folder.

1. Place the folder in your resources directory as `rsg-backpacks`.
2. Add the backpack items to `rsg-core/shared/items.lua` using `install/items.lua` (see below).
3. Copy the PNGs from `install/images/` into `rsg-inventory/html/images/`.
4. **Database:** nothing to import. On start the script creates the `player_backpack` table, adds any missing columns/indexes to older tables (e.g. from hdrp-backpack) and logs what it changed (`Config.AutoCreateTable = true`). To set it up manually instead, set it to `false` and import `install/player_backpack.sql`.
5. Add to `server.cfg`:

   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-backpacks
   ```

6. Make sure `hdrp-backpack` and `bln_belt_attachments` are **not** started.

### Items

`install/items.lua` contains the 7 backpack entries. Paste them inside `RSGShared.Items = { ... }` in `rsg-core/shared/items.lua`. Backpack items **must** stay `unique = true` so each one keeps its own serial:

```lua
backpack_simple = { name = 'backpack_simple', label = 'Backpack Simple', weight = 100, type = 'item', image = 'backpack_simple.png', unique = true, useable = true, shouldClose = true, description = 'Backpack Simple — useful item to have around.', category = 'backpacks' },
```

Items: `backpack_ammo`, `backpack_fish`, `backpack_nat`, `backpack_big`, `backpack_normal`, `backpack_simple`, `backpack_trapper`.

The belt/back attachments (lanterns, lasso, machete, bow) use weapons that are already defined in rsg-core's weapons list, so they need no new items.

---

## Usage

- **Use** a backpack item: it is assigned a serial on first use, the prop is attached to your back and the stash opens.
- **Use it again** while wearing it: the stash opens again.
- **Using a different backpack** while wearing one swaps the prop and opens that stash.
- **`/removebackpack`**: take off the backpack you are wearing.
- **One backpack per player** (`Config.OneBackpackOnly`): dragging a second backpack into your inventory (from a stash, the ground, etc.) sends it straight back. If you end up with two another way (given by a player or admin), you are warned and can't use a backpack until you drop or store the extra one.
- If the item leaves your inventory (dropped, given away, stolen), the prop is removed automatically.

---

## Configuration

All settings are in [`shared/config.lua`](shared/config.lua).

| Option | Default | Description |
| --- | --- | --- |
| `Config.ActionCooldown` | `1000` | Cooldown between backpack uses (ms) |
| `Config.AutoCreateTable` | `true` | Build / upgrade `player_backpack` on start |
| `Config.BlockNestedBackpacks` | `true` | Prevent backpacks from being stored inside backpack stashes |
| `Config.OneBackpackOnly` | `true` | A player can only carry one backpack at a time |

### Backpack types

Edit `Config.backpackType` to change models, stash `maxweight`/`slots`, and prop `position`/`rotation`.

### Belt attachments

Configured under `Config.Belt`:

- `enabled`: turn the whole module on or off.
- `debounceTime`: minimum time between attach/detach changes.
- `categories`: each entry has `hashName`, `model`, `bone`, `offset` and `alwaysAttached`. Set `female = false` to reuse the male bone/offset.

---

## Security

Everything involving items and money is validated on the server:

- The client never sends stash names, serials, weights or slots: the stash is opened by the server directly from the item use.
- Serials are assigned server-side by editing the item in place (`SetItemData`), so the backpack is never removed and re-added.
- Item serials are validated (alphanumeric, max 32 chars) before any database lookup.
- Backpack use is rate limited (`Config.ActionCooldown`) and guarded against parallel requests.
- If the backpack leaves the player's inventory while its stash is open (given away, dropped), the stash is closed.
- Backpacks can't be nested (`Config.BlockNestedBackpacks`). See below.

Items shown in the belt module are client-side visuals and have no server events.

### Nested backpack block

`rsg-inventory` has no item-move hook and performs moves as remove-then-add, so `rsg-backpacks` can't reject a move itself. Instead it **enforces** the rule:

- After any item is moved into a `backpack_<serial>` stash, and again when that stash is closed, the server scans it.
- Any backpack found inside is moved back to the player who put it there, who gets a notification.
- If the player has no room to take it back, the item is restored to the stash so nothing is ever lost. It is retried on the next move or close.
- Backpacks left in a stash by older versions or other scripts are cleaned up the same way.
- Only the player who opened the stash (through the server) can trigger this, so spoofed events can't pull backpacks out of someone else's stash.
- **Recovery:** backpacks already stuck inside one of your own backpacks are returned automatically when your character loads, or with `/backpackrecover`.

This needs no changes to `rsg-inventory`. The drawback is that the backpack briefly appears in the stash before being moved back.

#### Optional: instant block (patch `rsg-inventory`)

To refuse the move before anything changes, add this to `rsg-inventory/server/main.lua` inside the `rsg-inventory:server:SetInventoryData` handler, right after the `if not Player then return end` line:

```lua
local movingItem = getItem(fromInventory, src, tonumber(fromSlot))
if movingItem and toInventory:sub(1, 9) == 'backpack_'
    and exports['rsg-backpacks']:IsBackpackItem(movingItem.name) then
    TriggerClientEvent('ox_lib:notify', src, { description = 'Backpacks cannot be stored inside another backpack.', type = 'error', duration = 5000 })
    return
end
```

The `rsg-backpacks` enforcer stays active as a safety net.

---

## Localization

Locales use the ox_lib JSON format (`locales/<lang>.json`). Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

Pick the language with the ox_lib convar in `server.cfg`:

```cfg
setr ox:locale "de"
```

To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values. Keep every `%s` placeholder in the same order.

---

## File structure

```text
rsg-backpacks/
├── client/
│   ├── main.lua      # backpack prop handling
│   └── belt.lua      # belt/back attachments
├── server/
│   ├── utils.lua     # notify, rate limit, held-backpack lookup
│   ├── database.lua  # automatic table build / upgrade
│   └── main.lua      # serials, usable items, stash opening, nested block, recovery
├── shared/
│   └── config.lua
├── locales/          # en, de, el, es, fr, ja, nl, pl, pt-br, ro (.json)
├── install/
│   ├── images/       # backpack item icons (copy to rsg-inventory)
│   ├── items.lua     # item entries for rsg-core/shared/items.lua
│   └── player_backpack.sql
└── fxmanifest.lua
```

---

## Events

| Event | Side | Description |
| --- | --- | --- |
| `rsg-backpacks:client:wear` | client | Server tells the client to wear the backpack prop |

## Commands

| Command | Side | Description |
| --- | --- | --- |
| `/removebackpack` | client | Take off the worn backpack |
| `/backpackrecover` | server | Return backpacks stuck inside your own backpacks |

Export: `exports['rsg-backpacks']:IsBackpackItem(itemName)` returns `true` if the item is one of the configured backpacks.

---

## Changelog

### 1.0.1
- Serial assignment edits the item in place instead of remove + add (removes an item-loss path).
- Nested-block sweep only refreshes the inventory when something actually moved.
- Fixed a race where reopening a backpack within 0.5s of closing it lost stash tracking.
- Stricter serial validation.
- Belt attachments retry if a prop model fails to load instead of staying hidden.
- Removed unused `Config.Debug` / `BP.Debug`; one-backpack watchdog thread only starts when enabled.

---

## Credits

- Original backpack script: `hdrp-backpack`
- Original belt attachments: BLN Studio (`bln_belt_attachments`)
- Conversion, security fixes and merge for RSG-Core
