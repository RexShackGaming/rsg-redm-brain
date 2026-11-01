local RSGCore = exports['rsg-core']:GetCoreObject()

local uiOpen = false

---------------------------------
-- npc
---------------------------------
DrugsProximityNpc(Config.NPC, {
    name = 'rsg_drugs_talk',
    icon = 'far fa-comments',
    label = locale('target_talk'),
    onSelect = function() TriggerEvent('rsg-drugs:client:open') end,
})

---------------------------------
-- nui
---------------------------------
local function closeUI()
    uiOpen = false
    TriggerServerEvent('rsg-drugs:server:closed')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

AddEventHandler('rsg-drugs:client:open', function()
    if uiOpen then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-drugs:server:getLab', 10000)
    if not data then return end
    data.supplies = RSGCore.Functions.AwaitCallback('rsg-drugs:server:getSupplies', 10000)
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data, locale = locale() })
end)

RegisterNetEvent('rsg-drugs:client:refresh', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'update', data = data })
end)

RegisterNUICallback('close', function(_, cb) closeUI() cb('ok') end)

RegisterNUICallback('action', function(body, cb)
    local data = RSGCore.Functions.AwaitCallback('rsg-drugs:server:action', 10000, body.action, body.data)
    if data then data.supplies = RSGCore.Functions.AwaitCallback('rsg-drugs:server:getSupplies', 10000) end
    cb(data or false)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
end)

-- don't leave the cursor stuck if the player dies / logs out with the lab open
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() if uiOpen then closeUI() end end)
