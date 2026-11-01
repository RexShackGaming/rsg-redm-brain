-- add these to rsg-core/shared/items.lua (inside the items table)
-- add matching images to rsg-inventory/html/images/
-- skip any item that already exists on your server (fruit, herbs, water etc. often do) - don't add duplicates

---------------------------------
-- still & bottling
---------------------------------
moonshine_still         = { name = 'moonshine_still', label = 'Moonshine Still', weight = 5000, type = 'item', image = 'moonshine_still.png', unique = false, useable = true, shouldClose = true, description = 'A copper still for brewing moonshine' },
moonshine_jug_empty     = { name = 'moonshine_jug_empty', label = 'Empty Moonshine Jug', weight = 300, type = 'item', image = 'moonshine_jug_empty.png', unique = false, useable = false, shouldClose = true, description = 'An empty jug for bottling moonshine' },

---------------------------------
-- moonshine (recipe outputs)
---------------------------------
moonshine               = { name = 'moonshine', label = 'Corn Moonshine', weight = 500, type = 'item', image = 'moonshine.png', unique = false, useable = true, shouldClose = true, description = 'Strong homemade corn liquor' },
moonshine_apple         = { name = 'moonshine_apple', label = 'Apple Moonshine', weight = 500, type = 'item', image = 'moonshine_apple.png', unique = false, useable = true, shouldClose = true, description = 'Apple flavoured moonshine' },
moonshine_blackberry    = { name = 'moonshine_blackberry', label = 'Blackberry Moonshine', weight = 500, type = 'item', image = 'moonshine_blackberry.png', unique = false, useable = true, shouldClose = true, description = 'Blackberry flavoured moonshine' },
moonshine_raspberry     = { name = 'moonshine_raspberry', label = 'Raspberry Moonshine', weight = 500, type = 'item', image = 'moonshine_raspberry.png', unique = false, useable = true, shouldClose = true, description = 'Raspberry flavoured moonshine' },
moonshine_peach         = { name = 'moonshine_peach', label = 'Peach Moonshine', weight = 500, type = 'item', image = 'moonshine_peach.png', unique = false, useable = true, shouldClose = true, description = 'Peach flavoured moonshine' },
moonshine_plumb         = { name = 'moonshine_plumb', label = 'Plum Moonshine', weight = 500, type = 'item', image = 'moonshine_plumb.png', unique = false, useable = true, shouldClose = true, description = 'Creek plum flavoured moonshine' },
moonshine_wildcider     = { name = 'moonshine_wildcider', label = 'Wild Cider Moonshine', weight = 500, type = 'item', image = 'moonshine_wildcider.png', unique = false, useable = true, shouldClose = true, description = 'Apple and wild mint moonshine' },
moonshine_currant       = { name = 'moonshine_currant', label = 'Sweet Currant Moonshine', weight = 500, type = 'item', image = 'moonshine_currant.png', unique = false, useable = true, shouldClose = true, description = 'Black and golden currant moonshine' },
moonshine_applepie      = { name = 'moonshine_applepie', label = 'Apple Crumb Moonshine', weight = 500, type = 'item', image = 'moonshine_applepie.png', unique = false, useable = true, shouldClose = true, description = 'Apple and vanilla moonshine' },
moonshine_orange        = { name = 'moonshine_orange', label = 'Vanilla Orange Moonshine', weight = 500, type = 'item', image = 'moonshine_orange.png', unique = false, useable = true, shouldClose = true, description = 'Orange and vanilla moonshine' },
moonshine_alaskan       = { name = 'moonshine_alaskan', label = 'Alaskan Moonshine', weight = 500, type = 'item', image = 'moonshine_alaskan.png', unique = false, useable = true, shouldClose = true, description = 'Lemon and wintergreen moonshine' },
moonshine_american      = { name = 'moonshine_american', label = 'American Moonshine', weight = 500, type = 'item', image = 'moonshine_american.png', unique = false, useable = true, shouldClose = true, description = 'Corn and wintergreen moonshine' },

