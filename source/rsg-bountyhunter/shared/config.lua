Config = {}
-- build the database tables automatically on start (set false and import the SQL file for a manual install)
Config.AutoDatabase = true

Config.Debug = false -- prints distance checks to the server console

-- While the bounty board is open, block game controls but keep push-to-talk working (rsg-voice).
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

---------------------------------
-- general
---------------------------------
Config.RequiredJob         = nil     -- job-lock contracts (checked on the server): 'bountyhunter' or { 'bountyhunter', 'sheriff' }, nil = anyone
Config.MoneyType           = 'cash'  -- paid with Player.Functions.AddMoney
Config.BoardSize           = 6       -- posters shown on the board at once
Config.RefreshMinutes      = 30      -- board re-rolls unclaimed posters this often
Config.ContractMinutes     = 30      -- time to bring the target in before the contract expires
Config.WarnMinutes         = 5       -- warn the hunter when this many minutes are left
Config.AcceptCooldown      = 120     -- seconds before another contract can be taken after abandon/fail/expiry
Config.MinHuntSeconds      = 60      -- anti-exploit: minimum time between finding the target and turning it in
Config.MaxTravelSpeed      = 25.0    -- anti-exploit: metres per second. The minimum hunt time also grows with the hideout -> office distance (distance / this); 0 = off
Config.AbandonCommand      = 'abandonbounty' -- abandon the current contract from anywhere, false to disable

Config.InteractDistance    = 3.0     -- rsg-target reach to the clerk
Config.ServerCheckDistance = 10.0    -- server-side radius around the office coords (keep larger than InteractDistance)
Config.DeliverRadius       = 12.0    -- target must be within this distance of the office to turn in
Config.ClerkSpawnDistance  = 60.0    -- clerk peds only exist while a player is this close

Config.SpawnDistance       = 150.0   -- outlaws spawn when the hunter gets this close to the hideout
Config.SearchRadius        = 120.0   -- size of the search area blip (hideout is somewhere inside)
Config.TargetBlipDistance  = 60.0    -- target gets a bounty blip when the hunter is this close
Config.LeaderboardSize     = 5
Config.LeaderboardCache    = 60      -- seconds to cache the leaderboard query

---------------------------------
-- poster conditions: NPC posters can demand a live or a dead outlaw
---------------------------------
Config.Conditions = {
    Enabled             = true,
    AliveOnlyChance     = 0.15, -- chance a poster is "alive only": a dead target pays nothing and fails the contract
    DeadOnlyChance      = 0.15, -- chance a poster is "dead only": a live target is refused until it is dead
    AliveOnlyMultiplier = 1.3,  -- alive-only posters pay this share of the normal alive reward
    DeadOnlyMultiplier  = 0.8,  -- dead-only posters pay this share of the normal alive reward
}

---------------------------------
-- rsg-skills (optional): bounty hunting level, XP and a reward perk. Does nothing when rsg-skills is not started.
---------------------------------
Config.Skills = {
    Enabled      = true,
    Key          = 'bounty_hunting',
    XP           = { [1] = 20, [2] = 40, [3] = 80 }, -- XP per capture by tier
    AliveBonusXP = 10,                               -- extra XP for a live capture
    PlayerXP     = 100,                              -- XP for bringing in a player
    TierLevels   = { [1] = 1, [2] = 4, [3] = 8 },    -- level needed to take a tier of NPC poster
    RewardPerk   = 'reward_bonus',                   -- perk (percent) added to NPC rewards
    Definition = {                                   -- passed to rsg-skills RegisterSkill
        label = 'Bounty Hunting', description = 'Track outlaws and bring them in.', order = 60, maxLevel = 20,
        perks = { reward_bonus = { suffix = '%', levels = { [3] = 5, [6] = 10, [10] = 15, [15] = 20, [20] = 25 } } },
    },
}

---------------------------------
-- bonuses on NPC rewards (sponsored and reputation payouts are fixed). All bonuses add together.
---------------------------------
Config.Streak = {
    Enabled       = true,
    WindowMinutes = 20,   -- bring the next one in within this long to keep the streak
    BonusPerStep  = 0.05, -- extra reward per capture after the first in a streak
    MaxBonus      = 0.25,
}
Config.GangBonus = {      -- gang members left dead at the hideout (checked by the server) add to the reward
    Enabled   = true,
    PerMember = 0.08,
    MaxBonus  = 0.32,
}

-- rsg-economy (optional): per-region reward multiplier (region ids as in Config.Reputation.Regions) and, when
-- PayFromTreasury is true, the town treasury pays out the reward when it can afford it (the hunter is always paid).
Config.Economy = {
    Enabled         = true,
    Multipliers     = {},    -- e.g. { saint_denis = 1.1, valentine = 0.95 }, anything missing is 1.0
    PayFromTreasury = false,
}

-- evidence the outlaw leaves behind. Items must exist in rsg-core shared items (see installation/items.lua).
Config.Evidence = {
    Enabled      = true,
    OnlyWhenDead = false,
    Items = {
        [1] = { { name = 'wanted_poster',       amount = { 1, 1 }, chance = 0.6 } },
        [2] = { { name = 'wanted_poster',       amount = { 1, 1 }, chance = 0.4 }, { name = 'outlaw_pocketwatch', amount = { 1, 1 }, chance = 0.5 } },
        [3] = { { name = 'outlaw_pocketwatch',  amount = { 1, 1 }, chance = 0.5 }, { name = 'outlaw_signet_ring', amount = { 1, 1 }, chance = 0.5 } },
    },
}

