Config = {}

Config.Debug = false   -- prints setup info (render target, projector, house lights) to the F8 console

-- Values below come from the RDR2 decompiled scripts (decompile/1355/script_rel):
--   show_movie_magic_lantern.c  func_156  (projector light, render target, volume)
--                               func_76   (cinema interior centre)
--                               func_154  (playlists)
--   theatre_ticket_taker.c      func_13   (ticket counter position)
-- Ticket seller model s_m_m_sdticketseller_01 from rdr3_discoveries/peds/peds_list.lua

Config.TicketPrice    = 1.0     -- cash, per showing
Config.ShowInterval   = 15      -- minutes between showings (per cinema)
Config.SalesWindow    = 10      -- minutes before a showing that tickets go on sale
Config.MaxShowLength  = 600     -- seconds; safety cut-off if no client reports end of film
Config.MinShowLength  = 60      -- seconds; end-of-film reports earlier than this are ignored
Config.LightsDim      = 0.05    -- house light intensity during a film (1.0 = normal, 0.0 = off)
Config.LightsFade     = 3000    -- ms to fade the house lights down / up
Config.WatchRadius    = 25.0    -- player must be this close to the cinema centre to see the film
Config.SellerSpawnDistance = 50.0 -- ticket seller NPC spawns when a player is this close
Config.AdminCommand    = 'cinemaadmin' -- opens the admin panel (start/stop films)
Config.AdminPermission = 'admin'

