# rsg-telephone

Persistent telephone props with private voice calls for the RSG Framework (RedM). **Version 3.1.0**

Admins place wall or desk phones that survive restarts; each phone gets a number. Players dial from a phone (keypad or directory), the far phone rings for anyone nearby, and answering opens a private voice line between the two callers. Public phones work as coin-operated payphones, and phones can be reserved for a job.

**Full developer and server-owner reference:** [DOCS.md](DOCS.md)

## Features

- Admin-placed, persistent phone props (wall or antique desk) with interior room support
- Placement through **rsg-gizmo** (free/fine modes, valid/invalid ring, precision controls)
- NUI telephone: keypad with rotary dial clicks, searchable directory, call timer
- Private voice line over Mumble – no pma-voice / saltychat needed
- Antique sounds generated in the page (no sound files): mechanical two-gong bell, buzzy ringback with line hiss
- Directional ringing: stereo panned from your camera, fades with distance, muffled behind walls
- Payphones: insert coins, charged per minute, unused credit refunded
- Job-restricted phones (e.g. only `medic` can call out; anyone can call in)
- Multijob support: a phone matches any job name or job type the character holds
- Map blips (`blip_ambient_telegraph`) named after each phone
- Player-owned telephones from a usable `telephone` item – place, change settings, pick up and re-place with the same number
- Admin panel (`/phoneadmin`) to manage, edit, teleport to and delete every phone
- Admin directory controls: hide / show any phone from the directory
- RDR2 leather & gold UI, rsg-core notifications, full JSON locales
- No ox_lib required

## Requirements

- rsg-core
- rsg-inventory
- rsg-target
- rsg-gizmo
- oxmysql

## Installation

