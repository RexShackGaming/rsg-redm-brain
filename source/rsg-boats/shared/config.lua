Config = {}

Config.Debug = false

-- Boat yard
Config.Yard = {
    defaultName = 'Saint Denis Boat Yard', -- name of the first yard created on install
    coords   = vector4(886.66, -1778.01, 42.14, 283.27), -- first yard only; admins add/move yards in /boatadmin (saved to rsg_boats_yards)
    -- femga peds/peds_list.lua: 0x44BCB3C8 "a_m_m_sddockforeman_01"
    npcModel = 'a_m_m_sddockforeman_01',
    blip = {
        enabled = true,
        sprite  = 62421675,          -- femga textures/blips: blip_canoe
        style   = `BLIP_STYLE_SHOP`, -- femga blip_styles
    },
    targetDistance = 2.5,
    npcSpawnDistance = 60.0,
}

-- Fallback launch point if no admin has set one yet (offset in front of the NPC)
Config.FallbackSpawnOffset = vector3(0.0, 8.0, -1.0)

Config.MaxBoats       = 0     -- max boats one character can own (0 = unlimited)
Config.LockToYard     = true  -- boats can only be launched/sold at the yard they are stored at
Config.MoneyType      = 'cash'
Config.SellBackRate   = 0.5   -- 50% refund when selling a boat back
Config.ActionRadius   = 15.0  -- server: max distance from the yard to buy / launch / sell
Config.MaxPointDistance = 300.0 -- launch point / dock must be within this distance of their yard
Config.StoreRadius    = 60.0  -- shop 'Store Boat' button: boat must be this close to the yard

-- Dock / store zone (defaults to the yard NPC position; admins set position + radius per yard in /boatadmin)
Config.Dock = {
    radius      = 15.0,   -- default store radius around the dock
    minRadius   = 3.0,
    maxRadius   = 100.0,
    promptKey   = 0xD51B784F, -- E (femga Controls/README.md: INPUT_CONTEXT_Y, active InVehicle)
    holdTime    = 1000,   -- ms to hold the prompt
    showMarker  = true,   -- draw the store zone ring when your boat is nearby
    markerRange = 60.0,
}
Config.Cooldown       = 2000  -- ms between shop actions per player
Config.WarpIntoBoat   = true

-- Transfer ownership to another player (My Boats tab)
Config.Transfer = {
    enabled       = true,
    maxDistance   = 10.0, -- the other player must be this close
    requireAccept = true, -- the other player gets a popup to accept
    acceptTimeout = 20,   -- seconds to accept
}

-- Boat storage (rsg-inventory stash per owned boat; slots/weight set per model in /boatadmin)
Config.Storage = {
    enabled       = true,
    defaultSlots  = 10,
    defaultWeight = 50000,   -- grams (rsg-inventory units: player max is 35000)
    maxSlots      = 100,     -- admin panel limit
    maxWeight     = 1000000, -- admin panel limit (rsg-inventory Config.Stash.MaxWeight caps at 10000000)
    distance      = 3.0,     -- rsg-target distance to the boat
    showInBoat    = true,    -- opening your inventory while in your boat shows the boat storage in the right panel
}

-- Storage upgrades (bought per owned boat in My Boats > Upgrades; needs Config.Storage.enabled)
-- Each level adds on top of the model's own slots/weight. Weight is in grams. Totals are capped by Config.Storage.maxSlots / maxWeight.
Config.Upgrades = {
    enabled = true,
    slots = {
        { price = 150, add = 5 },
        { price = 300, add = 5 },
        { price = 600, add = 10 },
    },
    weight = {
        { price = 150, add = 25000 },
        { price = 300, add = 25000 },
        { price = 600, add = 50000 },
    },
}

-- Hire boats: a short rental from a yard. Models get a hire price in /boatadmin (0 = not for hire).
-- A hired boat has no storage, is not owned and is taken back when the time runs out.
Config.Rental = {
    enabled     = true,
    minutes     = 20,  -- hire time, starts when the boat is on the water
    warnSeconds = 60,  -- warning before the boat is taken back
}

-- Admin
Config.AdminCommand    = 'boatadmin'
Config.AdminPermission = 'admin'

-- Launch point placer (uses rsg-gizmo; controls are shown in its HUD)
Config.Placer = {
    startDistance = 8.0,   -- how far in front of the admin the ghost boat starts
    maxDistance   = 80.0,  -- ghost can't wander further than this from the admin
    alpha         = 150,
}

-- While a boat NUI is open, game controls are blocked but push-to-talk keeps working (rsg-voice)
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK
}

---------------------------------------------------------------------
-- database
---------------------------------------------------------------------
Config.AutoDatabase = true -- create/update tables automatically on resource start (set false to import install.sql manually)

-- boats added on first install only (rowboat: femga/rdr3_discoveries vehicles_list 0x9FD6BA58)
Config.DefaultBoats = {
    { model = 'rowboat', label = 'Rowboat', description = 'A sturdy wooden rowboat for rivers and bayous.', price = 75, rent = 10, slots = 10, weight = 50000 },
}
