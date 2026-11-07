local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- KeepInput passes every key to the game, so while focused block all controls
-- except push-to-talk (see patterns/nui-push-to-talk.md)
CreateThread(function()
    while true do
        if isOpen and Config.AllowPushToTalkWhileOpen then
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
    if not isOpen then return end
    isOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('rsg-template:client:open', function()
    if isOpen then return end
    local items = RSGCore.Functions.AwaitCallback('rsg-template:server:getData')
    isOpen = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', data = { title = locale('ui_title'), items = items } })
end)

RegisterNUICallback('close', function(_, cb) closeUI(); cb('ok') end)

RegisterNUICallback('select', function(body, cb)
    TriggerServerEvent('rsg-template:server:select', body.id)
    cb('ok')
end)

local zone = exports['rsg-target']:addSphereZone({
    coords = Config.ShopCoords, radius = 1.5, debug = Config.Debug,
    options = {{ name = 'rsg-template:open', icon = 'fa-solid fa-hand', label = locale('target_label'), distance = 2.0,
        onSelect = function() TriggerEvent('rsg-template:client:open') end }},
})

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    exports['rsg-target']:removeZone(zone)
    if isOpen then applyNuiFocus(false) end
end)
