<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🚔 rsg-prison
**Complete prison system for RedM servers using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Fully integrated jail and sentence system for RedM built on RSG Core.  
> Handles jailing, job removal, sentence timers, and automatic release with ox_lib prompts and blips.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️ *(for UI and notifications)*
- [**oxmysql**](https://github.com/overextended/oxmysql) 🗄️ *(for player metadata)*
- [**PolyZone**](https://github.com/mkafrin/PolyZone) 📦 *(for prison area detection)*

**Locales:** `locales/en.json, fr.json, es.json, it.json, el.json, pt-br.json` (loaded via `lib.locale()`).

---

## ✨ Features (detailed)

### 🧭 Prison System
- Sends players to **Sisika Prison** and tracks remaining jail time.
- Automatically **removes player job** if `Config.RemoveJob = true`.
- Players are **automatically freed** after their sentence expires.
- Saves jail time in player metadata (`injail` key).

### 🗺️ Map & Zones
- Prison blip appears on map (`blip_mp_roles_bounty_hunter_lock`).
- Zone detection uses **PolyZone** to check if the player leaves prison bounds.
- Configurable **spawn points** for jailed players.

### 💬 Menu System
- Menu prompt defined in `Config.MenuLocations`.
- Opens jail management options (add/remove players, set time, etc.).

### 🚨 Server Events
```lua
-- Update sentence time
TriggerServerEvent('rsg-prison:server:updateSentance', newTime)

-- Remove job when jailed
TriggerServerEvent('rsg-prison:server:RemovePlayerJob')

-- Free player after sentence expires
TriggerServerEvent('rsg-prison:server:FreePlayer')
```

### ⚙️ Configuration
```lua
Config.RemoveJob = true      -- Player loses job when jailed
Config.MarkerDistance = 10.0 -- Marker draw distance
Config.Keybind = 'J'         -- Interaction key
Config.DistanceSpawn = 20.0  -- Spawn check distance
Config.FadeIn = true         -- Fade-in effect after teleport

Config.Blip = {
    blipName = 'Sisika Prison',
    blipSprite = 'blip_mp_roles_bounty_hunter_lock',
    blipScale = 0.2
}

Config.Locations = {
    ["outside"] = { coords = vector4(3340.71, -629.99, 43.72, 36.36) },
    ["middle"]  = { coords = vector4(3357.41, -679.26, 46.26, 165.59) },
    spawns = {
        [1] = { coords = vector4(3330.66, -692.75, 43.95, 292.86) },
        [2] = { coords = vector4(3349.62, -650.41, 45.38, 207.53) },
        [3] = { coords = vector4(3380.62, -672.35, 46.27, 110.95) },
        [4] = { coords = vector4(3366.75, -666.08, 46.34, 297.69) }
    }
}

Config.MenuLocations = {
    {
        name = 'Jail Menu',
        coords = vector3(3350.0, -680.0, 45.5),
        showblip = true
    }
}
```

---

## 📸 Preview
*(soon)*

---

## 📂 Installation
1. Place `rsg-prison` inside your `resources/[rsg]` folder.
2. Ensure `rsg-core`, `ox_lib`, `PolyZone`, and `oxmysql` are installed.
3. Configure `config.lua` for jail locations and behavior.
4. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure PolyZone
   ensure rsg-prison
   ```
5. Restart your server.

---

## 🔐 Permissions
- Only lawmen or admins should have access to jail commands.  
- Jail time is enforced server-side and saved as metadata.

---

## 🌍 Locales
Included languages: `en`, `fr`, `es`, `it`, `el`, `pt-br`.  
Loaded using `lib.locale()` for both client and server messages.

---

## 💎 Credits
- **RSG / Rexshack-RedM** and contributors  
- Community testers and translators  
- License: GPL‑3.0  

