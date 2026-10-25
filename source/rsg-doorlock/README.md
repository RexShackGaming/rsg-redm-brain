# rsg-doorlock

A database-driven door lock system for **RedM** using the **RSG Framework**. Doors are created, edited and deleted in game through an admin editor, synced to every player in real time, and logged to Discord.

---

## Features

### Door locks
- 🔒 Lock and unlock doors with a hold prompt and a key animation
- 🗄️ All doors are stored in the database (`rsg_doorlocks`), with no config editing needed
- 🔁 Lock states are saved and survive server restarts
- 🌐 Real-time sync, so every player sees the same state, including players who join late
- 🚪 Single and double doors (up to `Config.MaxDoorsPerLock` doors per lock)
- 👮 Job-based access, with optional on-duty requirement
- 🛡️ Admin bypass: admins can open any lock (optional)
- 🏛️ Sisika prison front gates locked by default

### Admin editor (`/doorlock`)
- 🖥️ NUI editor in the RDR2 black & white leather style
- 🔍 Searchable list of every lock (name, job or hash), sorted by nearest
- ➕ Create, ✏️ edit and 🗑️ delete locks without restarting the resource
- 🎯 **Point-and-select door picking**: aim at a door in the world and press ENTER
  - Top-left HUD shows the aimed door's model and hash, the selection count and the keys
  - Live feedback when doors are added or removed, plus a warning if a door already belongs to another lock
  - Lines drawn to the selected and aimed doors
  - Built-in list of ~1,750 RedM door hashes
  - **MLO door support**: add MLO door hashes to `shared/doorhashes_custom.lua`, or pick any door prop directly (it is frozen shut when locked)
- 📍 Teleport to any lock
- 🏷️ Job tag input, interaction range slider, default locked/unlocked state

### Security
- ✅ Everything is validated on the server: player, door, distance, job, permission and input data
- ⏱️ Server-side cooldown per player
- 🚫 Clients never decide the lock state; the server owns it
- 🧾 Admin actions are permission-checked and logged
- 🧩 A door can only belong to one lock; saving a duplicate is rejected with the name of the lock that owns it
- 🔢 Door hashes and coordinates are strictly validated (integers, finite values, map bounds)

### Discord webhooks
- Separate channels (or one default channel) for **Door use**, **Denied access**, **Admin actions**, **Security** and **System**
- Rich embeds with character name, citizen ID, job and grade, server ID, Discord mention and optional licence/Steam/IP
- Edit logs show a **before → after** list of changes
- Security alerts for likely cheaters (non-admin editor requests, fake doors, using doors from far away) with an optional role ping
- Rate-limit safe: batched messages, handling of Discord's 429 "too many requests" replies, and anti-spam throttles

### Performance
- Light 500ms loop, plus a per-frame loop **only** while a player stands at a door
- The door list is sent to clients once; the seed list is server-only

### Languages
`en`, `cs`, `de`, `el`, `es`, `fr`, `it`, `ja`, `nl`, `pl`, `pt-br`, `ro` (ox_lib locales: game text, editor UI **and** Discord logs)

---

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

---

## Installation

1. Download and place `rsg-doorlock` in your resources folder, e.g. `resources/[rsg]/rsg-doorlock`.
2. *(Optional)* Run `rsg_doorlocks.sql` on your database. The resource also creates the table automatically on first start.
3. Make sure the resource starts **after** its dependencies in your `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure rsg-core
   ensure rsg-doorlock
   ```
4. Set your language in `server.cfg` (ox_lib):
   ```cfg
   setr ox:locale en
   ```
5. *(Optional)* Add your Discord webhook URLs in `server/sv_config.lua`.
6. Start the server. On first start, the doors in `server/seed_doors.lua` (Valentine, Rhodes, Blackwater, Strawberry, Saint Denis and Sisika) are imported into the database **once**.

### Upgrading from 1.x (config-based)
Your old `Config.DoorList` doors now live in `server/seed_doors.lua` and are imported automatically when the `rsg_doorlocks` table is empty. After that, manage everything in game. Other resources that triggered the old `rsg-doorlock:updatedoorsv` / `rsg-doorlock:updateState` events need updating.

---

## Configuration

### `config.lua` (shared)

