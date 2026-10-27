-- exports

exports('closeInventory', function()
    return NUI_SERVICE.INVENTORY.CLOSE()
end)

exports('setHotbarVisible', function(visible)
    return NUI_SERVICE.HOTBAR.SET_VISIBLE(visible)
end)

exports('getWeaponDefaultWeight', function(hash)
    return UTILS.WEAPONS.GET_DEFAULT_WEIGHT(hash)
end)

exports('getWeaponDefaultDesc', function(hash)
    return UTILS.WEAPONS.GET_DEFAULT_DESC(hash)
end)

exports('getWeaponDefaultLabel', function(hash)
    return UTILS.WEAPONS.GET_DEFAULT_LABEL(hash)
end)

exports('getWeaponName', function(hash)
    return UTILS.WEAPONS.GET_DEFAULT_NAME(hash)
end)

exports('getWeaponsDefaultData', function(request)
    return UTILS.WEAPONS.GET_DEFAULT_DATA(request)
end)

exports('getWeaponAmmoTypes', function(group)
    return SHARED_DATA.AMMO_TYPES[group]
end)

exports('getAmmoLabel', function(ammo)
    return UTILS.AMMO.GET_DEFAULT_LABEL(ammo)
end)

exports('getInventoryItem', function(name)
    return UTILS.INVENTORY.GET_ITEM(name)
end)

exports('getInventoryItems', function()
    return UTILS.INVENTORY.GET_ITEMS()
end)

exports("getServerItem", function(data)
    return UTILS.INVENTORY.GET_SERVER_ITEM(data)
end)
