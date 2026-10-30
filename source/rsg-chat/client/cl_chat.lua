lib.locale()

local chatInputActive = false
local chatInputActivating = false
local chatHidden = true
local chatLoaded = false
local adminOpen = false
local myChannels = {}
local channelSuggestions = {}

local KVP_SETTINGS = 'rsgchat_settings'

-- Locale keys the NUI needs (sent once on load)
local UI_KEYS = {
    'ui_settings', 'ui_layout', 'ui_font_size', 'ui_opacity', 'ui_timestamps', 'ui_history',
    'ui_autohide', 'ui_hide_delay', 'ui_fade', 'ui_hide', 'ui_never', 'ui_reset_layout',
    'ui_close', 'ui_on', 'ui_off', 'ui_seconds', 'ui_messages', 'ui_drag_hint', 'ui_tab_hint',
    'ui_admin_title', 'ui_admin_sub', 'ui_new_channel', 'ui_channel_id', 'ui_label', 'ui_command',
    'ui_prefix', 'ui_show_prefix', 'ui_color', 'ui_range', 'ui_distance', 'ui_jobs', 'ui_gangs',
    'ui_require_duty', 'ui_permission', 'ui_everyone', 'ui_max_length', 'ui_enabled', 'ui_save',
    'ui_delete', 'ui_cancel', 'ui_confirm_delete', 'ui_saved', 'ui_deleted', 'ui_error',
    'ui_range_global', 'ui_range_local', 'ui_range_regional', 'ui_range_group',
    'ui_list_hint', 'ui_chat_enabled', 'ui_chat_off_hint', 'ui_select_channel', 'ui_disabled', 'ui_preview', 'ui_success', 'ui_info',
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
    for _, suggestion in ipairs(suggestions) do
        SendNUIMessage({ type = 'ON_SUGGESTION_ADD', suggestion = suggestion })
    end
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
    for _, ch in ipairs(myChannels) do
        if ch.command and ch.command ~= '' then
            local name = '/' .. ch.command
            channelSuggestions[#channelSuggestions + 1] = name
            SendNUIMessage({ type = 'ON_SUGGESTION_ADD', suggestion = {
                name = name, help = locale('help_channel', ch.label), params = param,
            } })
        end
    end
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
    end
    cb('ok')
end)

RegisterNUICallback('resetSettings', function(_, cb)
    DeleteResourceKvp(KVP_SETTINGS)
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

RegisterNetEvent('rsg-chat:client:openAdmin', function()
    if adminOpen or chatInputActive then return end
    local channels = lib.callback.await('rsg-chat:server:adminGetChannels', false)
    if not channels then
        lib.notify({ title = locale('chat_title'), description = locale('no_permission'), type = 'error' })
        return
    end
    adminOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'ON_ADMIN_OPEN',
        channels = channels,
        permissions = Config.PermissionLevels,
        limits = { minDistance = Config.DistanceLimits.min, maxDistance = Config.DistanceLimits.max, maxLength = Config.HardMaxLength },
    })
end)

RegisterNUICallback('adminClose', function(_, cb) closeAdmin() cb('ok') end)

RegisterNUICallback('adminSave', function(data, cb)
    if type(data) ~= 'table' then return cb({ ok = false }) end
    cb(lib.callback.await('rsg-chat:server:adminSave', false, data.channel, data.originalId) or { ok = false })
end)

RegisterNUICallback('adminDelete', function(data, cb)
    cb(lib.callback.await('rsg-chat:server:adminDelete', false, data and data.id) or { ok = false })
end)

RegisterNUICallback('adminToggle', function(data, cb)
    cb(lib.callback.await('rsg-chat:server:adminToggle', false, data and data.id) or { ok = false })
end)

RegisterNUICallback('adminMove', function(data, cb)
    cb(lib.callback.await('rsg-chat:server:adminMove', false, data and data.id, data and data.dir) or { ok = false })
end)

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
RegisterCommand('chatsettings', function()
    if chatInputActive or adminOpen then return end
    chatInputActive = true
    SendNUIMessage({ type = 'ON_OPEN', settings = true })
    SetNuiFocus(true, true)
end, false)

RegisterCommand('togglechat', function()
    SendNUIMessage({ type = 'ON_TOGGLE_CHAT' })
end, false)

RegisterNUICallback('chatToggled', function(data, cb)
    lib.notify({ title = locale('chat_title'), description = locale(data and data.off and 'chat_turned_off' or 'chat_turned_on'), type = 'inform' })
    cb('ok')
end)

RegisterCommand('channel', function(_, args)
    local id = args[1] and args[1]:lower()
    for _, ch in ipairs(myChannels) do
        if ch.id == id then
            SendNUIMessage({ type = 'ON_SET_CHANNEL', id = id })
            lib.notify({ title = locale('chat_title'), description = locale('channel_switched', ch.label), type = 'inform' })
            return
        end
    end
    lib.notify({ title = locale('chat_title'), description = locale('channel_unavailable'), type = 'error' })
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

    TriggerEvent('chat:addSuggestions', {
        { name = '/clearchat', help = locale('help_clearchat') },
        { name = '/chatsettings', help = locale('help_chatsettings') },
        { name = '/togglechat', help = locale('help_togglechat') },
        { name = '/channel', help = locale('help_channelcmd'), params = { { name = 'id', help = locale('param_channel_help') } } },
    })
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

AddEventHandler('onClientResourceStart', function()
    Wait(500)
    refreshCommands()
    refreshThemes()
end)

AddEventHandler('onClientResourceStop', function()
    Wait(500)
    refreshCommands()
    refreshThemes()
end)

RegisterNUICallback('loaded', function(_, cb)
    SendNUIMessage({
        type = 'ON_INIT',
        settings = loadSettings(),
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
end)

---------------------------------------------------------------------
-- Input loop (reads controls, so Wait(0) is required)
---------------------------------------------------------------------
CreateThread(function()
    SetTextChatEnabled(false)
    SetNuiFocus(false, false)

    while true do
        Wait(0)

        if not chatInputActive and not adminOpen then
            if IsControlPressed(0, `INPUT_MP_TEXT_CHAT_ALL`) then
                chatInputActive = true
                chatInputActivating = true
                SendNUIMessage({ type = 'ON_OPEN' })
            end
        end

        if chatInputActivating and not IsControlPressed(0, `INPUT_MP_TEXT_CHAT_ALL`) then
            SetNuiFocus(true, true)
            chatInputActivating = false
        end

        if chatLoaded then
            local shouldBeHidden = IsScreenFadedOut() or IsPauseMenuActive()
            if shouldBeHidden ~= chatHidden then
                chatHidden = shouldBeHidden
                SendNUIMessage({ type = 'ON_SCREEN_STATE_CHANGE', shouldHide = shouldBeHidden })
            end
        end
    end
end)
