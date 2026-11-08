local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------
-- FULL LOCALE TABLE (for the NUI)
-- script.js localizes its own UI text from a full key->string
-- dictionary rather than one key at a time, so we hand it the
-- active locales/<lang>.json file directly (falling back to
-- en.json), matching rsg-core's locale resolution (rsg:locale > ox:locale > en).
---------------------------------------------------------------
local cachedLocaleTable = nil
function GetLocaleTable()
    if cachedLocaleTable then return cachedLocaleTable end
    local lang = GetConvar('rsg:locale', GetConvar('ox:locale', 'en'))
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
    if not raw then
        raw = LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
    end
    cachedLocaleTable = raw and json.decode(raw) or {}
    return cachedLocaleTable
end

---------------------------------------------------------------
-- NOTIFICATIONS (rsg-core)
---------------------------------------------------------------
function Notify(msg, nType, duration)
    RSGCore.Functions.Notify({
        title = locale('notify_title'),
        description = msg,
        type = nType or 'inform',
        duration = duration or 5000,
    })
end

-- NOTE: server-side notifications must use TriggerClientEvent('RSGCore:Client:Notify', ...)
-- from a server file so locale() resolves on the server. Do NOT call
-- TriggerClientEvent from the client (it silently does nothing, which looks
-- like "notifications not working").

---------------------------------------------------------------
-- MODEL LOADING
---------------------------------------------------------------
-- Returns true once loaded, false if the model is invalid or times out
-- (prevents an infinite loop on a bad model name in config).
function LoadModel(model, timeoutMs)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + (timeoutMs or 10000)
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

function LoadTrainCars(trainHash)
    local wagonCount = Citizen.InvokeNative(0x635423D55CA84FC8, trainHash)
    for i = 0, wagonCount - 1 do
        local wagonModel = Citizen.InvokeNative(0x8DF5F6A19F99F0D5, trainHash, i)
        local deadline = GetGameTimer() + 10000
        while not HasModelLoaded(wagonModel) and GetGameTimer() < deadline do
            Citizen.InvokeNative(0xFA28FE3A6246FC30, wagonModel, 1)
            Wait(100)
        end
    end
end

---------------------------------------------------------------
-- DISTANCE HELPER
---------------------------------------------------------------
function GetDistanceBetween(v1, v2)
    return #(v1 - v2)
end

---------------------------------------------------------------
-- DEBUG PRINT
---------------------------------------------------------------
function DebugPrint(msg)
    if Config.Debug then
        print('[rsg-railroad] ' .. tostring(msg))
    end
end

---------------------------------------------------------------
-- FIND NEAREST STATION
---------------------------------------------------------------
function GetNearestStation(coords)
    local nearest, nearestDist = nil, 9999
    for _, station in ipairs(Config.Stations) do
        local dist = GetDistanceBetween(coords, station.coords)
        if dist < nearestDist then
            nearest = station
            nearestDist = dist
        end
    end
    return nearest, nearestDist
end

---------------------------------------------------------------
-- FIND TRAIN CONFIG BY MODEL+COMPANY
---------------------------------------------------------------
function FindTrainConfig(model, company)
    for _, train in ipairs(Config.Trains) do
        if train.model == model and train.company == company then
            return train
        end
    end
    -- fallback: just match model
    for _, train in ipairs(Config.Trains) do
        if train.model == model then
            return train
        end
    end
    return nil
end

---------------------------------------------------------------
-- GET RSGCore OBJECT (for client use)
---------------------------------------------------------------
function GetRSGCore()
    return RSGCore
end

---------------------------------------------------------------
-- NUI FOCUS (push-to-talk stays usable while the UI is open)
---------------------------------------------------------------
local uiFocus = false

function ApplyNuiFocus(enable)
    uiFocus = enable and true or false
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

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            local list = Config.PushToTalkControls
            if list then
                for i = 1, #list do
                    EnableControlAction(0, list[i], true)
                    EnableControlAction(1, list[i], true)
                    EnableControlAction(2, list[i], true)
                end
            end
        else
            Wait(250)
        end
    end
end)

---------------------------------------------------------------
-- NUI INFO MENU (replaces lib.registerContext / lib.showContext)
-- options = { { title = '', description = '' }, ... }
---------------------------------------------------------------
function ShowInfoMenu(title, options)
    SendNUIMessage({ action = 'openInfoMenu', title = title, options = options, lang = GetLocaleTable() })
    ApplyNuiFocus(true)
end

RegisterNUICallback('closeInfoMenu', function(_, cb)
    ApplyNuiFocus(false)
    cb({})
end)

---------------------------------------------------------------
-- NUI CONFIRM DIALOG (replaces lib.alertDialog) -> true / false
---------------------------------------------------------------
local pendingDialog = nil

function ConfirmDialog(data)
    if pendingDialog then pendingDialog:resolve(false) end
    local p = promise.new()
    pendingDialog = p
    SendNUIMessage({
        action  = 'openDialog',
        title   = data.header,
        body    = data.content,
        confirm = data.labels and data.labels.confirm,
        cancel  = data.labels and data.labels.cancel,
    })
    ApplyNuiFocus(true)
    return Citizen.Await(p)
end

RegisterNUICallback('dialogResult', function(data, cb)
    ApplyNuiFocus(false)
    if pendingDialog then
        local p = pendingDialog
        pendingDialog = nil
        p:resolve(data and data.confirmed == true)
    end
    cb({})
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if pendingDialog then pendingDialog:resolve(false) pendingDialog = nil end
    if uiFocus then ApplyNuiFocus(false) end
end)
