Config = {}

Config.locale = "en"
Config.keyToOpen = "U"
Config.keyToOpenBroadcast = "G"
Config.locations = {
    { label = "Valentine",   coords = vector4(-177.9952, 628.0817, 114.0896, 145.8196) },
    { label = "Blackwater",  coords = vector4(-875.0, -1329.27, 43.96, 90.0) },
    { label = "Strawberry",  coords = vector4(-1765.18, -384.21, 157.74, 180.0) },
    { label = "Rhodes",      coords = vector4(1289.91, -1300.89, 77.04, 180.0) },
    { label = "Saint Denis", coords = vector4(2747.23, -1394.92, 46.23, 180.0) },
    { label = "Emerald",     coords = vector4(1522.05, 438.76, 90.68, 180.0) },
    { label = "Van Horn",    coords = vector4(2985.92, 568.21, 44.63, 180.0) },
    { label = "Annesburg",   coords = vector4(2931.48, 1283.01, 44.65, 180.0) },
    { label = "Big Valley",  coords = vector4(-1301.32, 398.5, 95.43, 180.0) },
    { label = "Riggs Station", coords = vector4(-1094.42, -574.89, 82.41, 180.0) },
    { label = "Armadillo",   coords = vector4(-3729.17, -2603.31, -12.94, 180.0) },
    { label = "Rio Bravo",   coords = vector4(-5227.21, -3471.09, -20.55, 180.0) }
}

Config.NpcModel = "U_M_M_BIVFOREMAN_01"

Config.BlipName = "Mail Box"

Config.TimeBetweenUsersRefresh = -1 -- Time spent before server fetch all users from database another time. In Seconds. If value is negative or 0, users are only fetched once at server start and never again
Config.DelayBetweenTwoMessage = 600 -- Time spent before user is allowed to send a message another time. In Seconds. If value is negative or 0, no delay is set
Config.DelayBetweenTwoBroadcast = 600 -- Time spent before user is allowed to send a broadcast another time. In Seconds. If value is negative or 0, no delay is set
Config.MessageSendPrice = 10 -- Telegram price
Config.MessageBroadcastPrice = 3 -- How much should players pay to brodcast a message to everyone 

Keys = {
    ["G"] = 0x760A9C6F,
    ["Q"] = 0xDE794E3E,
    ["U"] = 0xD8F73058,
}