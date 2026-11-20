Config = {}

-- Build the database tables automatically on start (CREATE TABLE IF NOT EXISTS).
-- Set to false to import installation/rsg-gangs.sql manually instead.
Config.AutoDatabase = true

-- Check this resource's version against GitHub on start (prints to the server console).
Config.VersionCheck = true

-- Command used to open the gang menu
Config.Command = 'setupgang'

-- Cost (cash) to create a new gang
Config.CreateGangCost = 5000

-- Minimum characters for gang name / label
Config.MinNameLength = 3
Config.MaxNameLength = 20

-- Maximum members a single gang can have (0 = unlimited)
Config.MaxMembers = 15

-- Highest balance a gang bank can hold (the database column is a signed 32-bit int).
Config.MaxBankBalance = 2000000000

-- How long (seconds) a gang invite stays valid before it expires.
Config.InviteExpireSeconds = 120

-- Ranks available to every gang, in ascending order of power.
-- 'weight' determines hierarchy (higher = more powerful) and must be unique and consecutive (0, 1, 2, ...).
-- 'isLeader' rank can disband the gang and cannot be kicked.
-- Permissions: invite, kick, promote, demote, deposit, withdraw, upgrade (stash upgrades, claim/abandon/raid territories),
--              bounty (post gang bounties), rename (also sets the gang tag),
--              disband, rename, setcolor, equipment (wagon, camp equipment, crafting, stash).
Config.Ranks = {
    { name = 'recruit',   label = 'Recruit',    weight = 0, permissions = {} },
    { name = 'member',    label = 'Member',     weight = 1, permissions = { 'withdraw', 'equipment' } },
    { name = 'officer',   label = 'Officer',    weight = 2, permissions = { 'invite', 'kick', 'withdraw', 'deposit', 'equipment' } },
    { name = 'coleader',  label = 'Co-Leader',  weight = 3, permissions = { 'invite', 'kick', 'promote', 'demote', 'withdraw', 'deposit', 'upgrade', 'bounty', 'equipment' } },
    { name = 'leader',    label = 'Leader',     weight = 4, permissions = { 'invite', 'kick', 'promote', 'demote', 'withdraw', 'deposit', 'upgrade', 'bounty', 'disband', 'rename', 'setcolor', 'equipment' }, isLeader = true },
}

-- Default rank assigned to the gang creator
Config.DefaultLeaderRank = 'leader'
-- Default rank assigned to invited members
Config.DefaultJoinRank = 'recruit'

-- Colors members can choose for their gang tag (hex)
Config.GangColors = {
    '#e63946', '#f4a261', '#e9c46a', '#2a9d8f', '#264653',
    '#8338ec', '#3a86ff', '#ff006e', '#06d6a0', '#adb5bd',
}

-- Notifications (rsg-core notify)
Config.Notify = {
    duration = 5000,
}

-- Optional audit log (bank deposits/withdrawals, kicks, creation, disbanding) sent to rsg-log.
-- 'channel' must be a log channel that exists in your rsg-log config.
Config.Logging = {
    enabled = false,
    channel = 'default',
}

-- While the NUI is open, block game controls but still allow push-to-talk (rsg-voice).
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- How close (in meters) a member has to be to their wagon, deployed equipment, crafting
-- station or strongbox for the server to accept an action on it. Server-enforced.
Config.WagonInteractDistance = 40.0   -- wagon menu actions: set up / pack away / reset wagon
Config.StationInteractDistance = 6.0  -- crafting stations and the strongbox

-- Vehicle spawned in front of the founder when they create a new gang.
Config.GangVehicle = {
    enabled = true,
    model = 'chuckwagon002x',
    spawnDistance = 6.0,  -- meters in front of the player to try first
    checkRadius = 3.0,    -- meters around the spawn point that must be clear of peds/vehicles/objects
    maxAttempts = 6,      -- how many times to push the spawn point further out if blocked
    attemptStep = 2.5,    -- meters added to spawnDistance per retry
    restrictDriving = true,
    useTargetMenu = true,  -- open the gang menu from a target on the wagon instead of the chat command
}

-- How close (in meters) a player has to be to a saved wagon/equipment location
-- before the server will ask a client to spawn it there. Used by the
-- proximity threads in server/wagon.lua and server/equipment.lua so
-- entities only get created once someone is actually nearby, instead of
-- forcing a random online (possibly far away) player to load the model.
Config.RespawnProximityRadius = 80.0

