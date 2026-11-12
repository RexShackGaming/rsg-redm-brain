# rsg-rocks

Mining system for RSG Framework (rsg-core 3.x). Mine rocks and salt rocks, drill them into ores and gems at mining camps, and smelt ores into bars.

## Features

- Any player can mine, drill and smelt (no job lock)
- Database rock nodes with in-game admin place (rsg-gizmo: move + rotate, heading saved) / delete / toggle
- rsg-target on rock props (or plain sphere zones with `Config.SpawnRockProps = false`)
- Pickaxe durability (item `quality` metadata) – breaks at 0, or with `Config.PickaxeBreakAtZero = false` it is kept at 0 and can't mine until its quality is raised again (e.g. by a repair / sharpening script)
- Global node deplete (rock is empty for everyone for a while) + personal cooldown
- Mining XP / levels (`/miningxp`) with a yield bonus per level
- Foreman drill menu (NUI): choose how many rocks to drill or batch drill them one rock at a time, each paying out as it finishes (`Config.DrillMaxBatch`, `Config.DrillBatchPause`); push-to-talk works while it is open (`Config.AllowPushToTalkWhileOpen`)
- Weighted drill loot, rare gem chance on normal rock
- Camp smelting: one target option per recipe, only shown when you have the ore
- Miner's hat with lamp: needs the `mininghat` item, worn automatically near mining rocks and toggled on/off by using the item; the player's own hat is taken off while the miner's hat is worn and put back afterwards (`Config.MiningHat`)
- Miner's lamp panel (opens with `/minerlight` while the hat is worn, top left by default, draggable): light colour, brightness and spread, on/off; `/minerlight` to adjust. Settings and panel position are saved per player, and other players see your lamp (`Config.MiningHat.light`)
- Server-authoritative timed sessions for mining, drilling and smelting (no instant-reward spam)
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro

## Miner's hat item

Add to `rsg-core/shared/items.lua`:

```lua
mininghat = { name = 'mininghat', label = "Miner's Hat", weight = 500, type = 'item', image = 'mininghat.png', unique = false, useable = true, shouldClose = true, description = 'A hard hat with a lamp. Use it to put it on or take it off.' },
```

## Dependencies

- rsg-core
- rsg-inventory
- rsg-target
- rsg-gizmo
- oxmysql

## Installation

1. Place `rsg-rocks` in your resources folder.
2. The `rsg_rocks_zones` table is created and seeded automatically on first start (`Config.AutoCreateDatabase`, `Config.AutoSeedDefaultZones`). Prefer manual? Set both to `false` and import `install.sql`.
3. Make sure these items exist in your shared items: `pickaxe`, `mininghat` (useable), `resource_rock`, `resource_salt_rock`, and every output item in `shared/config.lua` (ores, bars, gems).
4. Add `ensure rsg-rocks` to `server.cfg` after its dependencies.

## Admin commands

Requires `Config.AdminPermission` (default `admin`) or `god`.

| Command | Description |
|---|---|
| `/rockadmin` | Help + loaded zone count |
| `/addrock [rock\|saltrock] [radius]` | Placement mode (ghost prop). **E** confirm, **Backspace** cancel |
| `/delrock [id]` | Delete nearest rock or by id (works on disabled rocks too) |
| `/togglerock [id]` | Enable/disable a rock without deleting it |
| `/nearbrocks [range]` | List rocks near you (default 25 m) |
| `/reloadrocks` | Reload zones from the database |
| `/miningxp` | (players) show your mining level and XP |

## Config

See `shared/config.lua` for timers, distances, workshop camps, rewards, drill/gem pools and smelting recipes.

## Locales

Set the language with `setr rsg:locale "en"` in server.cfg.

## Support

https://buymeacoffee.com/rexshack
