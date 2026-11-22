<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🔐 rsg-lockpick
**Lockpicking minigame for RedM (RSG Core).**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> A lightweight NUI lockpicking game (pick + cylinder) you can start from any script, with an optional **server-issued attempt** mode that adds lock presets, skill-based difficulty, lockpick wear and breakage, and lawman alerts. Version 3.1.0 · full developer reference in [DOCS.md](DOCS.md).

---

## 🛠️ Dependencies
- **rsg-core** (framework, also provides the locale loader)
- **rsg-inventory** (lockpick item, quality and wear)
- *Optional:* **rsg-skills** (lockpicking skill and perks), **rsg-reputation** (honor and standing for crimes) and **rsg-lawman** (alerts). All are detected at runtime and simply skipped when not running.

No ox_lib, no database, no external web assets: the UI is fully bundled (only the Roboto font is loaded from Google Fonts, with a system fallback).

---

## ✨ Features
- 🎮 **NUI minigame** in the house leather-and-gold style (SVG lock, no jQuery/GSAP/CDN images).
- 🔁 **Three client APIs**: the original event (backward compatible), a blocking export, or a callback.
- 🛡️ **Server-issued attempts** (`StartAttempt`): the server picks the difficulty, validates the result (ticket, timing, distance) and applies the consequences.
- 🎚️ **Lock presets** `easy` / `medium` / `hard`, plus per-call overrides, all clamped to safe limits.
- 🕵️ **Reputation**: a calling script can report a successful pick as `theft` or `robbery` (optionally in a town), and rsg-reputation applies the honor and standing change.
- 🧠 **Skill-based difficulty** through rsg-skills: wider sweet spot, less pick damage and extra picks as the *lockpicking* skill levels up, plus XP for each attempt.
- 🔧 **Lockpick wear**: the item loses quality with use, a worn pick takes more damage, and a failure can destroy it.
- 🚨 **Lawman alert**: on-duty lawmen can be alerted after an attempt (chance-based, per-call override).
- ⏱️ **Optional timer**, **sound feedback** and an **optional animation**.
- 🕹️ **Gamepad support** in the UI, plus mouse / wheel / keyboard.
- 🗣️ **Push-to-talk keeps working** while the minigame is open (configurable).
- 🧹 **Safe lifecycle**: one attempt at a time, cancelled on death, disconnect, timeout or resource stop; callers always get a result.
- 🌍 **Locales**: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru.

---

