# rsg-inventory exports
Server (target = player src or stash/drop id):
- `AddItem(target, name, amount, info?, slot?, reason?)` → `ok, err`. Legacy `(target, name, amount, slot, info)` order auto-detected. Fires ItemBox and logs automatically.
- `RemoveItem(target, name, amount, slot?, reason?)`, `CanAddItem(target, name, amount)` (check before adding), `HasItem(target, items, amount)`, `GetItemCount`, `GetItemByName`, `GetItemBySlot`, `GetItemsByName`, `SetItemInfo`/`SetItemData`, `GetInventory`, `ClearInventory`, `GetTotalWeight`, `GetFreeWeight`, `GetSlots`.
- Stashes: `OpenInventory(src, id, {maxweight, slots, label})`, `OpenInventoryById`, `CreateInventory`, `DeleteInventory`, `ClearStash`, `LoadInventory`, `SaveInventory`, `ForceDropItem`.
- Shops: `CreateShop({name, label, coords, items={...}})`, `OpenShop(src, name)`, `DoesShopExist`, `RestockShop`.
Client: `HasItem(items, amount)`, `GetItemCount(name)`, `CloseInventory()`, `IsOpen()`.
Item notification: `TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[name], 'add'|'remove', amount)` (only needed when not using AddItem/RemoveItem).
