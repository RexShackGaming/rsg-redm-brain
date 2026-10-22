-- Reference: client NUI open/close bridge. html/script.js posts to https://<resource>/<callback>
local isOpen = false

local function openUI(data)
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

local function closeUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb) closeUI(); cb('ok') end)

-- Forward actions to the server. The server must re-validate everything.
RegisterNUICallback('action', function(body, cb)
    TriggerServerEvent('rsg-example:server:action', body.id)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)

return { open = openUI, close = closeUI }
