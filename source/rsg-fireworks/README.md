# RSG Fireworks

Player-useable fireworks and admin-controlled firework displays for the RSG Framework.

**Version:** 3.0.0
**Author:** RexShack
**Framework:** RSG Core
**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-gizmo`

Full technical documentation: [DOCS.md](DOCS.md)

---

## Features

- **Individual Fireworks** — players use `firework_big` / `firework_small` items and place them in the world with `rsg-gizmo`.
- **Firework Displays** — timed, multi-firework sequences triggered by admin commands.
- **Particle Effects** — RedM particle assets plus configurable explosions and sound.
- **Server-Authoritative** — the item is consumed only after the server validates the `rsg-gizmo` placement; broadcasts still require that validated use.
- **Anti-Abuse** — per-player cooldowns, placement distance checks and display rate limits.
- **Localisation** — all player-facing text comes from `locales/en.json` via the rsg-core locale loader.
- **Clean Lifecycle** — particles and spawned objects are tracked and removed on resource stop.

---

## Installation

### Prerequisites

- `rsg-core` (3.0.3 or newer)
- `rsg-inventory`
- `rsg-gizmo`

### Load order

```cfg
ensure rsg-core
ensure rsg-inventory
ensure rsg-gizmo

# Add the custom items to rsg-core before starting this resource
ensure rsg-fireworks
```

### Items

Add the item definitions from `installation/shared_items.lua` to the shared items table in `rsg-core/shared/items.lua`:

```lua
firework_big   = { name = 'firework_big',   label = 'Big Firework',   weight = 1000, type = 'item', image = 'firework_big.png',   unique = false, useable = true, shouldClose = true, description = 'create explosions in the sky!' },
firework_small = { name = 'firework_small', label = 'Small Firework', weight = 500,  type = 'item', image = 'firework_small.png', unique = false, useable = true, shouldClose = true, description = 'create explosions in the sky!' },
```

Copy `firework_big.png` and `firework_small.png` into your inventory's item image folder.

### Database

This resource does not create or use any database tables.

---

## Configuration

Edit `shared/config.lua`:

| Option | Default | Description |
|---|---:|---|
| `Config.EnableSound` | `true` | Play explosion audio. |
| `Config.BigFireworkTime` | `30` | Big firework duration in seconds. |
| `Config.SmallFireworkTime` | `30` | Small firework duration in seconds. |
| `Config.PlacementDistance` | `6.0` | Maximum metres between the player and the placed firework (enforced by `rsg-gizmo`). |
| `Config.FuseTime` | `5000` | Milliseconds between confirming the placement and the firework igniting. |
| `Config.AllowInteriorPlacement` | `false` | When `false`, fireworks can only be placed outdoors. |
| `Config.PendingFireworkTimeout` | `30000` | Milliseconds after an item use in which the player may finish placing the firework. |
| `Config.BroadcastCooldown` | `1000` | Milliseconds between ignited fireworks per player. |
| `Config.DisplayCooldown` | `5000` | Milliseconds between display commands per admin. |
| `Config.Displays` | Valentine | List of display definitions (see below). |

### Adding a display

```lua
{
    name = 'Display Name',
    command = 'displaycommand',
    fireworks = {
        { type = 'small', coords = vector3(x, y, z), delay = 0 },
        { type = 'big',   coords = vector3(x, y, z), delay = 5000 },
    }
}
```

| Field | Description |
|---|---|
| `name` | Display name used server-side for validation. |
| `command` | Chat command that triggers the display (case-sensitive, unique). |
| `fireworks[].type` | `'small'` or `'big'`. |
| `fireworks[].coords` | World position of the firework. |
| `fireworks[].delay` | Milliseconds before the firework starts. |

---

## How to use

### Players

1. Obtain a `firework_big` or `firework_small` item.
2. Use the item from the inventory.
3. The `rsg-gizmo` placement tool opens. Move and rotate the firework, then confirm the placement. Indoor positions are rejected.
4. The item is consumed, a short fuse runs, and the firework ignites for nearby players.

Cancelling the placement (or failing validation) leaves the item in the inventory. A second firework cannot be started until the current placement is confirmed or cancelled.

The placement keys are the standard `rsg-gizmo` controls, shown in its on-screen HUD.

### Admins

Run the command configured for a display. The default display uses:

```text
/valfireworkdisplay
```

Display commands require the `admin` permission or an ACE entry allowed to use `command`. Unauthorised attempts receive an error notification.

| Command | Permission | Description |
|---|---|---|
| `/valfireworkdisplay` | Admin | Triggers the Valentine display. |
| *(configured commands)* | Admin | Any command added to `Config.Displays`. |

---

## Developer examples

Trigger a display for all players from another trusted resource:

```lua
TriggerClientEvent('rsg-fireworks:client:display', -1, 'Valentine Display')
```

Listen for a validated firework placement:

```lua
AddEventHandler('rsg-fireworks:server:place', function(item, coords, rot)
    -- item: 'firework_big' | 'firework_small'
    -- coords: vector3, rot: vector3 (pitch, roll, yaw)
end)
```

See [DOCS.md](DOCS.md) for the full event and security reference.

---

## Locales

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

Set the server locale to one of the included language codes:

```cfg
setr rsg:locale "de"
```

To add another language, copy `locales/en.json` to `locales/<code>.json`, translate the values, then set the server locale to that code. Missing keys fall back to `en.json`.

---

## Support

- Support the Project : https://rexshack.tebex.store/

## License

This project is licensed under the terms specified in the LICENSE file.

## Special thanks

Special thanks goes out to the original creator Xakra — https://github.com/XakraD
