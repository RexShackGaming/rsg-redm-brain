Config = {}

---------------------------------------------------------------------
-- All coords / models / anim scenes below come from the RDR2
-- decompiled scripts (build 1436, script_rel):
--   show_nbx_*.c          -> scene dicts, origins, entity names, models
--   generic_show_mc.c     -> curtain model P_NEW_THEATER_CURTAIN, MC CS_CABARETMC
--   theatre_ticket_taker.c-> ticket fence volume at 2540.43, -1280.87, 48.02
---------------------------------------------------------------------

Config.Debug = false

-- Ticket seller (placed at the ticket fence volume from theatre_ticket_taker.c)
Config.TicketSeller = {
    model  = `A_M_M_NBXUPPERCLASS_01`,
    coords = vector4(2542.20, -1282.52, 49.22, 46.44),
    blip   = { sprite = `blip_ambient_theatre` }, -- rdr3_discoveries textures/blips; name is locale 'blip_name'
    targetDistance = 2.0,
    buyDistance    = 6.0,          -- server-side max distance from the seller to buy
}

Config.TicketPrice      = 1.50          -- cash per ticket (server side)
Config.TicketCooldown   = 3             -- seconds between purchases per player

-- Show schedule (server driven)
Config.ShowInterval     = 15            -- minutes between shows
Config.FirstShowDelay   = 2             -- minutes after resource start
Config.ShowOrder        = 'rotation'    -- 'rotation' or 'random'
Config.MaxShowLength    = 420           -- seconds, safety cap on a single show

-- Players must be within this radius of the stage when the show starts
Config.Stage            = vector3(2546.41, -1303.55, 46.9)
Config.AudienceRadius   = 30.0

-- Performers and props are created backstage, then the anim scene moves them on stage
-- (Local_8.f_42 in show_nbx_bigband_02.c / show_nbx_cancan.c)
Config.Backstage        = vector3(2553.875, -1313.143, 48.2166)

-- NPC audience, spawned locally for each viewer while a show plays
-- (show_nbx_cancan.c func_37 / func_174-178: 56 theatre seats, NBX_CIVILIANS population set,
--  seated with the PROP_HUMAN_SEAT_CHAIR scenario; spots 53-55 are standing spots and left out)
Config.Audience = {
    enabled  = true,
    fill     = 0.6,                      -- fraction of seats to fill (0.0 - 1.0); lower = better performance
    popSet   = `NBX_CIVILIANS`,           -- Rockstar's Saint Denis population set
    scenario = `PROP_HUMAN_SEAT_CHAIR`,
    -- used if the population set returns nothing (models from rdr3_discoveries peds list)
    fallbackModels = {
        `A_M_M_NBXUPPERCLASS_01`, `A_F_M_NBXUPPERCLASS_01`,
        `A_M_M_NBXSLUMS_01`, `A_F_M_NBXSLUMS_01`, `A_M_M_NBXLABORERS_01`,
    },
    seats = {
    vector4(2541.954, -1303.652, 47.51162, 189.76),
    vector4(2542.625, -1303.628, 47.50835, 194.54),
    vector4(2543.253, -1303.504, 47.51194, 185.02),
    vector4(2543.914, -1303.447, 47.50978, 185.67),
    vector4(2544.554, -1303.35, 47.51124, 186.48),
    vector4(2545.212, -1303.286, 47.48675, 189.64),
    vector4(2540.851, -1302.391, 47.83032, 194.87),
    vector4(2541.405, -1302.162, 47.83151, 197.45),
    vector4(2542.039, -1301.995, 47.83165, 192.94),
    vector4(2542.659, -1301.895, 47.83114, 190.4),
    vector4(2543.281, -1301.785, 47.83141, 187.74),
    vector4(2543.887, -1301.719, 47.8308, 188.21),
    vector4(2544.536, -1301.635, 47.831, 191.46),
    vector4(2545.165, -1301.591, 47.81311, 187.8),
    vector4(2540.816, -1300.638, 48.12306, 197.77),
    vector4(2541.43, -1300.473, 48.12244, 197.28),
    vector4(2542.034, -1300.312, 48.12096, 195.7),
    vector4(2542.644, -1300.153, 48.12228, 194.38),
    vector4(2543.269, -1300.039, 48.12248, 189.91),
    vector4(2543.896, -1299.926, 48.12423, 187.19),
    vector4(2545.169, -1299.818, 48.10023, 183.35),
    vector4(2540.844, -1298.88, 48.39516, 195.68),
    vector4(2541.442, -1298.742, 48.39409, 195.08),
    vector4(2542.07, -1298.587, 48.39284, 197.6),
    vector4(2543.302, -1298.275, 48.39411, 192.22),
    vector4(2543.898, -1298.179, 48.39465, 187.31),
    vector4(2544.536, -1298.092, 48.39633, 186.63),
    vector4(2550.958, -1303.615, 47.48922, 174.21),
    vector4(2550.302, -1303.543, 47.48922, 175.4),
    vector4(2549.651, -1303.483, 47.48394, 177.33),
    vector4(2549.005, -1303.43, 47.48394, 177.62),
    vector4(2548.356, -1303.367, 47.48394, 175.4),
    vector4(2547.713, -1303.341, 47.48394, 176.59),
    vector4(2552.097, -1302.355, 47.80622, 165.32),
    vector4(2551.509, -1302.193, 47.80622, 170.16),
    vector4(2550.899, -1302.034, 47.80622, 170.37),
    vector4(2550.298, -1301.884, 47.80622, 174.13),
    vector4(2549.661, -1301.76, 47.80622, 175.59),
    vector4(2549.037, -1301.683, 47.80622, 173.64),
    vector4(2548.413, -1301.624, 47.80622, 178.62),
    vector4(2552.122, -1300.556, 48.09521, 169.96),
    vector4(2551.499, -1300.414, 48.09521, 171.41),
    vector4(2550.871, -1300.243, 48.09521, 170.19),
    vector4(2550.255, -1300.129, 48.09521, 171.15),
    vector4(2549.635, -1300.029, 48.09521, 174.93),
    vector4(2549.016, -1299.949, 48.09521, 177.61),
    vector4(2552.115, -1298.813, 48.36841, 169.6),
    vector4(2551.499, -1298.658, 48.36841, 171.53),
    vector4(2550.254, -1298.388, 48.36841, 172.77),
    vector4(2549.629, -1298.312, 48.36841, 174.2),
    vector4(2549.001, -1298.207, 48.36841, 175.33),
    vector4(2548.368, -1298.123, 48.36841, 175.1),
    vector4(2547.733, -1298.041, 48.36841, 176.09),

    },
}

