# rsg-crafting

Version 3.3.0. rsg-crafting

An XP-based crafting book for **RSG-Core (RedM)**. Players use a crafting book item to open a NUI menu. From there they pick a recipe and a batch size, then craft it while an animation plays. They earn crafting XP that unlocks more recipes. - Usable `craftingbook` item opens a draggable NUI (position saved per player, double-click header or ↺ to reset) - Recipe categories, locked recipes shown wit

Source: https://github.com/Rexshack-RedM/rsg-crafting

**Dependencies:** `rsg-core`, `rsg-inventory`, `oxmysql`, `rsg-target`, `rsg-gizmo`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-crafting']:Name)

**server:** `ForgetRecipe(src, key)`, `GetCraftingRecipes()`, `GetPlayerCraftingXP(src)`, `GivePlayerCraftingXP(src, amount)`, `HasLearnedRecipe(src, key)`, `IsNearStation(src, stationType)`, `LearnRecipe(src, key)`, `SendCraftingLog(logType, title, description, src, extra)`

**client:** `OpenCraftingBook()`

## Net events registered

**server:** `rsg-crafting:server:assist`, `rsg-crafting:server:cancelCrafting`, `rsg-crafting:server:createStation`

**client:** `RSGCore:Client:OnPlayerUnload`, `rsg-crafting:client:addStation`, `rsg-crafting:client:assistAnim`, `rsg-crafting:client:assisted`, `rsg-crafting:client:openBook`, `rsg-crafting:client:placeStation`, `rsg-crafting:client:removeStation`, `rsg-crafting:client:setStations`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-crafting:server:finishCrafting`, `rsg-crafting:server:getRecipes`, `rsg-crafting:server:getStations`, `rsg-crafting:server:startCrafting`

## Commands (RSGCore.Commands.Add)

**server:** `/craftingrecipe`, `/craftingxp`, `/craftstation`, `/removecraftstation`

## Public (table) functions

**server/database.lua:** `CraftingServer.OnReady(fn)`

**server/server.lua:** `CraftingServer.LearnRecipe(Player, key)`, `CraftingServer.ForgetRecipe(Player, key)`, `CraftingServer.IsBlueprint(key)`

**server/stations.lua:** `CraftingServer.StationLabel(stationType)`, `CraftingServer.IsNearStation(src, stationType, extra)`, `CraftingServer.RemoveNearestStation(src)`

## Database tables

`rsg_crafting_recipes`, `rsg_crafting_stations`
