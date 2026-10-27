local Core <const> = exports.vorp_core:GetCore()
local LIB <const> = Import "/config"
local CONFIG <const> = LIB.CONFIG --[[@as vorp_housing_config]]
local Inventory <const> = exports.vorp_inventory


local function registerHouse(source, character)
    local charId <const> = character.charIdentifier
    for index, house in ipairs(CONFIG.HOUSES) do
        local isOwner <const> = house.OWNERS[charId]
        if isOwner then
            SetTimeout(5000, function()
                if isOwner.DOOR then
                    for _, door in ipairs(house.DOORS) do
                        exports.vorp_doorlocks:updateDoorPermission(source, door, true)
                    end
                end

                TriggerClientEvent("vorp_housing:Client:RegisterHouse", source, index, charId)
            end)

            if isOwner.STORAGE then
                for _, storage in ipairs(house.STORAGES) do
                    local prefix <const> = "house_" .. storage.ID
                    local isStorageRegistered <const> = Inventory:isCustomInventoryRegistered(prefix)
                    if not isStorageRegistered then
                        Inventory:registerInventory({
                            id = prefix,
                            name = storage.LABEL,
                            limit = storage.MAX_SLOTS,
                            acceptWeapons = storage.WEAPONS,
                            shared = storage.SHARED, -- inventory is shared with owners of the house or should each have their own ?
                            ignoreItemStackLimit = true,
                            whitelistItems = false,
                            UsePermissions = false,
                            UseBlackList = #storage.BLACKLISTED_ITEMS > 0,
                            whitelistWeapons = false,
                            webhook = "" -- add here a webhook to monitor the houses inventories
                        })

                        if #storage.BLACKLISTED_ITEMS > 0 then
                            for _, item in ipairs(storage.BLACKLISTED_ITEMS) do
                                exports.vorp_inventory:BlackListCustomAny(prefix, item)
                            end
                        end
                    end
                end
            end
        end
    end
end

AddEventHandler("vorp:SelectedCharacter", function(source, character)
    if CONFIG.DEV_MODE then return end
    -- needs this to change door permissions when registering house
    repeat Wait(1000) until Player(source).state.IsInSession
    registerHouse(source, character)
end)

-- HERE WE HANDLE OPENING STORAGES FOR THE HOUSE
RegisterServerEvent("vorp_housing:Server:OpenStorage", function(index, storageIndex)
    local _source <const> = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    local character <const> = user.getUsedCharacter
    local charId <const> = character.charIdentifier

    local house <const> = CONFIG.HOUSES[index]
    if not house then return print("House not found") end

    local isOwner <const> = house.OWNERS[charId]
    if not isOwner then return print(CONFIG.TRANSLATION.not_owner) end

    if not isOwner.STORAGE then return print("Player is not allowed to access storages") end

    local houseCoords <const> = house.POSITION
    local pedCoords <const> = GetEntityCoords(GetPlayerPed(_source))
    if #(pedCoords - houseCoords) > 10.0 then return print("Player is not close to the house") end

    local storage <const> = house.STORAGES[storageIndex]
    if not storage then return print("Storage not found") end

    local location <const> = storage.LOCATION
    local distance <const> = #(pedCoords - location)
    if distance > 3.0 then return print("Player is not close to this storage") end

    local prefix <const> = "house_" .. storage.ID
    local isStorageRegistered <const> = Inventory:isCustomInventoryRegistered(prefix)
    if not isStorageRegistered then return print("Storage is not registered in the inventory") end

    Inventory:openInventory(_source, prefix)
end)

RegisterServerEvent("vorp_housing:Server:OpenWardrobe", function(index)
    local _source <const> = source
    local config <const> = CONFIG.HOUSES[index]
    if not config then
        return print("House not found")
    end

    if not config.WARDROBE.ENABLE then
        return print("Wardrobe is not enabled for this house")
    end
    local wardrobeCoords <const> = config.WARDROBE.LOCATION
    local pedCoords <const> = GetEntityCoords(GetPlayerPed(_source))
    if #(pedCoords - wardrobeCoords) > 10.0 then
        return print("Player is not close to this wardrobe")
    end

    local result <const> = exports.vorp_character:OpenOutfitsMenu(_source)
    if not result then return print("Failed to open wardrobe") end
end)


--FOR TESTS
if CONFIG.DEV_MODE then
    RegisterServerEvent("vorp_housing:Server:DevMode", function()
        local _source <const> = source
        local user <const> = Core.getUser(_source)
        if not user then return end
        local character <const> = user.getUsedCharacter
        registerHouse(_source, character)
    end)

    RegisterCommand(CONFIG.COMMAND, function(source)
        local user <const> = Core.getUser(source)
        if not user then return end

        local group <const> = user.getGroup
        if group ~= "admin" then return Core.NotifyObjective(CONFIG.TRANSLATION.not_admin, 5000) end

        TriggerClientEvent("vorp_housing:Client:ShowHouses", source)
    end, false)
end
