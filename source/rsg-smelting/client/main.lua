local RSGCore = exports['rsg-core']:GetCoreObject()

local spawnedPeds = {}
local blips = {}
local uiOpen = false
local isSmelting = false
local activeSmelter, activePropCoords

local function notify(description, nType)
    lib.notify({ title = locale('smelter_title'), description = description, type = nType or 'inform', duration = 5000 })
end

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local uiStrings -- built once, sent to NUI on open
local function getUiStrings()
    if uiStrings then return uiStrings end
    uiStrings = {}
    for _, key in ipairs({ 'smelter_title', 'ui_subtitle', 'ui_close', 'ui_can_make', 'ui_missing_ore', 'ui_smelt', 'ui_smelt_item',
        'ui_quantity', 'ui_max', 'ui_max_n', 'ui_cancel', 'ui_time', 'ui_remaining', 'ui_complete', 'ui_cancelled', 'ui_cancel_hint' }) do
        uiStrings[key] = locale(key)
    end
    return uiStrings
end

local function buildRecipeData()
    local counts = lib.callback.await('rsg-smelting:server:getOreCounts', false) or {}
    local items = RSGCore.Shared.Items
    local recipes = {}
    for i, r in ipairs(Config.Recipes) do
        local inputs, maxCraft = {}, Config.MaxBatch
        for _, inp in ipairs(r.inputs) do
            local def, have = items[inp.item], counts[inp.item] or 0
            inputs[#inputs + 1] = {
                label = def and def.label or inp.item,
                image = Config.ImagePath .. (def and def.image or (inp.item .. '.png')),
                amount = inp.amount,
                have = have,
            }
            maxCraft = math.min(maxCraft, math.floor(have / inp.amount))
        end
        local out = items[r.output]
        recipes[#recipes + 1] = {
            index = i,
            label = r.label and locale(r.label) or (out and out.label) or r.output,
            image = Config.ImagePath .. (out and out.image or (r.output .. '.png')),
            time = r.time,
            inputs = inputs,
            maxCraft = maxCraft,
        }
    end
    return recipes
end

local function closeUI()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openSmelter(index, propCoords)
    if uiOpen or isSmelting then return end
    activeSmelter, activePropCoords = index, propCoords
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = locale(index == 'prop' and Config.SmeltProps.label or Config.Smelters[index].label),
        strings = getUiStrings(),
        recipes = buildRecipeData(),
    })
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

-- Runs the smelt timer; returns true if completed, false if cancelled
local function runProgress(duration, label)
    local startTime, lastPct = GetGameTimer(), -1
    SendNUIMessage({ action = 'progress:start', label = label, duration = duration })

    while true do
        local elapsed = GetGameTimer() - startTime
        if elapsed >= duration then return true end

        DisableAllControlActions(0)
        EnableControlAction(0, `INPUT_LOOK_LR`, true)
        EnableControlAction(0, `INPUT_LOOK_UD`, true)
        if IsDisabledControlJustPressed(0, `INPUT_FRONTEND_CANCEL`) or IsEntityDead(cache.ped) then return false end

        local pct = math.floor(elapsed / duration * 100)
        if pct ~= lastPct then
            lastPct = pct
            SendNUIMessage({ action = 'progress:update', percent = pct, remaining = math.ceil((duration - elapsed) / 1000) })
        end
        Wait(0)
    end
end

RegisterNUICallback('smelt', function(data, cb)
    cb('ok')
    closeUI() -- always release focus, even on invalid input

    local recipeIndex = tonumber(data.index)
    local amount = math.floor(tonumber(data.amount) or 0)
    local recipe = Config.Recipes[recipeIndex or 0]
    if not recipe or amount < 1 or amount > Config.MaxBatch or isSmelting then return end

    isSmelting = true
    local ok, msg = lib.callback.await('rsg-smelting:server:startSmelt', false, activeSmelter, recipeIndex, amount, activePropCoords)
    if not ok then
        isSmelting = false
        return notify(msg or locale('err_generic'), 'error')
    end

    local finished = runProgress(recipe.time * amount, locale('progress_label', amount, locale(recipe.label)))
    SendNUIMessage({ action = 'progress:stop', cancelled = not finished })

    local success, result = lib.callback.await('rsg-smelting:server:finishSmelt', false, not finished)
    isSmelting = false
    if result then
        notify(result, success and 'success' or (finished and 'error' or 'warning'))
    end
end)

---------------------------------------------------------------------
-- NPCs (spawned by proximity via lib.points)
---------------------------------------------------------------------
local function spawnSmelterPed(index, data)
    if spawnedPeds[index] then return end
    local hash = joaat(data.model)
    if not IsModelValid(hash) or not pcall(lib.requestModel, hash, 5000) then return end

    local c = data.coords
    local ped = CreatePed(hash, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    if data.scenario then
        TaskStartScenarioInPlace(ped, joaat(data.scenario), -1, true, false, false, false)
    end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'rsg_smelting_' .. data.id,
            icon = 'fa-solid fa-fire',
            label = locale('use_smelter'),
            distance = Config.TargetDistance,
            onSelect = function() openSmelter(index) end,
        },
    })

    spawnedPeds[index] = ped
end

local function deleteSmelterPed(index)
    local ped = spawnedPeds[index]
    spawnedPeds[index] = nil
    if ped and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped)
        DeleteEntity(ped)
    end
end

for i, data in ipairs(Config.Smelters) do
    local c = data.coords

    if data.blip and data.blip.enabled then
        local blip = BlipAddForCoords(1664425300, c.x, c.y, c.z)
        SetBlipSprite(blip, joaat(data.blip.sprite), true)
        SetBlipScale(blip, 0.2)
        SetBlipName(blip, locale(data.blip.name))
        blips[#blips + 1] = blip
    end

    lib.points.new({
        coords = c.xyz,
        distance = Config.SpawnDistance,
        onEnter = function() spawnSmelterPed(i, data) end,
        onExit = function() deleteSmelterPed(i) end,
    })
end

---------------------------------------------------------------------
-- Prop targets (e.g. p_bucketore03x)
---------------------------------------------------------------------
if Config.SmeltProps.enabled then
    exports.ox_target:addModel(Config.SmeltProps.models, {
        {
            name = 'rsg_smelting_prop',
            icon = 'fa-solid fa-fire',
            label = locale('use_smelter'),
            distance = Config.TargetDistance,
            onSelect = function(data)
                if not data.entity or data.entity == 0 then return end
                openSmelter('prop', GetEntityCoords(data.entity))
            end,
        },
    })
end

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    for i in pairs(spawnedPeds) do deleteSmelterPed(i) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    if Config.SmeltProps.enabled then
        exports.ox_target:removeModel(Config.SmeltProps.models, 'rsg_smelting_prop')
    end
end)
