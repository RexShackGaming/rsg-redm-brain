# rsg-voice – Docs (v3.0.4)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports, events and commands
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `oxmysql` |
| `shared/config.lua` | Ranges, HUD, mute, muffle, talk icon, party |
| `client/client.lua` | Ranges, HUD, muffle, talk icon, party, exports |
| `server/server.lua` | Admin mutes, party management, exports |
| `server/versionchecker.lua` | GitHub version check |
| `html/index.html` | HUD |
| `install.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
Proximity voice on RedM's native Mumble voice.
- **Ranges:** Whisper 2.5 m, Normal 8 m (default), Shout 20 m, Trail 35 m. Cycle with `]` or `/voice`; the last range is remembered. A ground ring shows the range briefly.
- You always hear shouting out to the largest range, whatever your own range is.
- **HUD:** compact indicator (range, talking light, muted). Move it with `/voicehud`; hide/show with `/togglevoicehud`. Position is saved per client.
- **Muffled voices:** players in a different interior sound quieter.
- **Speaker icon** above nearby players while they talk (amber for party talk).
- **Auto-mute** while dead or in last stand, and optionally while cuffed (rsg-core metadata).
- **Admin mute:** server-enforced, saved in the database by licence, timed or permanent, with a reason.
- **Riding parties:** `/party` opens a menu to invite nearby riders (up to 8). Hold `[` to talk to party members within 100 m. Party members show on the map, and `/partywaypoint` shares a waypoint.

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `Ranges` | list | `{ name, range, default? }` |
| `CycleKey` / `CycleCommand` | `]` / `'voice'` | Change range |
| `SaveRange` | `true` | Remember last range (client KVP) |
| `ShowRangeRing`, `RingDuration`, `RingColour` | | Ground ring |
| `ShowHud`, `HudEditCommand`, `HudToggleCommand` | `true`, `voicehud`, `togglevoicehud` | HUD |
| `MuteWhenDead` / `MuteWhenCuffed` | `true` / `false` | Auto-mute |
| `AdminMuteCommand` / `AdminUnmuteCommand` | `voicemute` / `voiceunmute` | Admin commands |
| `AdminPermission` | `'admin'` | Permission needed |
| `MuteExpiryCheck` | `30` | Seconds between expiry checks |
| `Muffle` | table | `Enabled`, `Volume` (0.35), `Interval` |
| `TalkIcon` | table | `Enabled`, `Distance`, `ShowSelf`, texture, size, colours |
| `Party` | table | `Enabled`, `Command`, `TalkKey`, `TalkRange` (100), `InviteRange` (10), `MaxMembers` (8), `InviteTimeout` (30), `Blips`, `Waypoint` |

## 4. Exports, events and commands
### Client exports
| Export | Returns |
|---|---|
| `GetVoiceRange()` | Current range in metres |
| `SetVoiceRangeIndex(i)` | Set the range by index |
| `IsMuted()` | bool |
| `IsPlayerTalking(serverId)` | bool |
| `SetMuteOverride(state, reason)` | Force mute from a script |
| `GetPartyMembers()` / `IsInParty()` | Party info |

### Server exports
| Export | Notes |
|---|---|
| `SetPlayerMuted(src, state, reason)` | e.g. `exports['rsg-voice']:SetPlayerMuted(src, true, 'prison')` |
| `IsPlayerMuted(src)` | bool |
| `GetPartyMembers(src)` | `{ src, ... }, leaderSrc` or nil |
| `IsInParty(src)` | bool |

### Events and callbacks
| Name | Side | Notes |
|---|---|---|
| `rsg-voice:server:isMuted` | callback | Mute state for the caller |
| `rsg-voice:server:getParty` | callback | Current party |
| `rsg-voice:server:partyInvite` / `partyRespond` / `partyKick` / `partyLeave` / `partyWaypoint` | server events | Party actions |
| `rsg-voice:client:muteState` | client event | `(state)` |
| `rsg-voice:client:partyUpdate` / `partyInvite` / `partyPositions` / `partyWaypoint` | client events | Party UI and blips |

### Commands
| Command | Who | What |
|---|---|---|
| `/voice` | everyone | Cycle range |
| `/voicehud`, `/togglevoicehud` | everyone | Move / hide the HUD |
| `/party`, `/partywaypoint` | everyone | Party menu, share waypoint |
| `/voicemute [id] [minutes] [reason]` | admin | Mute (0 or blank = permanent) |
| `/voiceunmute [id]` | admin | Unmute |

## 5. Database
```sql
CREATE TABLE IF NOT EXISTS `rsg_voice_mutes` (
    `license`    VARCHAR(64)  NOT NULL,
    `reason`     VARCHAR(255) DEFAULT NULL,
    `muted_by`   VARCHAR(100) DEFAULT NULL,
    `expires_at` INT UNSIGNED DEFAULT NULL, -- unix time, NULL = permanent
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`license`)
);
```
Mutes are tied to the player's licence, so they survive reconnects.

## 6. Security
Admin mutes are enforced on the server, so the client can't undo them. Party invites check range, member cap and timeout on the server. Admin commands are permission-checked.

## 7. How-tos
- Mute a player from a script: `exports['rsg-voice']:SetPlayerMuted(src, true, 'jail')`.
- Change ranges by editing `Config.Ranges`.
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| Nobody hears anyone | Enable native Mumble voice in the server config |
| Can't talk after unmute | Check `MuteWhenDead`/`MuteWhenCuffed` and `SetMuteOverride` calls |
| HUD missing | `ShowHud`, or the player toggled it off |
| Party invite fails | Target must be within `InviteRange` |

Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-voice 3.0.4**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`

