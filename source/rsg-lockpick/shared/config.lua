Config = {}

---------------------------------------------------------------------------
-- UI / input
---------------------------------------------------------------------------
-- While the minigame is open, block game controls but allow push-to-talk (rsg-voice).
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

-- Where the mouse cursor is placed when the minigame opens (screen fraction 0.0 - 1.0).
Config.CursorStart = { x = 0.5, y = 0.5 }

-- Gamepad support inside the UI (left stick / D-pad rotates the pick, A or RT turns the lock, B cancels).
Config.Controller = true

-- A solve reported faster than this (ms after opening) is physically impossible and is
-- treated as a failure. Turning the cylinder alone takes ~750 ms at the default speed.
Config.MinSolveTime = 1000

-- Pause (ms) after a result so the player sees "Unlocked" / "Pick broken" before the UI closes.
Config.ResultDelay = 700

---------------------------------------------------------------------------
-- Difficulty
---------------------------------------------------------------------------
-- Base difficulty. Presets and per-call options override these.
Config.Defaults = {
    pins             = 1,    -- number of picks the player gets
    pinDamage        = 20,   -- damage per hit; a pick has 100 health
    damageInterval   = 150,  -- ms between damage ticks while the cylinder is jammed
    solvePadding     = 4,    -- degrees either side of the sweet spot that still opens the lock
    maxDistFromSolve = 45,   -- degrees away from the sweet spot where the cylinder cannot move at all
    mouseSmoothing   = 2,    -- higher = slower pick rotation with the mouse
    turnSpeed        = 120,  -- cylinder turn speed in degrees per second
    timeLimit        = 0,    -- seconds for the whole attempt, 0 = no timer
}

-- Named lock presets: pass { preset = 'hard' } (or data.preset on the server). Only the keys listed are changed.
Config.Presets = {
    easy   = { pins = 3, pinDamage = 12, solvePadding = 8, maxDistFromSolve = 60 },
    medium = { pins = 2, pinDamage = 20, solvePadding = 5, maxDistFromSolve = 50 },
    hard   = { pins = 1, pinDamage = 30, solvePadding = 3, maxDistFromSolve = 35, timeLimit = 45 },
}

-- Everything a calling script or preset passes is clamped to these {min, max} limits.
Config.Limits = {
    pins             = { 1, 10 },
    pinDamage        = { 1, 100 },
    damageInterval   = { 50, 1000 },
    solvePadding     = { 1, 30 },
    maxDistFromSolve = { 10, 90 },
    mouseSmoothing   = { 0.5, 10 },
    turnSpeed        = { 40, 400 },
    timeLimit        = { 0, 300 },
}

---------------------------------------------------------------------------
-- Feedback
---------------------------------------------------------------------------
-- Frontend sounds (PlaySoundFrontend name / soundset). Set enabled = false to mute.
-- Names come from rdr3_discoveries audio/soundsets. Some sets may need their audio bank loaded
-- by the game at that moment; if one is silent in your build, swap it here.
Config.Sounds = {
    enabled = true,
    turn    = { name = 'Dial_Turn_Single',          set = 'RDRO_Safecracking_Sounds' }, -- start turning the lock
    jam     = { name = 'Small_Safe_Tumbler',        set = 'RDRO_Safecracking_Sounds' }, -- cylinder jams, pick takes damage
    brk     = { name = 'Padlock_Impact',            set = 'UTP2_Sounds' },              -- pick breaks
    unlock  = { name = 'Small_Safe_Unlock',         set = 'Mud5_Sounds' },              -- lock opens
}

-- Optional animation while picking. The dictionary and clip exist in rdr3_discoveries
-- (megadictanims) but this clip is meant for a door handle, so it is OFF until you have tested it in-game.
Config.Animation = {
    Enabled = false,
    Dict    = 'mech_doors@locked@door_knob@generic@handle_l@hand_l@try_door',
    Name    = 'lockpick',
    Flag    = 1, -- 1 = loop
}