-- rsg-telegram (optional): tell a player when a bounty is posted on them and when they are brought in
Config.Telegram = { Enabled = true, Posted = true, Collected = true }

-- rsg-prison + rsg-lawman (optional): a player brought in alive is sentenced
Config.Jail = {
    Enabled    = true,
    Minutes    = 10,
    Reputation = true,   -- reputation (outlaw) bounties jail the target
    Sponsored  = false,  -- gang / player sponsored bounties do not
}

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
    -- plain vector3, or { coords = vector3, props = { { model, offset = vector3, heading } } } for a dressed camp
    -- (a hideout without props uses Config.Hideout.DefaultProps while Config.Hideout.Dress is true)
    vector3(-560.0,   480.0,  105.0),
    vector3(-1450.0, -230.0,  105.0),
    vector3(1050.0,  -1700.0,  46.0),
    vector3(2250.0,  -150.0,   45.0),
    vector3(-2300.0,  -480.0, 145.0),
    {
        coords = vector3(400.0, 950.0, 120.0),
        props = {
            { model = 'p_campfire02x',     offset = vector3(4.0, 0.0, 0.0) },
            { model = 'p_tent_leento01x',  offset = vector3(-6.0, 5.0, 0.0), heading = 120.0 },
            { model = 'p_bedrollopen03x',  offset = vector3(-3.0, 3.0, 0.0), heading = 60.0 },
            { model = 'p_cratetnt01x',     offset = vector3(2.0, -6.0, 0.0), heading = 20.0 },
        },
    },
}

---------------------------------
-- hideout behaviour: outlaws idle until the hunter gets close or someone is hurt, and camps can be dressed with props
-- props: data/rdr3_discoveries/objects/object_list.lua (every default below is listed there)
-- scenarios: names from the community scenario list; test them in game, a wrong name just leaves the ped standing
---------------------------------
Config.Hideout = {
    IdleUntilAlert = true,   -- outlaws idle at the hideout until alerted, then fight / flee
    AlertDistance  = 45.0,   -- the hunter this close to any outlaw alerts them all
    Scenarios      = { 'GENERIC_STANDING_SCENARIO', 'GENERIC_SIT_GROUND_SCENARIO' },
    Dress          = true,   -- spawn props at hideouts that have none of their own
    DefaultProps = {
        { model = 'p_campfire01x',    offset = vector3(5.0, 0.0, 0.0) },
        { model = 'p_tent_leento01x', offset = vector3(-5.0, 4.0, 0.0), heading = 90.0 },
        { model = 'p_barrel02x',      offset = vector3(3.0, 5.0, 0.0) },
    },
}

-- ambush on the way back: with this chance a contract has riders waiting once the target is down and you are
-- far from the hideout and from every office. The roll is made by the server.
Config.Ambush = {
    Enabled          = true,
    Chance           = 0.25,
    MinTier          = 2,           -- Petty contracts are never ambushed
    Count            = { 2, 3 },    -- ambushers (model, weapons and accuracy come from the contract's tier)
    MinDistance      = 350.0,       -- from the hideout
    SafeOfficeRadius = 250.0,       -- never this close to a sheriff's office
    SpawnRadius      = { 60.0, 90.0 },
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

-- rsg-reputation integration (optional). Needs the rsg-reputation resource; does nothing when it is not started.
Config.Reputation = {
    Enabled = true,
    Action  = 'bounty_delivered', -- action name in rsg-reputation's Config.Actions
    -- office id -> rsg-reputation region id (an id that is not listed here is used as it is)
    Regions = { saintdenis = 'saint_denis' },
}

-- Reputation bounties (optional). Needs rsg-reputation; does nothing when it is not started.
-- A player whose honor falls to the threshold is posted on the board automatically, and a hunter
-- collects the bounty on the real player: dead, or bound (hogtied / cuffed), at a sheriff's office.
-- The poster is removed when honor recovers, the player goes to jail or leaves, or the bounty is collected.
Config.ReputationBounty = {
    Enabled        = true,
    Threshold      = -600,   -- post when honor is at or below this (-600 = the Outlaw tier in rsg-reputation)
    ClearAbove     = -400,   -- remove the poster once honor rises above this (keep it higher than Threshold)
    BaseReward     = 100,    -- alive reward when honor is exactly at the threshold
    PerPoint       = 0.5,    -- extra alive reward for every honor point below the threshold
    MaxReward      = 500,    -- alive reward cap
    DeadMultiplier = 0.5,    -- dead pays this share of the alive reward
    ExemptJobTypes = { 'leo' }, -- job types that are never posted (lawmen)
    SkipJailed     = true,   -- jailed players are not posted
    BlockSameGang  = true,   -- a hunter cannot take a bounty on a member of their own gang
    RepostCooldownMinutes = 120, -- after being brought in, the player cannot be posted again for this long
    TrackSeconds   = 30,     -- how often the hunter's search area follows the target (minimum 15)
    TrackRadius    = 250.0,  -- size of the moving search area (the target is somewhere inside)
    RerollEvery    = 4,      -- every this many tracking updates the search area offset is re-rolled (0 = never)
    SweepSeconds   = 60,     -- how often every online player is re-checked (jail, decay, cooldown)
    NotifyTarget   = true,   -- tell the player when they are posted / cleared / brought in
}
