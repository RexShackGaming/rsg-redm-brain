# rsg-telephone

Persistent telephone props for the RSG Framework (RedM). Admins place wall or desk phones that survive restarts; each phone gets a number. Players dial from a phone (keypad or directory), the far phone rings for anyone nearby, and answering opens a private voice line between the two callers. Public phones work as coin-operated payphones, and phones can be reserved for a job.

## Features
- Admin-placed, persistent phone props (wall or antique desk) with interior room support
- NUI telephone: keypad with rotary dial clicks, searchable directory, call timer
- Private voice line over Mumble – no pma-voice / saltychat needed
- Antique sounds generated in the page (no sound files): mechanical two-gong bell, buzzy ringback with line hiss
- Directional ringing: stereo panned from your camera, fades with distance, muffled behind walls
- Payphones: insert coins, charged per minute, unused credit refunded
- Job-restricted phones (e.g. only `medic` can call out; anyone can call in)
- Map blips (`blip_ambient_telegraph`) named after each phone
- Player-owned telephones from a usable `telephone` item – place, change settings, pick up and re-place with the same number
- Admin panel (`/phoneadmin`) to manage, edit, teleport to and delete every phone
- Admin directory controls: hide / show any phone from the directory
- RDR2 leather & gold UI, ox_lib notifications, full JSON locales

## Requirements
- rsg-core
- ox_lib
- ox_target
- oxmysql

## Install
1. Add the `telephone` item to `rsg-core/shared/items.lua` (see below) and add it to a shop so players can buy it.
2. Drop `rsg-telephone` into your resources and add `ensure rsg-telephone` after the dependencies.
3. Run `install.sql` (optional – the table is created and upgraded automatically on start, on both MySQL and MariaDB).
4. Adjust `shared/config.lua`.

## Admin commands
Uses `Config.AdminPermission` (default `admin`).

| Command | What it does |
|---|---|
| `/phoneadmin` | Opens the Telephone Exchange admin panel (see below) |
| `/addphone` | Opens the telephone form (label, prop, number – blank = random, job, directory listing), then place the ghost prop |
| `/removephone` | Deletes the nearest phone (within 3 m); any call on it ends and is refunded |
| `/phonejob [job]` | Restricts the nearest phone so only that job type/name can make calls from it; blank = anyone |
| `/phoneinfo` | Shows the nearest phone's ID, number, label and job / payphone status |

### Admin panel (`/phoneadmin`)
A full NUI to manage every phone on the server:
- Searchable list of all phones with number, job / payphone / owned / hidden tags and a live status light (idle, ringing, on a call, picked up – refreshes every 5 s)
- Edit label, number, job, prop and directory listing, then **Save** – changes apply to every player instantly (props respawn if the model changes)
- **Teleport** to a phone, set a **Waypoint** to it, or **End Call** on a phone that's in use (the caller is refunded)
- **Delete** a phone (with confirmation) or **+** to place a new one
- Every action is re-checked against `Config.AdminPermission` on the server

### Placement controls
A panel in the top-left lights up each key as you press it and shows heading, height and distance.

| Key | Action |
|---|---|
| ← / → | Rotate |
| ↑ / ↓ | Raise / lower |
| E / Q | Move forward / back (away from / towards the camera) |
| Enter | Place |
| Backspace | Cancel |

## Player telephones (item)
Players can buy the `telephone` item (sell it in any shop) and place their own phone.

1. **Use** the item → fill in the form (label, prop, show in directory). The number is assigned automatically.
2. Place the ghost prop with the same keys as admins. The item is removed from the inventory once the phone is placed.
3. At their own phone the owner gets two extra target options:
   - **Phone Settings** – change the label and directory listing.
   - **Pick Up Phone** – removes the phone from the world and gives the item back. The item keeps the phone's ID, number and label.
4. Using that item again skips the form and places the **same phone** – same number, label, prop and listing.

Notes
- `Config.Item.MaxPerPlayer` limits how many phones a character can have **placed** at once. Picked-up phones don't count, so a lost or sold item never blocks its old owner.
- Player phones are free private lines (`Config.Item.Payphone = false`); set it to `true` to make them payphones too.
- A picked-up phone's number stays reserved, so nobody else can take it. Calling it says the number doesn't exist until it's placed again.
- Whoever holds a picked-up telephone item can place it and becomes the new owner – so the item can be sold or given away with its number.
- The server checks the item is still in the slot it was used from before placing, and gives it back if placing fails.
- Admins see owned phones tagged **owned** in `/phoneadmin` and can edit or delete them. Picked-up phones are listed as **Picked up** and can be deleted to free their number (the item then places as a brand-new phone).

