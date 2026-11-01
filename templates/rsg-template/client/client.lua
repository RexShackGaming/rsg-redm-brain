local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false

local function closeUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('rsg-template:client:open', function()
    if isOpen then return end
    local items = RSGCore.Functions.AwaitCallback('rsg-template:server:getData')
    isOpen = true
    SetNuiFocus(true, true)
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
    if isOpen then SetNuiFocus(false, false) end
end)
