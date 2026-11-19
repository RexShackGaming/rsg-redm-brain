Config = {}

-- Tables are created automatically on start. Set to false to import install.sql manually.
Config.AutoDatabase = true

-- While the NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- Chat command that opens the skills panel ('' to disable)
Config.Command = 'skills'

-- Permission level needed for the admin commands (addskillxp, setskillxp, setskilllevel, resetskill, skillboost)
Config.AdminPermission = 'admin'

------------------------------------------
-- XP
------------------------------------------
-- Global multiplier applied to every award (1.0 = normal)
Config.XPMultiplier = 1.0

-- Safety cap on a single award after multipliers. Protects against a buggy script handing out huge XP.
-- Awards made with { raw = true } (admin commands, trusted imports) skip multipliers and this cap.
Config.MaxXPPerAward = 1000

-- Highest multiplier /skillboost will accept, and the longest boost in minutes
Config.MaxBoostMultiplier = 5.0
Config.MaxBoostMinutes = 1440

-- Show a "+X XP" notification for every award (a new one replaces the one still on screen)
Config.NotifyXP = true
-- Show a notification when a skill levels up
Config.NotifyLevelUp = true

------------------------------------------
-- Level curve
-- XP needed to reach level L = floor(Base * (L - 1) ^ Growth). Level 1 needs 0 XP.
-- With Base 100 / Growth 1.5: L2 = 100, L5 = 800, L10 = 2,700, L20 = 8,282, L30 = 15,616
-- A skill can override any of these with its own `curve = { Base, Growth }` and `maxLevel`.
------------------------------------------
Config.Curve = {
    Base = 100,
    Growth = 1.5,
    MaxLevel = 30,
}

-- Rank titles shown next to the level (the highest entry at or below the level is used).
-- Each label is a locale key (see locales/*.json); plain text works too.
Config.Ranks = {
    { level = 1,  label = 'rank_greenhorn' },
    { level = 5,  label = 'rank_apprentice' },
    { level = 10, label = 'rank_journeyman' },
    { level = 15, label = 'rank_skilled' },
    { level = 20, label = 'rank_expert' },
    { level = 25, label = 'rank_veteran' },
    { level = 30, label = 'rank_master' },
}

------------------------------------------
-- Saving and leaderboards
------------------------------------------
Config.SaveInterval = 60          -- seconds between database saves of changed skills (also saved on logout)
Config.Leaderboard = {
    ShowTop = 10,                 -- rows shown
    MaxEntries = 200,             -- rows loaded for ranking
    CacheSeconds = 60,            -- how often a board is rebuilt from the database
}
Config.Weekly = {
    Enabled = true,               -- weekly boards (weeks start Monday 00:00 UTC)
    KeepWeeks = 4,                -- weeks of history kept in the database
}

------------------------------------------
-- Skills
-- key (lowercase letters, numbers, underscore):
--   label / description  locale keys (plain text works too). Defaults: skill_<key> / skill_<key>_desc
--   order                position in the panel (lower first)
--   maxLevel / curve     optional per-skill overrides of Config.Curve
--   xpMultiplier         optional extra multiplier for this skill only
--   repImport            optional: on a player's first load, seed this skill from their existing
--                        metadata.rep value of that name (e.g. 'hunting' carries rsg-hunting XP over)
--   perks                data only: other scripts read them with GetPerk and decide how to apply them.
--                        perks = { perk_key = { suffix = '%', levels = { [level] = value, ... } } }
--                        The value at the highest listed level the player has reached is used.
--                        The perk name is a locale key: perk_<perk_key>.
-- Other scripts can add skills at runtime with exports['rsg-skills']:RegisterSkill(key, definition).
------------------------------------------
Config.Skills = {
    hunting = {
        order = 10, repImport = 'hunting',
        perks = {
            extra_yield = { suffix = '%', levels = { [3] = 5, [8] = 10, [14] = 15, [20] = 20, [30] = 30 } },
            sell_bonus  = { suffix = '%', levels = { [2] = 5, [6] = 10, [12] = 15, [18] = 20, [26] = 25 } },
        },
    },
    fishing = {
        order = 20,
        perks = {
            rare_chance = { suffix = '%', levels = { [4] = 5, [10] = 10, [18] = 15, [26] = 20 } },
            sell_bonus  = { suffix = '%', levels = { [3] = 5, [9] = 10, [16] = 15, [24] = 20 } },
        },
    },
    mining = {
        order = 30,
        perks = {
            extra_yield = { suffix = '%', levels = { [3] = 5, [8] = 10, [14] = 15, [20] = 20, [30] = 30 } },
            rare_chance = { suffix = '%', levels = { [6] = 5, [14] = 10, [24] = 15 } },
        },
    },
    farming = {
        order = 40,
        perks = {
            extra_yield = { suffix = '%', levels = { [3] = 5, [8] = 10, [14] = 15, [20] = 20, [30] = 30 } },
            speed_bonus = { suffix = '%', levels = { [5] = 5, [12] = 10, [20] = 15 } },
        },
    },
    lumberjack = {
        order = 50,
        perks = {
            extra_yield = { suffix = '%', levels = { [3] = 5, [8] = 10, [14] = 15, [20] = 20, [30] = 30 } },
            speed_bonus = { suffix = '%', levels = { [5] = 5, [12] = 10, [20] = 15 } },
        },
    },
    herbalism = {
        order = 60,
        perks = {
            extra_yield = { suffix = '%', levels = { [3] = 5, [8] = 10, [14] = 15, [20] = 20 } },
            rare_chance = { suffix = '%', levels = { [7] = 5, [15] = 10, [25] = 15 } },
        },
    },
    crafting = {
        order = 70,
        perks = {
            save_chance = { suffix = '%', levels = { [4] = 5, [10] = 10, [18] = 15, [26] = 20 } },
            speed_bonus = { suffix = '%', levels = { [6] = 5, [14] = 10, [22] = 15 } },
        },
    },
    cooking = {
        order = 80,
        perks = {
            save_chance = { suffix = '%', levels = { [4] = 5, [10] = 10, [18] = 15 } },
            sell_bonus  = { suffix = '%', levels = { [5] = 5, [12] = 10, [20] = 15 } },
        },
    },
    ranching = {
        order = 90,
        perks = {
            extra_yield = { suffix = '%', levels = { [3] = 5, [8] = 10, [14] = 15, [20] = 20 } },
            sell_bonus  = { suffix = '%', levels = { [5] = 5, [12] = 10, [20] = 15 } },
        },
    },
    horsemanship = {
        order = 100,
        perks = {
            speed_bonus = { suffix = '%', levels = { [5] = 3, [12] = 6, [20] = 9, [28] = 12 } },
        },
    },
}
