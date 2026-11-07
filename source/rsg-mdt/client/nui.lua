NUI = {}

local windowState = {
    width = 1100,
    height = 700,
}

local externalStateCallback = nil

function NUI.SetStateCallback(cb)
    externalStateCallback = cb
end

function NUI.SendMessage(action, data)
    SendNuiMessage(json.encode({ action = action, data = data or {} }))
end

function NUI.SetVisibility(visible)
    NUI.SendMessage('setVisible', { visible = visible })
end

local mdtFocus = false

function NUI.SetFocus(hasFocus, hasCursor)
    if hasFocus then
        mdtFocus = true
        SetNuiFocus(true, hasCursor ~= false)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        mdtFocus = false
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- Push-to-talk whitelist while the MDT has focus
CreateThread(function()
    while true do
        if mdtFocus and Config.AllowPushToTalkWhileOpen then
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
    if res == GetCurrentResourceName() and mdtFocus then
        NUI.SetFocus(false)
    end
end)

function NUI.Open(data)
    NUI.SetFocus(true, true)
    
    local openData = data or {}
    openData.window = {
        width = windowState.width,
        height = windowState.height,
    }
    
    NUI.SendMessage('open', openData)
    
    if externalStateCallback then
        externalStateCallback(true)
    end
end

function NUI.Close()
    NUI.SetFocus(false, false)
    NUI.SendMessage('close')
    
    if externalStateCallback then
        externalStateCallback(false)
    end
end

function NUI.GetWindowState()
    return {
        width = windowState.width,
        height = windowState.height,
    }
end

function NUI.SetWindowState(state)
    if state.width then windowState.width = state.width end
    if state.height then windowState.height = state.height end
end

RegisterNuiCallback('windowResize', function(data, cb)
    if data.width and data.height then
        windowState.width = data.width
        windowState.height = data.height
    end
    cb({ success = true })
end)
