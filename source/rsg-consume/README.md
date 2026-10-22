<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🍞 rsg-consume
**Universal consumption system for RedM using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> Immersive eating and drinking system for RedM servers built on RSG Core.  
> Adds configurable hunger, thirst, alcohol and stress effects with synchronized animations and props.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠  
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️ *(notifications, locales)*  
- [**rsg-inventory**](https://github.com/Rexshack-RedM/rsg-inventory) 🎒 *(item use integration)*  

**Locales:** `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`  
**License:** GPL‑3.0  

---

## ✨ Features

### 🍴 Consumable Categories
| Category | Animation | Prop |
|----------|-----------|------|
| `Eat` | hand-held bite | `propname` per item |
| `Drink` | uncork + chug (quick sip when mounted) | `propname` per item |
| `Stew` | bowl + spoon interaction | fixed bowl & spoon |
| `Hotdrinks` | mug hold & sip | fixed coffee mug |
| `Eatcanned` | eat from can | `propname` per item |

- Every item in `shared/config.lua` is registered as **usable** automatically (missing shared items are skipped with a console warning).
- Each item can change **hunger**, **thirst**, **stress** and **alcohol**, and optionally return an item (`giveItem`, e.g. `emptybottle`).

### 🍺 Alcohol System
- Alcoholic drinks raise an alcohol level; food and soft drinks can lower it (negative `alcohol`).
- Above `DrunkThreshold` → drunk walk + screen effect.
- Above `PassOutThreshold` → vomit, pass out, wake up with a hangover.
- Level drops by `DecreaseAmount` every `DecreaseInterval` ms.

### 🔒 Security
- Items are removed **server-side** before the animation plays.
- Return items are only given once per real consumption (one-time server token) — the return event can't be spammed.
- If the client can't play the consume (already busy, passed out, dead) the item is refunded instead of lost.

---

## ⚙️ Configuration (`shared/config.lua`)
```lua
Consumables = {
    Drink = {
        ['water'] = {
            hunger = 0,     -- added to hunger (0-100), can be negative
            thirst = 25,    -- added to thirst (0-100), can be negative
            stress = 5,     -- positive relieves stress, negative adds stress
            alcohol = -5,   -- positive gets you drunk, negative sobers you up
            propname = 'p_bottlebeer01a_1',
            giveItem = 'emptybottle', -- optional item returned after drinking
        },
    },
},

AlcoholSystem = {
    DrunkThreshold = 50,
    PassOutThreshold = 200,
    DecreaseAmount = 1,
    DecreaseInterval = 5000,
    MaxAlcoholLevel = 500,
},
```
`AlcoholEffects` controls the post-fx names and the vomit / sleep / fade / hangover timings.

### 🔌 Integration
Other resources can react to consumption on the client:
```lua
AddEventHandler('rsg-consume:client:onConsume', function(data)
    -- data = the item's config entry (hunger, thirst, stress, alcohol, ...)
end)
```

---

## 🍽️ Item Examples (RSG Inventory)

```lua
bread   = { name = 'bread',   label = 'Bread',              weight = 100, type = 'item', image = 'consumable_bread_roll.png',    unique = false, useable = true, decay = 300, delete = true, shouldClose = true, description = 'A fresh piece of bread' },
water   = { name = 'water',   label = 'Water Bottle',       weight = 100, type = 'item', image = 'consumable_water_bottle.png',  unique = false, useable = true, decay = 300, delete = true, shouldClose = true, description = 'Fresh water to quench your thirst' },
whiskey = { name = 'whiskey', label = 'Whiskey Bottle',     weight = 150, type = 'item', image = 'consumable_whiskey_bottle.png',unique = false, useable = true, decay = 300, delete = true, shouldClose = true, description = 'A strong whiskey that warms you up and goes straight to your head' },
stew    = { name = 'stew',    label = 'Bowl of Stew',       weight = 200, type = 'item', image = 'consumable_stew.png',          unique = false, useable = true, decay = 300, delete = true, shouldClose = true, description = 'A hot, hearty bowl of stew' },
coffee  = { name = 'coffee',  label = 'Cup of Coffee',      weight = 80,  type = 'item', image = 'consumable_coffee.png',        unique = false, useable = true, decay = 300, delete = true, shouldClose = true, description = 'A strong black coffee to wake you up' },
```

---

## 📂 Installation
1. Place `rsg-consume` inside your `resources/[rsg]` folder.  
2. Ensure `rsg-core`, `rsg-inventory`, and `ox_lib` are installed.  
3. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-consume
   ```
4. Restart your server.

---

## 🌍 Locales
Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`  
Loaded automatically with `lib.locale()`.

---

## 💎 Credits
- **RSG / Rexshack-RedM** — base framework & design  
- Original concept and effects adapted by **Rexshack Dev Team**  
- Alcohol system logic added by **Suu** → [github.com/suu-yoshida](https://github.com/suu-yoshida)  
- Community testers and translators  
- License: GPL‑3.0  

---

## ☕ Support
If you enjoy this script, you can support development here: [buymeacoffee.com/rexshack](https://buymeacoffee.com/rexshack)