1. Add the `telephone` item to `rsg-core/shared/items.lua` (see [Item definition](#item-definition)) and add it to a shop so players can buy it.
2. Copy `installation/images/telephone.png` to `rsg-inventory/html/images`.
3. Drop `rsg-telephone` into your resources.
4. Add it to `server.cfg` after its dependencies:

```cfg
ensure rsg-core
ensure oxmysql
ensure rsg-inventory
ensure rsg-target
ensure rsg-gizmo
ensure rsg-telephone
```

5. The `rsg_telephones` table is created and upgraded automatically on start (MySQL and MariaDB). To manage the schema yourself, set `Config.AutoDatabase = false` and import `installation/install.sql`.
6. Adjust `shared/config.lua`.
7. Set the language in `server.cfg` (see [Locales](#locales)):

```cfg
setr rsg:locale "en"
```

### Item definition

`installation/shared_items.lua` contains the item entry for `rsg-core/shared/items.lua`:

```lua
telephone = { name = 'telephone', label = 'Telephone', weight = 1000, type = 'item', image = 'telephone.png', unique = true, useable = true, shouldClose = true, description = 'A telephone you can install anywhere', category = 'tools' },
```

`unique = true` keeps each picked-up phone's number on its own item.

## Configuration

All options live in `shared/config.lua`. Values are validated and clamped at startup so a bad entry cannot break the resource.

| Option | Default | Description |
|---|---|---|
| `Config.Models` | wall / desk | Props an admin can choose |
| `Config.SpawnDistance` | `75.0` | Props stream in/out around the player |
| `Config.UseDistance` | `2.0` | rsg-target interaction distance |
| `Config.PlaceDistance` | `6.0` | rsg-gizmo placement range |
| `Config.AutoDatabase` | `true` | Create and upgrade the table on start; `false` = import `installation/install.sql` |
| `Config.Payphone.Enabled` | `true` | Turn payphone charging on/off globally |
| `Config.Payphone.MoneyType` | `cash` | Money account charged (`cash`, `bank`, `gold`, `bloodmoney`) |
| `Config.Payphone.CostPerMinute` | `0.10` | Dollars charged per minute |
| `Config.Payphone.MaxDeposit` | `5.00` | Most a caller can insert for one call |
| `Config.Payphone.Coins` | `0.05, 0.10, 0.25, 1.00` | Coin buttons on the phone screen |
| `Config.Payphone.WarnSeconds` | `15` | Warn this long before credit runs out |
| `Config.Item.Enabled` | `true` | Enable the player-owned telephone item |
| `Config.Item.Name` | `telephone` | Inventory item name |
| `Config.Item.MaxPerPlayer` | `2` | Phones a character can have placed at once |
| `Config.Item.Payphone` | `false` | Make player-owned phones payphones too |
| `Config.Blip.Enabled` | `true` | Map blip on every placed phone |
| `Config.Blip.Sprite` | `blip_ambient_telegraph` | Blip sprite |
| `Config.Blip.Scale` | `0.2` | Blip scale |
| `Config.MaxCallDistance` | `3.0` | Walk further than this from your phone and the call ends |
| `Config.RingDistance` | `25.0` | How far the bell can be heard |
| `Config.RingTimeout` | `30` | Seconds before an unanswered call gives up |
| `Config.MaxCallLength` | `600` | Seconds, `0` = unlimited |
| `Config.CallCooldown` | `5` | Seconds between dial attempts per player |
| `Config.NumberLength` | `4` | Digits in auto-generated numbers (2–16) |
| `Config.Voice` | see below | Mumble voice target settings |
| `Config.AdminPermission` | `admin` | rsg-core permission for admin commands and callbacks |

### Voice

| Option | Default | Description |
|---|---|---|
| `Config.Voice.Target` | `4` | Mumble voice target slot used during a call (1–30, keep clear of other voice scripts) |
| `Config.Voice.DefaultTarget` | `0` | Target restored after the call (`0` = normal proximity; rsg-voice / saltychat setups may use `1`) |
| `Config.Voice.KeepProximity` | `true` | People next to you still hear you while you are on the phone |
| `Config.Voice.Volume` | `1.0` | Volume of the person on the other end |
| `Config.Voice.Refresh` | `1000` | Milliseconds between re-applying the voice target |

If you also run pma-voice or another voice script, set `Config.Voice.DefaultTarget` to the target it uses (pma-voice = `1`) and keep `Config.Voice.Target` on a free slot.

## How to use

### Placing a phone

`/addphone` (admins) or using the `telephone` item (players) opens the placement form. The prop is then placed with **rsg-gizmo**:

| Key | Action |
|---|---|
| LMB / Enter | Place |
| RMB / Backspace | Cancel |
| R | Switch Free / Fine mode |
| Mouse wheel | Free: turn · Fine: height |
| Arrows | Free: ←/→ turn · Fine: move relative to camera |
| Shift (hold) | Rotate with arrows/wheel (↑/↓ tilts when rotation = `all`) |
| Ctrl (hold) | Precision |
| G | Snap to ground |
| Q | Reset tilt |

While placing, `LocalPlayer.state.gizmoActive` is `true` so voice and other input scripts can stand down.

### Making a call

1. Target a phone → **Make Call**, then dial a number or pick an entry from the directory and press **Call** (or Enter).
2. The caller hears a ringback tone; the destination phone rings for anyone within `Config.RingDistance`.
3. Someone targets the ringing phone → **Answer Phone**. Each player's mic is routed to the other at full volume, regardless of distance.
4. Either player presses **End Call** (or Esc). Calls also end if a player walks away from their phone, disconnects, the ring times out, the call reaches `Config.MaxCallLength`, the phone is deleted, or payphone credit runs out.

### Directory

The directory lists every placed phone with **Show in directory** ticked. Admins also see hidden phones (marked **Hidden**) and can remove (✕) or re-add (✓) any entry from the directory tab.

### Payphones

A phone with **no job restriction** is a payphone (unless it is player-owned and `Config.Item.Payphone = false`).

- Before dialling, the caller inserts coins on the phone screen (up to `MaxDeposit`); **Return** clears them.
- The money is taken when the call is placed – only after every other check passes.
- Each minute is charged once the call is answered (the first minute on answer). Remaining credit is shown on screen.
- The caller is warned `WarnSeconds` before credit runs out; the call ends when it does.
- Unused credit is returned when the call ends; unanswered calls are refunded in full. Receiving calls is free.
- If the caller disconnects mid-call, the refund goes to their character in the database.

Set `Config.Payphone.Enabled = false` to make every phone free.

### Job phones

Give a phone a job (in the admin form or with `/phonejob`) and only players whose job **type** or **name** matches can make calls from it – others don't see **Make Call** and the server rejects them. Every job the character holds is checked (rsg-core multijob). Anyone can still call the phone and answer it. Job phones are free to use.

### Player telephones (item)

1. **Use** the item → fill in the form (label, prop, show in directory). The number is assigned automatically.
2. Place the prop with rsg-gizmo. The item is removed once the phone is placed.
3. At their own phone the owner gets two extra target options:
   - **Phone Settings** – change the label and directory listing.
   - **Pick Up Phone** – removes the phone from the world and gives the item back. The item keeps the phone's ID, number and label.
4. Using that item again skips the form and places the **same phone** – same number, label, prop and listing.

Notes:

- `Config.Item.MaxPerPlayer` limits how many phones a character has **placed** at once. Picked-up phones don't count, so a lost or sold item never blocks its old owner.
- Player phones are free private lines by default (`Config.Item.Payphone = false`); set it to `true` to make them payphones too.
- A picked-up phone's number stays reserved, so nobody else can take it. Calling it says the number doesn't exist until it is placed again.
- Whoever holds a picked-up telephone item can place it and becomes the new owner – so the item can be sold or given away with its number.
- The server checks the item is still in the slot it was used from before placing, and gives it back if placing fails.
- Admins see owned phones tagged **owned** in `/phoneadmin`. Picked-up phones are listed as **Picked up** and can be deleted to free their number (the item then places as a brand-new phone).

## Admin commands

All commands use `Config.AdminPermission` (default `admin`) and are re-checked on the server.

| Command | What it does |
|---|---|
| `/phoneadmin` | Opens the Telephone Exchange admin panel |
| `/addphone` | Opens the telephone form (label, prop, number – blank = random, job, directory listing), then the rsg-gizmo placement |
| `/removephone` | Deletes the nearest phone; any call on it ends and is refunded |
| `/phonejob [job]` | Restricts the nearest phone to a job type/name; blank = anyone |
| `/phoneinfo` | Shows the nearest phone's ID, number, label and job / payphone status |

### Admin panel (`/phoneadmin`)

- Searchable list of all phones with number, job / payphone / owned / hidden tags and a live status light (idle, ringing, on a call, picked up – refreshes every 5 seconds)
- Edit label, number, job, prop and directory listing, then **Save** – changes apply to every player instantly (props respawn if the model changes)
- **Teleport** to a phone, set a **Waypoint** to it, or **End Call** on a phone that is in use (the caller is refunded)
- **Delete** a phone (with confirmation) or **+** to place a new one
- Every action is re-checked against `Config.AdminPermission` on the server

## Developer examples

This resource does not expose its own exports; other resources can open the admin panel or read item metadata through the standard RSG APIs:

```lua
-- server: open the Telephone Exchange for a player (permission is re-checked by the callbacks)
TriggerClientEvent('rsg-telephone:client:openAdmin', src)

-- server: read the phone number stored on a picked-up telephone item
local item = exports['rsg-inventory']:GetItemBySlot(src, slot)
local number = item and item.info and item.info.number
```

See [DOCS.md](DOCS.md) for the full event, callback, data-format and security reference.

## Locales

Every player-facing string – notifications, target labels, commands, the phone screen, forms and admin panel – comes from `locales/*.json`, nothing is hard-coded. The locale is loaded by rsg-core from:

```cfg
setr rsg:locale "en"
```

Included languages: English (`en`), German (`de`), Greek (`el`), Spanish (`es`), French (`fr`), Japanese (`ja`), Dutch (`nl`), Polish (`pl`), Brazilian Portuguese (`pt-br`) and Romanian (`ro`).

To add another language, copy `en.json` to `locales/<code>.json` and translate the values (keep the keys and every `%s`).

---

Support: https://buymeacoffee.com/rexshack
