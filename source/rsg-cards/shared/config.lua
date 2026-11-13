Config = {}

Config.Debug = false

-- Prints a console message on start when a newer version is available on GitHub.
Config.VersionCheck = true

-- Database: tables are created automatically on start.
-- Set to false to import install.sql manually instead.
Config.AutoDatabase = true

-- While the NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- Inventory image folder used for item thumbnails in the UI
Config.ImagePath = 'nui://rsg-inventory/html/images/'

-- Item names (must exist in rsg-core shared items, see installation/shared_items.lua)
Config.Items = {
    Pack = 'card_package_cards', -- pack of cards
    Box  = 'card_storage_box',   -- card storage box
}

---------------------------------------------------------------------
-- INTERACTION
---------------------------------------------------------------------
Config.EnableTarget  = true -- true = rsg-target, false = rsg-core prompts
Config.FadeIn        = true -- fade NPCs and card props in/out
Config.DistanceSpawn = 20.0 -- distance at which NPCs and card props spawn

Config.Blip = {
    showblipShop    = true,
    ShopSprite      = 'blip_rc',
    ShopScale       = 0.2,

    showblipCollect = false, -- trade NPCs
    CollectSprite   = 'blip_ambient_secret',
    CollectScale    = 0.2,

    showblipCards   = false, -- shows every card location on the map
    cardSprite      = 'blip_ambient_secret',
    cardScale       = 0.2,
}

---------------------------------------------------------------------
-- CARD SETS
-- Item names are built from the set id:
--   single card: card_cigcard_<id>_c<1-12>    complete set: card_cigcard_<id>
-- tier      = pack rarity group (see Config.Pack.Chances)
-- cardPrice = vendor price for one card, deckPrice = vendor price for the complete set
-- landscape = card is wider than tall (changes the inspect animation)
---------------------------------------------------------------------
Config.CardsPerSet = 12

Config.Sets = {
    { id = 'act',  tier = 'basic', cardPrice = 0.50, deckPrice = 5.00 },
    { id = 'amer', tier = 'basic', cardPrice = 0.50, deckPrice = 10.00 },
    { id = 'aml',  tier = 'basic', cardPrice = 0.50, deckPrice = 15.00, landscape = true },
    { id = 'inv',  tier = 'basic', cardPrice = 0.50, deckPrice = 20.00, landscape = true },
    { id = 'art',  tier = 'rare',  cardPrice = 0.50, deckPrice = 25.00 },
    { id = 'grl',  tier = 'rare',  cardPrice = 0.50, deckPrice = 30.00 },
    { id = 'lnd',  tier = 'rare',  cardPrice = 0.50, deckPrice = 35.00 },
    { id = 'plt',  tier = 'ultra', cardPrice = 0.50, deckPrice = 40.00 },
    { id = 'gun',  tier = 'ultra', cardPrice = 0.50, deckPrice = 45.00 },
    { id = 'hrs',  tier = 'v',     cardPrice = 0.50, deckPrice = 50.00, landscape = true },
    { id = 'spt',  tier = 'v',     cardPrice = 0.50, deckPrice = 55.00 },
    { id = 'veh',  tier = 'vmax',  cardPrice = 0.50, deckPrice = 60.00, landscape = true },
}

---------------------------------------------------------------------
-- CARD PACKS
---------------------------------------------------------------------
Config.Pack = {
    Cards    = 4,    -- cards per pack
    OpenTime = 3000, -- progress bar (ms)

    -- Weighted chance per card. 'deck' gives a complete set.
    -- Weights must be whole numbers; these add up to 1000.
    Chances = {
        { tier = 'deck',  weight = 5 },
        { tier = 'vmax',  weight = 14 },
        { tier = 'v',     weight = 31 },
        { tier = 'ultra', weight = 50 },
        { tier = 'rare',  weight = 299 },
        { tier = 'basic', weight = 601 },
    },
}

---------------------------------------------------------------------
-- CARDS IN THE WORLD (locations in shared/cards_points.lua)
---------------------------------------------------------------------
Config.Card = {
    Key            = 'J',   -- prompt key when Config.EnableTarget = false
    PickupTime     = 3000,  -- progress bar (ms)
    PickupDistance = 3.0,   -- interaction distance
    Cooldown       = 360,   -- minutes before the same player can collect the same card again
    InspectTime    = 15000, -- max time (ms) a card is held when used from the inventory

    -- Eagle Eye: cards glow and a heartbeat plays when one is close
    EagleEye = {
        enabled   = true,
        distance  = 50.0,
        soundRef  = 'RDRO_Sniper_Tension_Sounds',
        soundName = 'Heartbeat',
    },
}

-- Card storage box stash
-- Use the box to open it beside your inventory; use it again to close just the box.
Config.Storage = {
    MaxWeight = 500,
    MaxSlots  = 81,
    OpenDelay = 300, -- ms to wait before the box opens when the box item is `shouldClose = true` (the inventory closes first)

    -- Shows a "Bundle Sets" button at the top of the box. It turns every complete run of cards
    -- inside the box into the complete-set item (needs rsg-inventory 3.2.0 or newer).
    BundleSets = true,

    -- Only these item categories (the `category` field in rsg-core shared items) can be kept in a box.
    -- Every rsg-cards card, set and pack is always allowed, even if its category is missing.
    -- Anything else put in a box is handed straight back to the player.
    AllowedCategories = { 'card', 'cardset', 'cardpack' },
}