---------------------------------------------------------------------------
-- Server-issued attempts (StartAttempt export)
---------------------------------------------------------------------------
Config.Server = {
    TicketTTL      = 180000, -- ms a ticket stays valid before the attempt is cancelled
    MinSolveTime   = 1500,   -- ms: a solve reported faster than this (server clock) counts as a failure
    Cooldown       = 2000,   -- ms between attempts per player
    DefaultRadius  = 5.0,    -- metres: max distance from data.coords when a radius is not given
    DistanceSlack  = 2.0,    -- extra metres allowed when the result arrives
}

-- Lockpick item: required, worn down by use, and a worn pick is harder to use.
Config.Item = {
    Enabled = true,
    Name    = 'tool_lockpick', -- must exist in RSGCore.Shared.Items
    Require = true,            -- refuse to start an attempt without the item
    QualityDamageScale = 1.0,  -- pick damage x (1 + (100 - quality) / 100 * scale); 0 disables
    Wear = {
        Success          = 5,    -- quality lost after a successful attempt
        Fail             = 25,   -- quality lost after a failed attempt
        BreakChanceOnFail = 0.25 -- chance (0-1) the lockpick is destroyed outright on a failure
    },
}

-- Lockpicking skill in rsg-skills (optional: ignored if rsg-skills is not running).
Config.Skill = {
    Enabled = true,
    Name    = 'lockpicking',
    XP      = { Success = 15, Fail = 3 },
    Definition = {
        order = 120,
        maxLevel = 20,
        -- Add locale keys perk_lockpick_sweet_spot, perk_lockpick_pick_damage and perk_lockpick_extra_pick
        -- to rsg-skills' locales so the panel shows readable names.
        perks = {
            lockpick_sweet_spot = { suffix = '°', levels = { [3] = 1, [6] = 2, [10] = 3, [15] = 4 } }, -- wider sweet spot
            lockpick_pick_damage = { suffix = '%', levels = { [5] = 10, [10] = 20, [15] = 30 } },      -- less damage taken
            lockpick_extra_pick  = { suffix = '',  levels = { [12] = 1, [20] = 2 } },                   -- extra picks per attempt
        },
    },
}

-- Reputation (rsg-reputation, optional: ignored if it is not running).
-- A successful server-issued attempt can report a crime. The calling script decides what the lock is:
--   exports['rsg-lockpick']:StartAttempt(src, { preset = 'medium', reputation = { action = 'theft', region = 'valentine' } }, cb)
-- `region` is optional (without it only honor changes). Only actions listed in Actions are accepted.
-- The amounts come from rsg-reputation's Config.Actions. Failed and cancelled attempts change nothing.
Config.Reputation = {
    Enabled       = true,
    DefaultAction = nil,   -- applied to successful attempts that pass no `reputation` (nil = only when the caller asks)
    Actions       = { theft = true, robbery = true },
}

-- Alert on-duty lawmen (rsg-lawman) after a server-issued attempt.
Config.Alert = {
    Enabled         = true,
    JobType         = 'leo',
    ChanceOnFail    = 0.6,
    ChanceOnSuccess = 0.15,
    MinGap          = 10000, -- ms between alerts from the same player
}

---------------------------------------------------------------------------
-- Shared helpers (used by client and server)
---------------------------------------------------------------------------
-- Fills missing keys from Config.Defaults and clamps every value to Config.Limits.
function Config.Clamp(opts)
    opts = type(opts) == 'table' and opts or {}
    local out = {}
    for key, default in pairs(Config.Defaults) do
        local v = tonumber(opts[key])
        if v == nil then v = default end
        local limit = Config.Limits[key]
        if limit then v = math.max(limit[1], math.min(limit[2], v)) end
        out[key] = v
    end
    out.pins = math.floor(out.pins)
    return out
end

-- Defaults < preset < explicit options, then clamped.
function Config.Build(presetName, overrides)
    local merged = {}
    for k, v in pairs(Config.Defaults) do merged[k] = v end
    local preset = presetName and Config.Presets[presetName]
    if preset then for k, v in pairs(preset) do merged[k] = v end end
    if type(overrides) == 'table' then
        for k in pairs(Config.Defaults) do
            if overrides[k] ~= nil then merged[k] = overrides[k] end
        end
    end
    return Config.Clamp(merged)
end
