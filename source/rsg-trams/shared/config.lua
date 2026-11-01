Config = {}

Config.Debug = false

--------------------------------------------------------------------------------
-- Trolley lines. All values from RDR3 decompiled medium_update.c (build 1491.50):
--   func_308  -> train config hash per ambient train index (8..12)
--   func_1284 -> spawn coords, func_1285 -> direction
--   func_775  -> cruise speed 3.5, func_779 -> max speed 6.0 for trolleys
--   func_1287 -> trolleys stop for stations
-- Rockstar index names (func_1283): 8 AMBIENT_NBX_TROLLEY, 9 _1, 10 _2,
-- 11 AMBIENT_NBX_TROLLEY_UPPER, 12 AMBIENT_NBX_TROLLEY_INNER
--------------------------------------------------------------------------------
Config.Lines = {
    { name = 'nbx_trolley',       enabled = true,  config = -1083616881, coords = vector3(2608.538, -1203.883, 52.3572), direction = true  },
    { name = 'nbx_trolley_1',     enabled = true,  config = -1083616881, coords = vector3(2797.85,  -1184.51,  46.2297), direction = true  },
    { name = 'nbx_trolley_2',     enabled = true,  config = -1083616881, coords = vector3(2760.354, -1369.4,   45.4277), direction = true  },
    { name = 'nbx_trolley_upper', enabled = true,  config = 1936859429,  coords = vector3(2496.795, -1190.73,  48.3086), direction = false, callOutOnly = true },
    { name = 'nbx_trolley_inner', enabled = true,  config = -272646696,  coords = vector3(2496.795, -1190.73,  48.3086), direction = true  },
}
-- Rockstar runs lines 8/9/10 on the same loop (three trolleys spaced out).
-- Enable more lines if your server can handle the extra networked entities.

-- How many trolleys run at once (default; admins change it in-game with /trams <number>,
-- which is saved and overrides this). nil = every enabled line.
Config.MaxTrams   = nil
Config.AdminGroup = 'group.admin' -- ace group allowed to use /trams

Config.CruiseSpeed     = 3.5   -- func_775
Config.MaxSpeed        = 6.0   -- func_779 (_0x615B3B8E73634509 on trolley tracks)
Config.StopForStations = true  -- func_1287
Config.Passengers      = true  -- ambient passengers in the car
Config.Conductor       = true  -- driver/conductor ped
Config.Invincible      = true  -- stop players wrecking the network
Config.Blip            = true

-- Trolley sound: force each car's audio game object on every client (fixes silent
-- trolleys). Add car model names here if a trolley config uses other models.
Config.Audio = {
    enabled = true,
    models  = { 'trolley01x' },
}
Config.BlipSprite      = `blip_ambient_train` -- confirm in rdr3_discoveries useful_info_from_rpfs/blip_textures
Config.BlipModifier    = `BLIP_MODIFIER_MP_COLOR_32`

-- Conductor announcements (medium_update func_773/func_1278). Stations come from
-- GET_CURRENT_STATION_FOR_TRAIN, so no stop coords are needed.
Config.Announce = true
Config.AnnounceRange = 25.0

Config.TrafficGap      = 30.0 -- a trolley stops if another is this close ahead (following / at a stop)
-- Obstacle avoidance: the trolley brakes for living people, horses and carts on the
-- rails ahead and moves off again once the way is clear.
Config.Avoid = {
    enabled  = true,
    distance = 15.0, -- metres ahead of the trolley's front to look
    width    = 2.0,  -- metres either side of the rails' centre line
    interval = 250,  -- ms between checks while a client owns a trolley
    clearNpcAfter = 6,  -- seconds: then NPC peds/carts in the way are removed (false = never)
    maxWait  = 15,   -- seconds: then the trolley moves off whatever is ahead (false = wait forever)
    pushTime = 8,    -- seconds it ignores obstacles after pushing through
    stopGap  = 3.0,  -- metres short of the obstacle the trolley comes to rest
    brake    = 1.5,  -- m/s² braking (lower = gentler)
    accel    = 0.8,  -- m/s² pulling away again
}
Config.SpawnClearance  = 40.0 -- wait to spawn a line until no trolley is this close to its spawn point

Config.HostCheckInterval = 10000 -- ms between host health checks
Config.DriverlessChecks  = 2     -- health checks in a row without a living driver before the trolley is replaced
