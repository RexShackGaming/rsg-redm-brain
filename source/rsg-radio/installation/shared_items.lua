    -- rsg-radio (only needed when Config.RegisterItem = false). Add radio.png to rsg-inventory's images.
    radio = { name = 'radio', label = 'Field Radio', weight = 500, type = 'item', image = 'radio.png', unique = false, useable = true, shouldClose = true, description = 'A portable field radio for talking to others on the same frequency', category = 'tools' },
    -- radio_battery (only needed when Config.Battery.Enabled and Config.RegisterItem = false). Add radio_battery.png to rsg-inventory's images.
    -- With batteries on, also set unique = true on the radio item above so every radio keeps its own charge.
    radio_battery = { name = 'radio_battery', label = 'Radio Battery', weight = 100, type = 'item', image = 'radio_battery.png', unique = false, useable = true, shouldClose = true, description = 'A fresh battery pack for a field radio', category = 'tools' },
