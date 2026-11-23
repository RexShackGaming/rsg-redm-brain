# rsg-canteen

Version 3.1.0. rsg-canteen

Fill a canteen at water pumps with **rsg-target**, or straight from rivers and lakes, and drink from it to restore thirst. Full technical reference in [DOCS.md](DOCS.md). - Target `p_waterpump01x` and `p_wellpumpnbx01x` to fill your canteen (option only shows if you carry one). - Stand in shallow river/lake water and hold **G** to fill (optional zone whitelist).

Source: https://github.com/Rexshack-RedM/rsg-canteen

**Dependencies:** `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

## Exports (call as exports['rsg-canteen']:Name)

**server:** `ConsumeUse(src)`

## Net events registered

**server:** `rsg-canteen:server:addPump`, `rsg-canteen:server:finishDrink`, `rsg-canteen:server:finishFill`, `rsg-canteen:server:finishPurify`, `rsg-canteen:server:finishShare`

**client:** `rsg-canteen:client:addPump`, `rsg-canteen:client:drink`, `rsg-canteen:client:sick`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-canteen:server:startFill`, `rsg-canteen:server:startPurify`, `rsg-canteen:server:startShare`

## Commands (RSGCore.Commands.Add)

**server:** `/canteenaddpump`, `/canteenremovepump`

## Database tables

`rsg_canteen_pumps`
