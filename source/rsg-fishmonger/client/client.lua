local RSGCore = exports['rsg-core']:GetCoreObject()

local spawnedPeds = {}
local blips = {}
local blipOpen = {}
local uiOpen = false
local activeLocation = nil

---------------------------------
-- helpers
---------------------------------
local function loadModel(model)
    if HasModelLoaded(model) then return true end
    if not IsModelValid(model) then return false end
    RequestModel(model, false)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

local function buildFishList()
    local list = {}
    for item, data in pairs(Config.Fish) do
        local shared = RSGCore.Shared.Items[item]
        local fillet = RSGCore.Shared.Items[FishmongerFillet(item)]
        list[#list + 1] = {
            item = item,
            label = shared and shared.label or item,
            price = data.price,
            fillets = data.fillets,
            filletLabel = fillet and fillet.label or locale('cl_fillet_fallback'),
            kind = 'fish',
        }
    end
    -- fillets can be sold back (never processed)
    local sale = Config.FilletSale
    if sale and sale.enabled then
        for item, price in pairs(sale.items or {}) do
            local shared = RSGCore.Shared.Items[item]
            if shared then
                list[#list + 1] = { item = item, label = shared.label, price = price, fillets = 0, filletLabel = '', kind = 'fillet' }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.kind ~= b.kind then return a.kind == 'fish' end
        return a.label < b.label
    end)
    return list
end

---------------------------------
-- NUI focus (keeps push-to-talk working while the menu is open)
---------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- KeepInput passes every key to the game, so block all controls except push-to-talk while focused
CreateThread(function()
    while true do
        if uiOpen and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, c in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, c, true)
                EnableControlAction(1, c, true)
                EnableControlAction(2, c, true)
            end
        else
            Wait(250)
        end
    end
end)

local function closeUI()
    uiOpen = false
    activeLocation = nil
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local uiStrings
local function getUiStrings()
    if uiStrings then return uiStrings end
    uiStrings = {}
    for _, key in ipairs({
        'ui_search', 'ui_owned_only', 'ui_add_all_cart', 'ui_cart', 'ui_fish', 'ui_sell_value', 'ui_sell',
        'ui_process', 'ui_clear', 'ui_cancel', 'ui_confirm', 'ui_close', 'ui_remove', 'ui_add', 'ui_all',
        'ui_each', 'ui_fillets', 'ui_owned', 'ui_in_cart', 'ui_no_fish', 'ui_cart_empty', 'ui_sell_title',
        'ui_process_title', 'ui_sell_confirm', 'ui_process_confirm', 'ui_sell_all', 'ui_demand', 'ui_bonus',
        'ui_stock_left', 'ui_unlimited', 'ui_over_stock', 'ui_orders', 'ui_order_deliver', 'ui_order_done',
        'ui_order_reward', 'ui_order_title', 'ui_order_confirm', 'ui_fillet_tag',
    }) do uiStrings[key] = locale(key) end
    return uiStrings
end

local function notify(message, ntype)
    RSGCore.Functions.Notify({
        title = locale('cl_title'),
        description = message,
        type = ntype,
        position = 'top-right',
        duration = 5000,
        icon = 'fa-solid fa-fish',
    })
end

-- the server decides if the shop is open and the player is in range, and says why when it is not
local function getMenuData(locationIndex)
    local data = RSGCore.Functions.AwaitCallback('rsg-fishmonger:server:getMenuData', 10000, locationIndex)
    if data and data.denied then notify(data.message, 'error') return nil end
    return data
end

local opening = false
local function openUI(locationIndex)
    if uiOpen or opening then return end
    opening = true -- guard against double-open while the callback is in flight
    local data = getMenuData(locationIndex)
    opening = false
    if not data then return end
    local filletData = RSGCore.Shared.Items[Config.FilletItem]
    uiOpen = true
    activeLocation = locationIndex
    applyNuiFocus(true)
    SendNUIMessage({
        action = 'open',
        title = locale('loc_' .. Config.Locations[locationIndex].key),
        subtitle = locale('cl_subtitle'),
        fish = buildFishList(),
        data = data,
        imagePath = Config.ImagePath,
        filletLabel = filletData and filletData.label or locale('cl_fillet_fallback'),
        lang = getUiStrings(),
    })
end

-- blip colour follows the town's opening hours (the server sends the states)
local function setBlipStatus(i, open)
    local blip = blips[i]
    if not blip or blipOpen[i] == open then return end
    if blipOpen[i] ~= nil then
        BlipRemoveModifier(blip, joaat(blipOpen[i] and Config.Blip.openColor or Config.Blip.closedColor))
    end
    BlipAddModifier(blip, joaat(open and Config.Blip.openColor or Config.Blip.closedColor))
    blipOpen[i] = open
end

local function applyHours(states)
    if not Config.OpeningHours.enabled or type(states) ~= 'table' then return end
    for i = 1, #Config.Locations do
        if states[i] ~= nil then setBlipStatus(i, states[i]) end
    end
end

RegisterNetEvent('rsg-fishmonger:client:hours', applyHours)

