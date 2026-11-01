Config = {}

-- how often (ms) changed ammo counts are saved to the database
Config.SaveAmmoInterval = 10000

-- progress bar time (ms) when opening an ammo box
Config.OpenAmmoBoxTime = 2000

-- ammo box items (progress bar) -> ammo type
Config.BoxAmmo = {
    ['ammo_box_revolver']                    = 'AMMO_REVOLVER',
    ['ammo_box_revolver_express']            = 'AMMO_REVOLVER_EXPRESS',
    ['ammo_box_revolver_explosive']          = 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE',
    ['ammo_box_revolver_velocity']           = 'AMMO_REVOLVER_HIGH_VELOCITY',
    ['ammo_box_revolver_splitpoint']         = 'AMMO_REVOLVER_SPLIT_POINT',
    ['ammo_box_pistol']                      = 'AMMO_PISTOL',
    ['ammo_box_pistol_express']              = 'AMMO_PISTOL_EXPRESS',
    ['ammo_box_pistol_explosive']            = 'AMMO_PISTOL_EXPRESS_EXPLOSIVE',
    ['ammo_box_pistol_velocity']             = 'AMMO_PISTOL_HIGH_VELOCITY',
    ['ammo_box_pistol_splitpoint']           = 'AMMO_PISTOL_SPLIT_POINT',
    ['ammo_box_repeater']                    = 'AMMO_REPEATER',
    ['ammo_box_repeater_express']            = 'AMMO_REPEATER_EXPRESS',
    ['ammo_box_repeater_explosive']          = 'AMMO_REPEATER_EXPRESS_EXPLOSIVE',
    ['ammo_box_repeater_velocity']           = 'AMMO_REPEATER_HIGH_VELOCITY',
    ['ammo_box_repeater_splitpoint']         = 'AMMO_REPEATER_SPLIT_POINT',
    ['ammo_box_rifle']                       = 'AMMO_RIFLE',
    ['ammo_box_rifle_express']               = 'AMMO_RIFLE_EXPRESS',
    ['ammo_box_rifle_explosive']             = 'AMMO_RIFLE_EXPRESS_EXPLOSIVE',
    ['ammo_box_rifle_velocity']              = 'AMMO_RIFLE_HIGH_VELOCITY',
    ['ammo_box_rifle_splitpoint']            = 'AMMO_RIFLE_SPLIT_POINT',
    ['ammo_box_shotgun']                     = 'AMMO_SHOTGUN',
    ['ammo_box_shotgun_buckshot_incendiary'] = 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY',
    ['ammo_box_shotgun_slug']                = 'AMMO_SHOTGUN_SLUG',
    ['ammo_box_shotgun_slug_explosive']      = 'AMMO_SHOTGUN_SLUG_EXPLOSIVE',
    ['ammo_box_rifle_elephant']              = 'AMMO_RIFLE_ELEPHANT',
    ['ammo_box_varmint']                     = 'AMMO_22',
    ['ammo_box_varmint_tranquilizer']        = 'AMMO_22_TRANQUILIZER',
}

-- arrow items (used instantly) -> ammo type
Config.ArrowAmmo = {
    ['ammo_arrow']          = 'AMMO_ARROW',
    ['ammo_arrow_small']    = 'AMMO_ARROW_SMALL_GAME',
    ['ammo_arrow_fire']     = 'AMMO_ARROW_FIRE',
    ['ammo_arrow_poison']   = 'AMMO_ARROW_POISON',
    ['ammo_arrow_dynamite'] = 'AMMO_ARROW_DYNAMITE',
}

