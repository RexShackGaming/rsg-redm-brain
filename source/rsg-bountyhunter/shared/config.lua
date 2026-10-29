Config = {}

Config.Debug = false -- prints distance checks to the server console

---------------------------------
-- general
---------------------------------
Config.RequiredJob         = nil     -- e.g. 'bountyhunter' to job-lock contracts (checked on the server), nil = anyone
Config.MoneyType           = 'cash'  -- paid with Player.Functions.AddMoney
Config.BoardSize           = 6       -- posters shown on the board at once
Config.RefreshMinutes      = 30      -- board re-rolls unclaimed posters this often
Config.ContractMinutes     = 30      -- time to bring the target in before the contract expires
Config.WarnMinutes         = 5       -- warn the hunter when this many minutes are left
Config.AcceptCooldown      = 120     -- seconds before another contract can be taken after abandon/fail/expiry
Config.MinHuntSeconds      = 60      -- anti-exploit: minimum time between finding the target and turning it in
Config.AbandonCommand      = 'abandonbounty' -- abandon the current contract from anywhere, false to disable

Config.InteractDistance    = 3.0     -- ox_target reach to the clerk
Config.ServerCheckDistance = 10.0    -- server-side radius around the office coords (keep larger than InteractDistance)
Config.DeliverRadius       = 12.0    -- target must be within this distance of the office to turn in
Config.ClerkSpawnDistance  = 60.0    -- clerk peds only exist while a player is this close

Config.SpawnDistance       = 150.0   -- outlaws spawn when the hunter gets this close to the hideout
Config.SearchRadius        = 120.0   -- size of the search area blip (hideout is somewhere inside)
Config.TargetBlipDistance  = 60.0    -- target gets a bounty blip when the hunter is this close
Config.LeaderboardSize     = 5
Config.LeaderboardCache    = 60      -- seconds to cache the leaderboard query

---------------------------------
-- sheriff offices (bounty clerk + turn-in point); label is a locale key
-- coords taken from rsg-lawman config.lua; clerk positions/headings may need tuning in game
---------------------------------
Config.ClerkModel = 's_m_m_valdeputy_01' -- data/rdr3_discoveries/peds/peds_list.lua
Config.Offices = {
    { id = 'valentine',  label = 'office_valentine',  coords = vector4(-273.81, 813.31, 119.36, 16.26),  blip = true },
    { id = 'rhodes',     label = 'office_rhodes',     coords = vector4(1355.99, -1298.06, 76.78, 349.54), blip = true },
    { id = 'blackwater', label = 'office_blackwater', coords = vector4(-769.66, -1270.81, 43.56, 107.12), blip = true },
    { id = 'saintdenis', label = 'office_saintdenis', coords = vector4(2510.08, -1318.03, 48.53, 184.06), blip = true },
}

-- blip sprite hash: blip_ambient_sheriff (data/rdr3_discoveries/useful_info_from_rpfs/textures/blips/README.md)
Config.OfficeBlipSprite = -693644997

---------------------------------
-- hideouts: where targets can be found. EXAMPLE coords - set your own wilderness spots.
-- z is snapped to the ground on the client when spawning.
---------------------------------
Config.Hideouts = {
    vector3(-560.0,   480.0,  105.0),
    vector3(-1450.0, -230.0,  105.0),
    vector3(1050.0,  -1700.0,  46.0),
    vector3(2250.0,  -150.0,   45.0),
    vector3(-2300.0,  -480.0, 145.0),
    vector3(400.0,    950.0,  120.0),
}

---------------------------------
-- outlaw tiers
-- ped models: data/rdr3_discoveries/peds/peds_list.lua
-- weapons:    data/rdr3_discoveries/weapons/weapons.lua
---------------------------------
Config.Tiers = {
    [1] = {
        label = 'tier_petty',      -- locale key
        rewardAlive = { 15, 30 },  -- random range
        deadMultiplier = 0.5,      -- dead pays this share of the alive reward
        gang = { 0, 1 },
        behaviour = 'flee',        -- 'flee' or 'fight' (gang members always fight)
        accuracy = 20,
        models = { 'g_m_m_unicriminals_01' },
        weapons = { 'weapon_revolver_cattleman' },
    },
    [2] = {
        label = 'tier_wanted',
        rewardAlive = { 35, 60 },
        deadMultiplier = 0.5,
        gang = { 1, 2 },
        behaviour = 'fight',
        accuracy = 35,
        models = { 'g_m_m_uniduster_01', 'g_m_m_unibanditos_01' },
        weapons = { 'weapon_revolver_cattleman', 'weapon_repeater_carbine' },
    },
    [3] = {
        label = 'tier_notorious',
        rewardAlive = { 75, 120 },
        deadMultiplier = 0.4,
        gang = { 2, 4 },
        behaviour = 'fight',
        accuracy = 50,
        models = { 'g_m_y_uniexconfeds_01', 'g_m_m_unibanditos_01' },
        weapons = { 'weapon_repeater_carbine', 'weapon_revolver_cattleman' },
    },
}

-- random poster names (proper nouns, not translated) and crimes (locale keys in locales/*.json)
Config.FirstNames = { 'Jebediah', 'Silas', 'Amos', 'Cletus', 'Ezra', 'Horace', 'Virgil', 'Rufus', 'Otis', 'Lemuel', 'Wade', 'Boone' }
Config.LastNames  = { 'Crane', 'Hollister', 'McCready', 'Thorne', 'Pike', 'Vance', 'Dutton', 'Gage', 'Rourke', 'Slade', 'Kimball', 'Fenn' }
Config.Crimes = {
    [1] = { 'crime_horse_theft', 'crime_cattle_rustling', 'crime_assault', 'crime_arson' },
    [2] = { 'crime_armed_robbery', 'crime_stagecoach_robbery', 'crime_murder', 'crime_jailbreak' },
    [3] = { 'crime_train_robbery', 'crime_bank_robbery', 'crime_multiple_murders', 'crime_killing_lawman' },
}
