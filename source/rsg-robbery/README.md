# rsg-robbery

Player-to-player robbery system for RedM / RSG Core.

---

## For Players

### How to rob another player


 **Approach** a player and get close (within ~2.5m)
 **Target them** using the third-eye targeting system (press the target key) they need to have hands up
 Select the **"Rob"** option from the targeting 
 Their **inventory opens** on your screen — drag items from their slots to yours
 Walk away — the target stays **cuffed** state then goes back to handsup when inventory closes 

### What you need



| Distance | Within ~2.5m of the target |
| Target state | Not already cuffed, not in a vehicle |

### What happens to your victim

- They get **cuffed** (can't move, can't fight, can't use items)
- They see a notification: *"You are being robbed!"*
- Their inventory is opened on **your screen**
- They remain cuffed until:
  - The auto-uncuff timer expires (default: 2 minutes, configurable)
  - A lawman uncuffs them
  - Someone uses `/uncuff` command or targets them 



## For Server Owners

### Installation

1. Place `rsg-robbery` in your `resources/[test]` folder
2. **Modify `rsg-inventory`** — edit `[framework]/rsg-inventory/server/events/events.lua`:
   ```lua
   -- Line ~181 — BEFORE:
   if not hasPerm and not targetMeta.isdead then
   
   -- Line ~181 — AFTER:
   if not hasPerm and not targetMeta.isdead and not targetMeta.ishandcuffed then
   ```
   This allows **any player** to take items from a **cuffed** target (not just police).
3. Ensure all dependencies are started before `rsg-robbery`:
   ```cfg
   ensure rsg-core
   ensure rsg-target
   ensure rsg-inventory
   ensure rsg-robbery
   ```
4. Restart your server or start the resource

### Dependencies

| Resource | Required | Notes |
|----------|----------|-------|
| `rsg-core` | Yes | Framework |
| `rsg-inventory` | Yes | Must apply the 1-line fix above |
| `rsg-target` | Yes | Player targeting (replaces ox_target) |

### Configuration

Edit `shared/config.lua`:

Language is set with the `rsg:locale` convar (e.g. `setr rsg:locale de`). Included: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru.

```lua
Config = Config or {}

Config.RobDistance = 2.5           -- Max distance to rob
Config.CuffDistance = 1.5          -- Max distance to cuff
Config.RobCooldown = 30000         -- Cooldown between robberies (ms)
Config.AutoUncuffTime = 120000     -- Auto-uncuff after ms (0 = disable)
```


### Uninstallation

1. Remove `rsg-robbery` from your resources folder
2. Revert the 1-line change in `rsg-inventory/server/events/events.lua`:
   ```lua
   -- Change back to:
   if not hasPerm and not targetMeta.isdead then
   ```
3. Remove `ensure rsg-robbery` from your `server.cfg`

---

## How It Works

```
Player targets victim via rsg-target
        │
        ▼
Select "Rob" option
        │
        ▼
Server checks: has handsup? target not cuffed? distance OK?
        │
        ▼
Server cuffs target (sets metadata + client effects)
        │
        ▼
Server opens target's inventory for robber via rsg-inventory
        │
        ▼
Robber drags items from target to their own inventory
```

The 1-line rsg-inventory change is required because normally only police (job = police/marshal) can take items from a living cuffed player. The change adds `and not targetMeta.ishandcuffed` to the permission check, meaning any player can take items from a cuffed target.


---

☕ Support the Project : https://rexshack.tebex.store/
