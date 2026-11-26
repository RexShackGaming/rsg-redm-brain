Config = {}

---------------------------------
-- general
---------------------------------
Config.VersionCheck = false -- set true once the resource has an entry in rsg-versioncheckers

-- Tables are created automatically on start. Set to false to import install.sql manually.
Config.AutoDatabase = true

-- While the NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

---------------------------------
-- npcs
---------------------------------
Config.SpawnDistance    = 60.0 -- NPCs only exist while a player is this close
Config.InteractDistance = 2.5  -- default rsg-target distance (can be set per NPC)
Config.ServerLeeway     = 2.0  -- extra distance allowed by the server check
Config.ChoiceCooldownMs = 400  -- minimum time between replies from one player

Config.ScheduleCheckMs  = 5000 -- how often NPC opening hours are checked (needs rsg-weather)

---------------------------------
-- quest markers on NPCs (blip colour and talk prompt)
---------------------------------
Config.Markers = {
    Enabled      = true,
    RefreshMs    = 10000, -- how often markers are rechecked (they also update after replies and quest changes)
    ShowBlip     = true,  -- add a temporary blip for a marked NPC that has no blip of its own
    OfferColour  = 'BLIP_MODIFIER_MP_COLOR_6', -- has a quest to give (yellow)
    TurnInColour = 'BLIP_MODIFIER_MP_COLOR_8', -- has a quest to hand in (green)
}

---------------------------------
-- conversation presentation
---------------------------------
Config.Camera = {
    enabled    = true,
    offset     = vector3(0.45, 1.45, 0.55), -- right, forward, up from the NPC
    lookAt     = vector3(0.0, 0.0, 0.45),   -- point on the NPC to look at
    fov        = 40.0,
    easeMs     = 600,
    hidePlayer = true, -- hide your own character locally so it never blocks the shot
}
Config.TypeSpeed = 35    -- milliseconds per letter, 0 = show text instantly
Config.HideRadar = true

---------------------------------
-- quests
---------------------------------
Config.Quests = {
    MaxActive         = 10,    -- active quests per character
    TickMs            = 2000,  -- how often the server checks visits and carried items
    MinRepeatCooldown = 60,    -- shortest cooldown (seconds) a repeatable quest may have
    KillRange         = 150.0, -- how far away a counted body may be
    CheckKiller       = true,  -- reject bodies the server knows someone else killed
    JournalCommand    = 'quests',
    JournalKey        = '',    -- optional default key name, e.g. 'J' ('' = players bind it themselves)
    TrackerCommand    = 'questhud', -- show / hide the on-screen tracker
    TrackerMax        = 3,     -- quests shown on the tracker
    TrackerPosition   = 'right', -- 'right' or 'left'
    GpsColour         = 'COLOR_YELLOW', -- route set from the journal

    -- real-world time at which daily and weekly quests reset
    Reset = {
        Hour      = 6, -- 0-23
        WeekDay   = 1, -- weekly reset day: 1 = Monday ... 7 = Sunday
        UtcOffset = 0, -- hours from UTC (not adjusted for summer time)
    },
    -- random pick: how many quests of each pool are offered per day / week (pools not listed offer 1)
    Pools = {
        -- bounties = 2,
    },
}

---------------------------------
-- admin editor
---------------------------------
Config.AdminCommand    = 'npcdialog'
Config.AdminPermission = 'admin'
Config.PlaceDistance   = 10.0 -- rsg-gizmo placement range

-- Largest values the validator accepts in any dialog (config, export or editor)
Config.Limits = {
    money = 10000,
    items = 100,
    xp    = 1000,
    rep   = 100,
}

---------------------------------
-- named actions
-- Dialog choices run these by name. The in-game editor can ONLY pick from this list
-- (and actions added with the RegisterAction export), so it can never type raw events.
--   side = 'server' : TriggerEvent(event, source, npcId, args)  (AddEventHandler, not RegisterNetEvent)
--   side = 'client' : TriggerClientEvent(event, source, npcId, args)
---------------------------------
Config.Actions = {
    -- open_stables = { side = 'client', event = 'my-resource:client:open', args = { id = 'valentine' } },
}