---------------------------------
-- ingredients (most servers already have the fruit & herb items)
---------------------------------
corn                    = { name = 'corn', label = 'Corn', weight = 100, type = 'item', image = 'corn.png', unique = false, useable = false, shouldClose = true, description = 'Corn' },
sugarcane               = { name = 'sugarcane', label = 'Sugarcane', weight = 100, type = 'item', image = 'sugarcane.png', unique = false, useable = false, shouldClose = true, description = 'Sugarcane' },
yeast                   = { name = 'yeast', label = 'Yeast', weight = 50, type = 'item', image = 'yeast.png', unique = false, useable = false, shouldClose = true, description = 'Brewer\'s yeast' },
water                   = { name = 'water', label = 'Water', weight = 300, type = 'item', image = 'water.png', unique = false, useable = false, shouldClose = true, description = 'Fresh water' },
apple                   = { name = 'apple', label = 'Apple', weight = 100, type = 'item', image = 'apple.png', unique = false, useable = false, shouldClose = true, description = 'A crisp apple' },
blackberry              = { name = 'blackberry', label = 'Blackberry', weight = 50, type = 'item', image = 'blackberry.png', unique = false, useable = false, shouldClose = true, description = 'Wild blackberries' },
raspberry               = { name = 'raspberry', label = 'Raspberry', weight = 50, type = 'item', image = 'raspberry.png', unique = false, useable = false, shouldClose = true, description = 'Wild raspberries' },
peach                   = { name = 'peach', label = 'Peach', weight = 100, type = 'item', image = 'peach.png', unique = false, useable = false, shouldClose = true, description = 'A ripe peach' },
orange                  = { name = 'orange', label = 'Orange', weight = 100, type = 'item', image = 'orange.png', unique = false, useable = false, shouldClose = true, description = 'A juicy orange' },
lemon                   = { name = 'lemon', label = 'Lemon', weight = 100, type = 'item', image = 'lemon.png', unique = false, useable = false, shouldClose = true, description = 'A sour lemon' },
herb_creek_plum         = { name = 'herb_creek_plum', label = 'Creek Plum', weight = 50, type = 'item', image = 'herb_creek_plum.png', unique = false, useable = false, shouldClose = true, description = 'Creek plum' },
herb_wild_mint          = { name = 'herb_wild_mint', label = 'Wild Mint', weight = 50, type = 'item', image = 'herb_wild_mint.png', unique = false, useable = false, shouldClose = true, description = 'Wild mint' },
herb_black_current      = { name = 'herb_black_current', label = 'Black Currant', weight = 50, type = 'item', image = 'herb_black_current.png', unique = false, useable = false, shouldClose = true, description = 'Black currant' },
herb_golden_currant     = { name = 'herb_golden_currant', label = 'Golden Currant', weight = 50, type = 'item', image = 'herb_golden_currant.png', unique = false, useable = false, shouldClose = true, description = 'Golden currant' },
herb_vanilla_orchid     = { name = 'herb_vanilla_orchid', label = 'Vanilla Flower', weight = 50, type = 'item', image = 'herb_vanilla_orchid.png', unique = false, useable = false, shouldClose = true, description = 'Vanilla orchid' },
herb_wintergreen_berry  = { name = 'herb_wintergreen_berry', label = 'Wintergreen Berry', weight = 50, type = 'item', image = 'herb_wintergreen_berry.png', unique = false, useable = false, shouldClose = true, description = 'Wintergreen berry' },

---------------------------------
-- fuel (should already exist on your server)
---------------------------------
-- resource_wood           = { name = 'resource_wood', label = 'Wood', weight = 500, type = 'item', image = 'resource_wood.png', unique = false, useable = false, shouldClose = true, description = 'A piece of firewood' },
-- resource_coal           = { name = 'resource_coal', label = 'Coal', weight = 500, type = 'item', image = 'resource_coal.png', unique = false, useable = false, shouldClose = true, description = 'A lump of coal' },
