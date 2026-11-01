local RSGCore = exports['rsg-core']:GetCoreObject()

-- Auction System Client
-- Handles NUI control, inventory snapshot and server communication.
-- All money/item logic is validated server-side; nothing here is trusted.

NUI = {}
local isOpen = false
local playerInventory = {}
local currentLocation = nil
local currentCoords = nil
local AUTO_CLOSE_DISTANCE = 6.0 -- UI closes if the player walks away from the auctioneer

-- Only the "ui.*" locale keys are sent to the NUI (built once)
local uiStrings
local function getUiStrings()
    if uiStrings then return uiStrings end
    uiStrings = {}
    for key, value in pairs(locale() or {}) do
        if key:sub(1, 3) == 'ui.' then uiStrings[key:sub(4)] = value end
    end
    return uiStrings
end

local function notify(description, nType, title)
    RSGCore.Functions.Notify({
        title = title or locale('notif_title_auction_house'),
        description = description,
        type = nType or 'inform',
        duration = Config.NotificationDuration or 5000
    })
end

-- ============================================
-- INVENTORY
-- ============================================

local function getItemImage(itemName)
    return 'nui://rsg-inventory/html/images/' .. itemName .. '.png'
end

local function refreshInventory()
    local items = {}
    local PlayerData = RSGCore.Functions.GetPlayerData()
    for slot, item in pairs(PlayerData and PlayerData.items or {}) do
        if item and item.amount and item.amount > 0 then
            local image = getItemImage(item.name)
            items[#items + 1] = {
                name = item.name,
                label = item.label or item.name,
                count = item.amount,
                slot = item.slot or slot,
                metadata = item.info or {},
                image = image,
                imageMeta = { url = image, itemName = item.name }
            }
        end
    end
    playerInventory = items
    return items
end

local function getInventoryItem(itemName, slot)
    for _, item in ipairs(playerInventory) do
        if item.name == itemName and (not slot or item.slot == slot) then return item end
    end
end

local function pushInventory()
    NUI.SendMessage('inventoryUpdated', { inventory = refreshInventory() })
end

-- ============================================
-- NUI HELPERS
-- ============================================

