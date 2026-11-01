local RSGCore = exports['rsg-core']:GetCoreObject()

local spawnedPeds = {}
local blips = {}
local uiOpen = false
local activeLocation = nil

---------------------------------
-- helpers
---------------------------------
local function loadModel(model)
    if HasModelLoaded(model) then return true end
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
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end
local fishList = buildFishList()

local function closeUI()
    uiOpen = false
    activeLocation = nil
    SetNuiFocus(false, false)
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
        'ui_stock_left', 'ui_unlimited', 'ui_over_stock',
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

-- quick client-side hours check (the server re-checks everything)
local function checkOpen(locationIndex)
    local open, oh, ch = FishmongerIsOpen(Config.Locations[locationIndex], GetClockHours())
    if not open then notify(locale('sv_closed', oh, ch), 'error') end
    return open
end

local function getMenuData(locationIndex)
    local data = RSGCore.Functions.AwaitCallback('rsg-fishmonger:server:getMenuData', 10000, locationIndex)
    if data and data.closed then notify(data.message, 'error') return nil end
    return data
end

local opening = false
local function openUI(locationIndex)
    if uiOpen or opening or not checkOpen(locationIndex) then return end
    opening = true -- guard against double-open while the callback is in flight
    local data = getMenuData(locationIndex)
    opening = false
    if not data then return end
    local filletData = RSGCore.Shared.Items[Config.FilletItem]
    uiOpen = true
    activeLocation = locationIndex
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = locale('loc_' .. Config.Locations[locationIndex].key),
        subtitle = locale('cl_subtitle'),
        fish = fishList,
        data = data,
        imagePath = Config.ImagePath,
        filletLabel = filletData and filletData.label or locale('cl_fillet_fallback'),
        lang = getUiStrings(),
    })
end

local function openShop(locationIndex)
    if not checkOpen(locationIndex) then return end
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
            SetBlipScale(blip, 0.2)
            SetBlipName(blip, locale('cl_blip_name'))
            blips[i] = blip
        end
    end

    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, loc in ipairs(Config.Locations) do
            local dist = #(pos - loc.coords.xyz)
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
        Wait(1000)
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

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if uiOpen then closeUI() end
    for i in pairs(spawnedPeds) do despawnPed(i) end
    for _, blip in pairs(blips) do RemoveBlip(blip) end
end)
