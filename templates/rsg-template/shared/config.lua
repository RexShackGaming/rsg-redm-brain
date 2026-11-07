Config = {}

Config.Debug = false

-- While NUI is open, block game controls but allow push-to-talk.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}
Config.InteractDistance = 3.0
Config.ShopCoords = vector3(-178.0, 627.0, 114.0) -- example (Valentine); replace
Config.Items = {
    -- [itemName] = { price = 1 },
}
