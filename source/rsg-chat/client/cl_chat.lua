local RSGCore = exports['rsg-core']:GetCoreObject()

local chatInputActive = false
local chatInputActivating = false
local chatHidden = true
local chatLoaded = false
local adminOpen = false
local aimFaded = false
local aimHideEnabled = Config.DefaultSettings.aimHide ~= false -- player setting, synced from the NUI
local myChannels = {}
local channelSuggestions = {}

local KVP_SETTINGS = 'rsgchat_settings'
local CB_TIMEOUT = 5000

local function notify(key, ntype, ...)
    RSGCore.Functions.Notify({ title = locale('chat_title'), description = locale(key, ...), type = ntype or 'inform', duration = 4000 })
end

local function adminCall(name, ...)
    return RSGCore.Functions.AwaitCallback('rsg-chat:server:' .. name, CB_TIMEOUT, ...) or { ok = false }
end

-- Locale keys the NUI needs (sent once on load)
local UI_KEYS = {
    'ui_settings', 'ui_layout', 'ui_font_size', 'ui_opacity', 'ui_timestamps', 'ui_history',
    'ui_autohide', 'ui_hide_delay', 'ui_fade', 'ui_hide', 'ui_never', 'ui_reset_layout',
    'ui_close', 'ui_seconds', 'ui_messages', 'ui_drag_hint', 'ui_tab_hint',
    'ui_admin_title', 'ui_admin_sub', 'ui_new_channel', 'ui_channel_id', 'ui_label', 'ui_command',
    'ui_prefix', 'ui_show_prefix', 'ui_color', 'ui_range', 'ui_distance', 'ui_jobs', 'ui_gangs',
    'ui_require_duty', 'ui_permission', 'ui_everyone', 'ui_max_length', 'ui_enabled', 'ui_save',
    'ui_delete', 'ui_cancel', 'ui_confirm_delete', 'ui_saved', 'ui_deleted', 'ui_error',
    'ui_range_global', 'ui_range_local', 'ui_range_regional', 'ui_range_group',
    'ui_aim_hide', 'ui_tab_channels', 'ui_tab_logs', 'ui_search', 'ui_log_text', 'ui_log_player', 'ui_log_channel',
    'ui_all_channels', 'ui_no_results', 'ui_log_hint',
    'ui_list_hint', 'ui_chat_enabled', 'ui_chat_off_hint', 'ui_select_channel', 'ui_preview', 'ui_success', 'ui_info',
}

local function uiStrings()
    local t = {}
    for _, k in ipairs(UI_KEYS) do t[k] = locale(k) end
    return t
end

local function loadSettings()
    local raw = GetResourceKvpString(KVP_SETTINGS)
    if not raw then return nil end
    local ok, data = pcall(json.decode, raw)
    return ok and type(data) == 'table' and data or nil
end

-- "Fade while aiming" lives in the player's saved settings; the Lua side needs it to decide when to fade
local function applyAimSetting(settings)
    if type(settings) == 'table' and settings.aimHide ~= nil then
        aimHideEnabled = settings.aimHide == true
    else
        aimHideEnabled = Config.DefaultSettings.aimHide ~= false
    end
end

RegisterNetEvent('chatMessage')
RegisterNetEvent('chat:addTemplate')
RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:addSuggestion')
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:removeSuggestion')
RegisterNetEvent('chat:clear')
RegisterNetEvent('__cfx_internal:serverPrint')

---------------------------------------------------------------------
-- Legacy / compatibility events
---------------------------------------------------------------------
AddEventHandler('chatMessage', function(author, color, text)
    local args = { text }
    if author ~= '' then table.insert(args, 1, author) end
    SendNUIMessage({ type = 'ON_MESSAGE', message = { color = color, multiline = true, args = args } })
end)

AddEventHandler('__cfx_internal:serverPrint', function(msg)
    print(msg)
    SendNUIMessage({ type = 'ON_MESSAGE', message = { templateId = 'print', multiline = true, args = { msg } } })
end)

AddEventHandler('chat:addMessage', function(message)
    SendNUIMessage({ type = 'ON_MESSAGE', message = message })
end)

