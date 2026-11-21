local RSGCore = exports['rsg-core']:GetCoreObject()

local uiFocus  = false
local adminOpen = false -- true while the staff panel (not the radio) is the open UI
local radioKey = nil -- rsg-voice transmit key, kept enabled while the radio is open

---------------------------------------------------------------------
-- NUI focus (push-to-talk keeps working while the radio is open)
---------------------------------------------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    for i = 1, #list do
        EnableControlAction(0, list[i], true)
        EnableControlAction(1, list[i], true)
        EnableControlAction(2, list[i], true)
    end
    if radioKey then
        EnableControlAction(0, radioKey, true)
        EnableControlAction(1, radioKey, true)
        EnableControlAction(2, radioKey, true)
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

---------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------
local function notify(key, nType, ...)
    RSGCore.Functions.Notify({ title = locale('notify_title'), description = locale(key, ...), type = nType, duration = 3000 })
end

local function getStrings()
    return {
        title = locale('ui_title'), subtitle = locale('ui_subtitle'),
        on = locale('ui_status_on'), off = locale('ui_status_off'),
        frequency = locale('ui_frequency'), connect = locale('ui_connect'), disconnect = locale('ui_disconnect'),
        channels = locale('ui_channels'), noChannels = locale('ui_no_channels'),
        active = locale('ui_active'), join = locale('ui_join'),
        hint = locale('ui_hint', Config.TransmitKeyLabel), members = locale('ui_members', '%s'),
        close = locale('ui_close'), move = locale('ui_move'),
        favorites = locale('ui_favorites'), noFavorites = locale('ui_no_favorites'), favAdd = locale('ui_fav_add'),
        favRemove = locale('ui_fav_remove'), favLabel = locale('ui_fav_label'),
        range = locale('ui_range', '%s', '%s'), restricted = locale('ui_restricted'), outOfRange = locale('ui_out_of_range', '%s', '%s'),
        private = locale('ui_private'), privateList = locale('ui_private_list'), code = locale('ui_code'),
        pname = locale('ui_pname'), privCreate = locale('ui_priv_create'), privUpdate = locale('ui_priv_update'),
        privDelete = locale('ui_priv_delete'), privCost = locale('ui_priv_cost', '%s'), privYours = locale('ui_priv_yours'), locked = locale('ui_locked'),
    }
end

local function closeRadio()
    if not uiFocus then return end
    uiFocus, adminOpen = false, false
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('rsg-radio:server:panelClosed')
end

local function openRadio(state)
    if uiFocus then return end
    if not state then return notify('cl_no_radio', 'error') end
    local ok, key = pcall(function() return exports['rsg-voice']:GetRadioTalkKey() end)
    radioKey = ok and key or nil
    uiFocus = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', strings = getStrings(), state = state })
end

local function requestOpen()
    if uiFocus then return end
    RSGCore.Functions.TriggerCallback('rsg-radio:server:getState', openRadio)
end

RegisterCommand(Config.Command, requestOpen, false)

-- Sent by the server when the radio item is used
RegisterNetEvent('rsg-radio:client:open', function()
    if GetInvokingResource() then return end
    requestOpen()
end)

-- Fresh state from the server (after joining/leaving, or nil when the radio was lost)
RegisterNetEvent('rsg-radio:client:state', function(state)
    if GetInvokingResource() then return end
    if not uiFocus then return end
    if not state then return closeRadio() end
    SendNUIMessage({ action = 'state', state = state })
end)

---------------------------------------------------------------------
-- NUI callbacks (the server validates everything again)
---------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    closeRadio()
    cb('ok')
end)

-- NUI callback that forwards a frequency (and optionally a favorite name) to a server event
local function forwardFreq(name, event, withLabel)
    RegisterNUICallback(name, function(data, cb)
        cb('ok')
        local freq = tonumber(data and data.freq)
        if not freq then return end
        if withLabel then TriggerServerEvent(event, freq, tostring(data.label or '')) else TriggerServerEvent(event, freq) end
    end)
end
-- join may carry a passcode for private channels
RegisterNUICallback('join', function(data, cb)
    cb('ok')
    local freq = tonumber(data and data.freq)
    if not freq then return end
    local code = type(data.code) == 'string' and data.code ~= '' and data.code:sub(1, 32) or nil
    TriggerServerEvent('rsg-radio:server:join', freq, code)
end)
RegisterNUICallback('savePrivate', function(data, cb)
    cb('ok')
    local freq = tonumber(data and data.freq)
    if not freq then return end
    TriggerServerEvent('rsg-radio:server:savePrivate', freq, tostring(data.name or ''), tostring(data.code or ''))
end)
forwardFreq('deletePrivate', 'rsg-radio:server:deletePrivate')
forwardFreq('addFavorite', 'rsg-radio:server:addFavorite', true)
forwardFreq('removeFavorite', 'rsg-radio:server:removeFavorite')

