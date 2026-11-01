Config = {}

-----------------------------------------------------------
-- settings
-----------------------------------------------------------
Config.TicketItem     = 'boat_ticket'
Config.TicketCost     = 10      -- cash per ticket
Config.MaxTickets     = 10      -- max tickets per purchase
Config.BuyCooldown    = 5       -- seconds
Config.TravelCooldown = 30      -- seconds
Config.InteractRadius = 5.0     -- server-side max distance from the port NPC
Config.DistanceSpawn  = 20.0    -- NPC spawn distance
Config.FadeIn         = true    -- fade NPCs in/out
Config.TravelTime     = 3000    -- ms the screen stays black while travelling

-----------------------------------------------------------
-- blip settings
-----------------------------------------------------------
Config.Blip = {
    sprite = 'blip_ambient_riverboat',
    scale  = 0.2,
}

-----------------------------------------------------------
-- ports (key = port id, destination = port id to sail to)
-----------------------------------------------------------
Config.Ports = {
    stdenis = {
        label       = 'port_stdenis',   -- locale key
        guarma      = false,
        destination = 'guarma',
        showblip    = true,
        npcmodel    = `u_m_o_rigtrainstationworker_01`,
        npccoords   = vector4(2662.3156, -1541.951, 45.969783, 265.44274),
        arrival     = vector4(2663.2485, -1544.214, 45.969753, 266.12268),
    },
    guarma = {
        label       = 'port_guarma',    -- locale key
        guarma      = true,
        destination = 'stdenis',
        showblip    = true,
        npcmodel    = `u_m_o_rigtrainstationworker_01`,
        npccoords   = vector4(1268.4835, -6850.459, 43.318496, 212.38269),
        arrival     = vector4(1268.4954, -6853.771, 43.318477, 241.44442),
    },
}

-----------------------------------------------------------
-- guarma world (values from RDR2 decompiled guama*.c scripts)
-----------------------------------------------------------
Config.Guarma = {
    AmbientAudio  = true,               -- island ambience (AZL_Endlesss_Summer, guama1-3.c / camp_guarma.c)
    Shipwreck = {                       -- story steamer map data (guama1.c)
        enabled = true,
        ipl     = -425834853,           -- 0xE69E469B (data/rdr3_discoveries/imaps)
        cullbox = 'Guarma_Boat',
    },
    Population = {                      -- per-frame density while on Guarma (aguasdulces.c); 1.0 = game default (no per-frame loop)
        enabled         = true,
        humanDensity    = 1.0,
        pedRange        = 1.0,
        scenarioDensity = 1.0,
        scenarioRange   = 1.0,
    },
}

-----------------------------------------------------------
-- guarma weather (server picks one shared weather for the island)
-- needs rsg-weather; while on Guarma the player's rsg-weather sync is paused
-----------------------------------------------------------
Config.Weather = {
    enabled    = true,
    interval   = 20,     -- minutes between changes
    transition = 15.0,   -- seconds
    types = {            -- weighted chance (valid rsg-weather types)
        highpressure = 55,
        clouds       = 20,
        fog          = 10,
        drizzle      = 10,
        hurricane    = 5,   -- uses the Guarma hurricane variation (HURRICANE_guama)
    },
}

-----------------------------------------------------------
-- Fussar's soldiers (patrol routes from region_law_guama_fussar.c)
-- networked peds spawned by the server (everyone sees the same soldiers), hostile to players
-----------------------------------------------------------
Config.Soldiers = {
    enabled         = true,   -- set to false for a peaceful Guarma (no soldiers spawn at all)
    model           = `s_m_m_fussarhenchman_01`,
    spawnDistance   = 120.0,
    despawnDistance = 160.0,
    pedsPerRoute    = 2,
    weapons         = { `WEAPON_REPEATER_CARBINE`, `WEAPON_REVOLVER_CATTLEMAN` },
    sniperWeapon    = `WEAPON_SNIPERRIFLE_CARCANO`,
    routes = {
        { enabled = true,  sniper = false, nodes = { vector3(1547.69, -7061.763, 80.98825), vector3(1463.462, -6979.851, 72.17596), vector3(1492.056, -6945.109, 75.02325), vector3(1569.833, -7010.37, 84.61304) } },
        { enabled = true,  sniper = false, nodes = { vector3(1423.832, -7077.051, 68.73053), vector3(1332.573, -7009.969, 52.6828), vector3(1394.447, -6937.98, 61.26836), vector3(1466.745, -7052.835, 70.23048) } },
        -- closest route to the port (~60m), off by default so arriving players aren't shot
        { enabled = false, sniper = false, nodes = { vector3(1276.878, -6914.748, 42.99872), vector3(1269.852, -6986.301, 44.36502), vector3(1252.001, -7091.143, 40.75356), vector3(1211.104, -7103.643, 41.48995) } },
        { enabled = true,  sniper = false, nodes = { vector3(1309.89, -7050.633, 47.73157), vector3(1282.163, -7093.915, 45.52501), vector3(1397.532, -7138.745, 67.66041), vector3(1411.206, -7068.766, 66.23284) } },
        { enabled = true,  sniper = true,  nodes = { vector3(1683.376, -7223.112, 132.7217), vector3(1623.999, -7313.509, 112.2114), vector3(1577.847, -7362.998, 100.5893), vector3(1657.111, -7251.768, 124.6736) } },
        { enabled = true,  sniper = false, nodes = { vector3(1576.992, -7361.878, 100.3456), vector3(1608.229, -7481.153, 128.0874), vector3(1540.681, -7432.281, 113.7524) } },
        { enabled = true,  sniper = true,  nodes = { vector3(1506.142, -7520.447, 158.1895), vector3(1620.642, -7540.919, 144.9812), vector3(1542.976, -7397.477, 106.9753), vector3(1470.417, -7369.557, 97.17374) } },
        { enabled = true,  sniper = false, nodes = { vector3(1143.145, -7259.119, 73.90079), vector3(1192.581, -7217.897, 68.34444), vector3(1163.34, -7129.541, 50.03685), vector3(1230.028, -7148.012, 52.79202) } },
        { enabled = true,  sniper = false, nodes = { vector3(1208.154, -7057.239, 40.75641), vector3(1144.686, -7038.287, 41.26281), vector3(1142.318, -7114.154, 46.50215), vector3(1223.22, -7103.775, 40.93461) } },
    },
}
