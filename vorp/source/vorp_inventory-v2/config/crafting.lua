CONFIG = CONFIG or {}
-- CAN CRAFT WEAPONS OR ITEMS
CONFIG.HAND_CRAFTING = {
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
        },
        REWARD = { apple = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            -- Example with vorp_animations
            --local Animations = exports.vorp_animations.initiate()
            --Animations.playAnimation('campfire', 2000)
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
            water = 2,
            coal = 1,
        },
        REWARD = { cigar = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "Molotov",
        DESC = "make a molotov",
        NEEDED = {
            paper = 1,
            apple = 2,
        },
        ISWEAPON = true,                        -- needed to marke this item as weapon
        REWARD = { WEAPON_THROWN_MOLOTOV = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
        },
        REWARD = { apple = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
        },
        REWARD = { cigar = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
        },
        REWARD = { apple = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
        },
        REWARD = { cigar = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
        },
        REWARD = { cigar = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
        },
        REWARD = { cigar = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
    {
        LABEL = "cigar",
        DESC = "roll a cigar",
        NEEDED = {
            tobacco = 1,
            paper = 1,
            apple = 2,
        },
        REWARD = { cigar = 1 }, -- cant add more items only one but amount can be more than one

        ANIM = function()
            -- client: play animation when you implement craft execution
            Wait(1000) -- if no animation wait this time to get the item crafted
        end
    },
}