-- Sounds (interact-sound). Skipped automatically if interact-sound isn't running.
Config.Sounds = {
    enabled = true,
    volume  = 0.8,
    open    = 'dealfour',
    flip    = 'flip',
}

---------------------------------------------------------------------
-- CARD VENDORS (buy packs and boxes, sell cards and sets)
---------------------------------------------------------------------
Config.Shop = {
    Key              = 'J',    -- prompt key when Config.EnableTarget = false
    Payment          = 'cash', -- 'cash' or 'bloodmoney'
    InteractDistance = 5.0,    -- server-side distance check
    PersistStock     = true,   -- keep stock across restarts (rsg-inventory)
    CraftSets        = true,   -- vendors turn all 12 cards of a set into the complete set
    BoxesOnly        = true,   -- true = vendors only look in the card boxes the player carries (loose cards in the inventory are ignored)
                               -- false = vendors look in the inventory first, then the card boxes

    -- amount = stock
    Items = {
        { name = 'card_package_cards', amount = 500, price = 5.0 },
        { name = 'card_storage_box',   amount = 50,  price = 50.0 },
    },

    Locations = {
        {
            id        = 'CardshopCollect',
            coords    = vector3(2855.22, -1223.84, 47.58),
            npcmodel  = `mp_u_f_m_nat_traveler_01`,
            npccoords = vector4(2855.22, -1223.84, 47.58, 32.84),
        },
        {
            id        = 'CardshopCollect2',
            coords    = vector3(1296.75, -6941.65, 55.31),
            npcmodel  = `mp_u_f_m_nat_traveler_01`,
            npccoords = vector4(1296.75, -6941.65, 55.31, 208.93),
        },
    },
}

---------------------------------------------------------------------
-- CARD COLLECTORS (trade a handful of cards from one set for the complete set)
---------------------------------------------------------------------
Config.Trades = {
    Key              = 'E', -- prompt key when Config.EnableTarget = false
    Refresh          = 90,  -- minutes between new offers
    MaxActive        = 3,   -- offers per collector
    MinCards         = 3,   -- cards an offer asks for (min)
    MaxCards         = 8,   -- cards an offer asks for (max)
    RewardAmount     = 1,   -- complete sets given per trade
    OncePerPlayer    = true, -- each request can only be completed once per player (until the requests refresh)
    InteractDistance = 5.0, -- server-side distance check

    Locations = {
        { id = 'CardshopCollect5',  coords = vector3(341.90, -660.64, 41.89),    npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(341.90, -660.64, 41.89, 141.4) },
        { id = 'CardshopCollect6',  coords = vector3(1891.88, -1853.79, 43.12),  npcmodel = `a_m_y_nbxstreetkids_01`,      npccoords = vector4(1891.88, -1853.79, 43.12, 170.25) },
        { id = 'CardshopCollect7',  coords = vector3(-1760.74, -430.08, 155.23), npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(-1760.74, -430.08, 155.23, 141.4) },
        { id = 'CardshopCollect8',  coords = vector3(2516.74, -1224.20, 53.68),  npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(2516.74, -1224.20, 53.68, 293.07) },
        { id = 'CardshopCollect9',  coords = vector3(502.60, 627.82, 111.70),    npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(502.60, 627.82, 111.70, 141.4) },
        { id = 'CardshopCollect10', coords = vector3(2768.32, -1161.75, 48.44),  npcmodel = `a_m_y_sdstreetkids_slums_02`, npccoords = vector4(2768.32, -1161.75, 48.44, 293.07) },
        { id = 'CardshopCollect11', coords = vector3(2529.17, -1572.10, 45.97),  npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(2529.17, -1572.10, 45.97, 141.4) },
        { id = 'CardshopCollect12', coords = vector3(1329.07, -1372.74, 80.28),  npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(1329.07, -1372.74, 80.28, 293.07) },
        { id = 'CardshopCollect13', coords = vector3(2094.03, -612.50, 45.13),   npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(2094.03, -612.50, 45.13, 293.07) },
        { id = 'CardshopCollect14', coords = vector3(-810.08, -1372.64, 44.02),  npcmodel = `mp_u_f_m_nat_traveler_01`,    npccoords = vector4(-810.08, -1372.64, 44.02, 293.07) },
        { id = 'CardshopCollect15', coords = vector3(-5570.66, -3050.78, 0.47),  npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(-5570.66, -3050.78, 0.47, 293.07) },
        { id = 'CardshopCollect16', coords = vector3(2931.15, 514.86, 45.48),    npcmodel = `a_f_m_sdfancywhore_01`,       npccoords = vector4(2931.15, 514.86, 45.48, 293.07) },
    },
}

---------------------------------------------------------------------
-- LOGGING (rsg-log)
---------------------------------------------------------------------
Config.Webhook = {
    Name   = 'rsg-cards', -- must match a webhook entry in rsg-log
    Title  = 'CARDS',
    Colour = 'default',
}