-- Admin command to force a show: /theatre <showId>
Config.AdminCommand     = 'theatre'
Config.AdminPermission  = 'admin'

-- Curtain (generic_show_mc.c / show_nbx_cancan.c func_161/func_163)
Config.Curtain = {
    model     = `P_NEW_THEATER_CURTAIN`,
    coords    = vector3(2546.522, -1306.835, 48.26664),
    sceneDict = 'script@shows@curtains@curtains',
    entity    = 'CURTAIN',
    closed    = 'PBL_IDLE_CLOSED',
    open      = 'PBL_OPEN_SLOW',
    close     = 'PBL_CLOSE_SLOW',
}
Config.CurtainRange       = 60.0   -- curtain is spawned (closed) while you're this close to the stage
Config.CurtainOpenDelay   = 3000   -- ms after the curtain starts opening before the act begins
Config.CurtainCloseDelay  = 4000   -- ms to let the curtain close before the 'show over' message

local O1 = { coords = vector3(2546.41,  -1303.55,  46.9),   rot = vector3(0.0, 0.0, 40.0) }
local O2 = { coords = vector3(2546.453, -1303.998, 46.793), rot = vector3(0.0, 0.0, 40.0) }
local O3 = { coords = vector3(2546.525, -1302.055, 46.79),  rot = vector3(0.0, 0.0, 40.0) }

