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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

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