### Item definition (`rsg-core/shared/items.lua`)
```lua
telephone = { name = 'telephone', label = 'Telephone', weight = 2000, type = 'item', image = 'telephone.png', unique = true, useable = true, shouldClose = true, description = 'A telephone you can install anywhere' },
```
`unique = true` keeps each picked-up phone's number on its own item. Add a `telephone.png` to `rsg-inventory/html/images`.

## How a call works
1. Target a phone → **Make Call**, dial or pick from the directory, press **Call** (or Enter).
2. The caller hears a ringback tone; the destination phone rings for anyone within `Config.RingDistance`.
3. Someone targets the ringing phone → **Answer Phone**. Each player's mic is routed to the other at full volume, regardless of distance.
4. Either player presses **End Call** (or Esc). Calls also end if a player walks away from their phone, disconnects, the ring times out, the call reaches `Config.MaxCallLength`, or payphone credit runs out.

## Directory
The directory lists every placed phone with "Show in directory" ticked. Admins also see hidden phones (marked **Hidden**) and can remove (✕) or re-add (✓) any entry from the directory tab.

## Payphones
Any phone **without** a job restriction is a payphone (`Config.Payphone`).
- Before dialling, the caller inserts coins on the phone screen (up to `MaxDeposit`); **Return** clears them.
- The money is taken when the call is placed – only after every other check passes.
- Each minute is charged once the call is answered (the first minute on answer). Remaining credit is shown on screen.
- The caller is warned `WarnSeconds` before credit runs out; the call ends when it does.
- Unused credit is returned when the call ends; unanswered calls are refunded in full. Receiving calls is free.
- If the caller disconnects mid-call, the refund goes to their character in the database.

Set `Config.Payphone.Enabled = false` to make every phone free.

## Job phones
Give a phone a job (in the form or with `/phonejob`) and only players whose job **type** or **name** matches can make calls from it – others don't see the **Make Call** option and the server rejects them. Anyone can still call the phone and answer it. Job phones are free to use.

## Config overview
| Option | Default | Description |
|---|---|---|
| `Config.Models` | wall / desk | Props an admin can choose |
| `Config.SpawnDistance` | 75.0 | Props stream in/out around the player |
| `Config.UseDistance` | 2.0 | ox_target distance |
| `Config.MaxCallDistance` | 3.0 | Walk further than this from your phone and the call ends |
| `Config.RingDistance` | 25.0 | How far the bell can be heard |
| `Config.RingTimeout` | 30 | Seconds before an unanswered call gives up |
| `Config.MaxCallLength` | 600 | Seconds, 0 = unlimited |
| `Config.CallCooldown` | 5 | Seconds between dial attempts |
| `Config.NumberLength` | 4 | Digits in auto-generated numbers |
| `Config.Voice` | – | Mumble voice target settings (see below) |
| `Config.Item` | enabled, max 2 | Player telephone item name, max placed per character, payphone or free |
| `Config.Payphone` | enabled, $0.10/min | Money type, cost, max deposit, coin buttons, warning time |
| `Config.Blip` | enabled | Sprite and scale of the map blips |

### Voice
If you also run pma-voice or another voice script, set `Config.Voice.DefaultTarget` to the target it uses (pma-voice = 1) and keep `Config.Voice.Target` on a free slot. Players standing next to a caller still hear that caller by normal proximity voice, but only the two callers hear each other over the line.

## Locales
Every player-facing string – notifications, target labels, commands, the phone screen, placement panel, forms and admin panel – comes from `locales/*.json` (ox_lib), nothing is hard-coded.

Included languages: English (`en`), German (`de`), Greek (`el`), Spanish (`es`), French (`fr`), Japanese (`ja`), Dutch (`nl`), Polish (`pl`), Brazilian Portuguese (`pt-br`) and Romanian (`ro`).

ox_lib picks the language from the `ox:locale` convar, e.g. in `server.cfg`:
```
setr ox:locale "de"
```
To add another language, copy `en.json` to `locales/<code>.json` and translate the values (keep the keys and every `%s`).

## Support
https://buymeacoffee.com/rexshack
