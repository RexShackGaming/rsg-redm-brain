-- Reference: client NUI open/close bridge. html/script.js posts to https://<resource>/<callback>
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

local function openUI(data)
    if isOpen then return end
    isOpen = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', data = data })
end

local function closeUI()
    if not isOpen then return end
    isOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('close', function(_, cb) closeUI(); cb('ok') end)

-- Forward actions to the server. The server must re-validate everything.
RegisterNUICallback('action', function(body, cb)
    TriggerServerEvent('rsg-example:server:action', body.id)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() and isOpen then applyNuiFocus(false) end
end)

return { open = openUI, close = closeUI }