function NUI.SendMessage(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

function NUI.Open(data)
    if isOpen then return end

    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.citizenid then
        notify(locale('error_could_not_load_player'), 'error', locale('notif_title_error'))
        return
    end

    isOpen = true
    currentLocation = data and data.location
    currentCoords = data and data.coords

    local categories = {}
    for _, cat in ipairs(Config.Categories or {}) do
        categories[#categories + 1] = { id = cat.id, label = cat.label, icon = cat.icon or '📦', description = cat.description or '' }
    end

    local money = PlayerData.money or {}
    local charinfo = PlayerData.charinfo

    SetNuiFocus(true, true)
    NUI.SendMessage('open', {
        inventory = refreshInventory(),
        cashCents = Money.dollarsToCents(money.cash or 0),
        bankCents = Money.dollarsToCents(money.bank or 0),
        citizenid = data and data.playerToken or '', -- opaque server token matching the IDs in auction data
        locale = getUiStrings(),
        playerName = charinfo and (charinfo.firstname .. ' ' .. charinfo.lastname) or 'Unknown',
        feeConfig = Config.CreationFee or {},
        buyoutConfig = Config.Buyout or { enabled = false, minMultiplier = 1.5 },
        minBidIncrement = Config.MinBidIncrement or 0.05,
        minDuration = Config.MinDuration or 60,
        maxDuration = Config.MaxDuration or 604800,
        blacklist = Config.BlacklistedItems or {},
        categories = categories,
        location = currentLocation,
        locationLabel = data and data.locationLabel or currentLocation
    })

    TriggerServerEvent('auction:server:getAuctions', currentLocation)
    TriggerServerEvent('auction:server:getPendingCollections')

    -- Close automatically if the player walks off or dies with the UI open
    if currentCoords then
        CreateThread(function()
            while isOpen do
                local ped = PlayerPedId()
                if IsEntityDead(ped) or #(GetEntityCoords(ped) - currentCoords) > AUTO_CLOSE_DISTANCE then
                    NUI.Close()
                    break
                end
                Wait(1000)
            end
        end)
    end
end

function NUI.Close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    NUI.SendMessage('close')
end

-- ============================================
-- NUI CALLBACKS
-- ============================================

RegisterNUICallback('close', function(_, cb)
    NUI.Close()
    cb({ success = true })
end)

RegisterNUICallback('createAuction', function(data, cb)
    local item = getInventoryItem(data.itemName, tonumber(data.slot))
    if not item then
        return cb({ success = false, error = locale('error_item_not_in_inventory') })
    end
    if item.count < (tonumber(data.count) or 1) then
        return cb({ success = false, error = locale('error_insufficient_item_count') })
    end
    if not data.category or data.category == '' then
        return cb({ success = false, error = locale('error_select_category') })
    end

    -- Only intent is sent; the server resolves label, metadata, image and location itself.
    TriggerServerEvent('auction:server:createAuction', {
        itemName = data.itemName,
        slot = item.slot,
        count = data.count or 1,
        category = data.category,
        startingBid = data.startingBid,
        buyoutPrice = data.buyoutPrice,
        duration = data.duration
    })
    cb({ success = true, message = locale('notif_creating_auction') })
end)

RegisterNUICallback('placeBid', function(data, cb)
    if not data.auctionId or not data.amountCents then
        return cb({ success = false, error = locale('error_invalid_bid_data') })
    end
    TriggerServerEvent('auction:server:placeBid', data.auctionId, data.amountCents)
    cb({ success = true, message = locale('notif_placing_bid') })
end)

RegisterNUICallback('cancelAuction', function(data, cb)
    if not data.auctionId then
        return cb({ success = false, error = locale('error_invalid_auction_id') })
    end
    TriggerServerEvent('auction:server:cancelAuction', data.auctionId)
    cb({ success = true, message = locale('notif_cancelling_auction') })
end)

RegisterNUICallback('buyoutAuction', function(data, cb)
    if not data.auctionId then
        return cb({ success = false, error = locale('error_invalid_auction_id') })
    end
    TriggerServerEvent('auction:server:buyoutAuction', data.auctionId)
    cb({ success = true, message = locale('notif_processing_buyout') })
end)

RegisterNUICallback('collectItem', function(data, cb)
    if not data.auctionId or not data.itemName then
        return cb({ success = false, error = locale('error_invalid_item_data') })
    end
    TriggerServerEvent('auction:server:collectItem', data.auctionId, data.itemName)
    cb({ success = true, message = locale('notif_collecting_item') })
end)

RegisterNUICallback('searchAuctions', function(data, cb)
    if type(data) ~= 'table' then
        return cb({ success = false, error = locale('error_invalid_search') })
    end
    TriggerServerEvent('auction:server:searchAuctions', {
        query = data.query or '',
        page = data.page or 1,
        limit = data.limit or 10,
        filterOwn = data.filterOwn or false,
        category = data.category,
        location = currentLocation
    })
    cb({ success = true })
end)

-- Simple pass-through callbacks
local passthrough = {
    getPendingCollections = function() TriggerServerEvent('auction:server:getPendingCollections') end,
    collectMoney = function() TriggerServerEvent('auction:server:collectMoney') end,
    imageFailed = function(data)
        if Config.Debug and data and data.itemName then
            TriggerServerEvent('auction:server:reportMissingImage', data.itemName)
        end
    end,
}

for name, fn in pairs(passthrough) do
    RegisterNUICallback(name, function(data, cb)
        fn(data)
        cb({ success = true })
    end)
end

-- ============================================
-- SERVER EVENTS -> NUI
-- ============================================

-- Events that are forwarded to the NUI only while it is open
local forwarded = {
    ['auction:client:receiveAuctions'] = 'receiveAuctions',
    ['auction:client:receiveSearchResults'] = 'receiveSearchResults',
    ['auction:client:bidResult'] = 'bidResult',
    ['auction:client:buyoutResult'] = 'buyoutResult',
    ['auction:client:receivePendingCollections'] = 'receivePendingCollections',
    ['auction:client:balanceUpdated'] = 'balanceUpdated',
}

for event, action in pairs(forwarded) do
    RegisterNetEvent(event, function(data)
        if isOpen then NUI.SendMessage(action, data) end
    end)
end

RegisterNetEvent('auction:client:update', function(payload)
    if isOpen and type(payload) == 'table' then
        NUI.SendMessage(payload.action, payload.data)
    end
end)

RegisterNetEvent('auction:client:createResult', function(result)
    if not isOpen then return end
    NUI.SendMessage('createResult', result)
    if result.success then pushInventory() end
end)

RegisterNetEvent('auction:client:cancelResult', function(result)
    if not isOpen then return end
    NUI.SendMessage('cancelResult', result)
    if result.success then pushInventory() end
end)

RegisterNetEvent('auction:client:collectionResult', function(result)
    if not isOpen then return end
    NUI.SendMessage('collectionResult', result)
    if result.success and result.type == 'item' then pushInventory() end
end)

-- Auction events: shown in the NUI when it's open, otherwise as an rsg-core notification.
RegisterNetEvent('auction:client:notification', function(data)
    if type(data) ~= 'table' then return end
    if isOpen then
        NUI.SendMessage('notification', data)
        -- Something may now be waiting at the kiosk; refresh the Collect tab badge/list
        TriggerServerEvent('auction:server:getPendingCollections')
        return
    end

    local item, count = data.itemName or 'item', data.count or 1
    local amount = Money.format(data.amountCents or 0)

    if data.type == 'outbid' then
        notify(data.message or locale('notif_outbid', item, Money.format(data.newHighBidCents or 0)), 'warning', locale('notif_title_auction'))
    elseif data.type == 'won' then
        notify(locale(data.isBuyout and 'notif_won_desc_buyout' or 'notif_won_desc', item, count, amount), 'success',
            locale(data.isBuyout and 'notif_title_won_buyout' or 'notif_title_won'))
    elseif data.type == 'sold' then
        notify(locale(data.isBuyout and 'notif_sold_desc_buyout' or 'notif_sold_desc', item, count, amount), 'success',
            locale(data.isBuyout and 'notif_title_sold_buyout' or 'notif_title_sold'))
    elseif data.type == 'expired' then
        notify(locale('notif_expired_desc', item, count), 'inform', locale('notif_title_auction_expired'))
    elseif data.type == 'info' and data.message then
        notify(data.message, 'inform')
    end
end)

RegisterNetEvent('auction:client:webhookResult', function(data)
    notify(data.message or locale(data.success and 'cmd_webhook_success' or 'cmd_webhook_error'),
        data.success and 'success' or 'error', locale('notif_title_webhook_admin'))
end)

-- Close the UI cleanly if the resource restarts while it's open
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isOpen then
        isOpen = false
        SetNuiFocus(false, false)
    end
end)
