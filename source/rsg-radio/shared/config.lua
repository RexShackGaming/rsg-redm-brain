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

-- Shown in the hint. Must match rsg-voice's Config.Radio.TalkKey.
Config.TransmitKeyLabel = 'O'

-- While the radio is open, block game controls but allow push-to-talk and the radio transmit key.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK (N)
}