-- maxAmmo = carry limit, refill = amount given per item
Config.AmmoTypes = {
    ['AMMO_REVOLVER']                    = { maxAmmo = 200, refill = 12 },
    ['AMMO_REVOLVER_HIGH_VELOCITY']      = { maxAmmo = 200, refill = 12 },
    ['AMMO_REVOLVER_SPLIT_POINT']        = { maxAmmo = 200, refill = 12 },
    ['AMMO_REVOLVER_EXPRESS']            = { maxAmmo = 200, refill = 12 },
    ['AMMO_REVOLVER_EXPRESS_EXPLOSIVE']  = { maxAmmo = 10,  refill = 10 },
    ['AMMO_PISTOL']                      = { maxAmmo = 100, refill = 12 },
    ['AMMO_PISTOL_HIGH_VELOCITY']        = { maxAmmo = 100, refill = 12 },
    ['AMMO_PISTOL_SPLIT_POINT']          = { maxAmmo = 50,  refill = 12 },
    ['AMMO_PISTOL_EXPRESS']              = { maxAmmo = 100, refill = 12 },
    ['AMMO_PISTOL_EXPRESS_EXPLOSIVE']    = { maxAmmo = 10,  refill = 10 },
    ['AMMO_REPEATER']                    = { maxAmmo = 200, refill = 12 },
    ['AMMO_REPEATER_HIGH_VELOCITY']      = { maxAmmo = 200, refill = 12 },
    ['AMMO_REPEATER_SPLIT_POINT']        = { maxAmmo = 100, refill = 12 },
    ['AMMO_REPEATER_EXPRESS']            = { maxAmmo = 200, refill = 12 },
    ['AMMO_REPEATER_EXPRESS_EXPLOSIVE']  = { maxAmmo = 10,  refill = 10 },
    ['AMMO_RIFLE']                       = { maxAmmo = 100, refill = 12 },
    ['AMMO_RIFLE_HIGH_VELOCITY']         = { maxAmmo = 100, refill = 12 },
    ['AMMO_RIFLE_SPLIT_POINT']           = { maxAmmo = 50,  refill = 12 },
    ['AMMO_RIFLE_EXPRESS']               = { maxAmmo = 100, refill = 12 },
    ['AMMO_RIFLE_EXPRESS_EXPLOSIVE']     = { maxAmmo = 10,  refill = 10 },
    ['AMMO_SHOTGUN']                     = { maxAmmo = 60,  refill = 12 },
    ['AMMO_SHOTGUN_BUCKSHOT_INCENDIARY'] = { maxAmmo = 14,  refill = 7  },
    ['AMMO_SHOTGUN_SLUG']                = { maxAmmo = 60,  refill = 12 },
    ['AMMO_SHOTGUN_SLUG_EXPLOSIVE']      = { maxAmmo = 10,  refill = 10 },
    ['AMMO_RIFLE_ELEPHANT']              = { maxAmmo = 20,  refill = 10 },
    ['AMMO_22']                          = { maxAmmo = 100, refill = 12 },
    ['AMMO_22_TRANQUILIZER']             = { maxAmmo = 200, refill = 12 },
    ['AMMO_ARROW']                       = { maxAmmo = 40,  refill = 10 },
    ['AMMO_ARROW_SMALL_GAME']            = { maxAmmo = 40,  refill = 10 },
    ['AMMO_ARROW_FIRE']                  = { maxAmmo = 8,   refill = 3  },
    ['AMMO_ARROW_POISON']                = { maxAmmo = 8,   refill = 2  },
    ['AMMO_ARROW_DYNAMITE']              = { maxAmmo = 8,   refill = 1  },
    ['AMMO_MOLOTOV']                     = { maxAmmo = 8,   refill = 1  },
    ['AMMO_TOMAHAWK']                    = { maxAmmo = 3,   refill = 1  },
    ['AMMO_TOMAHAWK_ANCIENT']            = { maxAmmo = 1,   refill = 1  },
    ['AMMO_DYNAMITE']                    = { maxAmmo = 8,   refill = 1  },
    ['AMMO_POISONBOTTLE']                = { maxAmmo = 8,   refill = 1  },
    ['AMMO_THROWING_KNIVES']             = { maxAmmo = 8,   refill = 1  },
    ['AMMO_THROWING_KNIVES_DRAIN']       = { maxAmmo = 8,   refill = 1  },
    ['AMMO_THROWING_KNIVES_POISON']      = { maxAmmo = 8,   refill = 1  },
    ['AMMO_BOLAS']                       = { maxAmmo = 3,   refill = 1  },
    ['AMMO_BOLAS_HAWKMOTH']              = { maxAmmo = 3,   refill = 1  },
    ['AMMO_BOLAS_INTERTWINED']           = { maxAmmo = 3,   refill = 1  },
    ['AMMO_BOLAS_IRONSPIKED']            = { maxAmmo = 3,   refill = 1  },
    ['AMMO_HATCHET']                     = { maxAmmo = 1,   refill = 1  },
    ['AMMO_HATCHET_HUNTER']              = { maxAmmo = 1,   refill = 1  },
    ['AMMO_HATCHET_CLEAVER']             = { maxAmmo = 1,   refill = 1  },
}
