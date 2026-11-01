--=========================== NUI CALL BACKS  ===========================--
RegisterNUICallback('NUIFocusOff', NUI_SERVICE.FOCUS.OFF)
RegisterNUICallback('DropItemMoney', NUI_SERVICE.CURRENCY.DROP_MONEY)
RegisterNUICallback('DropItemGold', NUI_SERVICE.CURRENCY.DROP_GOLD)
RegisterNUICallback('DropItemRoll', NUI_SERVICE.CURRENCY.DROP_ROLL)
RegisterNUICallback('DropItemStandard', NUI_SERVICE.ITEM.DROP)
RegisterNUICallback('DropItemWeapon', NUI_SERVICE.WEAPON.DROP)
RegisterNUICallback('DropItemAdvanced', NUI_SERVICE.SHARED.PLACE)
RegisterNUICallback('UseItem', NUI_SERVICE.SHARED.USE)
RegisterNUICallback('sound', NUI_SERVICE.SOUND.PLAY)
RegisterNUICallback('GiveItem', NUI_SERVICE.SHARED.GIVE)
RegisterNUICallback('UnequipWeapon', NUI_SERVICE.WEAPON.UNEQUIP)
RegisterNUICallback('TakeFromCustom', NUI_SERVICE.INVENTORY.TAKE_FROM_SECONDARY)
RegisterNUICallback('MoveToCustom', NUI_SERVICE.INVENTORY.MOVE_TO_SECONDARY)
RegisterNUICallback("TakeFromPlayer", NUI_SERVICE.INVENTORY.TAKE_FROM_PLAYER)
RegisterNUICallback("MoveToPlayer", NUI_SERVICE.INVENTORY.MOVE_TO_PLAYER)
RegisterNUICallback('getActionsConfig', NUI_SERVICE.INVENTORY.GET_GROUPS)
RegisterNUICallback('requestHandCraftingRecipes', NUI_SERVICE.CRAFTING.REQUEST_RECIPES)
RegisterNUICallback('handCraftingExecute', NUI_SERVICE.CRAFTING.CRAFT_ITEM)
RegisterNUICallback('inventorySaddle', NUI_SERVICE.SADDLE.OPEN)
RegisterNUICallback('ContextMenu', NUI_SERVICE.INVENTORY.CONTEXT_MENU)
RegisterNUICallback('TransferLimitExceeded', NUI_SERVICE.INVENTORY.TRANSFER_EXCEEDED)
RegisterNUICallback('SaveInventoryLayout', NUI_SERVICE.INVENTORY.SAVE_LAYOUT)
RegisterNUICallback('SaveHotbar', NUI_SERVICE.HOTBAR.SAVE_LAYOUT)
RegisterNUICallback('SaveHotbarPosition', NUI_SERVICE.HOTBAR.SAVE_POSITION)
RegisterNUICallback('addWeaponAttachment', NUI_SERVICE.WEAPON.ADD_COMPONENT)
RegisterNUICallback('removeWeaponAttachment', NUI_SERVICE.WEAPON.REMOVE_COMPONENT)
RegisterNUICallback('inspection', NUI_SERVICE.WEAPON.INSPECT)


--========================================================================--
-- shared
RegisterNetEvent("vorp_inventory:CloseInv")
AddEventHandler("vorp_inventory:CloseInv", NUI_SERVICE.INVENTORY.CLOSE)

-- dont know why this is here
AddEventHandler("vorp_inventory:Client:DisableInventory", NUI_SERVICE.INVENTORY.DISABLE)


RegisterNetEvent("vorp_inventory:blockInventory")
AddEventHandler("vorp_inventory:blockInventory", NUI_SERVICE.INVENTORY.DISABLE)

