# rsg-roulette

Version 3.0.0. Multiplayer roulette tables for RSG Framework

Multiplayer European roulette tables for **RSG Framework** (RedM). Players share a table, place chips on a full betting layout during a timed round, and winnings are paid in cash server side. - Shared, server-authoritative rounds (betting → spin → result) per table - Straight, split, corner, red/black, odd/even, 1-18/19-36, dozens and columns

Source: https://github.com/Rexshack-RedM/rsg-roulette

**Dependencies:** `rsg-core`, `oxmysql`, `ox_lib`, `ox_target`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-roulette']:Name)

**client:** `openRoulette(tableId)`

## Net events registered

**server:** `rsg-roulette:server:clearBets`, `rsg-roulette:server:join`, `rsg-roulette:server:leave`, `rsg-roulette:server:placeBet`, `rsg-roulette:server:placeTable`, `rsg-roulette:server:removeBet`

**client:** `rsg-roulette:client:addTable`, `rsg-roulette:client:forceClose`, `rsg-roulette:client:removeTable`, `rsg-roulette:client:startPlacement`, `rsg-roulette:client:syncState`

## Callbacks (lib.callback)

**server:** `rsg-roulette:server:getTables`

## Public (table) functions

**client/nui.lua:** `NUI.Send(action, data)`, `NUI.Open(data)`, `NUI.Close()`, `NUI.IsOpen()`

## Database tables

`rsg_roulette_tables`
