Config = {}

-- The radio item. Players need it in their inventory to use the radio.
Config.Item = 'radio'
-- Register the item with rsg-core on start, so no items.lua edit is needed (set false if you add it yourself,
-- see installation/shared_items.lua). Add radio.png to rsg-inventory's images.
Config.RegisterItem = true
Config.ItemDefinition = {
    label       = 'Field Radio',
    weight      = 500,
    type        = 'item',
    image       = 'radio.png',
    unique      = false,
    useable     = true,
    shouldClose = true,
    description = 'A portable field radio for talking to others on the same frequency',
    category    = 'tools',
}

Config.Command = 'radio' -- opens the radio (needs the item). Using the item does the same.

-- Frequencies are real radio frequencies with `Decimals` decimal places, between Min and Max.
-- Players type e.g. 446.0 and see it with the unit (MHz). Set Decimals = 0 for plain whole-number channels (Unit is then just a label).
-- PMR446-style example: Min = 446.0, Max = 446.2 gives 446.0, 446.1 and 446.2.
Config.Frequency = { Min = 100.0, Max = 470.0, Decimals = 1, Unit = 'MHz' }

-- Favorite frequencies each player can save (stored per character in their metadata, no database table needed).
Config.MaxFavorites = 10
Config.FavoriteLabelLength = 16 -- longest favorite name (characters)

