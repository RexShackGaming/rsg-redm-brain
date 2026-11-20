# rsg-robbery — Developer Docs

## Overview
Player-to-player robbery: target a player with hands up via rsg-target, cuff them, and open their inventory. Victims can be uncuffed by the robber, by another player, or auto-uncuff after `Config.AutoUncuffTime`.

## Dependencies
- `rsg-core` (locales, notify)
- `rsg-inventory` (with the one-line cuffed-target fix from the README)
- `rsg-target`

No ox_lib dependency — locales load from `@rsg-core/shared/locale.lua` and notifications use `RSGCore:Client:Notify`.

## Files
| File | Purpose |
|---|---|
| `shared/config.lua` | Distances, cooldown, auto-uncuff timer |
| `client/client.lua` | rsg-target global player options (`rob_player`, `uncuff_player`), cuff animation/effects |
| `server/server.lua` | Validation (distance, cooldown, handcuffs item, vehicle, cuffed state), cuff metadata, uncuff, auto-uncuff |
| `server/versionchecker.lua` | Checks GitHub for updates |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## Config
| Key | Default | Description |
|---|---|---|
| `Config.RobDistance` | 2.5 | Max distance to rob |
| `Config.CuffDistance` | 1.5 | Max distance to cuff |
| `Config.RobCooldown` | 30000 | ms between robberies |
| `Config.AutoUncuffTime` | 120000 | ms before auto-uncuff (0 = off) |

## Localisation
Set the language with `setr rsg:locale <code>`. Keys live under `robbery.*`.

## Security
All checks (distance, cooldown, item, state) are server-side; client target options only request the action.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-robbery 3.0.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.RobDistance` | `2.5` |  |
| `Config.CuffDistance` | `1.5` |  |
| `Config.ConsumeHandcuffs` | `false` |  |
| `Config.RobCooldown` | `30000` |  |
| `Config.HandcuffItem` | `'handcuffs'` |  |
| `Config.AutoUncuffTime` | `120000` |  |

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-robbery:client:verifyhandsup` | client | `robberId` | `client/client.lua` |
| `rsg-robbery:client:getcuffed` | client | `` | `client/client.lua` |
| `rsg-robbery:client:uncuffed` | client | `` | `client/client.lua` |
| `rsg-robbery:server:robplayer` | server | `targetId` | `server/server.lua` |
| `rsg-robbery:server:confirmrobbery` | server | `robberId` | `server/server.lua` |
| `rsg-inventory:server:closeInventory` | server | `inventory` | `server/server.lua` |
| `rsg-robbery:server:uncuffplayer` | server | `targetId` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-robbery:server:robplayer', targetId)
-- from a server script
TriggerClientEvent('rsg-robbery:client:verifyhandsup', source, robberId)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/uncuff` | locale('robbery.uncuff_self_help') | `server/server.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