AddEventHandler('chat:addSuggestion', function(name, help, params)
    SendNUIMessage({ type = 'ON_SUGGESTION_ADD', suggestion = { name = name, help = help, params = params or nil } })
end)

AddEventHandler('chat:addSuggestions', function(suggestions)
    if type(suggestions) ~= 'table' then return end
    SendNUIMessage({ type = 'ON_SUGGESTIONS_ADD', suggestions = suggestions }) -- one NUI message for the whole batch
end)

AddEventHandler('chat:removeSuggestion', function(name)
    SendNUIMessage({ type = 'ON_SUGGESTION_REMOVE', name = name })
end)

AddEventHandler('chat:addTemplate', function(id, html)
    SendNUIMessage({ type = 'ON_TEMPLATE_ADD', template = { id = id, html = html } })
end)

AddEventHandler('chat:clear', function()
    SendNUIMessage({ type = 'ON_CLEAR' })
end)

---------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------
local function refreshChannelSuggestions()
    for _, name in ipairs(channelSuggestions) do
        SendNUIMessage({ type = 'ON_SUGGESTION_REMOVE', name = name })
    end
    channelSuggestions = {}
    local param = { { name = locale('param_message'), help = locale('param_message_help') } }
    local batch = {}
    for _, ch in ipairs(myChannels) do
        if ch.command and ch.command ~= '' then
            local name = '/' .. ch.command
            channelSuggestions[#channelSuggestions + 1] = name
            batch[#batch + 1] = { name = name, help = locale('help_channel', ch.label), params = param }
        end
    end
    if #batch > 0 then SendNUIMessage({ type = 'ON_SUGGESTIONS_ADD', suggestions = batch }) end
end

RegisterNetEvent('rsg-chat:client:syncChannels', function(list, defaultId)
    myChannels = type(list) == 'table' and list or {}
    SendNUIMessage({ type = 'ON_CHANNELS', channels = myChannels, defaultChannel = defaultId })
    if chatLoaded then refreshChannelSuggestions() end
end)

RegisterNetEvent('rsg-chat:client:channelMessage', function(payload)
    if type(payload) ~= 'table' then return end
    SendNUIMessage({ type = 'ON_CHANNEL_MESSAGE', message = payload })
end)

local function requestChannels() TriggerServerEvent('rsg-chat:server:requestChannels') end
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', requestChannels)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', requestChannels)
RegisterNetEvent('RSGCore:Client:OnGangUpdate', requestChannels)

---------------------------------------------------------------------
-- NUI callbacks: chat
---------------------------------------------------------------------
RegisterNUICallback('chatResult', function(data, cb)
    chatInputActive = false
    SetNuiFocus(false, false)
    if type(data) ~= 'table' then return cb('ok') end

    local message = type(data.message) == 'string' and data.message or ''
    if not data.canceled and message ~= '' then
        if message:sub(1, 1) == '/' then
            ExecuteCommand(message:sub(2))
        else
            TriggerServerEvent('rsg-chat:server:send', type(data.channel) == 'string' and data.channel or '', message)
        end
    end
    cb('ok')
end)

RegisterNUICallback('saveSettings', function(data, cb)
    if type(data) == 'table' then
        SetResourceKvp(KVP_SETTINGS, json.encode(data))
        applyAimSetting(data)
    end
    cb('ok')
end)

RegisterNUICallback('resetSettings', function(_, cb)
    DeleteResourceKvp(KVP_SETTINGS)
    applyAimSetting(nil)
    cb(Config.DefaultSettings)
end)

---------------------------------------------------------------------
-- NUI callbacks: admin panel (server re-checks permission every call)
---------------------------------------------------------------------
local function closeAdmin()
    adminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'ON_ADMIN_CLOSE' })
end

