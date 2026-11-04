local wanted, visible, ready, latest = false, false, false, nil
local requestId = 0

local function display()
    if not wanted or not ready or not latest then return end
    local opening = not visible
    visible = true
    if opening then SetNuiFocus(true, true) end
    -- Locales are only needed once per open, not on every live refresh.
    SendNUIMessage({
        action = opening and 'openLeaderboard' or 'leaderboard', data = latest,
        locales = opening and TargetPractiseLocale.ui() or nil
    })
end

local function close()
    requestId = requestId + 1
    wanted, visible, latest = false, false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('rsg-targetpractise:server:leaderboard', false)
end

RegisterNetEvent('rsg-targetpractise:client:openLeaderboard', function()
    if wanted then return end
    wanted = true
    requestId = requestId + 1
    local request = requestId
    TriggerServerEvent('rsg-targetpractise:server:leaderboard', true)
    -- Recover if the server has not loaded the player yet or a request was throttled.
    SetTimeout(5000, function()
        if request == requestId and wanted and not visible then
            close()
            TargetPractiseNotify(locale('board_timeout'), 'error')
        end
    end)
end)

RegisterNetEvent('rsg-targetpractise:client:leaderboard', function(data)
    if not wanted then return end
    latest = data
    display()
end)

RegisterNUICallback('ready', function(_, cb)
    ready = true
    visible = false
    if not wanted then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
    display()
    cb({ ok = true, locales = TargetPractiseLocale.ui() })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb({ ok = true })
end)

RegisterCommand('targetboard', function()
    TriggerEvent('rsg-targetpractise:client:openLeaderboard')
end, false)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', close)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if wanted or visible then
            SetNuiFocus(false, false)
            TriggerServerEvent('rsg-targetpractise:server:leaderboard', false)
        end
    end
end)
