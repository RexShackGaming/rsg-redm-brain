-- PROCESSING USERS MAKING TRANSACTIONS
local PROCESSING_USERS <const> = {}

math.randomseed(GetGameTimer())
local SvUtils = {

    GENERATE_UNIQUE_ID = function()
        local time = os.time()
        local randomNum = math.random(1000000, 9999999)
        return tostring(time) .. tostring(randomNum)
    end,

    DISCORD_LOG = function(data)
        CORE.AddWebhook(data.title, data.webhook, data.description, data.color, data.name)
    end,

    WEAPONS = {
        GET_ALL_BY_NAME = function(invId, name)
            local userWeapons <const> = USERS_WEAPONS[invId]
            local weapons <const> = {}

            if userWeapons == nil then
                return {}
            end

            for _, weapon in pairs(userWeapons) do
                if name == weapon:getName() then
                    weapons[#weapons + 1] = weapon
                end
            end

            return weapons
        end,

        GENERATE_WEAPON_LABEL = function(name)
            return SHARED_DATA.WEAPONS[name] and SHARED_DATA.WEAPONS[name].Name or ""
        end,

        FILTER_WEAPONS_SERIAL_NUMBER = function(name)
            return SHARED_DATA.WEAPONS[name] and SHARED_DATA.WEAPONS[name].NoSerialNumber
        end,
        GENERATE_SERIAL_NUMBER = function(name)
            if SV_UTILS.WEAPONS.FILTER_WEAPONS_SERIAL_NUMBER(name) then
                return ""
            end
            local timeStamp = os.time()
            local randomNumber = math.random(1000, 9999)
            return string.format("%s-%s", timeStamp, randomNumber)
        end,
        GET_WEAPON_WEIGHT = function(name)
            local weaponName = nil
            if type(name) == "number" then
                for _, value in pairs(SHARED_DATA.WEAPONS) do
                    if joaat(value.HashName) == name then
                        weaponName = value.HashName
                        break
                    end
                end
            else
                weaponName = name
            end
            return SHARED_DATA.WEAPONS[weaponName] and SHARED_DATA.WEAPONS[weaponName].Weight or 1
        end,
    },
    ITEMS = {
        GET_ALL_BY_NAME = function(invId, identifier, name)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            local items <const> = {}

            if not userInventory then
                return items
            end

            for _, item in pairs(userInventory) do
                if name == item:getName() then
                    items[#items + 1] = item
                end
            end

            return items
        end,

        GET_ITEM = function(invId, identifier, name)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then return nil end

            for _, item in pairs(userInventory) do
                if name == item:getName() then
                    return item
                end
            end

            return nil
        end,

        GET_ITEM_BY_METADATA = function(invId, identifier, name, metadata)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then
                return nil
            end

            if metadata then
                for _, item in pairs(userInventory) do
                    if name == item:getName() and SHARED_UTILS.TABLE_EQUALS(metadata, item:getMetadata()) then
                        return item
                    end
                end
            else
                -- this returns the first item that matches the name, not carring for metadata
                for _, item in pairs(userInventory) do
                    if name == item:getName() then
                        return item
                    end
                end
            end

            return nil
        end,

        GET_ITEM_NO_METADATA = function(invId, identifier, name)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then return nil end

            for _, item in pairs(userInventory) do
                if name == item:getName() and not next(item:getMetadata()) then
                    return item
                end
            end

            return nil
        end,

        GET_ITEM_COUNT = function(invId, identifier, name, percentage)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]

            if not userInventory then return 0 end

            --get item count  by percentage , this allows to control get expired items or at a desired percentage
            local count = 0
            for _, item in pairs(userInventory) do
                if percentage then
                    local expiredPercentage = true
                    -- items with decay detection
                    if percentage == 0 then
                        expiredPercentage = item:getPercentage() == 0
                    else
                        expiredPercentage = item:getPercentage() >= percentage
                    end

                    if name == item:getName() and expiredPercentage then
                        count = count + item:getCount()
                    end
                else
                    -- detect any items because if we change this it breaks other scripts that are using it wrong
                    if name == item:getName() then
                        -- by not allowing decay items in here we are getting the count of only normal items
                        -- in conjunction with subItem that will only delete items that dont have decay if decay detection is not passed this allows to function normal as before
                        count = count + item:getCount()
                    end
                end
            end

            return count
        end,

        GET_ITEM_MATCHING_METADATA = function(invId, identifier, name, metadata)
            local userInventory <const> = CUSTOM_INVENTORIES[invId].shared and USERS_ITEMS[invId] or USERS_ITEMS[invId][identifier]
            if not userInventory then return nil end

            for _, item in pairs(userInventory) do
                if name == item:getName() and SHARED_UTILS.TABLE_CONTAINS(item:getMetadata(), metadata) then
                    return item
                end
            end

            return nil
        end,

        DOES_ITEM_EXIST = function(itemName, api)
            if SERVER_ITEMS[itemName] then
                return SERVER_ITEMS[itemName]
            end
            print("[^2" .. api .. "7^] Item [^3" .. tostring(itemName) .. "^7] does not exist in DB.")
            return false
        end,
    },

    PROCESS = {
        ADD_USER = function(id)
            PROCESSING_USERS[id] = true
        end,
        USER_IN_PROCESSING = function(id)
            return PROCESSING_USERS[id]
        end,
        REMOVE_USER = function(id)
            PROCESSING_USERS[id] = nil
            TriggerClientEvent("vorp_inventory:ProcessingReady", id)
        end,
    }
}

SV_UTILS      = SvUtils


AddEventHandler("playerDropped", function()
    local _source = source
    PROCESSING_USERS[_source] = nil
end)
