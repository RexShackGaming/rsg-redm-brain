<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 💈 rsg-barbers
**Barbershops for RedM (RSG Framework): hair, beard and makeup with a live preview.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

---

## ✨ Features
- Barber NPCs that spawn and fade in near each shop, with map blips.
- Sit in the barber chair with a scripted camera and studio lighting.
- Change hair style and colour, beard style and colour (male), and makeup: stubble (male), eyeshadow, blush, lipstick and eyeliner.
- The menu opens with your **current** look loaded, so you only change what you touch.
- Custom NUI panel in the RSG leather & gold style: Hair & Beard and Makeup tabs, arrow steppers (hold to repeat), clickable opacity bars, Shift + mouse wheel to adjust.
- Live preview. Leaving without paying (Cancel / ✕ / Esc) reverts your appearance.
- The price is shown in the panel. Press **Pay** (or Enter) to buy. You're only charged when something actually changed.
- Interaction via **rsg-target** on the NPC, or an rsg-core prompt.
- Secure server side: the server works out the hair/beard hashes itself, checks every makeup value against the config ranges, checks distance to the chair, applies a cooldown, takes cash before saving and refunds it if the save fails.
- Locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro (plus cs, it).

---

## 🛠️ Dependencies
- [rsg-core](https://github.com/Rexshack-RedM/rsg-core) (callbacks, notify, locales, prompts)
- [rsg-character](https://github.com/Rexshack-RedM/rsg-character) (`playerskins` table and skin reload)
- [rsg-target](https://github.com/Rexshack-RedM/rsg-target)
- [oxmysql](https://github.com/overextended/oxmysql)

No ox_lib needed.

---

## 📂 Installation
1. Put `rsg-barbers` in your resources folder.
2. Add it to `server.cfg` after its dependencies:
   ```cfg
   ensure oxmysql
   ensure rsg-core
   ensure rsg-target
   ensure rsg-character
   ensure rsg-barbers
   ```
3. Set the language with `setr rsg:locale en` (any shipped locale).

No SQL needed: styles are saved in the `skin` column of rsg-character's `playerskins` table.

---

## ⚙️ Configuration (`config.lua`)
| Option | Default | Description |
|---|---|---|
| `Config.BarberCost` | `5` | Cash price for a new style. A location can override it with `price`. |
| `Config.UseTarget` | `true` | `true` = rsg-target on the NPC, `false` = rsg-core prompt at `coords`. |
| `Config.Key` | `'J'` | Prompt key when not using target. |
| `Config.MaxDistance` | `3.0` | Max distance from the chair when paying (server checked). |
| `Config.Cooldown` | `3` | Seconds between purchase attempts. |
| `Config.MenuAlign` | `'right'` | Side of the screen for the NUI panel (`'right'` or `'left'`). |
| `Config.DistanceSpawn` | `20.0` | NPC spawn/despawn distance. |
| `Config.FadeIn` | `true` | Fade NPCs in and out. |
| `Config.BlipSprite` / `Config.BlipScale` | | Map blip settings. |
| `Config.Makeup` | | Makeup sliders (key, label, min, max, step). The server uses the same ranges to validate. |

### Adding a barbershop
Add an entry to `Config.BarberLocations`:
```lua
{
    name      = 'Rhodes',
    barberid  = 'rho-barber',                 -- unique id
    npcmodel  = `s_m_m_barber_01`,
    npccoords = vector4(x, y, z, heading),    -- barber NPC
    coords    = vector3(x, y, z),             -- interaction point
    seat      = vector4(x, y, z, heading),    -- chair the player sits in
    camPos    = vector3(x, y, z),
    camRot    = vector3(pitch, 0.0, yaw),
    lighting  = vector3(x, y, z),
    showblip  = true,
    price     = 8,                            -- optional
},
```

---

## 🧩 Events & callbacks
- NUI callbacks: `change`, `save`, `close` (every value is re-checked in Lua and again on the server).
- Client: `rsg-barbers:client:open` (`barberid`): opens the barber when the player is close. The old `rsg-barber:client:menu` still works for local triggers.
- Server callback: `rsg-barbers:server:purchase` (`barberid`, `selection`) returns `{ ok, reason }`.

---

## 💎 Credits
- **RexshackGaming / Rexshack-RedM**: resource and maintenance
- Humanity Is Insanity#3505 & Zee#2115 (The Crossroads RP): code inspiration
- Community translators

**License:** GPL-3.0

Support: https://buymeacoffee.com/rexshack
