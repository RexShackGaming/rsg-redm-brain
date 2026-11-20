local RSGCore = exports['rsg-core']:GetCoreObject()

-- Small shared table for the other client files (loaded after this one).
RSGGangsClient = {
    gangName = nil,            -- name of the gang the local player is in
    hasDeployedEquipment = false,
    receivedState = false,
}

local menuOpen = false
local uiFocus = false
local currentState = { inGang = false }

function RSGGangsClient.Notify(description, nType)
    RSGCore.Functions.Notify({
        title = locale('notify_title'),
        description = description,
        type = nType or 'inform',
        duration = Config.Notify and Config.Notify.duration or 5000,
    })
end

---------------------------------------------------------------------
-- NUI focus with push-to-talk support
---------------------------------------------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

-- With keep-input on, every key reaches the game, so block everything except push-to-talk.
local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    for _, control in ipairs(Config.PushToTalkControls or {}) do
        EnableControlAction(0, control, true)
        EnableControlAction(1, control, true)
        EnableControlAction(2, control, true)
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

local function openMenu(focusOnly)
    if menuOpen then return end
    menuOpen = true
    uiFocus = true
    applyNuiFocus(true)
    if not focusOnly then
        TriggerServerEvent('rsg-gangs:server:requestState')
        SendNUIMessage({ action = 'locale', data = locale() })
        SendNUIMessage({ action = 'open' })
    end
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    uiFocus = false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

-- Used by client/crafting.lua, which opens its own NUI view.
function RSGGangsClient.OpenFocusOnly()
    if menuOpen then return end
    menuOpen = true
    uiFocus = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'locale', data = locale() })
end

RegisterNetEvent('rsg-gangs:client:openMenu', function() openMenu(false) end)
RegisterNetEvent('rsg-gangs:client:closeMenu', closeMenu)

RegisterNetEvent('rsg-gangs:client:requestAccept', function()
    TriggerServerEvent('rsg-gangs:server:acceptInvite')
end)

RegisterNetEvent('rsg-gangs:client:requestDecline', function()
    TriggerServerEvent('rsg-gangs:server:declineInvite')
end)

---------------------------------------------------------------------
-- State from the server
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:client:setState', function(state)
    state = state or { inGang = false }
    currentState = state
    RSGGangsClient.receivedState = true
    RSGGangsClient.gangName = state.gang and state.gang.name or nil

    local deployed = false
    for _, item in ipairs((state.gang and state.gang.equipment) or {}) do
        if item.deployed then deployed = true break end
    end
    RSGGangsClient.hasDeployedEquipment = deployed

    SendNUIMessage({ action = 'state', data = state })
end)

function RSGGangsClient.RequestState()
    TriggerServerEvent('rsg-gangs:server:requestState')
    TriggerServerEvent('rsg-gangs:server:requestWagonRegistry')
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    RSGGangsClient.receivedState = false
    RSGGangsClient.RequestState()
end)

-- Covers a resource restart while the player is already in game.
CreateThread(function()
    Wait(2000)
    if LocalPlayer.state.isLoggedIn == false then return end
    RSGGangsClient.RequestState()
    local attempts = 0
    while not RSGGangsClient.receivedState and attempts < 12 do
        Wait(5000)
        if not RSGGangsClient.receivedState then RSGGangsClient.RequestState() end
        attempts = attempts + 1
    end
end)

---------------------------------------------------------------------
-- NUI callbacks (every one just forwards; the server validates)
---------------------------------------------------------------------
local function forward(name, event, ...)
    local keys = { ... }
    RegisterNUICallback(name, function(data, cb)
        data = type(data) == 'table' and data or {}
        local args = {}
        for i, key in ipairs(keys) do
            local value = data[key]
            if key == 'amount' or key == 'serverId' then value = tonumber(value) end
            args[i] = value
        end
        TriggerServerEvent(event, table.unpack(args, 1, #keys))
        cb('ok')
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb('ok')
end)

forward('createGang', 'rsg-gangs:server:createGang', 'label')
forward('disbandGang', 'rsg-gangs:server:disbandGang')
forward('invitePlayer', 'rsg-gangs:server:invitePlayer', 'serverId')
forward('kickMember', 'rsg-gangs:server:kickMember', 'citizenid')
forward('leaveGang', 'rsg-gangs:server:leaveGang')
forward('promoteMember', 'rsg-gangs:server:promoteMember', 'citizenid')
forward('demoteMember', 'rsg-gangs:server:demoteMember', 'citizenid')
forward('transferLeadership', 'rsg-gangs:server:transferLeadership', 'citizenid')
forward('depositMoney', 'rsg-gangs:server:depositMoney', 'amount')
forward('withdrawMoney', 'rsg-gangs:server:withdrawMoney', 'amount')
forward('renameGang', 'rsg-gangs:server:renameGang', 'label')
forward('setColor', 'rsg-gangs:server:setColor', 'color')
forward('deployEquipment', 'rsg-gangs:server:deployEquipment', 'id')
forward('packEquipment', 'rsg-gangs:server:packEquipment', 'id')
forward('upgradeGangStash', 'rsg-gangs:server:upgradeGangStash')
forward('resetWagon', 'rsg-gangs:server:resetWagon')
forward('craftItem', 'rsg-gangs:server:craftItem', 'stationId', 'id')
forward('declineInvite', 'rsg-gangs:server:declineInvite')
forward('refresh', 'rsg-gangs:server:requestState')

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
end)
