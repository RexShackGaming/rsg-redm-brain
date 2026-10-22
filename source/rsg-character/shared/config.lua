RSG = {}

RSG.Debug = false

RSG.ProfanityWords = {
    ['bad word'] = true,
    ['dick'] = true,
    ['ass'] = true
}

-- Character select: how many character slots each player license gets
RSG.MaxCharacterSlots = 4

-- Nationalities offered as a dropdown in the character creator (period-appropriate
-- for RDR2's ~1899 setting, but feel free to trim/reorder/add your own).
-- Each entry is a locale key: its display name lives in locales/*.json under "nationalities"
RSG.Nationalities = {
    'american',
    'british',
    'irish',
    'scottish',
    'welsh',
    'french',
    'german',
    'italian',
    'spanish',
    'mexican',
    'dutch',
    'swedish',
    'norwegian',
    'danish',
    'polish',
    'russian',
    'chinese',
    'japanese',
    'cuban',
    'native_american',
    'other',
}

-- Starter items: given once to a brand new character right after it's created
RSG.StarterItems = {
    { item = 'bread',   amount = 2 },
    { item = 'water',   amount = 2 },
    { item = 'bandage', amount = 1 },
}

-- Character select: world location where the character-select peds line up
RSG.CharSelectLocation = {
    coords = vector4(4234.78, -717.32, 50.12, 151.79),
    spacing = 1.65,
    camera = {
        back = 2.0,    -- Floor only - ComputeCameraBack will push this out as needed to fit all slots
        height = 1.95,  -- Camera height, aimed roughly at chest/head level
        fov = 55.0,    -- Wider FOV lets the camera sit closer while still fitting the whole row in frame
    },
}

-- Discord webhook logging - one category per character lifecycle event.
-- Paste your own Discord webhook URL into each `url` field you want active
-- and flip `enabled` to true (categories left blank print a warning to the
-- server console instead of erroring). `color` is a standard Discord embed
-- decimal color code.
RSG.Webhooks = {
    ['character_created'] = {
        enabled = true,
        url = 'https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX',
        name = 'Character Logs',
        avatar = '',
        color = 3066993, -- green
    },
    ['character_deleted'] = {
        enabled = true,
        url = 'https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX',
        name = 'Character Logs',
        avatar = '',
        color = 15158332, -- red
    },
    ['character_selected'] = {
        enabled = false,
        url = 'https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX',
        name = 'Character Logs',
        avatar = '',
        color = 3447003, -- blurple
    },
    ['appearance_saved'] = {
        enabled = true,
        url = 'https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX',
        name = 'Character Logs',
        avatar = '',
        color = 10181046, -- purple
    },
    ['outfit_purchased'] = {
        enabled = true,
        url = 'https://discord.com/api/webhooks/XXXXXXXX/XXXXXXXX',
        name = 'Character Logs',
        avatar = '',
        color = 15844367, -- gold
    },
}

-- Spawn system: locations offered on the spawn-select screen after login/
-- character creation. `coords` is a vector4 (x, y, z, heading). These are
-- rough town-center coordinates meant as a starting point - check them
-- in-game and adjust to wherever you actually want people to be able to
-- spawn on your map.
--
-- `image` is what shows on that location's card on the spawn-select screen
-- (html/index.html's #spawn-select-cards, populated by client/spawn.lua) -
-- an NUI-relative path, so drop a screenshot in html/img/spawn/ (create the
-- folder) and point this at e.g. 'img/spawn/valentine.png'. A missing/nil
-- image just leaves that card's image area blank, it won't error.
RSG.SpawnLocations = {
    { label = locale('spawn_locations.valentine'),   coords = vector4(-169.47, 629.38, 113.03, 236.72), image = 'img/spawn/valentine.jpg' },
    { label = locale('spawn_locations.rhodes'),      coords = vector4(1263.6, -1305.7, 77.9, 210.0), image = 'img/spawn/rhodes.jpg' },
    { label = locale('spawn_locations.saint_denis'), coords = vector4(2694.69, -1448.48, 45.27, 23.27), image = 'img/spawn/saint_denis.jpg' },
    { label = locale('spawn_locations.blackwater'),  coords = vector4(-1035.71, -2731.87, 12.86, 0.0), image = 'img/spawn/blackwater.jpg' },
}

RSG.SpawnChecks = {
    ["Character Creation"] = {
        badSpawn = {
            vector3(4234.78, -717.32, 50.12),
        },
        moveTo = {
            vector3(-169.47, 629.38, 113.03), -- valentine
        },
        Radius = 200,
    },
}

RSG.CameraPromptText = locale('camera_prompt_text')
RSG.RotatePromptText = locale('rotate_prompt_text')
RSG.ZoomPromptText = locale('zoom_prompt_text')
RSG.GroupPromptText = locale('group_prompt_text')

RSG.Prompt = {
    MalePrompt = 0xA65EBAB4,
    FemalePrompt = 0xDEB34313,
    ConfirmPrompt = 0x2CD5343E,
    CameraUp = 0x8FD015D8,
    CameraDown = 0xD27782E3,
    RotateLeft = 0x7065027D,
    RotateRight = 0xB4E465B4,
    Zoom1 = 0x62800C92,
    Zoom2 = 0x8BDE7443,
}

RSG.Texts = {
    Body = locale('texts.body'),
    Face = locale('texts.face'),
    Hair_beard = locale('texts.hair_beard'),
    HairStyle = locale('texts.hair_style'),
    HairColor = locale('texts.hair_color'),
    BeardStyle = locale('texts.beard_style'),
    BeardColor = locale('texts.beard_color'),
    Makeup = locale('texts.makeup'),
    Appearance = locale('texts.appearance'),
    Slim = locale('texts.slim'),
    Sporty = locale('texts.sporty'),
    Medium = locale('texts.medium'),
    Fat = locale('texts.fat'),
    Strong = locale('texts.strong'),
    FaceWidth = locale('texts.face_width'),
    SkinTone = locale('texts.skin_tone'),
    Eyes = locale('texts.eyes'),
    Eyelids = locale('texts.eyelids'),
    Eyebrows = locale('texts.eyebrows'),
    Nose = locale('texts.nose'),
    Mouth = locale('texts.mouth'),
    Teeth = locale('texts.teeth'),
    Cheekbones = locale('texts.cheekbones'),
    Jaw = locale('texts.jaw'),
    Ears = locale('texts.ears'),
    Chin = locale('texts.chin'),
    Defects = locale('texts.defects'),
    Hair = locale('texts.hair'),
    Beard = locale('texts.beard'),
    Type = locale('texts.type'),
    Visibility = locale('texts.visibility'),
    ColorPalette = locale('texts.color_palette'),
    ColorFirstrate = locale('texts.color_firstrate'),
    Eyebrow = locale('texts.eyebrow'),
    NoseCurvature = locale('texts.nose_curvature'),
    UP_DOWN = locale('texts.up_down'),
    left_right = locale('texts.left_right'),
    UpperLipHeight = locale('texts.upper_lip_height'),
    UpperLipWidth = locale('texts.upper_lip_width'),
    UpperLipDepth = locale('texts.upper_lip_depth'),
    LowerLipHeight = locale('texts.lower_lip_height'),
    LowerLipWidth = locale('texts.lower_lip_width'),
    LowerLipDepth = locale('texts.lower_lip_depth'),
    Make_up = locale('texts.make_up'),
    Older = locale('texts.older'),
    Scars = locale('texts.scars'),
    Freckles = locale('texts.freckles'),
    Moles = locale('texts.moles'),
    Disadvantages = locale('texts.disadvantages'),
    Spots = locale('texts.spots'),
    Shadow = locale('texts.shadow'),
    ColorShadow = locale('texts.color_shadow'),
    ColorFirst_Class = locale('texts.color_first_class'),
    Blushing_Cheek = locale('texts.blushing_cheek'),
    blush_id = locale('texts.blush_id'),
    blush_c1 = locale('texts.blush_c1'),
    Lipstick = locale('texts.lipstick'),
    ColorLipstick = locale('texts.color_lipstick'),
    lipsticks_c1 = locale('texts.lipsticks_c1'),
    lipsticks_c2 = locale('texts.lipsticks_c2'),
    Eyeliners = locale('texts.eyeliners'),
    eyeliners_id = locale('texts.eyeliners_id'),
    eyeliners_c1 = locale('texts.eyeliners_c1'),
    save = locale('texts.save'),
    Options = locale('texts.options'),
    align = locale('texts.align'),
    Style = locale('texts.style'),
    Color = locale('texts.color'),
    Size = locale('texts.size'),
    Width = locale('texts.width'),
    Height = locale('texts.height'),
    Depth = locale('texts.depth'),
    Waist = locale('texts.waist'),
    Chest = locale('texts.chest'),
    Distance = locale('texts.distance'),
    Angle = locale('texts.angle'),
    Clarity = locale('texts.clarity'),
    Color1 = "<img src='nui://rsg-character/img/skin1.png' height='20'>",
    Color2 = "<img src='nui://rsg-character/img/skin2.png' height='20'>",
    Color3 = "<img src='nui://rsg-character/img/skin3.png' height='20'>",
    Color4 = "<img src='nui://rsg-character/img/skin4.png' height='20'>",
    Color5 = "<img src='nui://rsg-character/img/skin5.png' height='20'>",
    Color6 = "<img src='nui://rsg-character/img/skin6.png' height='20'>",
    Creator = locale('texts.creator'),

    firsmenu = {
        label_firstname = locale('texts.first_menu.label_firstname'),
        label_lastname = locale('texts.first_menu.label_lastname'),
        desc = locale('texts.first_menu.desc'),
        none = locale('texts.first_menu.none'),
        Start = locale('texts.first_menu.start'),
        empty = locale('texts.first_menu.empty'),
        Nationality = locale('texts.first_menu.nationality'),
        Birthdate = locale('texts.first_menu.birthdate'),
    }
}

--Clothing store

RSG.Cloakroomtext = locale('prompts.cloakroom_text')
RSG.BlipName = locale('blips.clothing_store') -- Blip Name Showed on map
RSG.BlipNameCloakRoom = locale('blips.wardrobe') -- Blip Name Showed on map
RSG.BlipSprite = 1195729388	 -- Clothing shop sprite
RSG.BlipSpriteCloakRoom = 1496995379	 -- Clothing shop sprite
RSG.BlipScale = 0.2 -- Blip scale
RSG.OpenKey = 0xD9D0E1C0 -- Opening key hash
RSG.Keybind = 'ENTER' -- keybind

RSG.SetDoorState = {
    -- open = 0 / locked = 1
    { door = 3554893730, state = 1 }, -- valentine
    { door = 2432590327, state = 1 }, -- rhodes
    { door = 3804893186, state = 1 }, -- saint dennis
    { door = 3277501452, state = 1 }, -- blackwater
    { door = 94437577,   state = 1 }, -- strawberry
    { door = 3315914718, state = 1 }, -- armadillo
    { door = 3208189941, state = 1 }, -- tumbleweed
}

RSG.Zones1 = {

    {
        location = 'valentine',
        blipcoords = vector3(-327.07, 807.77, 117.89),
        fittingcoords = vector4(-327.765, 807.769, 117.894, 254.593),
        quitcoords = vector4(-326.033, 805.976, 117.882, 241.450),
        promtcoords = vector3(-325.9504, 806.58251, 117.8897),
        showblip = true
    },
    {
        location = 'rhodes',
        blipcoords = vector3(1323.64, -1289.04, 77.02),
        fittingcoords = vector4(1324.265, -1287.926, 77.018, 150.606),
        quitcoords = vector4(1322.828, -1291.433, 77.028, 167.880),
        promtcoords = vector3(1322.9941, -1291.02, 77.031051),
        showblip = true
    },
    {
        location = 'saintdenis',
        blipcoords = vector3(2554.90, -1166.89, 53.68),
        fittingcoords = vector4(2555.500, -1161.000, 53.730, 310.371),
        quitcoords = vector4(2553.285, -1161.101, 53.684, 96.703),
        promtcoords = vector3(2554.9929, -1168.596, 53.68354),
        epromtcoords = vector3(2553.7929, -1161.27, 53.683544),
        showblip = true
    },
    {
        location = 'blackwater',
        blipcoords = vector3(-761.99, -1293.55, 43.84),
        fittingcoords = vector4(-767.951, -1294.627, 43.835, 250.153),
        quitcoords = vector4(-766.549, -1293.269, 43.836, 348.399),
        promtcoords = vector3(-762.0018, -1291.981, 43.853542),
        epromtcoords = vector3(-766.5512, -1293.67, 43.835578),
        showblip = true
    },
    {
        location = 'strawberry',
        blipcoords = vector3(-1793.4, -394.13, 160.34),
        fittingcoords = vector4(-1794.604, -395.540, 160.336, 317.471),
        quitcoords = vector4(-1791.907, -391.948, 160.266, 160.266),
        promtcoords = vector3(-1792.499, -392.3773, 160.35339),
        showblip = true
    },
    {
        location = 'armadillo',
        blipcoords = vector3(-3687.866, -2630.905, -13.40),
        fittingcoords = vector4(-3688.229, -2624.204, -10.218, 359.769),
        quitcoords = vector4(-3687.822, -2630.876, -13.395, 73.005),
        promtcoords = vector3(-3687.79, -2630.85, -13.39526),
        epromtcoords = vector3(-3687.168, -2622.447, -10.19031),
        showblip = true
    },
    {
        location = 'tumbleweed',
        blipcoords = vector3(-5480.13, -2933.97, -0.365),
        fittingcoords = vector4(-5479.786, -2932.66, -0.283, 166.096),
        quitcoords = vector4(-5481.510, -2935.005, -0.396, 85.180),
        promtcoords = vector3(-5480.852, -2934.573, -0.384145),
        showblip = true
    },

}

RSG.Cloakroom = {
    vector3(-325.29, 766.24, 117.48),   -- valentine
    vector3(-1817.11, -368.77, 166.54), -- strawberry
    vector3(-825.40, -1323.76, 47.91),  -- blackwater
    vector3(1331.86, -1377.35, 80.55),  -- rhodes
    vector3(2550.67, -1159.46, 53.73)   -- saint denis
}

-- ox_target wardrobe props (opens the cloakroom / outfits menu)
RSG.WardrobeTarget = {
    enabled  = true,
    distance = 2.0,
    icon     = 'fa-solid fa-shirt',
    label    = 'Open Wardrobe',
    models   = {
        'p_armoir02x', 'p_armoir02x_loot', 'p_armoir03x', 'p_armoir04x', 'p_armoir04x_loot',
        'p_armoir05x', 'p_armoir05x_loot', 'p_armoir06x', 'p_armoir07bx', 'p_armoir07x',
        'p_armoir07x_loot', 'p_armoir08x', 'p_armoireregal01', 'p_armoiroffice66x', 's_armoir02x',
        'p_cabinet09x', 'p_chest02x', 'p_commode01x', 'p_commode02x', 'p_commodini01x', 'p_dresser03x',
        'p_dresser04x', 'p_dresser05x', 'p_dresser06x', 'p_dresser07x', 'p_dresser08x', 'p_dresser09x',
        'p_dresser10x', 'p_dresser11x', 'p_dresser11x_static', 'p_dresserval01x', 'p_sdtheater_chest01x',
        'p_sidetable11x', 'p_vanity01x', 'p_vanity02x', 'p_washstand02x', 'p_washstand02x_static',
	},
}

RSG.Label = {
    boot_accessories    = locale('labels.boot_accessories'),
    pants               = locale('labels.pants'),
    cloaks              = locale('labels.cloaks'),
    hats                = locale('labels.hats'),
    vests               = locale('labels.vests'),
    chaps               = locale('labels.chaps'),
    shirts_full         = locale('labels.shirts_full'),
    badges              = locale('labels.badges'),
    masks               = locale('labels.masks'),
    spats               = locale('labels.spats'),
    neckwear            = locale('labels.neckwear'),
    boots               = locale('labels.boots'),
    accessories         = locale('labels.accessories'),
    jewelry_rings_right = locale('labels.jewelry_rings_right'),
    jewelry_rings_left  = locale('labels.jewelry_rings_left'),
    jewelry_bracelets   = locale('labels.jewelry_bracelets'),
    gauntlets           = locale('labels.gauntlets'),
    neckties            = locale('labels.neckties'),
    holsters_knife      = locale('labels.holsters_knife'),
    loadouts            = locale('labels.loadouts'),
    suspenders          = locale('labels.suspenders'),
    satchels            = locale('labels.satchels'),
    gunbelts            = locale('labels.gunbelts'),
    belts               = locale('labels.belts'),
    belt_buckles        = locale('labels.belt_buckles'),
    holsters_left       = locale('labels.holsters_left'),
    holsters_right      = locale('labels.holsters_right'),
    coats               = locale('labels.coats'),
    coats_closed        = locale('labels.coats_closed'),
    ponchos             = locale('labels.ponchos'),
    eyewear             = locale('labels.eyewear'),
    gloves              = locale('labels.gloves'),
    holsters_crossdraw  = locale('labels.holsters_crossdraw'),

    skirts              = locale('labels.skirts'),
    hair_accessories    = locale('labels.hair_accessories'),
    armor               = locale('labels.armor'),
    dresses             = locale('labels.dresses'),
    ammunition_belts    = locale('labels.ammunition_belts'),
    gunbelt_ammunition  = locale('labels.gunbelt_ammunition'),
    gunbelt_accs        = locale('labels.gunbelt_accs'),
    leg_attachments     = locale('labels.leg_attachments'),


    -- other

    save = locale('labels.save'),
    clothes = locale('labels.clothes'),
    options = locale('labels.options'),
    color = locale('labels.color'),
    choose = locale('labels.choose'),
    wear = locale('labels.wear'),
    wear_desc = locale('labels.wear_desc'),
    delete = locale('labels.delete'),
    delete_desc = locale('labels.delete_desc'),
    shop = locale('labels.shop'),
    total = locale('labels.total'),
}

RSG.MenuElements = {
    ["head"] = {
        label = locale('menu_elements.head.label'),
        category = {
            "hats",
            "eyewear",
            "masks",
            "neckwear",
            "neckties",
        }
    },

    ["shirts_vests"] = {
        label = locale('menu_elements.shirts_vests.label'),
        category = {
            "shirts_full",
            "vests",
            "suspenders",
            "loadouts",
        }
    },

    ["belts_holsters"] = {
        label = locale('menu_elements.belts_holsters.label'),
        category = {
            "gunbelts",
            "belts",
            "holsters_left",
            "holsters_right",
            "ammunition_belts",
            "gunbelt_ammunition",
        }
    },

    ["coats_outerwear"] = {
        label = locale('menu_elements.coats_outerwear.label'),
        category = {
            "coats",
            "coats_closed",
            "cloaks",
            "ponchos",
            "dresses",
        }
    },

    ["legs"] = {
        label = locale('menu_elements.legs.label'),
        category = {
            "pants",
            "chaps",
            "skirts",
            "leg_attachments",
        }
    },
    ["foot"] = {
        label = locale('menu_elements.foot.label'),
        category = {
            "boots",
            "spats",
            "boot_accessories",
        }
    },

    ["hands"] = {
        label = locale('menu_elements.hands.label'),
        category = {
            "jewelry_rings_right",
            "jewelry_rings_left",
            "jewelry_bracelets",
            "gauntlets",
            "gloves",
        }
    },

    ["belts_satchels"] = {
        label = locale('menu_elements.belts_satchels.label'),
        category = {
            "accessories",
            "belt_buckles",
            "satchels",
        }
    },

    ["misc_gear"] = {
        label = locale('menu_elements.misc_gear.label'),
        category = {
            "holsters_crossdraw",
            "armor",
            "badges",
            "hair_accessories",
        }
    },
}


RSG.Price = {
    ["boot_accessories"] = 4,
    ["pants"] = 2,
    ["cloaks"] = 4,
    ["hats"] = 2,
    ["vests"] = 2,
    ["chaps"] = 2,
    ["shirts_full"] = 2,
    ["badges"] = 10,
    ["masks"] = 5,
    ["spats"] = 3,
    ["neckwear"] = 2,
    ["boots"] = 2,
    ["accessories"] = 5,
    ["jewelry_rings_right"] = 10,
    ["jewelry_rings_left"] = 10,
    ["jewelry_bracelets"] = 6,
    ["gauntlets"] = 3,
    ["neckties"] = 3,
    ["holsters_knife"] = 3,
    ["loadouts"] = 5,
    ["suspenders"] = 3,
    ["satchels"] = 3,
    ["gunbelts"] = 3,
    ["belts"] = 2,
    ["belt_buckles"] = 6,
    ["holsters_left"] = 5,
    ["holsters_right"] = 5,
    ["coats"] = 5,
    ["coats_closed"] = 5,
    ["ponchos"] = 3,
    ["eyewear"] = 5,
    ["gloves"] = 3,
    ["holsters_crossdraw"] = 4,
    ["skirts"] = 2,
    ["hair_accessories"] = 2,
    ["dresses"] = 1,
    ["armor"] = 20,
    ["ammunition_belts"] = 3,
    ["gunbelt_ammunition"] = 3,
    ["gunbelt_accs"] = 3,
    ["leg_attachments"] = 4,
}

RSG.Prompts = {
    {
        label = locale('prompts.clothing_store_label'),
        id = "OPEN_CLOTHING_MENU"
    },
    {
        label = locale('prompts.zoom_label'),
        id = "ZOOM_IO",
        control = `INPUT_CURSOR_SCROLL_UP`,
        control2 = `INPUT_CURSOR_SCROLL_DOWN`,
        time = 0
    },
    {
        label = locale('prompts.camera_up_label'),
        id = "CAM_UD",
        control = `INPUT_MOVE_UP_ONLY`,
        control2 = `INPUT_MOVE_DOWN_ONLY`,
        time = 0
    },
    {
        label = locale('prompts.camera_turn_label'),
        id = "TURN_LR",
        control = `INPUT_MOVE_LEFT_ONLY`,
        control2 = `INPUT_MOVE_RIGHT_ONLY`,
        time = 0
    },
}

--INPUT_RADIAL_MENU_NAV_UD
RSG.CreatedEntries = {}