RegisterNetEvent('rsg-chat:client:openAdmin', function(tab)
    if adminOpen or chatInputActive then return end
    local channels = RSGCore.Functions.AwaitCallback('rsg-chat:server:adminGetChannels', CB_TIMEOUT)
    if type(channels) ~= 'table' then return notify('no_permission', 'error') end
    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'ON_ADMIN_OPEN',
        tab = tab == 'logs' and 'logs' or 'channels',
        channels = channels,
        permissions = Config.PermissionLevels,
        limits = { minDistance = Config.DistanceLimits.min, maxDistance = Config.DistanceLimits.max, maxLength = Config.HardMaxLength },
    })
end)

RegisterNUICallback('adminClose', function(_, cb) closeAdmin() cb('ok') end)

RegisterNUICallback('adminSave', function(data, cb)
    if type(data) ~= 'table' then return cb({ ok = false }) end
    cb(adminCall('adminSave', data.channel, data.originalId))
end)

RegisterNUICallback('adminDelete', function(data, cb)
    cb(adminCall('adminDelete', data and data.id))
end)

RegisterNUICallback('adminToggle', function(data, cb)
    cb(adminCall('adminToggle', data and data.id))
end)

RegisterNUICallback('adminSearchLogs', function(data, cb)
    cb(adminCall('adminSearchLogs', type(data) == 'table' and data or {}))
end)

RegisterNUICallback('adminMove', function(data, cb)
    cb(adminCall('adminMove', data and data.id, data and data.dir))
end)

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
RegisterCommand('chatsettings', function()
    if not chatLoaded or chatInputActive or adminOpen then return end
    chatInputActive = true
    SendNUIMessage({ type = 'ON_OPEN', settings = true })
    SetNuiFocus(true, true)
end, false)

RegisterCommand('clearchat', function()
    SendNUIMessage({ type = 'ON_CLEAR' })
end, false)

RegisterCommand('togglechat', function()
    SendNUIMessage({ type = 'ON_TOGGLE_CHAT' })
end, false)

RegisterNUICallback('chatToggled', function(data, cb)
    notify(data and data.off and 'chat_turned_off' or 'chat_turned_on')
    cb('ok')
end)

RegisterCommand('channel', function(_, args)
    local id = args[1] and args[1]:lower()
    for _, ch in ipairs(myChannels) do
        if ch.id == id then
            SendNUIMessage({ type = 'ON_SET_CHANNEL', id = id })
            notify('channel_switched', 'inform', ch.label)
            return
        end
    end
    notify('channel_unavailable', 'error')
end, false)

