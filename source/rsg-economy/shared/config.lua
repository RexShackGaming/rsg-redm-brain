Config = {}

-- Tables are created automatically on start. Set to false to import install.sql manually.
Config.AutoDatabase = true

-- While the NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- Chat command that opens the economy panel ('' to disable)
Config.Command = 'economy'

-- Permission level needed for the admin commands
Config.AdminPermission = 'admin'

-- Seconds between database saves of changed treasuries, rates and prices
Config.SaveInterval = 30

-- Money type used for deposits and withdrawals ('cash' or 'bank')
Config.MoneyType = 'cash'

-- Use rsg-reputation price modifiers (disliked players pay more, respected players less) when it is running
Config.UseReputation = true

------------------------------------------
-- Regions: each has a treasury, its own tax rates and its own officials.
-- Ids match rsg-reputation. label = plain text or locale key.
-- officials: players holding one of these jobs at minGrade or higher may change taxes and spend the treasury.
-- Defaults: the town's law job (Sheriff grade) and the 'government' job (rsg-townhall's manager job).
-- Raise the government minGrade if not every government worker should be an official.
------------------------------------------
Config.RequireOnDuty = false

-- coords (town centre, approximate - edit to taste) lets other scripts find the region of a position with
-- exports['rsg-economy']:GetRegionAt(coords). A position further than RegionRadius from every town has no region.
Config.RegionRadius = 800.0

local function officials(lawJob)
    local list = {}
    if lawJob then list[#list + 1] = { job = lawJob, minGrade = 2 } end
    list[#list + 1] = { job = 'government', minGrade = 0 }
    return list
end

Config.Regions = {
    valentine   = { label = 'Valentine',   order = 1, coords = vector3(-281.0, 803.0, 119.4), officials = officials('vallaw') },
    rhodes      = { label = 'Rhodes',      order = 2, coords = vector3(1225.0, -1297.0, 76.9), officials = officials('rholaw') },
    saint_denis = { label = 'Saint Denis', order = 3, coords = vector3(2632.0, -1312.0, 51.4), officials = officials('stdenlaw') },
    strawberry  = { label = 'Strawberry',  order = 4, coords = vector3(-1791.0, -386.0, 160.0), officials = officials('strlaw') },
    blackwater  = { label = 'Blackwater',  order = 5, coords = vector3(-813.0, -1336.0, 43.6), officials = officials('blklaw') },
    annesburg   = { label = 'Annesburg',   order = 6, coords = vector3(2930.0, 1285.0, 44.7), officials = officials(nil) },
    van_horn    = { label = 'Van Horn',    order = 7, coords = vector3(2987.0, 569.0, 44.6), officials = officials(nil) },
    armadillo   = { label = 'Armadillo',   order = 8, coords = vector3(-3685.0, -2623.0, -14.0), officials = officials(nil) },
    tumbleweed  = { label = 'Tumbleweed',  order = 9, coords = vector3(-5512.0, -2937.0, -1.9), officials = officials(nil) },
}

------------------------------------------
-- Taxes. Rates are fractions (0.05 = 5%). Officials can change a rate within min / max, in steps of Step.
-- label = locale key (cat_*) or plain text.
------------------------------------------
Config.Tax = {
    Step = 0.005,
    -- seconds an official must wait before changing the same rate again in the same region
    ChangeCooldown = 300,
    Categories = {
        sales    = { label = 'cat_sales',    default = 0.05, min = 0.0, max = 0.20, order = 1 }, -- shop purchases (added to the price)
        trade    = { label = 'cat_trade',    default = 0.03, min = 0.0, max = 0.15, order = 2 }, -- goods sold to shops (taken from the payout)
        property = { label = 'cat_property', default = 0.04, min = 0.0, max = 0.15, order = 3 }, -- rent, deeds, land
        license  = { label = 'cat_license',  default = 0.02, min = 0.0, max = 0.10, order = 4 }, -- permits and licences
    },
}

------------------------------------------
-- Treasury
------------------------------------------
Config.Treasury = {
    PublicBalance = true,           -- everyone can see the balance (false = officials only)
    AllowPublicDonations = true,    -- any player can donate to a town
    DonationAction = 'donation',    -- rsg-reputation action applied to a donor (nil to disable)
    MaxAmount = 1000000,            -- largest single deposit or withdrawal
    Withdraw = {
        Enabled = true,             -- officials can take money out through the panel
        DailyLimit = 2000,          -- per region and UTC day, across all officials
    },
    Ledger = {
        KeepDays = 30,              -- older entries are deleted
        PageSize = 20,              -- entries shown in the panel
        LogTax = true,              -- one entry per taxed sale (turn off on busy servers)
    },
}

------------------------------------------
-- Dynamic prices. Every item has a pressure per region from -1 (heavy demand) to +1 (oversupply).
-- Selling to shops raises it (prices fall), buying lowers it (prices rise). It fades back to 0 over time.
-- price multiplier = 1 - pressure * sensitivity, kept between min and max.
------------------------------------------
Config.Market = {
    Enabled = true,
    PressurePerUnit = 0.02,   -- pressure change per unit traded
    HalfLifeHours = 12,       -- hours for the pressure to halve
    Sensitivity = 0.5,        -- default
    MinMultiplier = 0.5,
    MaxMultiplier = 1.5,
    -- per-item overrides: { sensitivity, min, max, perUnit }
    Items = {
        -- ['venison'] = { sensitivity = 0.8, min = 0.4, max = 1.6, perUnit = 0.03 },
    },
}

------------------------------------------
-- Town projects: officials spend treasury money; the effect is up to other scripts, which read HasProject(region, id)
-- or listen to the rsg-economy:server:projectFunded event. days = 0 means permanent.
-- label = plain text or locale key.
------------------------------------------
Config.Projects = {
    { id = 'street_lamps',  label = 'Street lamps',  cost = 2000, days = 14 },
    { id = 'extra_deputies', label = 'Extra deputies', cost = 3000, days = 14 },
    { id = 'road_repairs',  label = 'Road repairs',  cost = 2500, days = 30 },
    { id = 'town_festival', label = 'Town festival', cost = 1500, days = 3 },
}
