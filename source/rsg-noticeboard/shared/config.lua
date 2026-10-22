Config = {}

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
-- image links must start with one of these (leave empty table to allow any https link)
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
-- expiry
---------------------------------
Config.WarnBeforeExpiry = 60 * 60 * 6 -- warn the poster 6 hours before expiry
Config.CheckInterval    = 60          -- seconds between expiry checks

---------------------------------
-- prop placer keybinds (admin board placement)
-- hash = RedM control hash, label = text shown in the on-screen help
-- control list: https://github.com/femga/rdr3_discoveries/tree/master/Controls
---------------------------------
Config.PlacerKeys = {
    confirm    = { hash = 0x07CE1E61, label = 'LMB' },   -- INPUT_ATTACK
    cancel     = { hash = 0xF84FA74F, label = 'RMB' },   -- INPUT_AIM
    rotateLeft = { hash = 0xA65EBAB4, label = 'Left' },  -- INPUT_COVER
    rotateRight= { hash = 0xDEB34313, label = 'Right' }, -- INPUT_ENTER
    raise      = { hash = 0x6319DB71, label = 'Up' },    -- INPUT_FRONTEND_UP
    lower      = { hash = 0x05CA7C52, label = 'Down' },  -- INPUT_FRONTEND_DOWN
}
Config.PlacerRotateSpeed = 1.5   -- degrees per frame
Config.PlacerHeightSpeed = 0.01  -- metres per frame
Config.PlacerMaxDistance = 15.0  -- how far from the camera the board can be placed

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
