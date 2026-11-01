# rsg-treasure

Version 3.0.0. Treasure map hunting for RSG Framework

Treasure map hunting for RSG Framework. Using a treasure map puts a search circle on the map. Equip `weapon_kit_metal_detector` inside the circle: the detector vibrates and bleeps louder, higher and faster, and an on-screen signal meter fills, as you close in. When you pinpoint the spot, press [J] to dig and the muddy strongbox is pulled out of the ground, and the server checks everything before p

Source: https://github.com/Rexshack-RedM/rsg-treasure

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-treasure']:Name)

**server:** `SendLog(channel, title, description, color, src, extra)`

## Net events registered

**server:** `rsg-treasure:server:digStart`

**client:** `rsg-treasure:client:endHunt`, `rsg-treasure:client:startHunt`

## Callbacks (lib.callback)

**server:** `rsg-treasure:server:dig`
