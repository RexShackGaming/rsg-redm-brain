RegisterNetEvent("vorpInventory:giveItemsTable", INVENTORY_SERVICE.PROCESS_ITEMS)
RegisterNetEvent("vorpInventory:giveInventory", INVENTORY_SERVICE.GET_INVENTORY)
RegisterNetEvent("vorpInventory:giveLoadout", INVENTORY_SERVICE.GET_LOADOUT)
RegisterNetEvent("vorpInventory:receiveItem", INVENTORY_SERVICE.RECEIVE_ITEM)
RegisterNetEvent("vorpInventory:removeItem", INVENTORY_SERVICE.REMOVE_ITEM)
RegisterNetEvent("vorpInventory:receiveWeapon", INVENTORY_SERVICE.RECEIVE_WEAPON)
RegisterNetEvent("vorpInventory:setWeaponSerialNumber", INVENTORY_SERVICE.SET_WEAPON_SERIAL_NUMBER)
RegisterNetEvent("vorpInventory:setWeaponCustomLabel", INVENTORY_SERVICE.SET_WEAPON_CUSTOM_LABEL)
RegisterNetEvent("vorpInventory:setWeaponCustomDesc", INVENTORY_SERVICE.SET_WEAPON_CUSTOM_DESC)
RegisterNetEvent("vorpInventory:setWeaponUsed", INVENTORY_SERVICE.SET_WEAPON_USED)

--PICKUPS
RegisterNetEvent("vorpInventory:sharePickupClient", PICKUP_SERVICE.SHARE_PICKUP)
RegisterNetEvent("vorpInventory:shareMoneyPickupClient", PICKUP_SERVICE.SHARE_MONEY)
RegisterNetEvent("vorpInventory:shareGoldPickupClient", PICKUP_SERVICE.SHARE_GOLD)
RegisterNetEvent("vorpInventory:shareRollPickupClient", PICKUP_SERVICE.SHARE_ROLL)
RegisterNetEvent("vorpInventory:playerPickUpAnim", PICKUP_SERVICE.PLAY_ANIM)

--shared
RegisterNetEvent("vorp:SelectedCharacter")
AddEventHandler("vorp:SelectedCharacter", INVENTORY_SERVICE.ON_SELECTED_CHARACTER)

CORE.Callback.Register("vorp_inventory:callback:wantToGiveItems", INVENTORY_SERVICE.ASK_TO_GIVE_ITEMS)
