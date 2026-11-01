Config = {}

---------------------------------
-- general
---------------------------------
Config.Debug           = false -- spawns debug zones/options (see client/debug.lua)
Config.Toggle          = false -- true: press key to open/close | false: hold key
Config.DefaultDistance = 7.0   -- default interact distance when an option has none
Config.RaycastDistance = 20.0  -- how far the camera raycast reaches
Config.CleanupInterval = 10000 -- (ms) server cleanup of deleted networked entities

---------------------------------
-- keys (RedM control hashes)
---------------------------------
Config.Keys = {
    Target = 0x8AAA0AD4, -- LEFT ALT  (hold / toggle targeting)
    Focus  = 0x07B8BEAF, -- LEFT MOUSE (focus the option list)
    Close  = 0x53296B75, -- RIGHT MOUSE (close while focused)
}

---------------------------------
-- zone sprites
---------------------------------
Config.DrawSprite   = 24                   -- max zone sprites drawn per frame (0 = disabled, limit 32)
Config.SpriteColour = { 155, 155, 155, 175 } -- r, g, b, a
Config.SpriteHover  = { 255, 255, 255, 255 } -- r, g, b, a when looking at zone

---------------------------------
-- nearby target highlighting
-- while targeting, scans around you and marks
-- everything you can interact with
---------------------------------
Config.Highlight = {
    Enabled            = true,
    Radius             = 10.0,  -- scan radius around the player
    ScanInterval       = 500,   -- (ms) how often to rescan
    MaxDrawn           = 16,    -- max markers (game limit is 32 draws per frame)
    Peds               = true,
    Vehicles           = true,  -- wagons, carts, boats
    Objects            = true,
    Zones              = true,  -- replaces the normal zone sprites while enabled
    IncludeGlobal      = false, -- true = also mark things that only have global options (e.g. every ped)
    RequireLineOfSight = true,  -- only mark entities you can see
    HeightOffset       = 0.15,  -- marker height above the entity
    Size               = 22,    -- eyeball icon size (px)
    Pulse              = true,
    Colour             = '#c8c8c8', -- eye colour
    HoverColour        = '#6fbf73', -- green: the target you are aiming at (active)
}
