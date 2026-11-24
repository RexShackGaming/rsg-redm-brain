<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# ⭐ rsg-lawman `3.4.0`
**Law enforcement and sheriff management system for RedM using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Full-featured law enforcement framework for RedM built on RSG Core.  
> Provides arrest, search, alerts, and law office management systems with rsg-core notifications/locales and configurable prompts.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠
- [**oxmysql**](https://github.com/overextended/oxmysql) 🗄️ *(for database storage)*
- [**rsg-inventory**](https://github.com/Rexshack-RedM/rsg-inventory) 🎒 *(for player search & confiscation)*

**Interaction:** Prompts are automatically created at each law office defined in `Config.LawOfficeLocations`.  
**Keybind:** Default interaction key = `'J'`.  
**Locales:** en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (plus cs, it), loaded via rsg-core (`@rsg-core/shared/locale.lua`). Set language with `setr rsg:locale <code>`.

---

## ✨ Features (detailed)

### 🧭 Law Office Menu
- Built-in NUI menu (RDR2 leather & gold style) for players with a **law job** (e.g., `vallaw`, `rholaw`, `blklaw`).
- Shows your duty state; the armoury is greyed out below the required grade.
- Opened through prompts created at configured coordinates.

### 👮 Law Tools
- **Search Player Inventory**
  - Command: `/searchplayer`
  - Progress bar, then opens the inventory of a restrained player (cuffed, down, hands up, hogtied or lassoed).
- **Cuff / Escort / Jail**
  - `/cuff` (soft, can walk) or `/cuff hard` (frozen), `/escort`, `/jail <id> <minutes>`, `/jailnear` (dialog, also a rebindable key), `/unjail <id>`.
- **Frisk & Seize**: `/frisk` lists weapons and contraband, pick one to seize.
- **Fines**: `/fine <id> <amount> <reason>` through rsg-society.
- **Holding cells**: `/holdcell <id>`, `/releasecell <id>` (set `Config.HoldingCells`).
- **/911**: any player can report a crime to the on-duty law.
- **Alert types** with their own blip, timer and notification style; optional gunshot alerts.
- **Outlaw cooldown** and a **Discord log** (both off by default).
- **Crime Alerts**
  - Command: `/testalert` (debug/test command).
  - Triggers a **map alert** for nearby lawmen.
  - Alerts can originate from player or NPC deaths (configurable).
- **Lawman Alert System**
  - Sends real-time alerts to on-duty lawmen with coordinates and context.
  - Customizable cooldown, distance, and timer values in config.

### 🔫 Storage & Armoury
- Shared storage locker per law job, only at your own office.
- `Config.StorageMaxWeight` and `Config.StorageMaxSlots` define stash capacity.
- `Config.ArmouryAccessGrade` determines minimum grade required for access.

### 🧩 Configuration Highlights
| Option | Default | Description |
|---|---|---|
| `Config.RequireOnDuty` | `true` | cuff, escort, search, jail and unjail need on-duty |
| `Config.MaxJailTime` | `180` | longest sentence (minutes) |
| `Config.ActionDistance` / `JailDistance` | `4.0` / `10.0` | server-side distance checks |
| `Config.CuffFreezePlayer` | `false` | cuffed players cannot walk |
| `Config.SearchTime` | `10000` | search progress bar in ms (`0` = instant) |
| `Config.SearchRequireRestrained` | `true` | target must be cuffed, down, hands up, hogtied or lassoed |
| `Config.AlertTimer` | `60` | seconds an alert blip stays |
| `Config.AlertCooldown` | `30000` | ms between automatic death alerts |
| `Config.EnablePlayerDeathAlerts` / `EnableNPCDeathAlerts` | `false` | automatic alerts |
| `Config.ArmouryAccessGrade` | `1` | grade needed for the armoury |
| `Config.StorageMaxWeight` / `StorageMaxSlots` | `4000000` / `50` | law storage size |
| `Config.Keybind` | `'J'` | office prompt key |
| `Config.JailNearKey` | `''` | rebindable key for "jail closest player" (game key settings) |
| `Config.Frisk` / `Fines` / `Report` | tables | frisk, fines and `/911` settings |
| `Config.AlertTypes` | tables | blip and notification style per alert type |
| `Config.GunshotAlerts` / `OutlawDecay` / `HoldingCells` / `Discord` | off / empty | optional features |

See [DOCS.md](DOCS.md) for every option, export, event and the security model.

### 🗺️ Law Office Locations
Example from `config.lua`:
```lua
Config.LawOfficeLocations = {
    {
        name = 'Lawman Office',
        prompt = 'vallawoffice',
        coords = vector3(-278.42, 805.29, 119.38),
        jobaccess = 'vallaw',
        blipsprite = 'blip_ambient_sheriff',
        blipscale = 0.2,
        showblip = true
    },
}
```

---

## 📸 Preview
*(soon)*

---

## 📂 Installation
1. Place `rsg-lawman` inside your `resources/[rsg]` folder.
2. Ensure **rsg-core**, **rsg-inventory**, and **oxmysql** are installed (**rsg-society** for `/fine`) (ox_lib is no longer required).
3. No database import needed. Adjust settings and locations in `config.lua`.
4. Add to your `server.cfg`:
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-lawman
   ```
5. Restart your server.

---

## 🎙️ Push-to-talk
`Config.AllowPushToTalkWhileOpen` (default `true`) keeps push-to-talk working while the menu or jail dialog is open; other game controls are blocked. Controls are listed in `Config.PushToTalkControls`.

---

## ⭐ Reputation (optional)
With `rsg-reputation` started, a lawman who jails a player earns the `arrest` action. Configure in `Config.Reputation` (`Enabled`, `Action`, `MinMinutes`, `Cooldown`).

## 🔐 Permissions
- Law actions need a job of type `leo` and, with `Config.RequireOnDuty`, to be on duty. Everything is re-checked on the server (job, duty, distance, arguments).
- The armoury needs grade ≥ `Config.ArmouryAccessGrade`; the storage needs you to stand at your own office.

---

## 🌍 Locales
Provided in `locales/`: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru` (plus `cs`, `it`).  
Fully localized prompts, menus, and notifications.

---

## 💎 Credits
- **RSG / Rexshack-RedM** and contributors  
- Community testers and translators  
- License: GPL‑3.0  

Support: https://rexshack.tebex.store
