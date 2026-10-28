Config = {}

-- ── Core ────────────────────────────────────────────────────────────────────
Config.Debug = false -- prints diagnostics and enables /fortunetest + /fortunespeech

-- ── Payment ─────────────────────────────────────────────────────────────────
Config.Price           = 1.00 -- cash per reading (0 = free)
Config.CooldownSeconds = 0    -- per-machine cooldown after a reading
Config.RequestCooldown = 2    -- per-player anti-spam (seconds)

-- ── Interaction ─────────────────────────────────────────────────────────────
Config.Interaction         = 'auto'  -- 'auto' = ox_target if started, else native prompt | 'target' | 'prompt'
Config.InteractionDistance = 2.0
Config.TargetIcon          = 'fa-solid fa-moon'
Config.PromptKey           = 0x760A9C6F -- G

-- How the player lines up with the machine before a reading.
Config.Approach = {
    distance   = 1.1, -- stop this far from the machine
    lookHeight = 1.0, -- look at this height above the machine origin
}

-- ── Timing ──────────────────────────────────────────────────────────────────
Config.PrepareTimeoutSeconds = 15
Config.MaxReadingSeconds     = 120
Config.StartDelayMs          = 750  -- machine start -> first line
Config.PauseBetweenLines     = 0.35 -- seconds
Config.SpeechPaddingSeconds  = 0.85 -- breathing room after each line

-- ── Audio ───────────────────────────────────────────────────────────────────
Config.HearingDistance = 25.0
Config.Volume          = 1.0 -- CustomLines (.ogg) volume
Config.SpeechParam     = 'SPEECH_PARAMS_FORCE'
-- Ambient voice names tried in order for the FTELL speech bank
Config.Voices = { 'FTELL', 'FORTUNE_TELLER', 'S_F_M_BWMWORKER_01', 'CS_FORTUNETELLER', 'S_FORTUNETELLER01X' }

-- ── Machine ─────────────────────────────────────────────────────────────────
Config.Model                   = 's_fortuneteller01x'
Config.StreamDistance          = 80.0
Config.UseConfiguredMachines   = true
Config.AutoDetectExistingProps = true -- allow map-placed machines that aren't in Config.Machines

-- Prop animation played on the machine itself.
Config.MachineAnim = {
    dictionary = 's_lev_des_mission',
    clip       = 's_fortuneteller01x',
}

-- ── Handover (the player hands over cash before the reading) ────────────────
Config.Handover = {
    enabled    = true,
    dictionary = 'script_common@handover@generic@player_handover@money',
    clip       = 'handover_money_plyr',
    blendIn    = 8.0,
    blendOut   = -8.0,
    durationMs = 2600,
    flag       = 0, -- one-shot
    prop = {
        enabled        = true,
        model          = 's_herbalpouch01x',
        bone           = 7966, -- hand bone
        visibleAfterMs = 300,
    },
}

-- ── Effects ─────────────────────────────────────────────────────────────────
Config.Light = {
    enabled   = true,
    red = 255, green = 220, blue = 186,
    range     = 2.5,
    intensity = 2.0,
}

-- ── Commands ────────────────────────────────────────────────────────────────
Config.CoordinatesCommand = 'fortunecoords' -- prints your vector4 for Config.Machines

-- ── Reading content ─────────────────────────────────────────────────────────
-- Game speech lines live in shared/lines.lua (Config.Lines).
Config.IntroLines  = {} -- always played before the random fortune
Config.CustomLines = {  -- .ogg files in ui/sounds/
    { id = 'custom_1', enabled = false, file = 'my-fortune.ogg', duration = 8.0, volume = 1.0 },
}

-- ── Machine placements ──────────────────────────────────────────────────────
Config.Machines = {
    { id = 'machine_1', enabled = true, spawn = true, coords = vector4(-308.29, 810.2, 117.98, 276.89) },   -- Valentine saloon
    { id = 'machine_2', enabled = true, spawn = true, coords = vector4(2629.61, -1219.4, 52.27, 90.00) },   -- Saint Denis
    { id = 'machine_3', enabled = true, spawn = true, coords = vector4(1324.49, -1294.63, 76.0, 240.00) },  -- Rhodes
}
