Config = {}

Config.Debug = false

---------------------------------
-- Legendary trapper (sells maps, buys pelts)
-- Model: casp_hunting02_males_01 (rdr3_discoveries/peds/peds_list.lua)
-- Coords are a starting point next to the Valentine trapper (rsg-hunting) - move to suit your map.
---------------------------------
Config.Trappers = {
    {
        id = 'valentine',
        model = `casp_hunting02_males_01`,
        coords = vector4(-333.52, 769.63, 116.40, 112.45),
        blip = { enabled = true, sprite = `blip_shop_animal_trapper`, name = 'blip_trapper' }  -- locale key,
    },
}
Config.TrapperInteractDistance = 3.0   -- rsg-target distance
Config.TrapperServerDistance   = 6.0   -- server-side check for buy/sell
Config.TrapperSpawnDistance    = 80.0  -- trapper ped only exists while a player is this close

---------------------------------
-- Hunt flow
---------------------------------
Config.MapItem         = 'legendary_map'
Config.HuntDuration    = 60 * 60        -- seconds a started hunt stays active
Config.ClueCount       = 3              -- clues to inspect before the animal appears
Config.ClueSpread      = 120.0          -- clues are scattered this far from the zone centre (metres, 2D)
Config.RouteToClue       = true         -- draw a GPS route to the next clue
Config.ClueZoneDistance   = 40.0         -- clue prompt is armed once you're this close (terrain is loaded)
Config.ClueTargetDistance = 3.0          -- how close you must be for the 'Inspect tracks' prompt to show
Config.CluePromptKey      = 0xCEFD9220   -- E (RSGCore.Shared.Keybinds['E'])
Config.CluePromptHold     = 1000         -- ms to hold the key
Config.ClueInspectDist = 4.0            -- server check: player must be this close to a clue
Config.ClueInspectTime = 5000           -- ms crouch-inspect
Config.ClueScenario    = `WORLD_HUMAN_CROUCH_INSPECT`  -- rdr3_discoveries/animations/scenarios
Config.SpawnOffset     = 60.0           -- animal spawns this far beyond the last clue
Config.ActivateDistance = 120.0         -- the legendary spawns once you are this close to its spawn point
Config.SkinFallbackDelay = 15          -- seconds after death before an rsg-target 'Skin' option appears (0 = never). Covers models with no native skin prompt
Config.SkinTime        = 8000           -- ms progress bar for rsg-target skinning
Config.DeleteCarriedPelt = true        -- remove the vanilla pelt the game puts on your shoulder (you get the RSG items instead)
Config.SkinMaxDistance = 6.0            -- server: player must be this close to the carcass
Config.CooldownHours   = 24             -- per player, per legendary animal
Config.MoneyType       = 'cash'

---------------------------------
-- Kill quality: a legendary killed with one of these weapons counts as a 'perfect' kill
-- (weapon names from rdr3_discoveries/weapons). Perfect kills multiply the trinket rewards.
---------------------------------
Config.Quality = {
    Enabled        = true,
    PerfectWeapons = { `WEAPON_BOW`, `WEAPON_BOW_IMPROVED`, `WEAPON_MELEE_KNIFE`, `WEAPON_THROWN_THROWING_KNIVES`, `WEAPON_RIFLE_VARMINT` },
    TrinketMult    = 2,       -- perfect kill: trinket amounts x this (the pelt stays at 1)
}

-- Rare bonus: chance of one extra of the animal's trinket on any kill
Config.BonusTrinketChance = 0.10   -- 0.0 - 1.0

---------------------------------
-- Trophy board (trapper menu tab): first kill and fastest hunt per legendary
---------------------------------
Config.Trophies = {
    Enabled  = true,
    CacheSec = 60,            -- board is cached this long on the server
}

---------------------------------
-- Group hunts: the hunt owner invites nearby players (/invitehunt id, they /accepthunt).
-- Members see the trail; members near the carcass when it's skinned get the trinket rewards.
---------------------------------
Config.Group = {
    Enabled        = true,
    MaxMembers     = 3,       -- not counting the owner
    InviteDistance = 10.0,
    InviteTimeout  = 60,      -- seconds to accept
    ShareDistance  = 30.0,    -- members within this distance of the carcass share rewards
}

---------------------------------
-- Active hunts are saved and restored on relog / restart (until they expire)
---------------------------------
Config.SaveHunts = true

---------------------------------
-- rsg-telegram: the trapper sends a telegram when a legendary is off cooldown
---------------------------------
Config.CooldownTelegram = {
    Enabled  = true,
    CheckMin = 5,             -- how often the server checks (minutes)
}

