# rsg-radio – Docs (v3.3.2)

Technical reference for server owners and developers. For a short overview and install steps see [README.md](README.md).

## Contents
1. [Overview](#1-overview)
2. [Files](#2-files)
3. [Installation](#3-installation)
4. [Configuration](#4-configuration)
5. [Frequencies](#5-frequencies)
6. [Restricted channels](#6-restricted-channels)
7. [Favorites](#7-favorites)
8. [Lifecycle](#8-lifecycle)
9. [API reference](#9-api-reference)
10. [Integration examples](#10-integration-examples)
11. [Security model](#11-security-model)
12. [Performance](#12-performance)
13. [Localisation](#13-localisation)
14. [Server owner how-tos](#14-server-owner-how-tos)
15. [Troubleshooting](#15-troubleshooting)
16. [Private channels, hotkeys, staff and admin panel](#16-private-channels-hotkeys-staff-and-admin-panel)
17. [Known limitations](#17-known-limitations)
18. [Features added in 3.1.0](#18-features-added-in-310)
19. [Examples for the 3.1.0 features](#19-examples-for-the-310-features)

---

## 1. Overview

rsg-radio is the **rules and UI layer** of the field radio. [rsg-voice](https://github.com/Rexshack-RedM/rsg-voice) carries the voice.

| Concern | Owned by |
|---|---|
| Who may be on which frequency (item, range, job/type/gang, on duty) | rsg-radio (server) |
| Tuning panel, favorites, panel position | rsg-radio (client + NUI) |
| Channel membership, transmit key, voice routing, radio static, HUD tag | rsg-voice |

```
 Player ──/radio or item──▶ rsg-radio client ──callback getState──▶ rsg-radio server
    ▲                              │ NUI (html/index.html)                  │ validates
    │ hold O (rsg-voice)           ▼                                        ▼
 rsg-voice client ◀── channel members ◀── rsg-voice server ◀── JoinRadio(src, '446.0')
```

Requires rsg-core 3.0.3+, rsg-inventory and **rsg-voice 3.1.3+** (3.1.3 binds the transmit key by name; earlier versions may not detect the O key on every setup). Uses oxmysql for private channels only (auto-built table), no ox_lib.

## 2. Files

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-voice` |
| `shared/config.lua` | Item, command, frequency format, favorites, restricted channels and ranges, HUD, recents, incapacitation, battery, interference, volume, handheld, private channels, staff, key settings |
| `install.sql` | Schema of `rsg_radio_private` (same as the automatic build) |
| `server/server.lua` | Database build, private channels, staff commands, live updates, item registration/use, frequency validation, joining and leaving through rsg-voice, favorites, recents, reserved ranges, instant and periodic access checks, downed/cuffed/hogtied handling, battery, HUD data, volume settings, exports |
| `client/client.lua` | Command, NUI focus with push-to-talk whitelist, NUI callbacks that forward to the server, HUD, volume/mute and signal hand-over to rsg-voice, hogtied report, interference zones, handheld prop and animation |
| `html/index.html` | Tuning panel and HUD (NUI): frequency tuner, search, favorites, recents, channel list, volume, compact mode, drag-to-move, staff panel |
| `installation/shared_items.lua` | Item lines for manual install (`Config.RegisterItem = false`): `radio` and the optional `radio_battery` |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (identical keys) |
| `CHANGELOG.md` | Version history |

## 3. Installation

1. Update **rsg-voice to 3.2.0 or later** (volume, mute, signal, call priority and the `radioTalkChanged` event this resource uses), or **3.3.0** for the volume test.
2. Start order:
   ```cfg
   ensure rsg-core
   ensure rsg-inventory
   ensure rsg-voice
   ensure rsg-radio
   ```
3. Item: registered automatically on start (`Config.RegisterItem = true`, skipped if the item already exists). For a manual install set it to `false` and paste `installation/shared_items.lua` into `rsg-core/shared/items.lua`.
4. Add `radio.png` to rsg-inventory's images (none is shipped).
5. Give players a way to get the item (shop, crafting, admin).
6. Edit `Config.Channels` to match your job names/types and set the frequency range you want.

7. Requires **oxmysql**. The table `rsg_radio_private` is created on start when `Config.AutoDatabase = true` (printed in green on success, red on failure). For a manual install set it to `false` and import `install.sql`. Favorites are stored in the character's metadata and need no table.

## 4. Configuration

`shared/config.lua`:

| Option | Default | Description |
|---|---|---|
| `Config.Item` | `'radio'` | Item name players need in their inventory |
| `Config.RegisterItem` | `true` | Call `exports['rsg-core']:AddItem` on start if the item is missing |
| `Config.ItemDefinition` | table | `label, weight, type, image, unique, useable, shouldClose, description, category` of the auto-registered item |
| `Config.Command` | `'radio'` | Command that opens the radio (needs the item) |
| `Config.Frequency` | `{ Min = 100.0, Max = 470.0, Decimals = 1, Unit = 'MHz' }` | Allowed range, decimal places (0–3, clamped) and unit label shown in the UI |
| `Config.MaxFavorites` | `10` | Favorites per character |
| `Config.FavoriteLabelLength` | `16` | Longest favorite name in characters |
| `Config.Channels` | lawman, medic | Restricted channels, see [section 6](#6-restricted-channels) |
| `Config.CheckInterval` | `10` | Seconds between checks that connected players still have the item and access (minimum 1) |
| `Config.TransmitKeyLabel` | `'O'` | Text of the "Hold O to transmit" hint, used only when rsg-voice cannot report its key (older rsg-voice, or `UseKeyMapping = false`). With rsg-voice 3.4.0+ the hint uses rsg-voice's `Config.Radio.Key` |
| `Config.AllowPushToTalkWhileOpen` | `true` | While the panel is open: `SetNuiFocusKeepInput(true)` plus a control whitelist so voice keys keep working |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the panel is open (N, push-to-talk) |
| `Config.Ranges` | `{}` | Reserved ranges: `min`, `max`, `label` (locale key) plus the channel rules `jobs`, `jobtypes`, `gangs`, `onduty`, `minGrade`, `permission`. See [18.1](#181-reserved-ranges-configranges) |
| `Config.Hud` | table | `Enabled` (true), `Command` (`'radiohud'`, `''` = none), `Names` (`'character'`, `'callsign'`, `'id'`), `MaxRows` (8), `Left` / `Top` (18 / 18, default position in pixels) |
| `Config.Recents` | `{ Max = 8 }` | Recent frequencies kept per character, `0` = off |
| `Config.Incapacitated` | `{ Dead = true, Cuffed = true, Hogtied = true, Rejoin = false }` | Which states drop a player off the radio, and whether they are put back when they recover |
| `Config.Battery` | `Enabled = false` | `DrainInterval` (60 s), `DrainPerMinute` (0.5), `TransmitDrainPerMinute` (4.0), `LowWarning` (20), `ChargeItem` (`'radio_battery'`), `ChargeAmount` (100), `ChargeItemDefinition` |
| `Config.Interference` | `Enabled = false` | `Zones`: `{ label, coords (vector3), radius, signal (0.0-1.0), falloff (bool) }` |
| `Config.Volume` | `{ Default = 50, Step = 5, Bleep = true, TestCommand = 'radiotest' }` | Starting radio volume in percent, the slider step, whether the slider plays a short bleep (`false` = silent) and the volume test command (`''` = no command) |
| `Config.Handheld` | `Enabled = false` | `Model` (nil = no prop), `Bone`, `Offset`, `Rotation`, `Anim` / `AnimFemale` (`{ dict, clip, flag }`), `OnMount` |
| `Config.Private`, `Config.Staff`, `Config.FavoriteHotkeys`, `Config.AutoDatabase`, `Config.MultiJob` | tables | See [section 16.1](#161-config-options) |

Things that live in **rsg-voice**: `Config.Radio` (`Enabled`, `UseKeyMapping`, `Key` default `'O'`, `TalkKey` fallback control hash, `NearbyHear`, `MaxMembers`, `Static` radio sound, `MaxTransmitSeconds` push-to-talk limit, `TransmitCooldown`, `Debug`) and `Config.Priority` (`RadioVsParty`, `Call`).

## 5. Frequencies

A frequency is a number with at most `Config.Frequency.Decimals` decimal places inside `Min`–`Max`. The server converts it to a fixed-format string (`'446.0'`). That string is used everywhere: in rsg-voice as the channel key, in the state sent to the UI, in favorites and in `GetFrequency`.

```lua
-- default: 100.0 to 470.0, one decimal
446.0   --> '446.0'   accepted
446     --> '446.0'   accepted
446.05  --> nil       rejected (too many decimals)
99.9    --> nil       rejected (below Min)
'446'   --> nil       rejected (must be a number, never a string)
0/0     --> nil       rejected (NaN)
```

Common setups:

```lua
-- PMR446 band, three frequencies only
Config.Frequency = { Min = 446.0, Max = 446.2, Decimals = 1, Unit = 'MHz' }

-- Finer steps (the +/- buttons step by 0.001 then)
Config.Frequency = { Min = 100.000, Max = 470.000, Decimals = 3, Unit = 'MHz' }

-- Plain whole-number channels 1 to 999
Config.Frequency = { Min = 1, Max = 999, Decimals = 0, Unit = '' }
```

Changing the format does not migrate anything: favorites and `Config.Channels` entries that no longer fit are not removed automatically (favorites stay in the list but their Join button is disabled until removed; invalid channels are skipped with a console warning).

Two players hear each other when they are on the same frequency string.

## 6. Restricted channels

```lua
Config.Channels = {
    { freq = 155.0, label = 'channel_lawman', jobtypes = { 'leo' }, onduty = true },
    { freq = 155.5, label = 'channel_medic',  jobs = { 'medic' },   onduty = true },
    { freq = 460.5, label = 'channel_gang',   gangs = { 'odriscoll' } },
    { freq = 450.0, label = 'channel_open_named' },                 -- no rules: named but open to everyone
}
```

| Field | Meaning |
|---|---|
| `freq` | Must be valid under `Config.Frequency`. Invalid or duplicate entries are skipped with a red console warning at start |
| `label` | Locale key (add it to every `locales/*.json`) |
| `jobs` | Allowed `job.name` values |
| `jobtypes` | Allowed `job.type` values (for example `'leo'`) |
| `gangs` | Allowed `gang.name` values |
| `onduty` | `true` also requires `job.onduty` |

A player matches when **any** of `jobs`, `jobtypes`, `gangs` matches. Only the **active** job is read (not other jobs held through multi-job). Restricted channels are listed in the panel only for players who qualify. Players who don't qualify see "Restricted frequency – no access" if they type that number, and the server refuses the join.

## 7. Favorites

- Stored in the player metadata key `radiofavs`, saved with the character (no SQL needed):

  ```lua
  { { freq = '446.0', label = 'Camp' }, { freq = '155.0', label = '' } }
  ```
- Up to `Config.MaxFavorites`. Saving an existing frequency updates its name.
- Names: control characters removed, trimmed, cut to `Config.FavoriteLabelLength` characters (the server bounds the work before cleaning, so an oversized string from a modified client is cheap).
- A favorite on a restricted frequency is only accepted if the player currently qualifies. If the range or the player's access changes later, the favorite stays in the list but is marked `usable = false` and its Join button is disabled.
- Favorites are sent to the UI inside the state (see [9.3](#93-state-object)).

Read a player's favorites from another script:

```lua
local Player = RSGCore.Functions.GetPlayer(src)
local favs = Player.PlayerData.metadata.radiofavs or {}
for _, f in ipairs(favs) do print(f.freq, f.label) end
```

## 8. Lifecycle

1. **Open**: the player uses the item or `/radio`. The client calls the callback `rsg-radio:server:getState`. With no item the server returns nil and the client shows "You don't have a radio". Otherwise the panel opens with NUI focus. `SetNuiFocusKeepInput(true)` and a per-frame whitelist keep push-to-talk working (rsg-voice's transmit key is bound by name and works independently).
2. **Join**: the NUI sends the frequency to the client, which fires `rsg-radio:server:join`. The server checks the player, the item, the frequency, and channel access, then calls `exports['rsg-voice']:JoinRadio(src, key)`. rsg-voice tells every member.
3. **Transmit**: the player holds the radio key (default O, set in rsg-voice). Everyone on the channel hears them at full volume at any distance. The voice HUD tag turns green.
4. **Checks**: the server re-checks a connected player the moment their inventory, job, gang, duty or metadata changes (batched, 250 ms) and every `Config.CheckInterval` seconds as a fallback. Players are removed when they lost the item (`sv_lost_radio`), are downed, cuffed or hogtied (`sv_lost_incap`), have a flat battery (`sv_batt_dead`) or lost channel access (`sv_lost_access`).
5. **Leave / cleanup**: Switch off in the panel, logout, disconnect (rsg-voice also removes players on `playerDropped` and `RSGCore:Server:OnPlayerUnload`). If something else removes the player from the channel, rsg-radio clears its record and updates the panel (`rsg-voice:server:radioChanged`).
6. **Restarts**: if rsg-voice restarts, rsg-radio rejoins everyone after 1.5 s. If rsg-radio restarts, it adopts players still on a channel in rsg-voice, and the next check removes those without the item.

## 9. API reference

### 9.1 Server exports

| Export | Returns | Notes |
|---|---|---|
| `exports['rsg-radio']:GetFrequency(src)` | frequency string or `nil` | The frequency the player tuned in with this radio |
| `exports['rsg-radio']:GetBattery(src)` | number 0-100 or `nil` | The charge of the player's radio. `nil` when `Config.Battery.Enabled` is false or the player has no radio |

Voice-level functions are in rsg-voice: `JoinRadio(src, freq)`, `LeaveRadio(src)`, `GetPlayerRadio(src)`, `GetRadioMembers(freq)` (server), `GetRadio()`, `IsRadioTalking()`, `GetRadioTalkKey()` (client).

### 9.2 Events and callbacks

| Name | Side | Payload | Validation and limits |
|---|---|---|---|
| `rsg-radio:server:getState` (callback) | server | none | Returns the [state object](#93-state-object), or `nil` when the player has no radio |
| `rsg-radio:server:join` | server | `freq` (number), `code` (string, optional passcode) | Player exists, has item, valid frequency, access to restricted channel, rsg-voice not full. 500 ms cooldown (shared with leave) |
| `rsg-radio:server:savePrivate` | server | `freq`, `name`, `code` | See 16.3. 1 s cooldown |
| `rsg-radio:server:deletePrivate` | server | `freq` | Owner only. 1 s cooldown |
| `rsg-radio:server:cycleFavorite` | server | `dir` (`1` / `-1`) | Next/previous usable favorite. 300 ms cooldown |
| `rsg-radio:server:panelClosed` | server | none | Stops live updates for that player |
| `rsg-radio:server:leave` | server | none | Only if connected. 500 ms cooldown |
| `rsg-radio:server:addFavorite` | server | `freq` (number), `label` (string) | Player has item, valid frequency, access, `MaxFavorites`. 300 ms cooldown |
| `rsg-radio:server:removeFavorite` | server | `freq` (number) | Valid frequency. 300 ms cooldown |
| `rsg-radio:client:open` | client | none | Sent by the server when the item is used. Ignored if triggered by another resource |
| `rsg-radio:client:state` | client | state or `nil` | New state for an open panel; `nil` closes it. Ignored if triggered by another resource |
| `rsg-radio:server:hogtied` | server | `state` (boolean) | Rejected unless a boolean. 400 ms cooldown. Only affects the sender's own radio |
| `rsg-radio:server:setSettings` | server | `vol` (0-100), `muted` (boolean) | Clamped, ignored when unchanged. 250 ms cooldown. Stored in `metadata.radiosettings` |
| `rsg-radio:client:hud` | client | `{ freq, unit, members, battery }` or `nil` | Server to client only. Ignored if triggered by another resource |
| `rsg-radio:client:battery` | client | `value` (0-100) | Server to client only. Ignored if triggered by another resource |
| `rsg-voice:server:radioChanged` | server (listened) | `src, newFreq, oldFreq` | Used to keep `GetFrequency` correct and to refresh HUDs |
| `rsg-voice:server:radioTalkChanged` | server (listened) | `src, state` | Server-only, fired by rsg-voice after it validated the transmit change. Used for the battery's transmit drain |
| `rsg-voice:client:radioTalk` | client (listened) | `sid, state` | Who is speaking, for the HUD |
| `rsg-voice:client:onRadioTalk` | client (rsg-voice) | `state` (bool) | Not used by rsg-radio; available for animations or sounds |

### 9.3 State object

Returned by the callback and pushed through `rsg-radio:client:state`:

```lua
{
    freq = '446.0',            -- current frequency or nil
    count = 3,                 -- people on the current frequency
    min = 100.0, max = 470.0,  -- range
    dec = 1, unit = 'MHz',     -- decimals and unit
    channels = {               -- restricted channels this player can join
        { freq = '155.0', label = 'Lawmen', count = 2 },
    },
    reserved = { '155.5' },    -- restricted frequencies this player cannot join (only used for the "restricted" hint)
    favorites = {
        { freq = '446.0', label = 'Camp', usable = true },
    },
    maxFavorites = 10,
    -- added in 3.1.0
    recents = { { freq = '155.0', label = 'Lawmen', usable = true, locked = false } },
    ranges = { { min = '160.0', max = '169.9', label = 'Lawmen' } },  -- reserved ranges this player may use
    reservedRanges = { { min = '170.0', max = '174.9' } },            -- reserved ranges this player may not use
    vol = 50, muted = false, volStep = 5,                             -- radio volume (percent) and mute
    battery = 87.5,                                                   -- nil when batteries are off
}
```

`count` values are a snapshot, refreshed automatically while the panel is open (see 16.4).

### 9.4 NUI protocol (`html/index.html`)

Messages from Lua (`SendNUIMessage`):

| `action` | Fields | Effect |
|---|---|---|
| `open` | `strings` (translated UI text), `state` | Shows the panel, restores the saved position |
| `state` | `state` | Re-renders |
| `close` | none | Hides the panel |

NUI callbacks (POST to the resource): `close`, `join {freq, code}`, `savePrivate {freq, name, code}`, `deletePrivate {freq}`, `leave`, `addFavorite {freq, label}`, `removeFavorite {freq}`. The client forwards them to the server events above and never trusts the values.

## 10. Integration examples

**Which frequency is a player on?**

```lua
local freq = exports['rsg-radio']:GetFrequency(src)
if freq == '155.0' then
    -- on the lawman channel
end
```

**Put a player on a channel from a script (no item or access check)**

```lua
-- server
local ok, reason = exports['rsg-voice']:JoinRadio(src, '155.0') -- reason: 'disabled' | 'invalid' | 'full'
exports['rsg-voice']:LeaveRadio(src)
```

Note: rsg-radio only tracks (and runs its item/access checks on) players who joined through its own panel. Players you join directly through rsg-voice are not tracked, so `GetFrequency` returns `nil` for them and rsg-radio will not remove them if they have no radio.

**Who is on a channel?**

```lua
local members = exports['rsg-voice']:GetRadioMembers('155.0') or {}
print(('%d people on 155.0'):format(#members))
```

**Alert everyone on a channel**

```lua
local function alertChannel(freq, text)
    for _, id in ipairs(exports['rsg-voice']:GetRadioMembers(freq) or {}) do
        TriggerClientEvent('RSGCore:Client:Notify', id, { title = 'Dispatch', description = text, type = 'warning', duration = 6000 })
    end
end
alertChannel('155.0', 'Shots fired in Valentine')
```

**React when a player changes channel**

```lua
AddEventHandler('rsg-voice:server:radioChanged', function(src, newFreq, oldFreq)
    -- newFreq is nil when the player left the radio
end)
```

**Do something while the local player transmits (client)**

```lua
AddEventHandler('rsg-voice:client:onRadioTalk', function(state)
    if state then print('transmitting') else print('stopped') end
end)
```

**Give the radio item (server)**

```lua
exports['rsg-inventory']:AddItem(src, 'radio', 1, nil, nil, 'shop-purchase')
```

## 11. Security model

What the server enforces on every request:

| Check | Where |
|---|---|
| Player exists (`GetPlayer`) | join, leave, favorites |
| Player owns the item | join, addFavorite, getState |
| Frequency is a number, not NaN or infinity, at most `Decimals` decimals, inside `Min`–`Max` | join, addFavorite, removeFavorite |
| Channel access (job, type, gang, on duty) | join, addFavorite, periodic check |
| Per-player cooldowns (500 ms join/leave, 300 ms favorites, 1 s private channels, 400 ms hogtie report, 250 ms volume save) | join, leave, favorites, private, hogtied, setSettings |
| Not downed, cuffed or hogtied; battery not flat | join, rejoin, instant and periodic checks |
| Volume clamped to 0-100, mute is a boolean, nothing written when unchanged | setSettings |
| Battery is read from and written to the radio item on the server only; the client only receives the number | battery |
| Favorites count, name cleaned and length-bounded | addFavorite |
| Radio and access re-checked the moment inventory, job, gang, duty or metadata changes, and every `CheckInterval` seconds as a fallback | instant check, periodic check |

Other points:

- No client event can add a player to a channel. Membership is changed only on the server through rsg-voice's exports.
- Net events from other resources are ignored for the two client events (`GetInvokingResource`).
- The NUI escapes all text it renders (channel names, favorite names).
- Config is validated at start. Bad channel entries are skipped with a console warning instead of breaking the resource.
- The client-reported hogtied flag can only be used to drop the sender from their own radio; it grants nothing.
- The HUD names come from the server (`Config.Hud.Names`), cleaned and length-bounded; the client cannot choose what others see.
- Voice routing itself is done client-side by rsg-voice (as for party talk), so a modified client could aim its voice at players who are not on its channel. Do not use the radio for anything that must stay secret. This is a property of the voice layer, not of rsg-radio.
- Other scripts: never call `JoinRadio` from a net event without checking the player yourself.

## 12. Performance

- Client: idle at `Wait(250)`. A per-frame control whitelist runs **only** while the panel is open. The panel itself is static HTML.
- Server: access is re-checked on change events (batched, 250 ms per player, nothing for players not on the radio) plus a fallback loop every `CheckInterval` seconds (one inventory check per connected player). The battery loop runs every `DrainInterval` seconds and only touches connected players when `Config.Battery.Enabled`. HUD updates are batched (150 ms) per channel. Open panels are refreshed at most once per `LiveUpdateDelay`.
- State building does one `GetRadioMembers` per restricted channel, only when a panel opens or a player joins/leaves/changes favorites.
- Everything per-player is cleaned on `playerDropped` and `RSGCore:Server:OnPlayerUnload`.

## 13. Localisation

Locale files in `locales/` (`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`), all with the same keys. Language: `setr rsg:locale en`. Loaded through rsg-core (`@rsg-core/shared/locale.lua`).

| Key | English |
|---|---|
| `notify_title` | Radio |
| `cl_no_radio` | You don't have a radio |
| `sv_joined` | Tuned to frequency %s |
| `sv_left` | Radio switched off |
| `sv_invalid_freq` | That frequency is not available |
| `sv_no_access` | You are not allowed on that frequency |
| `sv_full` | That channel is full |
| `sv_lost_radio` | You no longer have a radio |
| `sv_lost_access` | You lost access to that frequency |
| `sv_fav_added` / `sv_fav_removed` | Saved %s to favorites / Removed %s from favorites |
| `sv_fav_full` | Your favorites list is full |
| `ui_title`, `ui_subtitle` | Radio, Field Radio |
| `ui_status_on`, `ui_status_off` | Connected, Switched off |
| `ui_frequency`, `ui_connect`, `ui_disconnect` | Frequency, Connect, Switch off |
| `ui_channels`, `ui_no_channels` | Channels, No restricted channels available to you |
| `ui_active`, `ui_join`, `ui_close` | Active, Join, Close |
| `ui_hint` | Hold %s to transmit |
| `ui_members` | %s on channel |
| `ui_move` | Drag to move · double-click to reset |
| `ui_range` | Public frequencies %s–%s |
| `ui_restricted` | Restricted frequency – no access |
| `ui_out_of_range` | Enter a frequency from %s to %s |
| `ui_favorites`, `ui_no_favorites` | Favorites, No favorites yet. Tune a frequency and press ★ |
| `ui_fav_add`, `ui_fav_remove`, `ui_fav_label` | Add to favorites, Remove from favorites, Name (optional) |
| `channel_lawman`, `channel_medic` | Lawmen, Medical |

Every channel `label` you add to `Config.Channels` needs a key in all locale files. `%s` placeholders must keep their order in translations.

## 14. Server owner how-tos

- **Add a channel**: add an entry to `Config.Channels` and its `label` key to every `locales/*.json`.
- **Open a named channel to everyone**: omit `jobs`, `jobtypes` and `gangs`.
- **Use a different item**: set `Config.Item`; set `Config.RegisterItem = false` if you define the item yourself.
- **Change the transmit key**: set `Config.Radio.Key` in rsg-voice (and `Config.TransmitKeyLabel` here for the hint). Players can also rebind it in the game's key settings ("Radio transmit (hold)").
- **Limit channel size**: `Config.Radio.MaxMembers` in rsg-voice.
- **Turn off radio static**: `Config.Radio.Static.Enabled = false` in rsg-voice.
- **Whole-number channels instead of MHz**: `Config.Frequency = { Min = 1, Max = 999, Decimals = 0, Unit = '' }` and change the `freq` values in `Config.Channels`.

## 15. Troubleshooting

| Problem | Fix |
|---|---|
| "You don't have a radio" | Check the item name (`Config.Item`) exists and is in the inventory |
| Pressing the transmit key does nothing | Use rsg-voice 3.1.3+. Set `Config.Radio.Debug = true` in rsg-voice and read the F8 console: it shows the key state and what blocks it (`not on a radio channel`, `muted`, `menu has focus`, `party talk active`) |
| Panel opens but nobody hears me | Both players must be on the **same frequency string** (`446.0`, not `446`) and hold the transmit key. Check rsg-voice `Config.Radio.Enabled = true` |
| Kicked off a channel after a few seconds | The check found no item or no access (job/type/gang/on duty). Review `Config.Channels` |
| Channel missing from the list | Active job or gang doesn't match, or the player is off duty. Or the entry was skipped at start: look for a red `[rsg-radio] Config.Channels` line in the server console |
| Join button greyed out on a favorite | The frequency is outside the current range or the player lost access to it. Remove the favorite |
| Item has no icon | Add `radio.png` to rsg-inventory's images |
| Panel opens off-screen or in a strange place | Double-click its header to reset. The saved position is clamped to the screen |
| Character's mouth doesn't move while transmitting | Expected: radio audio bypasses the game's own talk detection. Cosmetic only (see limitations) |

## 16. Private channels, hotkeys, staff and admin panel

### 16.1 Config options
`Config.MultiJob` (bool), `Config.FavoriteHotkeys = { Enabled, Next, Prev }` (key names for `RegisterKeyMapping`), `Config.LiveUpdateDelay` (ms, minimum 100), `Config.Private = { Cost, MoneyType, Enabled, MaxPerPlayer, MaxChannels, CodeMin, CodeMax, NameLength, ExpireDays, MaxWrongCodes, LockoutSeconds }`, `Config.Staff = { Permission, MuteMinutes, Webhook }`, `Config.AutoDatabase`. Channels accept `minGrade`.

### 16.2 Access rules
A restricted channel matches when the player's active job (`jobs` / `jobtypes`) or gang matches **and** the grade level is at least `minGrade` **and** the player is on duty when `onduty` is set. With `Config.MultiJob`, jobs held but not active also count, unless the channel has `onduty` (only the active job can be on duty). Held jobs come from `exports['rsg-core']:GetPlayerJobs` and are cached 30 s (cleared on `RSGCore:Server:OnJobUpdate`). The periodic check removes players who lose access.

### 16.3 Private channels
- Table `rsg_radio_private (freq PK, owner, name, code, created_at, last_used)`.
- Cost: creating charges `Config.Private.Cost` from `Config.Private.MoneyType` (server-side, refunded if the database insert fails). Updates and deletes are free. The price is shown on the Create button.
- Create/update: `rsg-radio:server:savePrivate(freq, name, code)`. The frequency must be valid, not a configured restricted channel, unused (new channels), and the passcode `^%w+$` with length `CodeMin`..`CodeMax`. Limits: `MaxPerPlayer`, `MaxChannels`. Cooldown 1 s.
- Join: `rsg-radio:server:join(freq, code)`. Owners and players who already entered the right passcode this session need no code. `MaxWrongCodes` wrong tries cause a `LockoutSeconds` lockout, tracked per character so reconnecting does not reset it.
- Changing the passcode removes all other members; deleting removes everyone. `last_used` is updated at most once an hour; channels unused for `ExpireDays` are deleted (hourly check, only when empty).
- The passcode is a plain-text PIN stored in the database. It is never sent to clients. Treat it as a social lock, not strong security.

### 16.4 Favorite hotkeys and live counts
`rsg-radio:server:cycleFavorite(dir)` (`1` or `-1`) joins the next/previous usable favorite (300 ms cooldown). Panels report open/close through the `getState` callback and `rsg-radio:server:panelClosed`; while open they receive fresh state after any channel change, batched by `LiveUpdateDelay`.

### 16.5 Staff commands
| Command | Effect |
|---|---|
| `/radiolist [freq]` | Counts per frequency, or members of one frequency |
| `/radiokick [id]` | Removes a player from the radio |
| `/radiomute [id] [minutes]` | Removes and blocks a player (default `Config.Staff.MuteMinutes`, max 1440). Kept in memory by citizen id, cleared on restart |
| `/radiounmute [id]` | Lifts the block |
| `/radiodeleteprivate [freq]` | Deletes a private channel |

If `Config.Staff.Webhook` is an http(s) URL, each action is posted to it (never passcodes).

### 16.5b Admin panel (`/radioadmin`)
- Opening: the command triggers `rsg-radio:client:admin:open` on the staff member's client, which asks the callback `rsg-radio:server:admin:getData`. The callback returns `nil` (and the player is told they lack permission) unless `RSGCore.Functions.HasPermission(src, Config.Staff.Permission)` is true.
- Data: `{ stats = { onAir, channels, private, blocks }, channels = {{ freq, kind = 'public'|'restricted'|'private', label, members = {{ id, name, cid, job, blocked }} }}, private = {{ freq, name, owner, ownerName, count, days }}, mutes = {{ cid, name, minutes }}, log = {{ time, who, text }}, unit, muteDefault }`. Players are found with `GetPlayerRadio` for every online player, so people who joined through rsg-voice directly also appear.
- Events (all staff-only, 300 ms cooldown, followed by fresh data via `rsg-radio:client:admin:data`): `rsg-radio:server:admin:kick(id)`, `mute(id, minutes)` (1–1440), `unmute(citizenid)`, `deletePrivate(freq)`, `clearChannel(freq)`.
- NUI: messages `adminOpen`, `adminData`; callbacks `adminRefresh`, `adminKick`, `adminMute`, `adminUnmute`, `adminDeletePrivate`, `adminClear`. The panel polls `adminRefresh` every 5 s while open.
- The log is kept in memory (last 50) and cleared on restart; blocks are also in memory.

### 16.6 State object additions
`state.priv = { list = {{ freq, name, owner, count }}, locked = { '300.0' }, mine, maxPerPlayer, codeMin, codeMax, nameLen, cost }` (nil when private channels are disabled); favorites also carry `locked` (private channel needing a passcode).

## 17. Known limitations

- Live updates only reach players who have the panel open; the staff block is kept in memory and is cleared on restart.
- Players on on-duty channels need the matching job to be active (secondary jobs are never on duty).
- Private channel passcodes are stored in plain text and are a social lock, not strong security.
- The panel position is stored in the client's NUI storage (per machine, not per character).
- The character's lips do not animate while transmitting; no verified native for this is documented in the project's RedM knowledge base.
- A transmitting player's voice is routed client-side by rsg-voice; the radio is not a secure channel.
- Signal interference is worked out on the client. A modified client can ignore it, as it can ignore any client-side voice rule.
- Your own signal affects what you hear and whether you can transmit. It does not make you sound worse to the others on the channel.
- No handheld animation or prop is configured by default. The suggested clip (a neck rub, not a real radio pose) is untested in game; props are optional and their offsets are untuned.
- Hogtied is the only incapacitation read from the client (a native, not stored by any script). A modified client can hide it; dead and cuffed come from server metadata.
- Weather based interference is not included.
- The push-to-talk time limit (`Config.Radio.MaxTransmitSeconds` in rsg-voice) is enforced by the client, like voice routing, so a modified client can ignore it.
- If a player carries several radios, battery and rechargers act on the first radio stack the inventory returns.

---

Support: https://buymeacoffee.com/rexshack

## 18. Features added in 3.1.0

Needs **rsg-voice 3.2.0+**. The changelog has the short version.

### 18.1 Reserved ranges (`Config.Ranges`)
Each entry: `min`, `max` (inside `Config.Frequency`, at most `Decimals` decimals), optional `label` (locale key) and the channel rules `jobs`, `jobtypes`, `gangs`, `onduty`, `minGrade`, `permission`. A frequency in the range follows the entry's rules, and an explicit `Config.Channels` entry on a frequency inside the range wins. Private channels cannot be created inside a range. Invalid entries are skipped with a console warning. `permission = 'admin'` lets anyone with that rsg-core permission level in, whatever their job, duty or grade (it works on `Config.Channels` entries too). Players who may use a range see it in the channel list, others get the "restricted" hint when they type a frequency in it.

### 18.2 Instant access updates
The server listens to `RSGCore:Player:SetPlayerData` (fires on every inventory and metadata change), `RSGCore:Server:OnJobUpdate`, `RSGCore:Server:OnGangUpdate` and `RSGCore:Server:SetDuty`. For players who are connected (or waiting to rejoin) it re-runs the access check 250 ms later, once per burst. The `Config.CheckInterval` sweep stays as a fallback.

### 18.3 Downed, cuffed and hogtied (`Config.Incapacitated`)
| Condition | Source |
|---|---|
| Downed | `metadata.isdead` (rsg-medic) |
| Cuffed | `metadata.ishandcuffed` (rsg-lawman) |
| Hogtied | The client checks `IsPedHogtied` every 750 ms and sends `rsg-radio:server:hogtied (bool)` when it changes (bool only, 400 ms cooldown). It only affects the sender's own radio |

While true the player is removed from the radio (`sv_lost_incap`) and cannot join (`sv_incap`). `Rejoin = true` remembers the channel and puts the player back (`sv_rejoined`) once they recover, if they still have the radio and access. Each flag has its own switch (`Dead`, `Cuffed`, `Hogtied`).

### 18.4 Channel HUD (`Config.Hud`)
When rsg-voice reports a channel change the server sends every member `rsg-radio:client:hud` with `{ freq, unit, members = { { id, name } }, battery }` (batched 150 ms), or `nil` when the player left. Names: `character` (first name and last initial), `callsign` (rsg-core `metadata.callsign`, falls back to character) or `id`. The client shows who is speaking from rsg-voice's `rsg-voice:client:radioTalk` events and its own `rsg-voice:client:onRadioTalk`. The HUD starts at `Config.Hud.Left`/`Top` (top left by default). While the radio panel is open it can be dragged and a double-click resets it; the position is kept in the NUI's localStorage (`rsg-radio:hudpos`). `/radiohud` (or the name in `Config.Hud.Command`) hides it for that player (client KVP `rsg-radio:hudHidden`).

### 18.5 Recents, search and compact menu
`Config.Recents.Max` frequencies are stored in `metadata.radiorecents` (newest first, saved on every successful join). Search and the compact toggle are client side only (the compact choice is kept in the NUI storage).

### 18.6 Volume and mute
`metadata.radiosettings = { vol = 0-100, muted = bool }`. The panel applies changes at once through the client exports `SetRadioVolume(0.0-1.0)` and `SetRadioMuted(bool)` of rsg-voice, then saves them (`rsg-radio:server:setSettings (vol, muted)`, 250 ms cooldown, validated and clamped). They are applied again when the character loads and when rsg-voice restarts. Muting only silences incoming radio. The slider and mute button are per player: each player sets their own. A character with no saved value starts at `Config.Volume.Default`. While the slider moves the panel plays a 90 ms WebAudio tone (throttled to one per 90 ms) whose loudness and pitch follow the chosen volume; it is silent when muted or at 0, and `Config.Volume.Bleep = false` turns it off (sent to the NUI as `bleep` in the `open` message).

**Volume test:** the play button next to the slider and `/radiotest` (`Config.Volume.TestCommand`) call rsg-voice's client export `TestRadioIncoming()` (**rsg-voice 3.3.0+**). rsg-voice plays about 2.5 s of simulated incoming radio (squelch, speech-like audio, squelch) at its own live radio gain, which is `volume x signal` and 0 when muted, without signal or during a call. It is the same gain rsg-voice applies to real radio talkers, so the test shows what the volume really does, not rsg-radio's copy of the settings (turn on `Config.Radio.Debug` in rsg-voice to print the values in F8). The export returns `{ gain, volume, signal, muted, call, reason }`; when `gain` is 0 rsg-radio notifies `cl_test_silent`, and when the export is missing (older rsg-voice) `cl_test_unavailable`. It does not reach other players, and the sound is synthesised, so it approximates the loudness of a real voice. NUI callback `testVolume` (no data). Locale keys `ui_test_volume`, `cl_test_silent`, `cl_test_unavailable`.

### 18.7 Battery (`Config.Battery`)
The charge is `info.battery` (0 to 100) on the radio item; a radio without it counts as full. While tuned in it drains `DrainPerMinute`, plus `TransmitDrainPerMinute` for the time spent transmitting (measured from rsg-voice's server-only `rsg-voice:server:radioTalkChanged (src, state)` event), applied every `DrainInterval` seconds. A notice appears at `LowWarning`, a radio at 0 is dropped (`sv_batt_dead`) and cannot connect. Using `ChargeItem` with a radio in the inventory consumes one and adds `ChargeAmount` (refunded if the write fails). Enabling batteries makes the auto-registered radio item `unique`; if you registered the item yourself set `unique = true` too. The client receives `rsg-radio:client:battery (value)` for the HUD.

### 18.8 Signal interference (`Config.Interference`)
Zones are `{ coords, radius, signal, falloff }`. The weakest zone the player stands in decides their signal (1.0 clear, 0.0 none); with `falloff` it rises from `signal` at the centre to 1.0 at the edge. The client hands it to rsg-voice with `SetRadioSignal`, which scales the incoming volume (more static the weaker it is) and blocks transmitting and hearing at 0.0.

### 18.9 Handheld radio (`Config.Handheld`)
On `rsg-voice:client:onRadioTalk(true)` the client creates a networked prop (`Model`), attaches it to `Bone` with `Offset`/`Rotation` and plays `Anim` (`dict`, `clip`, `flag`; `AnimFemale` for female peds, falls back to `Anim`). `Model` is optional: leave it `nil` for the animation only. It is removed when the key is released, the player dies, ragdolls, swims, climbs, falls, mounts (unless `OnMount`), enters a wagon, leaves the channel or the resource stops. `Anim` and `AnimFemale` are `nil` by default, so nothing plays. The suggested clip is `rub_neck_01` from `amb_wander@code_human_wander@male@generic` / `@female@generic` with flag 18 (upper body, holds the last frame), found in the RedM brain's `ingameanims_list.lua`. The megaphone (`p_cs_megaphone01x`, clip `idle_hixon` in `script_mp@moonshiner@story_missions@moon1@ig4_megaphone`, flag 31) still works as an option; its offsets are zero and must be tuned.

### 18.10 Call and party priority (rsg-voice and rsg-telephone)
rsg-voice 3.2.0 adds `Config.Priority` (call blocks radio and party voice, and `RadioVsParty = 'first' | 'radio' | 'party'`) and `Config.Radio.MaxTransmitSeconds` / `TransmitCooldown`. rsg-telephone 3.1.1 calls `exports['rsg-voice']:SetCallActive(true/false)` for the length of a call. See the rsg-voice DOCS.

### 18.11 Metadata keys
`radiofavs` (favorites), `radiorecents` (recent frequencies), `radiosettings` (volume and mute).

### 18.12 New events and exports
| Name | Side | Payload |
|---|---|---|
| `rsg-radio:client:hud` | client | `{ freq, unit, members, battery }` or `nil` (server only) |
| `rsg-radio:client:battery` | client | `value` 0-100 (server only) |
| `rsg-radio:server:hogtied` | server | `state` (boolean) |
| `rsg-radio:server:setSettings` | server | `vol` (0-100), `muted` (boolean) |
| `GetBattery(src)` | server export | see 9.1 |
NUI: messages `hud`, `battery`; callbacks `setVolume {vol, muted}` (applies locally) and `saveVolume` (stores).

## 19. Examples for the 3.1.0 features

### 19.1 Config
```lua
-- Reserve 160.0-169.9 for lawmen on duty (rank 1+) and 170.0-174.9 for medics, admins can use both
Config.Ranges = {
    { min = 160.0, max = 169.9, label = 'range_lawman', jobtypes = { 'leo' }, onduty = true, minGrade = 1, permission = 'admin' },
    { min = 170.0, max = 174.9, label = 'range_medic',  jobs = { 'medic' },   permission = 'admin' },
}

-- Batteries: 100% lasts ~3 hours listening, much less when talking a lot
Config.Battery = { Enabled = true, DrainPerMinute = 0.5, TransmitDrainPerMinute = 4.0, LowWarning = 20, ChargeAmount = 100 }

-- A mine shaft with no signal in the middle that clears towards the edge
Config.Interference = {
    Enabled = true,
    Zones = { { label = 'Mine shaft', coords = vector3(1234.0, -567.0, 80.0), radius = 150.0, signal = 0.0, falloff = true } },
}

-- Put downed players back on their channel when they recover
Config.Incapacitated = { Dead = true, Cuffed = true, Hogtied = true, Rejoin = true }

-- HUD: top left by default, names from the rsg-core callsign
Config.Hud = { Enabled = true, Command = 'radiohud', Names = 'callsign', MaxRows = 8, Left = 18, Top = 18 }
```
For the `range_*` locale keys use the existing ones or add your own to all 11 `locales/*.json`.

### 19.2 Reading the battery from another script (server)
```lua
local charge = exports['rsg-radio']:GetBattery(src) -- 0-100, or nil when batteries are off / no radio
if charge and charge < 10 then
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = 'Radio', description = 'Your radio is nearly flat', type = 'warning' })
end
```

### 19.3 Reacting to a player going on or off the radio (server)
```lua
AddEventHandler('rsg-voice:server:radioChanged', function(src, newFreq, oldFreq)
    if newFreq == '160.0' then
        -- joined the lawman dispatch frequency
    elseif oldFreq == '160.0' and not newFreq then
        -- left it
    end
end)
```

### 19.4 Hooking the radio to your own signal source (client, rsg-voice exports)
```lua
-- e.g. a storm script lowering reception: 1.0 clear, 0.0 none (0.0 also blocks transmitting)
exports['rsg-voice']:SetRadioSignal(0.4)
-- ...and back to normal
exports['rsg-voice']:SetRadioSignal(1.0)
```
rsg-radio hands its own signal (from `Config.Interference`) and the player's volume and mute to rsg-voice whenever one of them changes, which overwrites a value you set. Use this example only when `Config.Interference.Enabled = false`, and set the signal again after the player changes volume or mute.

### 19.5 Phone calls over the radio (client, rsg-voice exports)
```lua
exports['rsg-voice']:SetCallActive(true)  -- radio and party voice are blocked and muted per rsg-voice Config.Priority.Call
-- ...call ends
exports['rsg-voice']:SetCallActive(false)
```
rsg-telephone 3.1.1 does this for you.

### 19.6 Handheld animation only (no prop)
```lua
Config.Handheld = {
    Enabled = true, Model = nil,
    Anim       = { dict = 'amb_wander@code_human_wander@male@generic',   clip = 'rub_neck_01', flag = 18 },
    AnimFemale = { dict = 'amb_wander@code_human_wander@female@generic', clip = 'rub_neck_01', flag = 18 },
}
```
Untested in game. Flag 18 is upper body and holds the last frame; use 31 for a looping clip.
