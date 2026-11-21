# rsg-radio

Field radio for **RSG Framework (RedM)**, built on [rsg-voice](https://github.com/Rexshack-RedM/rsg-voice). Players with a radio item tune to a frequency and talk to everyone else on it, at any distance. Lawmen, medics (or any job, job type or gang you configure) get restricted channels.

Version 3.1.0 · Requires rsg-core 3.0.3+, rsg-inventory, oxmysql and rsg-voice 3.2.0+ (radio volume, mute, signal and call priority). Full reference: [DOCS.md](DOCS.md).

---

## Features

- **Radio item** (`radio`): use it, or type `/radio`, to open a tuning panel. Without the item nothing opens.
- **Real frequencies in MHz**: players tune to a frequency such as `446.0 MHz` (range, decimals and unit are configurable, for example a PMR446-style `446.0`–`446.2`). Everyone tuned to the same frequency hears each other.
- **Restricted channels**: frequencies tied to a job, job type or gang (optionally on duty only). Only people who qualify see and can join them.
- **Hold O to transmit** (key set in rsg-voice, rebindable in the game's key settings). Players tuned in hear you at full volume at any distance, and people standing next to you still hear you speak. A green `RADIO <freq>` tag on the voice HUD shows your channel, and lights up while you transmit.
- **Push-to-talk keeps working** while the panel is open.
- **Favorites**: press ★ next to the frequency (optionally with a name) to save it to a per-character favorites list. Join it in one click, tap a favorite to load it into the tuner, or ✕ to remove it. Stored in the character's metadata, so no database table is needed and favorites follow the character.
- **Channel feedback**: a live hint under the frequency box shows the public range, warns about out-of-range or restricted frequencies and names channels you can join, and each channel in the list shows how many people are on it (counts refresh when you open the panel or join/leave).
- **Movable panel**: drag the header to move the radio anywhere on screen, double-click the header to reset it. Your position is remembered between sessions.
- **Automatic cleanup**: you leave the channel the moment you lose the radio, lose job or gang access, go off duty (on duty-only channels), get downed, cuffed or hogtied, log out or disconnect. If rsg-voice restarts, everyone is put back on their channel. Optionally you are put back on your channel when you recover (`Config.Incapacitated.Rejoin`).
- **Volume and mute**: a volume slider and mute button in the panel, saved per character.
- **Channel HUD**: a small list of who is on your channel, with a light on whoever is speaking, even with the panel closed (`/radiohud` to hide it).
- **Search, recents and a compact menu**: search every list, jump back to recently used frequencies, shrink the panel.
- **Reserved frequency ranges** for jobs, job types, gangs, with duty, grade and permission rules.
- **Handheld prop and animation** while you transmit (off by default, see Handheld radio below).
- **Optional battery** and **signal interference** (dead zones), both off by default.
- **Server-authoritative**: the server checks the item, frequency range, channel access and spam limits on every join.
- No database needed. rsg-core locales and notifications, 11 languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru. No ox_lib.
- Leather & gold themed UI, no vignette.

---

## Installation

1. Update **rsg-voice to 3.2.0 or later** (radio channels, volume, mute, signal and call priority that this resource relies on).
2. Drop the `rsg-radio` folder into your resources, then start it after `rsg-voice` and `rsg-inventory`:

```cfg
ensure rsg-core
ensure rsg-inventory
ensure rsg-voice
ensure rsg-radio
```

3. **Item**: by default the `radio` item is registered automatically on start (`Config.RegisterItem = true`). To add it yourself instead, set that to `false` and paste `installation/shared_items.lua` into `rsg-core/shared/items.lua`.
4. Add a `radio.png` image to rsg-inventory's images (no image is included).
5. Give players a way to get the item (shop, crafting, admin).
6. Open `shared/config.lua` and set the restricted channels to your own job names and types.

The private channel table `rsg_radio_private` is created automatically on first start (`Config.AutoDatabase = true`). To install manually, set it to `false` and import `install.sql`. Favorites are stored in character metadata and need no table.

---

## Usage

| Action | How |
|---|---|
| Open the radio | Use the `radio` item, or type `/radio` |
| Change frequency | Type a frequency such as `446.0` (or use − / +, which step by the smallest allowed amount), then **Connect** (or press ENTER) |
| Save a favorite | Tune a frequency, optionally type a name, press **★**. Press ★ again to remove it |
| Use a favorite | Press **Join** next to it in the Favorites list (tap its name to load it into the tuner) |
| Join a restricted channel | Press **Join** next to it (only channels you may use are listed) |
| Transmit | Hold **O** while tuned in (default; players can rebind it in the game's key settings) |
| Switch off | **Switch off** in the panel |
| Close the panel | ✕ or ESC |

---

## Configuration

`shared/config.lua`:

| Option | Default | Description |
|---|---|---|
| `Config.Item` | `'radio'` | Item players need |
| `Config.RegisterItem` | `true` | Register the item with rsg-core on start |
| `Config.ItemDefinition` | table | Label, weight, image, description of the auto-registered item |
| `Config.Command` | `'radio'` | Command that opens the radio |
| `Config.Frequency` | `{ Min = 100.0, Max = 470.0, Decimals = 1, Unit = 'MHz' }` | Allowed frequency range, decimal places (0–3) and unit label. `Decimals = 0` gives plain whole-number channels |
| `Config.MaxFavorites` | `10` | Favorites per character |
| `Config.FavoriteLabelLength` | `16` | Longest favorite name (characters) |
| `Config.Channels` | lawman (155.0), medic (155.5) | Restricted channels: `freq`, `label` (locale key), `jobs`, `jobtypes`, `gangs`, `onduty`, `minGrade` (minimum grade level) |
| `Config.MultiJob` | `true` | Players holding a matching job (not only the active one) can use channels that do not require being on duty |
| `Config.FavoriteHotkeys` | `{ Enabled = true, Next = 'PAGEDOWN', Prev = 'PAGEUP' }` | Hotkeys to cycle favorites (rebindable in key settings) |
| `Config.LiveUpdateDelay` | `500` | ms to batch live updates of open panels |
| `Config.Private` | table | Private channels: `Enabled`, `MaxPerPlayer`, `MaxChannels`, `CodeMin`, `CodeMax`, `NameLength`, `ExpireDays`, `MaxWrongCodes`, `LockoutSeconds` |
| `Config.Staff` | `{ Permission = 'admin', MuteMinutes = 10, Webhook = '' }` | Staff command permission, default block length and optional Discord webhook |
| `Config.AutoDatabase` | `true` | Create the `rsg_radio_private` table on start (false = import `install.sql`) |
| `Config.CheckInterval` | `10` | Seconds between checks that radio and access are still valid |
| `Config.TransmitKeyLabel` | `'O'` | Key name shown in the hint. Keep in line with rsg-voice `Config.Radio.Key` |
| `Config.AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk and the transmit key working while the panel is open |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the panel is open |
| `Config.Ranges` | empty | Reserved frequency ranges: `min`, `max`, `label` (locale key) and the same rules as channels |
| `Config.Hud` | table | Channel HUD: `Enabled`, `Command`, `Names` (`character`, `callsign`, `id`), `MaxRows`, `Left`, `Top` (default position) |
| `Config.Recents` | `{ Max = 8 }` | Recent frequencies kept per character (0 = off) |
| `Config.Incapacitated` | `{ Dead, Cuffed, Hogtied = true, Rejoin = false }` | Leave the radio while downed, cuffed or hogtied |
| `Config.Battery` | `Enabled = false` | Battery: drain rates, low warning, recharge item |
| `Config.Interference` | `Enabled = false` | Dead zones and weak spots (`Zones`) |
| `Config.Volume` | `{ Default = 100, Step = 5 }` | Default radio volume (percent) and slider step |
| `Config.Handheld` | `Enabled = false` | Prop, bone, offsets and animation while transmitting |

A channel matches a player if **any** of `jobs`, `jobtypes`, `gangs` or `permission` (an rsg-core permission level, bypasses duty and grade) matches. A channel with none of them is open to everyone with a radio. Only the player's active job is checked. The default lawman channel uses job type `leo` and the medic channel uses job name `medic`; change them to match your server.

To add a channel: add an entry to `Config.Channels`, then add its `label` key to every file in `locales/`.

The transmit key, whether nearby players hear you and the channel size limit are set in **rsg-voice** (`Config.Radio`).

With the config, frequency rules, favorites format, events, state object and integration examples, see [DOCS.md](DOCS.md).

---

## Private channels
Open **Private** in the radio, type any free frequency, a name and a passcode (letters/numbers, length set by `Config.Private`), then **Create**. Creating a channel costs `Config.Private.Cost` (default $250 cash, `MoneyType`; 0 = free); updating or deleting your own channel is free. Others join by typing the frequency and the passcode. The owner can update the name/passcode (everyone else is removed and must enter the new one) or delete the channel with ✕. Channels nobody uses for `ExpireDays` are removed. Restricted job channels cannot be turned private.

## Volume, mute, search, recents and the compact menu
- The slider and the speaker button set how loud radio transmissions are for **you** (saved per character). Muting only silences incoming radio; you can still transmit.
- The search box filters channels, private channels, favorites and recents. **Recent** lists your last used frequencies; press ☆ to turn one into a favorite.
- The ⇕ button in the header switches between the full and the compact panel (remembered).

## Channel HUD
While you are on a channel a small box lists who else is on it and lights up whoever is speaking. It sits at the top left by default. Open the radio panel and drag the HUD to move it (double-click it to put it back); the position is remembered. `/radiohud` shows or hides it for you (remembered). Server settings are in `Config.Hud`.

## Reserved ranges
`Config.Ranges` reserves every frequency between `min` and `max` for the people who match its rules (`jobs`, `jobtypes`, `gangs`, `onduty`, `minGrade`, `permission`). A channel in `Config.Channels` inside a range wins over the range. Private channels cannot be created inside a range.

## Downed, cuffed or hogtied
You leave the radio when you are downed (`isdead`), cuffed (`ishandcuffed`) or hogtied, and cannot tune in until it ends. With `Config.Incapacitated.Rejoin = true` you are put back on your channel when you recover.

## Battery (optional)
Set `Config.Battery.Enabled = true`. The charge is stored in the radio item. It drains while you are tuned in and faster while you transmit, you get a warning at `LowWarning`, and a flat radio cannot connect. Use a `radio_battery` item (auto-registered when `Config.RegisterItem` is true, add `radio_battery.png` to rsg-inventory) with a radio in your inventory to recharge. Existing radios count as full.

## Signal interference (optional)
Set `Config.Interference.Enabled = true` and add zones (`coords`, `radius`, `signal`, `falloff`). Inside a zone your signal drops: you hear the channel quieter with more static, and at `signal = 0.0` you cannot transmit or hear anything. Your signal affects what **you** hear and whether **you** can transmit.

## Handheld radio (optional)
`Config.Handheld` shows a prop and plays an animation while you transmit. It is off by default because RDR2 has no radio prop or radio animation. No animation and no prop are set by default. The config lists the nearest vanilla clip (a hand-to-neck gesture, `rub_neck_01`) to fill in if you want to try it. Set `Config.Handheld.Model` (for example the megaphone) to hold a prop, then tune `Bone`, `Offset` and `Rotation` in game. The clips are untested in game; other options are listed in the config.

## Hotkeys
`PAGEDOWN` / `PAGEUP` jump to the next / previous favorite you can use (rebind in the game's key settings, "Radio: next/previous favorite").

## Admin panel
`/radioadmin` (permission `Config.Staff.Permission`, default `admin`) opens the staff panel: live stats, every channel with its members (remove, block for N minutes, clear the channel), private channels (owner, idle days, delete), active blocks (unblock) and the last 50 staff actions. Drag the header to move it, double-click to reset. All actions are checked again on the server.

## Staff commands
Permission `Config.Staff.Permission` (default `admin`): `/radioadmin`, `/radiolist [freq]`, `/radiokick [id]`, `/radiomute [id] [minutes]`, `/radiounmute [id]`, `/radiodeleteprivate [freq]`.

## Exports (server)

```lua
local freq = exports['rsg-radio']:GetFrequency(src) -- frequency string or nil
local battery = exports['rsg-radio']:GetBattery(src) -- 0-100, or nil when batteries are off / no radio
```

To put a player on a channel without the item or panel, call rsg-voice directly: `exports['rsg-voice']:JoinRadio(src, '5')`. See the rsg-voice docs.

---

## Localisation

`locales/*.json`: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale en`.

---

## File structure

```
rsg-radio/
├── client/client.lua
├── server/server.lua
├── shared/config.lua
├── html/index.html
├── installation/shared_items.lua
├── locales/*.json
└── fxmanifest.lua
```

Support: https://buymeacoffee.com/rexshack