local function openShop(locationIndex)
    TriggerServerEvent('rsg-fishmonger:server:openShop', locationIndex)
end

---------------------------------
-- npc spawning
---------------------------------
local function spawnPed(index)
    local loc = Config.Locations[index]
    if not loadModel(Config.NpcModel) then return end
    local c = loc.coords
    local ped = CreatePed(Config.NpcModel, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(ped) do
        if GetGameTimer() > timeout then return end
        Wait(10)
    end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    local options = {
        {
            name = 'rsg_fishmonger_' .. index,
            icon = 'fa-solid fa-fish',
            label = locale('cl_target_label'),
            distance = Config.TargetDistance,
            onSelect = function() openUI(index) end,
        },
    }
    if Config.Shop.enabled then
        options[#options + 1] = {
            name = 'rsg_fishmonger_shop_' .. index,
            icon = 'fa-solid fa-basket-shopping',
            label = locale('cl_target_shop'),
            distance = Config.TargetDistance,
            onSelect = function() openShop(index) end,
        }
    end
    exports['rsg-target']:addLocalEntity(ped, options)
    spawnedPeds[index] = ped
end

local function despawnPed(index)
    local ped = spawnedPeds[index]
    if ped and DoesEntityExist(ped) then
        exports['rsg-target']:removeLocalEntity(ped, { 'rsg_fishmonger_' .. index, 'rsg_fishmonger_shop_' .. index })
        DeleteEntity(ped)
    end
    spawnedPeds[index] = nil
end

CreateThread(function()
    if Config.Blip.enabled then
        for i, loc in ipairs(Config.Locations) do
            local blip = BlipAddForCoords(Config.Blip.style, loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, Config.Blip.sprite, true)
            SetBlipScale(blip, Config.Blip.scale or 0.2)
            SetBlipName(blip, locale('cl_blip_name'))
            blips[i] = blip
        end
        if Config.OpeningHours.enabled then
            applyHours(RSGCore.Functions.AwaitCallback('rsg-fishmonger:server:getHours', 10000))
        end
    end

    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local nearest = math.huge
        for i, loc in ipairs(Config.Locations) do
            local dist = #(pos - loc.coords.xyz)
            if dist < nearest then nearest = dist end
            if dist < Config.SpawnDistance and not spawnedPeds[i] then
                spawnPed(i)
            elseif dist >= Config.SpawnDistance and spawnedPeds[i] then
                despawnPed(i)
            end
        end
        -- release the model once no peds need it
        if not next(spawnedPeds) and HasModelLoaded(Config.NpcModel) then SetModelAsNoLongerNeeded(Config.NpcModel) end
        -- auto close if player walks away
        if uiOpen and activeLocation then
            local c = Config.Locations[activeLocation].coords
            if #(pos - c.xyz) > Config.MaxUseDistance then closeUI() end
        end
        -- check less often while far from every fishmonger
        Wait(nearest > Config.SpawnDistance * 3 and 3000 or 1000)
    end
end)

---------------------------------
-- nui callbacks
---------------------------------
RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({ ok = true })
end)

RegisterNUICallback('checkout', function(data, cb)
    if not uiOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    if (data.mode ~= 'sell' and data.mode ~= 'process') or type(data.cart) ~= 'table' then return cb({ ok = false }) end
    local locationIndex = activeLocation
    cb({ ok = true })
    local result = RSGCore.Functions.AwaitCallback('rsg-fishmonger:server:checkout', 10000, locationIndex, data.mode, data.cart)
    result = result or { ok = false, message = locale('sv_failed') }
    notify(result.message, result.ok and 'success' or 'error')
    if result.ok then
        if uiOpen then closeUI() end
        return
    end
    -- failed: keep the menu open with fresh counts and the cart kept (clamped to what is owned)
    if not uiOpen or activeLocation ~= locationIndex then return end
    local fresh = getMenuData(locationIndex)
    if not fresh then return closeUI() end
    SendNUIMessage({ action = 'refresh', data = fresh, error = result.message })
end)

-- release the menu if the character logs out
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    if uiOpen then closeUI() end
end)

-- deliver a daily order; the menu stays open with fresh counts either way
RegisterNUICallback('order', function(data, cb)
    if not uiOpen or type(data) ~= 'table' or type(data.slot) ~= 'number' then return cb({ ok = false }) end
    local locationIndex = activeLocation
    cb({ ok = true })
    local result = RSGCore.Functions.AwaitCallback('rsg-fishmonger:server:deliverOrder', 10000, locationIndex, data.slot)
    result = result or { ok = false, message = locale('sv_failed') }
    notify(result.message, result.ok and 'success' or 'error')
    if not uiOpen or activeLocation ~= locationIndex then return end
    local fresh = getMenuData(locationIndex)
    if not fresh then return closeUI() end
    SendNUIMessage({ action = 'refresh', data = fresh, error = (not result.ok) and result.message or nil })
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if uiOpen then closeUI() end
    for i in pairs(spawnedPeds) do despawnPed(i) end
    for _, blip in pairs(blips) do RemoveBlip(blip) end
end)
