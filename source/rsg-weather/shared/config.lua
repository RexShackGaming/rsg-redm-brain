Config = {}

---------------------------------
-- general
---------------------------------
Config.Debug          = false
Config.AdminPermissions = { 'god', 'admin' } -- RSGCore permission levels allowed to use admin commands / menu
Config.SyncDelay      = 5000           -- ms between server -> client syncs
Config.EnableLegacyNetEvents = true    -- accept old weathersync:* net events from clients (admin-checked)

---------------------------------
-- time
---------------------------------
-- seconds of a week (0-604799) or DHMSToTime(day, hour, minute, second), day 0 = Sunday
Config.Time          = DHMSToTime(0, 6, 0, 0)
-- in-game seconds per real second (30 = vanilla). 0 = use real server clock
Config.Timescale     = 4
Config.RealTimeOffset = 0              -- seconds, only used when Timescale = 0
Config.TimeIsFrozen  = false

---------------------------------
-- weather
---------------------------------
Config.Weather         = 'sunny'
Config.WeatherInterval = DHMSToTime(0, 1, 0, 0) -- in-game time between changes
Config.WeatherIsFrozen = false
Config.PermanentSnow   = false
Config.DynamicSnow     = true          -- snow on ground in snowy regions / snowy weather
Config.MaxForecast     = 23            -- number of intervals queued (23 = 24h forecast)
Config.RegionalWeather = true          -- translate weather per region (snow in north, sandstorm in desert...)

---------------------------------
-- wind
---------------------------------
Config.WindDirection      = 0.0
Config.WindSpeed          = 0.0
Config.WindIsFrozen       = false
Config.WindShearDirection = 45         -- degrees per interval of altitude
Config.WindShearSpeed     = 2.0        -- speed added per interval of height above ground
Config.WindShearInterval  = 50.0       -- metres
Config.MeanSeaLevel       = 40.0

---------------------------------
-- weather pattern (each block must add up to 100)
---------------------------------
Config.WeatherPattern = {
    sunny        = { sunny = 85, clouds = 15 },
    clouds       = { clouds = 20, sunny = 70, misty = 3, fog = 2, overcastdark = 5 },
    overcastdark = { overcastdark = 5, clouds = 70, sunny = 15, overcast = 5, thunder = 5 },
    misty        = { misty = 10, clouds = 20, sunny = 60, fog = 10 },
    fog          = { fog = 10, clouds = 20, sunny = 50, misty = 10, overcast = 10 },
    overcast     = { overcast = 5, clouds = 45, overcastdark = 20, drizzle = 15, shower = 5, rain = 10 },
    drizzle      = { drizzle = 5, overcast = 10, rain = 5, shower = 5, overcastdark = 15, clouds = 60 },
    rain         = { rain = 5, overcastdark = 30, clouds = 30, drizzle = 15, shower = 5, thunderstorm = 10, hurricane = 5 },
    thunder      = { thunder = 5, overcastdark = 25, clouds = 30, thunderstorm = 40 },
    thunderstorm = { thunderstorm = 5, thunder = 15, clouds = 40, rain = 20, drizzle = 10, shower = 10 },
    hurricane    = { hurricane = 5, rain = 30, drizzle = 65 },
    shower       = { shower = 5, clouds = 30, overcast = 15, overcastdark = 50 },
}

---------------------------------
-- legacy aliases (old weathersync config names, read by some 3rd party scripts)
---------------------------------
Config.isRDR          = true
Config.weatherTypes   = WeatherTypes
Config.weatherPattern = Config.WeatherPattern
Config.timescale      = Config.Timescale
Config.syncDelay      = Config.SyncDelay

---------------------------------
-- seasonal events (switch automatically by the server's real date)
---------------------------------
Config.Seasonal = {
    Enabled       = true,
    CheckInterval = 60,   -- seconds between real-date checks
    -- date ranges are inclusive and may wrap the year (e.g. Dec 28 -> Jan 2)
    Events = {
        halloween = {
            label         = 'Halloween',
            icon          = '🎃',
            start         = { month = 10, day = 15 },
            finish        = { month = 11, day = 1 },
            startWeather  = 'fog',
            permanentSnow = false,
            -- only weathers that have a blood-moon (_MP_Pred) variation in the game
            pattern = {
                fog          = { fog = 30, misty = 40, shower = 20, thunderstorm = 10 },
                misty        = { misty = 30, fog = 40, shower = 20, thunderstorm = 10 },
                shower       = { shower = 20, fog = 40, misty = 30, thunderstorm = 10 },
                thunderstorm = { thunderstorm = 20, fog = 40, misty = 30, shower = 10 },
            },
            -- blood moon: game weather variations applied during these in-game hours
            -- (set fromHour = 0, toHour = 24 for blood-moon weather all day)
            night = {
                fromHour   = 20,
                toHour     = 5,
                variations = {
                    fog          = 'Fog_MP_Pred',
                    misty        = 'MISTY_MP_Pred',
                    shower       = 'shower_MP_Pred',
                    thunderstorm = 'THUNDERSTORM_MP_Pred',
                },
            },
        },
        christmas = {
            label         = 'Christmas',
            icon          = '❄',
            start         = { month = 12, day = 01 },
            finish        = { month = 12, day = 27 },
            startWeather  = 'snow',
            permanentSnow = true,               -- snow on the ground everywhere
            pattern = {
                snow      = { snow = 40, snowlight = 40, blizzard = 10, clouds = 10 },
                snowlight = { snowlight = 40, snow = 40, clouds = 15, fog = 5 },
                blizzard  = { blizzard = 20, snow = 60, snowlight = 20 },
                clouds    = { clouds = 20, snowlight = 50, snow = 30 },
                fog       = { fog = 10, snowlight = 60, snow = 30 },
            },
            night = nil,
        },
    },
}