| Option | Default | Description |
|---|---|---|
| `Config.DefaultDistance` | `1.25` | Interaction range for new locks |
| `Config.DistanceTolerance` | `2.0` | Extra server-side leeway on the distance check (latency) |
| `Config.SyncDistance` | `30.0` | Doors within this range are kept in their synced state |
| `Config.Cooldown` | `1500` | Milliseconds between door uses per player (server enforced) |
| `Config.RequireOnDuty` | `false` | Player must be on duty to use job doors |
| `Config.AdminPermission` | `'admin'` | RSG permission for the editor (`god`, `developer`, `headadmin`, `admin`, `mod`) |
| `Config.AdminCommand` | `'doorlock'` | Command that opens the editor |
| `Config.AdminBypass` | `true` | Admins can open every lock, including ones with no jobs |
| `Config.MaxDoorsPerLock` | `8` | Maximum doors in a single lock |
| `Config.PickRange` | `2.0` | How close your aim must be to a door to select it |
| `Config.Debug` | `false` | Print MLO door lookups to the F8 console |
| `Config.AllowCustomDoors` | `true` | Allow picking door props that are not in the door hash lists (frozen-object fallback) |
| `Config.ImportConfigDoors` | `true` | Import `server/seed_doors.lua` when the table is empty |
| `Config.JailDoors` | Sisika gates | Door hashes that are always locked |

### `server/sv_config.lua` (server only, webhooks)

> ⚠️ This file contains your webhook URLs. Never move it to `shared_scripts`, and don't commit real URLs to a public repository.

```lua
SvConfig.Webhooks = {
    Enabled    = true,
    BotName    = 'Door Locks',
    AvatarUrl  = '',
    ServerName = 'RSG RedM',

    Urls = {
        Default  = 'https://discord.com/api/webhooks/...', -- used when a type below is empty
        DoorUse  = '',
        Denied   = '',
        Admin    = '',
        Security = '',
        System   = '',
    },

    Log = { DoorUse = true, Denied = true, Admin = true, Security = true, System = true },

    SecurityMention = '<@&ROLE_ID>', -- ping a role on security alerts ('' = off)
    DeniedThrottle  = 60,            -- seconds between Denied logs per player per door

    ShowLicense = true, ShowDiscord = true, ShowSteam = false, ShowIp = false,
}
```

### Locales
All text lives in `locales/*.json`. To change any wording, edit the key in your language file. To add a language, copy `en.json` to e.g. `sv.json`, translate the values (keep each `%s`), and set `setr ox:locale sv`.

### MLO doors
MLO doors are not in the built-in door list, so the editor can't find them until you add them.

1. **Preferred:** add the door's entry to `shared/doorhashes_custom.lua` in the usual door-hash format (most MLOs ship a door list like this):
   ```lua
   CustomDoorHashes = {
       [1651863461] = { 1651863461, -667091646, "p_door58x", -5528.4658, -2953.7189, -1.6969 },
   }
   ```
   Restart the resource. The door can now be picked in `/doorlock` and is locked by the game's door system, exactly like a vanilla door.
2. **Fallback:** if you have no door hash, aim at the door prop in pick mode. It's saved as **Custom door (MLO)** and frozen in its closed position when locked. **Pick it while the door is closed**, because that angle is what it's locked at. This only works for separate door props, not doors built into the MLO's fixed geometry.

---

## Usage

### Players
1. Walk up to a managed door. A **Door Status: Locked / Unlocked** prompt appears.
2. **Hold ENTER** to lock or unlock it. Your character uses a key and you get a confirmation notification.
3. You need one of the lock's authorised jobs (and to be on duty, if `RequireOnDuty` is on).

### Admins: creating a lock
1. Type **`/doorlock`** to open the editor.
2. Click **+ New Lock**.
3. Enter a **name**, add **jobs** (type a job, press Enter), set the **interaction range** and the **starting state**.
   - Leave jobs empty to make a door nobody can open (e.g. prison doors).
4. Click **Select doors in world**. The editor hides and the HUD appears top-left:
   - **Aim** at a door and its model and hash show in the HUD.
   - **ENTER**: add or remove the aimed door
   - **BACKSPACE**: finish and return to the editor
   - For double doors, add **both** sides.
5. Click **Save**. The lock is live for everyone immediately.

### Admins: managing locks
- **Edit**: click a lock in the list, change anything (including reselecting doors), then **Save**.
- **Delete**: open a lock, click **Delete** and confirm. Its doors are unlocked for everyone.
- **Teleport**: click the ➤ button on a lock row.
- **Search**: filter by name, job or door hash.
- **ESC**: steps back (modal → form → list → close).

---

## Exports / events

| Event | Side | Description |
|---|---|---|
| `rsg-doorlock:client:setState` (`doorId`, `locked`) | client | Fired to all clients when a door changes state |
| `rsg-doorlock:client:syncDoor` (`id`, `door`, `old`) | client | Fired when an admin creates, edits or deletes a lock |

---

## Credits
- Door hash data: [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries)
- RSG Framework: [Rexshack-RedM](https://github.com/Rexshack-RedM)

---

## Support

If you find this resource useful, consider supporting development:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/rexshack)

☕ **https://buymeacoffee.com/rexshack**
