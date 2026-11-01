Config = {}

-- Prop models (both confirmed in rdr3_discoveries objects/object_list.lua)
Config.Models = {
    { value = 's_phonewall01x',    label = 'Wall Telephone' },
    { value = 'p_phoneantique01x', label = 'Desk Telephone (antique)' },
}

Config.SpawnDistance   = 75.0   -- props stream in/out around the player
Config.UseDistance     = 2.0    -- ox_target distance

-- Payphones: phones with NO job restriction charge the caller per minute.
-- The caller inserts coins before dialling; the money is taken when the call is placed,
-- each minute is charged once the call is answered (first minute on answer) and any
-- unused credit is refunded when the call ends. Unanswered calls are fully refunded.
Config.Payphone = {
    Enabled       = true,
    MoneyType     = 'cash',
    CostPerMinute = 0.10,                 -- dollars
    MaxDeposit    = 5.00,                 -- most a caller can insert for one call
    Coins         = { 0.05, 0.10, 0.25, 1.00 }, -- coin buttons on the phone
    WarnSeconds   = 15,                   -- warn this long before credit runs out
}

-- Player-owned telephones: the usable item lets a player place their own phone.
-- Placing removes the item; the owner can pick it up again (item comes back with the phone's
-- number and settings stored on it) and re-place it anywhere with the same configuration.
Config.Item = {
    Enabled      = true,
    Name         = 'telephone',
    MaxPerPlayer = 2,      -- phones a character can have placed at the same time
    Payphone     = false,  -- false = player phones are free private lines
}

-- Map blip on every placed telephone (named after the phone's label)
Config.Blip = {
    Enabled = true,
    Sprite  = 'blip_ambient_telegraph',
    Scale   = 0.2,
}
Config.MaxCallDistance = 3.0    -- server: walk further than this from your phone and the call ends
Config.RingDistance    = 25.0   -- how far away other players can hear a phone ringing
Config.RingTimeout     = 30     -- seconds before an unanswered call gives up
Config.MaxCallLength   = 600    -- seconds, 0 = unlimited
Config.CallCooldown    = 5      -- seconds between dial attempts per player
Config.NumberLength    = 4      -- auto-generated numbers have this many digits

-- Built-in voice line (Mumble natives, no pma-voice)
Config.Voice = {
    Target        = 4,     -- Mumble voice target slot used while on a call (1-30, keep clear of other voice scripts)
    DefaultTarget = 0,     -- target restored after the call (0 = normal proximity; pma-voice/saltychat setups use 1)
    KeepProximity = true,  -- people standing next to you still hear you while you're on the phone
    Volume        = 1.0,   -- volume of the person on the other end (0.0-1.0), ignores distance
    Refresh       = 1000,  -- ms; re-applies the line in case another script resets the voice target
}

-- Who can place / remove phones (rsg-core permission)
Config.AdminPermission = 'admin'

-- The directory lists every placed phone that has "Show in directory" ticked.
-- Admins can hide / show entries from the directory tab on any phone.
