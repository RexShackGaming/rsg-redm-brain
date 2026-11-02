Config = {}

---------------------------------
-- general
---------------------------------
Config.CheckInterval = 500   -- ms between zone checks
Config.DisplayTime   = 5000  -- ms the banner stays on screen
Config.DisplayMode   = 'nui'    -- 'nui' = custom banner (works while riding), 'native' = RDR2 location banner, 'notify' = rsg-core notify
-- only used with DisplayMode 'native': the native banner is not drawn while the player is moving
Config.WhileMoving   = 'native' -- 'notify' = rsg-core notify when moving, 'wait' = banner once the player slows down, 'native' = always try the banner
Config.MovingSpeed   = 1.5      -- m/s; above this the player counts as moving
Config.MaxFeedWait   = 3000  -- native only: ms to wait for a busy feed before showing the banner anyway
Config.Debug         = false -- print zone hashes to F8 when they change and enable /zonetest

-- which zone changes show a banner automatically
Config.Notify = {
    State    = true,  -- New Hanover, Lemoyne...
    District = true,  -- The Heartlands, Big Valley...
    Town     = true,  -- Valentine, Saint Denis...
    LeaveTown = true, -- show the district banner again when riding out of a town
}

---------------------------------
-- bottom line (time | temperature | wind)
---------------------------------
Config.ShowTime       = true
Config.NightStart     = 22  -- hour the night colour starts
Config.NightEnd       = 6   -- hour the night colour ends
Config.TimeDayColor   = '~COLOR_WHITE~'
Config.TimeNightColor = '~COLOR_BLUEDARK~'