## 📂 Installation
1. Place `rsg-lockpick` in `resources/[rsg]`.
2. Make sure the `lockpick` item exists in your shared items (or change `Config.Item.Name`).
3. In your `server.cfg`:
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-skills      # optional
   ensure rsg-lockpick
   ```
4. Restart your server. No database setup is needed.
5. *(Optional)* To show readable perk names in the rsg-skills panel, add these keys to rsg-skills' locales: `perk_lockpick_sweet_spot`, `perk_lockpick_pick_damage`, `perk_lockpick_extra_pick`.

---

## ⚙️ Configuration (`shared/config.lua`)
| Option | Default | Description |
|---|---|---|
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk usable while the UI has focus; all other controls are blocked |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the UI is open |
| `CursorStart` | `{ x = 0.5, y = 0.5 }` | Cursor position when the UI opens |
| `Controller` | `true` | Gamepad input in the UI |
| `MinSolveTime` | `1000` | Client: a solve reported faster than this (ms) is a failure |
| `ResultDelay` | `700` | Pause (ms) so the player sees "Unlocked" / "Pick broken" |
| `Defaults.*` | see file | `pins`, `pinDamage`, `damageInterval`, `solvePadding`, `maxDistFromSolve`, `mouseSmoothing`, `turnSpeed`, `timeLimit` |
| `Presets` | easy / medium / hard | Named difficulty sets (only changed keys listed) |
| `Limits` | see file | Min/max clamp for every value that reaches the UI |
| `Sounds` | enabled | Sound set and name per event (`turn`, `jam`, `brk`, `unlock`) |
| `Animation` | **off** | Optional pick animation (untested, see below) |
| `Server.TicketTTL` | `180000` | ms a server-issued attempt stays valid |
| `Server.MinSolveTime` | `1500` | Server clock: faster solves count as failures |
| `Server.Cooldown` | `2000` | ms between attempts per player |
| `Server.DefaultRadius` / `DistanceSlack` | `5.0` / `2.0` | Distance rules when `data.coords` is given |
| `Item.*` | enabled, `lockpick` | Item name, require it, damage scaling by quality, wear on success / failure, break chance |
| `Skill.*` | enabled, `lockpicking` | rsg-skills skill name, XP per attempt, perk definitions |
| `Reputation.*` | enabled | rsg-reputation: allowed actions (`theft`, `robbery`) and an optional default action for successful attempts |
| `Alert.*` | enabled | Job type, chance on success / failure, minimum gap |

---

## 🎮 How to play
- Move the **mouse** (or the **wheel**, **Q / E**, or the **left stick / D-pad**) to rotate the pick.
- Hold **left click, Space, W/A/S/D, the arrow keys, or A / a trigger on a gamepad** to turn the lock.
- The closer the pick is to the hidden sweet spot, the further the cylinder turns. If it jams, the pick takes damage and eventually breaks.
- Turn the cylinder all the way to unlock. **Esc**, **Backspace**, **B** or the ✕ button cancels (a cancel never wears the lockpick).

---

## 🧑‍💻 Usage (from code)

### Server-issued attempt (recommended for anything with a reward)
```lua
-- server side, after YOUR script's own checks (job, state, etc.)
local started, ticketOrReason = exports['rsg-lockpick']:StartAttempt(src, {
    preset = 'hard',                              -- easy | medium | hard (optional)
    options = { pins = 2 },                       -- optional overrides
    coords = vector3(x, y, z), radius = 3.0,      -- optional: player must stay near this point
    alert = 0.8,                                  -- optional: lawman alert chance, or false for none
}, function(success, reason)
    -- runs on the server with the VALIDATED result
    if success then
        -- open the door / give the loot
    end
end)
```

### Client-only
```lua
-- 1) Event with callback (original API; options and preset are optional)
TriggerEvent('rsg-lockpick:client:openLockpick', function(success, outcome)
    -- outcome: 'success' | 'fail' | 'cancel'
end, { preset = 'easy' })

-- 2) Blocking export (call from a thread or event handler)
local success, outcome = exports['rsg-lockpick']:Lockpick({ pins = 3 })

-- 3) Helpers
exports['rsg-lockpick']:IsLockpicking()
exports['rsg-lockpick']:CancelLockpick()
```

> ⚠️ A client-only result can be faked by a modified client. For doors, containers, banks and anything with a reward, use `StartAttempt` and act only on its server callback. See the security model in [DOCS.md](DOCS.md).

---

## 🧪 Notes on unverified in-game behaviour
- **Sounds** use sets from the RDR3 audio data (`RDRO_Safecracking_Sounds`, `UTP2_Sounds`, `Mud5_Sounds`). If one is silent on your build, change it in `Config.Sounds`.
- **Animation** is disabled by default: the `lockpick` clip is a door-handle animation and has not been tested in-game here. Set `Config.Animation.Enabled = true` and check it looks right.
- **Gamepad** uses the browser Gamepad API with the standard layout; it has not been tested on a physical pad here.

---

## 🧩 Files
- `fxmanifest.lua`: manifest, locale loader, UI files
- `shared/config.lua`: all settings and the shared option builder
- `client/main.lua`: NUI focus, client API, server-attempt handling, sounds, animation, cleanup
- `server/main.lua`: `StartAttempt`, ticket validation, wear, rsg-skills, lawman alerts
- `html/`: `index.html`, `style.css`, `script.js` (game logic and SVG lock)
- `locales/*.json`: 11 translations

---

## 💎 Credits
- **qbcore‑redm‑framework**: original resource  
  🔗 https://github.com/qbcore-redm-framework
- **QRCore‑RedM‑Re**: convert and rework  
  🔗 https://github.com/QRCore-RedM-Re
- **RSG / Rexshack‑RedM**: adaptation & maintenance  
  🔗 https://github.com/Rexshack-RedM
- **Community contributors & translators**
- License: GPL‑3.0

Support: https://rexshack.tebex.store  
☕ Buy me a coffee: https://buymeacoffee.com/rexshack
