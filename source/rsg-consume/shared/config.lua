Config = {

    -- stress: positive relieves stress, negative adds stress | hunger/thirst: added to current value (0-100)
    Consumables = {
        Eat = { -- default food items
    ------------------------------------------
	-- Breads
    ------------------------------------------
            ['bread'] = {
                hunger = 25,
                thirst = 0,
                stress = 5,
                propname = 's_bit_bread06',
            },
            ['bread_sour'] = {
                hunger = 40,
                thirst = 0,
                stress = 10,
                propname = 'p_bread_14_ab_s_a',
            },
            ['bread_toast'] = {
                hunger = 25,
                thirst = 0,
                stress = 5,
                alcohol = -5,
                propname = 'p_bread_14_ab_s_a',
            },
            ['toast_apple'] = {
                hunger = 35,
                thirst = 0,
                stress = 10,
                alcohol = -5,
                propname = 'p_bread_14_ab_s_a',
            },
            ['toast_blackberry'] = {
                hunger = 40,
                thirst = 0,
                stress = 10,
                alcohol = -5,
                propname = 'p_bread_14_ab_s_a',
            },
            ['toast_raspberry'] = {
                hunger = 40,
                thirst = 0,
                stress = 10,
                alcohol = -5,
                propname = 'p_bread_14_ab_s_a',
            },
            ['toast_orange'] = {
                hunger = 40,
                thirst = 0,
                stress = 10,
                alcohol = -5,
                propname = 'p_bread_14_ab_s_a',
            },
    ------------------------------------------
	-- meats/fish
    ------------------------------------------
            ['cooked_meat'] = {
                hunger = 30,
                thirst = 5,
                stress = 5,
                alcohol = -5,
                propname = 'p_meatchunk_sm02x',
            },
            ['cooked_fish'] = {
                hunger = 30,
                thirst = 5,
                stress = 5,
                alcohol = -5,
                propname = 'p_meatchunk_sm02x',
            },
            ['jerky_meat'] = {
                hunger = 25,
                thirst = 0,
                stress = 10,
                alcohol = -5,
                propname = 'p_meatchunk_sm02x',
            },
            ['jerky_fish'] = {
                hunger = 25,
                thirst = 0,
                stress = 10,
                alcohol = -5,
                propname = 'p_meatchunk_sm02x',
            },
    ------------------------------------------
	-- raw fruits
    ------------------------------------------
            ['apple'] = {
                hunger = 15,
                thirst = 5,
                stress = 5,
                propname = 's_bit_apple01x',
            },
            ['banana'] = {
                hunger = 15,
                thirst = 5,
                stress = 5,
                propname = 'p_banana_day_01x',
            },
            ['blackberry'] = {
                hunger = 15,
                thirst = 5,
                stress = 5,
                propname = 'p_blackberry01x',
            },
            ['raspberry'] = {
                hunger = 15,
                thirst = 5,
                stress = 5,
                propname = 'p_blackberry01x',
            },
            ['orange'] = {
                hunger = 15,
                thirst = 5,
                stress = 5,
                propname = 's_bit_peach01x',
            },
            ['peach'] = {
                hunger = 15,
                thirst = 5,
                stress = 5,
                propname = 's_bit_peach01x',
            },
    ------------------------------------------
	-- candy
    ------------------------------------------
            ['candy_chocolates'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candy_lemondrops'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candy_licorice_blk'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candy_licorice_red'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candy_lollipop'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candy_peanuts'] = {
                hunger = 30,
                thirst = 0,
                stress = 20,
                propname = 'p_cs_candy01x',
            },
            ['candy_popcorn'] = {
                hunger = 30,
                thirst = 0,
                stress = 20,
                propname = 'p_cs_candy01x',
            },
            ['candy_popcorn_carm'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candy_swtaffy'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candyapple'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candyapple_carm'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candyrock_blue'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candyrock_red'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candystick_blue'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
            ['candystick_orange'] = {
                hunger = 30,
                thirst = 0,
                stress = 30,
                propname = 'p_cs_candy01x',
            },
    ------------------------------------------
	-- raw vegtables
    ------------------------------------------
            ['carrot'] = {
                hunger = 15,
                thirst = 5,
                stress = 5,
                propname = 's_bit_carrot01x',
            },
    ------------------------------------------
	-- Deserts
    ------------------------------------------
                ['cobbler_apple'] = {
                hunger = 40,
                thirst = 5,
                stress = 25,
                alcohol = -15,
                propname = 'p_cornbread02x',
            },
                ['pie_peach'] = {
                hunger = 40,
                thirst = 5,
                stress = 25,
                alcohol = -15,
                propname = 'p_cornbread01x',
            },
                ['pie_raspberry'] = {
                hunger = 40,
                thirst = 5,
                stress = 25,
                alcohol = -15,
                propname = 'p_cornbread01x',
            },
        },
    ------------------------------------------
	-- Drinks
    ------------------------------------------
        Drink = { -- default drink items
            ['water'] = {
                hunger = 0,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_bottlebeer01a_1',
                giveItem = 'emptybottle'
            },
                ['milk'] = {
                hunger = 15,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_bottlebeer01x'
            },
            ['glass_lemonmint'] = {
                hunger = 0,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_masonjar01x'
            },
            ['glass_lemonrasp'] = {
                hunger = 0,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_masonjar01x'
            },
            ['bottle_cola'] = {
                hunger = 0,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_bottlebeer01a'
            },
            ['bottle_colachry'] = {
                hunger = 0,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_bottlebeer01a_3'
            },
            ['bottle_sodaorg'] = {
                hunger = 0,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_bottlebeer03x'
            },
            ['bottle_sasparil'] = {
                hunger = 0,
                thirst = 25,
                stress = 5,
                alcohol = -5,
                propname = 'p_bottlebeer02x'
            },           
    ------------------------------------------
	-- Alcohol
    ------------------------------------------
            ['bottle_beer'] = {
                hunger = 20, --- beer is filling, but you can't live off it ---
                thirst = -5,
                stress = -10,
                alcohol = 25,
                propname = 'p_bottlebeer01x'
            },
			['glass_absinthe'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 40,
				propname = 's_champglass01x'
			},
			['glass_bourbon'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 35,
				propname = 's_tumbler02x_brown'
			},
			['glass_brandy'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 35,
				propname = 'p_glass03x'
			},
			['glass_champagne'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_champglass01x'
			},
			['glass_gin'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_tumbler02x_brown'
			},
			['glass_martini'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 'mp001_p_glass003x_lqd'
			},
			['glass_mintjulip'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_champglass01x'
			},
			['glass_rum'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_tumbler02x_brown' 
			},
			['glass_tequila'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_tumbler02x_brown' 
			},
			['glass_vodka'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_tumbler02x_brown' 
			},
			['glass_whisky'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_tumbler02x_brown' 
			},
            ['glass_wine_red'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 's_wineglass01x_red'
			},
            ['glass_wine_white'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 'p_glass03x'
			},
            ['moonshine'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 25,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_apple'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 25,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_blackberry'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_raspberry'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_peach'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 30,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_plumb'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 35,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_wildcider'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 35,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_currant'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 35,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_applepie'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 40,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_orange'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 40,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_alaskan'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 50,
				propname = 'p_masonjarmoonshine01x'
			},
            ['moonshine_american'] = {
				hunger = -5, --- you'll wake up hungry and thirsty ---
				thirst = -10, --- hard liquor dehydrates you ---
				stress = -20,
				alcohol = 60,
				propname = 'p_masonjarmoonshine01x'
			},
        },
    ------------------------------------------
	-- meals (stew)
    ------------------------------------------
        Stew = { -- always uses the bowl + spoon props
            ['bakedbeans'] = {
                hunger = 35,
                thirst = 15,
                stress = 15,
                alcohol = -10,
            },
            ['stew'] = {
                buff = { health = { amount = 2, interval = 3000, duration = 45000 } },
                hunger = 50,
                thirst = 25,
                stress = 20,
                alcohol = -10,
            },
            ['stew_fish'] = {
                buff = { health = { amount = 2, interval = 3000, duration = 45000 } },
                hunger = 50,
                thirst = 25,
                stress = 20,
                alcohol = -10,
            },
            ['stew_veg'] = {
                buff = { health = { amount = 2, interval = 3000, duration = 45000 } },
                hunger = 50,
                thirst = 25,
                stress = 20,
                alcohol = -10,
            },
            ['fish_n_chips'] = {
                hunger = 45,
                thirst = 15,
                stress = 10,
                alcohol = -10, -- not stew but meals should always uses the bowl + spoon props
            },
        },
    ------------------------------------------
	-- Hot Drinks
    ------------------------------------------
        Hotdrinks = { -- default hot drink items
            ['coffee'] = {
                buff = { stamina = { amount = 3, interval = 2000, duration = 40000 } }, -- timed buff, see Config.Buffs
                hunger = 0,
                thirst = 25,
                stress = 20,
                alcohol = -15, -- hot drinks always use the coffee mug prop
            },
            ['tea'] = {
                buff = { health = { amount = 1, interval = 3000, duration = 30000 } },
                hunger = 0,
                thirst = 25,
                stress = 20,
                alcohol = -15, -- hot drinks always use the coffee mug prop
            },
            ['tea_mint'] = {
                hunger = 0,
                thirst = 25,
                stress = 20,
                alcohol = -10, -- hot drinks always use the coffee mug prop
            },
        },
    ------------------------------------------
	-- Canned
    ------------------------------------------
        Eatcanned = { -- canned food items
            ['canned_apricots'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 's_canrigapricots01x',
            },
            ['canned_beans'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 's_canbeans01x',
            },
            ['canned_fruitsalad'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 's_canrigstrawberrie01x',
            },
            ['canned_peaches'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 's_canrigpeaches01x',
            },
            ['canned_pear'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 's_canrigpineapple01x',
            },
            ['canned_pineapples'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 'p_can08x',
            },
            ['canned_salmon'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 'p_can10x',
            },
            ['canned_strawberries'] = {
                hunger = 10,
                thirst = 10,
                stress = 5,
                alcohol = -3,
                propname = 's_canrigstrawberrie01x',
            },
        },
    },

    -- ==========================================================================================
    -- Features (all can be switched off)
    -- ==========================================================================================

    -- Refuse food/drink that would only fill a need that is already (nearly) full (0-100).
    -- Items with alcohol, or that restore neither hunger nor thirst, are never blocked.
    Fullness = { Enabled = true, BlockAt = 95 },

    -- Items that decay in rsg-inventory carry info.quality (0-100). Positive hunger/thirst scale from
    -- MinFactor (quality 0) to 1.0 (quality 100). Items without quality are unaffected.
    Quality = { Enabled = true, MinFactor = 0.5 },

    -- Old food can make you sick. Below `Below` quality the chance rises linearly to MaxChance (%) at
    -- quality 0. Only categories listed here can spoil (canned food and drinks do not).
    Spoilage = {
        Enabled = true,
        Below = 20,
        MaxChance = 60,
        Categories = { Eat = true, Stew = true },
        EffectFactor = 0.0,   -- share of the hunger/thirst you still get from spoiled food
        ThirstLoss = 10,      -- extra thirst lost
        StressGain = 10,      -- stress added
        SickDuration = 6000,  -- vomit animation (ms)
    },

    -- Regular drinkers handle more. Each alcohol point adds GainPerAlcohol tolerance (0-Max); it raises the
    -- drunk / pass-out thresholds by up to MaxThresholdBonus (0.5 = +50%) and fades by DecayPerDay.
    -- Stored in player metadata (alcoholtolerance), so it survives relogs.
    Tolerance = { Enabled = true, GainPerAlcohol = 0.1, Max = 100, MaxThresholdBonus = 0.5, DecayPerDay = 5 },

    -- Passing out leaves a hangover: thirst drops and stress rises (server side).
    Hangover = { Enabled = true, ThirstLoss = 20, StressGain = 10 },

    -- Press the key while eating/drinking to stop. Progress is measured by the server (Config.Duration):
    -- below RefundBelow the item is refunded, above it you get that share of the effects.
    Cancel = { Enabled = true, Key = 'X', RefundBelow = 0.5, Hint = true },

    -- Approximate real animation length per category (ms); used to work out cancel progress
    Duration = { Eat = 5000, Drink = 4000, Stew = 7000, Hotdrinks = 5000, Eatcanned = 2750 },

    -- Timed buffs. Add `buff = { health = { amount, interval, duration }, stamina = { ... } }` to an item:
    -- every `interval` ms for `duration` ms it adds `amount` health points / stamina percent.
    Buffs = { Enabled = true },

    -- Body temperature (needs rsg-hud with the AddWarmth export). amount = degrees C added for `duration`
    -- seconds (negative cools). Set per category here or per item with `warmth = { amount = -3, duration = 120 }`.
    Warmth = {
        Enabled = true,
        Categories = {
            Hotdrinks = { amount = 3, duration = 180 },
            Stew = { amount = 4, duration = 240 },
        },
    },

    -- Hand one of these items to a nearby player (target the player). They drink it themselves.
    Share = {
        Enabled = true,
        Distance = 2.5,
        Items = {
            bottle_beer = true, glass_whisky = true, glass_bourbon = true, glass_wine_red = true,
            glass_wine_white = true, moonshine = true, coffee = true, tea = true,
        },
    },

    -- Order at the bar: pay cash, drink on the spot (no item is created, no empty bottle).
    -- Add your own bars; coordinates are never guessed here. Prices are cash.
    -- { coords = vec3(x, y, z), radius = 3.0, icon = 'fa-solid fa-beer-mug-empty',
    --   items = { bottle_beer = 0.50, glass_whisky = 0.75, coffee = 0.25 } },
    Bars = {},

    -- AlcoholSystem Configuration
    AlcoholSystem = {
        DrunkThreshold = 50,      -- Threshold to be considered drunk
        PassOutThreshold = 200,   -- Threshold to pass out
        DecreaseAmount = 1,       -- Points removed per cycle
        DecreaseInterval = 5000,  -- Decrement interval (in ms)
        MaxAlcoholLevel = 500,    -- Maximum alcohol level (safety)
        ScaleDrunkness = true,    -- Drunk walk gets stronger as the level rises (false = fixed MaxDrunkLevel)
        MinDrunkLevel = 0.3,      -- Drunkness at DrunkThreshold (0.0 - 1.0)
        MaxDrunkLevel = 0.95,     -- Drunkness at PassOutThreshold (0.0 - 1.0)
    },

    -- Minimum time (ms) the server expects each category to take. If the client reports "finished"
    -- faster than this, the animation was skipped: no effects are applied and the item is refunded.
    -- Keep well below the real animation length (Eat/Hotdrinks 5000, Drink ~4000, Eatcanned 2750).
    MinDuration = {
        Eat = 3000,
        Drink = 2400,
        Stew = 1000,
        Hotdrinks = 3000,
        Eatcanned = 1600,
    },

    AlcoholEffects = {
        -- Visual Effects Configuration
        DrunkEffect = true,                      -- Enable or disable the drunk post-fx effect
        DrunkEffectName = "PlayerDrunk01",       -- The name of the visual effect for being drunk
        PassOutEffect = "PlayerDrunk01_PassOut", -- The name of the visual effect for passing out
        WakeUpEffect = "PlayerWakeUpDrunk",      -- The name of the visual effect for waking up
        GroggyEffectName = "PlayerHealthPoorCS", -- The visual effect for the hangover/groggy state

        -- Timings & Durations (in milliseconds)
        GroggyDuration = 15000,                  -- How long the hangover state lasts after waking up (ms)
        VomitDuration = 10000,                   -- How long the vomit animation plays (ms)
        SleepDuration = 20000,                   -- Total time asleep on the ground, fade-out included (ms)
        FadeOutDuration = 10000,                 -- Duration of the screen fading to black (ms)
        FadeInDuration = 10000,                  -- Duration of the screen fading back in (ms)
    },
}
