# rsg-radio – Docs (v3.0.0)

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
| `shared/config.lua` | Item, command, frequency format, favorites, restricted channels, key settings |
| `install.sql` | Schema of `rsg_radio_private` (same as the automatic build) |
| `server/server.lua` | Database build, private channels, staff commands, live updates, item registration/use, frequency validation, joining and leaving through rsg-voice, favorites, periodic access checks, export |
| `client/client.lua` | Command, NUI focus with push-to-talk whitelist, NUI callbacks that forward to the server |
| `html/index.html` | Tuning panel (NUI): frequency tuner, favorites, channel list, drag-to-move |
| `installation/shared_items.lua` | Item line for manual install (`Config.RegisterItem = false`) |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru (identical keys) |
| `CHANGELOG.md` | Version history |

## 3. Installation

1. Update **rsg-voice to 3.1.3 or later**.
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
| `Config.TransmitKeyLabel` | `'O'` | Text of the "Hold O to transmit" hint only. Keep in line with rsg-voice `Config.Radio.Key` |
| `Config.AllowPushToTalkWhileOpen` | `true` | While the panel is open: `SetNuiFocusKeepInput(true)` plus a control whitelist so voice keys keep working |
| `Config.PushToTalkControls` | `{ 0x4BC9DABB }` | Controls left enabled while the panel is open (N, push-to-talk) |

Things that live in **rsg-voice** `Config.Radio`: `Enabled`, `UseKeyMapping`, `Key` (default `'O'`), `TalkKey` (fallback control hash), `NearbyHear`, `MaxMembers`, `Static` (radio sound), `Debug`.

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
4. **Checks**: every `Config.CheckInterval` seconds the server removes connected players who lost the item (`sv_lost_radio`) or their channel access (`sv_lost_access`: job change, off duty, gang change).
5. **Leave / cleanup**: Switch off in the panel, logout, disconnect (rsg-voice also removes players on `playerDropped` and `RSGCore:Server:OnPlayerUnload`). If something else removes the player from the channel, rsg-radio clears its record and updates the panel (`rsg-voice:server:radioChanged`).
6. **Restarts**: if rsg-voice restarts, rsg-radio rejoins everyone after 1.5 s. If rsg-radio restarts, it adopts players still on a channel in rsg-voice, and the next check removes those without the item.

## 9. API reference

### 9.1 Server exports

| Export | Returns | Notes |
|---|---|---|
| `exports['rsg-radio']:GetFrequency(src)` | frequency string or `nil` | The frequency the player tuned in with this radio |

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
| `rsg-voice:server:radioChanged` | server (listened) | `src, newFreq, oldFreq` | Used to keep `GetFrequency` correct |
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
| Per-player cooldowns (500 ms join/leave, 300 ms favorites) | join, leave, favorites |
| Favorites count, name cleaned and length-bounded | addFavorite |
| Radio and access re-checked every `CheckInterval` seconds | periodic check |

Other points:

- No client event can add a player to a channel. Membership is changed only on the server through rsg-voice's exports.
- Net events from other resources are ignored for the two client events (`GetInvokingResource`).
- The NUI escapes all text it renders (channel names, favorite names).
- Config is validated at start. Bad channel entries are skipped with a console warning instead of breaking the resource.
- Voice routing itself is done client-side by rsg-voice (as for party talk), so a modified client could aim its voice at players who are not on its channel. Do not use the radio for anything that must stay secret. This is a property of the voice layer, not of rsg-radio.
- Other scripts: never call `JoinRadio` from a net event without checking the player yourself.

## 12. Performance

- Client: idle at `Wait(250)`. A per-frame control whitelist runs **only** while the panel is open. The panel itself is static HTML.
- Server: one 10-second loop over connected players (one inventory check each). State building does one `GetRadioMembers` per restricted channel, only when a panel opens or a player joins/leaves/changes favorites.
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

---

Support: https://buymeacoffee.com/rexshack
