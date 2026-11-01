Config = Config or {}

---------------------------------------------------------------------
-- Brick export: a buyer NPC who pays for weed_brick on a demand market
---------------------------------------------------------------------
Config.Export = {
    Enabled  = true,
    MinLevel = 5,          -- drug XP level needed (5 = Distributor, 6 = Kingpin)
    Item     = 'weed_brick',
    MoneyType = 'cash',    -- 'cash' or 'bloodmoney'

    NPC = {
        -- default: Van Horn (from rsg-shops 'gen-vanhorn'). That is the store keeper's spot, MOVE THIS to a quiet dock/back alley.
        coords   = vector4(900.91, -1793.82, 43.08, 324.51),
        model    = `g_m_m_unicriminals_01`,
        spawnDistance  = 50.0,
        targetDistance = 2.5,
        interactDistance = 4.0, -- server-side check
    },

    -- price per brick = MaxPrice at an empty market, sliding down to MinPrice at Saturation bricks held
    MaxPrice   = 3000,
    MinPrice   = 800,
    Saturation = 40,       -- bricks in the buyer's stock that count as "flooded"
    Curve      = 1.4,      -- >1 = price holds up early then drops faster as it floods

    -- the buyer moves product on over time (market recovers)
    TickMinutes   = 5,     -- market update interval
    DrainPerHour  = 6,     -- bricks the buyer offloads per hour (randomised +-30%)

    -- demand drifts slowly (random walk) to make prices feel alive
    DemandMin  = 0.80,
    DemandMax  = 1.20,
    DemandStep = 0.04,     -- max change per market tick

    MaxPerSale = 10,       -- bricks per transaction
    Cooldown   = 10,       -- seconds between sales per player
    History    = 24,       -- price points kept for the trend chart (one per market tick)
}
