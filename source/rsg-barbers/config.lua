Config = {}

---------------------------------
-- general
---------------------------------
Config.Debug         = false
Config.BarberCost    = 5        -- default price (cash) for a new style; a location can override with `price`
Config.UseTarget     = true     -- true = rsg-target on the barber NPC, false = rsg-core prompt at `coords`
Config.Key           = 'J'      -- prompt key when Config.UseTarget = false
Config.MaxDistance   = 3.0      -- max distance (server checked) from the chair when paying
Config.Cooldown      = 3        -- seconds between purchase attempts per player
Config.MenuAlign     = 'right'   -- NUI panel side: 'right' or 'left'

---------------------------------
-- npc / blip
---------------------------------
Config.DistanceSpawn = 20.0     -- spawn/despawn distance for barber NPCs
Config.FadeIn        = true
Config.BlipSprite    = -2090472724
Config.BlipScale     = 0.2

---------------------------------
-- makeup sliders (also used by the server to validate values)
---------------------------------
Config.Makeup = {
    { key = 'beardstabble_t',  label = 'stubble_type',      min = 0, max = 1,   default = 0, maleOnly = true },
    { key = 'beardstabble_op', label = 'opacity',           min = 0, max = 100, default = 0, hop = 10, maleOnly = true },
    { key = 'shadows_t',       label = 'shadow_type',       min = 1, max = 5,   default = 1 },
    { key = 'shadows_op',      label = 'opacity',           min = 0, max = 100, default = 0, hop = 5 },
    { key = 'shadows_id',      label = 'shadow_color',      min = 1, max = 25,  default = 1 },
    { key = 'shadows_c1',      label = 'shadow_tone',       min = 0, max = 64,  default = 0 },
    { key = 'blush_t',         label = 'blush_type',        min = 1, max = 4,   default = 1 },
    { key = 'blush_op',        label = 'opacity',           min = 0, max = 100, default = 0, hop = 5 },
    { key = 'blush_id',        label = 'blush_color',       min = 1, max = 25,  default = 1 },
    { key = 'blush_c1',        label = 'blush_tone',        min = 0, max = 64,  default = 0 },
    { key = 'lipsticks_t',     label = 'lipstick_type',     min = 1, max = 7,   default = 1 },
    { key = 'lipsticks_op',    label = 'opacity',           min = 0, max = 100, default = 0, hop = 5 },
    { key = 'lipsticks_id',    label = 'lipstick_color',    min = 1, max = 25,  default = 1 },
    { key = 'lipsticks_c1',    label = 'lipstick_primary',  min = 0, max = 64,  default = 0 },
    { key = 'lipsticks_c2',    label = 'lipstick_secondary',min = 0, max = 64,  default = 0 },
    { key = 'eyeliners_t',     label = 'eyeliner_type',     min = 1, max = 15,  default = 1 },
    { key = 'eyeliners_op',    label = 'opacity',           min = 0, max = 100, default = 0, hop = 5 },
    { key = 'eyeliners_id',    label = 'eyeliner_color',    min = 1, max = 25,  default = 1 },
    { key = 'eyeliners_c1',    label = 'eyeliner_tone',     min = 0, max = 64,  default = 0 },
}

---------------------------------
-- locations
---------------------------------
Config.BarberLocations = {
    {
        name      = 'Valentine',
        barberid  = 'val-barber',
        npcmodel  = `s_m_m_barber_01`,
        npccoords = vector4(-307.96, 814.16, 118.99, 190.93),
        coords    = vector3(-307.96, 814.16, 118.99),
        seat      = vector4(-306.62, 813.56, 118.75, 90.60),
        camPos    = vector3(-307.35, 813.45, 119.61),
        camRot    = vector3(-18.29, 0.0, -79.42),
        lighting  = vector3(-307.39, 813.43, 119.51),
        showblip  = true,
        -- price  = 5,
    },
    {
        name      = 'Saint Denis',
        barberid  = 'std-barber',
        npcmodel  = `s_m_m_barber_01`,
        npccoords = vector4(2656.16, -1180.87, 53.28, 176.33),
        coords    = vector3(2656.16, -1180.87, 53.28),
        seat      = vector4(2655.38, -1180.92, 53.00, 182.8),
        camPos    = vector3(2655.38, -1181.69, 53.87),
        camRot    = vector3(-16.55, 0.0, 2.01),
        lighting  = vector3(2655.35, -1182.23, 54.07),
        showblip  = true,
    },
    {
        name      = 'Blackwater',
        barberid  = 'blk-barber',
        npcmodel  = `s_m_m_barber_01`,
        npccoords = vector4(-815.88, -1364.72, 43.75, 268.01),
        coords    = vector3(-815.88, -1364.72, 43.75),
        seat      = vector4(-815.17, -1368.75, 43.50, 95.5),
        camPos    = vector3(-816.06, -1368.76, 44.26),
        camRot    = vector3(-10.98, 0.0, -88.66),
        lighting  = vector3(-816.46, -1368.77, 44.26),
        showblip  = true,
    },
}
