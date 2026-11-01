local RSGCore = exports['rsg-core']:GetCoreObject()

local UI_LOCALE_KEYS = {
    'menu_title', 'menu_current_xp', 'ui_locked', 'ui_requires', 'ui_makes', 'ui_select', 'ui_ingredients',
    'ui_quantity', 'ui_craft', 'ui_stop', 'ui_missing', 'ui_close', 'ui_xp', 'ui_time', 'ui_crafting',
    'ui_cancelled', 'ui_next_unlock', 'ui_reset_pos', 'ui_xp_label', 'ui_all', 'ui_count', 'ui_have_need', 'ui_required_tools', 'ui_missing_tools', 'amount_item', 'seconds', 'minutes_seconds',
}

local uiOpen = false
local crafting = nil -- { id, cancelled, startedAt, duration, label, qty }
local pending = false -- a start request is in flight

---------------------------------------------
-- helpers
---------------------------------------------
local function notify(description, ntype)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = description, type = ntype or 'inform', duration = 5000 })
end

local function uiLocale()
    local t = {}
    for _, k in ipairs(UI_LOCALE_KEYS) do t[k] = locale(k) end
    return t
end

local function fetchRecipes()
    local data = RSGCore.Functions.AwaitCallback('rsg-crafting:server:getRecipes', 10000)
    if not data or #data.recipes == 0 then return nil end
    return data
end

local function failReason(result)
    local reason = result and result.reason
    if reason == 'busy' then return locale('busy_desc') end
    if reason == 'job' then return locale('job_required_desc', result.requiredJob) end
    if reason == 'xp' then return locale('xp_required_desc', result.requiredXP, result.currentXP) end
    if reason == 'missing' then return locale('ui_missing') end
    if reason == 'tools' then return locale('tools_required_desc', result.tools or '') end
    if reason == 'inventory_full' then return locale('inventory_full', result.label or '') end
    return locale('craft_error')
end

---------------------------------------------
-- NUI
---------------------------------------------
local function closeUI()
    if not uiOpen then return end
    -- closing the book does NOT cancel an active craft; it carries on in the background
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function refreshUI()
    if not uiOpen then return end
    local data = fetchRecipes()
    if not data then return closeUI() end
    SendNUIMessage({ action = 'refresh', xp = data.xp, nextUnlock = data.nextUnlock, recipes = data.recipes })
end

local function openBook()
    if uiOpen then return end
    if not crafting and LocalPlayer.state.inv_busy then return end

    local data = fetchRecipes()
    if not data then return notify(locale('no_recipes'), 'inform') end

    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        imagePath = 'nui://' .. Config.Image,
        maxBatch = Config.MaxBatch,
        locale = uiLocale(),
        xp = data.xp,
        nextUnlock = data.nextUnlock,
        recipes = data.recipes,
        active = crafting and {
            id = crafting.id, label = crafting.label, qty = crafting.qty,
            duration = crafting.duration, elapsed = GetGameTimer() - crafting.startedAt,
        } or nil,
    })
end

RegisterNetEvent('rsg-crafting:client:openBook', openBook)

local function runCrafting(recipeId, duration)
    LocalPlayer.state:set('inv_busy', true, true)

    local ped = PlayerPedId()
    local anim = Config.Anim
    if anim and RSGCore.Functions.RequestAnimDict(anim.dict, 5000) then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 1, 0, false, false, false)
    end

    local endsAt = GetGameTimer() + duration
    while GetGameTimer() < endsAt and not crafting.cancelled and not IsEntityDead(ped) do
        Wait(100)
    end

    local finished = not crafting.cancelled and not IsEntityDead(ped)
    ClearPedTasks(ped)
    if anim then RemoveAnimDict(anim.dict) end

    if finished then
        local result = RSGCore.Functions.AwaitCallback('rsg-crafting:server:finishCrafting', 10000, recipeId)
        local ok = result and result.ok
        local msg = ok and locale('craft_success', result.amount, result.label) or failReason(result)
        if uiOpen then
            SendNUIMessage({ action = 'finished', ok = ok, message = msg })
        end
        notify(msg, ok and 'success' or 'error')
    else
        TriggerServerEvent('rsg-crafting:server:cancelCrafting')
        if uiOpen then SendNUIMessage({ action = 'cancelled' }) end
    end

    LocalPlayer.state:set('inv_busy', false, true)
    crafting = nil
    refreshUI()
end

RegisterNUICallback('craft', function(data, cb)
    if crafting or pending or not uiOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local id = tonumber(data.id)

    pending = true
    local result = RSGCore.Functions.AwaitCallback('rsg-crafting:server:startCrafting', 10000, id, tonumber(data.qty))
    pending = false
    if not result or not result.ok or not uiOpen then
        if result and result.ok then TriggerServerEvent('rsg-crafting:server:cancelCrafting') end
        cb({ ok = false, error = failReason(result) })
        return refreshUI()
    end

    crafting = { id = id, cancelled = false, startedAt = GetGameTimer(), duration = result.crafttime, label = result.label, qty = result.qty } -- claim the slot now so a second click can't slip in before the thread starts
    cb({ ok = true, crafttime = result.crafttime, label = result.label, qty = result.qty })
    CreateThread(function() runCrafting(id, result.crafttime) end)
end)

RegisterNUICallback('cancel', function(_, cb)
    if crafting then crafting.cancelled = true end
    cb({})
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({})
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if crafting then
        LocalPlayer.state:set('inv_busy', false, true)
        ClearPedTasks(PlayerPedId())
    end
    if uiOpen then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
end)

exports('OpenCraftingBook', openBook)
