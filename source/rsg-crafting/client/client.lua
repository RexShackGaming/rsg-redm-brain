local RSGCore = exports['rsg-core']:GetCoreObject()

local UI_LOCALE_KEYS = {
    'menu_title', 'menu_current_xp', 'ui_locked', 'ui_requires', 'ui_makes', 'ui_select', 'ui_ingredients',
    'ui_quantity', 'ui_craft', 'ui_stop', 'ui_missing', 'ui_close', 'ui_xp', 'ui_time', 'ui_crafting',
    'ui_cancelled', 'ui_next_unlock', 'ui_reset_pos', 'ui_xp_label', 'ui_all', 'ui_count', 'ui_have_need',
    'ui_required_tools', 'ui_missing_tools', 'amount_item', 'seconds', 'minutes_seconds',
    'ui_search', 'ui_favourites', 'ui_max', 'ui_queue', 'ui_add_queue', 'ui_remove',
    'ui_queue_added', 'ui_fail_chance', 'ui_quality', 'ui_station', 'ui_not_at_station', 'ui_blueprint',
    'ui_no_results',
}

local uiOpen = false
local uiFocus = false
local crafting = nil -- { id, cancelled, startedAt, duration, label, qty }
local pending = false -- a start request is in flight
local queue = {} -- crafts waiting behind the active one: { id, qty, label }

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
    if reason == 'station' then return locale('station_required_desc', result.station or '') end
    if reason == 'blueprint' then return locale('blueprint_required_desc') end
    if reason == 'crafting_failed' then return locale('craft_failed_all', result.label or '') end
    if reason == 'inventory_full' then return locale('inventory_full', result.label or '') end
    return locale('craft_error')
end

local function queueView()
    local out = {}
    for i, q in ipairs(queue) do out[i] = { label = q.label, qty = q.qty } end
    return out
end

---------------------------------------------
-- NUI focus (push-to-talk keeps working while the book is open)
---------------------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- KeepInput passes every key to the game: block the controls and let only push-to-talk through
CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, control in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, control, true)
                EnableControlAction(1, control, true)
                EnableControlAction(2, control, true)
            end
        else
            Wait(250)
        end
    end
end)

---------------------------------------------
-- NUI
---------------------------------------------
local function closeUI()
    if not uiOpen then return end
    -- closing the book does NOT cancel an active craft; it carries on in the background
    uiOpen = false
    uiFocus = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function refreshUI()
    if not uiOpen then return end
    local data = fetchRecipes()
    if not data then return closeUI() end
    SendNUIMessage({ action = 'refresh', xp = data.xp, nextUnlock = data.nextUnlock, recipes = data.recipes })
end

local function sendQueue()
    if uiOpen then SendNUIMessage({ action = 'queue', queue = queueView() }) end
end

local function stopAnim()
    local anim = Config.Anim
    if anim then StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0) end
end

local function playAnim()
    local anim = Config.Anim
    if anim and RSGCore.Functions.RequestAnimDict(anim.dict, 5000) then
        TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip, 8.0, -8.0, -1, anim.flag or 1, 0, false, false, false)
    end
end

local function openBook()
    if uiOpen then return end
    if IsPedDeadOrDying(PlayerPedId(), true) then return end
    if not crafting and LocalPlayer.state.inv_busy then return end

    local data = fetchRecipes()
    if not data then return notify(locale('no_recipes'), 'inform') end

    uiOpen = true
    uiFocus = true
    applyNuiFocus(true)
    SendNUIMessage({
        action = 'open',
        imagePath = 'nui://' .. Config.Image,
        maxBatch = Config.MaxBatch,
        queueEnabled = Config.Queue and Config.Queue.Enabled or false,
        queueMax = Config.Queue and Config.Queue.MaxLength or 0,
        locale = uiLocale(),
        xp = data.xp,
        nextUnlock = data.nextUnlock,
        recipes = data.recipes,
        queue = queueView(),
        active = crafting and {
            id = crafting.id, label = crafting.label, qty = crafting.qty,
            duration = crafting.duration, elapsed = GetGameTimer() - crafting.startedAt,
        } or nil,
    })
end

RegisterNetEvent('rsg-crafting:client:openBook', openBook)

---------------------------------------------
-- crafting
---------------------------------------------
local beginCraft

local function startNext()
    while #queue > 0 do
        local nextCraft = table.remove(queue, 1)
        local res = beginCraft(nextCraft.id, nextCraft.qty)
        if res.ok then
            if uiOpen then
                SendNUIMessage({ action = 'started', id = res.id, label = res.label, qty = res.qty, crafttime = res.crafttime })
            end
            sendQueue()
            return
        end
        notify(res.error or locale('craft_error'), 'error')
    end
    sendQueue()
end

