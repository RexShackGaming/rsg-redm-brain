local RSGCore = exports['rsg-core']:GetCoreObject()

---------------------------------------------------------------
-- FULL LOCALE TABLE (for the NUI)
-- script.js localizes its own UI text from a full key->string
-- dictionary rather than one key at a time, so we hand it the
-- active locales/<lang>.json file directly (falling back to
-- en.json), matching lib.locale()'s own language resolution.
---------------------------------------------------------------
local cachedLocaleTable = nil
function GetLocaleTable()
    if cachedLocaleTable then return cachedLocaleTable end
    local lang = GetConvar('ox:locale', 'en')
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(lang))
    if not raw then
        raw = LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
    end
    cachedLocaleTable = raw and json.decode(raw) or {}
    return cachedLocaleTable
end

---------------------------------------------------------------
-- NOTIFICATIONS (ox_lib wrapper)
---------------------------------------------------------------
function Notify(msg, nType, duration)
    lib.notify({
        title = locale('notify_title'),
        description = msg,
        type = nType or 'inform',
        duration = duration or 5000,
    })
end

-- NOTE: server-side notifications must use TriggerClientEvent('ox_lib:notify', ...)
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
