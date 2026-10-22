<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🔐 rsg-lockpick
**Simple lockpicking minigame for RedM (RSG Core).**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> A lightweight NUI lockpicking game (pin + cylinder) you can invoke from any script and receive a success/failure callback.

---

## 🛠️ Dependencies
- **rsg-core** (framework)  
- **NUI** (HTML/CSS/JS bundled with the resource)

**License:** GPL‑3.0

---

## ✨ Features
- 🎯 **Client-only minigame** with clean NUI (HTML/CSS/JS).  
- 🔁 **Callback-based API** — open the minigame and get `true/false` on completion.  
- 🖱️ **Mouse rotation** for the pick, **keyboard press** to push the cylinder.  
- ⚙️ Self-contained UI (`ui_page 'html/index.html'`).

---

## ⚙️ Usage (from code)
Trigger the client event **`rsg-lockpick:client:openLockpick`** from your resource and pass a callback to receive the result:

```lua
-- client.lua (your resource)
RegisterCommand('trylock', function()
    TriggerEvent('rsg-lockpick:client:openLockpick', function(success)
        if success then
            print('Lockpick: success!')
            -- proceed with your success logic
        else
            print('Lockpick: failed.')
            -- e.g. consume item, break lockpick, alert guards, etc.
        end
    end)
end)
```

**What the event does**
```lua
-- from this resource (client/main.lua)
AddEventHandler('rsg-lockpick:client:openLockpick', function(callback)
    lockpickCallback = callback
    openLockpick(true)
end)

RegisterNUICallback('callback', function(data, cb)
    openLockpick(false)
    lockpickCallback(data.success) -- true/false
    cb('ok')
end)
```

---

## 🎮 Controls
- Move the **mouse** left/right to **rotate the pick** (pin).  
- Press **W/A/S/D or Arrow keys** to **push the cylinder**.  
- The goal is to find the **correct angle** and push without breaking the pin.

*(Controls mapped in `html/script.js`: mouse movement & keydown handlers.)*

---

## 📂 Installation
1. Place `rsg-lockpick` in `resources/[rsg]`.  
2. In your `server.cfg`:
   ```cfg
   ensure rsg-core
   ensure rsg-lockpick
   ```
3. Restart your server.

---

## 🧩 Files
- `fxmanifest.lua` — defines `ui_page`, client script & asset list.  
- `client/main.lua` — NUI focus, open/close, and result callback.  
- `html/index.html`, `html/style.css`, `html/script.js`, `html/reset.css` — UI and game logic.

---

## 💎 Credits
- **qbcore‑redm‑framework** — original resource  
  🔗 https://github.com/qbcore-redm-framework  
- **QRCore‑RedM‑Re** — convert and rework  
  🔗 https://github.com/QRCore-RedM-Re  
- **RSG / Rexshack‑RedM** — adaptation & maintenance  
  🔗 https://github.com/Rexshack-RedM  
- **Community contributors & translators**  
- License: GPL‑3.0
