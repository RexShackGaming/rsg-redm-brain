Config = {}

Config.ForemanModel    = 'u_m_m_bht_mineforeman'
Config.SpawnDistance   = 50.0       -- foreman ped spawns when player is within this range
Config.TargetDistance  = 2.5
Config.ManageDistance  = 10.0       -- server-side: max distance from the foreman to use the ledger
Config.ActionCooldown  = 500        -- ms between foreman actions per player (anti-spam)
Config.MoneyType       = 'cash'     -- cash | bank
Config.NotifyPosition  = 'top-right'
Config.ImagePath       = 'nui://rsg-inventory/html/images/'  -- where item images live

---------------------------------
-- lease
---------------------------------
Config.LeaseDurationHours = 72      -- real-time hours a lease lasts
Config.AllowRenew         = true    -- lease holder can extend from the foreman UI
Config.MaxLeaseHours      = 336     -- cap on total remaining time when renewing

---------------------------------
-- supplies (item names in your rsg-core shared items)
---------------------------------
Config.Supplies = {
    bread   = { item = 'bread',   label = 'Bread' },
    water   = { item = 'water',   label = 'Water' },
    pickaxe = { item = 'pickaxe', label = 'Pickaxe' },
}

---------------------------------
-- workers
---------------------------------
Config.WorkInterval      = 10     -- minutes between work cycles
Config.FoodDrain         = 25     -- food lost per cycle (0-100)
Config.WaterDrain        = 34     -- water lost per cycle (0-100)
Config.PickaxeWear       = 20     -- durability lost per cycle (0-100)
Config.BreadRestore      = 100    -- food restored by 1 bread
Config.WaterRestore      = 100    -- water restored by 1 water
Config.MinSkill          = 1
Config.MaxSkill          = 10
Config.SkillGainPerCycle = 0.05   -- workers improve slowly on the job
Config.SkillChanceBonus  = 0.08   -- +8% ore chance per skill level above 1
Config.SkillAmountBonus  = 0.5    -- extra ore per skill level (floored)

