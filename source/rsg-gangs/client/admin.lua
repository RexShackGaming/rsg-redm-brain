local RSGCore = exports['rsg-core']:GetCoreObject()

local adminOpen = false

local function closeAdmin()
    if not adminOpen then return end
    adminOpen = false
    RSGGangsClient.SetFocus(false)
    SendNUIMessage({ action = 'adminClose' })
end

-- The server only sends this to players that passed the permission check.
RegisterNetEvent('rsg-gangs:client:openAdmin', function()
    if adminOpen or not (Config.Admin and Config.Admin.enabled) then return end
    adminOpen = true
    RSGGangsClient.SetFocus(true)
    SendNUIMessage({ action = 'locale', data = locale() })
    SendNUIMessage({ action = 'adminOpen' })
end)

RegisterNUICallback('adminClose', function(_, cb)
    closeAdmin()
    cb('ok')
end)

-- Single bridge for every panel action: the server re-checks the permission on each call.
RegisterNUICallback('adminCall', function(data, cb)
    data = type(data) == 'table' and data or {}
    if not adminOpen or type(data.action) ~= 'string' then
        cb({ ok = false })
        return
    end
    local result = RSGCore.Functions.AwaitCallback('rsg-gangs:server:admin', 15000, data.action, data.payload)
    cb(type(result) == 'table' and result or { ok = false })
end)

RegisterNetEvent('rsg-gangs:client:adminTeleport', function(x, y, z)
    if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return end
    local ped = PlayerPedId()
    local entity = IsPedOnMount(ped) and GetMount(ped) or ped
    SetEntityCoords(entity, x, y, z + 0.5, false, false, false, false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    adminOpen = false
end)
