----------------------------------------------------------------------------
-- Discord webhook logging config
--
-- Server-side only (server/webhook.lua never sends anything client-visible),
-- but declared shared/ alongside the rest of Config so it's edited in the
-- same place as everything else.
--
-- Each category below is independent: its own on/off switch and its own
-- webhook URL, so e.g. anti-cheat alerts can go to a staff-only channel
-- while crafting/loot logs go to a public one. Leaving a category's url
-- blank (or its enabled = false) silently skips it - nothing is sent, and
-- nothing errors.
----------------------------------------------------------------------------

Config.Webhook = {
    enabled = true, -- master switch; false disables every category regardless of their own settings

    botName = 'Rex Herbalist',
    botAvatar = '', -- optional, e.g. 'https://i.imgur.com/yourlogo.png'

    -- Outgoing embeds are queued and drained one at a time on a timer rather
    -- than fired off immediately, so a burst of events (several players
    -- crafting/looting at once) can't blow through Discord's per-webhook
    -- rate limit (roughly 5 requests/2s). 350ms between sends keeps well
    -- under that even with multiple categories sharing traffic.
    queueIntervalMs = 350,
    maxRetries = 3, -- per message, on top of automatic retry-after handling for HTTP 429

    -- Which of the player's identifiers to include on embeds. citizenid and
    -- character name are always shown; these are extra.
    identifiers = {
        showDiscord = true,  -- adds a clickable <@id> mention when available
        showSteam = false,
        showLicense = false,
    },

    categories = {
        -- Finished tonic crafts (and refunds when the output couldn't be granted).
        craft = {
            enabled = true,
            url = '', -- paste your Discord webhook URL here
        },

        -- Mystery box opens, including the full loot roll.
        mysterybox = {
            enabled = true,
            url = '',
        },

        -- Distance/plant-mismatch/cooldown-spam violations - see Config.Webhook.antiCheat
        -- below for how individual violations are batched into an alert.
        anticheat = {
            enabled = true,
            url = '',
            mentionRoleId = '', -- optional Discord role ID to @-mention on each alert, e.g. '123456789012345678'
        },

        -- Every successful herb gather. Off by default - this fires once per
        -- pickup and can be very high volume on a populated server. Give it
        -- its own low-traffic/archive channel if you turn it on.
        gather = {
            enabled = false,
            url = '',
        },

        -- Resource start/stop. Off by default; useful for an ops/audit channel.
        resource = {
            enabled = false,
            url = '',
        },

        -- version.txt mismatch results from server/versionchecker.lua. Off by
        -- default; useful for an ops/audit channel.
        version = {
            enabled = false,
            url = '',
        },
    },

    -- A single violation (one bad gather/craft/box-open attempt) is common
    -- and often innocent - packet loss causing a double-send, a node
    -- despawning mid-animation, and so on. Only a *pattern* of violations
    -- from the same player in a short window is actually worth an alert, so
    -- individual violations are counted (and always Debug-logged to
    -- console) but a Discord alert only fires once the count within
    -- violationWindowMs reaches violationThreshold - and then again every
    -- violationThreshold violations after that, so a persistent offender
    -- keeps generating alerts rather than just one.
    antiCheat = {
        violationWindowMs = 60000,
        violationThreshold = 3,
    },
}
