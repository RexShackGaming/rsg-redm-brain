Config = {}

-- Required permission to use the Blip/NPC menu
Config.AdminPermission = 'admin'

-- Create/upgrade the database tables automatically on resource start.
-- Set to false if you prefer to import rsg-stores.sql by hand.
Config.AutoInstallDatabase = true

--  NPC scenario
Config.DefaultScenario = 'WORLD_HUMAN_STAND_IMPATIENT'
Config.DistanceSpawn = 20.0  -- Distance before spawning/despawning the NPC (GTA Units)
Config.FadeIn = true         -- Enable fade in/out effect
Config.SellPricePercentage = 0.80  -- Player gets 80% (20% shop fee)
Config.SellAddsStock = true        -- Items sold to a shop are added back to its stock (limited-stock items only)
Config.MaxShopStock = 100          -- Most of any one item a shop will hold from player sales (0 = no cap)
Config.TargetDistance = 2.5       -- rsg-target range; server allows +5.0 for latency

-- Player-owned stores: created by admins in /createshop ("Run by: Player"), no NPC is spawned.
-- The owner stocks the store from their own inventory, sets prices and collects the till.
Config.OwnedStores = {
    Enabled           = true,
    ZoneRadius        = 1.2,    -- size of the counter target zone at the store position
    BuyBackPercentage = 0.80,   -- customers selling to an owned store get price x this, paid from the till
    MaxListings       = 50,     -- most different items one store can list
    MaxStock          = 500,    -- most of any one item a store can hold (0 = no cap)
    MaxPrice          = 10000,  -- highest price an owner can set per item
    NotifyOwner       = true,   -- tell the owner (if online) when a customer buys or sells
    -- Items owners may not stock (money items, unique/metadata items are always refused)
    BlacklistItems    = { 'dollar', 'cent', 'blood_dollar', 'blood_cent' },
}

-- Shop sign item: admins give players the item (e.g. /giveitem [id] shopsign 1).
-- Using it places a sign in front of the player and opens a player-owned store they own.
-- Customers and the owner target the sign to trade / manage.
Config.ShopSign = {
    Enabled        = true,
    Item           = 'shopsign',
    Model          = 'p_sandwichboard02x', -- rdr3_discoveries objects/object_list.lua (0x456CF4F4)
    MaxPerPlayer   = 1,       -- sign stores one character can own (0 = no limit)
    MinSpacing     = 8.0,     -- metres from any other store/NPC shop
    PlaceDistance  = 1.5,     -- start distance in front of the player (owner can adjust 0.75 - 3.0)
    DefaultType    = 'buy',   -- starting counter type: 'buy' | 'sell' | 'both'
    ReturnOnPackUp = true,    -- give the sign back when the owner packs the store up
    -- Upkeep (rent) for sign stores, taken from the till each period. Unpaid upkeep closes the store
    -- to customers until the owner pays; after EvictAfterMissed unpaid periods the store is repossessed
    -- (stock and till forfeited, sign not returned).
    Upkeep = { Enabled = true, Amount = 5.0, IntervalHours = 24, EvictAfterMissed = 3 },
    Blip = { Enabled = true, Sprite = 1475879922, Color = 'BLIP_MODIFIER_MP_COLOR_32' }, -- blip_shop_store, from Config.BlipTypes
    -- Auto-registered in rsg-core if your items list doesn't have it yet
    ItemDefinition = {
        name = 'shopsign', label = 'Shop Sign', weight = 2000, type = 'item', image = 'shopsign.png',
        unique = false, useable = true, shouldClose = true, description = 'Place it to open your own store',
    },
}


-- Shopkeeper speech (NPC shops). Lines/params from RDR3 decompiled shop_general.c
-- (PLAY_PED_AMBIENT_SPEECH_NATIVE). Set a line to false to skip it.
Config.Speech = {
    Enabled = true,
    Greet   = 'WELCOME',
    Thanks  = 'THANKS',
    Goodbye = 'GOODBYE_POS',
    Params  = 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR',
}

-- Opening hours (in-game clock, 0-23). Close < Open wraps past midnight (e.g. 18 -> 2).
Config.OpeningHours = {
    Enabled     = false,
    Open        = 7,
    Close       = 21,
    OwnedStores = false,   -- also apply to player-owned stores
    Shops = {              -- per-shop override by shop id (shop_name), e.g.
        -- ['valsaloon'] = { Open = 12, Close = 3 },
    },
}

-- Job / gang discounts on NPC shop purchases (player-owned stores set their own prices).
-- The best matching discount applies; worked out on the server.
Config.Discounts = {
    Enabled     = false,
    MaxDiscount = 0.50,
    Jobs  = { -- ['vallaw'] = 0.10,
    },
    Gangs = { -- ['odriscoll'] = 0.05,
    },
}

