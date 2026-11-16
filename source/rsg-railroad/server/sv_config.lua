-- Server-only settings. This file is loaded by the server only, so values here
-- (Discord webhook URLs) are never sent to players. Do NOT move it to shared_scripts.

---------------------------------------------------------------
-- DISCORD WEBHOOK LOGGING
-- Each category can point at a different Discord webhook URL (or share
-- the same one). Leave a URL blank ('') to disable that category.
---------------------------------------------------------------
Config.Webhooks = {
    Enabled     = true,
    BotName     = 'RSG Railroad',
    BotAvatar   = '', -- optional image URL shown as the webhook's avatar

    -- Per-category webhook URLs. Paste your Discord webhook URLs below.
    URLs = {
        economy   = '', -- train/company purchases, sales, withdrawals, upgrades, mission payouts
        robbery   = '', -- train robbery outcomes
        employees = '', -- driver applications, approvals, rejections, firings, rank-ups
        admin     = '', -- fallback / anything not covered above
    },

    -- Embed colors (decimal, not hex -- e.g. 0x2ECC71 = 3066993)
    Colors = {
        success = 3066993,  -- green
        error   = 15158332, -- red
        info    = 3447003,  -- blue
        warn    = 15105570, -- orange
    },

    -- Mission completions fire very frequently -- off by default so the
    -- economy channel isn't flooded. Turn on if you want every delivery
    -- / maintenance job logged too.
    LogMissionCompletions = false,
}