### Database

Tables: `rsg_voice_mutes`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `install.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.Ranges` | `table` | Voice ranges (metres). The entry with default = true is used on spawn. |
| `Config.CycleKey` | `0xA5BDCD3C` | RIGHTBRACKET |
| `Config.CycleCommand` | `'voice'` |  |
| `Config.SaveRange` | `true` | remember each player's last range between sessions (client KVP) |
| `Config.ShowRangeRing` | `true` | Ground ring shown when changing range |
| `Config.RingDuration` | `1500` |  |
| `Config.RingColour` | `{ r = 255, g = 255, b = 255, a = 90 }` |  |
| `Config.ShowHud` | `true` | HUD |
| `Config.HudEditCommand` | `'voicehud'` | drag the HUD box to move it |
| `Config.HudToggleCommand` | `'togglevoicehud'` | players can hide/show their own HUD (saved per client) |
| `Config.MuteWhenDead` | `true` | Auto-mute (rsg-core metadata) |
| `Config.MuteWhenCuffed` | `false` |  |
| `Config.AdminMuteCommand` | `'voicemute'` | /voiceunmute [id] |
| `Config.AdminUnmuteCommand` | `'voiceunmute'` |  |
| `Config.AdminPermission` | `'admin'` |  |
| `Config.MuteExpiryCheck` | `30` | seconds between checks for expired mutes |
| `Config.Muffle` | `table` | Muffled voices: players in a different interior (inside vs outside, another building) sound quieter |
| `Config.Enabled` | `true` |  |
| `Config.Volume` | `0.35` |  |
| `Config.Interval` | `500` |  |
| `Config.TalkIcon` | `table` | Texture: overhead / overhead_speaker (rdr3_discoveries textures/overhead) |
| `Config.Distance` | `15.0` |  |
| `Config.ShowSelf` | `false` |  |
| `Config.Dict` | `'overhead'` |  |
| `Config.Texture` | `'overhead_speaker'` |  |
| `Config.Size` | `0.022` |  |
| `Config.ZOffset` | `1.05` |  |
| `Config.Colour` | `{ r = 255, g = 255, b = 255, a = 220 }` |  |
| `Config.PartyColour` | `{ r = 217, g = 164, b = 65,  a = 230 }` |  |
| `Config.Party` | `table` | Party members within TalkRange hear each other while holding the party talk key. |
| `Config.Command` | `'party'` |  |
| `Config.TalkKey` | `0x430593AA` |  |
| `Config.TalkRange` | `100.0` |  |
| `Config.InviteRange` | `10.0` |  |
| `Config.MaxMembers` | `8` |  |
| `Config.InviteTimeout` | `30` |  |
| `Config.Blips` | `table` | Map blips for your party members |
| `Config.Waypoint` | `table` | Share your map waypoint with the party (/partywaypoint, run again with no waypoint to clear) |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `SetPlayerMuted` | `src, state, reason` | `server/server.lua` |
| `IsPlayerMuted` | `src` | `server/server.lua` |
| `GetPartyMembers` | `` | `server/server.lua` |
| `IsInParty` | `src` | `server/server.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `GetVoiceRange` | `` | `client/client.lua` |
| `SetVoiceRangeIndex` | `i` | `client/client.lua` |
| `IsMuted` | `` | `client/client.lua` |
| `IsPlayerTalking` | `sid` | `client/client.lua` |
| `SetMuteOverride` | `state, reason` | `client/client.lua` |
| `GetPartyMembers` | `` | `client/client.lua` |
| `IsInParty` | `` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-voice']:SetPlayerMuted(src, state, reason)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-voice:server:isMuted` | server | `src, cb` | `server/server.lua` |
| `rsg-voice:server:getParty` | server | `src, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-voice:server:isMuted', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `RSGCore:Player:SetPlayerData` | client | `data` | `client/client.lua` |
| `rsg-voice:client:muteState` | client | `state` | `client/client.lua` |
| `rsg-voice:client:partyPositions` | client | `list` | `client/client.lua` |
| `rsg-voice:client:partyWaypoint` | client | `c, fromName` | `client/client.lua` |
| `rsg-voice:client:partyUpdate` | client | `data` | `client/client.lua` |
| `rsg-voice:client:partyInvite` | client | `fromName, timeout` | `client/client.lua` |
| `rsg-voice:server:partyInvite` | server | `target` | `server/server.lua` |
| `rsg-voice:server:partyRespond` | server | `accept` | `server/server.lua` |
| `rsg-voice:server:partyKick` | server | `target` | `server/server.lua` |
| `rsg-voice:server:partyLeave` | server | `` | `server/server.lua` |
| `rsg-voice:server:partyWaypoint` | server | `coords` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-voice:server:partyInvite', target)
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerLoaded', source)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
