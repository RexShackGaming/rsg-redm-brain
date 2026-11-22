-- rsg-stables: admin panel (client)
-- Opens the NUI from /horseadmin (server checks the permission) and relays the panel's requests to the server callbacks in
-- server/admin.lua. The client never decides anything: every callback re-checks the admin permission on the server.
local RSGCore = exports['rsg-core']:GetCoreObject()

if not (Config.Admin and Config.Admin.enabled) then return end

local uiFocus = false

-- push-to-talk friendly focus (see Config.AllowPushToTalkWhileOpen)
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            local list = Config.PushToTalkControls
            if list then
                for i = 1, #list do
                    EnableControlAction(0, list[i], true)
                    EnableControlAction(1, list[i], true)
                    EnableControlAction(2, list[i], true)
                end
            end
        else
            Wait(250)
        end
    end
end)

local STRING_KEYS = {
    'title', 'subtitle', 'search_ph', 'search', 'online', 'offline', 'horses_n', 'no_players', 'no_horses', 'back', 'close',
    'give', 'give_title', 'edit_title', 'save', 'cancel', 'transfer', 'transfer_title', 'transfer_ph', 'delete', 'confirm_delete',
    'confirm', 'actions', 'stats', 'danger', 'give_to', 'status_out', 'status_stored', 'status_dead', 'busy_out',
    'f_name', 'f_gender', 'f_stable', 'f_breed', 'f_age', 'f_foal', 'f_insured', 'f_health', 'f_stamina', 'f_hunger',
    'f_thirst', 'f_bonding', 'f_speed', 'f_accel', 'f_handling', 'f_maxhealth', 'male', 'female', 'yes', 'no', 'days',
    'stage_young', 'stage_adult', 'stage_old', 'a_forceStore', 'a_revive', 'a_resetShoes', 'a_resetCoat', 'a_resetTack',
    'a_resetTraining', 'a_clearCooldown', 'a_openSaddlebags', 'loading', 'error',
}

local function buildStrings()
    local out = {}
    for _, k in ipairs(STRING_KEYS) do out[k] = locale('adm_' .. k) end
    return out
end

RegisterNetEvent('rsg-stables:client:openAdmin', function()
    if uiFocus then return end
    uiFocus = true
    SendNUIMessage({ action = 'adminOpen', strings = buildStrings() })
    applyNuiFocus(true)
end)

-- the admin force-stored this player's horse: remove it from the world without touching the database
RegisterNetEvent('rsg-stables:client:adminStoreHorse', function()
    if DespawnActiveHorseForAdmin then DespawnActiveHorseForAdmin() end
end)

local function wrap(name, serverName)
    RegisterNUICallback(name, function(data, cb)
        data = type(data) == 'table' and data or {}
        local a, b = RSGCore.Functions.AwaitCallback(serverName, 8000, data.a, data.b, data.c, data.d, data.e, data.f, data.g)
        cb({ ok = a, data = b })
    end)
end

wrap('adminSearch',       'rsg-stables:server:admin:search')
wrap('adminOptions',      'rsg-stables:server:admin:getOptions')
wrap('adminHorses',       'rsg-stables:server:admin:getHorses')
wrap('adminUpdate',       'rsg-stables:server:admin:updateHorse')
wrap('adminAction',       'rsg-stables:server:admin:action')
wrap('adminGive',         'rsg-stables:server:admin:giveHorse')
wrap('adminTransfer',     'rsg-stables:server:admin:transferHorse')

RegisterNUICallback('adminClose', function(_, cb)
    cb('ok')
    if uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
end)
