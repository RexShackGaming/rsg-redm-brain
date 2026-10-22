# rsg-cooking

Version 3.0.0. rsg-cooking

A cooking system for **RSG-Core (RedM)**. Players cook food through a full-screen NUI, cook several of the same recipe at once, and can set up their own campfires anywhere in the world. - **Cooking UI**: recipes grouped by category tabs, with item images, cook time, XP reward and a lock for recipes that need more XP. - **Ingredient images and amounts**: each ingredient shows its picture and `have 

Source: https://github.com/Rexshack-RedM/rsg-cooking

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `ox_target`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-cooking']:Name)

**server:** `AddCustomRecipe(recipe)`, `CanCookItem(itemName)`, `CheckPlayerIngredients(src, ingredients)`, `CheckPlayerJob(src, requiredJob)`, `GetCookingRecipes()`, `GetPlayerCookingXP(src, xpType)`, `GetPlayerJob(src)`, `GetRecipeJobRequirement(itemName)`, `GetRecipesByJob(jobName)`, `GivePlayerCookingXP(src, xpGain, xpType)`, `ProcessCooking(src, cookData)`, `ProcessCookingWithJobCheck(src, cookData)`

**client:** `GetCookingCategories()`, `GetCookingRecipes(category)`, `GetRecipeByItem(itemName)`, `GetRecipeIngredients(itemName)`, `GetRecipesByCookingType(cookingType)`, `OpenCookingMenu(cookingType)`

## Net events registered

**server:** `rsg-cooking:server:cancelCooking`, `rsg-cooking:server:placeCampfire`, `rsg-cooking:server:removeCampfire`

**client:** `RSGCore:Client:OnPlayerLoaded`, `rsg-cooking:client:campfireAdded`, `rsg-cooking:client:campfireRemoved`, `rsg-cooking:client:notify`, `rsg-cooking:client:useCampfireItem`

## Event handlers

**client:** `rsg-cooking:client:cookingmenu`

## Callbacks (lib.callback)

**server:** `rsg-cooking:server:finishCooking`, `rsg-cooking:server:getCampfires`, `rsg-cooking:server:getRecipes`, `rsg-cooking:server:startCooking`

## Public (table) functions

**server/campfire.lua:** `CampfireServer.IsNear(src, maxDist)`

**server/webhooks.lua:** `Webhooks.CookingStarted(src, recipe)`, `Webhooks.CookingCompleted(src, recipe)`, `Webhooks.CookingCancelled(src, recipe)`, `Webhooks.CookingFailed(src, recipe, missingItems)`, `Webhooks.JobRestricted(src, recipe, requiredJob)`, `Webhooks.XPGained(src, xpGained, newTotal)`, `Webhooks.CheckMilestones(src, xpGained, newTotal)`, `Webhooks.CheckHighXP(src, xpGained)`, `Webhooks.Suspicious(src, title, detail)`

**shared/utils.lua:** `CookingUtils.MatchesType(recipe, cookingType)`, `CookingUtils.IsValidType(cookingType)`, `CookingUtils.FindRecipeByItem(itemName)`

## Database tables

`rsg_cooking_campfires`
