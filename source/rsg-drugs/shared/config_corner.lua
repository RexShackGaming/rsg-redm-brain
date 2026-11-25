Config = Config or {}

---------------------------------------------------------------------
-- Corner selling
-- A player runs /corner (Config.Corner.Command) and starts selling what they carry. Ambient NPCs walk up to
-- them one at a time and a haggle starts: the player names a price per unit, the buyer counters, and they go
-- back and forth until they agree, the buyer runs out of patience and walks off, or the player walks away.
-- Every price, limit and result is worked out on the server; the client only sends the price you type.
---------------------------------------------------------------------
Config.Corner = {
    Command   = 'corner',   -- chat command that starts / stops corner selling
    MoneyType = 'cash',     -- 'cash' or 'bloodmoney'
    BlockLaw  = true,       -- on-duty law (Config.Heat.LawJobTypes / LawJobs) can't deal on the corner

    -- What can be sold. price = street price per unit at default potency, before the potency, rsg-skills sell
    -- perk and rsg-economy town multipliers. maxQty = most a single buyer wants. addicts = a buyer can get hooked
    -- on weed (only ambient buyers; spawned ones are deleted after the deal).
    Items = {
        weed_bag   = { price = 6.0, maxQty = 3, addicts = true },
        weed_joint = { price = 2.5, maxQty = 4, addicts = true },
    },

    -- Street market: the server keeps the average price per unit actually paid for each item (over the last
    -- Window sales, all players) and shows it in the haggle panel so players know roughly what things sell for.
    Market = {
        Enabled = true,
        Window  = 40,    -- how many recent sales the average covers
        MinSales = 3,    -- shown only once at least this many sales are recorded
    },

    -- You work from the spot where you ran the command
    Spot = {
        LeaveRadius = 15.0, -- walk further than this from the spot and corner selling stops
    },

    -- Customers
    Approach = {
        FirstSeconds = { 4, 10 },   -- wait before the first customer after starting
        EverySeconds = { 12, 35 },  -- wait between customers (random in this range)
        -- who comes: 'ambient' = only existing townsfolk (can get hooked), 'spawn' = only spawned customers,
        -- 'both' = ambient first, a spawned customer when no ambient one is around or reaches you
        Source       = 'both',
        Debug        = false,       -- print what the customer picker is doing (F8 console)
        Radius       = 40.0,        -- ambient customers are picked within this distance
        IgnoreSeconds = 45,         -- an ambient NPC that couldn't reach you is left alone for this long
        SpawnMin     = 25.0,        -- customers are spawned this far from you (min)...
        SpawnMax     = 40.0,        -- ...and this far (max), preferably out of sight
        LeaveDistance   = 35.0,     -- after the deal they walk this far away from you
        LeaveSpeed      = 1.0,      -- 1.0 walk, 2.0 run
        LeaveTimeout    = 25,       -- seconds before a leaving customer is deleted whatever happens
        DespawnDistance = 28.0,     -- a leaving customer is deleted once this far from you
        -- civilian models a customer is picked from (random)
        Models = {
            'a_m_m_valtownfolk_01', 'a_m_m_valtownfolk_02', 'a_m_m_rhdtownfolk_01', 'a_m_m_rhdtownfolk_02',
            'a_m_m_strtownfolk_01', 'a_m_m_armtownfolk_01', 'a_m_m_blwtownfolk_01', 'a_m_m_lagtownfolk_01',
            'a_m_m_middlesdtownfolk_01', 'a_m_m_lowersdtownfolk_01', 'a_m_m_tumtownfolk_01', 'a_m_m_vhttownfolk_01',
            'a_f_m_valtownfolk_01', 'a_f_m_rhdtownfolk_01', 'a_f_m_rhdtownfolk_02', 'a_f_m_strtownfolk_01',
            'a_f_m_armtownfolk_01', 'a_f_m_blwtownfolk_01', 'a_f_m_middlesdtownfolk_01', 'a_f_m_lowersdtownfolk_01',
            'a_m_o_guatownfolk_01', 'a_f_o_lagtownfolk_01',
        },
        StopDistance = 1.6,         -- how close they come before talking
        Speed        = 1.0,         -- 1.0 walk, 2.0 run
        Timeout      = 60,          -- seconds a customer has to reach you before giving up
    },

    -- The haggle. All values are server side.
    Haggle = {
        -- hidden limit: the most a buyer will ever pay per unit = street price x a random value in this range
        CeilingMin  = 0.90,
        CeilingMax  = 1.35,
        -- what a buyer would pay before any haggling, as a share of their limit
        OpeningMin  = 0.55,
        OpeningMax  = 0.75,
        -- how many of your offers a buyer puts up with before walking away
        PatienceMin = 4,
        PatienceMax = 6,
        -- share of the gap a buyer closes each round when your price is inside their limit
        ConcedeMin  = 0.40,
        ConcedeMax  = 0.70,
        -- share of the gap to their limit a buyer moves when your price is over it (they dig in)
        StubbornMin = 0.00,
        StubbornMax = 0.15,
        CloseEnough = 0.04,         -- a buyer accepts your price outright once their counter is within 4% of it
        -- asking more than limit x InsultMult insults them: it costs InsultPatience instead of 1, and a buyer who
        -- walks off after being insulted reports you with CallLawChance %
        InsultMult     = 1.8,
        InsultPatience = 2,
        CallLawChance  = 15,
        -- panel limits
        MaxAskMult  = 3.0,          -- highest price you can type (x street price)
        Step        = 0.05,         -- the +/- buttons
        ShowStreetPrice = true,     -- tell the player the street price as a starting point
        -- anti spam
        OfferCooldown = 0.5,        -- seconds between offers
        DealSeconds   = 120,        -- a haggle left open this long is dropped
        MinInterval   = 8,          -- seconds between two haggles for the same player
        MaxDealsPerHour = 40,       -- most haggles one player can open per hour (0 = no limit); stops scripted ped farms
    },

    -- Buyer types, picked per haggle by weight. ceiling / qty scale the buyer's limit and how many they want,
    -- patience is added to the rounds they put up with. 'undercover' is a sting (see Sting below).
    Buyers = {
        regular    = { weight = 62, ceiling = 1.00, qty = 1.0, patience = 0 },
        cheap      = { weight = 20, ceiling = 0.80, qty = 1.0, patience = 1  },   -- tight wallet, but patient
        bigspender = { weight = 15, ceiling = 1.25, qty = 1.5, patience = -1 },   -- pays well, wants more, short fuse
        undercover = { weight = 3,  ceiling = 1.00, qty = 1.0, patience = 0 },
    },

    -- Undercover officers posing as buyers. Spotting one: they greet you oddly, open with a generous offer
    -- straight away, and accept almost anything. Taking the deal is a bust: the goods are seized, you get no money,
    -- heat goes up and the law is shown your exact position. Only happens while MinLaw on-duty law are online.
    Sting = {
        Enabled    = true,
        MinLaw     = 1,
        CeilingMin = 1.30, CeilingMax = 1.60,   -- their limit (x street price)
        OpenMin    = 0.90, OpenMax    = 0.98,   -- their first offer (x their limit)
        Heat       = 15.0,
    },

    -- Corner rank: lifetime units sold on the corner raise the price every buyer will pay. Stored on the character
    -- (metadata 'cornerrep'). label = locale key.
    Rank = {
        Enabled = true,
        Levels = {
            { sold = 0,    bonus = 0,  label = 'cfg_corner_rank_1' },
            { sold = 25,   bonus = 3,  label = 'cfg_corner_rank_2' },
            { sold = 100,  bonus = 6,  label = 'cfg_corner_rank_3' },
            { sold = 300,  bonus = 10, label = 'cfg_corner_rank_4' },
            { sold = 800,  bonus = 15, label = 'cfg_corner_rank_5' },
        },
    },

    -- Supply and demand: every unit sold pushes the street price down for everyone, recovering over time.
    -- (In memory: demand resets to normal when the server restarts.)
    Demand = {
        Enabled   = true,
        Capacity  = 60,     -- units sold at which the price has dropped by MaxDrop
        MaxDrop   = 0.30,   -- biggest price drop (0.30 = -30%)
        Recover   = 4,      -- units of pressure lost per minute
    },

    -- Towns: needs rsg-economy (the region of the player). Keys are the region id from rsg-economy, lowercased
    -- (set Approach.Debug = true to print the region of each buyer). A town not listed uses Default.
    --   price   = street price multiplier        ceiling = how far buyers will go above the street price
    --   heat    = multiplier on heat from sales   sting   = multiplier on the chance of an undercover buyer
    Towns = {
        Enabled = true,
        Default = { price = 1.0, ceiling = 1.0, heat = 1.0, sting = 1.0 },
        List = {
            -- ['saintdenis'] = { price = 1.15, ceiling = 1.10, heat = 1.5, sting = 2.0 }, -- pays well, watched closely
            -- ['blackwater'] = { price = 0.90, ceiling = 1.00, heat = 0.7, sting = 0.5 }, -- quiet but cheap
        },
    },

    -- Regulars: a buyer you sold to at a fair price may become one of your regulars (kept on the character).
    -- Regulars come back now and then, pay more and buy more as their loyalty grows; insult one and you lose them.
    -- They are never undercover.
    Regulars = {
        Enabled         = true,
        Max             = 6,      -- regulars per player
        Recruit         = 20,     -- % chance a fair sale makes the buyer a regular
        FairMult        = 1.05,   -- a sale counts as fair at or below street price x this
        Return          = 25,     -- % chance a new buyer is one of your regulars (when one is free)
        CooldownMinutes = 10,     -- a regular is not back sooner than this
        PerLevel        = 5,      -- sales per loyalty level
        MaxLevel        = 5,
        CeilingBonus    = 4,      -- % more they will pay per level
        QtyBonus        = 0.15,   -- bigger orders per level (0.15 = +15%)
        Names = { 'Abel', 'Amos', 'Clyde', 'Dutch', 'Eli', 'Floyd', 'Gus', 'Hank', 'Ira', 'Jed', 'Lester', 'Mose',
                  'Nate', 'Orville', 'Silas', 'Tobias', 'Walt', 'Ada', 'Cora', 'Dottie', 'Edith', 'Flora', 'Ida', 'Mabel' },
    },

    -- Buyers that bought become regulars if they are hooked: they buy again after this long. Other buyers only ever buy once.
    AddictRebuyMinutes = 5,

    -- Handover animation (rdr3_discoveries animations/ingameanims/ingameanims_list.lua)
    Anim = {
        Enabled = true,
        Dict    = 'script_common@handover@generic@player_handover@money',
        Player  = 'handover_money_plyr',   -- player hands the goods over
        Ped     = 'handover_money_male',   -- NPC takes them
        -- The package that changes hands: it appears in the player's hand, moves to the NPC's hand part way through
        -- the animation and is removed when it ends. Model: rdr3_discoveries objects/object_list.lua (0x46591C87).
        Prop = {
            Enabled   = true,
            Model     = 's_drugpackage_02x',
            Bone      = 'SKEL_R_Hand',  -- bone name; BoneId is used if the name isn't found
            BoneId    = 6286,
            HandoffAt = 0.5,            -- share of the animation after which the NPC takes the package (0.0 - 1.0)
            -- x, y, z offset and x, y, z rotation relative to the hand bone. Tune in game if it sits oddly.
            Player    = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
            Ped       = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
        },
    },

    -- Law alert when a buyer reports you
    Alert = {
        JobTypes = { leo = true },
        Jobs     = {},
        Duration = 300,    -- seconds the hotspot stays on the law's map
        Radius   = 60.0,   -- blip radius (not exact position)
        Offset   = 30.0,   -- random offset so the exact spot isn't revealed
        -- Investigating: an officer who walks into the hotspot narrows it down. Every few seconds inside, the
        -- circle shrinks by ShrinkStep (m) until it is MinRadius wide. The trail goes cold when Duration ends.
        ShrinkStep = 8.0,
        MinRadius  = 20.0,
        -- a bust (undercover sting) shows the law the exact spot with this radius
        ExactRadius = 15.0,
    },
}
