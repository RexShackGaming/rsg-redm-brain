local RSGCore = exports['rsg-core']:GetCoreObject()
--------------------------------------
-- trapper npcs: spawn when close, despawn when far
--------------------------------------
local vendorPeds = {} -- [index] = ped | true while spawning

local function spawnVendor(vendorIndex, vendor)
    local model = joaat(vendor.pedModel)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then
        print(('[rsg-hunting] vendor: failed to load ped model "%s", skipping vendor "%s"'):format(tostring(vendor.pedModel), tostring(vendor.blipname or vendor.pedModel)))
        return nil
    end

    local c = vendor.coords
    local ped = CreatePed(model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return nil end

    SetEntityInvincible(ped, true)
    SetRandomOutfitVariation(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)

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
            name = 'vendor_contract',
            label = locale('contract_option'),
            icon = 'fa-solid fa-file-signature',
            distance = 2.0,
            canInteract = function() return Config.Contracts and Config.Contracts.Enabled end,
            onSelect = function() TriggerServerEvent('rsg-hunting:server:contract', vendorIndex) end
        },
        {
            name = 'vendor_bounties',
            label = locale('bounty_option'),
            icon = 'fa-solid fa-scroll',
            distance = 2.0,
            canInteract = function() return Config.Bounty and Config.Bounty.Enabled end,
            onSelect = function() ShowDailyBounties(vendorIndex) end
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
    return ped
end

local function despawnVendor(ped)
    if not DoesEntityExist(ped) then return end
    exports['rsg-target']:removeLocalEntity(ped)
    DeleteEntity(ped)
end

CreateThread(function()
    local range = Config.DistanceSpawn or 20.0
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for k, vendor in ipairs(Config.Vendors) do
            local near = #(coords - vector3(vendor.coords.x, vendor.coords.y, vendor.coords.z)) < range
            local current = vendorPeds[k]

            if near and not current then
                vendorPeds[k] = true
                CreateThread(function() vendorPeds[k] = spawnVendor(k, vendor) end)
            elseif not near and type(current) == 'number' then
                vendorPeds[k] = nil
                despawnVendor(current)
            end
        end
        Wait(1500)
    end
end)

--------------------------------------
-- trapper sell UI (NUI)
--------------------------------------
local sellUiOpen = false
local currentVendor = nil

local function closeSellUi()
    if not sellUiOpen then return end
    sellUiOpen = false
    currentVendor = nil
    HuntingNui.Focus('sell', false)
    SendNUIMessage({ action = 'close' })
end

function OpenSellMenu(vendorIndex)
    if sellUiOpen then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getSellData', nil, vendorIndex)
    if not data then return end

    sellUiOpen = true
    currentVendor = vendorIndex
    HuntingNui.Focus('sell', true)
    SendNUIMessage({
        action = 'open',
        title = data.title,
        imagePath = 'nui://' .. Config.Image,
        items = data.items,
        qualityMult = data.qualityMult,
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

function ShowDailyBounties(vendorIndex)
    local list = RSGCore.Functions.AwaitCallback('rsg-hunting:server:getBounties', nil, vendorIndex) or {}
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

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, ped in pairs(vendorPeds) do
        if type(ped) == 'number' then despawnVendor(ped) end
    end
    if sellUiOpen then HuntingNui.Focus('sell', false) end
end)
