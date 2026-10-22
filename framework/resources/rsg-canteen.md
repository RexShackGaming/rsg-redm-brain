# rsg-canteen

Version 3.0.4. rsg-canteen

Fill a canteen at water pumps with **ox_target** and drink from it to restore thirst. - Target `p_waterpump01x` and `p_wellpumpnbx01x` to fill your canteen (option only shows if you carry one). - A full canteen has **10 uses**; each drink restores **25 thirst** (capped at 100).

Source: https://github.com/Rexshack-RedM/rsg-canteen

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`

## Net events registered

**server:** `rsg-canteen:server:finishDrink`, `rsg-canteen:server:finishFill`

**client:** `rsg-canteen:client:addThirst`, `rsg-canteen:client:drink`

## Callbacks (lib.callback)

**server:** `rsg-canteen:server:startFill`