-- wages (paid from the mine's payroll fund every work cycle / shift)
Config.WageBase          = 2      -- base pay per shift
Config.WagePerSkill      = 0.5    -- extra pay per skill level (wage is rounded up)
Config.MaxPayroll        = 5000   -- most money the payroll fund can hold
Config.AllowWithdraw     = true   -- lease holder can take unused wages back out

-- hiring
Config.CandidateCount    = 5
Config.CandidateRefresh  = 30     -- minutes before the hiring board refreshes
Config.HireBaseCost      = 10
Config.HireCostPerSkill  = 8      -- cost = base + skill * this
Config.CandidateSkillMax = 7      -- best skill a fresh hire can have

Config.FirstNames = { 'Amos','Bill','Cyrus','Eli','Silas','Jeb','Otis','Hank','Walt','Clem','Rufus','Ezra','Luther','Abner','Wade','Moses','Gus','Ike' }
Config.LastNames  = { 'Hollis','Carver','Dunn','Pruitt','Mosby','Hale','Riggs','Tate','Booker','Cobb','Haskell','Lyle','Pike','Grady','Barlow','Stokes' }

---------------------------------
-- mines
---------------------------------
Config.Mines = {
    {
        id          = 'annesburg',
        label       = 'Annesburg Mining Camp',
        foreman     = vector4(2799.88, 1350.10, 73.13, 276.61),
        leasePrice  = 500,
        maxWorkers  = 5,
        storageCap  = 500,
        blip        = { enabled = true, sprite = 'blip_ambient_quartermaster', name = 'Annesburg Mining Camp' },
        ores = {
            -- standard ores
            { item = 'resource_clay',           chance = 80, min = 1, max = 2 },
            { item = 'resource_coal',           chance = 40, min = 1, max = 2 },
            { item = 'resource_salt',           chance = 10, min = 1, max = 2 },
            { item = 'resource_copper_ore',     chance = 25, min = 1, max = 2 },
            { item = 'resource_iron_ore',       chance = 25, min = 1, max = 2 },
            { item = 'resource_lead_ore',       chance = 25, min = 1, max = 2 },
            { item = 'resource_nitrate_ore',    chance = 10, min = 1, max = 2 },
            { item = 'resource_sulfur_ore',     chance = 10, min = 1, max = 2 },
            -- precious metals
            { item = 'resource_silver_ore',     chance = 3,  min = 1, max = 1, minSkill = 5 },
            { item = 'resource_gold_ore',       chance = 2,  min = 1, max = 1, minSkill = 5 },
            -- precious gems
            { item = 'resource_amethyst_uncut', chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_diamond_uncut',  chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_emerald_uncut',  chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_opal_uncut',     chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_quartz_uncut',   chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_ruby_uncut',     chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_sapphire_uncut', chance = 1,  min = 1, max = 1, minSkill = 7 },
        },
    },
    {
        id          = 'gaptooth',
        label       = 'Gaptooth Mining Camp',
        foreman     = vector4(-5988.13, -3214.70, -17.62, 306.18),
        leasePrice  = 700,
        maxWorkers  = 7,
        storageCap  = 700,
        blip        = { enabled = true, sprite = 'blip_ambient_quartermaster', name = 'Gaptooth Mining Camp' },
        ores = {
            -- standard ores
            { item = 'resource_clay',           chance = 80, min = 1, max = 2 },
            { item = 'resource_coal',           chance = 40, min = 1, max = 2 },
            { item = 'resource_salt',           chance = 10, min = 1, max = 2 },
            { item = 'resource_copper_ore',     chance = 25, min = 1, max = 2 },
            { item = 'resource_iron_ore',       chance = 25, min = 1, max = 2 },
            { item = 'resource_lead_ore',       chance = 25, min = 1, max = 2 },
            { item = 'resource_nitrate_ore',    chance = 10, min = 1, max = 2 },
            { item = 'resource_sulfur_ore',     chance = 10, min = 1, max = 2 },
            -- precious metals
            { item = 'resource_silver_ore',     chance = 3,  min = 1, max = 1, minSkill = 5 },
            { item = 'resource_gold_ore',       chance = 2,  min = 1, max = 1, minSkill = 5 },
            -- precious gems
            { item = 'resource_amethyst_uncut', chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_diamond_uncut',  chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_emerald_uncut',  chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_opal_uncut',     chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_quartz_uncut',   chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_ruby_uncut',     chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_sapphire_uncut', chance = 1,  min = 1, max = 1, minSkill = 7 },
        },
    },
    {
        id          = 'grizzlies',
        label       = 'Grizzlies Mining Camp',
        foreman     = vector4(-1415.48, 1131.38, 225.54, 336.54),
        leasePrice  = 1000,
        maxWorkers  = 10,
        storageCap  = 1000,
        blip        = { enabled = true, sprite = 'blip_ambient_quartermaster', name = 'Grizzlies Mining Camp' },
        ores = {
            -- standard ores
            { item = 'resource_clay',           chance = 80, min = 1, max = 2 },
            { item = 'resource_coal',           chance = 40, min = 1, max = 2 },
            { item = 'resource_salt',           chance = 10, min = 1, max = 2 },
            { item = 'resource_copper_ore',     chance = 25, min = 1, max = 2 },
            { item = 'resource_iron_ore',       chance = 25, min = 1, max = 2 },
            { item = 'resource_lead_ore',       chance = 25, min = 1, max = 2 },
            { item = 'resource_nitrate_ore',    chance = 10, min = 1, max = 2 },
            { item = 'resource_sulfur_ore',     chance = 10, min = 1, max = 2 },
            -- precious metals
            { item = 'resource_silver_ore',     chance = 3,  min = 1, max = 1, minSkill = 5 },
            { item = 'resource_gold_ore',       chance = 2,  min = 1, max = 1, minSkill = 5 },
            -- precious gems
            { item = 'resource_amethyst_uncut', chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_diamond_uncut',  chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_emerald_uncut',  chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_opal_uncut',     chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_quartz_uncut',   chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_ruby_uncut',     chance = 1,  min = 1, max = 1, minSkill = 7 },
            { item = 'resource_sapphire_uncut', chance = 1,  min = 1, max = 1, minSkill = 7 },
        },
    },
}