-- Hunting XP requirement for buying maps (XP comes from rsg-hunting: exports['rsg-hunting']:GetHuntingXP,
-- stored as player rep 'hunting'). Each animal can set its own minXP; otherwise DefaultMinXP is used.
Config.XPRequirement = {
    Enabled      = true,
    DefaultMinXP = 1000,
    RepName      = 'hunting',   -- fallback if rsg-hunting isn't running (must match rsg-hunting Config.HuntingXP.RepName)
}

-- Blip styles (rdr3_discoveries/useful_info_from_rpfs/blip_styles)
Config.ZoneBlipStyle = `BLIP_STYLE_AREA`
Config.ClueBlipStyle = `BLIP_STYLE_OBJECTIVE`

---------------------------------
-- Legendary animals
-- Names/descriptions come from locales: animal_<key> and animal_<key>_desc
-- model: models from rdr3_discoveries/peds/peds_list.lua. The mp_a_c_* models are the Online legendary
--        variants; a_c_boarlegendary_01 and a_c_buffalo_tatanka_01 are dedicated legendary models.
-- outfit: outfit preset index. Verify in-game with /legendpreview <key> <preset> (admin) and pick the look you want.
-- zone: x,y centre of the hunting area (z is resolved on the client from the ground).
--       Zone centres are approximate - stand in the spot you want in-game and update them.
-- aggressive: true = attacks the hunter when it appears, false = wanders/flees
-- healthMult: multiplier on the model's normal max health
-- skin: 'native' (default, game skinning prompt) or 'target' (rsg-target + progress bar)
---------------------------------
Config.Animals = {
    bear = {
        model = `mp_a_c_bear_01`, outfit = 0, price = 25, minXP = 2500,
        zone = vector2(2690.0, 1120.0), radius = 250.0,
        aggressive = true, healthMult = 4.0,
        rewards = { { item = 'legendary_bear_pelt', amount = 1 }, { item = 'legendary_bear_claw', amount = 2 } },
    },
    buck = {
        model = `mp_a_c_buck_01`, outfit = 0, price = 15, minXP = 1000,
        zone = vector2(-1820.0, 560.0), radius = 250.0,
        aggressive = false, healthMult = 2.0,
        rewards = { { item = 'legendary_buck_pelt', amount = 1 }, { item = 'legendary_buck_antler', amount = 1 } },
    },
    boar = {
        model = `a_c_boarlegendary_01`, outfit = 0, price = 15, minXP = 1500,
        zone = vector2(2000.0, -620.0), radius = 220.0,
        aggressive = true, healthMult = 3.0,
        rewards = { { item = 'legendary_boar_pelt', amount = 1 }, { item = 'legendary_boar_tusk', amount = 2 } },
    },
    wolf = {
        model = `mp_a_c_wolf_01`, outfit = 0, price = 20, minXP = 2000,
        zone = vector2(1300.0, 1950.0), radius = 250.0,
        aggressive = true, healthMult = 3.0,
        rewards = { { item = 'legendary_wolf_pelt', amount = 1 }, { item = 'legendary_wolf_fang', amount = 2 } },
    },
    cougar = {
        model = `mp_a_c_cougar_01`, outfit = 0, price = 25,
        zone = vector2(-5300.0, -2600.0), radius = 250.0,
        aggressive = true, healthMult = 3.5,
        rewards = { { item = 'legendary_cougar_pelt', amount = 1 }, { item = 'legendary_cougar_fang', amount = 2 } },
    },
    panther = {
        model = `mp_a_c_panther_01`, outfit = 0, price = 30,
        zone = vector2(1500.0, -1700.0), radius = 220.0,
        aggressive = true, healthMult = 4.0,
        rewards = { { item = 'legendary_panther_pelt', amount = 1 }, { item = 'legendary_panther_fang', amount = 2 } },
    },
    bighorn = {
        model = `mp_a_c_bighornram_01`, outfit = 0, price = 15,
        zone = vector2(500.0, 1000.0), radius = 250.0,
        aggressive = false, healthMult = 2.5,
        rewards = { { item = 'legendary_bighorn_pelt', amount = 1 }, { item = 'legendary_bighorn_horn', amount = 1 } },
    },
    moose = {
        model = `mp_a_c_moose_01`, outfit = 0, price = 20,
        zone = vector2(2600.0, 1500.0), radius = 250.0,
        aggressive = false, healthMult = 3.0,
        rewards = { { item = 'legendary_moose_pelt', amount = 1 }, { item = 'legendary_moose_antler', amount = 1 } },
    },
    elk = {
        model = `mp_a_c_elk_01`, outfit = 1, price = 15,   -- or try `a_c_elk_01` (single-player model, 8 presets)
        zone = vector2(650.0, 1300.0), radius = 250.0,
        aggressive = false, healthMult = 2.5,
        skin = 'target',   -- mp_a_c_elk_01 has no native skin prompt
        rewards = { { item = 'legendary_elk_pelt', amount = 1 }, { item = 'legendary_elk_antler', amount = 1 } },
    },
    fox = {
        model = `mp_a_c_fox_01`, outfit = 0, price = 10,
        zone = vector2(1800.0, -1200.0), radius = 200.0,
        aggressive = false, healthMult = 1.5,
        rewards = { { item = 'legendary_fox_pelt', amount = 1 }, { item = 'legendary_fox_tail', amount = 1 } },
    },
    coyote = {
        model = `mp_a_c_coyote_01`, outfit = 0, price = 10,
        zone = vector2(900.0, -1100.0), radius = 220.0,
        aggressive = false, healthMult = 1.5,
        rewards = { { item = 'legendary_coyote_pelt', amount = 1 }, { item = 'legendary_coyote_fang', amount = 1 } },
    },
    alligator = {
        model = `mp_a_c_alligator_01`, outfit = 0, price = 30,
        zone = vector2(2400.0, -800.0), radius = 200.0,
        aggressive = true, healthMult = 5.0,
        rewards = { { item = 'legendary_alligator_skin', amount = 1 }, { item = 'legendary_alligator_tooth', amount = 2 } },
    },
    beaver = {
        model = `mp_a_c_beaver_01`, outfit = 0, price = 10,
        zone = vector2(2550.0, 300.0), radius = 180.0,
        aggressive = false, healthMult = 1.5,
        rewards = { { item = 'legendary_beaver_pelt', amount = 1 }, { item = 'legendary_beaver_tooth', amount = 1 } },
    },
    pronghorn = {
        model = `mp_a_c_pronghorn_01`, outfit = 0, price = 15,
        zone = vector2(-2300.0, -2500.0), radius = 250.0,
        aggressive = false, healthMult = 2.0,
        rewards = { { item = 'legendary_pronghorn_pelt', amount = 1 }, { item = 'legendary_pronghorn_horn', amount = 1 } },
    },
    tatanka = {
        model = `a_c_buffalo_tatanka_01`, outfit = 0, price = 35,
        zone = vector2(-1600.0, -1900.0), radius = 250.0,
        aggressive = false, healthMult = 5.0,
        rewards = { { item = 'legendary_bison_pelt', amount = 1 }, { item = 'legendary_bison_horn', amount = 2 } },
    },
}