Config.ShowTemperature       = true
Config.TemperatureUnit       = 'celsius' -- 'celsius', 'fahrenheit' or 'auto' (follows the player's game metric setting)
Config.TemperatureColdDegree = 15  -- celsius; below this uses the cold colour
Config.TemperatureHotColor   = '~COLOR_YELLOWSTRONG~'
Config.TemperatureColdColor  = '~COLOR_BLUE~'

Config.ShowWind  = true
Config.SpeedUnit = 'mph' -- 'mph', 'kmh' or 'auto' (follows the player's game metric setting)
Config.WindColor = '~COLOR_RADAR_CENTER_BLIP~'

---------------------------------
-- "where am I" (shows landmarks, lakes and rivers too)
---------------------------------
Config.Key            = false        -- e.g. 0x80F28E95 (L); false = no keybind
Config.Command        = 'location'   -- false to disable
Config.ToggleCommand  = 'zonenotify' -- players turn auto banners on/off (saved per player); false to disable
Config.ManualCooldown = 3000         -- ms between manual checks

---------------------------------
-- custom banner colours (DisplayMode 'nui'): the ~COLOR_X~ codes above are mapped to these
---------------------------------
Config.NuiColors = {
    COLOR_WHITE             = '#f2f2f2',
    COLOR_BLUEDARK          = '#6f8fc9',
    COLOR_BLUE              = '#8fb8e8',
    COLOR_YELLOWSTRONG      = '#d9a441',
    COLOR_RADAR_CENTER_BLIP = '#9a9a9a',
}

---------------------------------
-- name overrides: if a place shows the wrong name, set it here (key = label from client.lua)
---------------------------------
Config.LabelNames = {
    district_roanoake_ridge   = 'Roanoke Ridge',
    district_tall_Trees       = 'Tall Trees',
    HOMESTEAD_MACLEANS_HOUSE  = "MacLean's House",
    HOMESTEAD_WATSONS_CABIN   = "Watson's Cabin",
    LANDMARK_BERYLS_DREAM     = "Beryl's Dream",
    LANDMARK_RILEYS_CHARGE    = "Riley's Charge",
    LANDMARK_LUCKYS_CABIN     = "Lucky's Cabin",
    LANDMARK_RADLEYS_PASTURE  = "Radley's Pasture",
    LANDMARK_GRANGERS_HOGGERY = "Granger's Hoggery",
    LANDMARK_MONTOS_REST      = "Monto's Rest",
    LANDMARK_QUAKERS_COVE     = "Quaker's Cove",
    LANDMARK_MILLESANI_CLAIM  = "Millesani Claim",
    LANDMARK_JORGES_GAP       = "Jorge's Gap",
    LANDMARK_BARDS_CROSSING   = "Bard's Crossing",
    LANDMARK_CALIBANS_SEAT    = "Caliban's Seat",
    LANDMARK_SOLOMONS_FOLLY   = "Solomon's Folly",
    HIDEOUT_SOLOMONS_FOLLY    = "Solomon's Folly",
    HOMESTEAD_LONNIES_SHACK   = "Lonnie's Shack",
    HOMESTEAD_WILLARDS_REST   = "Willard's Rest",
    HOMESTEAD_CATFISH_JACKSONS = "Catfish Jackson's",
    HOMESTEAD_COMPSONS_STEAD  = "Compson's Stead",
    HOMESTEAD_SHEPHERDS_RISE  = "Shepherd's Rise",
    HOMESTEAD_CHEZ_PORTER     = 'Chez Porter',
    SETTLEMENT_COOTS_CHAPEL   = "Coot's Chapel",
    SETTLEMENT_THIEVES_LANDING = "Thieves' Landing",
    SETTLEMENT_AGUASDULCES    = 'Aguasdulces',
    SETTLEMENT_SISIKA_PENITENTIARY = 'Sisika Penitentiary',
    TOWN_SAINTDENIS           = 'Saint Denis',
    TOWN_VANHORN              = 'Van Horn',
    TOWN_MACFARLANES_RANCH    = "MacFarlane's Ranch",
    WATER_OCREAGHS_RUN        = "O'Creagh's Run",
    WATER_FLAT_IRON_LAKE      = 'Flat Iron Lake',
    WATER_KAMASSA_RIVER_BLUEWATER_MARSH = 'Kamassa River',
    WATER_KAMASSA_RIVER_BAYOU_NWA = 'Kamassa River',
    WATER_SAN_LUIS_RIVER_NEW_AUSTIN = 'San Luis River',
    water_san_luis_river_west_elizabeth = 'San Luis River',
    WATER_SEA_OF_CORONADO     = 'Sea of Coronado',
    WATER_BAHIA_DE_LA_PAZ     = 'Bahía de la Paz',
    LANDMARK_HEARTLAND_OVERFLOW = 'Heartland Overflow',
    LANDMARK_BRITTLEBUSH_TRAWL = 'Brittlebrush Trawl',
    STATE_AMBARINO            = 'Ambarino',
    district_bayou_nwa        = 'Bayou Nwa',
}

---------------------------------
-- discoveries: "NEW DISCOVERY" stamp the first time a character visits a place (saved in the database)
---------------------------------
Config.AutoDatabase = true -- create the table automatically; set false to import install.sql manually
Config.Discovery = {
    Enabled      = true,
    ShowStamp    = true,     -- show the "New Discovery" stamp on the banner
    Landmarks    = true,     -- also show a one-time banner for landmarks, lakes and rivers you ride past
    Command      = 'places', -- shows how many places you have found; false to disable
    MaxPerPlayer = 1000,     -- server-side cap (anti-spam)
}

---------------------------------
-- sounds: played by the NUI page. Leave a file nil for the built-in chime,
-- or put an .ogg/.mp3 in html/sounds/ and set e.g. town = 'sounds/town.ogg'. false = silent for that kind.
---------------------------------
Config.Sound = {
    Enabled = true,
    Volume  = 0.25, -- 0.0 - 1.0
    Files = {
        state     = nil,
        district  = nil,
        town      = nil,
        landmark  = nil,
        discovery = nil,
        manual    = false,
        custom    = nil,
    },
}

---------------------------------
-- flavour lines under the title: label key (see LabelNames / Debug) = locale key
---------------------------------
Config.ZoneMessages = {
    state_new_austin = 'zone_msg_new_austin',
    state_guarma     = 'zone_msg_guarma',
    TOWN_SAINTDENIS  = 'zone_msg_saint_denis',
}

---------------------------------
-- hide the banner while a scripted camera is rendering (rsg-moviemaker, cutscenes, character creator...)
---------------------------------
Config.HideWhileScriptedCam = true
