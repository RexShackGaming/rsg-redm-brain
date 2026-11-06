Config = {}

-- Prop models (both confirmed in rdr3_discoveries objects/object_list.lua)
Config.Models = {
    { value = 's_phonewall01x',    label = locale('model_wall') },
    { value = 'p_phoneantique01x', label = locale('model_desk') },
}

Config.SpawnDistance   = 75.0   -- props stream in/out around the player
Config.UseDistance     = 2.0    -- rsg-target interaction distance
Config.PlaceDistance   = 6.0    -- rsg-gizmo placement range

-- Create / upgrade the database table automatically on start.
-- Set to false and import installation/install.sql yourself if you prefer.
Config.AutoDatabase    = true

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
    DefaultTarget = 0,     -- target restored after the call (0 = normal proximity; rsg-voice/saltychat setups use 1)
    KeepProximity = true,  -- people standing next to you still hear you while you're on the phone
    Volume        = 1.0,   -- volume of the person on the other end (0.0-1.0), ignores distance
    Refresh       = 1000,  -- ms; re-applies the line in case another script resets the voice target
}

-- Who can place / remove phones (rsg-core permission)
Config.AdminPermission = 'admin'

-- The directory lists every placed phone that has "Show in directory" ticked.
-- Admins can hide / show entries from the directory tab on any phone.

-----------------------------------------------------------------------
-- Configuration guards
-----------------------------------------------------------------------
-- These keep a bad config value from breaking the whole resource at runtime.
local function numberOr(value, fallback)
    local number = tonumber(value)
    return number ~= nil and number == number and number ~= math.huge and number ~= -math.huge and number or fallback
end

Config.SpawnDistance   = math.max(1.0, numberOr(Config.SpawnDistance, 75.0))
Config.UseDistance     = math.max(0.5, numberOr(Config.UseDistance, 2.0))
Config.PlaceDistance   = math.max(1.0, numberOr(Config.PlaceDistance, 6.0))
Config.MaxCallDistance = math.max(0.5, numberOr(Config.MaxCallDistance, 3.0))
Config.RingDistance    = math.max(1.0, numberOr(Config.RingDistance, 25.0))
Config.RingTimeout     = math.max(1, math.floor(numberOr(Config.RingTimeout, 30)))
Config.MaxCallLength   = math.max(0, math.floor(numberOr(Config.MaxCallLength, 600)))
Config.CallCooldown    = math.max(0, math.floor(numberOr(Config.CallCooldown, 5)))
Config.NumberLength    = math.max(2, math.min(16, math.floor(numberOr(Config.NumberLength, 4))))
Config.Item.MaxPerPlayer = math.max(1, math.floor(numberOr(Config.Item.MaxPerPlayer, 2)))

Config.Payphone.CostPerMinute = math.max(0, numberOr(Config.Payphone.CostPerMinute, 0.10))
-- a positive price below one cent would round down to a free call
if Config.Payphone.CostPerMinute > 0 and Config.Payphone.CostPerMinute < 0.01 then
    Config.Payphone.CostPerMinute = 0.01
end
Config.Payphone.MaxDeposit    = math.max(0, numberOr(Config.Payphone.MaxDeposit, 5.00))
if Config.Payphone.CostPerMinute > 0 then
    -- a deposit cap below one minute would make every payphone call impossible
    Config.Payphone.MaxDeposit = math.max(Config.Payphone.MaxDeposit, Config.Payphone.CostPerMinute)
end
Config.Payphone.WarnSeconds   = math.max(0, math.floor(numberOr(Config.Payphone.WarnSeconds, 15)))

-- keep only usable coin values; a bad list would leave the payphone screen without coins
local coins = {}
for _, value in ipairs(Config.Payphone.Coins or {}) do
    local coin = numberOr(value, 0)
    if coin > 0 then coins[#coins + 1] = coin end
end
if #coins == 0 then coins = { 0.05, 0.10, 0.25, 1.00 } end
Config.Payphone.Coins = coins

Config.Blip.Scale = math.max(0.01, numberOr(Config.Blip.Scale, 0.2))
Config.Voice.Target       = math.max(1, math.min(30, math.floor(numberOr(Config.Voice.Target, 4))))
Config.Voice.DefaultTarget = math.max(0, math.min(30, math.floor(numberOr(Config.Voice.DefaultTarget, 0))))
Config.Voice.Volume       = math.max(0.0, math.min(1.0, numberOr(Config.Voice.Volume, 1.0)))
Config.Voice.Refresh      = math.max(250, math.floor(numberOr(Config.Voice.Refresh, 1000)))

local validMoneyType = { cash = true, bank = true, gold = true, bloodmoney = true }
if not validMoneyType[Config.Payphone.MoneyType] then
    Config.Payphone.MoneyType = 'cash'
end
