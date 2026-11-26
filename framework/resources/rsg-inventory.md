# rsg-inventory

Version 3.6.0. rsg-inventory

Slot/weight inventory for the RSG Framework (rsg-core) with a hotbar, persistent stashes, ground drops, shops with persistent stock, category filters, automatic coin exchange and a legacy-compatible API so existing RSG scripts keep working. **Version:** 3.6.0 · **Requires:** `rsg-core` 3.5.0 or newer, `oxmysql` · **ox_lib:** not required > Developers: see **[DOCS.md](DOCS.md)** for the full API, d

Source: https://github.com/Rexshack-RedM/rsg-inventory

**Dependencies:** `rsg-core`, `oxmysql`

Has NUI (`ui_page`).

## Exports (call as exports['rsg-inventory']:Name)

**server:** `AddCapacityBonus(src, key, slots, weight)`, `AddItem(target, name, amount, info, slot, reason)`, `AdjustQuality(target, slot, delta, removeAtZero)`, `CanAddItem(target, name, amount)`, `CanCarry(target, name, amount)`, `ClearInventory(target, keep)`, `ClearStash(id)`, `CloseInventory(src)`, `CreateDrop(coords, items)`, `CreateInventory(id, data)`, `CreateShop(data)`, `DamageItem(target, slot, amount, removeAtZero)`, `DeleteInventory(id)`, `DoesShopExist(name)`, `ForceDropItem(src, item, amount, info, reason)`, `GetCapacityBonus(src)`, `GetFirstSlotByItem(items, name)`, `GetFreeWeight(target)`, `GetInventory(target)`, `GetItemByName(target, name)`, `GetItemBySlot(target, slot)`, `GetItemCount(target, name)`, `GetItemWeight(name)`, `GetItemsByName(target, name)`, `GetSlots(target)`, `GetSlotsByItem(items, name)`, `GetStashHistory(id, limit)`, `GetTotalWeight(items)`, `HasItem(target, items, amount)`, `LoadInventory(_, citizenid)`, `OpenInventory(src, id, data)`, `OpenInventoryById(src, targetId)`, `OpenPlayerInventory(src, targetId)`, `OpenShop(src, name)`, `OpenStash(src, id, opts)`, `RegisterStash(id, opts)`, `RemoveCapacityBonus(src, key)`, `RemoveItem(target, name, amount, slot, reason)`, `RepairItem(target, slot, amount)`, `RestockShop(name, percentage)`, `SaveInventory(srcOrData, offline)`, `SaveStash(id)`, `SetInventory(src, items)`, `SetItemData(src, itemName, key, val)`, `SetItemInfo(target, slot, info)`, `TradeItems(a, b, offerA, offerB)`, `UseItem(a, b, c)`

**client:** `CloseInventory()`, `GetItemCount(name)`, `HasItem(items, amount)`, `IsOpen()`

## Net events registered

**server:** `rsg-inventory:server:adminOpenStash`, `rsg-inventory:server:close`, `rsg-inventory:server:drop`, `rsg-inventory:server:give`, `rsg-inventory:server:move`, `rsg-inventory:server:open`, `rsg-inventory:server:sort`, `rsg-inventory:server:stashAction`, `rsg-inventory:server:syncDrops`, `rsg-inventory:server:takeAll`, `rsg-inventory:server:trash`, `rsg-inventory:server:useItem`

**client:** `RSGCore:Client:OnPlayerLoaded`, `RSGCore:Client:OnPlayerUnload`, `rsg-inventory:client:ItemBox`, `rsg-inventory:client:addDrop`, `rsg-inventory:client:checkWeapon`, `rsg-inventory:client:close`, `rsg-inventory:client:giveAnim`, `rsg-inventory:client:open`, `rsg-inventory:client:refresh`, `rsg-inventory:client:removeDrop`, `rsg-inventory:client:stashBrowser`

## Event handlers

**server:** `RSGCore:Server:OnPlayerUnload`, `RSGCore:Server:PlayerLoaded`, `rsg-inventory:stashAction`, `txAdmin:events:serverShuttingDown`

## Callbacks (RSGCore.Functions.CreateCallback)

**server:** `rsg-inventory:server:adminStashHistory`, `rsg-inventory:server:adminStashes`, `rsg-inventory:server:getNearbyPlayers`

## Commands (RSGCore.Commands.Add)

**server:** `/clearinv`, `/giveitem`, `/stashes`, `/stashlog`, `/viewinv`

## Public (table) functions

**server/main.lua:** `API.AddItem(target, name, amount, info, slot, reason)`, `API.RemoveItem(target, name, amount, slot, reason)`, `API.GetItemCount(target, name)`, `API.HasItem(target, items, amount)`, `API.CanCarry(target, name, amount)`, `API.GetItemBySlot(target, slot)`, `API.GetItemByName(target, name)`, `API.SetItemInfo(target, slot, info)`, `API.AdjustQuality(target, slot, delta, removeAtZero)`, `API.RepairItem(target, slot, amount)`, `API.DamageItem(target, slot, amount, removeAtZero)`, `API.ClearInventory(target, keep)`, `API.GetInventory(target)`, `API.RegisterStash(id, opts)`, `API.SaveStash(id)`, `API.CreateDrop(coords, items)`, `API.AddCapacityBonus(src, key, slots, weight)`, `API.RemoveCapacityBonus(src, key)`, `API.GetCapacityBonus(src)`, `API.OpenStash(src, id, opts)`, `API.OpenInventory(src, id, data)`, `API.OpenPlayerInventory(src, targetId)`, `API.CloseInventory(src)`, `API.UseItem(a, b, c)`, `API.TradeItems(a, b, offerA, offerB)`, `InvCore.WaitForDatabase()`, `API.GetStashHistory(id, limit)`

**server/shops.lua:** `Shops.CreateShop(data)`, `Shops.OpenShop(src, name)`, `Shops.DoesShopExist(name)`, `Shops.RestockShop(name, percentage)`, `Shops.Buy(src, shop, slot, amount, toSlot)`, `Shops.Sell(src, shop, playerSlot, amount)`

## Database tables

`inventories`, `inventory_drops`, `inventory_stash_log`, `shop_stock`
