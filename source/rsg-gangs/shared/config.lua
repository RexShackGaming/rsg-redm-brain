Config = {}

-- Build the database tables automatically on start (CREATE TABLE IF NOT EXISTS).
-- Set to false to import installation/rsg-gangs.sql manually instead.
Config.AutoDatabase = true

-- Check this resource's version against GitHub on start (prints to the server console).
Config.VersionCheck = true

-- Command used to open the gang menu
Config.Command = 'setupgang'

-- Staff panel: a NUI where admins manage every gang (create, rename, bank, members, turf, equipment, upkeep).
-- The command and every action in the panel are checked on the server against this permission.
Config.Admin = {
    enabled = true,
    command = 'gangadmin',
    permission = 'admin',  -- rsg-core permission (ACE group) allowed to use the panel
    logLines = 100,        -- activity log rows loaded for a gang in the panel
}

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

-- Ranks, permissions, members and the bank now belong to rsg-society (version 3.1.0 or newer).
-- Each gang's ranks (names, order, what each rank may do) are edited in rsg-society's menu on the Ranks tab.
-- Rank "weight" below means the rank level: 0 is the lowest rank of a gang, the boss rank is the highest.
--
-- This list is only used by the staff panel (/gangadmin) as the choices for adding a member or
-- changing a rank. The level numbers must match the ranks your gangs have in rsg-society (its default
-- ranks are Recruit, Member, Officer, Co-Leader, Leader = levels 0 to 4). The leader rank is never offered.
Config.Ranks = {
    { name = 'recruit',   label = 'Recruit',    weight = 0 },
    { name = 'member',    label = 'Member',     weight = 1 },
    { name = 'officer',   label = 'Officer',    weight = 2 },
    { name = 'coleader',  label = 'Co-Leader',  weight = 3 },
    { name = 'leader',    label = 'Leader',     weight = 4, isLeader = true },
}

-- Permissions are the rsg-society permissions of the rank (Ranks tab):
--   invite = hire, kick = fire, promote/demote = promote, deposit, withdraw, rename and setcolor = settings,
--   upgrade (stash upgrades, claim/abandon/raid territories), bounty, disband, equipment (wagon, camp equipment, crafting, stash).

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
Config.StationInteractDistance = 6.0  -- crafting stations, the well pump and the strongbox

-- Vehicle spawned in front of the founder when they create a new gang.
Config.DebugWagon = false -- print wagon spawn/save/despawn steps to the server console

Config.GangVehicle = {
    enabled = true,
    model = 'chuckwagon002x',
    spawnOnRoad = true,        -- place the new wagon on the nearest road/trail instead of in front of the founder
    maxRoadDistance = 150.0,   -- meters: furthest road node from the founder that may be used
    minRoadDistance = 6.0,     -- meters: skip road nodes right on top of the founder
    roadNodeAttempts = 12,     -- how many of the nearest road nodes to try (nearest first)
    fallbackOffRoad = true,    -- if no clear road spot exists, fall back to the spot-in-front search below
    checkRadius = 4.0,         -- meters around the spawn point that must be clear of peds/vehicles/objects
    spawnDistance = 6.0,       -- off-road fallback: meters in front of the player to try first
    maxAttempts = 6,           -- off-road fallback: how many times to push the spawn point further out if blocked
    attemptStep = 2.5,         -- off-road fallback: meters added to spawnDistance per retry
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

-- Well pump: lets gang members fill an empty bucket at their deployed 'wellpump' equipment.
-- The bucket items, uses, animation and fill time are set in rsg-wellpump's config (Config.EmptyItem,
-- Config.FullItem, Config.BucketUses, Config.FillTime). Server-enforced: the member must be in the gang
-- and standing at the gang's own deployed pump.
Config.WellPump = {
    enabled = true,
    equipmentId = 'wellpump',          -- ties this to the 'wellpump' Config.GangEquipment item
    targetIcon = 'fa-solid fa-droplet',
    drink = true,                      -- also show a Drink Water option (amount and cooldown are set in rsg-wellpump's Config.Drink)
    drinkIcon = 'fa-solid fa-glass-water',
    requirePermission = false,         -- true = only ranks with the 'equipment' permission may use the pump
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
                    id = 'ammo_box_pistol',
                    label = 'Pistol Ammo (x10)',
                    output = { item = 'ammo_box_pistol', amount = 10 },
                    ingredients = {
                        { item = 'resource_copper_bar', amount = 1 },
                        { item = 'resource_lead_bar',   amount = 1 },
                        { item = 'resource_gunpowder',  amount = 1 },
                    },
                },
                {
                    id = 'ammo_box_rifle',
                    label = 'Rifle Ammo (x10)',
                    output = { item = 'ammo_box_rifle', amount = 10 },
                    ingredients = {
                        { item = 'resource_copper_bar', amount = 1 },
                        { item = 'resource_lead_bar',   amount = 1 },
                        { item = 'resource_gunpowder',  amount = 1 },
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
                    output = { item = 'cooked_meat', amount = 1 },
                    ingredients = {
                        { item = 'raw_meat', amount = 1 },
                    },
                },
                {
                    id = 'cooked_fish',
                    label = 'Cooked Fish',
                    output = { item = 'cooked_fish', amount = 1 },
                    ingredients = {
                        { item = 'raw_fish', amount = 1 },
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

-- Gang bounties via rsg-bountyhunter (3.4.0+): a gang funds a bounty on a player (picked from the online players)
-- or on a rival gang for hunters to collect. The amount is held from the gang bank until the poster ends.
Config.Bounties = {
    enabled = true,
    minReward = 500,
    maxReward = 20000,
    maxActive = 2,
    expireHours = 6,
    targetPlayers = true, -- allow bounties on a single player
    targetGangs = true,   -- allow bounties on a rival gang (any online member can be brought in)
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
