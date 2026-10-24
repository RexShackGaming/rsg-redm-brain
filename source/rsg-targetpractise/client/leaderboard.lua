lib.locale()

local wanted, visible, ready, latest = false, false, false, nil
local requestId = 0

local function display()
    if not wanted or not ready or not latest then return end
    local action = visible and 'leaderboard' or 'openLeaderboard'
    visible = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = action, data = latest, locales = TargetPractiseLocale.ui() })
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
            lib.notify({ title = locale('notify_title'), description = locale('board_timeout'), type = 'error', duration = 5000 })
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
        if wanted or visible then SetNuiFocus(false, false) end
    end
end)
