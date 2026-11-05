WeaponDefinitionCatalog = WeaponDefinitionCatalog or {}

WeaponDefinitionCatalog.weapons = {
    pistol_volcanic = {
        id = "pistol_volcanic",
        kind = "weapon",
        itemName = "weapon_pistol_volcanic",
        label = "Volcanic Pistol",
        nativeWeaponName = "WEAPON_PISTOL_VOLCANIC",
        family = "pistol",
        slot = "sidearm",
        ammunitionType = "ammo_pistol_regular",
        ammunitionTypes = { "ammo_pistol_regular", "ammo_pistol_express", "ammo_pistol_high_velocity", "ammo_pistol_split_point", "ammo_pistol_explosive" },
        capacity = 8,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "volcanic_long_barrel" },
            sight = { "volcanic_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "pistol" }
    },
    pistol_m1899 = {
        id = "pistol_m1899",
        kind = "weapon",
        itemName = "weapon_pistol_m1899",
        label = "M1899 Pistol",
        nativeWeaponName = "WEAPON_PISTOL_M1899",
        family = "pistol",
        slot = "sidearm",
        ammunitionType = "ammo_pistol_regular",
        ammunitionTypes = { "ammo_pistol_regular", "ammo_pistol_express", "ammo_pistol_high_velocity", "ammo_pistol_split_point", "ammo_pistol_explosive" },
        capacity = 8,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "m1899_long_barrel" },
            sight = { "m1899_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "pistol" }
    },
    pistol_semiauto = {
        id = "pistol_semiauto",
        kind = "weapon",
        itemName = "weapon_pistol_semiauto",
        label = "Semi-Automatic Pistol",
        nativeWeaponName = "WEAPON_PISTOL_SEMIAUTO",
        family = "pistol",
        slot = "sidearm",
        ammunitionType = "ammo_pistol_regular",
        ammunitionTypes = { "ammo_pistol_regular", "ammo_pistol_express", "ammo_pistol_high_velocity", "ammo_pistol_split_point", "ammo_pistol_explosive" },
        capacity = 8,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "semiauto_long_barrel" },
            sight = { "semiauto_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "pistol" }
    },
    pistol_mauser = {
        id = "pistol_mauser",
        kind = "weapon",
        itemName = "weapon_pistol_mauser",
        label = "Mauser Pistol",
        nativeWeaponName = "WEAPON_PISTOL_MAUSER",
        family = "pistol",
        slot = "sidearm",
        ammunitionType = "ammo_pistol_regular",
        ammunitionTypes = { "ammo_pistol_regular", "ammo_pistol_express", "ammo_pistol_high_velocity", "ammo_pistol_split_point", "ammo_pistol_explosive" },
        capacity = 10,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "mauser_long_barrel" },
            sight = { "mauser_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "pistol" }
    },

    revolver_cattleman = {
        id = "revolver_cattleman",
        kind = "weapon",
        itemName = "weapon_revolver_cattleman",
        label = "Cattleman Revolver",
        nativeWeaponName = "WEAPON_REVOLVER_CATTLEMAN",
        family = "revolver",
        slot = "sidearm",
        ammunitionType = "ammo_revolver_regular",
        ammunitionTypes = { "ammo_revolver_regular", "ammo_revolver_express", "ammo_revolver_high_velocity", "ammo_revolver_split_point", "ammo_revolver_explosive" },
        capacity = 6,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        -- Slot keys point to attachment definition IDs accepted by this weapon.
        attachmentSlots = {
            barrel = { "cattleman_long_barrel" },
            sight = { "cattleman_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "revolver" }
    },
    revolver_schofield = {
        id = "revolver_schofield",
        kind = "weapon",
        itemName = "weapon_revolver_schofield",
        label = "Schofield Revolver",
        nativeWeaponName = "WEAPON_REVOLVER_SCHOFIELD",
        family = "revolver",
        slot = "sidearm",
        ammunitionType = "ammo_revolver_regular",
        ammunitionTypes = { "ammo_revolver_regular", "ammo_revolver_express", "ammo_revolver_high_velocity", "ammo_revolver_split_point", "ammo_revolver_explosive" },
        capacity = 6,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "schofield_short_barrel" },
            sight = { "schofield_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Long Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "revolver" }
    },
    revolver_doubleaction = {
        id = "revolver_doubleaction",
        kind = "weapon",
        itemName = "weapon_revolver_doubleaction",
        label = "Double-Action Revolver",
        nativeWeaponName = "WEAPON_REVOLVER_DOUBLEACTION",
        family = "revolver",
        slot = "sidearm",
        ammunitionType = "ammo_revolver_regular",
        ammunitionTypes = { "ammo_revolver_regular", "ammo_revolver_express", "ammo_revolver_high_velocity", "ammo_revolver_split_point", "ammo_revolver_explosive" },
        capacity = 6,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "doubleaction_long_barrel" },
            sight = { "doubleaction_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "revolver" }
    },
    revolver_lemat = {
        id = "revolver_lemat",
        kind = "weapon",
        itemName = "weapon_revolver_lemat",
        label = "LeMat Revolver",
        nativeWeaponName = "WEAPON_REVOLVER_LEMAT",
        family = "revolver",
        slot = "sidearm",
        ammunitionType = "ammo_revolver_regular",
        ammunitionTypes = { "ammo_revolver_regular", "ammo_revolver_express", "ammo_revolver_high_velocity", "ammo_revolver_split_point", "ammo_revolver_explosive" },
        capacity = 9,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "lemat_long_barrel" },
            sight = { "lemat_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "revolver" }
    },
    revolver_navy = {
        id = "revolver_navy",
        kind = "weapon",
        itemName = "weapon_revolver_navy",
        label = "Navy Revolver",
        nativeWeaponName = "WEAPON_REVOLVER_NAVY",
        family = "revolver",
        slot = "sidearm",
        ammunitionType = "ammo_revolver_regular",
        ammunitionTypes = { "ammo_revolver_regular", "ammo_revolver_express", "ammo_revolver_high_velocity", "ammo_revolver_split_point", "ammo_revolver_explosive" },
        capacity = 6,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "navy_long_barrel" },
            sight = { "navy_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "revolver" }
    },

    repeater_carbine = {
        id = "repeater_carbine",
        kind = "weapon",
        itemName = "weapon_repeater_carbine",
        label = "Carbine Repeater",
        nativeWeaponName = "WEAPON_REPEATER_CARBINE",
        family = "repeater",
        slot = "longgun",
        ammunitionType = "ammo_repeater_regular",
        ammunitionTypes = { "ammo_repeater_regular", "ammo_repeater_express", "ammo_repeater_high_velocity", "ammo_repeater_split_point", "ammo_repeater_explosive" },
        capacity = 7,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "carbine_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "repeater" }
    },
    repeater_lancaster = {
        id = "repeater_lancaster",
        kind = "weapon",
        itemName = "weapon_repeater_lancaster",
        label = "Lancaster Repeater",
        nativeWeaponName = "WEAPON_REPEATER_WINCHESTER",
        family = "repeater",
        slot = "longgun",
        ammunitionType = "ammo_repeater_regular",
        ammunitionTypes = { "ammo_repeater_regular", "ammo_repeater_express", "ammo_repeater_high_velocity", "ammo_repeater_split_point", "ammo_repeater_explosive" },
        capacity = 14,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "lancaster_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "repeater" }
    },
    repeater_henry = {
        id = "repeater_henry",
        kind = "weapon",
        itemName = "weapon_repeater_henry",
        label = "Litchfield Repeater",
        nativeWeaponName = "WEAPON_REPEATER_HENRY",
        family = "repeater",
        slot = "longgun",
        ammunitionType = "ammo_repeater_regular",
        ammunitionTypes = { "ammo_repeater_regular", "ammo_repeater_express", "ammo_repeater_high_velocity", "ammo_repeater_split_point", "ammo_repeater_explosive" },
        capacity = 16,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "litchfield_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "repeater" }
    },
    repeater_evans = {
        id = "repeater_evans",
        kind = "weapon",
        itemName = "weapon_repeater_evans",
        label = "Evans Repeater",
        nativeWeaponName = "WEAPON_REPEATER_EVANS",
        family = "repeater",
        slot = "longgun",
        ammunitionType = "ammo_repeater_regular",
        ammunitionTypes = { "ammo_repeater_regular", "ammo_repeater_express", "ammo_repeater_high_velocity", "ammo_repeater_split_point", "ammo_repeater_explosive" },
        capacity = 26,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "evans_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "repeater" }
    },

    rifle_springfield = {
        id = "rifle_springfield",
        kind = "weapon",
        itemName = "weapon_rifle_springfield",
        label = "Springfield Rifle",
        nativeWeaponName = "WEAPON_RIFLE_SPRINGFIELD",
        family = "rifle",
        slot = "longgun",
        ammunitionType = "ammo_rifle_regular",
        ammunitionTypes = { "ammo_rifle_regular", "ammo_rifle_express", "ammo_rifle_high_velocity", "ammo_rifle_split_point", "ammo_rifle_explosive" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "springfield_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "rifle" }
    },
    rifle_boltaction = {
        id = "rifle_boltaction",
        kind = "weapon",
        itemName = "weapon_rifle_boltaction",
        label = "Bolt Action Rifle",
        nativeWeaponName = "WEAPON_RIFLE_BOLTACTION",
        family = "rifle",
        slot = "longgun",
        ammunitionType = "ammo_rifle_regular",
        ammunitionTypes = { "ammo_rifle_regular", "ammo_rifle_express", "ammo_rifle_high_velocity", "ammo_rifle_split_point", "ammo_rifle_explosive" },
        capacity = 5,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "boltaction_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "rifle" }
    },
    rifle_varmint = {
        id = "rifle_varmint",
        kind = "weapon",
        itemName = "weapon_rifle_varmint",
        label = "Varmint Rifle",
        nativeWeaponName = "WEAPON_RIFLE_VARMINT",
        family = "rifle",
        slot = "longgun",
        ammunitionType = "ammo_varmint",
        ammunitionTypes = { "ammo_varmint", "ammo_varmint_tranquilizer" },
        capacity = 14,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "varmint_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "rifle" }
    },
    rifle_rollingblock = {
        id = "rifle_rollingblock",
        kind = "weapon",
        itemName = "weapon_sniperrifle_rollingblock",
        label = "Rolling Block Rifle",
        nativeWeaponName = "WEAPON_SNIPERRIFLE_ROLLINGBLOCK",
        family = "rifle",
        slot = "longgun",
        ammunitionType = "ammo_rifle_regular",
        ammunitionTypes = { "ammo_rifle_regular", "ammo_rifle_express", "ammo_rifle_high_velocity", "ammo_rifle_split_point", "ammo_rifle_explosive" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "rollingblock_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "rifle" }
    },
    rifle_carcano = {
        id = "rifle_carcano",
        kind = "weapon",
        itemName = "weapon_sniperrifle_carcano",
        label = "Carcano Rifle",
        nativeWeaponName = "WEAPON_SNIPERRIFLE_CARCANO",
        family = "rifle",
        slot = "longgun",
        ammunitionType = "ammo_rifle_regular",
        ammunitionTypes = { "ammo_rifle_regular", "ammo_rifle_express", "ammo_rifle_high_velocity", "ammo_rifle_split_point", "ammo_rifle_explosive" },
        capacity = 6,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "carcano_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "rifle" }
    },
    rifle_elephant = {
        id = "rifle_elephant",
        kind = "weapon",
        itemName = "weapon_rifle_elephant",
        label = "Elephant Rifle",
        nativeWeaponName = "WEAPON_RIFLE_ELEPHANT",
        family = "rifle",
        slot = "longgun",
        ammunitionType = "ammo_rifle_elephant",
        ammunitionTypes = { "ammo_rifle_elephant" },
        capacity = 2,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "elephant_long_barrel" },
            sight = { "elephant_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "rifle" }
    },

    shotgun_doublebarrel = {
        id = "shotgun_doublebarrel",
        kind = "weapon",
        itemName = "weapon_shotgun_doublebarrel",
        label = "Double-Barreled Shotgun",
        nativeWeaponName = "WEAPON_SHOTGUN_DOUBLEBARREL",
        family = "shotgun",
        slot = "longgun",
        ammunitionType = "ammo_shotgun_regular",
        ammunitionTypes = { "ammo_shotgun_regular", "ammo_shotgun_slug", "ammo_shotgun_buckshot_incendiary", "ammo_shotgun_slug_explosive" },
        capacity = 2,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "doublebarrel_long_barrel" },
            sight = { "doublebarrel_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "shotgun" }
    },
    shotgun_sawedoff = {
        id = "shotgun_sawedoff",
        kind = "weapon",
        itemName = "weapon_shotgun_sawedoff",
        label = "Sawed-Off Shotgun",
        nativeWeaponName = "WEAPON_SHOTGUN_SAWEDOFF",
        family = "shotgun",
        slot = "sidearm",
        ammunitionType = "ammo_shotgun_regular",
        ammunitionTypes = { "ammo_shotgun_regular", "ammo_shotgun_slug", "ammo_shotgun_buckshot_incendiary", "ammo_shotgun_slug_explosive" },
        capacity = 2,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            sight = { "sawedoff_wide_sight" }
        },
        attachmentDefaults = {
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "sidearm", "shotgun" }
    },
    shotgun_pump = {
        id = "shotgun_pump",
        kind = "weapon",
        itemName = "weapon_shotgun_pump",
        label = "Pump-Action Shotgun",
        nativeWeaponName = "WEAPON_SHOTGUN_PUMP",
        family = "shotgun",
        slot = "longgun",
        ammunitionType = "ammo_shotgun_regular",
        ammunitionTypes = { "ammo_shotgun_regular", "ammo_shotgun_slug", "ammo_shotgun_buckshot_incendiary", "ammo_shotgun_slug_explosive" },
        capacity = 5,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "pump_shotgun_long_barrel" },
            sight = { "pump_shotgun_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "shotgun" }
    },
    shotgun_semiauto = {
        id = "shotgun_semiauto",
        kind = "weapon",
        itemName = "weapon_shotgun_semiauto",
        label = "Semi-Auto Shotgun",
        nativeWeaponName = "WEAPON_SHOTGUN_SEMIAUTO",
        family = "shotgun",
        slot = "longgun",
        ammunitionType = "ammo_shotgun_regular",
        ammunitionTypes = { "ammo_shotgun_regular", "ammo_shotgun_slug", "ammo_shotgun_buckshot_incendiary", "ammo_shotgun_slug_explosive" },
        capacity = 5,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "semiauto_shotgun_long_barrel" },
            sight = { "semiauto_shotgun_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "shotgun" }
    },
    shotgun_repeating = {
        id = "shotgun_repeating",
        kind = "weapon",
        itemName = "weapon_shotgun_repeating",
        label = "Repeating Shotgun",
        nativeWeaponName = "WEAPON_SHOTGUN_REPEATING",
        family = "shotgun",
        slot = "longgun",
        ammunitionType = "ammo_shotgun_regular",
        ammunitionTypes = { "ammo_shotgun_regular", "ammo_shotgun_slug", "ammo_shotgun_buckshot_incendiary", "ammo_shotgun_slug_explosive" },
        capacity = 6,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {
            barrel = { "repeating_shotgun_long_barrel" },
            sight = { "repeating_shotgun_wide_sight" }
        },
        attachmentDefaults = {
            barrel = "Standard Short Barrel",
            sight = "Standard Narrow Sight"
        },
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "firearm", "longgun", "shotgun" }
    },
    utility_lasso = {
        id = "utility_lasso",
        kind = "weapon",
        itemName = "weapon_lasso",
        label = "Lasso",
        nativeWeaponName = "WEAPON_LASSO",
        family = "lasso",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "lasso" }
    },
    utility_davy_lantern = {
        id = "utility_davy_lantern",
        kind = "weapon",
        itemName = "weapon_melee_davy_lantern",
        label = "Davy Lantern",
        nativeWeaponName = "WEAPON_MELEE_DAVY_LANTERN",
        family = "lantern",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "lantern" }
    },
    utility_binoculars = {
        id = "utility_binoculars",
        kind = "weapon",
        itemName = "weapon_kit_binoculars",
        label = "Binoculars",
        nativeWeaponName = "WEAPON_KIT_BINOCULARS",
        family = "binoculars",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "binoculars" }
    },
    utility_binoculars_improved = {
        id = "utility_binoculars_improved",
        kind = "weapon",
        itemName = "weapon_kit_binoculars_improved",
        label = "Improved Binoculars",
        nativeWeaponName = "WEAPON_KIT_BINOCULARS_IMPROVED",
        family = "binoculars",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "binoculars", "improved" }
    },
    utility_metal_detector = {
        id = "utility_metal_detector",
        kind = "weapon",
        itemName = "weapon_kit_metal_detector",
        label = "Metal Detector",
        nativeWeaponName = "WEAPON_KIT_METAL_DETECTOR",
        family = "metal_detector",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "metal_detector" }
    },
    utility_fishing_rod = {
        id = "utility_fishing_rod",
        kind = "weapon",
        itemName = "weapon_fishingrod",
        label = "Fishing Rod",
        nativeWeaponName = "WEAPON_FISHINGROD",
        family = "fishing_rod",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "fishing_rod" }
    },
    utility_camera = {
        id = "utility_camera",
        kind = "weapon",
        itemName = "weapon_kit_camera",
        label = "Camera",
        nativeWeaponName = "WEAPON_KIT_CAMERA",
        family = "camera",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "camera" }
    },
    utility_camera_advanced = {
        id = "utility_camera_advanced",
        kind = "weapon",
        itemName = "weapon_kit_camera_advanced",
        label = "Advanced Camera",
        nativeWeaponName = "WEAPON_KIT_CAMERA_ADVANCED",
        family = "camera",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "camera" }
    },
    utility_lasso_reinforced = {
        id = "utility_lasso_reinforced",
        kind = "weapon",
        itemName = "weapon_lasso_reinforced",
        label = "Reinforced Lasso",
        nativeWeaponName = "WEAPON_LASSO_REINFORCED",
        family = "lasso",
        slot = "utility",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0, maximum = 100, equipMinimum = 1,
            repair = { itemDefinitionId = "gun_oil", quantity = 1, restore = 25 }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = { transferable = true, droppable = true, destructible = true, serialRequired = true },
        tags = { "utility", "lasso" }
    },
    melee_knife = {
        id = "melee_knife",
        kind = "weapon",
        itemName = "weapon_melee_knife",
        label = "Knife",
        nativeWeaponName = "WEAPON_MELEE_KNIFE",
        family = "knife",
        slot = "melee",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "melee", "knife" }
    },
    melee_machete = {
        id = "melee_machete",
        kind = "weapon",
        itemName = "weapon_melee_machete",
        label = "Machete",
        nativeWeaponName = "WEAPON_MELEE_MACHETE",
        family = "machete",
        slot = "melee",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "melee", "machete" }
    },
    melee_hammer = {
        id = "melee_hammer",
        kind = "weapon",
        itemName = "weapon_melee_hammer",
        label = "Hammer",
        nativeWeaponName = "WEAPON_MELEE_HAMMER",
        family = "hammer",
        slot = "melee",
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "melee", "hammer" }
    },
    melee_cleaver = {
        id = "melee_cleaver",
        kind = "weapon",
        itemName = "weapon_melee_cleaver",
        label = "Cleaver",
        nativeWeaponName = "WEAPON_MELEE_CLEAVER",
        family = "cleaver",
        slot = "melee",
        nativeGrantAmount = 1,
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "melee", "cleaver" }
    },
    melee_hatchet = {
        id = "melee_hatchet",
        kind = "weapon",
        itemName = "weapon_melee_hatchet",
        label = "Hatchet",
        nativeWeaponName = "WEAPON_MELEE_HATCHET",
        family = "hatchet",
        slot = "melee",
        nativeGrantAmount = 1,
        usesAmmunition = false,
        ammunitionTypes = {},
        capacity = 0,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "melee", "hatchet" }
    },
    throwable_throwing_knives = {
        id = "throwable_throwing_knives",
        kind = "weapon",
        itemName = "weapon_thrown_throwing_knives",
        label = "Throwing Knives",
        nativeWeaponName = "WEAPON_THROWN_THROWING_KNIVES",
        family = "throwing_knife",
        multiTypeAmmunition = true,
        slot = "throwable",
        ammunitionType = "ammo_throwing_knives_regular",
        ammunitionTypes = { "ammo_throwing_knives_regular", "ammo_throwing_knives_poison" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "throwing_knife" }
    },
    throwable_tomahawk = {
        id = "throwable_tomahawk",
        kind = "weapon",
        itemName = "weapon_thrown_tomahawk",
        label = "Tomahawk",
        nativeWeaponName = "WEAPON_THROWN_TOMAHAWK",
        family = "tomahawk",
        slot = "throwable",
        ammunitionType = "ammo_tomahawk_regular",
        ammunitionTypes = { "ammo_tomahawk_regular" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "tomahawk" }
    },
    throwable_tomahawk_ancient = {
        id = "throwable_tomahawk_ancient",
        kind = "weapon",
        itemName = "weapon_thrown_ancient_tomahawk",
        label = "Ancient Tomahawk",
        nativeWeaponName = "WEAPON_THROWN_TOMAHAWK_ANCIENT",
        family = "tomahawk",
        slot = "throwable",
        ammunitionType = "ammo_tomahawk_ancient",
        ammunitionTypes = { "ammo_tomahawk_ancient" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "tomahawk", "ancient" }
    },
    throwable_bolas = {
        id = "throwable_bolas",
        kind = "weapon",
        itemName = "weapon_thrown_bolas",
        label = "Bolas",
        nativeWeaponName = "WEAPON_THROWN_BOLAS",
        family = "bolas",
        slot = "throwable",
        ammunitionType = "ammo_bolas_regular",
        ammunitionTypes = { "ammo_bolas_regular" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "bolas", "regular" }
    },
    throwable_bolas_hawkmoth = {
        id = "throwable_bolas_hawkmoth",
        kind = "weapon",
        itemName = "weapon_thrown_bolas_hawkmoth",
        label = "Hawkmoth Bolas",
        nativeWeaponName = "WEAPON_THROWN_BOLAS_HAWKMOTH",
        family = "bolas",
        slot = "throwable",
        ammunitionType = "ammo_bolas_hawkmoth",
        ammunitionTypes = { "ammo_bolas_hawkmoth" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "bolas", "regular" }
    },
    throwable_bolas_ironspiked = {
        id = "throwable_bolas_ironspiked",
        kind = "weapon",
        itemName = "weapon_thrown_bolas_ironspiked",
        label = "Gravesend Bolas",
        nativeWeaponName = "WEAPON_THROWN_BOLAS_IRONSPIKED",
        family = "bolas",
        slot = "throwable",
        ammunitionType = "ammo_bolas_ironspiked",
        ammunitionTypes = { "ammo_bolas_ironspiked" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "bolas", "ironspiked" }
    },
    throwable_bolas_intertwined = {
        id = "throwable_bolas_intertwined",
        kind = "weapon",
        itemName = "weapon_thrown_bolas_intertwined",
        label = "Brookstone Bolas",
        nativeWeaponName = "WEAPON_THROWN_BOLAS_INTERTWINED",
        family = "bolas",
        slot = "throwable",
        ammunitionType = "ammo_bolas_intertwined",
        ammunitionTypes = { "ammo_bolas_intertwined" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "bolas", "intertwined" }
    },
    throwable_dynamite = {
        id = "throwable_dynamite",
        kind = "weapon",
        itemName = "weapon_thrown_dynamite",
        label = "Dynamite",
        nativeWeaponName = "WEAPON_THROWN_DYNAMITE",
        family = "dynamite",
        slot = "throwable",
        ammunitionType = "ammo_dynamite",
        ammunitionTypes = { "ammo_dynamite" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "dynamite", "regular" }
    },
    throwable_molotov = {
        id = "throwable_molotov",
        kind = "weapon",
        itemName = "weapon_thrown_molotov",
        label = "Fire Bottle",
        nativeWeaponName = "WEAPON_THROWN_MOLOTOV",
        family = "molotov",
        slot = "throwable",
        ammunitionType = "ammo_molotov",
        ammunitionTypes = { "ammo_molotov" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "molotov", "regular" }
    },
    throwable_poisonbottle = {
        id = "throwable_poisonbottle",
        kind = "weapon",
        itemName = "weapon_thrown_poisonbottle",
        label = "Toxic Moonshine",
        nativeWeaponName = "WEAPON_THROWN_POISONBOTTLE",
        family = "poisonbottle",
        slot = "throwable",
        ammunitionType = "ammo_poisonbottle",
        ammunitionTypes = { "ammo_poisonbottle" },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "throwable", "poisonbottle", "regular" }
    },
    bow = {
        id = "bow",
        kind = "weapon",
        itemName = "weapon_bow",
        label = "Bow",
        nativeWeaponName = "WEAPON_BOW",
        family = "bow",
        slot = "longgun",
        ammunitionType = "ammo_arrow_regular",
        ammunitionTypes = {
            "ammo_arrow_regular",
            "ammo_arrow_small_game",
            "ammo_arrow_poison",
            "ammo_arrow_fire",
            "ammo_arrow_dynamite"
        },
        capacity = 1,
        condition = {
            minimum = 0,
            maximum = 100,
            equipMinimum = 1,
            repair = {
                itemDefinitionId = "gun_oil",
                quantity = 1,
                restore = 25
            }
        },
        attachmentSlots = {},
        attachmentDefaults = {},
        policies = {
            transferable = true,
            droppable = true,
            destructible = true,
            serialRequired = true
        },
        tags = { "ranged", "longgun", "bow" }
    }
}

-- Controlled opt-in; no ownership is granted by enabling pool metadata.
if Config.AmmunitionPools and Config.AmmunitionPools.enabled == true then
    for id in pairs(Config.AmmunitionPools.weapons or {}) do
        local definition = WeaponDefinitionCatalog.weapons[id]
        if definition and definition.usesAmmunition ~= false and #definition.ammunitionTypes > 1 then
            definition.multiTypeAmmunition = true
        end
    end
end