local function refreshCommands()
    if GetRegisteredCommands then
        local suggestions = {}
        for _, command in ipairs(GetRegisteredCommands()) do
            if IsAceAllowed(('command.%s'):format(command.name)) then
                suggestions[#suggestions + 1] = { name = '/' .. command.name, help = '' }
            end
        end
        TriggerEvent('chat:addSuggestions', suggestions)
    end

    local own = {
        { name = '/clearchat', help = locale('help_clearchat') },
        { name = '/chatsettings', help = locale('help_chatsettings') },
        { name = '/togglechat', help = locale('help_togglechat') },
        { name = '/channel', help = locale('help_channelcmd'), params = { { name = 'id', help = locale('param_channel_help') } } },
    }
    local messageParam = { name = locale('param_message'), help = locale('param_message_help') }
    if Config.PM.Enabled then
        own[#own + 1] = { name = '/' .. Config.PM.Command, help = locale('help_pm'), params = {
            { name = locale('param_target'), help = locale('param_target_help') }, messageParam } }
        own[#own + 1] = { name = '/' .. Config.PM.ReplyCommand, help = locale('help_reply'), params = { messageParam } }
    end
    if Config.Roleplay.Enabled then
        own[#own + 1] = { name = '/' .. Config.Roleplay.DoCommand, help = locale('help_do'), params = { messageParam } }
        own[#own + 1] = { name = '/' .. Config.Roleplay.RollCommand, help = locale('help_roll'), params = {
            { name = locale('param_sides'), help = locale('param_sides_help') } } }
    end
    TriggerEvent('chat:addSuggestions', own)
    refreshChannelSuggestions()
end

local function refreshThemes()
    local themes = {}
    for resIdx = 0, GetNumResources() - 1 do
        local resource = GetResourceByFindIndex(resIdx)
        if GetResourceState(resource) == 'started' and GetNumResourceMetadata(resource, 'chat_theme') > 0 then
            local themeName = GetResourceMetadata(resource, 'chat_theme')
            local themeData = json.decode(GetResourceMetadata(resource, 'chat_theme_extra') or 'null')
            if themeName and themeData then
                themeData.baseUrl = 'nui://' .. resource .. '/'
                themes[themeName] = themeData
            end
        end
    end
    SendNUIMessage({ type = 'ON_UPDATE_THEMES', themes = themes })
end

local refreshPending, themesDirty = false, false
local function queueRefresh(resource)
    if not chatLoaded then return end
    if type(resource) == 'string' and GetNumResourceMetadata(resource, 'chat_theme') > 0 then themesDirty = true end
    if refreshPending then return end
    refreshPending = true -- many resources start together: refresh once
    SetTimeout(500, function()
        refreshPending = false
        refreshCommands()
        if themesDirty then
            themesDirty = false
            refreshThemes()
        end
    end)
end
AddEventHandler('onClientResourceStart', queueRefresh)
AddEventHandler('onClientResourceStop', queueRefresh)

RegisterNUICallback('loaded', function(_, cb)
    local saved = loadSettings()
    applyAimSetting(saved)
    SendNUIMessage({
        type = 'ON_INIT',
        pmCommand = Config.PM.Enabled and Config.PM.Command or nil,
        settings = saved,
        defaults = Config.DefaultSettings,
        maxHistory = Config.MaxHistoryCap,
        ui = uiStrings(),
    })
    refreshCommands()
    refreshThemes()
    requestChannels()
    chatLoaded = true
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetTextChatEnabled(true)
end)

---------------------------------------------------------------------
-- Opening the chat
-- The text box takes NUI focus only after the key is released, so the key itself isn't typed into it.
---------------------------------------------------------------------
local function openChat()
    if chatInputActive or adminOpen then return end
    chatInputActive = true
    chatInputActivating = true
    SendNUIMessage({ type = 'ON_OPEN' })
end

local function focusChat()
    if not chatInputActivating then return end
    chatInputActivating = false
    if chatInputActive then SetNuiFocus(true, true) end
end

local function checkScreenState()
    if not chatLoaded then return end
    local shouldBeHidden = IsScreenFadedOut() or IsPauseMenuActive()
    if shouldBeHidden ~= chatHidden then
        chatHidden = shouldBeHidden
        SendNUIMessage({ type = 'ON_SCREEN_STATE_CHANGE', shouldHide = shouldBeHidden })
    end

    -- fade (not hide) while aiming or in a cinematic camera; never while the player is typing
    local faded = aimHideEnabled and not chatInputActive and not adminOpen
        and (IsPlayerFreeAiming(PlayerId()) or IsCinematicCamRendering()) or false
    if faded ~= aimFaded then
        aimFaded = faded
        SendNUIMessage({ type = 'ON_AIM_STATE', faded = faded })
    end
end

CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    -- Rebindable key (rsg-core RegisterKey): no per-frame work at all
    if Config.UseKeyMapping and RSGCore.Functions.RegisterKey
        and RSGCore.Functions.RegisterKey('rsgchat_open', locale('key_open_chat'), Config.OpenKey, openChat, focusChat, {
            requireLogin = false, -- chat also works on the character screen
            canTrigger = function() return not IsPauseMenuActive() end,
        }) then
        while true do
            Wait(250)
            checkScreenState()
        end
    end

    -- Fallback (Config.UseKeyMapping = false): read the control every frame
    local nextScreenCheck = 0
    while true do
        Wait(0)
        if IsControlPressed(0, `INPUT_MP_TEXT_CHAT_ALL`) then openChat() end
        if chatInputActivating and not IsControlPressed(0, `INPUT_MP_TEXT_CHAT_ALL`) then focusChat() end
        if GetGameTimer() >= nextScreenCheck then
            nextScreenCheck = GetGameTimer() + 250
            checkScreenState()
        end
    end
end)