-- Wholesale: owners of player stores buy stock straight onto the shelf from a supplier.
Config.Wholesale = {
    Enabled = true,
    PayFrom = 'either',    -- 'till' | 'cash' | 'either' (till first, then cash)
    Markup  = 1.5,         -- default shelf price for a new listing = cost x Markup
    Items = {              -- item = cost each
        bread = 0.10,
        water = 0.10,
    },
}

-- Sales ledger shown to owners in the management panel.
Config.Ledger = {
    Enabled = true,
    Keep    = 100,   -- entries kept per store
    Show    = 50,    -- entries shown in the panel
}

-- Labels are locale keys (locales/*.json), translated when the admin menu opens.
Config.BlipTypes = {
    { label = 'cfg_blip_general_store', value = 1475879922 },   -- blip_shop_store
    { label = 'cfg_blip_gunsmith', value = -145868367 },        -- blip_shop_gunsmith
    { label = 'cfg_blip_butcher', value = -1665418949 },        -- blip_shop_butcher
    { label = 'cfg_blip_saloon', value = 1879260108 },          -- blip_saloon
}

Config.NpcModels = {
    { label = 'cfg_model_tumbleweed_store', value = 'u_f_m_tumgeneralstoreowner_01' },
    { label = 'cfg_model_armadillo_store', value = 'u_m_m_armgeneralstoreowner_01' },
    { label = 'cfg_model_saintdenis_store', value = 'u_m_m_nbxgeneralstoreowner_01' },
    { label = 'cfg_model_rhodes_store_1', value = 'u_m_m_rhdgenstoreowner_01' },
    { label = 'cfg_model_rhodes_store_2', value = 'u_m_m_rhdgenstoreowner_02' },
    { label = 'cfg_model_strawberry_store', value = 'u_m_m_strgenstoreowner_01' },
    { label = 'cfg_model_valentine_store', value = 'u_m_m_valgenstoreowner_01' },
    { label = 'cfg_model_wallace_store', value = 'u_m_m_walgeneralstoreowner_01' },
    { label = 'cfg_model_annesburg_gunsmith', value = 'u_m_m_asbgunsmith_01' },
    { label = 'cfg_model_saintdenis_gunsmith', value = 'u_m_m_nbxgunsmith_01' },
    { label = 'cfg_model_rhodes_gunsmith', value = 'u_m_m_rhdgunsmith_01' },
    { label = 'cfg_model_tumbleweed_gunsmith', value = 'u_m_m_tumgunsmith_01' },
    { label = 'cfg_model_valentine_gunsmith', value = 'u_m_m_valgunsmith_01' },
    { label = 'cfg_model_generic_butcher', value = 's_m_m_unibutchers_01' },
    { label = 'cfg_model_tumbleweed_butcher', value = 'u_m_m_tumbutcher_01' },
    { label = 'cfg_model_valentine_butcher', value = 'u_m_m_valbutcher_01' },
    { label = 'cfg_model_saintdenis_trapper', value = 'u_m_m_sdtrapper_01' },
    { label = 'cfg_model_thieveslanding_bartender', value = 'u_f_m_tljbartender_01' },
    { label = 'cfg_model_vanhorn_bartender', value = 'u_f_m_vhtbartender_01' },
    { label = 'cfg_model_saintdenis_bartender_1', value = 'u_m_m_nbxbartender_01' },
    { label = 'cfg_model_saintdenis_bartender_2', value = 'u_m_m_nbxbartender_02' },
    { label = 'cfg_model_rhodes_bartender', value = 'u_m_m_rhdbartender_01' },
    { label = 'cfg_model_armadillo_bartender', value = 'u_m_o_armbartender_01' },
    { label = 'cfg_model_blackwater_bartender', value = 'u_m_o_blwbartender_01' },
    { label = 'cfg_model_valentine_bartender', value = 'u_m_o_valbartender_01' }
}

Config.BlipColors = {
    { label = 'cfg_color_white', value = 'BLIP_MODIFIER_MP_COLOR_32' },
    { label = 'cfg_color_red', value = 'BLIP_MODIFIER_MP_COLOR_2' },
    { label = 'cfg_color_purple', value = 'BLIP_MODIFIER_MP_COLOR_3' },
    { label = 'cfg_color_orange', value = 'BLIP_MODIFIER_MP_COLOR_4' },
    { label = 'cfg_color_light_blue', value = 'BLIP_MODIFIER_MP_COLOR_5' },
    { label = 'cfg_color_yellow', value = 'BLIP_MODIFIER_MP_COLOR_6' },
    { label = 'cfg_color_pink', value = 'BLIP_MODIFIER_MP_COLOR_7' },
    { label = 'cfg_color_green', value = 'BLIP_MODIFIER_MP_COLOR_8' },
    { label = 'cfg_color_dark_blue', value = 'BLIP_MODIFIER_MP_COLOR_9' },
}
