# rsg-skills

Framework-wide skills for the RSG Framework: one shared place for XP, levels, rank titles, perks and leaderboards, so hunting, mining, farming and every other script can use the same progression instead of each keeping its own.

Version 3.0.0 · Requires `rsg-core` and `oxmysql` · No ox_lib, no target and no inventory dependency

Full developer and server owner documentation is in [DOCS.md](DOCS.md).

## Features
- 10 ready-made skills: hunting, fishing, mining, farming, lumberjack, herbalism, crafting, cooking, ranching, horsemanship. Add, remove or reorder them in `shared/config.lua`.
- One configurable level curve (per-skill overrides possible), rank titles (Greenhorn to Master) and a max level per skill.
- Perks are data: each skill lists values such as "+10% extra yield" that unlock at set levels. Scripts read them with one export.
- Skills panel (`/skills`) in the RSG house style: level badge, XP bar, rank, perks with the next unlock, plus a leaderboard tab.
- Leaderboards: all-time and weekly, overall or per skill, cached and throttled.
- Server-only XP: clients can never award XP. Other scripts award it through server exports.
- Level-up and XP notifications through rsg-core notify, plus a server event other scripts can listen to.
- Admin commands to add, set, reset and inspect skills, and a timed server-wide XP boost.
- Other scripts can register their own skills at runtime.
- Existing `metadata.rep` values can seed a skill once (the hunting skill is set up to import rsg-hunting's current XP).
- Push-to-talk keeps working while the panel is open.
- Database tables are created automatically.

## Installation
1. Copy the `rsg-skills` folder into your resources.
2. Start it after `oxmysql` and `rsg-core`, and before any script that uses it:
   ```
   ensure oxmysql
   ensure rsg-core
   ensure rsg-skills
   ```
3. Database: the tables (`rsg_skills`, `rsg_skills_weekly`) are created automatically on first start. To install manually instead, set `Config.AutoDatabase = false` in `shared/config.lua` and import `install.sql`.
4. Optional: set the language with `setr rsg:locale de` in `server.cfg` (see Locales).
5. Skills do nothing on their own. Scripts must call `AddXP` to award XP and `GetPerk` to apply perks (see below). No existing RSG resource does this yet.

## Configuration
All options are in `shared/config.lua`.

| Option | Default | Description |
| --- | --- | --- |
| `AutoDatabase` | `true` | Create the tables on start. Set `false` and import `install.sql` to do it by hand. |
| `AllowPushToTalkWhileOpen` | `true` | Keep push-to-talk working while the panel is open. |
| `PushToTalkControls` | `0x4BC9DABB` | Controls left enabled while the panel has focus. |
| `Command` | `'skills'` | Chat command that opens the panel (`''` to disable). |
| `AdminPermission` | `'admin'` | Permission level for the admin commands. |
| `XPMultiplier` | `1.0` | Global multiplier for every award. |
| `MaxXPPerAward` | `1000` | Cap on one award after multipliers. `raw` awards skip it. |
| `MaxBoostMultiplier` / `MaxBoostMinutes` | `5.0` / `1440` | Limits for `/skillboost`. |
| `NotifyXP` / `NotifyLevelUp` | `true` / `true` | "+X XP" and level-up notifications. |
| `Curve` | `Base 100, Growth 1.5, MaxLevel 30` | XP for level L = `floor(Base * (L-1)^Growth)`. |
| `Ranks` | 7 entries | Rank titles by level (locale keys). |
| `SaveInterval` | `60` | Seconds between saves of changed skills. Also saved on logout. |
| `Leaderboard` | `ShowTop 10, MaxEntries 200, CacheSeconds 60` | Rows shown, rows ranked and rebuild interval. |
| `Weekly` | `Enabled true, KeepWeeks 4` | Weekly boards (weeks start Monday 00:00 UTC) and how long history is kept. |
| `Skills` | 10 skills | Skill definitions: `order`, `maxLevel`, `curve`, `xpMultiplier`, `repImport`, `perks`. |

## How to use
**Players**
- `/skills` opens the panel. Use it again or press Escape to close it.
- The "My Skills" tab shows each skill with level, rank, XP progress and perks (with the next unlock in grey).
- The "Leaderboard" tab shows the top players. Pick Overall or a single skill and switch between All Time and This Week.

**Admin commands** (permission `Config.AdminPermission`; `id` is the player's server ID, the player must be online)

| Command | Description |
| --- | --- |
| `/addskillxp [id] [skill] [amount]` | Add XP. Skips multipliers and the per-award cap and does not count toward weekly boards. |
| `/setskillxp [id] [skill] [xp]` | Set exact XP. |
| `/setskilllevel [id] [skill] [level]` | Set the level (XP becomes that level's minimum). |
| `/resetskill [id] [skill]` | Set a skill back to 0 XP. |
| `/skillinfo [id]` | Show a player's skill levels. |
| `/skillboost [multiplier] [minutes]` | Boost XP for everyone, announced to all players. Multiplier 1 or no arguments clears it. The boost is kept in memory and ends on a restart. |

## For developers
Server side, award XP after your own checks have passed:
```lua
-- base XP is multiplied by the skill, global and boost multipliers, then capped
local ok, xp, level = exports['rsg-skills']:AddXP(src, 'hunting', 12, 'skinned a deer')

-- apply a perk (returns 0 when the player has not unlocked it)
local bonus = exports['rsg-skills']:GetPerk(src, 'hunting', 'sell_bonus')
price = price * (1 + bonus / 100)

-- gate something by level
if not exports['rsg-skills']:HasLevel(src, 'mining', 5) then return end
```
Listen for level-ups:
```lua
AddEventHandler('rsg-skills:server:levelUp', function(src, skill, newLevel, oldLevel)
    -- reward, unlock, log...
end)
```
All exports, events and the runtime `RegisterSkill` are in [DOCS.md](DOCS.md).

## Locales
Ships with `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br` and `ro`, all with the same keys. Skill names, rank titles and perk names are locale keys (`skill_<key>`, `skill_<key>_desc`, `rank_*`, `perk_<perk>`), so a new skill or perk needs matching entries in the locale files (a missing key shows as its raw name).

## Notes
- rsg-hunting keeps its own XP in `metadata.rep.hunting`. The hunting skill here is seeded from that value once, the first time a player has no row; after that the two are separate unless rsg-hunting is changed to call rsg-skills.
- XP is saved every `SaveInterval` seconds, on logout and when the resource stops. A hard server crash can lose up to one interval of XP.
- The leaderboard shows the character name stored when the player last earned XP.

---
Support the Project : https://rexshack.tebex.store/
