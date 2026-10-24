# rsg-backpacks

Version 3.0.3. RSG Backpacks: wearable backpacks with stashes and belt/back attachments (lanterns, lasso, machete, quiver)

Wearable backpacks with persistent stashes and belt/back attachments for **RedM** on **RSG-Core**. This resource merges and replaces: - `hdrp-backpack` (backpacks, stashes)

Source: https://github.com/Rexshack-RedM/rsg-backpacks

**Dependencies:** `rsg-core`, `rsg-inventory`, `ox_lib`, `oxmysql`

## Exports (call as exports['rsg-backpacks']:Name)

**server:** `IsBackpackItem(itemName)`

## Net events registered

**server:** `rsg-inventory:server:SetInventoryData`, `rsg-inventory:server:closeInventory`

**client:** `rsg-backpacks:client:wear`, `rsg:client:refreshSkin`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`

**client:** `RSGCore:Client:OnPlayerUnload`

## Commands (RegisterCommand)

**client:** `/removebackpack`

## Public (table) functions

**client/main.lua:** `BP.LoadModel(model, timeout)`

**server/utils.lua:** `BP.Notify(src, nType, titleKey, descKey, ...)`, `BP.RateLimited(src, key, ms)`, `BP.GetHeldBackpack(Player, serial)`

## Database tables

`player_backpack`