-- How far (in meters) EVERY player has to be from a spawned wagon/equipment
-- entity before it gets deleted again. Kept larger than RespawnProximityRadius
-- on purpose (hysteresis) so an entity doesn't flicker in and out of
-- existence for someone loitering right at the spawn boundary.
Config.DespawnProximityRadius = 100.0

-- How often (in milliseconds) the proximity threads re-check whether each
-- wagon/equipment entity should be spawned or despawned.
Config.ProximityCheckInterval = 5 * 1000

-- Equipment gang members can pull out of storage (their wagon) and set up around camp
Config.GangEquipment = {
    {
        id = 'tent',                                       -- stable identifier — used as the DB/rank key, don't change once players have deployed one
        label = 'Camp Tent',
        prop = 'mp005_s_posse_tent_bountyhunter07x',
        initialDistance = 3.0,       -- meters in front of the player the ghost preview starts at
        maxPlacementDistance = 10.0, -- final placement can't end up further than this from the wagon (server-enforced)
        maxDeployed = 1,             -- how many of this item can be deployed at once, server-enforced (default 1 if omitted)
    },
    {
        id = 'torch',
        label = 'Camp Torch',
        prop = 'p_torchpost01x',
        initialDistance = 2.0,
        maxPlacementDistance = 10.0,
        maxDeployed = 5,             -- up to 5 torches can be set up around camp at the same time
    },
    {
        id = 'hitchingpost',
        label = 'Hitching Post',
        prop = 'p_hitchingpost01x',
        initialDistance = 2.5,
        maxPlacementDistance = 10.0,
        maxDeployed = 2,             -- up to 2 hitching posts can be set up around camp at the same time
    },
    {
        id = 'campfire',
        label = 'Campfire',
        prop = 'p_campfirecombined01x',
        initialDistance = 2.5,
        maxPlacementDistance = 10.0,
        maxDeployed = 1,             -- only 1 campfire can be set up at a time
    },
    {
        id = 'crafttable',
        label = 'Crafting Table',
        prop = 'mp005_s_posse_ammotable03x',
        initialDistance = 2.5,
        maxPlacementDistance = 10.0,
        maxDeployed = 1,             -- only 1 ammo table can be set up at a time
    },
    {
        id = 'wellpump',
        label = 'Well Pump',
        prop = 'p_wellpumpnbx01x',
        initialDistance = 2.5,
        maxPlacementDistance = 10.0,
        maxDeployed = 1,             -- only 1 well pump can be set up at a time
    },
    {
        id = 'strongbox',
        label = 'Strongbox',
        prop = 'p_trunk05x',
        initialDistance = 2.0,
        maxPlacementDistance = 10.0,
        maxDeployed = 1,             -- only 1 strongbox can be set up at a time
    },
}

-- Crafting/cooking config
Config.Crafting = {
    enabled = true,
    stations = {
        {
            id = 'ammotable_craft',
            equipmentId = 'crafttable', -- ties this station to the 'crafttable' Config.GangEquipment item
            label = 'Ammo Table',
            targetLabel = 'Craft',
            targetIcon = 'fas fa-hammer',
            intro = 'Craft supplies using materials from your own saddlebag.',
            recipes = {
                {
                    id = 'ammo_pistol',
                    label = 'Pistol Ammo (x10)',
                    output = { item = 'ammo_pistol', amount = 10 },
                    ingredients = {
                        { item = 'metalscrap', amount = 2 },
                        { item = 'gunpowder', amount = 1 },
                    },
                },
                {
                    id = 'ammo_rifle',
                    label = 'Rifle Ammo (x10)',
                    output = { item = 'ammo_rifle', amount = 10 },
                    ingredients = {
                        { item = 'metalscrap', amount = 3 },
                        { item = 'gunpowder', amount = 2 },
                    },
                },
            },
        },
        {
            id = 'campfire_cook',
            equipmentId = 'campfire', -- ties this station to the 'campfire' Config.GangEquipment item
            label = 'Campfire',
            targetLabel = 'Cook',
            targetIcon = 'fas fa-fire',
            intro = 'Cook food over the fire using ingredients from your own saddlebag.',
            recipes = {
                {
                    id = 'cooked_meat',
                    label = 'Cooked Meat',
                    output = { item = 'meat_cooked', amount = 1 },
                    ingredients = {
                        { item = 'meat_raw', amount = 1 },
                    },
                },
                {
                    id = 'cooked_fish',
                    label = 'Cooked Fish',
                    output = { item = 'fish_cooked', amount = 1 },
                    ingredients = {
                        { item = 'fish_raw', amount = 1 },
                    },
                },
            },
        },
    },
}