-- Each show: scene = anim scene dict, playlist = starting playlist,
-- sequence = optional follow-on playlists played in order, flags = scene flags (default 2),
-- origin = optional (nil uses the origin baked into the scene),
-- peds = { scene entity name = model }, props = { scene entity name = model },
-- volunteer = optional seated audience member who is part of the act { entity, model, seat }
-- rope = optional rope tying a prop to a frozen anchor { prop, anchorModel, anchorCoords, coords, length, ropeType }
Config.Shows = {
    {
        id = 'cancan1', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@cancan_dance@CanCanDanceP1', playlist = 'PB_MAIN', origin = O1,
        peds = {
            CS_CANCAN_01 = `CS_CANCAN_01`, CS_CANCAN_02 = `CS_CANCAN_02`,
            CS_CANCAN_03 = `CS_CANCAN_03`, CS_CANCAN_04 = `CS_CANCAN_04`,
            CS_CANCANMAN_01 = `CS_CANCANMAN_01`,
        },
        props = {},
    },
    {
        id = 'cancan2', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@cancan_dance@CanCanDanceP2', origin = O1,
        peds = {
            CS_CANCAN_01 = `CS_CANCAN_01`, CS_CANCAN_02 = `CS_CANCAN_02`,
            CS_CANCAN_03 = `CS_CANCAN_03`, CS_CANCAN_04 = `CS_CANCAN_04`,
            CS_CANCANMAN_01 = `CS_CANCANMAN_01`,
        },
        props = {},
    },
    {
        id = 'bigband', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@band_play@p1_and_p2', playlist = 'PL_P1', origin = O3,
        peds = {
            CS_BANDBASSIST = `CS_BANDBASSIST`, CS_BANDDRUMMER = `CS_BANDDRUMMER`,
            CS_BANDPIANIST = `CS_BANDPIANIST`, CS_BANDSINGER = `CS_BANDSINGER`,
        },
        props = {
            ['p_benchpiano02x']    = `P_BENCHPIANO02X`,
            ['p_benchPiano02x^1']  = `P_BENCHPIANO02X`,
            ['p_cs_contrabass01x'] = `P_CS_CONTRABASS01X`,
            ['p_cs_drumkit01x']    = `P_CS_DRUMKIT01X`,
            ['p_drumstick01x']     = `P_DRUMSTICK01X`,
            ['p_drumstick01x^1']   = `P_DRUMSTICK01X`,
            ['p_piano01x']         = `P_NBXPIANO01X`,
        },
    },
    {
        id = 'firedance1', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@fire_performer@act1_p1@action', origin = O2,
        peds = { PERFORMER = `CS_FIRE_BREATHER` },
        props = {
            BOTTLE  = `P_BOTTLE03X`,
            lantern = `P_LIGHT_SD_THEATER01X`,
            BATON   = `S_FIREBATON01X`,
            TABLE   = `P_TABLE_SD_THEATER01X`,
        },
    },
    {
        id = 'firedance2', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@fire_dancer@act3_p1@action', origin = O2,
        peds = { DANCER = `CS_FIRE_BREATHER` },
        props = {
            LOTUS_0 = `S_LOTUSFIREPALM_01X`,
            LOTUS_1 = `S_LOTUSFIREPALM_01X`,
            LANTERN = `P_LIGHT_SD_THEATER01X`,
        },
    },
    {
        -- origin not set explicitly in show_nbx_snakedance_01.c; uses the shared stage origin
        id = 'snakedance', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@snake_dancer@act1_p1@action', playlist = 'PL_DANCE', origin = O2,
        peds = { DANCER = `CS_SWORDDANCER`, SNAKE = `A_C_SNAKEREDBOA10FT_01` },
        props = {},
    },
    {
        id = 'sworddance', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@sword_dancer@act3_p1@action', origin = O2,
        peds = { DANCER = `CS_SWORDDANCER` },
        props = { Sword = `P_SWORD01X` },
    },

    -- added from the 1436 show_nbx_* scripts (func_27 = models/origin/scene, func_169-style
    -- SET_ANIM_SCENE_ENTITY block = entity names, playlist switch functions = sequence)
    {
        id = 'bigband2', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@band_play@p1_and_p2', playlist = 'PL_P2', origin = O3,   -- show_nbx_bigband_02.c
        peds = {
            CS_BANDBASSIST = `CS_BANDBASSIST`, CS_BANDDRUMMER = `CS_BANDDRUMMER`,
            CS_BANDPIANIST = `CS_BANDPIANIST`, CS_BANDSINGER = `CS_BANDSINGER`,
        },
        props = {
            ['p_benchpiano02x']    = `P_BENCHPIANO02X`,
            ['p_benchPiano02x^1']  = `P_BENCHPIANO02X`,
            ['p_cs_contrabass01x'] = `P_CS_CONTRABASS01X`,
            ['p_cs_drumkit01x']    = `P_CS_DRUMKIT01X`,
            ['p_drumstick01x']     = `P_DRUMSTICK01X`,
            ['p_drumstick01x^1']   = `P_DRUMSTICK01X`,
            ['p_piano01x']         = `P_NBXPIANO01X`,
        },
    },
    {
        id = 'firebreath', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@fire_breather@act2_p1@action', playlist = 'PL_Dance',   -- show_nbx_firebreath_01.c
        sequence = { 'Pl_BreathWin' },
        origin = O2,
        peds = { DANCER = `CS_FIRE_BREATHER` },
        props = {
            BOTTLE   = `P_BOTTLE03X`,
            STICK_0_ = `S_FIRESTICK01X`,
            STICK_1_ = `S_FIRESTICK01X`,
            TABLE    = `P_TABLE_SD_THEATER01X`,
            lantern  = `P_LIGHT_SD_THEATER01X`,
        },
    },
    {
        id = 'snakedance2', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@snake_dancer@act2_p1@action', playlist = 'PL_DANCE',    -- show_nbx_snakedance_02.c
        origin = O2, -- not set in the script, same as Act I
        peds = { DANCER = `CS_SWORDDANCER`, SNAKE = `A_C_SNAKEREDBOA10FT_01` },
        props = {},
    },
    {
        id = 'strongwoman', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@feats_of_strength@act1@action', playlist = 'Pbl_Intro', -- show_nbx_strongwoman.c
        sequence = { 'PBL_SUCCESS' },
        origin = nil, -- script never sets an origin on this scene
        peds = { Female = `CS_FEATSOFSTRENGTH`, male = `U_M_M_SDSTRONGWOMANASSISTANT_01` },
        props = {
            BAR   = `S_RE_STRONGBAR01X`,
            CHEST = `P_SDTHEATER_CHEST01X`,
            HAMMER = `P_SLEDGEHAMMER01X`,
            Block = `S_CINDERBLOCK01X`,
            BOOK  = `S_RIPPABLEBOOK01X`,
        },
    },
    {
        id = 'escapeartist', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@escape_artist@act2_p1@action', playlist = 'PL_A_Performance', -- show_nbx_escapeartist.c
        sequence = { 'PL_B_Loop', 'PL_C_Reappears_Among_Crowd_AI', 'PL_E_Outro' },
        origin = O2,
        peds = { Benjamin = `CS_ESCAPEARTIST`, ASSISTANT_ = `CS_ESCAPEARTISTASSISTANT` },
        props = { BOX = `S_ESCAPEBOX01X`, Knife = `W_MELEE_KNIFE05`, mask = `P_CS_ESCAPEARTIST_MASK` },
    },
    {
        id = 'escapenoose', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@shows@escape_noose@act3_p1@action', playlist = 'PL_A_Performance', -- show_nbx_escapenoose.c
        sequence = { 'PL_B_Trying_To_Escape', 'PL_C_Choking', 'PL_E_Shoot_Rope' },
        origin = O2,
        peds = { BENJAMIN_NO_JACKET = `CS_ESCAPEARTIST`, Assistant = `CS_ESCAPEARTISTASSISTANT` },
        props = {
            NOOSE_STAND = `S_NOOSESTAND01X`,
            JACKET      = `P_CS_STRAIGHTJACKET`,
            DIVIDER     = `P_DIVIDER01X`,
            Noose       = `P_CS_NOOSE01XB`,
        },
        -- the noose hangs from a short rope tied to a frozen anchor in the rigging
        -- (show_nbx_escapenoose.c: func_237/func_238 anchor, _ADD_ROPE_2 + _ATTACH_ENTITIES_TO_ROPE_2)
        rope = {
            prop         = 'Noose',
            anchorModel  = `P_SHOTGLASS01X`,
            anchorCoords = vector3(2546.771, -1310.344, 50.83665),
            coords       = vector3(2546.724, -1309.638, 50.76665),
            length       = 0.3,
            ropeType     = 1,
        },
    },
    {
        id = 'oddfellows', -- name/description: locales show_<id> / show_<id>_desc
        scene = 'script@rcm@roddf@ig@roddf_s3@roddf_s3', playlist = 'pl_Performance', flags = 0, -- show_nbx_oddfellows.c
        origin = nil, -- the script never sets an origin on this scene (f_50 is assigned but unused); it's baked into the dict
        peds = {
            CS_GENSTORYFEMALE    = `CS_MISSMARJORIE`,
            CS_ODDFELLOWSPINHEAD = `CS_ODDFELLOWSPINHEAD`,
            CS_MAGNIFICO         = `CS_MAGNIFICO`,
        },
        props = { p_cs_bullwhip01x = `P_CS_BULLWHIP01X` },
        -- audience member pulled into the act: show_nbx_oddfellows.c func_46 grabs the ped in
        -- this seat as CS_GENSTORYMALE; show_nbx_cancan.c func_37 seats this model there for Odd Fellows
        volunteer = {
            entity = 'CS_GENSTORYMALE',
            model  = `U_M_M_ODDFELLOWPARTICIPANT_01`,
            seat   = vector4(2544.554, -1303.35, 47.51124, 186.48),
        },
    },
}
