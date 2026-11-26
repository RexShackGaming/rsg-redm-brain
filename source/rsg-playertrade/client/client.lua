local uiOpen = false

local labelKeys = {
    'ui_title', 'ui_with', 'ui_inventory', 'ui_your_offer', 'ui_their_offer', 'ui_empty_inventory', 'ui_empty_offer',
    'ui_cash', 'ui_set', 'ui_have', 'ui_ready', 'ui_unready', 'ui_confirm', 'ui_cancel', 'ui_quantity', 'ui_add',
    'ui_quality', 'ui_serial', 'ui_hint', 'ui_waiting', 'ui_partner_ready', 'ui_check', 'ui_waiting_confirm',
    'ui_partner_confirmed', 'ui_changed', 'ui_search',
}
local labels

local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function Close()
    if not uiOpen then return end
    uiOpen = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function Cancel()
    Close()
    TriggerServerEvent('rsg-playertrade:server:cancel')
end

RegisterNetEvent('rsg-playertrade:client:open', function(state)
    if not labels then
        labels = {}
        for _, k in ipairs(labelKeys) do labels[k] = locale(k) end
    end
    uiOpen = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', state = state, labels = labels, imagePath = Config.ImagePath,
        allowCash = Config.AllowCash, lockSeconds = Config.LockSeconds })
end)

RegisterNetEvent('rsg-playertrade:client:update', function(state)
    if uiOpen then SendNUIMessage({ action = 'update', state = state }) end
end)

RegisterNetEvent('rsg-playertrade:client:close', Close)

-- NUI -> server (the server checks everything again)
RegisterNUICallback('cancel', function(_, cb) cb('ok') Cancel() end)

RegisterNUICallback('setItem', function(data, cb)
    cb('ok')
    TriggerServerEvent('rsg-playertrade:server:setItem', data.slot, data.amount, data.name)
end)

RegisterNUICallback('setCash', function(data, cb)
    cb('ok')
    TriggerServerEvent('rsg-playertrade:server:setCash', data.amount)
end)

RegisterNUICallback('ready', function(data, cb)
    cb('ok')
    TriggerServerEvent('rsg-playertrade:server:ready', data.rev, data.state == true)
end)

RegisterNUICallback('confirm', function(data, cb)
    cb('ok')
    TriggerServerEvent('rsg-playertrade:server:confirm', data.rev)
end)

CreateThread(function()
    while true do
        if uiOpen then
            if IsEntityDead(PlayerPedId()) or IsPauseMenuActive() then
                Cancel()
                Wait(250)
            elseif Config.AllowPushToTalkWhileOpen then
                Wait(0)
                DisableAllControlActions(0)
                DisableAllControlActions(1)
                DisableAllControlActions(2)
                for _, control in ipairs(Config.PushToTalkControls or {}) do
                    EnableControlAction(0, control, true)
                    EnableControlAction(1, control, true)
                    EnableControlAction(2, control, true)
                end
            else
                Wait(250)
            end
        else
            Wait(250)
        end
    end
end)

--------------------------------------------------------------------------------
-- rsg-target
--------------------------------------------------------------------------------
local function ServerIdOf(entity)
    local player = NetworkGetPlayerIndexFromPed(entity)
    if not player or player == -1 then return nil end
    return GetPlayerServerId(player)
end

if Config.UseTarget then
    exports['rsg-target']:addGlobalPlayer({
        {
            name = 'rsg_playertrade_request', icon = 'fa-solid fa-handshake', label = locale('target_trade'),
            distance = Config.Distance,
            canInteract = function() return not uiOpen end,
            onSelect = function(data)
                local id = ServerIdOf(data.entity)
                if id then TriggerServerEvent('rsg-playertrade:server:request', id) end
            end,
        },
    })
end

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', Close)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then applyNuiFocus(false) end
    if Config.UseTarget then exports['rsg-target']:removeGlobalPlayer('rsg_playertrade_request') end
end)
