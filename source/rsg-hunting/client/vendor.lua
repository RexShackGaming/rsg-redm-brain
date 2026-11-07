local RSGCore = exports['rsg-core']:GetCoreObject()
local vendorPeds = {}
CreateThread(function()
    for vendorIndex, vendor in ipairs(Config.Vendors) do
        local model = GetHashKey(vendor.pedModel)
        RequestModel(model)
        local timeout = 0
        while not HasModelLoaded(model) and timeout < 100 do
            Wait(10)
            timeout = timeout + 1
        end

        if not HasModelLoaded(model) then
            print(('[rsg-hunting] vendor: failed to load ped model "%s", skipping vendor "%s"'):format(tostring(vendor.pedModel), tostring(vendor.blipname or vendor.pedModel)))
            goto continue
        end

        local ped = CreatePed(model, vendor.coords.x, vendor.coords.y, vendor.coords.z - 1.0, vendor.coords.w, false, false)
        SetModelAsNoLongerNeeded(model)
        SetEntityInvincible(ped, true)
        SetRandomOutfitVariation(ped, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        TaskStandStill(ped, -1)

        vendorPeds[#vendorPeds + 1] = ped

        exports['rsg-target']:addLocalEntity(ped, {
            {
                name = 'vendor_sell',
                label = locale('sell_items'),
                icon = 'fa-solid fa-hand-holding-dollar',
                distance = 2.0,
                onSelect = function()
                    OpenSellMenu(vendorIndex)
                end
            },
            {
                name = 'vendor_bounties',
                label = locale('bounty_option'),
                icon = 'fa-solid fa-scroll',
                distance = 2.0,
                canInteract = function() return Config.Bounty and Config.Bounty.Enabled end,
                onSelect = function() ShowDailyBounties() end
            },
            {
                name = 'vendor_weekly_claim',
                label = locale('weekly_claim_option'),
                icon = 'fa-solid fa-sack-dollar',
                distance = 2.0,
                canInteract = function() return Config.HuntingXP.Enabled and Config.HuntingXP.Weekly and Config.HuntingXP.Weekly.Enabled end,
                onSelect = function() ClaimWeeklyReward() end
            },
            {
                name = 'vendor_hunting_board',
                label = locale('hunting_board_option'),
                icon = 'fa-solid fa-trophy',
                distance = 2.0,
                canInteract = function()
                    return Config.HuntingXP and Config.HuntingXP.Enabled and Config.HuntingXP.Leaderboard.AtTrapper
                end,
                onSelect = function()
                    OpenHuntingLeaderboard()
                end
            }
        })

        ::continue::
    end
end)

--------------------------------------
-- trapper sell UI (NUI)
--------------------------------------
local sellUiOpen = false
local currentVendor = nil

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
    if not Config.AllowPushToTalkWhileOpen then return end
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

local function closeSellUi()
    if not sellUiOpen then return end
    sellUiOpen = false
    currentVendor = nil
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

function OpenSellMenu(vendorIndex)
    if sellUiOpen then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getSellData', nil, vendorIndex)
    if not data then return end

    sellUiOpen = true
    currentVendor = vendorIndex
    applyNuiFocus(true)
    SendNUIMessage({
        action = 'open',
        title = data.title,
        imagePath = 'nui://' .. Config.Image,
        items = data.items,
        labels = {
            subtitle = locale('ui_goods_wanted'), search = locale('ui_search'), ownedOnly = locale('ui_owned_only'),
            addAll = locale('ui_add_all'), basket = locale('ui_basket'), total = locale('ui_total'),
            clear = locale('ui_clear'), sell = locale('ui_sell_to_trapper'), confirmTitle = locale('ui_confirm_title'),
            cancel = locale('ui_cancel'), confirm = locale('ui_confirm_sell'), confirmText = locale('ui_confirm_text'),
            have = locale('ui_have'), inBasket = locale('ui_in_basket'), addToBasket = locale('ui_add_to_basket'),
            emptyBasket = locale('basket_empty'), nothingOwned = locale('ui_nothing_owned'), noMatch = locale('ui_no_match'),
            items = locale('ui_items'), max = locale('ui_max'), remove = locale('ui_remove'), close = locale('ui_close'),
            trapper = locale('ui_trapper'),
        },
    })
end

function ShowDailyBounties()
    local list = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getBounties', nil) or {}
    RSGCore.Functions.Notify({
        title = locale('bounty_title'),
        description = #list > 0 and locale('bounty_desc', table.concat(list, ', '), Config.Bounty.ButcherBonus or 0, Config.Bounty.XPMultiplier or 1) or locale('bounty_none'),
        type = 'inform',
        duration = 9000,
    })
end

function ClaimWeeklyReward()
    local result = RSGCore.Functions.AwaitCallback('rsg-hunting:server:claimWeekly', nil) or {}
    RSGCore.Functions.Notify({
        title = locale('weekly_title'),
        description = result.ok and locale('weekly_claimed', ('%.2f'):format(result.cash)) or locale('weekly_nothing'),
        type = result.ok and 'success' or 'inform',
    })
end

RegisterNUICallback('close', function(_, cb)
    closeSellUi()
    cb('ok')
end)

RegisterNUICallback('sellBasket', function(basket, cb)
    if not sellUiOpen or not currentVendor then return cb({ ok = false }) end
    local result = RSGCore.Functions.AwaitCallback('rsg-hunting:server:sellBasket', nil, currentVendor, basket) or { ok = false }
    if not result.ok then
        RSGCore.Functions.Notify({ title = locale('vendor'), description = result.message or locale('sale_failed'), type = 'error' })
    end
    cb(result)
end)

-- close the UI if the player wanders off / dies while it's open
CreateThread(function()
    while true do
        if sellUiOpen and currentVendor then
            local vendor = Config.Vendors[currentVendor]
            local ped = PlayerPedId()
            if IsEntityDead(ped) or #(GetEntityCoords(ped) - vector3(vendor.coords.x, vendor.coords.y, vendor.coords.z)) > 5.0 then
                closeSellUi()
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        if sellUiOpen and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, ped in ipairs(vendorPeds) do
            exports['rsg-target']:removeLocalEntity(ped)
            DeleteEntity(ped)
        end
        if sellUiOpen then applyNuiFocus(false) end
    end
end)
