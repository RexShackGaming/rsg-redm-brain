# rsg-lawman 3.4.0 — Developer Docs

## Contents
- [Overview](#overview) · [Files](#files) · [Configuration](#configuration) · [Security model](#security-model)
- [Exports](#exports) · [Callbacks](#callbacks) · [Events](#events) · [Commands](#commands) · [Items](#items)
- [NUI](#nui) · [Locales](#locales) · [Integration examples](#integration-examples) · [Troubleshooting](#troubleshooting)

## Overview
Law enforcement tools for RSG Framework: law office menu (duty, armoury, storage), soft/hard cuffing, escorting, searching, frisk and seize, jailing (hands off to rsg-prison), fines (rsg-society), holding cells, `/911` reports, typed map alerts for on-duty `leo` jobs, optional gunshot alerts, outlaw cooldown, Discord log and an optional rsg-reputation hook.
Dependencies: `rsg-core`, `rsg-inventory`, `oxmysql`. Optional: `rsg-reputation`, `rsg-prison` (jailing), `rsg-society` (`/fine`), `rsg-shops` (armoury event `rsg-shops:server:openstore`). No ox_lib. No database tables of its own (`AddOutlawStatus` uses `players.outlawstatus` from rsg-core).

A player counts as law when their job **type** is `leo`. Job names are only used to match a law office (`jobaccess`).

## Files
| File | Purpose |
|---|---|
| `config.lua` | all settings and law office locations |
| `client/client.lua` | menu/NUI glue, prompts, cuff/escort state, alert blips, search, death alerts |
| `server/server.lua` | commands, validation, jail, cuff/escort decisions, storage, alerts, exports |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI (menu and numeric input) |
| `locales/*.json` | 13 languages |

## Configuration
| Option | Default | Description |
|---|---|---|
| `Config.AddGPSRoute` | `true` | GPS route to the newest alert |
| `Config.AlertTimer` | `60` | seconds an alert blip stays |
| `Config.Keybind` | `'J'` | prompt key at law offices |
| `Config.StorageMaxWeight` / `StorageMaxSlots` | `4000000` / `50` | law storage size |
| `Config.ArmouryAccessGrade` | `1` | minimum grade level for the armoury |
| `Config.EnablePlayerDeathAlerts` | `false` | alert when a player dies |
| `Config.EnableNPCDeathAlerts` | `false` | alert when an NPC dies near a player |
| `Config.AlertCooldown` | `30000` | ms between automatic alerts per player |
| `Config.AlertDistance` | `100.0` | NPC death alert range |
| `Config.RequireOnDuty` | `true` | cuff, escort, search, jail, unjail need on-duty |
| `Config.ActionDistance` | `4.0` | server-side max distance for cuff / escort |
| `Config.JailDistance` | `10.0` | server-side max distance for jailing (`0` = off) |
| `Config.MaxJailTime` | `180` | longest sentence in minutes |
| `Config.CuffFreezePlayer` | `false` | `true` = every cuff is hard (frozen); otherwise `/cuff hard` |
| `Config.SearchTime` | `10000` | search progress bar in ms (`0` = instant) |
| `Config.SearchDistance` | `2.5` | search range |
| `Config.SearchRequireRestrained` | `true` | target must be restrained |
| `Config.AlertTowns` / `AlertWilderness` | table / `'Wilderness'` | town names used in automatic alerts |
| `Config.LawOfficeLocations` | 5 offices | `name, prompt, coords, jobaccess, blipsprite, blipscale, showblip` |
| `Config.UseKeyMapping` | `true` | register the rebindable jail key (rsg-core `RegisterKey`; no polling fallback because there is no default key) |
| `Config.JailNearKey` | `''` | default key for "jail closest player"; empty = unbound until the player binds it in the game's key settings |
| `Config.Frisk` | table | `Enabled, RequireRestrained, Weapons, IgnoreCategories, ExtraItems, MaxListed` |
| `Config.Fines` | table | `Enabled, MaxReasonLength`; amount limits come from rsg-society `Config.Fines` |
| `Config.Report` | table | `/911`: `Enabled, Cooldown (s), MaxLength` |
| `Config.AlertTypes` | table | per type `sprite, scale, ringScale, timer, notify`; `default`, `gunshot`, `death`, `report` |
| `Config.GunshotAlerts` | off | `Enabled, TownRadius, Cooldown` |
| `Config.OutlawDecay` | off | `Enabled, Interval (min), Amount` |
| `Config.HoldingCells` | empty | `['<jobaccess>'] = { cell = vector4, release = vector4, minutes = 5 }` |
| `Config.Discord` | off | `Enabled, Webhook, Username, Avatar, Color` |
| `Config.Reputation` | table | `Enabled, Action = 'arrest', MinMinutes, Cooldown` |
| `Config.AllowPushToTalkWhileOpen` / `PushToTalkControls` | `true` / PTT | push-to-talk while the NUI is open |

## Security model
Every server event re-validates the caller. Clients only say *what they want*; the server works out the rest.
| Action | Server checks |
|---|---|
| Search | law job, on duty, target is the closest player (server-side), within `SearchDistance + 1`, target restrained (metadata, or asked from the target's client) |
| Cuff | law job, on duty, valid target, `ActionDistance`, `handcuffs` item; server flips `ishandcuffed` |
| Escort | law job, on duty, valid target, `ActionDistance`, target cuffed or dead (or already escorted = release) |
| Fine | law job, on duty, valid target, `JailDistance`, amount integer > 0, rsg-society checks the `fines` permission and its own limits |
| Frisk / seize | same rules as search; a seized item must be on the target's server-side contraband list; the lawman needs room (`CanAddItem`) |
| Holding cell | law job, on duty, at own office, target cuffed and within `ActionDistance`, cell configured for that job |
| /911 | any player, cooldown, length cap, position from the server, refused when nobody is on duty |
| Jail | law job, on duty, integer minutes `1..MaxJailTime`, valid target, `JailDistance`, target not already jailed |
| Storage | law job, standing at an office of the player's own job; job read on the server |
| Alert (net event) | string only, control characters stripped, 150 chars, one per 4 s, position within 250 of the sender |
| `sethandcuffstatus`, `setescortstatus` | boolean only, only the caller's own flag |

Not covered here: the armoury event `rsg-shops:server:openstore` can be fired by any client, so the shop resource must check job and grade itself. `rsg-lawman:server:lawmanAlert` can still be spammed with free text by a modified client; resources that raise alerts from the server should use `exports['rsg-lawman']:SendAlert`.

## Exports
All server side.
| Export | Returns | Description |
|---|---|---|
| `SendAlert(coords, text, alertType?)` | `boolean` | send a map alert to on-duty `leo` players. `coords` must be a `vector3`, `text` a non-empty string (cut to 150), `alertType` a key of `Config.AlertTypes` (default `default`) |
| `AddOutlawStatus(src, amount)` | `boolean` | add (or remove with a negative number) outlaw status, floored at 0 |

## Callbacks
| Callback | Side | Arguments | Returns |
|---|---|---|---|
| `rsg-lawman:server:getlaw` | server | — | number of on-duty `leo` players |
| `rsg-lawman:client:isSearchable` | client (asked by the server) | — | `true` when the player has hands up, is hogtied, lassoed, cuffed, dead or ragdolled |

## Events
Server events are reachable from any client and are validated as described above.
| Event | Side | Arguments | Notes |
|---|---|---|---|
| `rsg-lawman:client:mainmenu` | client | `jobaccess, name` | opened by the office prompt |
| `rsg-lawman:client:openarmoury` | client | — | triggers `rsg-shops:server:openstore` |
| `rsg-lawman:client:openstorage` | client | — | asks the server to open the storage |
| `rsg-lawman:client:ToggleDuty` | client | — | local event, triggers `RSGCore:ToggleDuty` |
| `rsg-lawman:client:jailplayer` | client | `[playerId, time]` | with both: sends to the server; without: asks for minutes via the NUI for the closest player |
| `rsg-lawman:client:sendtojail` | client | `time` | clears cuffs, hands over to `rsg-prison:client:Enter`. Used by rsg-mdt and rsg-bountyhunter |
| `rsg-lawman:client:lawmanAlert` | client | `coords, text, alertType?` | alert blip with its own timer, styled by `Config.AlertTypes` |
| `rsg-lawman:client:frisk` / `friskResult` | client | `— / list` | `/frisk`; the server answers with `{ name, label, amount }[]` |
| `rsg-lawman:client:heldInCell` / `releasedFromCell` | client | `cell / release` | server-driven teleports for holding cells |
| `rsg-lawman:client:cuffplayer` | client | `hard?` | cuff the closest player (radial menu, `/cuff [hard]`, item) |
| `rsg-lawman:client:getcuffed` | client | `lawmanSrc, isSoftcuff, state, hard` | `state` true/false sets cuffs; no `state` toggles (rsg-adminmenu) |
| `rsg-lawman:client:escortplayer` | client | — | escort / release the closest player |
| `rsg-lawman:client:getescorted` | client | `draggerSrc, state` | `state` true/false; no `state` toggles |
| `rsg-lawman:client:lawbadge` | client | — | toggle the badge |
| `rsg-lawman:client:searchplayer` | client | — | progress bar, then asks the server |
| `rsg-lawman:server:SearchPlayer` | server | — | target is never sent by the client |
| `rsg-lawman:server:jailplayer` | server | `playerId, minutes` | |
| `rsg-lawman:server:cuffplayer` | server | `playerId, isSoftcuff, hard` | |
| `rsg-lawman:server:frisk` | server | — | target worked out on the server |
| `rsg-lawman:server:seize` | server | `itemName` | must be on the target's current contraband list |
| `rsg-lawman:server:escortplayer` | server | `playerId` | |
| `rsg-lawman:server:lawmanAlert` | server | `text, coords, alertType?` | clients may only pick `gunshot` or `death`; anything else becomes `default` |
| `rsg-lawman:server:storage` | server | — | argument ignored; job read on the server |
| `rsg-lawman:server:sethandcuffstatus` | server | `boolean` | own flag only |
| `rsg-lawman:server:setescortstatus` | server | `boolean` | own flag only |

Removed in 3.3.0: `rsg-lawman:server:updateoutlawstatus` (use the `AddOutlawStatus` export).

## Commands
All need a law job (`leo`) and, with `Config.RequireOnDuty`, to be on duty, except `/testalert` (admin) and `/searchplayer` (job checked by the server when it runs).
`/testalert`, `/searchplayer`, `/lawbadge`, `/jail <id> <minutes>`, `/jailnear`, `/unjail <id>`, `/cuff [hard]`, `/escort`, `/frisk`, `/fine <id> <amount> <reason>`, `/holdcell <id>`, `/releasecell <id>`.
`/911 <message>` is open to every player. The jail-closest key is rebindable in the game's key settings (`Config.UseKeyMapping`, `Config.JailNearKey`).

### Fines
`/fine` calls rsg-society `IssueFine(src, targetId, society, amount, reason)` with the lawman's **job name as the society name**. The lawman needs that society's `fines` permission; amount limits and issue limits are rsg-society's (`Config.Fines`).

### Holding cells
Set `Config.HoldingCells[<office jobaccess>]`. `/holdcell <id>` needs a cuffed player within `ActionDistance` and the lawman at their own office. The player is teleported into the cell and released after `minutes` (or by `/releasecell`). The flag `inholdcell` is stored in metadata, so a player who logs in still flagged is released.

### Discord log
Set `Config.Discord.Enabled = true` and a webhook. Logged: jail, fine, seizure, cell hold (labels are English, for staff).

## Items
`handcuffs` — useable item, cuffs the closest player. Needed for cuffing and uncuffing.

## NUI
- `html/index.html`, `style.css`, `script.js` in the house RDR2 style (no vignette, no native select).
- Messages: `openMenu { title, subtitle, options[{ id, title, description, icon, disabled }] }`, `openInput { title, label, confirm, cancel, max }`, `close`.
- Callbacks: `menuSelect { id }`, `inputSubmit { value|null }`, `close`. Menu actions run from a local table, so the NUI cannot trigger arbitrary events.
- Esc closes, Enter confirms; digits only, within `1..max`. Push-to-talk stays usable.

## Locales
`en` (master), `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`, plus `cs`, `it`. Same 92 keys in every file. Set the language with `setr rsg:locale "en"`.

## Integration examples
```lua
-- server: raise an alert from your own script
exports['rsg-lawman']:SendAlert(GetEntityCoords(GetPlayerPed(src)), 'Bank robbery in progress')

-- server: raise outlaw status
exports['rsg-lawman']:AddOutlawStatus(src, 5)

-- server: hand a player to the jail flow after your own checks
TriggerClientEvent('rsg-lawman:client:sendtojail', targetSrc, minutes)
```

## Troubleshooting
| Problem | Check |
|---|---|
| Menu says not authorised | the player's job name must equal the office `jobaccess` |
| "Need to be on duty" | `Config.RequireOnDuty`; toggle duty from the law office menu |
| Search does nothing | target must be restrained; `Config.SearchRequireRestrained`; stand within `Config.SearchDistance` |
| "Target is too far away" | raise `Config.ActionDistance` / `Config.JailDistance` if players lag |
| Armoury opens nothing | `rsg-shops` must be started and handle `rsg-shops:server:openstore` |
| Jailed player not teleported | `rsg-prison` must be started |

## Changelog
See `CHANGELOG.md`.

Support: https://rexshack.tebex.store
