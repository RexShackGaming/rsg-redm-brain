Config = {}

Config.UseTarget      = true             -- rsg-target option on other players
Config.Command        = 'trade'          -- /trade [id] (false to disable)
Config.AcceptCommand  = 'tradeaccept'    -- accept your trade request
Config.DeclineCommand = 'tradedecline'   -- decline your trade request

Config.Distance        = 3.0      -- metres: needed to send and accept a request
Config.CancelDistance  = 5.0      -- metres: an open trade is cancelled beyond this
Config.RequestTimeout  = 20       -- seconds a request stays open
Config.RequestCooldown = 5        -- seconds between requests from one player
Config.DeclineCooldown = 60       -- seconds before a declined player can ask the same person again
Config.TradeTimeout    = 300      -- seconds before an unfinished trade is cancelled
Config.LockSeconds     = 3        -- both ready: seconds before Confirm unlocks (time to check the offer)

Config.MaxOfferSlots = 12         -- most item stacks one player can offer
Config.AllowCash     = true       -- cash can be added to an offer
Config.MaxCash       = 100000     -- most cash (dollars) in one offer

-- Items that can never be traded. Cash items are always blocked (cash has its own field).
Config.BlacklistItems = {
    -- some_bound_item = true,
}
Config.BlacklistTypes = {
    -- weapon = true,
}

Config.ImagePath = 'nui://rsg-inventory/html/images/'

-- While the trade window is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
