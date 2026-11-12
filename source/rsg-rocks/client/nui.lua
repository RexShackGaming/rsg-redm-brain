-- Shared NUI focus for the drill menu and lamp panel.
-- Keeps rsg-voice push-to-talk working while a UI has focus.
local owners = {} -- [name] = true while that UI wants focus
local focused = false

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

function RocksSetNuiFocus(owner, enable)
    owners[owner] = enable or nil
    local want = next(owners) ~= nil
    if want == focused then return end
    focused = want
    applyNuiFocus(want)
end

CreateThread(function()
    while true do
        if focused and Config.AllowPushToTalkWhileOpen then
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

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and focused then applyNuiFocus(false) end
end)
