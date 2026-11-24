# rsg-zonenotify – Docs (v3.4.1)

Location banners, discoveries, rewards and an explorer's journal for the RSG Framework. This file is the full technical reference; [README.md](README.md) is the short overview.

## Contents
1. [Requirements and install](#1-requirements-and-install)
2. [Files](#2-files)
3. [How it works](#3-how-it-works)
4. [Configuration reference](#4-configuration-reference)
5. [Display modes, banners and the queue](#5-display-modes-banners-and-the-queue)
6. [Discoveries and place keys](#6-discoveries-and-place-keys)
7. [Rewards and milestones](#7-rewards-and-milestones)
8. [Journal, options and leaderboard](#8-journal-options-and-leaderboard)
9. [Commands and keybinds](#9-commands-and-keybinds)
10. [Exports](#10-exports)
11. [Events and callbacks](#11-events-and-callbacks)
12. [NUI messages](#12-nui-messages)
13. [Database](#13-database)
14. [Locales](#14-locales)
15. [Security model](#15-security-model)
16. [Server owner how-tos](#16-server-owner-how-tos)
17. [Troubleshooting](#17-troubleshooting)

---

## 1. Requirements and install
| Resource | Needed | Used for |
|---|---|---|
| `rsg-core` | yes | player data, callbacks, notifications, locales, `RegisterKey` |
| `oxmysql` | yes | discoveries and milestones |
| `rsg-skills` | optional | Explorer XP (skill registered automatically) |
| `rsg-reputation` | optional | town / state standing rewards |

`rsg-economy` is **not** used. ox_lib is not needed.

1. Put `rsg-zonenotify` in your resources folder.
2. `ensure rsg-zonenotify` after `rsg-core` and `oxmysql` (and after `rsg-skills` / `rsg-reputation` if you use them).
3. Tables are created on first start (`Config.AutoDatabase = true`). To install by hand set it to `false` and import `install.sql`.
4. Set the language with `setr rsg:locale "de"` in `server.cfg`.

No items, jobs or images are required.

## 2. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; locales via `@rsg-core/shared/locale.lua`; `ui_page html/index.html` |
| `shared/config.lua` | Every setting |
| `shared/zones.lua` | Zone hash tables (towns, districts, states, landmarks, water) plus `Zones.Keys` / `Kind` / `KindKeys` / `KindCount` / `Original`, used by client **and** server |
| `client/client.lua` | Zone checks, banners, discoveries, journal, options, commands, key mapping, client exports |
| `client/dataview.lua` | Buffer helper, only used by the `native` display mode |
| `server/server.lua` | Discovery storage, rewards, milestones, leaderboard, auto database, server exports |
| `server/versionchecker.lua` | GitHub version check |
| `html/index.html`, `script.js`, `style.css` | Banner NUI (queue, title fit, chimes) |
| `html/journal.js`, `journal.css` | Journal NUI |
| `html/sounds/` | Put your own `.ogg` / `.mp3` here |
| `install.sql` | Manual database install |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 3. How it works
**Zone check** – every `Config.CheckInterval` ms the client reads the map zone hashes for state, district and town with `_GET_MAP_ZONE_AT_COORDS` (0x43AD8FC02B429D33). When one changes:
1. `rsg-zonenotify:client:zoneChanged` fires for each mapped zone that was entered (state, then district, then town), whatever the banner settings are.
2. The most specific mapped zone becomes the *pending banner* (town > district > state; leaving a town re-shows the district).
3. If nothing else is pending, a landmark / water scan (every 1.5 s) queues a banner for any place the character has not found yet.

**Pending banner** – waits while something blocks it (pause menu, faded screen, dead, banners off, suppressed). It is dropped when the player leaves that zone (or rides 150 m away from a landmark). With banners switched off by the player the place is still recorded, silently.

**Discovery** – showing a banner for a place the character has not found marks it as discovered, adds the *New Discovery* stamp and plays the `discovery` sound, and sends `rsg-zonenotify:server:discover` (key + position) to the server. The server validates it, saves it, pays rewards and checks milestones (section 7).

**Names** – `Config.LabelNames` override, then the game's `GetLabelText`, then a readable fallback (`district_cumberland_forest` → `Cumberland Forest`). Results are cached.

## 4. Configuration reference
All settings are in `shared/config.lua`. Nested tables are written `Table.Option`.

### General
| Option | Default | Description |
|---|---|---|
| `CheckInterval` | `500` | ms between zone checks |
| `DisplayTime` | `5000` | ms a banner stays on screen |
| `DisplayMode` | `'nui'` | `'nui'` custom banner, `'native'` game banner, `'notify'` rsg-core notification |
| `WhileMoving` | `'native'` | native mode only: `'notify'`, `'wait'` or `'native'` while the player moves |
| `MovingSpeed` | `1.5` | m/s above which the player counts as moving (native mode) |
| `MaxFeedWait` | `3000` | native mode: ms to wait for a busy feed before showing anyway |
| `Debug` | `false` | prints zone hashes to F8 and enables `/zonetest` |
| `Notify.State` / `District` / `Town` | `true` | which zone changes show a banner |
| `Notify.LeaveTown` | `true` | show the district banner again when leaving a town |
| `HideWhileScriptedCam` | `true` | hide banners while a scripted camera renders |
| `BannerQueue` | `true` | `nui` mode: a banner waits for the current one (max 3 waiting, dropped after 15 s) |
| `PlayerOptions` | `true` | players can switch sound, time, temperature and wind off in the journal |

### Bottom line (time | temperature | wind)
| Option | Default | Description |
|---|---|---|
| `ShowTime` / `ShowTemperature` / `ShowWind` | `true` | show each part |
| `NightStart` / `NightEnd` | `22` / `6` | hours the night colour applies |
| `TimeDayColor` / `TimeNightColor` | `'~COLOR_WHITE~'` / `'~COLOR_BLUEDARK~'` | game colour codes |
| `TemperatureUnit` | `'celsius'` | `'celsius'`, `'fahrenheit'` or `'auto'` (game setting) |
| `TemperatureColdDegree` | `15` | °C below this uses the cold colour |
| `TemperatureHotColor` / `TemperatureColdColor` | `'~COLOR_YELLOWSTRONG~'` / `'~COLOR_BLUE~'` | |
| `SpeedUnit` | `'mph'` | `'mph'`, `'kmh'` or `'auto'` |
| `WindColor` | `'~COLOR_RADAR_CENTER_BLIP~'` | |
| `NuiColors` | table | maps each `COLOR_X` code above to a CSS colour for the `nui` banner |

### Where am I / keys
| Option | Default | Description |
|---|---|---|
| `UseKeyMapping` | `true` | `true` = rebindable keys (game key settings); `false` = fixed control hash polling |
| `Key` | `false` | default key **name** for "where am I", e.g. `'L'`. With `UseKeyMapping = false` a control hash such as `0x80F28E95`. `false` = no key |
| `Command` | `'location'` | `false` to disable |
| `ToggleCommand` | `'zonenotify'` | players switch banners on/off; `false` to disable |
| `ManualCooldown` | `3000` | ms between manual checks |

### Names and flavour lines
| Option | Description |
|---|---|
| `LabelNames` | `[labelKey] = 'Display name'` overrides. Use `Debug = true` to see label keys |
| `ZoneMessages` | `[labelKey] = 'locale_key'`: a line under the title. Ships with all states and the big towns |

### Discoveries and sound
| Option | Default | Description |
|---|---|---|
| `AutoDatabase` | `true` | create the tables on start; `false` = import `install.sql` |
| `Discovery.Enabled` | `true` | discovery tracking (turns rewards, journal places and leaderboard off when `false`) |
| `Discovery.ShowStamp` | `true` | *New Discovery* stamp |
| `Discovery.Landmarks` | `true` | one-time banners for landmarks, lakes and rivers |
| `Discovery.Command` | `'places'` | count command; `false` to disable |
| `Discovery.MaxPerPlayer` | `1000` | server cap per character |
| `Sound.Enabled` / `Sound.Volume` | `true` / `0.25` | banner sounds, volume 0.0–1.0 |
| `Sound.Files.<kind>` | `nil` | kinds `state`, `district`, `town`, `landmark`, `discovery`, `manual`, `custom`: `nil` built-in chime, `'sounds/x.ogg'` your file, `false` silent |

### Journal and leaderboard
| Option | Default | Description |
|---|---|---|
| `Journal.Enabled` | `true` | |
| `Journal.Command` | `'journal'` | `false` to disable |
| `Journal.Key` | `false` | default key name, e.g. `'J'` (needs `UseKeyMapping`) |
| `Journal.ShowUndiscovered` | `false` | `true` lists names of places not found yet (greyed), `false` shows `???` |
| `AllowPushToTalkWhileOpen` | `true` | keep push-to-talk working while the journal has focus |
| `PushToTalkControls` | `{ 0x4BC9DABB }` | controls left enabled while the journal is open |
| `Leaderboard.Enabled` | `true` | |
| `Leaderboard.Size` | `10` | rows (1–25) |
| `Leaderboard.CacheSeconds` | `300` | the list is rebuilt at most this often |
| `Leaderboard.Names` | `'initial'` | `'full'` (John Marston), `'initial'` (John M.), `'anonymous'` (Explorer #1) |

### Rewards and milestones
| Option | Default | Description |
|---|---|---|
| `Rewards.Enabled` | `true` | master switch for first-visit rewards |
| `Rewards.Cash.<kind>` | state 5, district 3, town 3, landmark 2, water 1 | cash via `AddMoney('cash', ...)` |
| `Rewards.XP.Skill` / `Label` | `'explorer'` / `'Explorer'` | rsg-skills skill and its display name |
| `Rewards.XP.Amounts.<kind>` | 40 / 25 / 25 / 15 / 10 | XP per kind |
| `Rewards.Standing.Amount` | `1` | rsg-reputation standing for a first visit to a listed town or state |
| `Rewards.Standing.Regions` | table | `[placeKey] = rsg-reputation region` |
| `Rewards.MinInterval` | `8` | seconds between two paid discoveries |
| `Rewards.MinTravel` | `40.0` | metres between two paid discoveries |
| `Rewards.MaxCoordGap` | `60.0` | metres the reported position may differ from the server's position |
| `Rewards.MaxPerDay` | `40` | paid discoveries per character per database day |
| `Milestones.Enabled` | `true` | |
| `Milestones.Categories.<kind>` | `{ cash, xp }` | paid once when every place of the category is found |
| `Milestones.Overall[<percent>]` | 25 / 50 / 75 / 100 | paid once at that percentage of all places |

`<kind>` is `state`, `district`, `town`, `landmark` or `water`. Set an amount to `0` to turn that reward off.

## 5. Display modes, banners and the queue
| `DisplayMode` | Result |
|---|---|
| `nui` | Custom banner with stamp, flavour line, coloured bottom line, queue and sounds. Works while riding |
| `native` | RDR2 location shard (stamp and flavour are added to the bottom line). The game skips it while moving (`WhileMoving`). Kept for compatibility, unreliable in game |
| `notify` | rsg-core notification |

**Queue** (`nui` only): `Config.BannerQueue` makes a banner wait until the current one has faded out. At most 3 wait; one that waited 15 s is dropped. `hide` clears the queue.

**Hiding** – no banner is shown, and a visible one is hidden, while any of these is true:
- `HideWhileScriptedCam` and a scripted camera is rendering (`GET_RENDERING_CAM`, 0x03A8931ECC8015D6)
- another resource called `SetSuppressed(reason, true)` (cleared when a resource named `reason` stops)
- the statebag `LocalPlayer.state.hideZoneBanner` is true

```lua
-- hide banners during your own cinematic
exports['rsg-zonenotify']:SetSuppressed(GetCurrentResourceName(), true)
-- ... camera runs ...
exports['rsg-zonenotify']:SetSuppressed(GetCurrentResourceName(), false)

-- or with a statebag
LocalPlayer.state:set('hideZoneBanner', true, false)
```

**Long names** shrink to fit; custom titles are capped at 64 characters and subtitles at 120.

## 6. Discoveries and place keys
A *place key* is the lower-case game label, e.g. `town_valentine`, `district_heartlands`, `water_flat_iron_lake`. `shared/zones.lua` is the single source of truth and builds:

| Table | Meaning |
|---|---|
| `Zones.Keys[key]` | `true` for every discoverable place (the server whitelist) |
| `Zones.Kind[key]` | `'state'`, `'district'`, `'town'`, `'landmark'` or `'water'` |
| `Zones.KindKeys[kind]` | sorted list of keys per kind |
| `Zones.KindCount[kind]` / `Zones.KeyCount` | totals (193 places at the time of writing) |
| `Zones.KindOrder` | `{ 'state', 'district', 'town', 'landmark', 'water' }` |
| `Zones.Original[key]` | the key as written in the tables (label keys are case sensitive) |

Discoveries are stored per **character** (citizenid). Only keys in `Zones.Keys` are accepted, counted or shown. To add a place, add its hash to the right table in `shared/zones.lua` (it appears everywhere automatically) and, if the game label looks wrong, add a `Config.LabelNames` entry.

```lua
-- client: did this character find Valentine?
local found = exports['rsg-zonenotify']:IsDiscovered('town_valentine')

-- server: progress for a character
local p = exports['rsg-zonenotify']:GetProgress(citizenid)
-- p = { found = 12, total = 193, percent = 6, kinds = { town = { found = 3, total = 11 }, ... } }
if p and p.kinds.town.found >= 5 then --[[ unlock something ]] end
```

## 7. Rewards and milestones
**First visit reward** (`Config.Rewards`), paid by the server once per character per place:
- cash: `Player.Functions.AddMoney('cash', amount, 'zonenotify-discovery')`
- XP: rsg-skills `AddXP(src, 'explorer', amount, 'zonenotify-discovery')`. The skill is registered at start and again on `rsg-skills:server:ready`
- standing: rsg-reputation `AddStanding(src, region, amount, 'zonenotify-discovery', true)` for the places in `Standing.Regions`

A resource that is not started is skipped. The player gets a notification with the place name and amounts.

**Checks before paying** (a failed check still saves the discovery, it just pays nothing):
1. `Rewards.Enabled`, and the event carried a position
2. the position is within `MaxCoordGap` of the player's server position
3. at least `MinInterval` seconds since the last paid discovery
4. at least `MinTravel` metres from the last paid discovery
5. fewer than `MaxPerDay` discoveries today (counted from the database)

**Milestones** are claimed once and stored in `zonenotify_milestones`:
| Id | When |
|---|---|
| `cat_state`, `cat_district`, `cat_town`, `cat_landmark`, `cat_water` | every place of that category found |
| `all_25`, `all_50`, `all_75`, `all_100` | that percentage of all places found |

Progress is **per category, not per state**: the game gives no reliable place-to-state data, so none is guessed.

```lua
-- server: extra reward for your own server logic
AddEventHandler('rsg-zonenotify:server:placeDiscovered', function(src, citizenid, zoneKey, kind)
    if zoneKey == 'town_valentine' then
        exports['rsg-inventory']:AddItem(src, 'bread', 1, nil, nil, 'first-valentine-visit')
    end
end)

AddEventHandler('rsg-zonenotify:server:milestoneReached', function(src, citizenid, id)
    if id == 'cat_town' then
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = 'Explorer', description = 'You have seen every town!', type = 'success' })
    end
end)
```

```lua
-- config: pay more for landmarks, nothing for water, no XP
Config.Rewards.Cash.landmark = 5
Config.Rewards.Cash.water = 0
Config.Rewards.XP.Amounts = { state = 0, district = 0, town = 0, landmark = 0, water = 0 }
```

## 8. Journal, options and leaderboard
`/journal` (or `Config.Journal.Key`) opens an NUI with tabs: **All places** (overview and milestones), one tab per category, **Leaderboard** and **Options**. Open a tab from another script:

```lua
exports['rsg-zonenotify']:OpenJournal()          -- overview
exports['rsg-zonenotify']:OpenJournal('town')    -- a category tab
exports['rsg-zonenotify']:OpenJournal('leaderboard')
exports['rsg-zonenotify']:CloseJournal()
```

- Opening needs a logged-in, alive player outside the pause menu; one open per second at most.
- While open, all game controls are blocked except `Config.PushToTalkControls`, so voice keeps working. Focus changes go through one helper (`applyNuiFocus`).
- It closes on **Esc** or the close button, on death, when the pause menu opens, on character unload and on resource stop.
- If the server cannot answer (database not ready) the player sees "The journal could not be opened right now".

**Options tab** (saved on the player's PC with resource KVP `rsg-zonenotify:prefs`): banners, sound, time, temperature, wind. With `PlayerOptions = false` only the banner switch is shown and the config applies to everyone. The old `/zonenotify` flag is migrated once. A player with banners off still has places recorded and rewards paid.

**Leaderboard**: top `Leaderboard.Size` characters by places found. Only places in `Zones.Keys` count, so junk rows from older versions are ignored. Rebuilt at most every `CacheSeconds` (one grouped query plus one name lookup). Names come from `players.charinfo`.

```lua
local top = exports['rsg-zonenotify']:GetLeaderboard() -- server
-- { { rank = 1, citizenid = 'ABC12345', name = 'John M.', found = 120 }, ... }
```

## 9. Commands and keybinds
| Command | Who | What |
|---|---|---|
| `/location` | everyone | show where you are, incl. landmarks, water and caves (`Config.Command`) |
| `/zonenotify` | everyone | banners on/off, saved per player (`Config.ToggleCommand`) |
| `/places` | everyone | places found out of the total (`Config.Discovery.Command`) |
| `/journal` | everyone | open the journal (`Config.Journal.Command`) |
| `/zonetest [seconds]` | only with `Debug = true` | test banner after an optional delay |

**Keys** use rsg-core `RegisterKey` and are rebindable in the game's key settings; the config value is only the default:
| Config | Command name | Description |
|---|---|---|
| `Config.Key = 'L'` | `rsgzonenotify_location` | "where am I" |
| `Config.Journal.Key = 'J'` | `rsgzonenotify_journal` | open the journal |

With `UseKeyMapping = false`, `Config.Key` may be a control hash and a polling loop is used. `Journal.Key` needs `UseKeyMapping = true`.

## 10. Exports
### Client
| Export | Returns | Description |
|---|---|---|
| `ShowCurrentLocation()` | – | same as `/location` |
| `ShowBanner(title, subtitle?, duration?)` | `bool` | show a custom banner; `false` when banners are off, suppressed or not logged in. Duration clamped 1000–15000 ms |
| `SetSuppressed(reason, state)` | – | hide banners while `state` is true; `reason` is any string |
| `IsDiscovered(key)` | `bool` | key is case-insensitive |
| `GetDiscoveryCount()` | `number` | places found by this character |
| `GetCurrentZone()` | `table` | `{ state, district, town }` lower-case keys, `nil` when unmapped |
| `OpenJournal(tab?)` / `CloseJournal()` | – | tab: `'overview'`, a kind, `'leaderboard'`, `'options'` |

### Server
| Export | Returns | Description |
|---|---|---|
| `ShowBanner(target, title, subtitle?, duration?)` | `bool` | `target` = server id or `-1` for everyone |
| `GetDiscoveryCount(citizenid)` | `number` | works for offline characters (not cached) |
| `HasDiscovered(citizenid, key)` | `bool` | |
| `GetProgress(citizenid)` | `table` or `nil` | `{ found, total, percent, kinds = { [kind] = { found, total } } }` |
| `GetLeaderboard()` | `table` | cached list of `{ rank, citizenid, name, found }` |

```lua
-- server: ferry arrival banner for one player
exports['rsg-zonenotify']:ShowBanner(src, 'Saint Denis', 'Ferry landing', 6000)

-- server: announce to everyone
exports['rsg-zonenotify']:ShowBanner(-1, 'Train Robbery!', 'Rhodes station', 8000)

-- client: arrival banner from a client script
exports['rsg-zonenotify']:ShowBanner('Guarma', 'You step off the boat')

-- client: react to where the player is
local zone = exports['rsg-zonenotify']:GetCurrentZone()
if zone.town == 'town_valentine' then --[[ in Valentine ]] end
```

## 11. Events and callbacks
| Name | Type | Arguments | Notes |
|---|---|---|---|
| `rsg-zonenotify:client:zoneChanged` | client, local | `{ kind, key, name }` | entering a mapped state / district / town; fires regardless of banner settings |
| `rsg-zonenotify:server:placeDiscovered` | server, local | `src, citizenid, key, kind` | after a first discovery was saved |
| `rsg-zonenotify:server:milestoneReached` | server, local | `src, citizenid, id` | after a milestone was claimed |
| `rsg-zonenotify:client:showBanner` | client net event | `{ title, subtitle, duration }` | server only; use the server `ShowBanner` export |
| `rsg-zonenotify:client:reward` | client net event | `{ key, cash, xp }` | server only; shows the reward notification |
| `rsg-zonenotify:client:milestone` | client net event | `{ id, kind or percent, cash, xp }` | server only |
| `rsg-zonenotify:server:discover` | server net event | `key, coords` | sent by the client; validated, whitelisted, rate limited |
| `rsg-zonenotify:server:getDiscoveries` | callback | – | the character's keys (1 call/s per player) |
| `rsg-zonenotify:server:getJournal` | callback | – | `{ discovered, claimed, leaderboard, found }` (1 call/s per player) |

```lua
-- client: run something when the player enters a town
AddEventHandler('rsg-zonenotify:client:zoneChanged', function(zone)
    -- zone = { kind = 'town', key = 'town_valentine', name = 'Valentine' }
    if zone.kind == 'town' then
        print(('Welcome to %s'):format(zone.name))
    end
end)
```

## 12. NUI messages
For developers changing the UI. The page is `html/index.html`; messages go through `SendNUIMessage`.

| `action` | Fields | Description |
|---|---|---|
| `show` | `title, parts = { { text, color? } }, duration, stamp?, flavour?, queue` | show or queue a banner |
| `hide` | – | hide the banner and clear the queue |
| `sound` | `kind, file, volume` | play a chime or file (`file == false` = silent) |
| `journal` | `tab?, found, total, categories, overall, leaderboard, showLeaderboard, prefs, toggles, text` | open the journal with this data |
| `journalClose` | – | close the journal |

NUI callbacks (page → game): `journalClose` and `journalPref` (`{ key, value }`, key one of `banners, sound, time, temperature, wind`, value boolean; the game replies with the saved prefs). All text is set with `textContent`; style follows the RSG house standard (Roboto, monochrome, no native `<select>`).

## 13. Database
Both tables are created automatically (`Config.AutoDatabase = true`) and are in `install.sql`. Nothing is ever dropped or altered.

```sql
CREATE TABLE IF NOT EXISTS `zonenotify_discoveries` (
    `citizenid` VARCHAR(50) NOT NULL,
    `zone` VARCHAR(64) NOT NULL,
    `discovered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `zone`)
);

CREATE TABLE IF NOT EXISTS `zonenotify_milestones` (
    `citizenid` VARCHAR(50) NOT NULL,
    `milestone` VARCHAR(32) NOT NULL,
    `claimed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `milestone`)
);
```
Discoveries and claims are cached for **online** characters only and cleared on `RSGCore:Server:OnPlayerUnload` and `playerDropped`. Export lookups for offline characters read the database without caching.

## 14. Locales
`locales/*.json` in en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru, all with the same keys. English is the master.

| Prefix | Used for |
|---|---|
| `cl_*` | notifications, command help, bottom line (time, temperature, wind), rewards, milestones |
| `key_*` | names shown in the game's key settings |
| `journal_*` | journal text (categories, tabs, options) |
| `zone_msg_*` | flavour lines under place names |

Place names are the game's own labels and are not in these files.

```lua
-- add a flavour line for Annesburg in your own words: 1) add the key to every locale file
--   "zone_msg_my_line": "The coal never sleeps"
-- 2) map it in shared/config.lua
Config.ZoneMessages.TOWN_ANNESBURG = 'zone_msg_my_line'
```
```lua
-- use a custom sound for towns: put town.ogg in html/sounds/ and set
Config.Sound.Files.town = 'sounds/town.ogg'
```

## 15. Security model
- **Client events** can be fired by any client. The server accepts `rsg-zonenotify:server:discover` only from a loaded player, for a key in `Zones.Keys`, within a token-bucket rate limit (burst 5, +1 per second) and the `Discovery.MaxPerPlayer` cap. Callbacks are limited to 1 call per second per player. SQL uses `?` parameters only.
- **Rewards** are decided and paid on the server from config, never from client values. See section 7 for the checks.
- **What the server cannot prove**: it has no coordinates for places, so it cannot confirm a player is really at a place. A modified client that really rides or teleports around can still collect rewards, and every new character can collect them again. The checks and the daily cap limit the damage; keep amounts small.
- **Client-only data**: the journal data, prefs and notifications are cosmetic; the NUI callbacks validate their input.
- **Banners** can only be sent to other players by the server (`ShowBanner` export). NUI text uses `textContent`, so titles cannot inject HTML.
- **Your scripts**: do not add rewards in a `placeDiscovered` handler without your own limits, and never trust coordinates or keys sent from the client.

## 16. Server owner how-tos
- **Wrong name for a place**: set `Config.Debug = true`, read the label key in F8, add it to `Config.LabelNames`.
- **Reset one character**:
  ```sql
  DELETE FROM zonenotify_discoveries WHERE citizenid = 'ABC12345';
  DELETE FROM zonenotify_milestones WHERE citizenid = 'ABC12345';
  ```
- **Turn rewards off but keep the journal**: `Config.Rewards.Enabled = false` and `Config.Milestones.Enabled = false`.
- **Hide the leaderboard**: `Config.Leaderboard.Enabled = false`.
- **Anonymous leaderboard**: `Config.Leaderboard.Names = 'anonymous'`.
- **Only the journal, no auto banners**: set `Config.Notify.State/District/Town = false` and `Discovery.Landmarks = false` (places are then only recorded through `/location`).
- **Add a language**: copy `locales/en.json`, translate every value, keep the `%s` placeholders in order, set `setr rsg:locale`.
- **Hide banners during your own camera script**: see section 5.

## 17. Troubleshooting
| Problem | Fix |
|---|---|
| No banner at all | The player may have used `/zonenotify`; run it again. Check `DisplayMode`, `Notify.*` and that no resource called `SetSuppressed` |
| No *New Discovery* stamp | Console must say "database tables ready"; `Discovery.Enabled`; the place may already be found |
| "The journal could not be opened right now" | Database not ready (see console), the server did not answer within 5 s, or the player opened it twice within a second |
| Journal opens but voice is dead | Keep `AllowPushToTalkWhileOpen = true` and make sure `PushToTalkControls` holds your push-to-talk control |
| No reward paid | The place was already found; amount is `0`; less than `MinInterval` seconds or `MinTravel` metres since the last paid one; over `MaxPerDay`; position differs from the server's by more than `MaxCoordGap`; `rsg-skills` / `rsg-reputation` not started (that part is skipped) |
| Explorer skill missing in rsg-skills | Start `rsg-skills` before `rsg-zonenotify`, or restart this resource; it also registers on `rsg-skills:server:ready` |
| Leaderboard empty | Nobody has found a place yet, or the cache has not expired (`CacheSeconds`) |
| Leaderboard shows "Explorer #n" | `Leaderboard.Names = 'anonymous'`, or the character has no name in `players.charinfo` |
| Banner never shows during a scene | Expected: a scripted camera is rendering; set `HideWhileScriptedCam = false` |
| Custom sound silent | File must be in `html/sounds/` and the config path must start with `sounds/` |
| Key does nothing | Needs `Config.Key` / `Journal.Key` as a key **name** with `UseKeyMapping = true`; players can rebind it in the game's key settings |
| Locale keys shown as text | Start rsg-core first; add every new key to all locale files |

Support the Project : https://rexshack.tebex.store/