local function runCrafting(recipeId)
    LocalPlayer.state:set('inv_busy', true, true)
    LocalPlayer.state:set('rsgCrafting', true, true) -- lets nearby players offer help
    playAnim()

    local ped = PlayerPedId()
    -- the server can shorten a craft while it runs (a helper joined), so the end time is read each tick
    while not crafting.cancelled and not IsEntityDead(ped) and GetGameTimer() < crafting.startedAt + crafting.duration do
        Wait(100)
    end

    local finished = not crafting.cancelled and not IsEntityDead(ped)
    local died = IsEntityDead(ped)
    stopAnim()
    if Config.Anim then RemoveAnimDict(Config.Anim.dict) end

    if finished then
        local result = RSGCore.Functions.AwaitCallback('rsg-crafting:server:finishCrafting', 10000, recipeId)
        local ok = result and result.ok
        local msg
        if ok then
            if result.failures and result.failures > 0 then
                msg = locale('craft_partial', result.amount, result.label, result.failures)
            elseif result.quality then
                msg = locale('craft_success_quality', result.amount, result.label, ('%s%%'):format(result.quality))
            else
                msg = locale('craft_success', result.amount, result.label)
            end
            if result.failures and result.failures > 0 and result.quality then
                msg = ('%s %s'):format(msg, locale('quality_suffix', ('%s%%'):format(result.quality)))
            end
        else
            msg = failReason(result)
        end
        if uiOpen then
            SendNUIMessage({ action = 'finished', ok = ok, message = msg })
        end
        notify(msg, ok and 'success' or 'error')
    else
        TriggerServerEvent('rsg-crafting:server:cancelCrafting')
        queue = {}
        sendQueue()
        if uiOpen then SendNUIMessage({ action = 'cancelled' }) end
    end

    LocalPlayer.state:set('inv_busy', false, true)
    LocalPlayer.state:set('rsgCrafting', false, true)
    crafting = nil
    refreshUI()
    if finished and not died then startNext() end
end

-- asks the server to start a craft; returns { ok, id, label, qty, crafttime } or { ok = false, error }
beginCraft = function(id, qty)
    if crafting or pending then return { ok = false } end
    pending = true
    local result = RSGCore.Functions.AwaitCallback('rsg-crafting:server:startCrafting', 10000, id, qty)
    pending = false
    if not result or not result.ok then return { ok = false, error = failReason(result) } end

    -- claim the slot now so a second click can't slip in before the thread starts
    crafting = { id = id, cancelled = false, startedAt = GetGameTimer(), duration = result.crafttime, label = result.label, qty = result.qty }
    CreateThread(function() runCrafting(id) end)
    return { ok = true, id = id, crafttime = result.crafttime, label = result.label, qty = result.qty }
end

RegisterNUICallback('craft', function(data, cb)
    if not uiOpen or pending or type(data) ~= 'table' then return cb({ ok = false }) end
    local id, qty = tonumber(data.id), tonumber(data.qty)

    -- a craft is running: line this one up behind it
    if crafting then
        local cfg = Config.Queue
        if not cfg or not cfg.Enabled then return cb({ ok = false, error = locale('busy_desc') }) end
        if #queue >= (cfg.MaxLength or 5) then return cb({ ok = false, error = locale('queue_full') }) end
        local label = tostring(data.label or '')
        queue[#queue + 1] = { id = id, qty = qty, label = label ~= '' and label or locale('category_other') }
        sendQueue()
        return cb({ ok = true, queued = true })
    end

    local res = beginCraft(id, qty)
    if not res.ok then
        cb({ ok = false, error = res.error })
        return refreshUI()
    end
    cb(res)
end)

RegisterNUICallback('queueRemove', function(data, cb)
    local index = type(data) == 'table' and math.tointeger(tonumber(data.index))
    if index and queue[index] then table.remove(queue, index) end
    sendQueue()
    cb({})
end)

RegisterNUICallback('cancel', function(_, cb)
    queue = {}
    sendQueue()
    if crafting then crafting.cancelled = true end
    cb({})
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({})
end)

---------------------------------------------
-- shared crafting
---------------------------------------------
-- a helper joined: the server sends the new total craft time
RegisterNetEvent('rsg-crafting:client:assisted', function(duration)
    if not crafting or type(duration) ~= 'number' then return end
    crafting.duration = duration
    if uiOpen then
        SendNUIMessage({ action = 'progress', duration = duration, elapsed = GetGameTimer() - crafting.startedAt })
    end
end)

-- the helper plays the craft animation for the time that is left
RegisterNetEvent('rsg-crafting:client:assistAnim', function(ms)
    if crafting or type(ms) ~= 'number' then return end
    CreateThread(function()
        playAnim()
        local endsAt = GetGameTimer() + math.min(ms, 120000)
        while GetGameTimer() < endsAt and not IsEntityDead(PlayerPedId()) do Wait(250) end
        stopAnim()
        if Config.Anim then RemoveAnimDict(Config.Anim.dict) end
    end)
end)

local ASSIST_TARGET = 'rsg_crafting_assist'

local function targetServerId(entity)
    local index = NetworkGetPlayerIndexFromPed(entity)
    if not index or index == -1 then return nil end
    return GetPlayerServerId(index)
end

CreateThread(function()
    if not (Config.Assist and Config.Assist.Enabled) then return end
    exports['rsg-target']:addGlobalPlayer({
        {
            name = ASSIST_TARGET,
            icon = 'fa-solid fa-handshake',
            label = locale('assist_target'),
            distance = Config.Assist.Distance or 3.0,
            canInteract = function(entity)
                if crafting or entity == PlayerPedId() then return false end
                local sid = targetServerId(entity)
                return sid ~= nil and Player(sid).state.rsgCrafting == true
            end,
            onSelect = function(data)
                local sid = data and data.entity and targetServerId(data.entity)
                if sid then TriggerServerEvent('rsg-crafting:server:assist', sid) end
            end,
        },
    })
end)

---------------------------------------------
-- lifecycle
---------------------------------------------
-- logging out / switching character: drop the UI and any running craft
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    queue = {}
    if crafting then crafting.cancelled = true end
    closeUI()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Config.Assist and Config.Assist.Enabled then exports['rsg-target']:removeGlobalPlayer(ASSIST_TARGET) end
    if crafting then
        LocalPlayer.state:set('inv_busy', false, true)
        LocalPlayer.state:set('rsgCrafting', false, true)
        stopAnim()
    end
    if uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
    if uiOpen then SendNUIMessage({ action = 'close' }) end
end)

exports('OpenCraftingBook', openBook)