---------------------------------
-- Trapper buy prices (server-side only, never sent from the client)
---------------------------------
Config.SellPrices = {
    legendary_bear_pelt = 120, legendary_bear_claw = 10,
    legendary_buck_pelt = 70,  legendary_buck_antler = 15,
    legendary_boar_pelt = 70,  legendary_boar_tusk = 8,
    legendary_wolf_pelt = 90,  legendary_wolf_fang = 8,
    legendary_cougar_pelt = 110, legendary_cougar_fang = 10,
    legendary_panther_pelt = 140, legendary_panther_fang = 12,
    legendary_bighorn_pelt = 70, legendary_bighorn_horn = 15,
    legendary_moose_pelt = 90, legendary_moose_antler = 18,
    legendary_elk_pelt = 70,   legendary_elk_antler = 15,
    legendary_fox_pelt = 50,   legendary_fox_tail = 8,
    legendary_coyote_pelt = 50, legendary_coyote_fang = 6,
    legendary_alligator_skin = 140, legendary_alligator_tooth = 10,
    legendary_beaver_pelt = 50, legendary_beaver_tooth = 6,
    legendary_pronghorn_pelt = 65, legendary_pronghorn_horn = 12,
    legendary_bison_pelt = 160, legendary_bison_horn = 18,
}

---------------------------------
-- Localised names (rsg-core locales, language set by the rsg:locale convar)
---------------------------------
for key, a in pairs(Config.Animals) do
    a.label = locale('animal_' .. key)
    a.description = locale('animal_' .. key .. '_desc')
end
for _, t in ipairs(Config.Trappers) do
    if t.blip then t.blip.name = locale(t.blip.name) end
end
