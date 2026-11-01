# rsg-fishing

Version 3.0.3. rsg-fishing

Fishing for **RSG-Core** (RedM). Players equip a fishing rod, bait it with an item from their inventory, cast, hook and reel in fish. Caught fish go into the inventory with their weight. An on-screen HUD guides the player through each step. - **Bait system:** 15 usable bait and lure items. Each fish species has its own bait preferences (`Config.BaitsPerFish`). - **Controls HUD (top-left):** a dark

Source: https://github.com/Rexshack-RedM/rsg-fishing

**Dependencies:** `rsg-core`, `rsg-inventory`

Has NUI (`ui_page`).

## Net events registered

**server:** `rsg-fishing:server:catchFish`, `rsg-fishing:server:removeBaitItem`

**client:** `rsg-fishing:client:usebait`
