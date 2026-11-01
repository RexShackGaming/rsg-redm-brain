# rsg-crafting

Version 3.1.0. rsg-crafting

An XP-based crafting book for **RSG-Core (RedM)**. Players use a crafting book item to open a NUI menu. From there they pick a recipe and a batch size, then craft it while an animation plays. They earn crafting XP that unlocks more recipes. - Usable `craftingbook` item opens a draggable NUI (position saved per player, double-click header or ↺ to reset) - Recipe categories, locked recipes shown wit

Source: https://github.com/Rexshack-RedM/rsg-crafting

**Dependencies:** `rsg-core`, `rsg-inventory`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-crafting']:Name)

**server:** `GetCraftingRecipes()`, `GetPlayerCraftingXP(src)`, `GivePlayerCraftingXP(src, amount)`, `SendCraftingLog(logType, title, description, src, extra)`

**client:** `OpenCraftingBook()`

## Net events registered

**server:** `rsg-crafting:server:cancelCrafting`

**client:** `rsg-crafting:client:openBook`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-crafting:server:finishCrafting`, `rsg-crafting:server:getRecipes`, `rsg-crafting:server:startCrafting`
