-- rsg-bountyhunter evidence items (Config.Evidence). Paste into rsg-core/shared/items.lua before the closing brace.
-- Images are not supplied: add wanted_poster.png, outlaw_pocketwatch.png and outlaw_signet_ring.png to rsg-inventory/html/images.
-- Without these definitions the script skips the evidence drop and prints a one-time console warning.

    wanted_poster       = { name = 'wanted_poster',       label = 'Wanted Poster',   weight = 50,  type = 'item', image = 'wanted_poster.png',       unique = false, useable = false, shouldClose = true, description = 'A torn poster from a captured outlaw.', category = 'misc' },
    outlaw_pocketwatch  = { name = 'outlaw_pocketwatch',  label = 'Pocket Watch',    weight = 100, type = 'item', image = 'outlaw_pocketwatch.png',  unique = false, useable = false, shouldClose = true, description = 'A pocket watch taken from an outlaw.', category = 'misc' },
    outlaw_signet_ring  = { name = 'outlaw_signet_ring',  label = 'Signet Ring',     weight = 50,  type = 'item', image = 'outlaw_signet_ring.png',  unique = false, useable = false, shouldClose = true, description = 'A gold signet ring taken from an outlaw.', category = 'misc' },