-- Restricted channels. `freq` must be inside Config.Frequency and use no more than `Decimals` decimal places.
-- A frequency listed here can only be joined by players who match
-- ANY of: `jobs` (job name), `jobtypes` (job type, e.g. 'leo') or `gangs` (gang name).
-- A channel with none of them is open to everyone with a radio.
-- `onduty = true` also requires the player to be on duty. `label` is a locale key (locales/*.json).
-- `minGrade = 2` (optional) also requires that job/gang grade level or higher.
-- `permission = 'admin'` (optional) lets anyone with that rsg-core permission level in, whatever their job, duty or grade.
-- Adjust names and types to your own jobs.
Config.Channels = {
    { freq = 155.0, label = 'channel_lawman', jobtypes = { 'leo' }, onduty = true },
    { freq = 155.5, label = 'channel_medic',  jobs = { 'medic' },   onduty = true },
}

-- Multi-job: also let players use a restricted channel through a job they hold but are not currently working.
-- Never applies to channels with `onduty = true` (only the active job can be on duty).
Config.MultiJob = true

-- Hotkeys to jump to the next/previous favorite without opening the panel (players can rebind them in the game's key settings).
-- Key names: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
Config.FavoriteHotkeys = { Enabled = true, Next = 'PAGEDOWN', Prev = 'PAGEUP' }

-- Milliseconds to wait before sending updated member counts to open panels (batches busy moments)
Config.LiveUpdateDelay = 500

-- Private channels: players create their own frequency protected by a passcode (letters and digits).
-- Stored in the `rsg_radio_private` table (built automatically, see Config.AutoDatabase). The passcode is a shared
-- PIN for friends, not a password: it is stored as plain text and never sent to any client.
Config.Private = {
    Cost = 250,            -- price to create a private channel (0 = free). Updating or deleting your own channel is free
    MoneyType = 'cash',    -- account charged (cash, bank, ...)
    Enabled        = true,
    MaxPerPlayer   = 1,    -- channels one character can own
    MaxChannels    = 200, -- channels on the whole server (keeps the panel's data small)
    CodeMin        = 4,
    CodeMax        = 12,
    NameLength     = 16,
    ExpireDays     = 30,   -- delete a private channel nobody has joined for this long (0 = never)
    MaxWrongCodes  = 3,    -- wrong passcodes in a row before a temporary lockout
    LockoutSeconds = 60,
}

-- Staff tools (chat commands, need the rsg-core permission below): /radiolist [freq], /radiokick [id],
-- /radiomute [id] [minutes], /radiounmute [id], /radiodeleteprivate [freq]
Config.Staff = {
    Permission  = 'admin',
    MuteMinutes = 10,  -- default length of /radiomute (kept in memory until the server restarts)
    Webhook     = '',  -- optional Discord webhook URL that receives staff actions (never passcodes)
}

-- Build the database table automatically on start (set false and import install.sql manually instead)
Config.AutoDatabase = true

-- Seconds between checks that connected players still own the radio and still have access to their channel
Config.CheckInterval = 10

-- Shown in the hint when rsg-voice cannot tell the key (older rsg-voice, or Config.Radio.UseKeyMapping = false).
-- With rsg-voice 3.3.1+ the hint uses rsg-voice's Config.Radio.Key automatically.
Config.TransmitKeyLabel = 'O'

-- While the radio is open, block game controls but allow push-to-talk and the radio transmit key.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK (N)
}

-- Reserved frequency ranges: every frequency from `min` to `max` is restricted like a channel in Config.Channels, with
-- the same rules (jobs, jobtypes, gangs, onduty, minGrade, permission). `label` is a locale key (locales/*.json).
-- An entry in Config.Channels that sits inside a range wins over the range. Private channels cannot be created inside a range.
-- Both ends must be inside Config.Frequency and use no more than `Decimals` decimal places.
Config.Ranges = {
    -- { min = 160.0, max = 169.9, label = 'range_lawman', jobtypes = { 'leo' }, onduty = true, minGrade = 0 },
    -- { min = 170.0, max = 174.9, label = 'range_medic',  jobs = { 'medic' },   permission = 'admin' },
}

-- Channel HUD: a small list of who is on your channel and who is speaking, shown while you are tuned in, even with the
-- radio panel closed. Players can switch their own copy off with the command below, and move it by dragging while the radio panel is open (remembered on their computer).
Config.Hud = {
    Enabled = true,
    Command = 'radiohud', -- '' = no command
    Names   = 'character', -- 'character' (first name + last initial), 'callsign' (rsg-core callsign, falls back to character) or 'id'
    MaxRows = 8,           -- members shown at once (people speaking are shown first)
    Left    = 18,          -- default position: pixels from the left edge (top left of the screen)
    Top     = 18,          -- default position: pixels from the top edge
    -- Players drag the HUD to move it while the radio panel is open; double-click it to put it back here (remembered)
}

-- Recently used frequencies kept per character (metadata). 0 = off.
Config.Recents = { Max = 8 }

-- Leave the radio automatically while the player is downed, cuffed or hogtied. They cannot tune in until it ends.
-- Rejoin = true puts them back on their channel once they recover (if they still have the radio and access).
Config.Incapacitated = { Dead = true, Cuffed = true, Hogtied = true, Rejoin = false }

-- Battery: the charge lives in the radio item (info.battery, 0-100). A flat radio cannot connect.
-- Enabling it makes the radio item unique so every radio keeps its own charge. Players recharge with ChargeItem.
Config.Battery = {
    Enabled = false,
    DrainInterval = 60,           -- seconds between battery updates while tuned in
    DrainPerMinute = 0.5,         -- % lost per minute while tuned in
    TransmitDrainPerMinute = 4.0, -- extra % lost per minute spent transmitting
    LowWarning = 20,              -- notify once when the charge falls to this % or lower
    ChargeItem = 'radio_battery', -- using it with a radio in the inventory recharges that radio
    ChargeAmount = 100,           -- % restored per battery
    ChargeItemDefinition = {
        label = 'Radio Battery', weight = 100, type = 'item', image = 'radio_battery.png', unique = false,
        useable = true, shouldClose = true, description = 'A fresh battery pack for a field radio', category = 'tools',
    },
}

-- Signal interference: dead zones and weak spots. Inside a zone your radio signal drops:
-- 1.0 = clear, 0.0 = no signal. At 0.0 you cannot transmit and hear nothing; in between you hear the channel quieter,
-- with more static. Needs rsg-voice 3.2.0+. Add your own zones (mine shafts, canyons, towns with bad reception...).
-- `signal` is the quality at the centre; with `falloff = true` it rises smoothly to 1.0 at the edge of the radius.
Config.Interference = {
    Enabled = false,
    Zones = {
        -- { label = 'Mine shaft', coords = vector3(0.0, 0.0, 0.0), radius = 150.0, signal = 0.0, falloff = true },
    },
}

-- Radio volume slider and mute button in the panel (saved per character). Default is the volume a character starts
-- with, in percent (0-100); Step is the slider step. Lower Default if the radio is too loud out of the box.
-- TestCommand: chat command that plays a simulated incoming transmission at your volume ('' = no command; the panel button stays)
Config.Volume = { Default = 50, Step = 5, Bleep = true, TestCommand = 'radiotest' } -- Bleep: short tone at the chosen volume while the slider moves

-- Handheld radio: while the player transmits they hold a prop and play an animation, which nearby players can see.
-- RDR2 has no radio model or radio animation. Set `Model` to a prop to hold one (megaphone p_cs_megaphone01x is the closest);
-- Offset and Rotation are relative to Bone and have NOT been tuned: set Enabled = true, then adjust them in game
-- (restart rsg-radio after each change). Any prop, bone, dict and clip works; leave Model nil for animation only.
-- `flag` is the TaskPlayAnim flag (31 = upper body loop, like rsg-smoking). Nothing shows on a horse, in a wagon, while
-- dead, ragdolling, swimming, climbing or falling.
Config.Handheld = {
    Enabled  = false,
    -- No animation and no prop by default (RDR2 has no radio animation). To try the nearest vanilla clip, a hand-to-neck gesture,
    -- fill Anim and AnimFemale with the commented lines below. Flag 18 = upper body, plays once and holds the last frame.
    Model    = nil, -- no prop. For a prop use e.g. 'p_cs_megaphone01x' with Bone/Offset/Rotation below
    Bone     = 'SKEL_R_Finger00',
    Offset   = vector3(0.0, 0.0, 0.0),
    Rotation = vector3(0.0, 0.0, 0.0),
    Anim       = nil, -- { dict = 'amb_wander@code_human_wander@male@generic',   clip = 'rub_neck_01', flag = 18 }
    AnimFemale = nil, -- { dict = 'amb_wander@code_human_wander@female@generic', clip = 'rub_neck_01', flag = 18 }; nil = use Anim
    -- Other options: male rub_neck_02 / rub_neck_03, 'ai_gestures@gen_male@standing@silent' clip 'aknwoledge_timid_neck_scratch_r_001',
    -- female 'scratch_ear_02'. Megaphone with prop: dict 'script_mp@moonshiner@story_missions@moon1@ig4_megaphone', clip 'idle_hixon', flag 31.
    OnMount  = false,
}
