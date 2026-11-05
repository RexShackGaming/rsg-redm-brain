local resourceName = GetCurrentResourceName()
local state = { open=false, visible=true, uiReady=false, messages={}, seen={}, submission=0,
    channels={}, aliases={}, suggestions={} }
local RefreshDirectory

local function Ui(message) SendNUIMessage(message) end
local function Snapshot()
    return { open=state.open, visible=state.visible, uiReady=state.uiReady,
        messageCount=#state.messages }
end

local function ApplyFocus(open)
    state.open = open == true and state.visible == true
    SetNuiFocus(state.open, state.open)
    Ui({ type=state.open and 'chat:open' or 'chat:close' })
    return ChatResults.Ok(Snapshot())
end

local function OpenChat()
    if not state.visible then return ChatResults.Err('not_visible', ChatLocale.T('error_chat_is_currently_hidden')) end
    Ui({ type='chat:locale', locale=ChatLocale.Dictionary(),
        ignoreEnabled=Config.Moderation.playerControls.ignoreEnabled })
    if RefreshDirectory then RefreshDirectory() end
    return ApplyFocus(true)
end

AddEventHandler('feather-core:locale:changed', function()
    Ui({ type='chat:locale', locale=ChatLocale.Dictionary(),
        ignoreEnabled=Config.Moderation.playerControls.ignoreEnabled })
    if state.open and RefreshDirectory then CreateThread(RefreshDirectory) end
end)

local function CloseChat() return ApplyFocus(false) end

local function SetChatVisible(visible)
    if type(visible) ~= 'boolean' then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_chat_visibility_must_be_a_boolean'))
    end
    state.visible = visible
    if not visible then ApplyFocus(false) end
    Ui({ type='chat:visibility', visible=visible })
    return ChatResults.Ok(Snapshot())
end

exports('OpenChat', OpenChat)
exports('CloseChat', CloseChat)
exports('SetChatVisible', SetChatVisible)
exports('GetChatState', function() return ChatResults.Ok(Snapshot()) end)

RegisterNUICallback('chat:case', function(data, callback)
    if GetResourceState('feather-admin') ~= 'started' then return callback({ ok=false }) end
    if type(data) ~= 'table' or type(data.payload) ~= 'table'
        or (data.operation ~= 'list' and data.operation ~= 'history' and data.operation ~= 'reply') then
        return callback({ ok=false })
    end
    if type(data.requestId) ~= 'string' or #data.requestId ~= 36 then return callback({ ok=false }) end
    TriggerEvent('feather-admin:conversation:panel-request', data.operation, data.payload, data.requestId)
    callback({ ok=true })
end)

AddEventHandler('feather-chat:conversation:panel-result', function(operation, result, requestId)
    Ui({ type='chat:case:result', operation=operation, result=result, requestId=requestId })
end)
AddEventHandler('feather-chat:conversation:updated', function(hint)
    Ui({ type='chat:case:updated', hint=hint })
end)

AddEventHandler('feather-chat:conversation:reset', function()
    Ui({ type='chat:case:reset' })
    CloseChat()
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'feather-admin' or resource == 'feather-core' then
        Ui({ type='chat:case:reset' })
        CloseChat()
    end
end)

RegisterCommand(Config.Input.command, function()
    if state.open then CloseChat() else OpenChat() end
end, false)
RegisterKeyMapping(Config.Input.command, ChatLocale.T('ui_open_feather_chat'), 'keyboard', Config.Input.defaultKey)

RegisterNUICallback('chat:ready', function(_, callback)
    state.uiReady = true
    local presentation = ChatPresentation.GetState()
    Ui({
        type='chat:bootstrap',
        config={ layout=presentation.layout, theme=presentation.theme,
            themeDocument=presentation.themeDocument, themeRevision=presentation.themeRevision,
            locale=ChatLocale.Dictionary(), limits=Config.Limits, ignoreEnabled=Config.Moderation.playerControls.ignoreEnabled },
        messages=state.messages, channels=state.channels, suggestions=state.suggestions
    })
    callback({ ok=true })
end)

local function Submit(channelKey, text)
    state.submission = state.submission + 1
    local submissionId = ('%s:%s:%s'):format(GetPlayerServerId(PlayerId()),
        GetGameTimer(), state.submission)
    local result, transportError = exports['feather-core']:CallRPCAsync(
        'chat.message.submit.v1', {
            channelKey=channelKey, text=text, submissionId=submissionId
        }, nil, Config.Limits.callbackTimeoutMs)
    if type(result) ~= 'table' then
        return ChatResults.Err(transportError and transportError.code or 'transport_failed',
            ChatLocale.T('error_chat_submission_failed'))
    end
    return ChatLocale.LocalizeResult(result)
end

local inputAliases = {
    say='local.say', whisper='local.whisper', shout='local.shout',
    me='roleplay.me', ['do']='roleplay.do'
}

local function ResolveInput(channelKey, text)
    if type(text) ~= 'string' or text:sub(1, 1) ~= '/' then
        return ChatResults.Ok({ channelKey=channelKey, text=text })
    end
    local command, body = text:match('^/([^%s]+)%s*(.*)$')
    command = command and command:lower() or nil
    local resolved = command and (state.aliases['/' .. command] or inputAliases[command]) or nil
    if not resolved then
        local commandLine = text:sub(2):gsub('^%s+', ''):gsub('%s+$', '')
        if commandLine == '' then
            return ChatResults.Err('invalid_command', ChatLocale.T('error_enter_a_command_after_the_slash'))
        end
        return ChatResults.Ok({ command=commandLine })
    end
    if body == '' then
        return ChatResults.Err('invalid_message', ChatLocale.T('error_enter_a_message_after_the_chat_command'))
    end
    return ChatResults.Ok({ channelKey=resolved, text=body })
end

RefreshDirectory = function()
    local result = exports['feather-core']:CallRPCAsync(
        'chat.channel.list.v1', {}, nil, Config.Limits.callbackTimeoutMs)
    if type(result) ~= 'table' or not result.ok or type(result.value) ~= 'table'
        or type(result.value.channels) ~= 'table' then return result end
    state.channels, state.suggestions, state.aliases = result.value.channels,
        type(result.value.suggestions) == 'table' and result.value.suggestions or {}, {}
    for _, suggestion in ipairs(state.suggestions) do
        if type(suggestion.descriptionKey) == 'string' then
            local ok, text = pcall(Feather.Locale.translate, 0, suggestion.descriptionKey)
            if ok and type(text) == 'string' and text ~= ''
                and not text:match('^Translation %[') and not text:match('^Locale %[') then
                suggestion.description = text
            end
        end
    end
    for _, channel in ipairs(state.channels) do
        local input = type(channel) == 'table' and channel.input or nil
        for _, alias in ipairs(type(input) == 'table' and input.aliases or {}) do
            state.aliases[alias] = channel.channelKey
        end
    end
    Ui({ type='chat:directory', channels=state.channels,
        suggestions=state.suggestions, revision=result.value.revision })
    return result
end

RegisterNetEvent('feather-chat:directory:v1', function()
    if state.open then RefreshDirectory() end
end)

RegisterNUICallback('chat:submit', function(payload, callback)
    local function Reject(result)
        callback(ChatLocale.LocalizeResult(result))
        CloseChat()
        Ui({ type='chat:error', message=result.message or ChatLocale.T('error_message_was_not_accepted') })
    end
    if type(payload) ~= 'table' or type(payload.channelKey) ~= 'string'
        or type(payload.text) ~= 'string' then
        Reject(ChatResults.Err('invalid_input', ChatLocale.T('error_chat_submission_is_invalid')))
        return
    end
    local resolved = ResolveInput(payload.channelKey, payload.text)
    if not resolved.ok then
        Reject(resolved)
        return
    end
    if resolved.value.command then
        ExecuteCommand(resolved.value.command)
        callback(ChatResults.Ok({ executed=true }))
        CloseChat()
        return
    end
    local result = Submit(resolved.value.channelKey, resolved.value.text)
    if not result.ok then
        Reject(result)
        return
    end
    callback(ChatLocale.LocalizeResult(result))
    if Config.Input.closeOnSubmit then CloseChat() end
end)

RegisterNUICallback('chat:ignore-toggle', function(payload, callback)
    if type(payload) ~= 'table' or type(payload.messageId) ~= 'string' then
        callback(ChatResults.Err('invalid_input', ChatLocale.T('error_ignore_request_is_invalid')))
        return
    end
    local result, transportError = exports['feather-core']:CallRPCAsync(
        'chat.ignore.toggle.v1', { messageId=payload.messageId }, nil,
        Config.Limits.callbackTimeoutMs)
    if type(result) ~= 'table' then
        result = ChatResults.Err(transportError and transportError.code or 'transport_failed',
            ChatLocale.T('error_ignore_preference_could_not_be_saved'))
    end
    callback(ChatLocale.LocalizeResult(result))
end)

local function IgnoreRPC(route, payload, callback)
    local result, transportError = exports['feather-core']:CallRPCAsync(
        route, payload, nil, Config.Limits.callbackTimeoutMs)
    if type(result) ~= 'table' then
        result = ChatResults.Err(transportError and transportError.code or 'transport_failed',
            ChatLocale.T('error_ignore_preference_request_failed'))
    end
    callback(ChatLocale.LocalizeResult(result))
end

RegisterNUICallback('chat:ignore-list', function(_, callback)
    IgnoreRPC('chat.ignore.list.v1', {}, callback)
end)

RegisterNUICallback('chat:ignore-remove', function(payload, callback)
    if type(payload) ~= 'table' or type(payload.ignoreId) ~= 'string' then
        callback(ChatResults.Err('invalid_input', ChatLocale.T('error_ignore_removal_request_is_invalid')))
        return
    end
    IgnoreRPC('chat.ignore.remove.v1', { ignoreId=payload.ignoreId }, callback)
end)

RegisterNetEvent('feather-chat:message:v1', function(message)
    if type(message) ~= 'table' or type(message.messageId) ~= 'string'
        or state.seen[message.messageId] then return end
    state.seen[message.messageId] = true
    state.messages[#state.messages + 1] = message
    while #state.messages > Config.Limits.maxClientBuffer do
        local removed = table.remove(state.messages, 1)
        if removed and removed.messageId then state.seen[removed.messageId] = nil end
    end
    Ui({ type='chat:message', message=message })
end)

RegisterNetEvent('feather-chat:notice:v1', function(message)
    if type(message) == 'string' and message ~= '' then
        Ui({ type='chat:error', message=message })
    end
end)

for command, channelKey in pairs(inputAliases) do
    RegisterCommand(command, function(_, args)
        local text = table.concat(args or {}, ' ')
        if text == '' then return OpenChat() end
        local result = Submit(channelKey, text)
        if not result.ok then
            Ui({ type='chat:error', message=result.message or ChatLocale.T('error_message_was_not_accepted') })
        end
    end, false)
end

RegisterNUICallback('chat:close', function(_, callback)
    CloseChat()
    callback({ ok=true })
end)

CreateThread(function()
    while true do
        Wait(250)
        if state.open and (IsPauseMenuActive() or IsScreenFadedOut()) then CloseChat() end
    end
end)

RegisterCommand('ChatClientFoundationSmokeTest', function()
    local before = Snapshot()
    local hidden = SetChatVisible(false)
    local refused = OpenChat()
    local restored = SetChatVisible(true)
    local opened = OpenChat()
    local closed = CloseChat()
    print(('[ChatClientFoundationSmokeTest] initial=%s hidden=%s refused=%s restored=%s opened=%s closed=%s uiReady=%s'):format(
        tostring(before.open == false), tostring(hidden.ok),
        tostring(refused.ok == false and refused.code == 'not_visible'),
        tostring(restored.ok), tostring(opened.ok), tostring(closed.ok), tostring(state.uiReady)))
end, false)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource ~= resourceName then return end
    state.open = false
    SetNuiFocus(false, false)
end)
