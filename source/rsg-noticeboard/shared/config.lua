Config = {}
-- build the database tables automatically on start (set false and import the SQL file for a manual install)
Config.AutoDatabase = true

---------------------------------
-- props that can be targeted (world boards + admin placed boards)
---------------------------------
Config.BoardModels = {
    `mp005_p_mp_bountyboard01x`,
    `mp005_p_mp_bountyboard02x`,
}
Config.PlacedBoardModel = 'mp005_p_mp_bountyboard02x' -- model admins place with the gizmo
Config.TargetDistance   = 2.5
Config.SpawnDistance    = 120.0 -- placed boards spawn when player is within this range

---------------------------------
-- blips for admin placed boards
---------------------------------
Config.ShowBlips  = true
Config.BlipSprite = `blip_job_board`
Config.BlipScale  = 0.2

---------------------------------
-- towns: each board shows only the notices of its nearest town
-- (coords are the town centre, adjust to suit your map)
---------------------------------
Config.SeparateTowns = true
Config.Towns = {
    { id = 'valentine',   label = 'Valentine',     coords = vector3(-281.0, 793.0, 119.0) },
    { id = 'rhodes',      label = 'Rhodes',        coords = vector3(1300.0, -1300.0, 76.0) },
    { id = 'saintdenis',  label = 'Saint Denis',   coords = vector3(2632.0, -1312.0, 51.0) },
    { id = 'blackwater',  label = 'Blackwater',    coords = vector3(-813.0, -1324.0, 43.0) },
    { id = 'strawberry',  label = 'Strawberry',    coords = vector3(-1791.0, -386.0, 160.0) },
    { id = 'annesburg',   label = 'Annesburg',     coords = vector3(2930.0, 1288.0, 44.0) },
    { id = 'vanhorn',     label = 'Van Horn',      coords = vector3(2980.0, 560.0, 44.0) },
    { id = 'emerald',     label = 'Emerald Ranch', coords = vector3(1420.0, 330.0, 89.0) },
    { id = 'lagras',      label = 'Lagras',        coords = vector3(2100.0, -600.0, 42.0) },
    { id = 'armadillo',   label = 'Armadillo',     coords = vector3(-3685.0, -2623.0, -14.0) },
    { id = 'tumbleweed',  label = 'Tumbleweed',    coords = vector3(-5512.0, -2950.0, -2.0) },
}

---------------------------------
-- posting
---------------------------------
Config.MoneyType          = 'cash'  -- cash / bank / bloodmoney
Config.MaxNoticesPerPlayer = 5
Config.PostCooldown       = 30    -- seconds between posts per character
Config.SessionTimeout     = 600   -- seconds a player can stay in the board UI and still post
Config.SessionDistance    = 10.0  -- max distance from where the board was opened when posting
Config.TitleMaxLength     = 60
Config.BodyMaxLength      = 1500
Config.RequireImage       = false
-- only allow image links from these hosts, e.g. { 'i.imgur.com', 'cdn.discordapp.com' }
-- (leave empty to allow any https link; note that every viewer's client loads the image, so
--  restricting hosts also stops IP-logging links)
Config.AllowedImageHosts  = {}

-- durations: seconds OR months = 1 (calendar month)
Config.Durations = {
    { id = '1d', label = '1 Day',   seconds = 86400,     price = 1.00 },
    { id = '3d', label = '3 Days',  seconds = 86400 * 3, price = 2.50 },
    { id = '1w', label = '1 Week',  seconds = 86400 * 7, price = 5.00 },
    { id = '2w', label = '2 Weeks', seconds = 86400 * 14, price = 9.00 },
    { id = '1m', label = '1 Month', months = 1,          price = 15.00 },
}

Config.Categories = {
    { id = 'events',   label = 'Events' },
    { id = 'wanted',   label = 'Wanted' },
    { id = 'forsale',  label = 'For Sale' },
    { id = 'jobs',     label = 'Work Offered' },
    { id = 'lost',     label = 'Lost & Found' },
    { id = 'general',  label = 'General' },
}

---------------------------------
-- browsing: the board loads one page of notices at a time (the text is fetched when a notice is opened)
---------------------------------
Config.PageSize         = 12
Config.SearchMaxLength  = 40
Config.AdminListLimit   = 300 -- notices shown in the admin panel

---------------------------------
-- editing, featured notices, map pins, reminders
---------------------------------
Config.AllowEdit = true  -- posters may edit title, text, image and category of their own notice (free)
Config.AllowPins = true  -- posters may pin their current position to a notice; viewers get a "Show on map" button

-- featured notices sit first on the board with a badge; extra fee on top of the display period
Config.Featured = { Enabled = true, Price = 10.00, MaxPerTown = 3 }

-- "Remind me": a telegram (rsg-telegram) shortly before the notice expires, handy for events.
-- Falls back to a notification when rsg-telegram is not running and the player is online.
Config.Reminders = { Enabled = true, Before = 3600, MaxPerPlayer = 20 }

---------------------------------
-- town treasury (rsg-economy): share of every fee paid into the treasury of the notice's town
-- Regions maps a Config.Towns id to an rsg-economy region id when they differ; towns without a region just keep nothing
---------------------------------
Config.Economy = {
    Enabled = true,
    Share   = 1.0,
    Regions = { saintdenis = 'saint_denis', vanhorn = 'van_horn' },
}

---------------------------------
-- reports and bans
-- HideAt: distinct reports that hide a notice until an admin reviews it
---------------------------------
Config.Reports = {
    Enabled    = true,
    HideAt     = 3,
    MaxPerDay  = 10,   -- reports one character may file per day
    Cooldown   = 10,   -- seconds between reports
    BanDays    = 7,    -- posting ban given by "Remove & ban" / "Ban poster"
    Reasons    = { 'scam', 'offensive', 'spam', 'other' }, -- labels: locale keys ui_reason_<id>
}

---------------------------------
-- reputation (rsg-reputation)
---------------------------------
Config.Reputation = {
    Enabled        = true,
    MinHonorToPost = -250, -- characters below this honor cannot post (set very low to disable)
    AbusePenalty   = 15,   -- honor removed from an online poster when an admin removes their reported notice
}

---------------------------------
-- expiry
---------------------------------
Config.WarnBeforeExpiry = 60 * 60 * 6 -- warn the poster 6 hours before expiry
Config.CheckInterval    = 60          -- seconds between expiry checks
Config.ExpiryPopup      = true        -- open the renew popup when a notice is about to expire (false = notification only)

---------------------------------
-- admin board placement (rsg-gizmo)
---------------------------------
Config.PlaceMaxDistance = 8.0 -- how far from the admin a board may be placed (checked on the server too)

---------------------------------
-- NUI
---------------------------------
-- While the UI is open, block game controls but keep push-to-talk working.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

---------------------------------
-- admin
---------------------------------
Config.AdminPermission = 'admin'
Config.AdminCommand    = 'noticeadmin'

---------------------------------
-- labels for categories / durations come from locales (cat_<id>, dur_<id>);
-- the label above is only a fallback if the key is missing
---------------------------------
function Config.Localize(prefix, list)
    local out = {}
    for i, item in ipairs(list) do
        local copy = {}
        for k, v in pairs(item) do copy[k] = v end
        local key = prefix .. item.id
        local text = locale(key)
        if text and text ~= key then copy.label = text end
        out[i] = copy
    end
    return out
end
