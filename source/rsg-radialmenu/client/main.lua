local RSGCore = exports['rsg-core']:GetCoreObject()

local inRadialMenu = false
local jobOptionId = nil
local nextOptionId = 0
local DynamicMenuItems = {}   -- [id] = option data added through the AddOption export
local DynamicOrder = {}       -- ids in the order they were added, so slots never shuffle between opens
local MenuItems = {}          -- live tree (keeps action/canOpen functions) used for lookups
local lastEmergency = nil

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function isVisible(item)
    if not item.canOpen then return true end
    local ok, result = pcall(item.canOpen)
    return ok and result and true or false
end

-- Returns a filtered copy of the menu tree, honouring canOpen and keeping functions
local function filterItems(items)
    local out = {}
    for _, item in ipairs(items) do
        if type(item) == 'table' and isVisible(item) then
            local copy = {}
            for k, v in pairs(item) do copy[k] = v end
            if item.items then
                copy.items = filterItems(item.items)
                if #copy.items == 0 then copy = nil end
            end
            if copy then out[#out + 1] = copy end
        end
    end
    return out
end

-- Strips functions so the tree can be serialised to NUI
local function toNui(items)
    local out = {}
    for i, item in ipairs(items) do
        local copy = {}
        for k, v in pairs(item) do
            if type(v) ~= 'function' and k ~= 'items' then copy[k] = v end
        end
        if item.items then copy.items = toNui(item.items) end
        out[i] = copy
    end
    return out
end

-- Plain data only (strings, numbers, booleans): functions and nested tables cannot travel to the server
local function toPayload(item)
    local out = {}
    for k, v in pairs(item) do
        local t = type(v)
        if t == 'string' or t == 'number' or t == 'boolean' then out[k] = v end
    end
    return out
end

local function findItem(items, id, event)
    for _, v in ipairs(items) do
        if v.items then
            local found = findItem(v.items, id, event)
            if found then return found end
        elseif v.id == id and (v.action or v.event == event) then
            return v
        end
    end
end

---------------------------------------------------------------------
-- Dynamic options (exports)
---------------------------------------------------------------------

local function AddOption(data, id)
    if type(data) ~= 'table' then return end
    if id == nil then
        nextOptionId = nextOptionId + 1
        id = nextOptionId
    end
    if DynamicMenuItems[id] == nil then DynamicOrder[#DynamicOrder + 1] = id end
    DynamicMenuItems[id] = data
    return id
end

local function RemoveOption(id)
    if id == nil or DynamicMenuItems[id] == nil then return end
    DynamicMenuItems[id] = nil
    for i = #DynamicOrder, 1, -1 do
        if DynamicOrder[i] == id then table.remove(DynamicOrder, i) break end
    end
end

local function SetupJobMenu()
    local job = RSGCore.Functions.GetPlayerData().job
    local items = job and Config.JobInteractions[job.name]

    if items and #items > 0 then
        jobOptionId = AddOption({ id = 'jobinteractions', title = locale('menu_work'), icon = 'briefcase', items = items }, jobOptionId or 'job')
    elseif jobOptionId then
        RemoveOption(jobOptionId)
        jobOptionId = nil
    end
end

local function BuildMenu()
    SetupJobMenu()
    local all = {}
    for _, v in ipairs(Config.MenuItems) do all[#all + 1] = v end
    for _, id in ipairs(DynamicOrder) do all[#all + 1] = DynamicMenuItems[id] end
    MenuItems = filterItems(all)
end

---------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------

local function canUseMenu()
    local md = RSGCore.Functions.GetPlayerData().metadata or {}
    return not md.isdead and not md.ishandcuffed and not IsPauseMenuActive()
end

local function setRadialState(open)
    if open then
        BuildMenu()
        TriggerEvent('rsg-radialmenu:client:onRadialmenuOpen')
        SendNUIMessage({ action = 'ui', radial = true, items = toNui(MenuItems), hold = Config.HoldToOpen, key = Config.Keybind })
        SetCursorLocation(0.5, 0.5)
    else
        TriggerEvent('rsg-radialmenu:client:onRadialmenuClose')
    end
    SetNuiFocus(open, open)
    inRadialMenu = open

    -- close the menu if the player dies, gets cuffed or opens the pause menu while it is up
    if open then
        CreateThread(function()
            while inRadialMenu do
                Wait(250)
                if inRadialMenu and not canUseMenu() then
                    setRadialState(false)
                    SendNUIMessage({ action = 'ui', radial = false })
                end
            end
        end)
    end
end

CreateThread(function()
    local key = RSGCore.Shared.Keybinds[Config.Keybind]
    if not key then
        print(('^1[%s] Config.Keybind "%s" is not a key in RSGCore.Shared.Keybinds, the menu cannot be opened^7'):format(GetCurrentResourceName(), tostring(Config.Keybind)))
        return
    end
    local activated = Config.HoldToOpen and IsControlJustPressed or IsControlJustReleased

    while true do
        Wait(inRadialMenu and 100 or 0)
        if not inRadialMenu and activated(0, key) and LocalPlayer.state.isLoggedIn and canUseMenu() then
            setRadialState(true)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and inRadialMenu then SetNuiFocus(false, false) end
end)

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------

RegisterNUICallback('closeRadial', function(_, cb)
    if inRadialMenu then setRadialState(false) end
    cb('ok')
end)

RegisterNUICallback('selectItem', function(inData, cb)
    cb('ok')
    if not canUseMenu() or type(inData) ~= 'table' or type(inData.itemData) ~= 'table' then return end

    -- only ever run items that exist in our own menu tree; never trust NUI payloads
    local item = findItem(MenuItems, inData.itemData.id, inData.itemData.event)
    if not item then return end

    if item.action then
        item.action(item)
    elseif item.type == 'client' then
        TriggerEvent(item.event, item)
    elseif item.type == 'server' then
        TriggerServerEvent(item.event, toPayload(item))
    elseif item.type == 'command' then
        ExecuteCommand(item.event)
    elseif item.type == 'rsgcommand' then
        TriggerServerEvent('RSGCore:CallCommand', item.event, toPayload(item))
    end
end)

---------------------------------------------------------------------
-- Events
---------------------------------------------------------------------

RegisterNetEvent('rsg-radialmenu:client:noPlayers', function()
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale('no_one_nearby'), type = 'error', duration = 5000 })
end)

local function sendEmergency(allowedJobs, prefix)
    local pd = RSGCore.Functions.GetPlayerData()
    if not pd.job or not allowedJobs[pd.job.name] then return end

    local now = GetGameTimer()
    if lastEmergency and now - lastEmergency < Config.EmergencyCooldown * 1000 then
        RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale('emergency_cooldown'), type = 'error', duration = 5000 })
        return
    end
    lastEmergency = now

    local msg = locale('emergency_alert', locale(prefix), pd.charinfo.firstname, pd.charinfo.lastname)
    TriggerServerEvent('rsg-lawman:server:lawmanAlert', msg)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale('emergency_sent'), type = 'success', duration = 5000 })
end

RegisterNetEvent('rsg-radialmenu:client:SendLawmanEmergencyAlert', function()
    sendEmergency(Config.LawJobs, 'prefix_officer')
end)

RegisterNetEvent('rsg-radialmenu:client:SendMedicEmergencyAlert', function()
    sendEmergency(Config.MedicJobs, 'prefix_medic')
end)

exports('AddOption', AddOption)
exports('RemoveOption', RemoveOption)