RegisterNUICallback('leave', function(_, cb)
    cb('ok')
    TriggerServerEvent('rsg-radio:server:leave')
end)

-- Favorite hotkeys (rebindable in the game's key settings)
local hk = Config.FavoriteHotkeys
if hk and hk.Enabled then
    RegisterCommand('+rsgradio_nextfav', function() TriggerServerEvent('rsg-radio:server:cycleFavorite', 1) end, false)
    RegisterCommand('-rsgradio_nextfav', function() end, false)
    RegisterCommand('+rsgradio_prevfav', function() TriggerServerEvent('rsg-radio:server:cycleFavorite', -1) end, false)
    RegisterCommand('-rsgradio_prevfav', function() end, false)
    RegisterKeyMapping('+rsgradio_nextfav', locale('ui_key_next_fav'), 'keyboard', hk.Next)
    RegisterKeyMapping('+rsgradio_prevfav', locale('ui_key_prev_fav'), 'keyboard', hk.Prev)
end

---------------------------------------------------------------------
-- Admin panel (staff). The server checks the permission on every call.
---------------------------------------------------------------------
local function adminStrings()
    local s = {}
    for _, k in ipairs({ 'title', 'subtitle', 'tab_channels', 'tab_private', 'tab_blocks', 'tab_log', 'stat_onair', 'stat_channels',
        'stat_private', 'stat_blocks', 'no_members', 'kick', 'mute', 'unmute', 'minutes', 'clear', 'delete', 'refresh', 'kind_public',
        'kind_restricted', 'kind_private', 'owner', 'offline', 'none', 'no_log', 'search', 'confirm_yes', 'confirm_no' }) do
        s[k] = locale('adm_' .. k)
    end
    s.idle = locale('adm_idle', '%s')
    s.left = locale('adm_left', '%s')
    s.members = locale('adm_members', '%s')
    s.confirmClear = locale('adm_confirm_clear', '%s')
    s.confirmDelete = locale('adm_confirm_delete', '%s')
    s.close = locale('ui_close')
    s.move = locale('ui_move')
    return s
end

local function showAdmin(data)
    if uiFocus then return end
    if not data then return notify('staff_no_access', 'error') end
    local ok, key = pcall(function() return exports['rsg-voice']:GetRadioTalkKey() end)
    radioKey = ok and key or nil
    uiFocus, adminOpen = true, true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'adminOpen', strings = adminStrings(), data = data })
end

RegisterNetEvent('rsg-radio:client:admin:open', function()
    if GetInvokingResource() or uiFocus then return end
    RSGCore.Functions.TriggerCallback('rsg-radio:server:admin:getData', showAdmin)
end)

RegisterNetEvent('rsg-radio:client:admin:data', function(data)
    if GetInvokingResource() or not adminOpen or not data then return end
    SendNUIMessage({ action = 'adminData', data = data })
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    cb('ok')
    if not adminOpen then return end
    RSGCore.Functions.TriggerCallback('rsg-radio:server:admin:getData', function(data)
        if data and adminOpen then SendNUIMessage({ action = 'adminData', data = data }) end
    end)
end)

-- name, server event, how to read the payload from the NUI message
local function adminAction(name, event, build)
    RegisterNUICallback(name, function(data, cb)
        cb('ok')
        if not adminOpen or type(data) ~= 'table' then return end
        local a, b = build(data)
        if a == nil then return end
        TriggerServerEvent(event, a, b)
    end)
end
adminAction('adminKick', 'rsg-radio:server:admin:kick', function(d) return tonumber(d.id) end)
adminAction('adminMute', 'rsg-radio:server:admin:mute', function(d) return tonumber(d.id), tonumber(d.minutes) end)
adminAction('adminUnmute', 'rsg-radio:server:admin:unmute', function(d) return type(d.cid) == 'string' and d.cid or nil end)
adminAction('adminDeletePrivate', 'rsg-radio:server:admin:deletePrivate', function(d) return tonumber(d.freq) end)
adminAction('adminClear', 'rsg-radio:server:admin:clearChannel', function(d) return tonumber(d.freq) end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    closeRadio()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
end)
