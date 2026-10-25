Config = Config or {}
lib.locale() -- labels come from locales/*.json (cfg_* keys)
Config.Addiction = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.Addiction.Debug        = false
Config.Addiction.TickInterval = 60    -- seconds between server addiction ticks (craving growth / natural decay)
Config.Addiction.UseCooldown  = 5     -- seconds, per player anti-spam on reported uses

---------------------------------------------------------------------
-- Substances
-- items: [itemName] = addiction gained per use (0-100 scale)
-- registerItems = true  -> this resource makes the items usable itself
-- registerItems = false -> another resource consumes them (rsg-consume) and we hook its event
-- Alcohol item names verified from rsg-consume/shared/config.lua (Drink category)
-- 'weed_joint' is provided by rsg-drugs (installation/shared_items.lua, useable = true)
---------------------------------------------------------------------
Config.Addiction.Substances = {
    alcohol = {
        label         = locale('cfg_sub_alcohol'),
        registerItems = false,
        items = {
            bottle_beer        = 6,
            glass_absinthe     = 12,
            glass_bourbon      = 10,
            moonshine_alaskan  = 14,
            moonshine_american = 16,
        },
        threshold   = 40,  -- addiction level at which the player is "hooked"
        decay       = 2,   -- level lost per tick while NOT hooked
        cravingRate = 5,   -- craving gained per tick while hooked and not feeding
    },
    weed = {
        label         = locale('cfg_sub_weed'),
        registerItems = true,
        items = {
            weed_joint = 10,
        },
        threshold   = 35,
        decay       = 2,
        cravingRate = 4,
        useScenario = 'WORLD_HUMAN_SMOKE',     -- rdr3_discoveries/animations/scenarios/scenario_types_with_conditional_anims.lua
        useTime     = 10000,                   -- ms
        highEnabled = false,                   -- false = no screen effect while high (boost/stress relief still apply)
        highEffect  = 'playerdrugshalluc01',   -- rdr3_discoveries/graphics/animpostfx/animpostfx.lua
        highTime    = 45000,                   -- ms
        -- performance boost while high (applied after the smoke finishes)
        -- cores: 0 = health, 1 = stamina, 2 = dead eye (eAttributeCore, natives/db/ATTRIBUTE.md)
        boost = {
            stressRelief = 30,                     -- rsg-hud RelieveStress (server export)
            fillCores    = { [1] = 100, [2] = 100 }, -- set stamina + dead eye cores to this value
            goldCores    = { 1, 2 },               -- fortify (gold) these cores
            goldSeconds  = 45.0,                   -- _ENABLE_ATTRIBUTE_CORE_OVERPOWER value
        },
    },
}

---------------------------------------------------------------------
-- Withdrawal stages (driven by craving 0-100). Highest stage reached applies.
-- shake: DRUNK_SHAKE (natives/db/CAM.md) | fx: PlayerHealthPoorCS (rsg-consume config, groggy effect)
---------------------------------------------------------------------
Config.Addiction.ShakeName = 'DRUNK_SHAKE'
Config.Addiction.Stages = {
    [1] = { craving = 30, label = locale('cfg_stage_1'),    shake = 0.15, fx = nil,                  staminaCap = 100, stumbleChance = 0,  stress = 1 },
    [2] = { craving = 60, label = locale('cfg_stage_2'),   shake = 0.35, fx = 'PlayerHealthPoorCS', staminaCap = 50,  stumbleChance = 8,  stress = 2 },
    [3] = { craving = 90, label = locale('cfg_stage_3'),shake = 0.60, fx = 'PlayerHealthPoorCS', staminaCap = 20,  stumbleChance = 20, stress = 4 },
}
Config.Addiction.EffectInterval  = 15000  -- ms between stumble/stress rolls on the client
Config.Addiction.StumbleOnlyMoving = true

---------------------------------------------------------------------
-- Rehab (served at Sisika — coords taken from rsg-prison/config.lua)
---------------------------------------------------------------------
Config.Addiction.Rehab = {
    DefaultMinutes = 10,
    MaxMinutes     = 30,
    VoluntaryMinutes = 8,
    Centre  = vector3(3357.41, -679.26, 46.26),     -- rsg-prison "middle"
    Radius  = 65.0,
    Spawns  = {
        vector4(3330.66, -692.75, 43.95, 292.86),
        vector4(3349.62, -650.41, 45.38, 207.53),
        vector4(3380.62, -672.35, 46.27, 110.95),
        vector4(3366.75, -666.08, 46.34, 297.69),
    },
    Release = vector4(3340.71, -629.99, 43.72, 36.36), -- rsg-prison "outside"
    -- Who may send a player to rehab with /rehab
    AllowedJobTypes = { leo = true },
    AllowedJobs     = { medic = true },
    AdminPermission = 'admin',
    MaxAdmitDistance = 5.0,
    -- Bonus paid to a lawman/medic for sending an addict (player or NPC) to rehab
    Reward = {
        Enabled     = true,
        Amount      = 1,       -- $ paid per admission
        MoneyType   = 'cash',  -- 'cash' or 'bank'
        NpcCooldown = 60,      -- seconds between NPC rehab rewards per officer (anti-farm)
    },
    -- Belongings are taken for the stint and handed back on release (stored in player metadata 'rehabitems')
    Confiscate = {
        Enabled        = true,
        ReEquipWeapons = true, -- re-equip guns that were equipped (needs rsg-weapons Config.SaveEquippedWeapons = true)
        -- items the patient keeps (money items: keep these so cash isn't touched)
        KeepItems = { dollar = true, cent = true, blood_dollar = true, blood_cent = true },
    },
    -- Voluntary check-in NPC (ox_target)
    CheckIn = {
        coords   = vector4(3333.70, -630.64, 43.64, 29.82),
        model    = `u_m_m_valdoctor_01`, -- rdr3_discoveries peds/peds_list.lua
        spawnDistance  = 50.0,
        targetDistance = 2.5,
        interactDistance = 4.0, -- server-side check
    },
}

---------------------------------------------------------------------
-- Ambient NPC addicts (client-side, visual only)
---------------------------------------------------------------------
Config.Addiction.NPC = {
    Enabled       = true,
    ScanInterval  = 10000,  -- ms
    ScanRadius    = 60.0,
    SaleChance    = 100,    -- % chance an NPC becomes addicted when sold a weed_bag
    MaxTracked    = 12,
    CravingRate   = 10,     -- craving gained per scan
    FeedChance    = 25,     -- % per scan an NPC feeds once craving >= 60
    -- rdr3_discoveries/animations/scenarios/scenario_types_with_conditional_anims.lua
    Scenarios = {
        alcohol   = 'WORLD_HUMAN_DRINKING',
        weed      = 'WORLD_HUMAN_SMOKE',
        withdrawal = 'WORLD_HUMAN_DRUNK_BRACE_WALL_NO_VOMIT',
    },
    FeedTime = 12000,
}

---------------------------------------------------------------------
-- Selling weed bags to NPCs (ox_target)
---------------------------------------------------------------------
Config.Addiction.Selling = {
    Item        = 'weed_bag',
    PriceMin    = 4,        -- $ paid per bag (random between min/max)
    PriceMax    = 8,
    MoneyType   = 'cash',
    BuyChance   = 40,       -- % a non-addicted NPC agrees (and then becomes addicted)
    Cooldown    = 5,        -- seconds between sell attempts per player
    AddictRebuyMinutes = 5, -- addicted NPCs buy again after this long; other NPCs only ever buy once
    RequireNetworkedPed = true, -- server must see the NPC within 4m (stops selling from anywhere); false = allow non-networked peds
    -- Handover animation (rdr3_discoveries animations/ingameanims/ingameanims_list.lua)
    Anim = {
        Enabled = true,
        Dict    = 'script_common@handover@generic@player_handover@money',
        Player  = 'handover_money_plyr',   -- player hands the bag over
        Ped     = 'handover_money_male',   -- NPC takes it
    },
    -- Law alert when an NPC refuses
    AlertJobTypes = { leo = true },
    AlertJobs     = {},
    AlertDuration = 300,    -- seconds the hotspot stays on the law's map
    AlertRadius   = 60.0,   -- blip radius (not exact position)
    AlertOffset   = 30.0,   -- random offset so the exact spot isn't revealed
}
