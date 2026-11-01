Config = {}

-- Snake peds that can inflict poison on bite
Config.Snakes = {
    { model = 'a_c_snakeblacktailrattle_01' },
    { model = 'a_c_snakeferdelance_01' },
    { model = 'a_c_snake_01' },
    { model = 'a_c_snakeredboa_01' },
}

-- Ammo types that inflict poison on hit
Config.PoisonAmmo = {
    'AMMO_THROWING_KNIVES_POISON',
    'AMMO_ARROW_POISON',
}

-- Weapons that inflict poison on hit directly (no separate poison ammo type)
Config.PoisonWeapons = {
    'WEAPON_THROWN_POISONBOTTLE',
}

-- How often (ms) the poison drains health while untreated
Config.PoisonTickInterval = 10000 -- ms

-- Health drained on each poison tick while poisoned and not cured.
Config.PoisonHealthDrainBase = 5 -- health removed per tick
