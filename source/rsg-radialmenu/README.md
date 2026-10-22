<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🧭 rsg-radialmenu
**Radial interaction menu for RedM using RSG Core.**

![Version](https://img.shields.io/badge/version-1.2.0-red)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

A fast, themed radial menu with nested submenus, job-specific actions, synced walk styles and an export API so other resources can add their own options.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core)
- [**ox_lib**](https://github.com/overextended/ox_lib) – notifications & locales
- *(optional)* **rsg-essentials**, **rsg-horses**, **rsg-lawman**, **rsg-medic**, **rsg-telegram**, **rsg-appearance** – for the default menu entries

---

## ✨ Features
- 🧭 Radial menu with unlimited nested submenus
- 👮 Job menus (law & medic by default) shown only to the right jobs
- 🚨 Emergency button with job check and cooldown
- 🚶 Walk styles – server-validated, **visible to all players**, saved to the character and restored on login
- 🧩 `AddOption` / `RemoveOption` exports with `canOpen` and `action` support
- 🎨 RDR2 monochrome leather theme, Font Awesome 6 icons
- ⌨️ Mouse, scroll wheel, number keys `1–9`, `Enter`, `Esc` / `Backspace` (back)
- 🌍 Locales: `en, de, el, es, fr, ja, nl, pl, pt-br, ro`
- 🔒 NUI never decides what runs – selections are matched against the client's own menu tree

---

## 📥 Installation
1. Place `rsg-radialmenu` in your `resources/[rsg]` folder.
2. Add to `server.cfg` **after** `rsg-core` and `ox_lib`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-radialmenu
   ```
3. *(optional)* Set the language:
   ```cfg
   setr ox:locale "en"
   ```
4. Restart the server.

---

## ⚙️ Configuration (`config.lua`)

| Option | Default | Description |
|---|---|---|
| `Config.Keybind` | `'F6'` | Key from `RSGCore.Shared.Keybinds` |
| `Config.HoldToOpen` | `true` | `true` = hold key, release to close · `false` = tap to open |
| `Config.EmergencyCooldown` | `60` | Seconds between emergency button presses |
| `Config.WalkstyleCooldown` | `2` | Seconds between walk style changes (server enforced) |
| `Config.LawJobs` | `vallaw, rholaw, blklaw, strlaw, stdenlaw` | Jobs that get the law menu |
| `Config.MedicJobs` | `medic` | Jobs that get the medic menu |
| `Config.Walkstyles` | 7 styles | `key = { clipset, motionType }` – server only accepts these keys |

### Menu items
Use the helper builders at the top of `config.lua`:

```lua
cmd('dress', locale('cloth_dress'), 'person-dress', 'dress')            -- runs /dress
cl('horselantern', locale('menu_horse_lantern'), 'lightbulb', 'rsg-horses:client:equipHorseLantern') -- client event
walk('angry', locale('walk_angry'))                                     -- walk style
```

Or write the table yourself:

| Field | Description |
|---|---|
| `id` | Unique id |
| `title` | Label (use `locale('key')`) |
| `icon` | Font Awesome 6 name (`'horse-head'`) or full class (`'fa-brands fa-discord'`) |
| `type` | `client`, `server`, `command` or `rsgcommand` |
| `event` | Event / command name |
| `shouldClose` | Close after selecting (default `true`, set `false` to keep open) |
| `items` | Sub items – makes this entry a submenu |

Browse icons at [fontawesome.com/icons](https://fontawesome.com/search?o=r&m=free).

---

## 🧩 Exports

```lua
local id = exports['rsg-radialmenu']:AddOption({
    id = 'my_category',
    title = 'My Actions',
    icon = 'star',
    items = {
        { id = 'do_thing', title = 'Do Thing', icon = 'hand', type = 'server', event = 'my_res:server:doThing' },
        { id = 'custom', title = 'Custom', icon = 'bolt', action = function(item) print('clicked', item.id) end },
    },
    canOpen = function()
        return LocalPlayer.state.isLoggedIn
    end,
})

exports['rsg-radialmenu']:RemoveOption(id)
```

- Pass a second argument to `AddOption(data, id)` to replace an existing option.
- `canOpen` is checked every time the menu opens; empty submenus are hidden.

> ⚠️ Server events you add are triggered by the client. Always validate them server-side.

---

## 📡 Events

| Event | Side | Description |
|---|---|---|
| `rsg-radialmenu:client:onRadialmenuOpen` | client | Fired when the menu opens |
| `rsg-radialmenu:client:onRadialmenuClose` | client | Fired when the menu closes |
| `rsg-radialmenu:client:setWalkstyle` | client | Set walk style: `TriggerEvent(..., 'angry')` |
| `rsg-radialmenu:client:reapplyWalkstyle` | client | Re-apply own walk style (call after skin reloads) |
| `rsg-radialmenu:client:noPlayers` | client | "No one nearby" notification |

Walk styles are stored in the player state bag `walkstyle` and in character metadata `walkstyle`.

---

## 🌍 Locales
Files live in `locales/*.json`. Copy `en.json`, translate the values and set `setr ox:locale "<file name>"`.

---

## 🎨 Offline icons (optional)
Icons load from cdnjs by default. To host locally, download Font Awesome Free into `html/fontawesome/`, change the `<link>` in `html/index.html` to `fontawesome/css/all.min.css` and add `'html/fontawesome/**'` to `files` in `fxmanifest.lua`.

---

## 💎 Credits
- **RSG / Rexshack-RedM** – framework & resource
- Radial menu originally based on work by **zfbx**
- Icons by [Font Awesome](https://fontawesome.com) (CC BY 4.0)
- License: GPL‑3.0