-- Film list: playlist = TV playlist name from show_movie_magic_lantern.c func_154
-- label = locale key (locales/*.json); cinema labels below are locale keys too
Config.Films = {
    { playlist = 'PL_MLAN_BEAR', label = 'film_bear' },
    { playlist = 'PL_MLAN_JOSIAH_BLACKWATER', label = 'film_josiah_blackwater' },
    { playlist = 'PL_MLAN_SECRET_OF_MANFLIGHT', label = 'film_secret_manflight' },
    { playlist = 'PL_MLAN_SAVIORS_AND_SAVAGES', label = 'film_saviors_savages' },
    { playlist = 'PL_MLAN_GHOST_STORY', label = 'film_ghost_story' },
    { playlist = 'PL_TOON_DIRECT_CURRENT_DAMNATION', label = 'film_direct_current' },
    { playlist = 'PL_TOON_FARMERS_DAUGHTER', label = 'film_farmers_daughter' },
    { playlist = 'PL_TOON_MODERN_MEDICINE', label = 'film_modern_medicine' },
    { playlist = 'PL_TOON_WORLDS_STRONGEST_MAN', label = 'film_strongest_man' },
    { playlist = 'PL_TOON_SKETCHING_FOR_SWEETHEART', label = 'film_sketching_sweetheart' },
}

-- To add a town, copy a block and set enabled = true.
-- screen    = where Rockstar spawns the hidden render-target object (model = linkModel)
-- projector = coords of the S_MOVIEPROJECTION01X map light (Rockstar pins it and projects the film through it)
Config.Cinemas = {
    saintdenis = {
        enabled      = true,
        label        = 'cinema_saintdenis',
        centre       = vector3(2696.776, -1353.734, 48.56572),
        renderTarget = 'bla_theater',
        linkModel    = 'SCRIPT_RT_VAL_MAGICLANTERN',
        projModel    = 'S_MOVIEPROJECTION01X',
        screen       = vector4(2702.49, -1348.78, 49.61, 130.1),         -- render target object (func_156 f_1077/f_1080)
        projector    = vector3(2694.768, -1355.454, 52.013),   -- func_156 case 1 (case 2 uses 2687.582, -1362.665, 55.639)
        draw         = { x = 0.5, y = 0.5, w = 1.0, h = 1.0 },     -- film position/size on the screen (0-1); tune live in /cinemaadmin > Picture
        volume       = 6.0,
        seller       = { model = 's_m_m_sdticketseller_01', coords = vector4(2687.112, -1361.769, 48.25, 130.0) },
        films        = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, -- indexes into Config.Films, played in rotation
        -- house lights dimmed while a film plays (show_movie_magic_lantern.c func_103-113, case 1)
        lights = {
            { model = 'P_LAMPWALL03X', coords = {
                vector3(2698.354, -1347.851, 48.38391), vector3(2702.992, -1353.339, 48.37968) } },
            { model = 'P_NAPOLEONLIGHT01X', coords = {
                vector3(2691.054, -1352.816, 52.59), vector3(2696.695, -1359.527, 52.59) } },
            { model = 'P_BULB_G_STAGE01X', coords = {
                vector3(2700.432, -1348.183, 47.87681), vector3(2700.377, -1348.514, 47.85976), vector3(2700.37, -1348.888, 47.8551),
                vector3(2700.434, -1349.257, 47.86578), vector3(2700.558, -1349.631, 47.84948), vector3(2701.542, -1350.802, 47.85961),
                vector3(2701.878, -1350.986, 47.88033), vector3(2702.219, -1351.111, 47.86714), vector3(2702.572, -1351.179, 47.87275),
                vector3(2702.962, -1351.181, 47.87634), vector3(2701.173, -1350.579, 47.846), vector3(2700.92, -1350.285, 47.846),
                vector3(2700.691, -1349.987, 47.846) } },
            { model = 'P_BULB_G_01X', coords = {
                vector3(2697.828, -1347.849, 48.061), vector3(2697.828, -1347.854, 48.89), vector3(2697.827, -1347.856, 49.633),
                vector3(2697.825, -1347.853, 50.458), vector3(2697.889, -1347.932, 51.201), vector3(2698.051, -1348.127, 52.013),
                vector3(2698.298, -1348.42, 52.674), vector3(2698.682, -1348.865, 53.307), vector3(2699.068, -1349.323, 53.747),
                vector3(2699.578, -1349.924, 54.096), vector3(2700.049, -1350.493, 54.234), vector3(2700.6, -1351.151, 54.236),
                vector3(2701.085, -1351.721, 54.095), vector3(2701.579, -1352.32, 53.744), vector3(2701.959, -1352.784, 53.318),
                vector3(2702.34, -1353.231, 52.683), vector3(2702.584, -1353.52, 52.034), vector3(2702.747, -1353.716, 51.212),
                vector3(2702.814, -1353.797, 50.457), vector3(2702.818, -1353.797, 49.618), vector3(2702.819, -1353.797, 48.896),
                vector3(2702.817, -1353.803, 48.036) } },
        },
        blip         = { sprite = 'blip_ambient_theatre', scale = 0.2 },
    },
    valentine = {
        enabled      = true,
        label        = 'cinema_valentine',
        centre       = vector3(-348.3176, 698.5706, 117.706),
        renderTarget = 'bla_theater',
        linkModel    = 'SCRIPT_RT_VAL_MAGICLANTERN',
        projModel    = 'S_MOVIEPROJECTION01X',
        screen       = vector4(-346.8974, 692.4412, 119.3474, 18.68),
        projector    = vector3(-349.2042, 701.0595, 119.1245),
        draw         = { x = 0.5, y = 0.5, w = 0.47, h = 0.45 },
        volume       = 1.5,
        entitySets   = { open = 'val_magiclantern_intgroup_open', closed = 'val_magiclantern_intgroup_closed' },
        seller       = { model = 's_m_m_sdticketseller_01', coords = vector4(-355.2777, 704.6901, 117.0523, 0.0) },
        films        = { 1, 2, 3, 4, 5 },
        blip         = { sprite = 'blip_ambient_theatre', scale = 0.2 },
    },
    blackwater = {
        enabled      = true,
        label        = 'cinema_blackwater',
        centre       = vector3(-779.4891, -1362.618, 45.14579),
        renderTarget = 'bla_theater',
        linkModel    = 'SCRIPT_RT_BLA_THEATER',
        projModel    = 'S_MOVIEPROJECTION01X',
        screen       = vector4(-772.29, -1362.65, 45.32, 90.0),
        projector    = vector3(-781.485, -1363.402, 47.649),
        draw         = { x = 0.5, y = 0.5, w = 0.66, h = 0.46 },
        volume       = 1.5,
        seller       = { model = 's_m_m_sdticketseller_01', coords = vector4(-789.86, -1362.55, 43.82, 278.03) },
        films        = { 6, 7, 8, 9, 10 },
        lights = { -- func_103-111, case 4
            { model = 'P_LIGHTBULB01X', coords = {
                vector3(-777.252, -1367.02, 44.965), vector3(-780.828, -1366.866, 45.282),
                vector3(-777.252, -1358.225, 44.965), vector3(-780.85, -1358.394, 45.282) } },
            { model = 'P_LAMPWALL04X', coords = { vector3(-783.34, -1367.153, 45.388), vector3(-783.939, -1360.04, 45.325) } },
        },
        blip         = { sprite = 'blip_ambient_theatre', scale = 0.2 },
    },
}
