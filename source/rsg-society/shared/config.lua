Config = {}

-- Build the database tables automatically on start (runs install.sql, CREATE TABLE IF NOT EXISTS).
-- Set to false and import install.sql by hand to install manually.
Config.AutoDatabase = true

-- Check GitHub for a newer version on start
Config.VersionCheck = true

-----------------------------------------------------------------------
-- General
-----------------------------------------------------------------------
Config.Command = 'society'          -- opens the menu at the nearest desk (or your gang menu)
Config.GangCommand = 'gang'         -- opens your gang menu (or the create-a-gang form) from anywhere
Config.Keybind = 'J'                -- key shown on the desk prompt (a key NAME from RSGCore.Shared.Keybinds)
Config.UseKeyMapping = true         -- also register a rebindable key that opens the menu
Config.GangKey = ''                 -- default key for that mapping ('' = unbound, players bind it in the game's key settings)

Config.InteractDistance = 5.0       -- server-side max distance from a desk for desk actions (jobs)
Config.HireDistance = 10.0          -- max distance to a player you hire, invite or fine
Config.MaxTransaction = 1000000     -- biggest single deposit or withdrawal
Config.ActionCooldown = 750         -- ms between menu actions per player
Config.ReadCooldown = 150           -- ms between menu reads per player (opening the menu, loading a tab)
Config.PageSize = 40                -- rows per page in the ledger, audit log and fine list
Config.PruneDays = 90               -- on start, delete ledger and audit rows (and settled fines) older than this many days. 0 = keep everything
Config.AllowEqualRank = true        -- a boss may act on, and assign, ranks up to their own level (false = strictly below)

-- While the menu is open, block game controls but still allow push-to-talk (rsg-voice).
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- Optional audit copy sent to rsg-log. 'channel' must exist in your rsg-log config.
Config.Logging = {
    enabled = false,
    channel = 'society',
}

-- Permission needed for the admin commands (/addsociety, /societydesk, /removesocietydesk, /societyfunds, /societymigrate, /removegang)
Config.AdminPermission = 'admin'

-- Admin panel: one NUI to see and manage every society (members, ranks, money, fines, desks, audit, tools).
-- Needs Config.AdminPermission. Every action is checked on the server again.
Config.Admin = {
    Enabled = true,
    Command = 'societyadmin',   -- opens the admin panel
    Key = '',                   -- default key for a rebindable mapping ('' = unbound, bind it in the game's key settings)
    MaxFunds = 10000000,        -- biggest single funds change from the panel (dollars)
}

-- Desk blips (only for locations with showblip = true)
Config.Blip = {
    name = 'Society Desk',
    sprite = 'blip_honor_good',
    scale = 0.2,
}

-----------------------------------------------------------------------
-- Permissions
-- Bosses (a boss grade of a job, the boss rank of a gang) always have every permission.
-- Everyone else only has what the Ranks tab gives their rank.
-----------------------------------------------------------------------
Config.Permissions = {
    'members',   -- see the member list
    'hire',      -- hire or invite players
    'fire',      -- fire or remove members below your own rank
    'promote',   -- change the rank of members below your own rank
    'finance',   -- see the balance and the ledger
    'deposit',   -- put cash into the account
    'withdraw',  -- take cash out of the account
    'payroll',   -- switch payroll on or off
    'storage',   -- open the shared storage
    'fines',     -- issue fines and see the fine list
    'finevoid',  -- cancel an unpaid fine
    'audit',     -- read the audit trail
    'ranks',     -- change what each rank may do (and rank names and pay for gangs)
    'settings',  -- gangs: rename, colour, tag
    'bonus',     -- pay a one-off bonus to an online member out of the account
    'announce',  -- write the announcement every member sees on the Overview tab
}
-- Extra permissions that only exist for gangs. Other scripts (rsg-gangs and so on) check these through the API.
Config.GangPermissions = {
    'disband',   -- disband the gang
    'equipment', -- use gang equipment, wagon and crafting
    'upgrade',   -- upgrade the strongbox, claim, abandon and raid territory
    'bounty',    -- post gang bounties
}

-----------------------------------------------------------------------
-- Payroll
-- Job wages are paid by rsg-core's paycheck loop, which asks society first (see DOCS.md, "rsg-core change").
-- A society with payroll on pays wages out of its balance. If the balance can't cover a wage, that wage is skipped.
-- Gang wages (the Pay column of the Ranks tab) are paid by this resource on its own timer.
-----------------------------------------------------------------------
Config.Payroll = {
    Enabled = true,          -- master switch for society-funded payroll
    TrustedWageCaller = 'rsg-core', -- only this resource may call ProcessWage / RefundWage (they move society money)
    GangInterval = 10,       -- minutes between gang payroll runs
    NotifyEmployee = true,   -- tell the player when their wage was skipped because the account is empty
    NotifyBosses = true,     -- tell online members with the 'payroll' permission (once per run per society)
    DefaultJobPayroll = true,  -- new job societies start with payroll on
    DefaultGangPayroll = false, -- new gang societies start with payroll off
}

-----------------------------------------------------------------------
-- Fines
-----------------------------------------------------------------------
Config.Fines = {
    Enabled = true,
    Min = 1,
    Max = 5000,
    PayWith = { 'cash', 'bank' },  -- money types taken, in this order
    AllowPartial = true,           -- take what the player has now and keep the rest as an unpaid fine
    CollectOnLogin = true,         -- collect unpaid fines when the player's character loads
    CollectOnPayroll = true,       -- ...and on every gang payroll run
    IssueLimit = 6,                -- most fines one person may issue inside the window below (0 = no limit)
    IssueWindowMinutes = 10,
}

-----------------------------------------------------------------------
-- Money controls
-----------------------------------------------------------------------
-- Job societies only: the member must be on duty in that job to use these menu actions.
Config.OnDuty = {
    Enabled = false,
    Actions = { 'deposit', 'withdraw', 'payroll', 'bonus', 'fine', 'transfer_funds' },
}

-- How much one member may withdraw in any 24 hours (dollars, 0 = no limit).
Config.Withdraw = {
    DailyLimit = 0,
    BossesExempt = true,
}

-- Bonus: one-off payment from the account to an online member (needs the 'bonus' permission).
Config.Bonus = {
    Max = 5000,   -- biggest single bonus (0 = bonuses off)
}

-- Transfers between society accounts (needs the 'withdraw' permission on the sending side).
Config.Transfers = {
    Enabled = false,
    Max = 100000,
    SameTypeOnly = true,   -- jobs can only send to jobs, gangs only to gangs
}

-- The announcement members see on the Overview tab (needs the 'announce' permission to edit).
Config.Motd = {
    MaxLength = 200,
}

-----------------------------------------------------------------------
-- Storage (rsg-inventory stash 'society_<name>')
-----------------------------------------------------------------------
Config.Storage = {
    job  = { maxWeight = 4000000, slots = 50 },
    gang = { maxWeight = 4000000, slots = 50 },
}

-----------------------------------------------------------------------
-- Job societies
-- Add a job name here to give it a society. Options: perms = { [grade level] = { 'permission', ... } } gives a non-boss grade
-- its starting permissions (bosses can change them in the Ranks tab afterwards).
-- Anything paying money in through exports['rsg-bossmenu']:AddMoney(job, amount) also gets a society automatically,
-- as long as the job exists in rsg-core.
-----------------------------------------------------------------------
Config.Jobs = {
    medic    = { perms = { [1] = { 'members', 'storage' } } },
    vallaw   = { perms = { [1] = { 'members', 'storage', 'fines' } } },
    rholaw   = { perms = { [1] = { 'members', 'storage', 'fines' } } },
    blklaw   = { perms = { [1] = { 'members', 'storage', 'fines' } } },
    strlaw   = { perms = { [1] = { 'members', 'storage', 'fines' } } },
    stdenlaw = { perms = { [1] = { 'members', 'storage', 'fines' } } },
}

-- Job members get a job slot through rsg-core multi-job. If the player has no real job (unemployed) the new job also becomes their active job.
Config.JobHireNeedsConsent = false  -- true: the player must accept a job invite first

-- Desks where job societies open their menu (hold the prompt key). Admins can add more in game with /societydesk.
Config.Locations = {
    { id = 'valmedic_boss',  name = 'Medic Boss Menu', society = 'medic',    coords = vector3(-289.95, 816.24, 119.39),    showblip = false },
    { id = 'vallaw_boss',    name = 'Law Boss Menu',   society = 'vallaw',   coords = vector3(-277.79, 807.43, 119.38),    showblip = false },
    { id = 'rholaw_boss',    name = 'Law Boss Menu',   society = 'rholaw',   coords = vector3(1361.41, -1303.56, 77.77),   showblip = false },
    { id = 'blklaw_boss',    name = 'Law Boss Menu',   society = 'blklaw',   coords = vector3(-762.20, -1266.68, 44.05),   showblip = false },
    { id = 'strlaw_boss',    name = 'Law Boss Menu',   society = 'strlaw',   coords = vector3(-1811.99, -354.03, 164.65),  showblip = false },
    { id = 'stdenlaw_boss',  name = 'Law Boss Menu',   society = 'stdenlaw', coords = vector3(2508.45, -1308.90, 48.95),   showblip = false },
}

-----------------------------------------------------------------------
-- Gangs (society owns gang membership, ranks, bank, storage and log)
-----------------------------------------------------------------------
Config.Gang = {
    Enabled = true,              -- players can create gangs
    CreateCost = 5000,           -- cash taken to create a gang
    MinNameLength = 3,
    MaxNameLength = 20,
    MaxMembers = 15,             -- 0 = unlimited
    InviteExpireSeconds = 120,
    MaxTagLength = 5,
    MaxRankPay = 1000,           -- highest wage per payroll run a gang boss can set for a rank
    MaxRanks = 10,               -- most ranks a gang can have (bosses add and delete ranks in the Ranks tab)
    RequireDesk = false,         -- gangs use their menu from anywhere
    RemoteStorage = false,       -- true: the Storage button opens the gang stash anywhere. false: only scripts that call exports['rsg-society']:OpenStorage (for example a strongbox) open it
    DisbandPayout = 'leader',    -- who gets the account balance when a gang is disbanded: 'leader' (as cash) or 'none'
    -- Ranks every new gang starts with, lowest first. 'boss' ranks always have every permission.
    DefaultRanks = {
        { name = 'Recruit',   payment = 0, perms = { 'members' } },
        { name = 'Member',    payment = 0, perms = { 'members', 'withdraw', 'equipment', 'storage' } },
        { name = 'Officer',   payment = 0, perms = { 'members', 'hire', 'fire', 'withdraw', 'deposit', 'equipment', 'storage', 'finance', 'audit', 'announce' } },
        { name = 'Co-Leader', payment = 0, perms = { 'members', 'hire', 'fire', 'promote', 'withdraw', 'deposit', 'upgrade', 'bounty', 'equipment', 'storage', 'finance', 'audit', 'announce', 'bonus' } },
        { name = 'Leader',    payment = 0, perms = {}, boss = true },
    },
    Colors = { '#e63946', '#f4a261', '#e9c46a', '#2a9d8f', '#264653', '#8338ec', '#3a86ff', '#ff006e', '#06d6a0', '#adb5bd' },
}

-----------------------------------------------------------------------
-- Migration (runs once on first start, never deletes anything)
-----------------------------------------------------------------------
Config.Migration = {
    Enabled = true,
    ImportManagementFunds = true,  -- rsg-bossmenu / rsg-gangmenu accounts (table management_funds)
    ImportCoreGangs = true,        -- gangs from rsg-core's shared/gangs.lua that have members or money become gang societies
    ImportRsgGangs = true,         -- rsg-gangs (tables rsg_gangs, rsg_gang_members, rsg_gang_logs)
    -- Permissions given to non-boss ranks of imported core gangs (rsg-core gangs have no permission data)
    ImportedRankPerms = { 'members', 'deposit', 'storage' },
}
