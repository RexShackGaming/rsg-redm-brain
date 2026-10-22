<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 💥 rsg-ammo
**Persistent ammunition system for RedM using the RSG Framework.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

Players refill their weapons by using ammo boxes and arrows from their inventory, and every ammo type is saved to the database per character, so ammo carries over between sessions and restarts.

---

## ✨ Features
- 📦 **Ammo boxes** for revolver, pistol, repeater, rifle, shotgun, elephant rifle and varmint ammo, including express, explosive, high velocity and split point variants.
- 🏹 **Arrow items** (regular, small game, fire, poison, dynamite) that refill instantly.
- 💾 **Persistent ammo** for every ammo type, including throwables: dynamite, molotovs, throwing knives, tomahawks, bolas and hatchets.
- 🚫 **Per-type carry limits**: an item is never used up if the player is already at max ammo.
- ⏳ **Cancellable progress bar** when opening a box; cancelling keeps the box.
- 🗄️ **Automatic database setup**: the table and any new ammo columns are created on start, with a manual SQL file as backup.
- 🔒 **Server-authoritative**: the server decides the item, ammo type and amount; saved values are validated and clamped.
- 🌍 **Localised** with ox_lib: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

---

## 🛠️ Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

---

## 📂 Installation
1. Download the resource and place the `rsg-ammo` folder in your `resources/[rsg]` directory.
2. Make sure all ammo items exist in `rsg-core/shared/items.lua` with `useable = true` (see [Items](#-items)).
3. Add it to `server.cfg` **after** its dependencies:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-ammo
   ```
4. Start or restart the server. The `player_ammo` table is created automatically; look for errors starting `[rsg-ammo]` in the console.

**Manual database (backup):** if automatic setup fails, usually because the database user lacks `CREATE`/`ALTER` permissions, import `installation/rsg-ammo.sql` into your database and restart.

---

## 🎮 How to use
**Players**
1. Open your inventory and use an ammo box (e.g. *Revolver Ammo Box*).
2. A progress bar shows while the box opens. Press the cancel key to stop and keep the box.
3. When it finishes, the box is removed and the ammo is added. A notification shows how much was added.
4. Arrows work the same way but are applied instantly, with no progress bar.

If you're already carrying the maximum for that ammo type you'll see **"Max Ammo Reached"** and the item isn't used.

Your ammo is saved automatically and restored when you next log in with that character.

**Server owners**
- Sell ammo items in your shops, or give them with `/giveitem [id] ammo_box_revolver 1`.
- Change carry limits and refill amounts in `shared/config.lua`.

---

## ⚙️ Configuration (`shared/config.lua`)

| Option | Default | Description |
|--------|---------|-------------|
| `Config.SaveAmmoInterval` | `10000` | How often (ms) changed ammo counts are saved to the database. Only changed values are sent. |
| `Config.OpenAmmoBoxTime` | `2000` | Progress bar duration (ms) when opening an ammo box. |
| `Config.BoxAmmo` | | Ammo box item name → ammo type. Uses the progress bar. |
| `Config.ArrowAmmo` | | Arrow item name → ammo type. Applied instantly. |
| `Config.AmmoTypes` | | Per ammo type: `maxAmmo` (carry limit) and `refill` (amount given per item). |

```lua
Config.AmmoTypes = {
    ['AMMO_REVOLVER'] = { maxAmmo = 200, refill = 12 },
    ['AMMO_ARROW']    = { maxAmmo = 40,  refill = 10 },
    -- ...
}
```

**Adding a new ammo item**
1. Add the item to `rsg-core/shared/items.lua` (`useable = true`).
2. Map it in `Config.BoxAmmo` or `Config.ArrowAmmo` to an ammo type.
3. If the ammo type isn't already in `Config.AmmoTypes`, add it. Its database column is created automatically on the next restart.

---

## 📦 Items

| Item(s) | Ammo type |
|---------|-----------|
| `ammo_box_revolver`, `_express`, `_explosive`, `_velocity`, `_splitpoint` | `AMMO_REVOLVER` variants |
| `ammo_box_pistol`, `_express`, `_explosive`, `_velocity`, `_splitpoint` | `AMMO_PISTOL` variants |
| `ammo_box_repeater`, `_express`, `_explosive`, `_velocity`, `_splitpoint` | `AMMO_REPEATER` variants |
| `ammo_box_rifle`, `_express`, `_explosive`, `_velocity`, `_splitpoint` | `AMMO_RIFLE` variants |
| `ammo_box_shotgun` | `AMMO_SHOTGUN` |
| `ammo_box_shotgun_buckshot_incendiary` | `AMMO_SHOTGUN_BUCKSHOT_INCENDIARY` |
| `ammo_box_shotgun_slug`, `ammo_box_shotgun_slug_explosive` | `AMMO_SHOTGUN_SLUG` variants |
| `ammo_box_rifle_elephant` | `AMMO_RIFLE_ELEPHANT` |
| `ammo_box_varmint`, `ammo_box_varmint_tranquilizer` | `AMMO_22` variants |
| `ammo_arrow` | `AMMO_ARROW` |
| `ammo_arrow_small` | `AMMO_ARROW_SMALL_GAME` |
| `ammo_arrow_fire`, `ammo_arrow_poison`, `ammo_arrow_dynamite` | `AMMO_ARROW_FIRE` / `_POISON` / `_DYNAMITE` |

Example `items.lua` entry:
```lua
ammo_box_revolver = { name = 'ammo_box_revolver', label = 'Revolver Ammo Box', weight = 250, type = 'item', image = 'ammo_box_revolver.png', unique = false, useable = true, shouldClose = true, description = 'Box of standard revolver ammo' },
```

---

## 🌍 Locales
All player-facing text lives in `locales/*.json`. Choose the language in `server.cfg`:
```cfg
setr ox:locale en
```
Available: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

---

## 🔌 Exports (client)
```lua
local ammoTypes = exports['rsg-ammo']:GetAmmoTypes()
-- { AMMO_REVOLVER = { hash = ..., dbColumn = 'ammo_revolver', maxAmmo = 200 }, ... }
```

---

## 🧠 Troubleshooting
| Issue | Solution |
|-------|----------|
| Item does nothing when used | Check it exists in `items.lua` with `useable = true` and is listed in `Config.BoxAmmo` or `Config.ArrowAmmo`. |
| "Max Ammo Reached" | The player is at `maxAmmo` for that type; raise it in config if needed. |
| Ammo not saved after relog | Look for `[rsg-ammo] database setup failed` in the console; if shown, import `installation/rsg-ammo.sql`. |
| Text shows as a key (e.g. `ammo_max_reached`) | Check `setr ox:locale` is set to one of the available languages. |

---

## 💎 Credits
- **RSG / Rexshack-RedM**: framework and resource
- Community translators
- License: GPL‑3.0

☕ Support: https://buymeacoffee.com/rexshack
