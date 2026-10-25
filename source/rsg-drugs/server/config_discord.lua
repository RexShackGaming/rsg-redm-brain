-- SERVER ONLY. Webhook URLs must never be in a shared/client file (clients could read and spam them).
ConfigDiscord = {
    Enabled  = true,
    Username = 'rsg-drugs',
    Avatar   = '',            -- optional image URL for the webhook avatar
    Footer   = 'rsg-drugs logs',
    Default  = '',            -- fallback webhook for any category left blank below

    -- one webhook per category (blank = use Default, false = don't log this category)
    Webhooks = {
        lab      = '',  -- hire, fire, assign, deposits, withdrawals, payroll
        sales    = '',  -- weed bag NPC sales and refusals (law alerts)
        export   = '',  -- brick export sales
        xp       = '',  -- level ups and XP resets (jail)
        rehab    = '',  -- admissions, check-ins, releases, escapes, rehab rewards
        admin    = '',  -- /clearaddiction, /setaddiction
        security = '',  -- suspicious requests (spoofed hires, out of range, NPC rehab farming)
    },

    -- embed colours (decimal)
    Colors = {
        lab = 9807270, sales = 5763719, export = 15844367, xp = 3447003,
        rehab = 10181046, admin = 15105570, security = 15548997,
    },

    -- per-category minimum size before logging, to cut noise
    MinWithdraw = 1,          -- only log withdrawals of at least this many units
    MinDeposit  = 1,

    -- identifiers shown on each log
    ShowLicense = true,
    ShowDiscord = true,       -- pings nobody; shows <@id> as a clickable mention
    ShowCoords  = true,

    -- Discord limit is ~30 messages/min per webhook; embeds are batched (max 10 per message)
    FlushSeconds = 3,
}