-- gang storage
Config.GangStash = {
    enabled = true,
    equipmentId = 'strongbox',
    targetLabel = 'Open Stash',
    targetIcon = 'fas fa-box',
    label = 'Strongbox',
    minWeight = 1, -- lowest rank weight that may open the stash (0 = recruits too)
    tiers = {
        { id = 'small',  label = 'Small',  slots = 50,  maxWeight = 500000,  upgradeCost = 0 },
        { id = 'medium', label = 'Medium', slots = 100, maxWeight = 1000000, upgradeCost = 5000 },
        { id = 'large',  label = 'Large',  slots = 200, maxWeight = 2000000, upgradeCost = 15000 },
    },
}

-- Activity log: bank, member, equipment, territory and upkeep events shown in the Log tab.
Config.ActivityLog = {
    enabled = true,
    keep = 200,      -- entries kept per gang (older ones are pruned)
    show = 50,       -- entries sent to the UI
    minWeight = 2,   -- lowest rank weight that can read the log (2 = officer)
}

-- Online gang members appear on each other's map.
Config.MemberBlips = {
    enabled = true,
    interval = 3000, -- ms between position updates
}

-- Weekly upkeep: the cost is taken from the gang bank. After maxMissed unpaid cycles in a row the gang is disbanded.
Config.Upkeep = {
    enabled = true,
    intervalHours = 168,
    cost = 2500,
    maxMissed = 3,
}

-- Territories: claim a spot (stand inside it, needs the 'upgrade' permission) and earn income for the gang bank.
-- The coordinates below are examples; set them to wherever you want turf on your map.
Config.Territories = {
    enabled = true,
    maxPerGang = 2,
    incomeIntervalMinutes = 30,
    requireOnlineMember = true, -- income is only paid while a member of the owning gang is online
    list = {
        { id = 'valentine', label = 'Valentine', coords = vector3(-281.0, 805.0, 119.0), region = 'valentine', radius = 80.0, claimCost = 5000, income = 150 },
        { id = 'rhodes', label = 'Rhodes', coords = vector3(1225.0, -1297.0, 76.0), region = 'rhodes', radius = 80.0, claimCost = 5000, income = 150 },
        { id = 'strawberry', label = 'Strawberry', coords = vector3(-1791.0, -386.0, 160.0), region = 'strawberry', radius = 80.0, claimCost = 4000, income = 120 },
    },
}

-- rsg-reputation integration (optional). Gang honor = average honor of the members.
-- claimAction must exist in rsg-reputation's Config.Actions; the territory's `region` is the reputation region id.
Config.Reputation = {
    enabled = true,
    claimAction = 'gang_territory',
    refreshMinutes = 5,
}

-- Gang bounties via rsg-bountyhunter (3.2.0+): the amount is held from the gang bank until the poster ends.
Config.Bounties = {
    enabled = true,
    minReward = 500,
    maxReward = 20000,
    maxActive = 2,
    expireHours = 6,
}

-- Rivalries: confirmed player kills between members of different gangs (needs rsg-core 3.4.0+).
Config.Rivalry = {
    enabled = true,
    pairCooldownSeconds = 300,
}

-- Turf raids: members of another gang enter a territory and out-number its defenders for holdSeconds to capture it.
Config.Raids = {
    enabled = true,
    minAttackers = 2,            -- members of the raiding gang that must be inside to start
    holdSeconds = 120,           -- time the attackers must out-number the defenders (counted while they do)
    durationSeconds = 600,       -- the raid fails when this runs out
    cooldownMinutes = 60,        -- per raiding gang
    protectMinutes = 120,        -- a captured territory cannot be raided again for this long
    requireDefenderOnline = true, -- cannot raid a gang with nobody online
}

-- Short gang tag shown in front of the gang name (and exported with GetGangTag for chat resources).
Config.Tags = {
    enabled = true,
    minLength = 2,
    maxLength = 5,
}

-- Leaderboard tab. Score = turf * turfPoints + rival kills * killPoints. monthlyReset clears rivalry kills each month.
Config.Leaderboard = {
    enabled = true,
    size = 10,
    turfPoints = 50,
    killPoints = 10,
    monthlyReset = true,
}
