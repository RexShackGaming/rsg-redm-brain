Config = {}

Config.Debug = false

--------------------------------------------------------------------------------
-- Track. Only the Saint Denis loop is used, with ONE trolley on it.
-- Values from RDR3 decompiled medium_update.c (build 1491.50):
--   func_308  -> train config hash per ambient train index
--   func_1284 -> spawn coords, func_1285 -> direction
--   func_775  -> cruise speed 3.5, func_779 -> max speed 6.0 for trolleys
--   func_1287 -> trolleys stop for stations
-- Rockstar runs indexes 8/9/10 (AMBIENT_NBX_TROLLEY, _1, _2) on the same loop with the
-- same config; here that loop is a single track with a single trolley.
-- The upper (11) and inner (12) tracks are not used.
-- The key (loop) is the track id used by /trams.
--------------------------------------------------------------------------------
Config.Tracks = {
    loop  = { enabled = true, order = 1, config = -1083616881, coords = vector3(2608.538, -1203.883, 52.3572), direction = true  },
}

-- Car models that count as a trolley. If any of these exists anywhere, no new
-- trolley is spawned (only one trolley in the world at any time).
Config.TrolleyModels = { 'trolley01x' }

Config.AdminPermission = 'admin' -- rsg-core permission for /trams

Config.CruiseSpeed     = 3.5   -- func_775
Config.MaxSpeed        = 6.0   -- func_779
Config.StopForStations = true  -- func_1287
Config.Passengers      = true  -- ambient passengers in the car
Config.Conductor       = true  -- driver/conductor ped
Config.Invincible      = true  -- stop players wrecking the network

Config.Blip         = true
Config.BlipSprite   = `blip_ambient_train`
Config.BlipModifier = `BLIP_MODIFIER_MP_COLOR_32`

-- Force each car's audio game object on every client (fixes silent trolleys)
Config.Audio = {
    enabled = true,
    models  = { 'trolley01x' },
}

-- Conductor announcements (medium_update func_773/func_1278)
Config.Announce      = true
Config.AnnounceRange = 25.0

-- Brake for living people, horses, carts and stray trolleys on the rails ahead; move off again once clear.
Config.Avoid = {
    enabled       = true,
    distance      = 15.0, -- metres ahead of the front to look
    width         = 2.0,  -- metres either side of the rails
    interval      = 250,  -- ms between checks while a client owns a trolley
    clearNpcAfter = 6,    -- seconds, then NPC peds/carts in the way are removed (false = never)
    maxWait       = 15,   -- seconds, then the trolley moves off anyway (false = wait forever)
    pushTime      = 8,    -- seconds it ignores obstacles after pushing through
    stopGap       = 3.0,  -- metres short of the obstacle it comes to rest
    brake         = 1.5,  -- m/s²
    accel         = 0.8,  -- m/s²
}

Config.SpawnClearance    = 40.0  -- wait to spawn until no trolley is this close to the spawn point
Config.HostCheckInterval = 10000 -- ms between server health checks
Config.DriverlessChecks  = 2     -- checks in a row without a living driver before replacing the trolley
Config.SpawnTimeout      = 60000 -- ms before an unanswered spawn request is retried
