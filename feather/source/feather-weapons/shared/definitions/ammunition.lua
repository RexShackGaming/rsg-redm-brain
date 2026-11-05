WeaponDefinitionCatalog = WeaponDefinitionCatalog or {}

WeaponDefinitionCatalog.ammunition = {
    ammo_rifle_elephant = {
        id = "ammo_rifle_elephant",
        kind = "ammunition",
        itemName = "ammo_rifle_elephant",
        label = "Rifle Cartridges - Nitro Express",
        nativeAmmoName = "AMMO_RIFLE_ELEPHANT",
        maxTotal = 20,
        stackable = true,
        tags = { "rifle", "elephant", "purchase" }
    },
    ammo_pistol_regular = {
        id = "ammo_pistol_regular",
        kind = "ammunition",
        itemName = "ammo_pistol_regular",
        label = "Pistol Cartridges - Regular",
        nativeAmmoName = "AMMO_PISTOL",
        stackable = true,
        tags = { "pistol", "regular", "purchase" }
    },
    ammo_pistol_express = {
        id = "ammo_pistol_express",
        kind = "ammunition",
        itemName = "ammo_pistol_express",
        label = "Pistol Cartridges - Express",
        nativeAmmoName = "AMMO_PISTOL_EXPRESS",
        stackable = true,
        tags = { "pistol", "express", "purchase" }
    },
    ammo_pistol_high_velocity = {
        id = "ammo_pistol_high_velocity",
        kind = "ammunition",
        itemName = "ammo_pistol_high_velocity",
        label = "Pistol Cartridges - High Velocity",
        nativeAmmoName = "AMMO_PISTOL_HIGH_VELOCITY",
        stackable = true,
        tags = { "pistol", "high_velocity", "purchase" }
    },
    ammo_pistol_split_point = {
        id = "ammo_pistol_split_point",
        kind = "ammunition",
        itemName = "ammo_pistol_split_point",
        label = "Pistol Cartridges - Split Point",
        nativeAmmoName = "AMMO_PISTOL_SPLIT_POINT",
        stackable = true,
        tags = { "pistol", "split_point", "craft" }
    },
    ammo_pistol_explosive = {
        id = "ammo_pistol_explosive",
        kind = "ammunition",
        itemName = "ammo_pistol_explosive",
        label = "Pistol Cartridges - Explosive",
        nativeAmmoName = "AMMO_PISTOL_EXPRESS_EXPLOSIVE",
        maxTotal = 10,
        stackable = true,
        tags = { "pistol", "explosive", "craft" }
    },

    ammo_revolver_regular = {
        id = "ammo_revolver_regular",
        kind = "ammunition",
        itemName = "ammo_revolver_regular",
        label = "Revolver Cartridges - Regular",
        nativeAmmoName = "AMMO_REVOLVER",
        stackable = true,
        tags = { "revolver", "regular", "purchase" }
    },
    ammo_revolver_express = {
        id = "ammo_revolver_express",
        kind = "ammunition",
        itemName = "ammo_revolver_express",
        label = "Revolver Cartridges - Express",
        nativeAmmoName = "AMMO_REVOLVER_EXPRESS",
        stackable = true,
        tags = { "revolver", "express", "purchase" }
    },
    ammo_revolver_high_velocity = {
        id = "ammo_revolver_high_velocity",
        kind = "ammunition",
        itemName = "ammo_revolver_high_velocity",
        label = "Revolver Cartridges - High Velocity",
        nativeAmmoName = "AMMO_REVOLVER_HIGH_VELOCITY",
        stackable = true,
        tags = { "revolver", "high_velocity", "purchase" }
    },
    ammo_revolver_split_point = {
        id = "ammo_revolver_split_point",
        kind = "ammunition",
        itemName = "ammo_revolver_split_point",
        label = "Revolver Cartridges - Split Point",
        nativeAmmoName = "AMMO_REVOLVER_SPLIT_POINT",
        stackable = true,
        tags = { "revolver", "split_point", "craft" }
    },
    ammo_revolver_explosive = {
        id = "ammo_revolver_explosive",
        kind = "ammunition",
        itemName = "ammo_revolver_explosive",
        label = "Revolver Cartridges - Explosive",
        nativeAmmoName = "AMMO_REVOLVER_EXPRESS_EXPLOSIVE",
        maxTotal = 10,
        stackable = true,
        tags = { "revolver", "explosive", "craft" }
    },

    ammo_repeater_regular = {
        id = "ammo_repeater_regular",
        kind = "ammunition",
        itemName = "ammo_repeater_regular",
        label = "Repeater Cartridges - Regular",
        nativeAmmoName = "AMMO_REPEATER",
        stackable = true,
        tags = { "repeater", "regular", "purchase" }
    },
    ammo_repeater_express = {
        id = "ammo_repeater_express",
        kind = "ammunition",
        itemName = "ammo_repeater_express",
        label = "Repeater Cartridges - Express",
        nativeAmmoName = "AMMO_REPEATER_EXPRESS",
        stackable = true,
        tags = { "repeater", "express", "purchase" }
    },
    ammo_repeater_high_velocity = {
        id = "ammo_repeater_high_velocity",
        kind = "ammunition",
        itemName = "ammo_repeater_high_velocity",
        label = "Repeater Cartridges - High Velocity",
        nativeAmmoName = "AMMO_REPEATER_HIGH_VELOCITY",
        stackable = true,
        tags = { "repeater", "high_velocity", "purchase" }
    },
    ammo_repeater_split_point = {
        id = "ammo_repeater_split_point",
        kind = "ammunition",
        itemName = "ammo_repeater_split_point",
        label = "Repeater Cartridges - Split Point",
        nativeAmmoName = "AMMO_REPEATER_SPLIT_POINT",
        stackable = true,
        tags = { "repeater", "split_point", "craft" }
    },
    ammo_repeater_explosive = {
        id = "ammo_repeater_explosive",
        kind = "ammunition",
        itemName = "ammo_repeater_explosive",
        label = "Repeater Cartridges - Explosive",
        nativeAmmoName = "AMMO_REPEATER_EXPRESS_EXPLOSIVE",
        -- The target RedM build clamps this native pool to ten. Keep any
        -- excess in Inventory instead of allowing reconciliation to discard it.
        maxTotal = 10,
        stackable = true,
        tags = { "repeater", "explosive", "craft" }
    },

    ammo_rifle_regular = {
        id = "ammo_rifle_regular",
        kind = "ammunition",
        itemName = "ammo_rifle_regular",
        label = "Rifle Cartridges - Regular",
        nativeAmmoName = "AMMO_RIFLE",
        stackable = true,
        tags = { "rifle", "regular", "purchase" }
    },
    ammo_rifle_express = {
        id = "ammo_rifle_express",
        kind = "ammunition",
        itemName = "ammo_rifle_express",
        label = "Rifle Cartridges - Express",
        nativeAmmoName = "AMMO_RIFLE_EXPRESS",
        stackable = true,
        tags = { "rifle", "express", "purchase" }
    },
    ammo_rifle_high_velocity = {
        id = "ammo_rifle_high_velocity",
        kind = "ammunition",
        itemName = "ammo_rifle_high_velocity",
        label = "Rifle Cartridges - High Velocity",
        nativeAmmoName = "AMMO_RIFLE_HIGH_VELOCITY",
        stackable = true,
        tags = { "rifle", "high_velocity", "purchase" }
    },
    ammo_rifle_split_point = {
        id = "ammo_rifle_split_point",
        kind = "ammunition",
        itemName = "ammo_rifle_split_point",
        label = "Rifle Cartridges - Split Point",
        nativeAmmoName = "AMMO_RIFLE_SPLIT_POINT",
        stackable = true,
        tags = { "rifle", "split_point", "craft" }
    },
    ammo_rifle_explosive = {
        id = "ammo_rifle_explosive",
        kind = "ammunition",
        itemName = "ammo_rifle_explosive",
        label = "Rifle Cartridges - Explosive",
        nativeAmmoName = "AMMO_RIFLE_EXPRESS_EXPLOSIVE",
        -- The target RedM build exposes at most ten rounds in this native
        -- pool. Do not escrow cartridges that the game cannot represent.
        maxTotal = 10,
        stackable = true,
        tags = { "rifle", "explosive", "craft" }
    },

    ammo_shotgun_regular = {
        id = "ammo_shotgun_regular",
        kind = "ammunition",
        itemName = "ammo_shotgun_regular",
        label = "Shotgun - Regular",
        nativeAmmoName = "AMMO_SHOTGUN",
        stackable = true,
        tags = { "shotgun", "regular", "purchase" }
    },
    ammo_shotgun_slug = {
        id = "ammo_shotgun_slug",
        kind = "ammunition",
        itemName = "ammo_shotgun_slug",
        label = "Shotgun - Slug",
        nativeAmmoName = "AMMO_SHOTGUN_SLUG",
        stackable = true,
        tags = { "shotgun", "slug", "purchase" }
    },
    ammo_shotgun_buckshot_incendiary = {
        id = "ammo_shotgun_buckshot_incendiary",
        kind = "ammunition",
        itemName = "ammo_shotgun_buckshot_incendiary",
        label = "Shotgun - Incendiary",
        nativeAmmoName = "AMMO_SHOTGUN_BUCKSHOT_INCENDIARY",
        -- RedM exposes fourteen shells for this special native pool.
        maxTotal = 14,
        stackable = true,
        tags = { "shotgun", "buckshot", "incendiary", "craft" }
    },
    ammo_shotgun_slug_explosive = {
        id = "ammo_shotgun_slug_explosive",
        kind = "ammunition",
        itemName = "ammo_shotgun_slug_explosive",
        label = "Shotgun - Explosive",
        nativeAmmoName = "AMMO_SHOTGUN_SLUG_EXPLOSIVE",
        -- The target RedM build clamps explosive slugs to ten shells.
        maxTotal = 10,
        stackable = true,
        tags = { "shotgun", "slug", "explosive", "craft" }
    },

    ammo_varmint = {
        id = "ammo_varmint",
        kind = "ammunition",
        itemName = "ammo_varmint",
        label = "Rifle Cartridges - Varmint",
        nativeAmmoName = "AMMO_22",
        stackable = true,
        tags = { "varmint", "regular", "purchase" }
    },
    ammo_varmint_tranquilizer = {
        id = "ammo_varmint_tranquilizer",
        kind = "ammunition",
        itemName = "ammo_varmint_tranquilizer",
        label = "Rifle Cartridges - Tranquilizer",
        nativeAmmoName = "AMMO_22_TRANQUILIZER",
        stackable = true,
        tags = { "varmint", "tranquilizer", "purchase" }
    },

    ammo_arrow_regular = {
        id = "ammo_arrow_regular",
        kind = "ammunition",
        itemName = "ammo_arrow_regular",
        label = "Arrow - Regular",
        nativeAmmoName = "AMMO_ARROW",
        -- The standard RedM arrow pool is bounded independently from firearm
        -- ammunition. Keep excess arrows in Inventory.
        maxTotal = 40,
        stackable = true,
        tags = { "bow", "arrow", "regular", "purchase" }
    },
    ammo_arrow_small_game = {
        id = "ammo_arrow_small_game",
        kind = "ammunition",
        itemName = "ammo_arrow_small_game",
        label = "Arrow - Small Game",
        nativeAmmoName = "AMMO_ARROW_SMALL_GAME",
        maxTotal = 40,
        stackable = true,
        tags = { "bow", "arrow", "small_game", "craft" }
    },
    ammo_arrow_poison = {
        id = "ammo_arrow_poison",
        kind = "ammunition",
        itemName = "ammo_arrow_poison",
        label = "Arrow - Poison",
        nativeAmmoName = "AMMO_ARROW_POISON",
        -- Special arrows use the smaller native carrying pool.
        maxTotal = 8,
        stackable = true,
        tags = { "bow", "arrow", "poison", "craft" }
    },
    ammo_arrow_fire = {
        id = "ammo_arrow_fire",
        kind = "ammunition",
        itemName = "ammo_arrow_fire",
        label = "Arrow - Fire",
        nativeAmmoName = "AMMO_ARROW_FIRE",
        -- Special arrows use the smaller native carrying pool.
        maxTotal = 8,
        stackable = true,
        tags = { "bow", "arrow", "fire", "craft" }
    },
    ammo_arrow_dynamite = {
        id = "ammo_arrow_dynamite",
        kind = "ammunition",
        itemName = "ammo_arrow_dynamite",
        label = "Arrow - Dynamite",
        nativeAmmoName = "AMMO_ARROW_DYNAMITE",
        -- Crafted special arrows use the smaller native carrying pool.
        maxTotal = 8,
        stackable = true,
        tags = { "bow", "arrow", "dynamite", "craft" }
    },

    ammo_throwing_knives_regular = {
        id = "ammo_throwing_knives_regular",
        kind = "ammunition",
        itemName = "ammo_throwing_knives_regular",
        label = "Throwing Knife - Regular",
        nativeAmmoName = "AMMO_THROWING_KNIVES",
        -- The target RedM build clamps regular throwing knives to eight.
        maxTotal = 8,
        stackable = true,
        tags = { "throwable", "throwing_knife", "regular", "purchase" }
    },

    ammo_throwing_knives_poison = {
        id = "ammo_throwing_knives_poison",
        kind = "ammunition",
        itemName = "ammo_throwing_knives_poison",
        label = "Throwing Knife - Poison",
        nativeAmmoName = "AMMO_THROWING_KNIVES_POISON",
        -- Eight-item load, restart, consumption and exact unload passed live testing.
        maxTotal = 8,
        stackable = true,
        tags = { "throwable", "throwing_knife", "poison", "craft" }
    },
    ammo_tomahawk_regular = {
        id = "ammo_tomahawk_regular",
        kind = "ammunition",
        itemName = "ammo_tomahawk_regular",
        label = "Tomahawk - Regular",
        nativeAmmoName = "AMMO_TOMAHAWK",
        -- The target RedM build clamps regular tomahawks to three.
        maxTotal = 3,
        stackable = true,
        tags = { "throwable", "tomahawk", "regular", "purchase" }
    },
    ammo_bolas_regular = {
        id = "ammo_bolas_regular",
        kind = "ammunition",
        itemName = "ammo_bolas_regular",
        label = "Bolas - Regular",
        nativeAmmoName = "AMMO_BOLAS",
        -- Candidate ceiling; target-build capacity/lifecycle verification pending.
        maxTotal = 3,
        stackable = true,
        tags = { "throwable", "bolas", "regular", "purchase" }
    },
    ammo_bolas_hawkmoth = {
        id = "ammo_bolas_hawkmoth",
        kind = "ammunition",
        itemName = "ammo_bolas_hawkmoth",
        label = "Bolas - Hawkmoth",
        nativeAmmoName = "AMMO_BOLAS_HAWKMOTH",
        -- Candidate ceiling; target-build capacity/lifecycle verification pending.
        maxTotal = 3,
        stackable = true,
        tags = { "throwable", "bolas", "regular", "purchase" }
    },
    ammo_bolas_ironspiked = {
        id = "ammo_bolas_ironspiked",
        kind = "ammunition",
        itemName = "ammo_bolas_ironspiked",
        label = "Bolas - Gravesend",
        nativeAmmoName = "AMMO_BOLAS_IRONSPIKED",
        -- Target-build capacity probe reports three; manual lifecycle checks passed.
        maxTotal = 3,
        stackable = true,
        tags = { "throwable", "bolas", "ironspiked", "purchase" }
    },
    ammo_bolas_intertwined = {
        id = "ammo_bolas_intertwined",
        kind = "ammunition",
        itemName = "ammo_bolas_intertwined",
        label = "Bolas - Brookstone",
        nativeAmmoName = "AMMO_BOLAS_INTERTWINED",
        -- Target-build maximum three confirmed; manual lifecycle checks passed.
        maxTotal = 3,
        stackable = true,
        tags = { "throwable", "bolas", "intertwined", "purchase" }
    },
    ammo_dynamite = {
        id = "ammo_dynamite",
        kind = "ammunition",
        itemName = "ammo_dynamite",
        label = "Dynamite - Regular",
        nativeAmmoName = "AMMO_DYNAMITE",
        -- Provisional eight-item ceiling; requires target-build verification.
        maxTotal = 8,
        stackable = true,
        tags = { "throwable", "dynamite", "regular", "purchase" }
    },
    ammo_molotov = {
        id = "ammo_molotov",
        kind = "ammunition",
        itemName = "ammo_molotov",
        label = "Fire Bottle - Regular",
        nativeAmmoName = "AMMO_MOLOTOV",
        -- Target-build maximum eight confirmed; lifecycle and restart checks passed.
        maxTotal = 8,
        stackable = true,
        tags = { "throwable", "molotov", "regular", "purchase" }
    },
    ammo_poisonbottle = {
        id = "ammo_poisonbottle",
        kind = "ammunition",
        itemName = "ammo_poisonbottle",
        label = "Toxic Moonshine - Regular",
        nativeAmmoName = "AMMO_POISONBOTTLE",
        -- Target-build maximum eight confirmed; user reports manual checks passed.
        maxTotal = 8,
        stackable = true,
        tags = { "throwable", "poisonbottle", "regular", "purchase" }
    },
    ammo_tomahawk_ancient = {
        id = "ammo_tomahawk_ancient",
        kind = "ammunition",
        itemName = "ammo_tomahawk_ancient",
        label = "Tomahawk - Ancient",
        nativeAmmoName = "AMMO_TOMAHAWK_ANCIENT",
        -- Target-build GetMaxAmmo reports one; one-item lifecycle passed live testing.
        maxTotal = 1,
        stackable = true,
        tags = { "throwable", "tomahawk", "ancient" }
    }
}