-- server
RegisterNetEvent("vorp_inventory:ProcessingReady", NUI_SERVICE.INVENTORY.PROCESSING_PAYMENT)
RegisterNetEvent("vorp_inventory:OpenInv", NUI_SERVICE.INVENTORY.OPEN)
RegisterNetEvent("vorp_inventory:OpenCustomInv", NUI_SERVICE.INVENTORY.OPEN_SECONDARY)
RegisterNetEvent("vorp_inventory:CloseCustomInv", NUI_SERVICE.INVENTORY.CLOSE)
RegisterNetEvent("vorp_inventory:ReloadCustomInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNetEvent("vorp_inventory:OpenPlayerInventory", NUI_SERVICE.INVENTORY.OPEN_PLAYER)
RegisterNetEvent("vorp_inventory:server:CacheImages", NUI_SERVICE.INVENTORY.CACHE_IMAGES)
RegisterNetEvent("vorp_inventory:client:secondaryItemAdded", NUI_SERVICE.SHARED.SECONDARY.ITEM_ADDED)
RegisterNetEvent("vorp_inventory:client:secondaryItemRemoved", NUI_SERVICE.SHARED.SECONDARY.ITEM_REMOVED)
RegisterNetEvent("vorp_inventory:client:secondaryItemUpdated", NUI_SERVICE.SHARED.SECONDARY.ITEM_UPDATED)

-- SYN SCRIPT EVENTS
-- Store Module
RegisterNetEvent("vorp_inventory:OpenStoreInventory")
AddEventHandler("vorp_inventory:OpenStoreInventory", NUIService.OpenStoreInventory)
RegisterNetEvent("vorp_inventory:ReloadStoreInventory")
AddEventHandler("vorp_inventory:ReloadStoreInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback('TakeFromStore', NUIService.NUITakeFromStore)
RegisterNUICallback('MoveToStore', NUIService.NUIMoveToStore)

-- Horse Module
RegisterNetEvent("vorp_inventory:OpenHorseInventory")
AddEventHandler("vorp_inventory:OpenHorseInventory", NUIService.OpenHorseInventory)
RegisterNetEvent("vorp_inventory:ReloadHorseInventory")
AddEventHandler("vorp_inventory:ReloadHorseInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback('TakeFromHorse', NUIService.NUITakeFromHorse)
RegisterNUICallback('MoveToHorse', NUIService.NUIMoveToHorse)

-- Steal
RegisterNetEvent("vorp_inventory:OpenstealInventory")
AddEventHandler("vorp_inventory:OpenstealInventory", NUIService.OpenstealInventory)
RegisterNetEvent("vorp_inventory:ReloadstealInventory")
AddEventHandler("vorp_inventory:ReloadstealInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback('TakeFromsteal', NUIService.NUITakeFromsteal)
RegisterNUICallback('MoveTosteal', NUIService.NUIMoveTosteal)

-- Cart Module
RegisterNetEvent("vorp_inventory:OpenCartInventory")
AddEventHandler("vorp_inventory:OpenCartInventory", NUIService.OpenCartInventory)
RegisterNetEvent("vorp_inventory:ReloadCartInventory")
AddEventHandler("vorp_inventory:ReloadCartInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback('TakeFromCart', NUIService.NUITakeFromCart)
RegisterNUICallback('MoveToCart', NUIService.NUIMoveToCart)

-- House Module
RegisterNetEvent("vorp_inventory:OpenHouseInventory")
AddEventHandler("vorp_inventory:OpenHouseInventory", NUIService.OpenHouseInventory)
RegisterNetEvent("vorp_inventory:ReloadHouseInventory")
AddEventHandler("vorp_inventory:ReloadHouseInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback('TakeFromHouse', NUIService.NUITakeFromHouse)
RegisterNUICallback('MoveToHouse', NUIService.NUIMoveToHouse)


--Hideout Module
RegisterNetEvent("vorp_inventory:OpenHideoutInventory")
AddEventHandler("vorp_inventory:OpenHideoutInventory", NUIService.OpenHideoutInventory)

RegisterNetEvent("vorp_inventory:ReloadHideoutInventory")
AddEventHandler("vorp_inventory:ReloadHideoutInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback("TakeFromHideout", NUIService.NUITakeFromHideout)
RegisterNUICallback("MoveToHideout", NUIService.NUIMoveToHideout)

-- Clan Module
RegisterNetEvent("vorp_inventory:OpenClanInventory")
AddEventHandler("vorp_inventory:OpenClanInventory", NUIService.OpenClanInventory)
RegisterNetEvent("vorp_inventory:ReloadClanInventory")
AddEventHandler("vorp_inventory:ReloadClanInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback("TakeFromClan", NUIService.NUITakeFromClan)
RegisterNUICallback("MoveToClan", NUIService.NUIMoveToClan)

-- Container Module
RegisterNetEvent("vorp_inventory:OpenContainerInventory")
AddEventHandler("vorp_inventory:OpenContainerInventory", NUIService.OpenContainerInventory)
RegisterNetEvent("vorp_inventory:ReloadContainerInventory")
AddEventHandler("vorp_inventory:ReloadContainerInventory", NUI_SERVICE.INVENTORY.RELOAD)
RegisterNUICallback("TakeFromContainer", NUIService.NUITakeFromContainer);
RegisterNUICallback("MoveToContainer", NUIService.NUIMoveToContainer);
