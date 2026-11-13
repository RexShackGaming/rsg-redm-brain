# rsg-backpacks – Docs (v3.0.4)

## Contents
1. Files
2. How it works
3. Setup
4. Configuration
5. Exports and commands
6. Database
7. Security
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `oxmysql` |
| `shared/config.lua` | Backpack types, limits, belt attachments |
| `client/main.lua` | Wearing, prop attach, `/removebackpack` |
| `client/belt.lua` | Belt and back attachments (lanterns, lasso, machete, quiver) |
| `server/main.lua` | Useable items, stashes, nested and one-backpack rules, recovery |
| `server/database.lua` | Automatic table creation and upgrade |
| `server/utils.lua` | Rate limit helpers |
| `server/versionchecker.lua` | GitHub version check |
| `installation/items.lua` | The 7 backpack items to paste into your items file |
| `installation/player_backpack.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

## 2. How it works
- Merges and replaces `hdrp-backpack` and `bln_belt_attachments`. Stop both before starting rsg-backpacks.
- 7 wearable backpack types, each with its own stash size and prop position.
- Each backpack has a unique serial; its stash is `backpack_<serial>` and persists.
- A backpack cannot be stored inside another backpack or itself (`BlockNestedBackpacks`).
- With `OneBackpackOnly`, a player can carry only one backpack item; extras are moved back.
- Belt/back attachments: lanterns, Davy lantern, metal detector, lasso, reinforced lasso, machete, bow quiver.

| Item | Slots | Max weight |
|---|---|---|
| `backpack_ammo` | 24 | 22000 |
| `backpack_fish` | 24 | 32000 |
| `backpack_nat` | 32 | 42000 |
| `backpack_big` | 128 | 62000 |
| `backpack_normal` | 64 | 52000 |
| `backpack_simple` | 32 | 22000 |
| `backpack_trapper` | 64 | 22000 |

## 3. Setup
1. Paste `installation/items.lua` into `RSGShared.Items` in `rsg-core/shared/items.lua`. Backpack items **must** be `unique = true`.
2. Copy the images from `installation/images/` into `rsg-inventory/html/images/`.
3. Database: nothing to import; the table is created and upgraded on start (`Config.AutoCreateTable`).
4. `ensure oxmysql`, `rsg-core`, `rsg-inventory`, then `rsg-backpacks`.

## 4. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `ActionCooldown` | `1000` | ms between open requests per player |
| `AutoCreateTable` | `true` | Build/upgrade `player_backpack` on start |
| `BlockNestedBackpacks` | `true` | No backpacks inside backpack stashes |
| `OneBackpackOnly` | `true` | One backpack item per player |
| `backpackType` | list | `{ model, item, maxweight, slots, position, rotation }` per backpack |

## 5. Exports and commands
| Name | Side | Notes |
|---|---|---|
| `IsBackpackItem(itemName)` | server export | True if the item is a configured backpack |
| `rsg-backpacks:client:wear` | client event | `(itemName, serial)` |

| Command | Who | What |
|---|---|---|
| `/removebackpack` | everyone | Take the worn backpack off |
| `/backpackrecover` | everyone | Recover items from a backpack stash (rate limited) |

## 6. Database
```sql
CREATE TABLE IF NOT EXISTS `player_backpack` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `serial` VARCHAR(32) NOT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `owner` VARCHAR(50) DEFAULT NULL,
    `backpackitem` VARCHAR(50) NOT NULL,
    `model` VARCHAR(100) DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `serial` (`serial`),
    KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
Older tables (e.g. from hdrp-backpack) get missing columns and indexes added automatically.

## 7. Security
Open requests are rate limited. Nested and extra backpacks are removed by the server and returned to the player's inventory (with restore on failure). Stash names come from the item serial, never from the client.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Backpack doesn't open | Item must be `unique = true` and listed in `backpackType` |
| Items missing after moving | Use `/backpackrecover` |
| Old resources conflict | Stop `hdrp-backpack` and `bln_belt_attachments` |
| Table errors | Import `installation/player_backpack.sql` |

Support the Project : https://rexshack.tebex.store/
