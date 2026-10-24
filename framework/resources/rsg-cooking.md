# rsg-cooking

Version 3.1.0. rsg-cooking

A cooking system for **RSG-Core (RedM)** that works the same way as [rsg-moonshine](https://github.com/Rexshack-RedM/rsg-moonshine): cooking stations keep their own pantry, firebox and serving tray, food cooks in real time on the server (even while you're away and across restarts), and everything is run from one NUI. 1. **Find a station**: target any stove on the map (**Use Stove**) or set up your

Source: https://github.com/Rexshack-RedM/rsg-cooking

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-cooking']:Name)

**server:** `AddCustomRecipe(recipe)`, `CanCookItem(itemName)`, `GetCookingRecipes()`, `GetPlayerCookingLevel(src)`, `GetPlayerCookingXP(src)`, `GivePlayerCookingXP(src, amount)`

**client:** `GetCookingRecipes(category)`, `GetRecipesByCookingType(stype)`

## Net events registered

**server:** `rsg-cooking:server:placeCampfire`, `rsg-cooking:server:requestCampfire`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-cooking:client:placeCampfire`, `rsg-cooking:client:removeStation`, `rsg-cooking:client:syncStation`

## Callbacks (lib.callback)

**server:** `rsg-cooking:server:action`, `rsg-cooking:server:getState`, `rsg-cooking:server:getStations`, `rsg-cooking:server:getWorldStation`

## Commands (RegisterCommand)

**client:** `/cooking_unfocus`

## Public (table) functions

**shared/config.lua:** `Config.RecipeAllowed(recipe, stationType)`

## Database tables

`rsg_cooking_stations`
