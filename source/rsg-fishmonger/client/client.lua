local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

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
        list[#list + 1] = {
            item = item,
            label = shared and shared.label or item,
            price = data.price,
            fillets = data.fillets,
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
        'ui_process_title', 'ui_sell_confirm', 'ui_process_confirm',
    }) do uiStrings[key] = locale(key) end
    return uiStrings
end

local opening = false
local function openUI(locationIndex)
    if uiOpen or opening then return end
    opening = true -- guard against double-open while the callback is in flight
    local counts = lib.callback.await('rsg-fishmonger:server:getFishCounts', false)
    opening = false
    if not counts then return end
    local filletData = RSGCore.Shared.Items[Config.FilletItem]
    uiOpen = true
    activeLocation = locationIndex
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = locale('loc_' .. Config.Locations[locationIndex].key),
        subtitle = locale('cl_subtitle'),
        fish = fishList,
        counts = counts,
        imagePath = Config.ImagePath,
        filletLabel = filletData and filletData.label or locale('cl_fillet_fallback'),
        lang = getUiStrings(),
    })
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

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'rsg_fishmonger_' .. index,
            icon = 'fa-solid fa-fish',
            label = locale('cl_target_label'),
            distance = Config.TargetDistance,
            onSelect = function() openUI(index) end,
        }
    })
    spawnedPeds[index] = ped
end

local function despawnPed(index)
    local ped = spawnedPeds[index]
    if ped and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped, 'rsg_fishmonger_' .. index)
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
        local pos = GetEntityCoords(cache.ped)
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
    cb('ok')
end)

RegisterNUICallback('checkout', function(data, cb)
    if not uiOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    if (data.mode ~= 'sell' and data.mode ~= 'process') or type(data.cart) ~= 'table' then return cb({ ok = false }) end
    local locationIndex = activeLocation
    closeUI()
    cb('ok')
    local result = lib.callback.await('rsg-fishmonger:server:checkout', false, locationIndex, data.mode, data.cart)
    result = result or { ok = false, message = locale('sv_failed') }
    lib.notify({
        title = locale('cl_title'),
        description = result.message,
        type = result.ok and 'success' or 'error',
        position = 'top-right',
        duration = 5000,
        icon = 'fish',
    })
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    for i in pairs(spawnedPeds) do despawnPed(i) end
    for _, blip in pairs(blips) do RemoveBlip(blip) end
end)
