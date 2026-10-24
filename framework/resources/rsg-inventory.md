# rsg-inventory

Version 3.0.7. rsg-inventory

Slot/weight inventory for RSG-Core with hotbar, persistent stashes, ground drops, shops and a legacy-compatible API. 1. Start order: `oxmysql`, `ox_lib`, `rsg-core`, then `rsg-inventory`. 2. Item images go in `html/images/` (same PNGs as the original rsg-inventory).

Source: https://github.com/Rexshack-RedM/rsg-inventory

**Dependencies:** `rsg-core`, `ox_lib`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-inventory']:Name)

**server:** `AddItem(target, name, amount, info, slot, reason)`, `CanAddItem(target, name, amount)`, `CanCarry(target, name, amount)`, `ClearInventory(target, keep)`, `ClearStash(id)`, `CloseInventory(src)`, `CreateDrop(coords, items)`, `CreateInventory(id, data)`, `CreateShop(data)`, `DeleteInventory(id)`, `DoesShopExist(name)`, `ForceDropItem(src, item, amount, info, reason)`, `GetFirstSlotByItem(items, name)`, `GetFreeWeight(target)`, `GetInventory(target)`, `GetItemByName(target, name)`, `GetItemBySlot(target, slot)`, `GetItemCount(target, name)`, `GetItemWeight(name)`, `GetItemsByName(target, name)`, `GetSlots(target)`, `GetSlotsByItem(items, name)`, `GetTotalWeight(items)`, `HasItem(target, items, amount)`, `LoadInventory(_, citizenid)`, `OpenInventory(src, id, data)`, `OpenInventoryById(src, targetId)`, `OpenPlayerInventory(src, targetId)`, `OpenShop(src, name)`, `OpenStash(src, id, opts)`, `RegisterStash(id, opts)`, `RemoveItem(target, name, amount, slot, reason)`, `RestockShop(name, percentage)`, `SaveInventory(srcOrData, offline)`, `SaveStash(id)`, `SetInventory(src, items)`, `SetItemData(src, itemName, key, val)`, `SetItemInfo(target, slot, info)`, `UseItem(a, b, c)`

**client:** `CloseInventory()`, `GetItemCount(name)`, `HasItem(items, amount)`, `IsOpen()`

## Net events registered

**server:** `rsg-inventory:server:close`, `rsg-inventory:server:drop`, `rsg-inventory:server:give`, `rsg-inventory:server:move`, `rsg-inventory:server:open`, `rsg-inventory:server:useItem`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-inventory:client:ItemBox`, `rsg-inventory:client:addDrop`, `rsg-inventory:client:checkWeapon`, `rsg-inventory:client:close`, `rsg-inventory:client:giveAnim`, `rsg-inventory:client:open`, `rsg-inventory:client:refresh`, `rsg-inventory:client:removeDrop`

## Event handlers

**server:** `RSGCore:Server:PlayerLoaded`, `txAdmin:events:serverShuttingDown`

## Callbacks (lib.callback)

**server:** `rsg-inventory:server:getDrops`

## Public (table) functions

**server/main.lua:** `API.AddItem(target, name, amount, info, slot, reason)`, `API.RemoveItem(target, name, amount, slot, reason)`, `API.GetItemCount(target, name)`, `API.HasItem(target, items, amount)`, `API.CanCarry(target, name, amount)`, `API.GetItemBySlot(target, slot)`, `API.GetItemByName(target, name)`, `API.SetItemInfo(target, slot, info)`, `API.ClearInventory(target, keep)`, `API.GetInventory(target)`, `API.RegisterStash(id, opts)`, `API.SaveStash(id)`, `API.CreateDrop(coords, items)`, `API.OpenStash(src, id, opts)`, `API.OpenInventory(src, id, data)`, `API.OpenPlayerInventory(src, targetId)`, `API.CloseInventory(src)`, `API.UseItem(a, b, c)`

**server/shops.lua:** `Shops.CreateShop(data)`, `Shops.OpenShop(src, name)`, `Shops.DoesShopExist(name)`, `Shops.RestockShop(name, percentage)`, `Shops.Buy(src, shop, slot, amount, toSlot)`, `Shops.Sell(src, shop, playerSlot, amount)`

## Database tables

`inventories`, `shop_stock`
