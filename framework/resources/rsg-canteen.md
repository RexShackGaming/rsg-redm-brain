# rsg-canteen

Version 3.0.5. rsg-canteen

Fill a canteen at water pumps with **rsg-target**, or straight from rivers and lakes, and drink from it to restore thirst. - Target `p_waterpump01x` and `p_wellpumpnbx01x` to fill your canteen (option only shows if you carry one). - Stand in shallow river/lake water and hold **G** to fill (optional zone whitelist).

Source: https://github.com/Rexshack-RedM/rsg-canteen

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`

## Net events registered

**server:** `rsg-canteen:server:finishDrink`, `rsg-canteen:server:finishFill`

**client:** `rsg-canteen:client:addThirst`, `rsg-canteen:client:drink`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-canteen:server:startFill`
