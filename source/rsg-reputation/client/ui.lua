-- rsg-reputation: NUI panel (/reputation)
local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false
local uiFocus = false

local function applyNuiFocus(enable)
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

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

local STRING_KEYS = {
    'ui_title', 'ui_subtitle', 'ui_honor', 'ui_standing', 'ui_infamy', 'ui_fame', 'ui_states', 'ui_towns',
    'ui_prices', 'ui_hostile', 'ui_close', 'ui_empty', 'ui_only_known', 'ui_show_all',
}

local function strings()
    local out = {}
    for i = 1, #STRING_KEYS do out[STRING_KEYS[i]] = locale(STRING_KEYS[i]) end
    return out
end

local function closeUi()
    if not uiOpen then return end
    uiOpen = false
    uiFocus = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function openUi()
    if uiOpen then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-reputation:server:getReputation', 5000)
    if not data then
        RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale('notify_panel_failed'), type = 'error' })
        return
    end
    uiOpen = true
    uiFocus = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', data = data, strings = strings() })
end

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

if Config.Command and Config.Command ~= '' then
    RegisterCommand(Config.Command, function()
        if uiOpen then closeUi() else CreateThread(openUi) end
    end, false)
end

RegisterNetEvent('rsg-reputation:client:open', function()
    CreateThread(openUi)
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function() closeUi() end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiFocus then applyNuiFocus(false) end
end)
