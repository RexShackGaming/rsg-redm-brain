Config = {}

Config.VersionCheck = true
Config.AutoDatabase = true        -- false: import install.sql manually

Config.Command = 'contracts'      -- opens the contract book anywhere (false to disable)

-- Delivering goods and collecting money/items only works at these offices.
-- Coordinates come from rsg-telegram/shared/config.lua (post offices).
Config.Offices = {
    { id = 'valentine',   label = 'Valentine',    coords = vector3(-178.90, 626.71, 114.09) },
    { id = 'rhodes',      label = 'Rhodes',       coords = vector3(1225.57, -1293.87, 76.91) },
    { id = 'saintdenis',  label = 'Saint Denis',  coords = vector3(2731.55, -1402.37, 46.18) },
    { id = 'blackwater',  label = 'Blackwater',   coords = vector3(-875.08, -1328.75, 43.96) },
    { id = 'strawberry',  label = 'Strawberry',   coords = vector3(-1765.07, -384.22, 157.74) },
    { id = 'annesburg',   label = 'Annesburg',    coords = vector3(2939.47, 1288.21, 44.65) },
    { id = 'tumbleweed',  label = 'Tumbleweed',   coords = vector3(-5487.28, -2936.25, -0.40) },
    { id = 'armadillo',   label = 'Armadillo',    coords = vector3(-3733.94, -2597.94, -12.93) },
}
Config.TargetRadius   = 1.5
Config.OfficeDistance = 4.0       -- metres, checked by the server
Config.SignDistance   = 5.0       -- metres between both players to send and sign an offer

Config.MinPay      = 1            -- dollars
Config.MaxPay      = 5000
Config.MaxDeposit  = 1000         -- optional deposit from the worker, 0 disables deposits
Config.MinHours    = 1            -- deadline in real hours (server downtime counts)
Config.MaxHours    = 168
Config.MaxQuantity = 500          -- most items in one supply order
Config.MaxOpen     = 5            -- open contracts a player can have written at once
Config.MaxTitle    = 60
Config.MaxDetails  = 500

Config.OfferHours   = 1           -- an unsigned offer expires after this
Config.ReviewHours  = 48          -- job marked done: the worker is paid if the buyer does nothing
Config.DisputeHours = 72          -- an undecided dispute is closed after this
-- what happens then: 'split' (half the payment each), 'worker' (worker paid), 'buyer' (buyer refunded)
-- the worker's deposit goes back to the worker with 'split' and 'worker'
Config.DisputeDefault = 'split'

-- who can decide disputes (must be on duty, and not part of the contract)
Config.ArbiterJobTypes = { leo = true }
Config.ArbiterJobs     = {}       -- e.g. { judge = true }

-- items that can never be ordered
Config.BlacklistItems = { dollar = true, cent = true, blood_dollar = true, blood_cent = true, contract_paper = true }
Config.BlacklistTypes = { weapon = true }

Config.PaperItem = 'contract_paper'  -- paper copy for both players when signed (false to disable)

-- optional rsg-reputation honor changes, 0 = off. Cheap contracts never give honor (anti-farming).
Config.HonorCompleted = 0
Config.HonorBroken    = -2        -- missed deadline, gave up, or lost a dispute
Config.HonorMinPay    = 25

-- While the window is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
