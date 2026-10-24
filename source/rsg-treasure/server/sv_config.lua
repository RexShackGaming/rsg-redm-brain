-- SERVER ONLY: never move this into shared/, clients would be able to read your webhook URLs
SvConfig = {}

SvConfig.Webhooks = {
    Enabled  = true,
    Name     = 'rsg-treasure',
    Avatar   = '',            -- optional image URL for the webhook avatar
    Footer   = 'rsg-treasure logs',
    -- one URL per channel; leave '' to disable that log. Unset channels fall back to Default.
    Default  = '',
    Hunts    = '',            -- map used / hunt started
    Rewards  = '',            -- treasure dug up + payout
    Security = '',            -- rejected digs, possible exploit attempts
    Colors = { hunt = 3447003, reward = 5763719, warn = 16776960, alert = 15548997 },
    MentionOnAlert = '',      -- e.g. '<@&ROLE_ID>' pinged on security alerts, '' = none
    QueueDelay = 1000,        -- ms between sends (Discord allows ~5 req / 2s per webhook)
}
