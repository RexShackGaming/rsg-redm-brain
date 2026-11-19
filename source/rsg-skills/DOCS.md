# rsg-skills developer and server owner documentation

For a short overview see [README.md](README.md).

## Contents
1. [How it works](#how-it-works)
2. [Files](#files)
3. [Levels, ranks and perks](#levels-ranks-and-perks)
4. [Server exports](#server-exports)
5. [Client exports](#client-exports)
6. [Events and callbacks](#events-and-callbacks)
7. [Integration examples](#integration-examples)
8. [Skill definitions](#skill-definitions)
9. [Persistence](#persistence)
10. [Leaderboards](#leaderboards)
11. [Commands](#commands)
12. [Security model](#security-model)
13. [Database schema](#database-schema)
14. [Server owner how-tos](#server-owner-how-tos)
15. [Troubleshooting](#troubleshooting)

## How it works
- Each skill has an XP total per character (`citizenid`). The level is calculated from the XP, it is never stored.
- Scripts award XP with the server export `AddXP`. The client has no way to add XP.
- Perks are values attached to levels in the config. rsg-skills only stores and reports them: the script that owns the feature (a sell price, a yield, a speed) reads the perk and applies it.
- A character's skills are loaded into memory when they join and saved on a timer, on logout and when the resource stops.
- The client keeps a read-only copy (level, XP, perk values) for its own convenience. It is never used for anything that matters.

## Files
| Path | Purpose |
| --- | --- |
| `shared/config.lua` | All options, the level curve, rank titles and skill definitions. |
| `server/database.lua` | Table creation, per-player cache, loading, saving, weekly counters. |
| `server/skills.lua` | Skill registry, XP and level logic, perks, boost, panel data, exports. |
| `server/leaderboard.lua` | Leaderboard queries, caching and the callback. |
| `server/commands.lua` | Admin commands. |
| `client/client.lua` | Read-only client mirror and client exports. |
| `client/ui.lua` | `/skills` command, NUI open/close, push-to-talk handling. |
| `html/` | The panel (`index.html`, `style.css`, `script.js`). |
| `locales/*.json` | 10 languages. |
| `install.sql` | Manual database install. |

## Levels, ranks and perks
- XP needed to reach level `L` is `floor(Base * (L - 1) ^ Growth)`, so level 1 needs 0 XP. With the defaults (`Base 100`, `Growth 1.5`): level 2 = 100, level 5 = 800, level 10 = 2,700, level 20 = 8,282, level 30 = 15,616 XP.
- A skill can set its own `maxLevel` (1 to 100) and `curve = { Base, Growth }`. XP keeps counting after the max level (it only stops at 2,000,000,000), so leaderboards still separate players.
- Changing the curve later does not change anyone's XP, only the level their XP maps to.
- The rank title is the entry in `Config.Ranks` with the highest `level` not above the player's level.
- A perk is `perk_key = { suffix = '%', levels = { [level] = value } }`. The value at the highest listed level the player has reached is used, or `0` before the first one.

## Server exports
All are called as `exports['rsg-skills']:Name(...)`. `src` is a player's server ID. The player must be online and have a character loaded. Functions that read a player's data may wait briefly the first time if the player is still loading.

### Changing XP
| Export | Returns |
| --- | --- |
| `AddXP(src, skill, amount, reason?, opts?)` | `true, newXP, newLevel` or `false, reason` |
| `RemoveXP(src, skill, amount)` | `true, newXP, newLevel` or `false, reason` |
| `SetXP(src, skill, xp)` | `true, newXP, newLevel` or `false, reason` |
| `SetLevel(src, skill, level)` | `true, newXP, newLevel` or `false, reason` |

- `AddXP` applies, in order: the skill's `xpMultiplier`, `Config.XPMultiplier` and the active boost, rounds (at least 1), then caps at `Config.MaxXPPerAward`. It sends the "+X XP" notification and, on a level-up, the level-up notification and events. `reason` is free text for your own use.
- `opts` is `{ raw = true, noWeekly = true }`. `raw` skips multipliers, the boost and the cap (use it for fixed, trusted amounts). `noWeekly` keeps the award off the weekly boards. Both default to off.
- `RemoveXP`, `SetXP` and `SetLevel` do not notify and do not count toward weekly boards. XP never goes below 0, and `SetLevel` clamps to `1..maxLevel`.
- Failure reasons: `unknown_skill`, `invalid_amount` (not a positive finite number, or a missing `src`), `no_player`, `xp_limit` (already at the XP limit).

### Reading
| Export | Returns |
| --- | --- |
| `GetXP(src, skill)` | XP (0 for an unknown skill) |
| `GetLevel(src, skill)` | `level, maxLevel` (`1, 1` for an unknown skill) |
| `HasLevel(src, skill, level)` | `true` when the player's level is at least `level` |
| `GetPerk(src, skill, perk)` | The perk value at the player's level, `0` if none |
| `GetProgress(src, skill)` | `{ xp, level, maxLevel, floorXP, nextXP, pct }` (`nextXP` is `nil` at max level) or `nil` |
| `GetSkills(src)` | `{ [skill] = { xp, level, perks = { [perk] = value } } }` |
| `GetSkillDefinitions()` | `{ { key, label, description, maxLevel, perks = { perkKey, ... } }, ... }` in panel order |
| `GetLevelByCitizenId(citizenid, skill)` | Level. Works for offline characters (reads the database when they are not loaded). |
| `GetBoost()` | `multiplier, secondsRemaining` (`1.0, 0` when no boost is active) |

### Registering a skill
`RegisterSkill(key, definition)` returns `true`, or `false, 'invalid_key'`. The key is lowercase letters, numbers and underscores, up to 50 characters. The definition uses the same fields as `Config.Skills` (see [Skill definitions](#skill-definitions)). Registering the same key again replaces the definition. Registered skills last until rsg-skills restarts, so register again when it announces itself (example below).

## Client exports
Read-only values from the client's copy. Use them for display and small client-side effects only; never to decide rewards or prices.

| Export | Returns |
| --- | --- |
| `GetLevel(skill)` | Level (1 when unknown) |
| `GetXP(skill)` | XP (0 when unknown) |
| `HasLevel(skill, level)` | boolean |
| `GetPerk(skill, perk)` | Perk value at the current level, 0 if none |
| `GetSkills()` | The whole table |
| `OpenSkills()` / `CloseSkills()` | Open or close the panel (for a radial menu or target option). `OpenSkills` toggles. |

## Events and callbacks
| Name | Side | Description |
| --- | --- | --- |
| `rsg-skills:server:levelUp` | server (local) | `(src, skill, newLevel, oldLevel)`. Fired on every level gain from `AddXP`. |
| `rsg-skills:server:ready` | server (local) | Fired once the database is ready and the config skills are registered. |
| `rsg-skills:client:levelUp` | client | `(skill, newLevel)`. Sent to the player who levelled up. |
| `rsg-skills:client:sync` | client | Internal: sends the client's copy of its skills. |
| `rsg-skills:server:getSkills` | callback | Panel data for the calling player (read-only, 0.5 s throttle). |
| `rsg-skills:server:getLeaderboard` | callback | `(mode, skill)` for the calling player (read-only, 0.5 s throttle). |

There is no client-to-server event that changes XP.

## Integration examples

### Award XP from a script (e.g. skinning)
```lua
-- server side, after your own validation (distance, cooldown, item checks) has passed
local ok = exports['rsg-skills']:AddXP(src, 'hunting', xpForThisAnimal, 'skinned animal')
```
Keep the amount on the server, from your config. Never take it from a client event.

### Apply perks
```lua
local sell = exports['rsg-skills']:GetPerk(src, 'hunting', 'sell_bonus')       -- 0, 5, 10, ...
price = math.floor(price * (1 + sell / 100))

local extra = exports['rsg-skills']:GetPerk(src, 'hunting', 'extra_yield')
if math.random(100) <= extra then
    -- give one extra item (check CanAddItem first)
end
```

### Gate by level
```lua
if not exports['rsg-skills']:HasLevel(src, 'mining', 5) then
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = 'Mining', description = 'You need mining level 5', type = 'error' })
    return
end
```

### Register your own skill
```lua
-- fxmanifest.lua: dependencies { 'rsg-skills' }
local function registerSkills()
    exports['rsg-skills']:RegisterSkill('gunsmith', {
        label = 'Gunsmith',             -- locale key or plain text
        description = 'Repair and build firearms.',
        order = 110,
        maxLevel = 20,
        perks = { speed_bonus = { suffix = '%', levels = { [5] = 5, [10] = 10, [15] = 15 } } },
    })
end
registerSkills()
AddEventHandler('rsg-skills:server:ready', registerSkills) -- again if rsg-skills restarts
```
Skills registered after players have joined appear in a player's client copy the next time that skill changes.

### React to level-ups
```lua
AddEventHandler('rsg-skills:server:levelUp', function(src, skill, newLevel)
    if skill == 'hunting' and newLevel == 10 then
        -- grant a title, an item, a recipe...
    end
end)
```

### Moving rsg-hunting onto rsg-skills
rsg-hunting stores XP as player rep (`Config.HuntingXP.RepName`, default `hunting`) and has its own levels. The `hunting` skill here imports that rep value once (`repImport = 'hunting'`). To make rsg-skills the single source, change `HuntingXP.Award` to call `AddXP(src, 'hunting', amount)` and read perks with `GetPerk`. This is not done for you.

## Skill definitions
Fields of an entry in `Config.Skills` (or the table passed to `RegisterSkill`):

| Field | Default | Description |
| --- | --- | --- |
| `label` | `skill_<key>` | Locale key or plain text for the name. |
| `description` | `skill_<key>_desc` | Locale key or plain text. The default key is hidden in the panel when it has no translation. |
| `order` | `100` | Position in the panel (lower first). |
| `maxLevel` | `Config.Curve.MaxLevel` | 1 to 100. |
| `curve` | `Config.Curve` | `{ Base = n, Growth = n }`. |
| `xpMultiplier` | `1.0` | Extra multiplier for this skill. |
| `repImport` | none | Name of an existing `metadata.rep` value to seed this skill from, once, when a character has no row for it. |
| `perks` | none | `{ perk_key = { suffix = '%', levels = { [level] = value } } }`. The name shown in the panel is the locale key `perk_<perk_key>`. |

## Persistence
- Changed skills are written every `Config.SaveInterval` seconds, when a player logs out or disconnects, and when the resource stops. A hard crash can lose up to one interval of XP.
- Weekly gains are tracked separately and added to the weekly table on the same schedule. Weeks start Monday 00:00 UTC. Rows older than `Config.Weekly.KeepWeeks` weeks are removed on start and every 6 hours.
- Each row stores the character's name when XP was last saved, which the leaderboards display.
- The data is per server and held in that server's memory. Running two servers against one database is not supported.

## Leaderboards
- Boards: all-time or weekly, for every skill together (total XP) or for a single skill.
- A board is rebuilt from the database at most every `Config.Leaderboard.CacheSeconds` (changed skills are saved first, so it is current) and ranks up to `MaxEntries` characters. `ShowTop` rows are sent to the player, along with the player's own rank when they are inside the ranked rows.
- Single-skill all-time boards show levels. Weekly and overall boards show XP only.
- Requests with an unknown mode or skill fall back to all-time and overall, and a player can request a board at most every half second.

## Commands
Admin commands use `Config.AdminPermission` and work from the server console (source 0), where replies are printed. Each change is printed to the console with the admin's name.

| Command | Arguments |
| --- | --- |
| `/addskillxp` | `id skill amount` |
| `/setskillxp` | `id skill xp` |
| `/setskilllevel` | `id skill level` |
| `/resetskill` | `id skill` |
| `/skillinfo` | `id` |
| `/skillboost` | `multiplier minutes` (multiplier 1 or no arguments clears) |

Player command: `/skills` (`Config.Command`).

## Security model
What rsg-skills checks:
- XP can only change through server exports and the admin commands. No client event awards, removes or sets XP.
- Amounts must be finite, positive numbers. A normal award is capped at `Config.MaxXPPerAward` after multipliers. Skill keys are validated against the registry.
- The two callbacks only read data for the calling player. The leaderboard callback accepts only known modes and skill keys, and all SQL uses `?` parameters.
- The panel writes every name and label with `textContent`, so player names cannot inject HTML.

What other scripts must check:
- Calling `AddXP` is trusted. Validate the action that earns the XP (distance, cooldown, item, job) on the server before you call it, and take the amount from your own config.
- Do not award XP from a client-supplied amount. Use `raw = true` only for fixed amounts you control.
- Client exports are a convenience copy. Check levels and perks on the server (`HasLevel`, `GetPerk`) before paying out anything.

## Database schema
Created automatically (or from `install.sql`).

`rsg_skills`

| Column | Type | Notes |
| --- | --- | --- |
| `citizenid` | `VARCHAR(50)` | Primary key part 1 |
| `skill` | `VARCHAR(50)` | Primary key part 2 |
| `xp` | `INT UNSIGNED` | Total XP |
| `name` | `VARCHAR(100)` | Character name for leaderboards |
| `updated` | `TIMESTAMP` | Last change |

Index `skill_xp (skill, xp)`.

`rsg_skills_weekly`

| Column | Type | Notes |
| --- | --- | --- |
| `citizenid` | `VARCHAR(50)` | Primary key part 1 |
| `skill` | `VARCHAR(50)` | Primary key part 2 |
| `week` | `INT` | Weeks since 1970-01-05 (a Monday) |
| `xp` | `INT UNSIGNED` | XP gained that week |
| `name` | `VARCHAR(100)` | Character name |

Index `week_skill_xp (week, skill, xp)`.

## Server owner how-tos
- **Add a skill:** add an entry to `Config.Skills`, then add `skill_<key>` and `skill_<key>_desc` to each file in `locales/` (a missing key shows as its raw name). Scripts then award XP to it.
- **Change the pace:** lower or raise `Curve.Base` / `Curve.Growth`, or set `Config.XPMultiplier`. For a limited time use `/skillboost 2 60` (double XP for an hour).
- **Add a perk type:** add it under a skill's `perks` and add `perk_<perk_key>` to the locale files. The script that should honour it has to call `GetPerk` with that name.
- **Change the language:** `setr rsg:locale <code>` in `server.cfg` (`en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`).
- **Turn off weekly boards:** `Config.Weekly.Enabled = false`.
- **Import rsg-hunting's XP:** nothing to do. The first time a character is loaded without a hunting row, their `metadata.rep.hunting` value is copied in.

## Troubleshooting
| Problem | Check |
| --- | --- |
| Console says it could not create the database tables | The database user needs `CREATE` rights, or set `Config.AutoDatabase = false` and import `install.sql`. |
| `/skills` says skills are not available | The character is still loading, the request was throttled, or the database never became ready (see the console). Try again in a moment. |
| XP is not increasing | rsg-skills only stores XP. A script has to call `AddXP`; no existing resource does by default. |
| Notification shows a name like `skill_gunsmith` | The skill has no locale entry. Add `skill_<key>` to `locales/*.json`. |
| Perk row shows a name like `perk_haste` | Add `perk_<perk_key>` to the locale files. |
| Leaderboard is empty | Nobody has earned XP yet, weekly boards only count XP from `AddXP` this week, and boards refresh every `CacheSeconds`. |
| Leaderboard shows `?` as a name | The character earned XP before a name was saved. It updates the next time their XP saves. |
| A level looks wrong after changing the curve | Levels are calculated from stored XP. Changing `Base`, `Growth` or `maxLevel` moves everyone's level. |
| `/skillboost` ended after a restart | Boosts are kept in memory only. |

---
Support the Project : https://rexshack.tebex.store/
