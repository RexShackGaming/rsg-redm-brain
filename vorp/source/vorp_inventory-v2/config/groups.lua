CONFIG = CONFIG or {}
-- item groupds are created in the database you must add it there and to the item it self , each item will have a group
CONFIG.ITEM_GROUPS = {
    all = {                                               -- name must match in the database
        types = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, -- all types of items
        label = "All",
        img = "satchel_nav_all.png"
    },
    medical = {
        types = { 0, 2 }, -- always include 0 + the type of the group
        label = "Remedies",
        img = "satchel_nav_remedies.png"
    },
    foods = {
        types = { 0, 3 },
        label = "Provisions",
        img = "satchel_nav_provisions.png"
    },
    weapons = {
        types = { 0, 5 },
        label = "Weapons",
        img = "weapon.png"
    },
    ammo = {
        types = { 0, 6 },
        label = "Ammo",
        img = "ammo.png"
    },
    tools = {
        types = { 0, 4 },
        label = "Materials",
        img = "satchel_nav_materials.png"
    },
    animals = {
        types = { 0, 8 },
        label = "Animals",
        img = "satchel_nav_animals.png"
    },
    documents = {
        types = { 0, 7 },
        label = "Documents",
        img = "satchel_nav_documents.png"
    },
    valuables = {
        types = { 0, 9 },
        label = "Valuables",
        img = "satchel_nav_valuables.png"
    },
    horse = {
        types = { 0, 10 },
        label = "Horse",
        img = "satchel_nav_horse_items.png"
    },
    herbs = {
        types = { 0, 11 },
        label = "Herbs",
        img = "satchel_nav_herbs.png"
    },
    tradable = {
        types = { 0, 11 },
        label = "Tradable",
        img = "satchel_nav_materials.png"
    },
    -- not advised to add more groups, unless you know what you are doing
}
