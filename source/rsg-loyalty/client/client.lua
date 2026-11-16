local RSGCore = exports['rsg-core']:GetCoreObject()

if not Config.Enabled then return end

local playerLoyalty = { loyalty_points = 0, lifetime_points = 0 }
local isLoggedIn = false
local nuiOpen = false
local uiFocus = false
local rewardPayload -- built once on first open (shared items must be loaded)

---------------------------------------------------------------------
-- NUI focus (keeps push-to-talk working while the menu is open)
---------------------------------------------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local control = list[i]
            EnableControlAction(0, control, true)
            EnableControlAction(1, control, true)
            EnableControlAction(2, control, true)
        end
    end
end

-- KeepInput passes every key to the game, so block all controls except push-to-talk
CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

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
    uiFocus = false
    applyNuiFocus(false)
    SendNUIMessage({ type = 'closeUI' })
end

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    closeLoyaltyNUI()
end)

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
        tier = data.tier,
        streak = data.streak or 0,
        boost = data.boost,
    })
end)

RegisterNetEvent('rsg-loyalty:client:storeState', function(data)
    if type(data) ~= 'table' then return end
    SendNUIMessage({
        type = 'storeState',
        rewards = data.rewards,
        rotationEnds = data.rotationEnds,
    })
end)

RegisterNetEvent('rsg-loyalty:client:leaderboardData', function(data)
    if type(data) ~= 'table' then return end
    SendNUIMessage({
        type = 'leaderboardData',
        topCurrent = data.topCurrent,
        topLifetime = data.topLifetime,
    })
end)

RegisterNetEvent('rsg-loyalty:client:historyData', function(rows)
    if type(rows) ~= 'table' then return end
    SendNUIMessage({ type = 'historyData', rows = rows })
end)

---------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------
local function buildRewardPayload()
    local cash, items, specials = {}, {}, {}

    for i, reward in ipairs(Config.CashRewards) do
        cash[i] = {
            label = locale(reward.label),
            points = reward.points,
            amount = reward.amount,
            kind = 'cash',
            image = Config.Image .. (reward.image or 'dollar.png'),
        }
    end

    for i, reward in ipairs(Config.ItemRewards) do
        local itemData = RSGCore.Shared.Items[reward.item]
        items[i] = {
            label = locale(reward.label),
            points = reward.points,
            amount = reward.amount,
            kind = 'item',
            image = Config.Image .. ((itemData and itemData.image) or reward.image or ''),
        }
    end

    for i, reward in ipairs(Config.SpecialRewards or {}) do
        local kind = reward.type or 'item'
        local itemData = kind == 'item' and RSGCore.Shared.Items[reward.item] or nil
        specials[i] = {
            label = locale(reward.label),
            points = reward.points,
            amount = reward.amount,
            kind = kind,
            rotating = reward.rotating == true,
            image = Config.Image .. ((itemData and itemData.image) or reward.image or (kind == 'cash' and 'dollar.png') or ''),
        }
    end

    return {
        cashRewards = cash,
        itemRewards = items,
        specialRewards = specials,
        locale = {
            title = locale('loyalty_menu_title'),
            subtitle = locale('loyalty_subtitle'),
            close = locale('close'),
            currentPoints = locale('loyalty_points'),
            lifetimePoints = locale('lifetime_points'),
            redeemCash = locale('redeem_cash'),
            redeemItems = locale('redeem_items'),
            tabSpecials = locale('tab_specials'),
            tabHistory = locale('tab_history'),
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
            tier = locale('tier_label'),
            tierNext = locale('tier_next'),
            tierMax = locale('tier_max'),
            rewardDiscount = locale('reward_discount'),
            earnBonus = locale('earn_bonus'),
            streak = locale('streak_label'),
            daysSuffix = locale('days_suffix'),
            boostBanner = locale('boost_banner'),
            soldOut = locale('sold_out'),
            limitReached = locale('limit_reached'),
            stockLeft = locale('stock_left'),
            playerLeft = locale('player_left'),
            specialRotates = locale('special_rotates'),
            historyEmpty = locale('history_empty'),
        },
    }
end

-- close the menu if the player dies or walks away from the NPC they opened it at
local function watchPlayer(origin)
    local maxDist = Config.Loyalty.MaxRedeemDistance or 5.0
    CreateThread(function()
        while nuiOpen do
            local ped = PlayerPedId()
            if IsEntityDead(ped) or (origin and #(GetEntityCoords(ped) - origin) > maxDist) then
                closeLoyaltyNUI()
                break
            end
            Wait(500)
        end
    end)
end

local function openLoyaltyNUI(origin)
    if not isLoggedIn or nuiOpen or IsEntityDead(PlayerPedId()) then return end
    rewardPayload = rewardPayload or buildRewardPayload()

    nuiOpen = true
    SendNUIMessage({
        type = 'openUI',
        currentPoints = playerLoyalty.loyalty_points or 0,
        lifetimePoints = playerLoyalty.lifetime_points or 0,
        tier = playerLoyalty.tier,
        streak = playerLoyalty.streak or 0,
        boost = playerLoyalty.boost,
        cashRewards = rewardPayload.cashRewards,
        itemRewards = rewardPayload.itemRewards,
        specialRewards = rewardPayload.specialRewards,
        locale = rewardPayload.locale,
    })
    uiFocus = true
    applyNuiFocus(true)
    watchPlayer(type(origin) == 'vector3' and origin or nil)

    -- refresh in the background; NUI updates when the replies arrive
    TriggerServerEvent('rsg-loyalty:server:getStore')
    TriggerServerEvent('rsg-loyalty:server:getLeaderboard')
end

RegisterNUICallback('redeemReward', function(data, cb)
    if nuiOpen and (data.type == 'cash' or data.type == 'item' or data.type == 'special') then
        TriggerServerEvent('rsg-loyalty:server:redeem', data.type, tonumber(data.index))
    end
    cb({ ok = true })
end)

RegisterNUICallback('requestHistory', function(_, cb)
    if nuiOpen then
        TriggerServerEvent('rsg-loyalty:server:getHistory')
    end
    cb({ ok = true })
end)

RegisterNUICallback('closeUI', function(_, cb)
    nuiOpen = false
    uiFocus = false
    applyNuiFocus(false)
    cb({ ok = true })
end)

RegisterNetEvent('rsg-loyalty:client:openloyaltyUI', openLoyaltyNUI)

if Config.UI.EnableCommand then
    RegisterCommand(Config.UI.OpenCommand, function() openLoyaltyNUI() end, false)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
end)
