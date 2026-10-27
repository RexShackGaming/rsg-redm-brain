SHARED_DATA = SHARED_DATA or {}

local scopes <const> = {
    COMPONENT_RIFLE_SCOPE02 = true,
    COMPONENT_RIFLE_SCOPE03 = true,
    COMPONENT_RIFLE_SCOPE04 = true,
}


SHARED_DATA.WEAPONS                      = {
    WEAPON_LASSO = {
        Name           = "Lasso",
        Desc           = "Used Up When You Hogtie Someone, The Reinforced one has unlimited hogtie usage",
        AttachPoint    = "",             -- these are not implemented
        HashName       = "WEAPON_LASSO", -- DONT TOUCH
        Weight         = 0.50,           -- 50 kg
        NoSerialNumber = true,           -- do not apply a serial number
        NoDegradation  = true,           -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_LASSO_REINFORCED = {
        Name           = "Reinforced Lasso",
        Desc           = "No Hogtie Limit",
        AttachPoint    = "",
        HashName       = "WEAPON_LASSO_REINFORCED",
        Weight         = 0.55,
        NoSerialNumber = true,
        NoDegradation  = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_KNIFE = {
        Name = "Knife",
        Desc = "Knife used mainly for skinning animals",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE",
        Weight = 0.33,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_KNIFE_RUSTIC = {
        Name = "Knife Rustic",
        Desc = "old looking knife, could it be still useful ?",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE_RUSTIC",
        Weight = 0.40,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_KNIFE_HORROR = {
        Name = "Knife Horror",
        Desc = "This knife was used to do plenty of unpleasant things",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE_HORROR",
        Weight = 0.40,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_KNIFE_CIVIL_WAR = {
        Name = "Knife Civil War",
        Desc = "A knife with a lot of history",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE_CIVIL_WAR",
        Weight = 0.45,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_KNIFE_JAWBONE = {
        Name = "Knife Jawbone",
        Desc = "A knife made of ancient bones",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE_JAWBONE",
        Weight = 0.37,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_KNIFE_MINER = {
        Name = "Knife Miner",
        Desc = "Miners bestfriend",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE_MINER",
        Weight = 0.40,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_KNIFE_VAMPIRE = {
        Name = "Knife Vampire",
        Desc = "They cant be real...",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE_VAMPIRE",
        Weight = 0.39,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_CLEAVER = {
        Name = "Cleaver",
        Desc = "Scary looking but useful",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_CLEAVER",
        Weight = 0.73,
        NoSerialNumber = true,
        NoAmmo = true,        -- this weapon does not need ammo to be used
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_MELEE_HATCHET = {
        Name = "Hachet",
        Desc = "A piece of wood with a blade",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_HATCHET",
        Weight = 1.05,
        NoSerialNumber = true,
        NoAmmo = true,        -- this weapon does not need ammo to be used
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_MELEE_HATCHET_DOUBLE_BIT = {
        Name = "Hachet Double Bit",
        Desc = "A Piece of wood with twice the blade",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_HATCHET_DOUBLE_BIT",
        Weight = 1.15,
        NoSerialNumber = true,
        NoAmmo = true,        -- this weapon does not need ammo to be used
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_MELEE_HATCHET_HEWING = {
        Name = "Hachet Hewing",
        Desc = "Some say this hatchet is magical",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_HATCHET_HEWING",
        Weight = 1.10,
        NoSerialNumber = true,
        NoAmmo = true,        -- this weapon does not need ammo to be used
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_MELEE_HATCHET_HUNTER = {
        Name = "Hachet Hunter",
        Desc = "A Hunters bestfriend",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_HATCHET_HUNTER",
        Weight = 1.15,
        NoSerialNumber = true,
        NoAmmo = true,        -- this weapon does not need ammo to be used
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_MELEE_HATCHET_VIKING = {
        Name = "Hachet Viking",
        Desc = "Smells of fish and salt",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_HATCHET_VIKING",
        Weight = 1.20,
        NoSerialNumber = true,
        NoAmmo = true,        -- this weapon does not need ammo to be used
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_THROWN_TOMAHAWK = {
        Name = "Tomahawk",
        Desc = "A weapon befitting a warrior",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_TOMAHAWK",
        Weight = 1.30,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_THROWN_TOMAHAWK_ANCIENT = {
        Name = "Tomahawk Ancient",
        Desc = "This one is Ancient",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_TOMAHAWK_ANCIENT",
        Weight = 1.50,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_THROWN_THROWING_KNIVES = {
        Name = "Throwing Knifes",
        Desc = "Folks love playing with these",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_THROWING_KNIVES",
        Weight = 1.05,
        DefaultClipSize = 5,  -- THE AMOUNT OF KNIVES YOU WILL HAVE , you need to use ammo to be add to belt and reload this weapon through vorp inventory
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_MELEE_MACHETE = {
        Name = "Machete",
        Desc = "Useful in the jungle",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_MACHETE",
        Weight = 1.3,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        IsThrowable = true,
    },
    WEAPON_BOW = {
        Name = "Bow",
        Desc = "A Simple but effective weapon",
        AttachPoint = "",
        HashName = "WEAPON_BOW",
        Weight = 0.85,
        -- for bows we need to change this because they only have one arrow in clip and we cant even hold it
        DefaultClipSize = 20, -- for bow you can change this is how many arrows it will be allowd to be added, vorp wepons register ammo items and decide how many they add to gunbelt
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_PISTOL_SEMIAUTO = {
        Name = "Pistol Semi-Auto",
        Desc = "repeating single-chamber handgun",
        AttachPoint = "",
        HashName = 'WEAPON_PISTOL_SEMIAUTO',
        Weight = 1.18,
        DefaultClipSize = 8,        -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,       -- default reload speed is 1.0
        ShortWeapon = true,
        ComponentCategoryCount = 3, -- EASIER TO ADD A COUNT THAN TO MAKE LOOPS, this allows to add slots to each weapon
        Components = {
            BARREL = {
                COMPONENT_PISTOL_SEMIAUTO_BARREL_SHORT = true,
                COMPONENT_PISTOL_SEMIAUTO_BARREL_LONG = true,
            },
            GRIP = { -- for example dont  use grip as items , must also change above the componetCategoryCount so it doesnt add a slot for this
                -- COMPONENT_PISTOL_SEMIAUTO_GRIP = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_SEMIAUTO_GRIP_PEARL = true,
                COMPONENT_PISTOL_SEMIAUTO_GRIP_IRONWOOD = true,
                COMPONENT_PISTOL_SEMIAUTO_GRIP_EBONY = true,
                COMPONENT_PISTOL_SEMIAUTO_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_PISTOL_SEMIAUTO_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_SEMIAUTO_SIGHT_WIDE = true,
            },
            --[[      CLIP = {
                COMPONENT_PISTOL_SEMIAUTO_CLIP = true,
            }, ]]
        },
    },
    WEAPON_PISTOL_MAUSER = {
        Name = "Pistol Mauser",
        Desc = "semi-automatic pistol that was originally produced by German arms manufacturer Mauser",
        AttachPoint = "",
        HashName = "WEAPON_PISTOL_MAUSER",
        Weight = 1.13,
        DefaultClipSize = 10, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 4,
        Components = {
            BARREL = {
                COMPONENT_PISTOL_MAUSER_BARREL_SHORT = true, -- might be default ?
                COMPONENT_PISTOL_MAUSER_BARREL_LONG = true,
                COMPONENT_PISTOL_MAUSER_BARREL_AZTEC = true,
            },
            GRIP = {
                -- COMPONENT_PISTOL_MAUSER_GRIP = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_MAUSER_GRIP_PEARL = true,
                COMPONENT_PISTOL_MAUSER_GRIP_EBONY = true,
                COMPONENT_PISTOL_MAUSER_GRIP_IRONWOOD = true,
                COMPONENT_PISTOL_MAUSER_GRIP_BURLED = true,
                COMPONENT_PISTOL_MAUSER_GRIP_AZTEC = true,
            },
            SIGHT = {
                -- COMPONENT_PISTOL_MAUSER_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_MAUSER_SIGHT_WIDE = true,
            },

            FRAME_VERTDATA = {
                COMPONENT_SHORTARM_ROLE_ENGRAVING_MAUSER_AZTEC = true,
            },
        },
    },
    WEAPON_PISTOL_VOLCANIC = {
        Name = "Pistol Volcanic",
        Desc = " an improved version of the Rocket Ball ammunition",
        AttachPoint = "",
        HashName = "WEAPON_PISTOL_VOLCANIC",
        Weight = 1.10,
        DefaultClipSize = 8, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 4,
        Components = {
            BARREL = {
                COMPONENT_PISTOL_VOLCANIC_BARREL_SHORT = true, -- might be default ?
                COMPONENT_PISTOL_VOLCANIC_BARREL_LONG = true,
                COMPONENT_PISTOL_VOLCANIC_BARREL_COLLECTOR = true,
            },
            GRIP = {
                -- COMPONENT_PISTOL_VOLCANIC_GRIP = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_VOLCANIC_GRIP_PEARL = true,
                COMPONENT_PISTOL_VOLCANIC_GRIP_EBONY = true,
                COMPONENT_PISTOL_VOLCANIC_GRIP_IRONWOOD = true,
                COMPONENT_PISTOL_VOLCANIC_GRIP_COLLECTOR = true,
                COMPONENT_PISTOL_VOLCANIC_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_PISTOL_VOLCANIC_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_VOLCANIC_SIGHT_WIDE = true,
                COMPONENT_PISTOL_VOLCANIC_SIGHT_COLLECTOR = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_SHORTARM_FRAME_ENGRAVING_VOLCANIC_COLLECTOR = true,
            },
        },
    },
    WEAPON_PISTOL_M1899 = {
        Name = "Pistol M1899",
        Desc = "its magazine-loaded ammunition allows for a swift reload",
        AttachPoint = "",
        HashName = "WEAPON_PISTOL_M1899",
        Weight = 1.15,
        DefaultClipSize = 8, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 3,
        Components = {
            BARREL = {
                COMPONENT_PISTOL_M1899_BARREL_SHORT = true,
                COMPONENT_PISTOL_M1899_BARREL_LONG = true,
            },
            --[[             CLIP = {
                COMPONENT_PISTOL_M1899_CLIP = true,
            }, ]]
            GRIP = {
                -- COMPONENT_PISTOL_M1899_GRIP = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_M1899_GRIP_IRONWOOD = true,
                COMPONENT_PISTOL_M1899_GRIP_PEARL = true,
                COMPONENT_PISTOL_M1899_GRIP_EBONY = true,
            },
            SIGHT = {
                -- COMPONENT_PISTOL_M1899_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_PISTOL_M1899_SIGHT_WIDE = true,
            },
        },
    },
    WEAPON_REVOLVER_DOUBLEACTION_GAMBLER = {
        Name            = "High Roller Double-Action Revolver",
        Desc            = "Double-action Revolver with gambler motifs engraved across the weapon",
        AttachPoint     = "",
        HashName        = "WEAPON_REVOLVER_DOUBLEACTION_GAMBLER",
        Weight          = 1.05,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        ShortWeapon     = true,
    },
    WEAPON_REVOLVER_SCHOFIELD = {
        Name = "Revolver Schofield",
        Desc = "single-action, cartridge-firing, top-break revolver",
        AttachPoint = "",
        HashName = "WEAPON_REVOLVER_SCHOFIELD",
        Weight = 1.30,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 4,
        Components = {
            -- BARREL
            BARREL = {
                COMPONENT_REVOLVER_SCHOFIELD_BARREL_SHORT = true,
                COMPONENT_REVOLVER_SCHOFIELD_BARREL_LONG = true,
                COMPONENT_REVOLVER_SCHOFIELD_BARREL_BOUNTY = true,
            },
            -- GRIP
            GRIP = {
                -- COMPONENT_REVOLVER_SCHOFIELD_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_SCHOFIELD_GRIP_PEARL = true,
                COMPONENT_REVOLVER_SCHOFIELD_GRIP_IRONWOOD = true,
                COMPONENT_REVOLVER_SCHOFIELD_GRIP_EBONY = true,
                COMPONENT_REVOLVER_SCHOFIELD_GRIP_BOUNTY = true,
                COMPONENT_REVOLVER_SCHOFIELD_GRIP_BURLED = true,
            },
            -- SIGHT
            SIGHT = {
                --  COMPONENT_REVOLVER_SCHOFIELD_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_SCHOFIELD_SIGHT_WIDE = true,
                COMPONENT_REVOLVER_SCHOFIELD_SIGHT_BOUNTY = true,
            },
            -- FRAME_VERTDATA
            FRAME_VERTDATA = {
                COMPONENT_SHORTARM_FRAME_ENGRAVING_SCHOFIELD_BOUNTY = true,
            },
        },
    },
    WEAPON_REVOLVER_NAVY = {
        Name = "Revolver Navy",
        Desc = "cap and ball revolver that was designed by Samuel Colt",
        AttachPoint = "",
        HashName = "WEAPON_REVOLVER_NAVY",
        Weight = 1.20,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 3,
        Components = {
            BARREL = {
                COMPONENT_REVOLVER_NAVY_BARREL_SHORT = true,
                COMPONENT_REVOLVER_NAVY_BARREL_LONG = true,
                COMPONENT_REVOLVER_NAVY_BARREL_CROSSOVER = true,
            },
            GRIP = {
                -- COMPONENT_REVOLVER_NAVY_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_NAVY_GRIP_IRONWOOD = true,
                COMPONENT_REVOLVER_NAVY_GRIP_PEARL = true,
                COMPONENT_REVOLVER_NAVY_GRIP_EBONY = true,
                COMPONENT_REVOLVER_NAVY_GRIP_CROSSOVER = true,
            },
            SIGHT = {
                -- COMPONENT_REVOLVER_NAVY_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_NAVY_SIGHT_WIDE = true,
                COMPONENT_REVOLVER_NAVY_SIGHT_CROSSOVER = true,
            },
        },
    },
    WEAPON_REVOLVER_NAVY_CROSSOVER = {
        Name = "Revolver Navy Crossover",
        Desc = "a revolver that is also a shotgun",
        AttachPoint = "",
        HashName = "WEAPON_REVOLVER_NAVY_CROSSOVER",
        Weight = 1.25,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
    },
    WEAPON_REVOLVER_LEMAT = {
        Name = "Revolver Lemat",
        Desc = "a revolver that is also a shotgun",
        AttachPoint = "",
        HashName = "WEAPON_REVOLVER_LEMAT",
        Weight = 1.86,
        DefaultClipSize = 9, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 3,
        Components = {
            BARREL = {
                COMPONENT_REVOLVER_LEMAT_BARREL_SHORT = true,
                COMPONENT_REVOLVER_LEMAT_BARREL_LONG = true,
            },
            GRIP = {
                -- COMPONENT_REVOLVER_LEMAT_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_LEMAT_GRIP_PEARL = true,
                COMPONENT_REVOLVER_LEMAT_GRIP_EBONY = true,
                COMPONENT_REVOLVER_LEMAT_GRIP_IRONWOOD = true,
            },
            SIGHT = {
                -- COMPONENT_REVOLVER_LEMAT_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_LEMAT_SIGHT_WIDE = true,
            },
        },
    },
    WEAPON_REVOLVER_DOUBLEACTION = {
        Name = "Revolver Double Action",
        Desc = "has a trigger that both cocks the hammer and releases it in one pull ",
        AttachPoint = "",
        HashName = "WEAPON_REVOLVER_DOUBLEACTION",
        Weight = 0.94,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 3,
        Components = {
            BARREL = {
                COMPONENT_REVOLVER_DOUBLEACTION_BARREL_SHORT = true,
                COMPONENT_REVOLVER_DOUBLEACTION_BARREL_LONG = true,
            },
            GRIP = {
                -- COMPONENT_REVOLVER_DOUBLEACTION_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_DOUBLEACTION_GRIP_EBONY = true,
                COMPONENT_REVOLVER_DOUBLEACTION_GRIP_IRONWOOD = true,
                COMPONENT_REVOLVER_DOUBLEACTION_GRIP_PEARL = true,
                COMPONENT_REVOLVER_DOUBLEACTION_GRIP_BAD_HONOR = true,
                COMPONENT_REVOLVER_DOUBLEACTION_GRIP_BURLED = true,
            },
            SIGHT = {
                COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_WIDE = true,
                -- COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_NARROW = true, this is default it will be added when you remove another
            },
        },
    },
    WEAPON_REVOLVER_CATTLEMAN = {
        Name = "Revolver Cattleman",
        Desc = "A cowboys bestfriend",
        AttachPoint = "",
        HashName = "WEAPON_REVOLVER_CATTLEMAN",
        Weight = 1.04,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
        ComponentCategoryCount = 4,
        Components = {
            BARREL = {
                COMPONENT_REVOLVER_CATTLEMAN_BARREL_SHORT = true,
                COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG = true,
                COMPONENT_REVOLVER_CATTLEMAN_BARREL_LEGENDARY = true,
            },
            GRIP = {
                -- COMPONENT_REVOLVER_CATTLEMAN_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_CATTLEMAN_GRIP_PEARL = true,
                COMPONENT_REVOLVER_CATTLEMAN_GRIP_EBONY = true,
                COMPONENT_REVOLVER_CATTLEMAN_GRIP_IRONWOOD = true,
                COMPONENT_REVOLVER_CATTLEMAN_GRIP_GOOD_HONOR = true,
                COMPONENT_REVOLVER_CATTLEMAN_GRIP_BURLED = true,
                COMPONENT_REVOLVER_CATTLEMAN_GRIP_LEGENDARY = true,
            },
            SIGHT = {
                -- COMPONENT_REVOLVER_CATTLEMAN_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REVOLVER_CATTLEMAN_SIGHT_WIDE = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_SHORTARM_ROLE_ENGRAVING_CATTLEMAN_LEGENDARY = true,
            },
        },
    },
    WEAPON_REVOLVER_CATTLEMAN_MEXICAN = {
        Name = "Revolver Cattleman mexican",
        Desc = "a different flavor",
        AttachPoint = "",
        HashName = "WEAPON_REVOLVER_CATTLEMAN_MEXICAN",
        Weight = 1.04,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        ShortWeapon = true,
    },
    WEAPON_RIFLE_VARMINT = {
        Name = "Varmint Rifle",
        Desc = "A rifle useful for hunting critters",
        AttachPoint = "",
        HashName = "WEAPON_RIFLE_VARMINT",
        Weight = 3.80,
        DefaultClipSize = 14, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 6,
        Components = {
            GRIP = {
                -- COMPONENT_RIFLE_VARMINT_GRIP = true, -- default grip dont use as item
                COMPONENT_RIFLE_VARMINT_GRIP_IRONWOOD = true,
                COMPONENT_RIFLE_VARMINT_GRIP_ENGRAVED = true,
                COMPONENT_RIFLE_VARMINT_GRIP_NATURALIST = true,
                COMPONENT_RIFLE_VARMINT_GRIP_BURLED = true,
            },
            SIGHT = {
                --  COMPONENT_REPEATER_PUMPACTION_SIGHT_NARROW = true, -- default sight dont use as item
                COMPONENT_REPEATER_PUMPACTION_SIGHT_WIDE = true,
                COMPONENT_RIFLE_VARMINT_SIGHT_NATURALIST = true,
            },
            CLIP = {
                --  COMPONENT_RIFLE_VARMINT_CLIP = true, -- default clip dont use as item
                COMPONENT_RIFLE_VARMINT_CLIP_ENGRAVED = true,
                COMPONENT_RIFLE_VARMINT_CLIP_IRONWOOD = true,
                COMPONENT_RIFLE_VARMINT_CLIP_NATURALIST = true,
                COMPONENT_RIFLE_VARMINT_CLIP_BURLED = true,
            },
            WRAP = {
                COMPONENT_RIFLE_VARMINT_WRAP1 = true,
                COMPONENT_RIFLE_VARMINT_WRAP2 = true,
                COMPONENT_RIFLE_VARMINT_WRAP3 = true,
                COMPONENT_RIFLE_VARMINT_WRAP4 = true,
                COMPONENT_RIFLE_VARMINT_WRAP5 = true,
                COMPONENT_RIFLE_VARMINT_WRAP6 = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_LONGARM_ROLE_ENGRAVING_VARMINT_NATURALIST = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_REPEATER_WINCHESTER = {
        Name = "Winchester Repeater",
        Desc = "lever-action repeating rifles manufactured by the Winchester Repeating Arms Company",
        AttachPoint = "",
        HashName = "WEAPON_REPEATER_WINCHESTER",
        Weight = 4.30,
        DefaultClipSize = 14, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            GRIP = {
                -- COMPONENT_REPEATER_WINCHESTER_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_WINCHESTER_GRIP_IRONWOOD = true,
                COMPONENT_REPEATER_WINCHESTER_GRIP_ENGRAVED = true,
                COMPONENT_REPEATER_WINCHESTER_GRIP_COLLECTOR = true,
                COMPONENT_REPEATER_WINCHESTER_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_REPEATER_WINCHESTER_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_WINCHESTER_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_REPEATER_WINCHESTER_WRAP1 = true,
                COMPONENT_REPEATER_WINCHESTER_WRAP2 = true,
                COMPONENT_REPEATER_WINCHESTER_WRAP3 = true,
                COMPONENT_REPEATER_WINCHESTER_WRAP4 = true,
                COMPONENT_REPEATER_WINCHESTER_WRAP5 = true,
                COMPONENT_REPEATER_WINCHESTER_WRAP6 = true,
                COMPONENT_REPEATER_WINCHESTER_WRAP_COLLECTOR = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_LONGARM_FRAME_ENGRAVING_WINCHESTER_COLLECTOR = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_REPEATER_HENRY = {
        Name = "Henry Reapeater",
        Desc = " lever-action tubular magazine rifle",
        AttachPoint = "",
        HashName = "WEAPON_REPEATER_HENRY",
        Weight = 4.20,
        DefaultClipSize = 16, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 4,
        Components = {
            GRIP = {
                -- COMPONENT_REPEATER_HENRY_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_HENRY_GRIP_IRONWOOD = true,
                COMPONENT_REPEATER_HENRY_GRIP_ENGRAVED = true,
                COMPONENT_REPEATER_HENRY_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_REPEATER_HENRY_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_HENRY_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_REPEATER_HENRY_WRAP1 = true,
                COMPONENT_REPEATER_HENRY_WRAP2 = true,
                COMPONENT_REPEATER_HENRY_WRAP3 = true,
                COMPONENT_REPEATER_HENRY_WRAP4 = true,
                COMPONENT_REPEATER_HENRY_WRAP5 = true,
                COMPONENT_REPEATER_HENRY_WRAP6 = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_REPEATER_EVANS = {
        Name = "Evans Repeater",
        Desc = "a lever-action repeating rifle designed by Warren R. Evans as a high capacity rifle",
        AttachPoint = "",
        HashName = "WEAPON_REPEATER_EVANS",
        Weight = 4.45,
        DefaultClipSize = 26, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            GRIP = {
                -- COMPONENT_REPEATER_EVANS_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_EVANS_GRIP_IRONWOOD = true,
                COMPONENT_REPEATER_EVANS_GRIP_ENGRAVED = true,
                COMPONENT_REPEATER_EVANS_GRIP_BURLED = true,
                COMPONENT_REPEATER_EVANS_GRIP_WINTER = true,
            },
            SIGHT = {
                -- COMPONENT_REPEATER_EVANS_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_EVANS_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_REPEATER_EVANS_WRAP = true,
                COMPONENT_REPEATER_EVANS_WRAP2 = true,
                COMPONENT_REPEATER_EVANS_WRAP3 = true,
                COMPONENT_REPEATER_EVANS_WRAP4 = true,
                COMPONENT_REPEATER_EVANS_WRAP5 = true,
                COMPONENT_REPEATER_EVANS_WRAP6 = true,
                COMPONENT_REPEATER_EVANS_WRAP_WINTER = true,
            },
            FRAME_ENGRAVING = {
                COMPONENT_LONGARM_ROLE_ENGRAVING_EVANS_WINTER = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_REPEATER_CARBINE = {
        Name = "Carabine Reapeater",
        Desc =
        "A reliable and popular repeating rifle, the Buck Carbine provides medium damage and a decent firing rate",
        AttachPoint = "",
        HashName = "WEAPON_REPEATER_CARBINE",
        Weight = 4.10,
        DefaultClipSize = 7, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            GRIP = {
                -- COMPONENT_REPEATER_CARBINE_GRIP = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_CARBINE_GRIP_IRONWOOD = true,
                COMPONENT_REPEATER_CARBINE_GRIP_ENGRAVED = true,
                COMPONENT_REPEATER_CARBINE_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_REPEATER_CARBINE_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_REPEATER_CARBINE_SIGHT_WIDE = true,
            },
            --[[             CLIP = {
                COMPONENT_REPEATER_CARBINE_CLIP = true,
            }, ]]
            TUBE = {
                COMPONENT_REPEATER_CARBINE_TUBE = true,
            },
            WRAP = {
                COMPONENT_REPEATER_CARBINE_WRAP1 = true,
                COMPONENT_REPEATER_CARBINE_WRAP2 = true,
                COMPONENT_REPEATER_CARBINE_WRAP3 = true,
                COMPONENT_REPEATER_CARBINE_WRAP4 = true,
                COMPONENT_REPEATER_CARBINE_WRAP5 = true,
                COMPONENT_REPEATER_CARBINE_WRAP6 = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_SNIPERRIFLE_ROLLINGBLOCK = {
        Name = "Rolling Block Rifle",
        Desc = "Remington Rolling Block is a family of breech-loading rifles",
        AttachPoint = "",
        HashName = "WEAPON_SNIPERRIFLE_ROLLINGBLOCK",
        Weight = 4.20,
        DefaultClipSize = 1, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            GRIP = {
                -- COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP = true, this is default it will be added when you remove another
                COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_IRONWOOD = true,
                COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_EXOTIC = true,
                COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_ENGRAVED = true,
                COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_BURLED = true,
                COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_REAPER = true,
            },
            SIGHT = {
                -- COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_RIFLE_ROLLINGBLOCK_WRAP1 = true,
                COMPONENT_RIFLE_ROLLINGBLOCK_WRAP2 = true,
                COMPONENT_RIFLE_ROLLINGBLOCK_WRAP3 = true,
                COMPONENT_RIFLE_ROLLINGBLOCK_WRAP4 = true,
                COMPONENT_RIFLE_ROLLINGBLOCK_WRAP5 = true,
                COMPONENT_RIFLE_ROLLINGBLOCK_WRAP6 = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_LONGARM_ROLE_ENGRAVING_ROLLINGBLOCK_REAPER = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_SNIPERRIFLE_CARCANO = {
        Name = "Carcano Rifle",
        Desc = "The Carcano is an Italian, bolt action rifle",
        AttachPoint = "",
        HashName = "WEAPON_SNIPERRIFLE_CARCANO",
        Weight = 3.62,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 0.6,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            GRIP = {
                --  COMPONENT_RIFLE_CARCANO_GRIP = true, -- default grip dont use as item
                COMPONENT_RIFLE_CARCANO_GRIP_IRONWOOD = true,
                COMPONENT_RIFLE_CARCANO_GRIP_ENGRAVED = true,
                COMPONENT_RIFLE_CARCANO_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_RIFLE_CARCANO_SIGHT_NARROW = true, -- default sight dont use as item
                COMPONENT_RIFLE_CARCANO_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_RIFLE_CARCANO_WRAP1 = true,
                COMPONENT_RIFLE_CARCANO_WRAP2 = true,
                COMPONENT_RIFLE_CARCANO_WRAP3 = true,
                COMPONENT_RIFLE_CARCANO_WRAP4 = true,
                COMPONENT_RIFLE_CARCANO_WRAP5 = true,
                COMPONENT_RIFLE_CARCANO_WRAP6 = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_RIFLE_SPRINGFIELD = {
        Name = "Springfield Rifle",
        Desc = "Army's standard issue rifle",
        AttachPoint = "",
        HashName = "WEAPON_RIFLE_SPRINGFIELD",
        Weight = 3.90,
        DefaultClipSize = 1, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 4,
        Components = {
            GRIP = {
                -- COMPONENT_RIFLE_SPRINGFIELD_GRIP = true, this is default it will be added when you remove another
                COMPONENT_RIFLE_SPRINGFIELD_GRIP_IRONWOOD = true,
                COMPONENT_RIFLE_SPRINGFIELD_GRIP_ENGRAVED = true,
                COMPONENT_RIFLE_SPRINGFIELD_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_RIFLE_SPRINGFIELD_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_RIFLE_SPRINGFIELD_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_RIFLE_SPRINGFIELD_WRAP1 = true,
                COMPONENT_RIFLE_SPRINGFIELD_WRAP2 = true,
                COMPONENT_RIFLE_SPRINGFIELD_WRAP3 = true,
                COMPONENT_RIFLE_SPRINGFIELD_WRAP4 = true,
                COMPONENT_RIFLE_SPRINGFIELD_WRAP5 = true,
                COMPONENT_RIFLE_SPRINGFIELD_WRAP6 = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_RIFLE_ELEPHANT = {
        Name = "Elephant Rifle",
        Desc = "Best Weapon for a hunter looking to take down large prey",
        AttachPoint = "",
        HashName = "WEAPON_RIFLE_ELEPHANT",
        Weight = 12.50,
        DefaultClipSize = 2, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 6,
        Components = {
            BARREL = {
                COMPONENT_RIFLE_ELEPHANT_BARREL_SHORT = true,
                COMPONENT_RIFLE_ELEPHANT_BARREL_LONG = true,
            },
            GRIP = {
                -- COMPONENT_RIFLE_ELEPHANT_GRIP = true, this is default it will be added when you remove another
                COMPONENT_RIFLE_ELEPHANT_GRIP_IRONWOOD = true,
                COMPONENT_RIFLE_ELEPHANT_GRIP_ENGRAVED = true,
                COMPONENT_RIFLE_ELEPHANT_GRIP_BURLED = true,
            },
            MAG = {
                --  COMPONENT_RIFLE_ELEPHANT_MAG = true,
                COMPONENT_RIFLE_ELEPHANT_MAG_IRONWOOD = true,
                COMPONENT_RIFLE_ELEPHANT_MAG_ENGRAVED = true,
                COMPONENT_RIFLE_ELEPHANT_MAG_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_RIFLE_ELEPHANT_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_RIFLE_ELEPHANT_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_RIFLE_ELEPHANT_WRAP1 = true,
                COMPONENT_RIFLE_ELEPHANT_WRAP2 = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_RIFLE_BOLTACTION = {
        Name = "BoltAction Rifle",
        Desc = "manual firearm action that is operated by directly manipulating the bolt",
        AttachPoint = "",
        HashName = "WEAPON_RIFLE_BOLTACTION",
        Weight = 4.08,
        DefaultClipSize = 5, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            GRIP = {
                -- COMPONENT_RIFLE_BOLTACTION_GRIP = true, this is default it will be added when you remove another
                COMPONENT_RIFLE_BOLTACTION_GRIP_IRONWOOD = true,
                COMPONENT_RIFLE_BOLTACTION_GRIP_ENGRAVED = true,
                COMPONENT_RIFLE_BOLTACTION_GRIP_BOUNTY = true,
                COMPONENT_RIFLE_BOLTACTION_GRIP_BURLED = true,
            },
            SIGHT = {
                COMPONENT_RIFLE_BOLTACTION_SIGHT_WIDE = true,
                -- COMPONENT_RIFLE_BOLTACTION_SIGHT_NARROW = true, this is default it will be added when you remove another
            },
            WRAP = {
                COMPONENT_RIFLE_BOLTACTION_WRAP = true,
                COMPONENT_RIFLE_BOLTACTION_WRAP2 = true,
                COMPONENT_RIFLE_BOLTACTION_WRAP3 = true,
                COMPONENT_RIFLE_BOLTACTION_WRAP4 = true,
                COMPONENT_RIFLE_BOLTACTION_WRAP5 = true,
                COMPONENT_RIFLE_BOLTACTION_WRAP6 = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_LONGARM_FRAME_ENGRAVING_BOLTACTION_BOUNTY = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_SHOTGUN_SEMIAUTO = {
        Name = "Semi-Auto Shotgun",
        Desc = "a repeating shotgun with a semi-automatic action, capable of automatically chambering a new shell",
        AttachPoint = "",
        HashName = "WEAPON_SHOTGUN_SEMIAUTO",
        Weight = 3.53,
        DefaultClipSize = 5, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            BARREL = {
                COMPONENT_SHOTGUN_SEMIAUTO_BARREL_SHORT = true,
                COMPONENT_SHOTGUN_SEMIAUTO_BARREL_LONG = true,
            },
            GRIP = {
                -- COMPONENT_SHOTGUN_SEMIAUTO_GRIP = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_SEMIAUTO_GRIP_IRONWOOD = true,
                COMPONENT_SHOTGUN_SEMIAUTO_GRIP_ENGRAVED = true,
                COMPONENT_SHOTGUN_SEMIAUTO_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_SHOTGUN_SEMIAUTO_WRAP1 = true,
                COMPONENT_SHOTGUN_SEMIAUTO_WRAP2 = true,
                COMPONENT_SHOTGUN_SEMIAUTO_WRAP3 = true,
                COMPONENT_SHOTGUN_SEMIAUTO_WRAP4 = true,
                COMPONENT_SHOTGUN_SEMIAUTO_WRAP5 = true,
                COMPONENT_SHOTGUN_SEMIAUTO_WRAP6 = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_SHOTGUN_SAWEDOFF = {
        Name = "Sawedoff Shotgun",
        Desc = "shotgun with a shorter gun barre",
        AttachPoint = "",
        HashName = "WEAPON_SHOTGUN_SAWEDOFF",
        Weight = 1.90,
        DefaultClipSize = 2, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 6,
        Components = {
            GRIP = {
                -- COMPONENT_SHOTGUN_SAWEDOFF_GRIP = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_SAWEDOFF_GRIP_IRONWOOD = true,
                COMPONENT_SHOTGUN_SAWEDOFF_GRIP_EBONY = true,
                COMPONENT_SHOTGUN_SAWEDOFF_GRIP_MOONSHINER = true,
                COMPONENT_SHOTGUN_SAWEDOFF_GRIP_BURLED = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_KRAMPUS = true,
            },
            SIGHT = {
                -- COMPONENT_SHOTGUN_SAWED_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_SAWED_SIGHT_WIDE = true,
                COMPONENT_SHOTGUN_SAWED_SIGHT_MOONSHINER = true,
            },
            WRAP = {
                COMPONENT_SHOTGUN_SAWEDOFF_WRAP1 = true,
                COMPONENT_SHOTGUN_SAWEDOFF_WRAP2 = true,
                COMPONENT_SHOTGUN_SAWEDOFF_WRAP3 = true,
                COMPONENT_SHOTGUN_SAWEDOFF_WRAP4 = true,
                COMPONENT_SHOTGUN_SAWEDOFF_WRAP5 = true,
            },
            STOCK = {
                -- COMPONENT_SHOTGUN_SAWEDOFF_STOCK = true,
                COMPONENT_SHOTGUN_SAWEDOFF_STOCK_IRONWOOD = true,
                COMPONENT_SHOTGUN_SAWEDOFF_STOCK_EBONY = true,
                COMPONENT_SHOTGUN_SAWEDOFF_STOCK_MOONSHINER = true,
                COMPONENT_SHOTGUN_SAWEDOFF_STOCK_BURLED = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_LONGARM_ROLE_ENGRAVING_SAWEDOFF_MOONSHINER = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_SHOTGUN_REPEATING = {
        Name = "Repeating Shotgun",
        Desc = "The Lancaster Repeating Shotgun",
        AttachPoint = "",
        HashName = "WEAPON_SHOTGUN_REPEATING",
        Weight = 3.60,
        DefaultClipSize = 6, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 5,
        Components = {
            BARREL = {
                COMPONENT_SHOTGUN_REPEATING_BARREL_SHORT = true,
                COMPONENT_SHOTGUN_REPEATING_BARREL_LONG = true,
            },
            GRIP = {
                -- COMPONENT_SHOTGUN_REPEATING01_GRIP = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_REPEATING01_GRIP_IRONWOOD = true,
                COMPONENT_SHOTGUN_REPEATING01_GRIP_ENGRAVED = true,
                COMPONENT_SHOTGUN_REPEATING_GRIP_BURLED = true,
            },
            SIGHT = {
                -- COMPONENT_SHOTGUN_REPEATING_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_REPEATING_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_SHOTGUN_REPEATING01_WRAP1 = true,
                COMPONENT_SHOTGUN_REPEATING01_WRAP2 = true,
                COMPONENT_SHOTGUN_REPEATING_WRAP3 = true,
                COMPONENT_SHOTGUN_REPEATING_WRAP4 = true,
                COMPONENT_SHOTGUN_REPEATING_WRAP5 = true,
                COMPONENT_SHOTGUN_REPEATING_WRAP6 = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC = {
        Name = "Double Barrel Exotic Shotgun",
        Desc = "exotic-rarity variant of the Double Barrel Shotgun",
        AttachPoint = "",
        HashName = "WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC",
        Weight = 3.71,
        DefaultClipSize = 2, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 1,
        Components = {
            SCOPE = scopes,
        },
    },
    WEAPON_SHOTGUN_PUMP = {
        Name = "Pump Shotgun",
        Desc = "repeating firearm action that is operated manually by moving a sliding handguard",
        AttachPoint = "",
        HashName = "WEAPON_SHOTGUN_PUMP",
        Weight = 3.60,
        DefaultClipSize = 5, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 7,
        Components = {
            BARREL = {
                COMPONENT_SHOTGUN_PUMP_BARREL_SHORT = true,
                COMPONENT_SHOTGUN_PUMP_BARREL_LONG = true,
                COMPONENT_SHOTGUN_PUMP_BARREL_HALLOWEEN = true,
            },
            GRIP = {
                -- COMPONENT_SHOTGUN_PUMP_GRIP = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_PUMP_GRIP_IRONWOOD = true,
                COMPONENT_SHOTGUN_PUMP_GRIP_ENGRAVED = true,
                COMPONENT_SHOTGUN_PUMP_GRIP_BURLED = true,
                COMPONENT_SHOTGUN_PUMP_GRIP_TRADER = true,
                COMPONENT_SHOTGUN_PUMP_GRIP_HALLOWEEN = true,
            },
            SIGHT = {
                -- COMPONENT_SHOTGUN_PUMP_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_PUMP_SIGHT_WIDE = true,
            },
            CLIP = {
                -- COMPONENT_SHOTGUN_PUMP_CLIP = true,
                COMPONENT_SHOTGUN_PUMP_CLIP_IRONWOOD = true,
                COMPONENT_SHOTGUN_PUMP_CLIP_ENGRAVED = true,
                COMPONENT_SHOTGUN_PUMP_CLIP_BURLED = true,
                COMPONENT_SHOTGUN_PUMP_CLIP_TRADER = true,
                COMPONENT_SHOTGUN_PUMP_CLIP_HALLOWEEN = true,
            },
            WRAP = {
                COMPONENT_SHOTGUN_PUMP_WRAP1 = true,
                COMPONENT_SHOTGUN_PUMP_WRAP2 = true,
                COMPONENT_SHOTGUN_PUMP_WRAP3 = true,
                COMPONENT_SHOTGUN_PUMP_WRAP4 = true,
                COMPONENT_SHOTGUN_PUMP_WRAP5 = true,
                COMPONENT_SHOTGUN_PUMP_WRAP6 = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_SHOTGUN_FRAME_ENGRAVING_PUMP_TRADER = true,
                COMPONENT_LONGARM_ROLE_ENGRAVING_PUMP_HALLOWEEN = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_SHOTGUN_DOUBLEBARREL = {
        Name = "Double Barrel Shotgun",
        Desc =
        "break-action shotgun with two parallel barrels, allowing two single shots to be fired in quick succession",
        AttachPoint = "",
        HashName = "WEAPON_SHOTGUN_DOUBLEBARREL",
        Weight = 3.65,
        DefaultClipSize = 2, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        AnimReloadRate = 1.0,
        LongWeapon = true,
        ComponentCategoryCount = 7,
        Components = {
            BARREL = {
                COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_SHORT = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_LONG = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_KRAMPUS = true,
            },
            GRIP = {
                -- COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_IRONWOOD = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_ENGRAVED = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_BURLED = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_EXOTIC = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_KRAMPUS = true,
            },
            SIGHT = {
                -- COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_NARROW = true, this is default it will be added when you remove another
                COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_WIDE = true,
            },
            WRAP = {
                COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP1 = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP2 = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP3 = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP4 = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP5 = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP6 = true,
            },
            MAG = {
                -- COMPONENT_SHOTGUN_DOUBLEBARREL_MAG = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_IRONWOOD = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_ENGRAVED = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_BURLED = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_EXOTIC = true,
                COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_KRAMPUS = true,
            },
            FRAME_VERTDATA = {
                COMPONENT_LONGARM_ROLE_ENGRAVING_DOUBLEBARREL_KRAMPUS = true,
            },
            SCOPE = scopes,
        },
    },
    WEAPON_KIT_CAMERA = {
        Name = "Camera",
        Desc = "a journalists bestfriend",
        AttachPoint = "",
        HashName = "WEAPON_KIT_CAMERA",
        Weight = 0.47,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_KIT_BINOCULARS_IMPROVED = {
        Name = "Improved Binoculars",
        Desc = "See things clearly !",
        AttachPoint = "",
        HashName = "WEAPON_KIT_BINOCULARS_IMPROVED",
        Weight = 1.50,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_KNIFE_TRADER = {
        Name = "Knife Trader",
        Desc = "a traders bestfriend",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_KNIFE_TRADER",
        Weight = 0.45,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_KIT_BINOCULARS = {
        Name = "Binoculars",
        Desc = "lets you see far things",
        AttachPoint = "",
        HashName = "WEAPON_KIT_BINOCULARS",
        Weight = 1.45,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_KIT_CAMERA_ADVANCED = {
        Name = "Advanced Camera",
        Desc = "a camera thats slightly technologicaly better",
        AttachPoint = "",
        HashName = "WEAPON_KIT_CAMERA_ADVANCED",
        Weight = 0.55,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_LANTERN = {
        Name = "Lantern",
        Desc = "lets you see better in the dark",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_LANTERN",
        Weight = 0.56,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_DAVY_LANTERN = {
        Name = "Davy Lantern",
        Desc = "safety lamp for use in flammable atmospheres",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_DAVY_LANTERN",
        Weight = 0.65,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_LANTERN_HALLOWEEN = {
        Name = "Halloween Lantern",
        Desc = "made with a real human skull",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_LANTERN_HALLOWEEN",
        Weight = 1.20,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_THROWN_POISONBOTTLE = {
        Name = "Poison Bottle",
        Desc = "who knows whats in this thing",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_POISONBOTTLE",
        Weight = 0.35,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_KIT_METAL_DETECTOR = {
        Name = "Metal Detector",
        Desc = "helps you find valuables",
        AttachPoint = "",
        HashName = "WEAPON_KIT_METAL_DETECTOR",
        Weight = 0.45,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_THROWN_DYNAMITE = {
        Name = "Dynamite",
        Desc = "boomstick",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_DYNAMITE",
        Weight = 0.19,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_THROWN_MOLOTOV = {
        Name = "Molotov",
        Desc = "an arsonists bestfriend",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_MOLOTOV",
        Weight = 0.45,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_BOW_IMPROVED = {
        Name = "Improved Bow",
        Desc = "a bow with better accuracy",
        AttachPoint = "",
        HashName = "WEAPON_BOW_IMPROVED",
        Weight = 1.10,
        DefaultClipSize = 30, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_MELEE_MACHETE_COLLECTOR = {
        Name = "Machete Collector",
        Desc = "every collector needs one",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_MACHETE_COLLECTOR",
        Weight = 1.40,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_LANTERN_ELECTRIC = {
        Name = "Electric Lantern",
        Desc = "a marvel of technology",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_LANTERN_ELECTRIC",
        Weight = 0.95,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_TORCH = {
        Name = "Torch",
        Desc = "your basic stick on fire",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_TORCH",
        Weight = 1.50,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MOONSHINEJUG_MP = {
        Name = "Moonshine Jug",
        Desc = "those are very fun",
        AttachPoint = "",
        HashName = "WEAPON_MOONSHINEJUG_MP",
        Weight = 2.00,
        DefaultClipSize = 20, -- THESE ARE DEFAULT CLIPSIZES YOU CANNOT CHANGE THEM THIS IS FOR SECURITY PURPOSES
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
    },
    WEAPON_THROWN_BOLAS = {
        Name = "Bolas",
        Desc = "every badass cowboy needs one",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_BOLAS",
        Weight = 0.55,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_THROWN_BOLAS_HAWKMOTH = {
        Name = "Bolas Hawkmoth",
        Desc = "a bola with a twist",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_BOLAS_HAWKMOTH",
        Weight = 0.65,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_THROWN_BOLAS_IRONSPIKED = {
        Name = "Bolas Ironspiked",
        Desc = "a more edgy bola",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_BOLAS_IRONSPIKED",
        Weight = 0.75,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_THROWN_BOLAS_INTERTWINED = {
        Name = "Bolas Intertwined",
        Desc = "a stronger bola",
        AttachPoint = "",
        HashName = "WEAPON_THROWN_BOLAS_INTERTWINED",
        Weight = 0.60,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
        IsThrowable = true,
    },
    WEAPON_FISHINGROD = {
        Name = "Fishing Rod",
        Desc = "whats better than catching fish",
        AttachPoint = "",
        HashName = "WEAPON_FISHINGROD",
        Weight = 1.10,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_MACHETE_HORROR = {
        Name = "Machete Horror",
        Desc = "this one scares people",
        AttachPoint = "",
        HashName = "WEAPON_MELEE_MACHETE_HORROR",
        Weight = 1.40,
        NoSerialNumber = true,
        NoDegradation = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo = true,        -- this weapon does not need ammo to be used
    },
    WEAPON_MELEE_HAMMER = {
        Name           = "Hammer",
        Desc           = "Richards Hammer!",
        AttachPoint    = "",
        HashName       = "WEAPON_MELEE_HAMMER",
        Weight         = 1.25,
        NoSerialNumber = true,
        NoDegradation  = true, -- DONT TOUCH THIS THIS WEAPON DOESNT DEGRADE NATIVELY
        NoAmmo         = true, -- this weapon does not need ammo to be used
    },
}

-- weapon categories allowed in loadout table under comps
-- {BARREL = "COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_SHORT"} -- example of data of comps loadout
SHARED_DATA.WEAPONS_COMPONENT_CATEGORIES = {
    BARREL = true,
    BARREL_ENGRAVING = true,
    BARREL_ENGRAVING_MATERIAL = true,
    BARREL_MATERIAL = true,
    BARREL_RIFLING = true,
    CLIP = true,
    CYLINDER_ENGRAVING = true,
    CYLINDER_ENGRAVING_MATERIAL = true,
    CYLINDER_MATERIAL = true,
    CYLINDER_TINT = true,
    FRAME_ENGRAVING = true,
    FRAME_ENGRAVING_MATERIAL = true,
    FRAME_MATERIAL = true,
    FRAME_VERTDATA = true,
    GRIP = true,
    GRIP_MATERIAL = true,
    GRIP_TINT = true,
    GRIPSTOCK_ENGRAVING = true,
    GRIPSTOCK_TINT = true,
    HAMMER_MATERIAL = true,
    MAG = true,
    MELEE_BLADE_ENGRAVING = true,
    MELEE_BLADE_ENGRAVING_MATERIAL = true,
    MELEE_BLADE_MATERIAL = true,
    SCOPE = true,
    SIGHT = true,
    SIGHT_MATERIAL = true,
    STOCK = true,
    STRAP = true,
    STRAP_TINT = true,
    TORCH_MATCHSTICK = true,
    TRIGGER_MATERIAL = true,
    TRIGGER_TINT = true,
    TUBE = true,
    WRAP = true,
    WRAP_MATERIAL = true,
    WRAP_TINT = true,

}
