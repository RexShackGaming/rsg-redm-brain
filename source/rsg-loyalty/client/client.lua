local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

if not Config.Enabled then return end

local playerLoyalty = { loyalty_points = 0, lifetime_points = 0 }
local isLoggedIn = false
local nuiOpen = false
local rewardPayload -- built once on first open (shared items must be loaded)

---------------------------------------------------------------------
-- Session
---------------------------------------------------------------------
local function startSession()
    isLoggedIn = true
    TriggerServerEvent('rsg-loyalty:server:playerLoaded')
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    startSession()
end)

-- resume after a resource restart without needing a relog
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then
        startSession()
    end
end)

local function closeLoyaltyNUI()
    if not nuiOpen then return end
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'closeUI' })
end

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    closeLoyaltyNUI()
end)

-- earning heartbeat; the server decides whether/how many points are awarded
if Config.Loyalty.EnableEarning ~= false then CreateThread(function()
    while true do
        Wait(60000)
        if isLoggedIn then
            TriggerServerEvent('rsg-loyalty:server:earnPoints')
        end
    end
end) end

---------------------------------------------------------------------
-- Server -> client data
---------------------------------------------------------------------
RegisterNetEvent('rsg-loyalty:client:updateLoyaltyData', function(data)
    if type(data) ~= 'table' then return end
    playerLoyalty = data
    SendNUIMessage({
        type = 'updatePoints',
        currentPoints = data.loyalty_points or 0,
        lifetimePoints = data.lifetime_points or 0,
    })
end)

RegisterNetEvent('rsg-loyalty:client:leaderboardData', function(data)
    SendNUIMessage({
        type = 'leaderboardData',
        topCurrent = data.topCurrent,
        topLifetime = data.topLifetime,
    })
end)

---------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------
local function buildRewardPayload()
    local cash, items = {}, {}

    for i, reward in ipairs(Config.CashRewards) do
        cash[i] = {
            label = locale(reward.label),
            points = reward.points,
            amount = reward.amount,
            image = Config.Image .. (reward.image or 'dollar.png'),
        }
    end

    for i, reward in ipairs(Config.ItemRewards) do
        local itemData = RSGCore.Shared.Items[reward.item]
        items[i] = {
            label = locale(reward.label),
            points = reward.points,
            amount = reward.amount,
            image = Config.Image .. ((itemData and itemData.image) or reward.image or ''),
        }
    end

    return {
        cashRewards = cash,
        itemRewards = items,
        locale = {
            title = locale('loyalty_menu_title'),
            subtitle = locale('loyalty_subtitle'),
            close = locale('close'),
            currentPoints = locale('loyalty_points'),
            lifetimePoints = locale('lifetime_points'),
            redeemCash = locale('redeem_cash'),
            redeemItems = locale('redeem_items'),
            leaderboard = locale('leaderboard'),
            topCurrent = locale('top_current_points'),
            topLifetime = locale('top_lifetime_points'),
            points = locale('points'),
            costs = locale('costs'),
            redeem = locale('redeem'),
            needMore = locale('need_more_points'),
            ptsSuffix = locale('leaderboard_points_suffix'),
            currencySymbol = locale('currency_symbol'),
            itemMultiplier = locale('item_multiplier'),
            noEntries = locale('leaderboard_empty'),
        },
    }
end

-- close the menu if the player walks away from the NPC they opened it at
local function watchDistance(origin)
    if not origin then return end
    local maxDist = Config.Loyalty.MaxRedeemDistance or 5.0
    CreateThread(function()
        while nuiOpen do
            if #(GetEntityCoords(cache.ped) - origin) > maxDist then
                closeLoyaltyNUI()
                break
            end
            Wait(500)
        end
    end)
end

local function openLoyaltyNUI(origin)
    if not isLoggedIn or nuiOpen then return end
    rewardPayload = rewardPayload or buildRewardPayload()

    nuiOpen = true
    SendNUIMessage({
        type = 'openUI',
        currentPoints = playerLoyalty.loyalty_points or 0,
        lifetimePoints = playerLoyalty.lifetime_points or 0,
        cashRewards = rewardPayload.cashRewards,
        itemRewards = rewardPayload.itemRewards,
        locale = rewardPayload.locale,
    })
    SetNuiFocus(true, true)
    if type(origin) == 'vector3' then watchDistance(origin) end

    -- refresh in the background; NUI updates when the replies arrive
    TriggerServerEvent('rsg-loyalty:server:getLoyaltyData')
    TriggerServerEvent('rsg-loyalty:server:getLeaderboard')
end

RegisterNUICallback('redeemReward', function(data, cb)
    if nuiOpen and (data.type == 'cash' or data.type == 'item') then
        TriggerServerEvent('rsg-loyalty:server:redeem', data.type, tonumber(data.index))
    end
    cb({ ok = true })
end)

RegisterNUICallback('closeUI', function(_, cb)
    nuiOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNetEvent('rsg-loyalty:client:openloyaltyUI', openLoyaltyNUI)

if Config.UI.EnableCommand then
    RegisterCommand(Config.UI.OpenCommand, function() openLoyaltyNUI() end, false)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and nuiOpen then
        SetNuiFocus(false, false)
    end
end)
