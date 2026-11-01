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
Config.TargetDistance = 2.5       -- ox_target range; server allows +5.0 for latency


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
