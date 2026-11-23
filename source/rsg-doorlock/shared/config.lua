Config = {}
-- build the database tables automatically on start (set false and import the SQL file for a manual install)
Config.AutoDatabase = true

Config.DefaultDistance   = 1.25  -- interaction range when a door has no 'distance' set
Config.DistanceTolerance = 2.0   -- extra server-side leeway for the proximity check (latency)
Config.SyncDistance      = 30.0  -- doors within this range are kept in their synced state
Config.Cooldown          = 1500  -- ms between door uses per player (server enforced)
Config.HoldDuration      = 750   -- ms the player must hold ENTER to use a door
Config.RequireOnDuty     = false -- true = player must be on duty to use job doors

Config.AdminPermission   = 'admin' -- RSG permission needed for /doorlock (god, developer, headadmin, admin, mod)
Config.AdminCommand      = 'doorlock'
Config.AdminBypass       = true  -- admins can open every lock (incl. ones with no jobs)
Config.MaxDoorsPerLock   = 8     -- e.g. 2 for double doors
Config.PickRange         = 2.0   -- how close your aim must be to a door to select it in the editor
Config.Debug             = false  -- print MLO door lookups to the F8 console
Config.AllowPushToTalkWhileOpen = true -- keep push-to-talk working while the /doorlock editor has focus
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
Config.AllowCustomDoors  = true  -- allow picking MLO / custom door objects that aren't in shared/doorhashes.lua

-- Lockpicking (needs the rsg-lockpick resource). A lock is only pickable when it has a difficulty set in the /doorlock editor.
Config.Lockpick = {
    Enabled      = true,
    Key          = 'G',   -- key name from RSGCore.Shared.Keybinds for the "Pick lock" prompt
    HoldDuration = 750,   -- ms the player must hold the key
    Presets      = { 'easy', 'medium', 'hard' }, -- difficulties offered in the editor (names from rsg-lockpick Config.Presets)
    Cooldown     = 5000,  -- ms between lockpick requests per player (server enforced)
    RelockAfter  = 300,   -- seconds a picked door stays unlocked before it locks again (0 = until someone locks it)
    Alert        = nil,   -- lawman alert chance on a pick, 0.0-1.0 (nil = rsg-lockpick's own Config.Alert, false = never alert)
    Reputation   = 'theft', -- rsg-reputation action reported on a successful pick, in the lock's region (nil = none)
}

-- Opening hours: a lock with open_from / open_to set in the editor unlocks at the first hour and locks at the second.
-- A manual toggle holds until the next opening or closing.
Config.Schedule = {
    Enabled       = true,
    UseGameTime   = true,  -- hours are in-game time from rsg-weather (false = the server's real clock)
    CheckInterval = 20,    -- seconds between schedule checks
}

-- Map blips for every lock, shown to the admin only while the /doorlock editor is open
Config.EditorBlips = {
    Enabled = true,
    Sprite  = 'blip_proc_home_locked',
    Scale   = 0.6,
}

-- Doors are stored in the database (table: rsg_doorlocks) and managed in game with /doorlock.
-- On first start (empty table) the doors in server/seed_doors.lua are imported once.
Config.ImportConfigDoors = true


Config.JailDoors = {
    -- main front gates
    906662604, -- -1819721708 : p_sis_frontgateb_r
    1121239638, -- -1819721708 : p_sis_frontgateb_r
    2617210026, -- 1692000954 : p_sis_frontgateb_l
    3984556459, -- 1692000954 : p_sis_frontgateb_l
}
