# rsg-voice

Proximity voice for **RSG Framework (RedM)**, built on RedM's native Mumble voice. It adds selectable voice ranges, a draggable HUD, riding parties (group voice), automatic muting while dead or cuffed, and a server-enforced admin mute.

---

## Features

- **Proximity voice ranges**: Whisper (2.5m), Normal (8m), Shout (20m) and Trail (35m), all configurable.
- **Cycle range** with a key (default **]**) or the `/voice` command. Your last range is remembered between sessions.
- **Range ring**: a ground ring briefly shows how far your voice carries when you change range.
- **Always hear shouting**: you hear players out to the largest range, whatever your own range is.
- **Draggable HUD**: a compact indicator shows your range, a talking light and your muted state. Move it with `/voicehud`; each player's position is saved on their own client.
- **Muffled voices**: players in a different interior (you're inside, they're outside, or another building) sound quieter.
- **Speaker icon** above nearby players while they talk (amber when a party member is using party talk).
- **Auto-mute** while dead or in last stand, and optionally while cuffed (read from rsg-core metadata).
- **Admin mute**: `/voicemute [id] [minutes] [reason]` mutes on the server, so the player's client can't undo it. Mutes can be timed or permanent, carry a reason, are tied to the player's licence and are saved in the database, so they survive reconnects and server restarts. `/voiceunmute [id]` lifts them.
- **Riding parties**: `/party` opens a menu to invite nearby riders (up to 8). Hold **[** to talk to party members within 100 m, even past your normal range. Party members show on your map, and `/partywaypoint` shares your map waypoint (with a GPS route) with the party.
- **Exports** (client and server) so other resources can read talking/range/party state and mute players, e.g. rsg-prison or rsg-hanging.
- **State bag**: `Player(src).state.voiceRange` holds each player's current range.
- **rsg-core** notifications, callbacks and locales in 10 languages: en, de, el, es, fr, ja, nl, pl, pt-br, ro. No ox_lib needed.
- Leather & gold themed UI, no vignette.

---

## Requirements

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core) (3.0.3+, provides locales, notify and callbacks)
- [oxmysql](https://github.com/overextended/oxmysql) (saved admin mutes)

> Do **not** run another voice resource (pma-voice, saltychat, etc.) alongside this one. They will fight over voice settings.

---

## Installation

1. The `rsg_voice_mutes` table is created automatically on first start (`install.sql` is included if you prefer to run it yourself).
2. Drop the `rsg-voice` folder into your `resources` directory (for example `resources/[rsg]/rsg-voice`).
3. Add the voice settings and the resource to your `server.cfg`, after `rsg-core`:

```cfg
# Native voice
setr voice_useNativeAudio true
setr voice_use3dAudio true
setr voice_useSendingRangeOnly true

# Language (en, de, el, es, fr, ja, nl, pl, pt-br, ro)
setr rsg:locale en

ensure oxmysql
ensure rsg-core
ensure rsg-voice
```

4. `/voicemute` and `/voiceunmute` use rsg-core permissions: anyone with the `admin` permission (or higher: headadmin, developer, god) can use it.

5. Restart the server.

---

## Usage

### Players

| Action | How |
|---|---|
| Cycle voice range | Press **]**, or type `/voice` |
| Move the HUD | Type `/voicehud`, drag the box, then press **ENTER** / **ESC** to save or **R** to reset |
| Hide / show the HUD | Type `/togglevoicehud` (remembered between sessions) |
| Riding party | Type `/party` to invite nearby riders or manage your party. Hold **[** to talk to party members within 100 m |
| Share waypoint | Set a map waypoint and type `/partywaypoint` (or use **Share Waypoint** in the party menu). Run it with no waypoint set to clear it for the party |

HUD indicators:
- **Bars**: current range (more bars means a larger range)
- **Green dot**: you are talking
- **Red dot and struck-through label**: you are muted
- **Amber dot and ⚑ tag**: you are talking to your party (the tag shows party size)

### Admins

| Command | Description |
|---|---|
| `/voicemute [id] [minutes] [reason]` | Server-enforced voice mute. Leave minutes blank or 0 for permanent. Re-running it updates the mute |
| `/voiceunmute [id]` | Remove a voice mute |

Expired mutes are lifted automatically (checked every `Config.MuteExpiryCheck` seconds) and the player is told.

---

## Configuration

All settings are in `shared/config.lua`.

```lua
Config.Ranges = {
    { name = 'whisper', range = 2.5 },
    { name = 'normal',  range = 8.0, default = true },
    { name = 'shout',   range = 20.0 },
    { name = 'trail',   range = 35.0 },
}
```

| Option | Default | Description |
|---|---|---|
| `Config.Ranges` | see above | Voice ranges in metres. `default = true` sets the starting range. |
| `Config.CycleKey` | `0xA5BDCD3C` (RIGHTBRACKET) | Control hash used to cycle range |
| `Config.CycleCommand` | `'voice'` | Command to cycle range |
| `Config.ShowRangeRing` | `true` | Show a ground ring when changing range |
| `Config.RingDuration` | `1500` | How long the ring shows (ms) |
| `Config.RingColour` | white, alpha 90 | RGBA colour of the ring |
| `Config.ShowHud` | `true` | Show the voice HUD |
| `Config.HudEditCommand` | `'voicehud'` | Command to move the HUD |
| `Config.HudToggleCommand` | `'togglevoicehud'` | Command for a player to hide/show their own HUD (saved per client) |
| `Config.Party.Enabled` | `true` | Enable riding parties (group voice chat) |
| `Config.Party.Command` | `'party'` | Opens the party menu |
| `Config.Party.TalkKey` | `0x430593AA` (LEFTBRACKET) | Hold to talk to your party |
| `Config.Party.TalkRange` | `100.0` | Max distance (metres) party talk reaches |
| `Config.Party.InviteRange` | `10.0` | How close (metres) a player must be to be invited |
| `Config.Party.MaxMembers` | `8` | Max party size, leader included |
| `Config.Party.InviteTimeout` | `30` | Seconds an invite stays valid |
| `Config.MuteWhenDead` | `true` | Mute while dead or in last stand |
| `Config.MuteWhenCuffed` | `false` | Mute while handcuffed |
| `Config.SaveRange` | `true` | Remember each player's last range (client KVP) |
| `Config.AdminMuteCommand` | `'voicemute'` | Admin mute command |
| `Config.AdminUnmuteCommand` | `'voiceunmute'` | Admin unmute command |
| `Config.AdminPermission` | `'admin'` | rsg-core permission needed for the mute commands |
| `Config.MuteExpiryCheck` | `30` | Seconds between expired-mute checks |
| `Config.Muffle.Enabled` | `true` | Muffle players in a different interior |
| `Config.Muffle.Volume` | `0.35` | Volume (0–1) of muffled players |
| `Config.Muffle.Interval` | `500` | ms between volume checks |
| `Config.TalkIcon.Enabled` | `true` | Speaker icon above talking players |
| `Config.TalkIcon.Distance` | `15.0` | Max distance (metres) the icon shows |
| `Config.TalkIcon.ShowSelf` | `true` | Also show the icon above yourself while you talk |
| `Config.TalkIcon.Dict` / `Texture` | `overhead` / `overhead_speaker` | Sprite used (rdr3_discoveries `textures/overhead`) |
| `Config.Party.Blips.Enabled` | `true` | Show party members on the map |
| `Config.Party.Blips.Interval` | `3000` | ms between blip position updates |
| `Config.Party.Blips.Sprite` / `Modifier` | `blip_ambient_companion` / `BLIP_MODIFIER_MP_COLOR_8` | Blip icon and colour |
| `Config.Party.Waypoint.Enabled` | `true` | Allow waypoint sharing |
| `Config.Party.Waypoint.Command` | `'partywaypoint'` | Share/clear command |
| `Config.Party.Waypoint.Cooldown` | `5` | Seconds between shares |
| `Config.Party.Waypoint.GpsColour` | `'COLOR_YELLOW'` | GPS route colour |
| `Config.Party.Waypoint.ArriveDistance` | `20.0` | Shared waypoint clears when you get this close |

### Adding a range

Add an entry to `Config.Ranges`, then add a `range_<name>` key to each file in `locales/`:

```lua
{ name = 'megaphone', range = 40.0 },
```
```json
"range_megaphone": "Megaphone"
```

If a locale key is missing, the HUD shows the raw `name`. If you change `Config.Party.TalkKey`, update `ui_party_hint` in the locale files too.

---

## Exports (client)

```lua
-- Current range in metres
local range = exports['rsg-voice']:GetVoiceRange()

-- Set range by its index in Config.Ranges
exports['rsg-voice']:SetVoiceRangeIndex(3)

-- Is the local player muted (dead, cuffed, admin, script)?
local muted = exports['rsg-voice']:IsMuted()

-- Is someone talking? No argument = you, or pass a server id (must be streamed in)
local talking = exports['rsg-voice']:IsPlayerTalking(serverId)

-- Client-side mute held by your resource (e.g. a gag). Not enforced: use the server export for punishments
exports['rsg-voice']:SetMuteOverride(true, 'gag')
exports['rsg-voice']:SetMuteOverride(false, 'gag')

-- Party
local inParty = exports['rsg-voice']:IsInParty()
local members = exports['rsg-voice']:GetPartyMembers() -- { { id, name, leader }, ... } or nil
```

## Exports (server)

```lua
-- Server-enforced mute. Each resource holds its own mute (reason defaults to the calling resource),
-- and the player stays muted while any resource or an admin holds one.
exports['rsg-voice']:SetPlayerMuted(src, true)   -- e.g. from rsg-prison on jail
exports['rsg-voice']:SetPlayerMuted(src, false)  -- on release
local muted = exports['rsg-voice']:IsPlayerMuted(src)

-- Party
local inParty = exports['rsg-voice']:IsInParty(src)
local members, leader = exports['rsg-voice']:GetPartyMembers(src) -- { src, ... }, leaderSrc or nil
```

### State bag

```lua
-- Server or client
local range = Player(serverId).state.voiceRange
```

---

## Localisation

Locale files are in `locales/*.json`. Set the server language with `setr rsg:locale <code>` (falls back to `ox:locale`, then `en`).

Supported languages: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

---

## File structure

```
rsg-voice/
├── client/client.lua
├── server/server.lua
├── server/versionchecker.lua
├── shared/config.lua
├── html/index.html
├── locales/*.json
├── install.sql
└── fxmanifest.lua
```

---

## Changelog

### 3.0.3
- **Muffled voices** through interiors, **speaker icon** above talking players and **saved range** between sessions.
- **Timed admin mutes with reasons**, saved in the database (`install.sql`), plus `/voiceunmute`. Expired mutes lift automatically.
- **Party map blips** and **waypoint sharing** (`/partywaypoint` or the Share Waypoint button), with a GPS route that clears on arrival.
- New exports: `IsPlayerTalking`, `SetMuteOverride`, `GetPartyMembers`, `IsInParty` (client) and `SetPlayerMuted`, `IsPlayerMuted`, `GetPartyMembers`, `IsInParty` (server). Server mutes are tracked per source, so a resource mute and an admin mute don't cancel each other out.
- Removed the ox_lib dependency: notifications, callbacks, locales and the admin command now use rsg-core.
- The party invite is now an in-style NUI dialog with a countdown bar (ENTER to join, ESC to decline).
- Ignored invites are now cleaned up when they expire, so the inviter no longer stays stuck in an empty party shown as "In a party".
- Inviting a rider who already has someone else's invite open now tells you, instead of silently overwriting that invite.
- The voice range key and party talk key are ignored while the party menu or invite dialog is open.
- NUI focus is shared properly between the HUD editor, party menu and invite dialog, so closing one no longer drops focus from another.
- Party menu refreshes are rate-limited on the server; kick/invite IDs are validated.
- Party talk state is cleared on resource stop so other players don't keep hearing you.

### 3.0.2
- Admin mutes are now re-applied server-side when a character loads, so a modified client can't skip them after reconnecting.
- Party invites have a 3-second cooldown and can't be re-sent to a player who still has your invite open (stops dialog spam).
- A party left with only the leader (invite declined, expired, or invitee disconnected) is now cleaned up instead of lingering.
- The invite timeout no longer closes unrelated ox_lib dialogs.
- Added the missing `range_trail` label in all locales; the party hint now shows the correct key (**[**).
- Removed the unused `cl_hud_party` locale key and redundant menu refreshes.

---

## Support

If you find this useful, you can support development here: https://buymeacoffee.com/rexshack
