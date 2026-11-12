-- All gun-store prices live here. Dollar amounts, NOT cents. Server-only.
-- Historical-based defaults: Cattleman $12 and pump shotgun $16.88 follow the
-- 1898 Sears offers. Other prices are gameplay estimates, not verified period quotes.
-- Change price to false to remove an offer. Keep established item keys unchanged.
-- Ammo price is for ONE BOX; rounds is delivered as existing loose-round items.
-- Changes apply at the next coordinated startup; use the documented safe-stop flow.
WeaponStoreConfig = {
    enabled = true,
    currency = 'dollars',
    maximumBoxes = 2, -- additionally capped at 100 delivered items per checkout
    stores = {
        {
            id = '73000000-0000-4000-8000-000000000001',
            label = 'Valentine Gun Store',
            organization = { key = 'valentine_gun_store', legalName = 'Valentine Gun Store Company', displayName = 'Valentine Gun Store' },
            position = { x = -281.2, y = 780.5, z = 119.5 },
            heading = 0.0
        }
    },
    weapons = {
        pistol_volcanic = 15.00,
        pistol_m1899 = 30.00,
        pistol_semiauto = 30.00,
        pistol_mauser = 35.00,
        revolver_cattleman = 12.00,
        revolver_schofield = 13.00,
        revolver_doubleaction = 12.00,
        revolver_lemat = 25.00,
        revolver_navy = 15.00,
        repeater_carbine = 12.00,
        repeater_lancaster = 12.00,
        repeater_henry = 15.00,
        repeater_evans = 20.00,
        rifle_springfield = 10.00,
        rifle_boltaction = 20.00,
        rifle_varmint = 5.00,
        rifle_rollingblock = 20.00,
        rifle_carcano = 25.00,
        rifle_elephant = 50.00,
        shotgun_doublebarrel = 12.00,
        shotgun_sawedoff = 10.00,
        shotgun_pump = 16.88,
        shotgun_semiauto = 35.00,
        shotgun_repeating = 20.00,
        utility_lasso = false,               -- no canonical Shops issuance support yet
        utility_davy_lantern = false,        -- no canonical Shops issuance support yet
        utility_binoculars = false,          -- no canonical Shops issuance support yet
        utility_binoculars_improved = false, -- no canonical Shops issuance support yet
        utility_metal_detector = false,      -- no canonical Shops issuance support yet
        utility_fishing_rod = false,         -- no canonical Shops issuance support yet
        utility_camera = false,              -- no canonical Shops issuance support yet
        utility_camera_advanced = false,     -- no canonical Shops issuance support yet
        utility_lasso_reinforced = false,    -- no canonical Shops issuance support yet
        melee_knife = false,                 -- no canonical Shops issuance support yet
        melee_machete = false,               -- no canonical Shops issuance support yet
        melee_hammer = false,                -- no canonical Shops issuance support yet
        melee_cleaver = false,               -- no canonical Shops issuance support yet
        melee_hatchet = false,               -- no canonical Shops issuance support yet
        throwable_throwing_knives = false,   -- no canonical Shops issuance support yet
        throwable_tomahawk = false,          -- no canonical Shops issuance support yet
        throwable_tomahawk_ancient = false,  -- no canonical Shops issuance support yet
        throwable_bolas = false,             -- no canonical Shops issuance support yet
        throwable_bolas_hawkmoth = false,    -- no canonical Shops issuance support yet
        throwable_bolas_ironspiked = false,  -- no canonical Shops issuance support yet
        throwable_bolas_intertwined = false, -- no canonical Shops issuance support yet
        throwable_dynamite = false,          -- no canonical Shops issuance support yet
        throwable_molotov = false,           -- no canonical Shops issuance support yet
        throwable_poisonbottle = false,      -- no canonical Shops issuance support yet
        bow = false,                         -- no canonical Shops issuance support yet
    },
    ammunition = {
        -- Representative period pack sizes. Specialty prices are gameplay estimates.
        ammo_rifle_elephant = { price = 3.00, rounds = 20 },
        ammo_pistol_regular = { price = 0.80, rounds = 50 },
        ammo_pistol_express = { price = 1.20, rounds = 50 },
        ammo_pistol_high_velocity = { price = 1.20, rounds = 50 },
        ammo_pistol_split_point = { price = 1.00, rounds = 50 },
        ammo_pistol_explosive = { price = 4.00, rounds = 50 },
        ammo_revolver_regular = { price = 0.80, rounds = 50 },
        ammo_revolver_express = { price = 1.20, rounds = 50 },
        ammo_revolver_high_velocity = { price = 1.20, rounds = 50 },
        ammo_revolver_split_point = { price = 1.00, rounds = 50 },
        ammo_revolver_explosive = { price = 4.00, rounds = 50 },
        ammo_repeater_regular = { price = 0.70, rounds = 50 },
        ammo_repeater_express = { price = 1.05, rounds = 50 },
        ammo_repeater_high_velocity = { price = 1.05, rounds = 50 },
        ammo_repeater_split_point = { price = 0.88, rounds = 50 },
        ammo_repeater_explosive = { price = 3.50, rounds = 50 },
        ammo_rifle_regular = { price = 0.70, rounds = 20 },
        ammo_rifle_express = { price = 1.05, rounds = 20 },
        ammo_rifle_high_velocity = { price = 1.05, rounds = 20 },
        ammo_rifle_split_point = { price = 0.88, rounds = 20 },
        ammo_rifle_explosive = { price = 3.50, rounds = 20 },
        ammo_shotgun_regular = { price = 0.50, rounds = 25 },
        ammo_shotgun_slug = { price = 0.75, rounds = 25 },
        ammo_shotgun_buckshot_incendiary = { price = 1.50, rounds = 25 },
        ammo_shotgun_slug_explosive = { price = 2.50, rounds = 25 },
        ammo_varmint = { price = 0.14, rounds = 50 },
        ammo_varmint_tranquilizer = { price = 3.00, rounds = 50 },
        ammo_arrow_regular = { price = 0.50, rounds = 5 },
        ammo_arrow_small_game = { price = 0.50, rounds = 5 },
        ammo_arrow_poison = { price = 1.50, rounds = 5 },
        ammo_arrow_fire = { price = 1.50, rounds = 5 },
        ammo_arrow_dynamite = { price = 2.50, rounds = 5 },
        ammo_throwing_knives_regular = { price = 1.00, rounds = 1 },
        ammo_throwing_knives_poison = { price = 3.00, rounds = 1 },
        ammo_tomahawk_regular = { price = 1.00, rounds = 1 },
        ammo_bolas_regular = { price = 1.00, rounds = 1 },
        ammo_bolas_hawkmoth = { price = 1.00, rounds = 1 },
        ammo_bolas_ironspiked = { price = 1.00, rounds = 1 },
        ammo_bolas_intertwined = { price = 1.00, rounds = 1 },
        ammo_dynamite = { price = 5.00, rounds = 1 },
        ammo_molotov = { price = 1.00, rounds = 1 },
        ammo_poisonbottle = { price = 3.00, rounds = 1 },
        ammo_tomahawk_ancient = { price = 1.00, rounds = 1 },
    },
    attachments = {
        -- Individual component prices; gameplay estimates.
        cattleman_long_barrel = 2.00,
        cattleman_wide_sight = 1.00,
        schofield_short_barrel = 2.00,
        schofield_wide_sight = 1.00,
        lemat_long_barrel = 2.00,
        lemat_wide_sight = 1.00,
        navy_long_barrel = 2.00,
        navy_wide_sight = 1.00,
        doubleaction_long_barrel = 2.00,
        doubleaction_wide_sight = 1.00,
        m1899_long_barrel = 2.00,
        m1899_wide_sight = 1.00,
        volcanic_long_barrel = 2.00,
        volcanic_wide_sight = 1.00,
        semiauto_long_barrel = 2.00,
        semiauto_wide_sight = 1.00,
        mauser_long_barrel = 2.00,
        mauser_wide_sight = 1.00,
        carbine_wide_sight = 1.00,
        lancaster_wide_sight = 1.00,
        litchfield_wide_sight = 1.00,
        evans_wide_sight = 1.00,
        springfield_wide_sight = 1.00,
        boltaction_wide_sight = 1.00,
        varmint_wide_sight = 1.00,
        elephant_long_barrel = 2.00,
        elephant_wide_sight = 1.00,
        rollingblock_wide_sight = 1.00,
        carcano_wide_sight = 1.00,
        repeating_shotgun_long_barrel = 2.00,
        repeating_shotgun_wide_sight = 1.00,
        pump_shotgun_long_barrel = 2.00,
        pump_shotgun_wide_sight = 1.00,
        semiauto_shotgun_long_barrel = 2.00,
        semiauto_shotgun_wide_sight = 1.00,
        doublebarrel_long_barrel = 2.00,
        doublebarrel_wide_sight = 1.00,
        sawedoff_wide_sight = 1.00,
    },
    gunOil = 0.25 -- per bottle; gameplay estimate
}
