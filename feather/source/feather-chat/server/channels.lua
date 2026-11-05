ChatChannels = {}

local channels, aliases, suggestions, accessProviders, revision = {}, {}, {}, {}, 0
local resourceName = GetCurrentResourceName()
local visibility = { public=true, eligible=true, discoverable=true, hidden=true, system=true }
local variants = { speech=true, whisper=true, shout=true, action=true, scene=true,
    organization=true, job=true, ooc=true, system=true }
local routing = { proximity=true, provider=true }

local function Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do result[Copy(key, seen)] = Copy(child, seen) end
    seen[value] = nil
    return result
end

local function Owner()
    return GetInvokingResource() or resourceName
end

local function ValidDefinition(definition)
    if type(definition) ~= 'table' or type(definition.channelKey) ~= 'string'
        or #definition.channelKey < 3 or #definition.channelKey > 96
        or not definition.channelKey:match('^[a-z][a-z0-9_.%-]+$')
        or not definition.channelKey:find('.', 1, true)
        or type(definition.label) ~= 'string' or #definition.label < 1 or #definition.label > 64
        or not visibility[definition.visibility] or type(definition.presentation) ~= 'table'
        or not variants[definition.presentation.variant] or not routing[definition.routing] then
        return false
    end
    if definition.routing == 'proximity' and (type(definition.radius) ~= 'string'
        or type(Config.Channels.proximity[definition.radius]) ~= 'number') then return false end
    if definition.routing == 'provider' and type(definition.accessProvider) ~= 'string' then return false end
    local input = definition.input
    if type(input) ~= 'table' or type(input.aliases) ~= 'table' or #input.aliases > 8
        or type(input.maximumLength) ~= 'number' or input.maximumLength < 1
        or input.maximumLength > Config.Limits.maxMessageBytes then return false end
    for _, alias in ipairs(input.aliases) do
        if type(alias) ~= 'string' or not alias:match('^/[a-z][a-z0-9_%-]*$') or #alias > 32 then
            return false
        end
    end
    if definition.accessProvider ~= nil and (type(definition.accessProvider) ~= 'string'
        or #definition.accessProvider < 1 or #definition.accessProvider > 96) then return false end
    return true
end

local function Public(channel)
    return {
        channelKey=channel.channelKey, label=channel.label, shortLabel=channel.shortLabel,
        description=channel.description, visibility=channel.visibility,
        presentation=Copy(channel.presentation), input=Copy(channel.input), revision=channel.revision
    }
end

local function RegisterSuggestion(definition, forcedOwner)
    if type(definition) ~= 'table' or type(definition.key) ~= 'string'
        or not definition.key:match('^[a-z][a-z0-9_.%-]+$') or #definition.key > 96
        or type(definition.trigger) ~= 'string'
        or not definition.trigger:match('^/[a-zA-Z][a-zA-Z0-9_%-]*$') or #definition.trigger > 32
        or type(definition.description) ~= 'string' or #definition.description < 1
        or #definition.description > 160 or (definition.channelKey ~= nil
        and type(definition.channelKey) ~= 'string')
        or (definition.descriptionKey ~= nil and (type(definition.descriptionKey) ~= 'string'
            or #definition.descriptionKey < 1 or #definition.descriptionKey > 96))
        or (definition.accessProvider ~= nil and (type(definition.accessProvider) ~= 'string'
            or #definition.accessProvider < 1 or #definition.accessProvider > 96)) then
        return ChatResults.Err('invalid_suggestion', ChatLocale.T('error_suggestion_definition_is_invalid'))
    end
    if definition.accessProvider then
        local provider = accessProviders[definition.accessProvider]
        if not provider or provider.ownerResource ~= (forcedOwner or Owner()) then
            return ChatResults.Err('forbidden', ChatLocale.T('error_suggestion_access_provider_must_belong_to_its_owner'))
        end
    end
    if suggestions[definition.key] then
        return ChatResults.Err('conflict', ChatLocale.T('error_that_suggestion_key_is_already_registered'))
    end
    local stored = Copy(definition)
    stored.ownerResource = forcedOwner or Owner()
    suggestions[stored.key] = stored
    revision = revision + 1
    TriggerClientEvent('feather-chat:directory:v1', -1, revision)
    return ChatResults.Ok(Copy(stored), { directoryRevision=revision })
end

local function RemoveSuggestion(key, forcedOwner)
    local suggestion = suggestions[key]
    if not suggestion then return ChatResults.Err('not_found', ChatLocale.T('error_suggestion_is_not_registered')) end
    if suggestion.ownerResource ~= (forcedOwner or Owner()) then
        return ChatResults.Err('forbidden', ChatLocale.T('error_only_the_suggestion_owner_may_remove_it'))
    end
    suggestions[key], revision = nil, revision + 1
    TriggerClientEvent('feather-chat:directory:v1', -1, revision)
    return ChatResults.Ok({ key=key }, { directoryRevision=revision })
end

local function Register(definition, forcedOwner)
    if not ValidDefinition(definition) then
        return ChatResults.Err('invalid_channel', ChatLocale.T('error_channel_definition_is_invalid'))
    end
    local owner = forcedOwner or Owner()
    if channels[definition.channelKey] then
        return ChatResults.Err('conflict', ChatLocale.T('error_that_channel_key_is_already_registered'))
    end
    for _, alias in ipairs(definition.input.aliases) do
        if aliases[alias] then return ChatResults.Err('conflict', ChatLocale.T('error_that_channel_alias_is_already_registered')) end
    end
    local stored = Copy(definition)
    stored.ownerResource, stored.revision = owner, 1
    channels[stored.channelKey] = stored
    for _, alias in ipairs(stored.input.aliases) do aliases[alias] = stored.channelKey end
    revision = revision + 1
    TriggerEvent('chat.channel.registered.v1', Public(stored))
    TriggerClientEvent('feather-chat:directory:v1', -1, revision)
    return ChatResults.Ok(Public(stored), { directoryRevision=revision })
end

local function Remove(channelKey, forcedOwner)
    local channel = channels[channelKey]
    if not channel then return ChatResults.Err('not_found', ChatLocale.T('error_channel_is_not_registered')) end
    if channel.ownerResource ~= (forcedOwner or Owner()) then
        return ChatResults.Err('forbidden', ChatLocale.T('error_only_the_channel_owner_may_remove_it'))
    end
    for _, alias in ipairs(channel.input.aliases) do aliases[alias] = nil end
    channels[channelKey], revision = nil, revision + 1
    TriggerEvent('chat.channel.unregistered.v1', { channelKey=channelKey, revision=channel.revision })
    TriggerClientEvent('feather-chat:directory:v1', -1, revision)
    return ChatResults.Ok({ channelKey=channelKey }, { directoryRevision=revision })
end

local function Update(channelKey, patch, expectedRevision)
    local channel = channels[channelKey]
    if not channel then return ChatResults.Err('not_found', ChatLocale.T('error_channel_is_not_registered')) end
    if channel.ownerResource ~= Owner() then
        return ChatResults.Err('forbidden', ChatLocale.T('error_only_the_channel_owner_may_update_it'))
    end
    if tonumber(expectedRevision) ~= channel.revision or type(patch) ~= 'table' then
        return ChatResults.Err('conflict', ChatLocale.T('error_channel_revision_changed'))
    end
    local allowed = { label=true, shortLabel=true, description=true, visibility=true,
        presentation=true, input=true, accessProvider=true, routing=true, radius=true }
    local candidate = Copy(channel)
    for key, value in pairs(patch) do
        if not allowed[key] then return ChatResults.Err('invalid_input', ChatLocale.T('error_channel_patch_contains_an_unknown_field')) end
        candidate[key] = Copy(value)
    end
    candidate.ownerResource, candidate.revision = nil, nil
    if not ValidDefinition(candidate) then return ChatResults.Err('invalid_channel', ChatLocale.T('error_channel_patch_is_invalid')) end
    for _, alias in ipairs(channel.input.aliases) do aliases[alias] = nil end
    for _, alias in ipairs(candidate.input.aliases) do
        if aliases[alias] and aliases[alias] ~= channelKey then
            for _, original in ipairs(channel.input.aliases) do aliases[original] = channelKey end
            return ChatResults.Err('conflict', ChatLocale.T('error_that_channel_alias_is_already_registered'))
        end
    end
    candidate.ownerResource, candidate.revision = channel.ownerResource, channel.revision + 1
    channels[channelKey] = candidate
    for _, alias in ipairs(candidate.input.aliases) do aliases[alias] = channelKey end
    revision = revision + 1
    TriggerEvent('chat.channel.updated.v1', Public(candidate))
    TriggerClientEvent('feather-chat:directory:v1', -1, revision)
    return ChatResults.Ok(Public(candidate), { directoryRevision=revision })
end

local function Provider(name)
    local result = exports['feather-core']:GetProvider('chat-channel-access', name, 1)
    return type(result) == 'table' and result.ok and result.value.implementation or nil
end

local function CallProvider(channel, method, request)
    if not channel.accessProvider then return ChatResults.Ok({ allowed=true }) end
    local implementation = Provider(channel.accessProvider)
    local callback = type(implementation) == 'table' and implementation[method] or nil
    if callback == nil then return ChatResults.Err('provider_unavailable', ChatLocale.T('error_channel_access_is_unavailable')) end
    local called, result = pcall(callback, request)
    if not called or type(result) ~= 'table' or type(result.ok) ~= 'boolean' then
        return ChatResults.Err('provider_unavailable', ChatLocale.T('error_channel_access_is_unavailable'))
    end
    return result
end

local function RegisterAccessProvider(name, implementation)
    if type(name) ~= 'string' or #name < 1 or #name > 96 or type(implementation) ~= 'table' then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_access_provider_registration_is_invalid'))
    end
    if accessProviders[name] then
        return ChatResults.Err('conflict', ChatLocale.T('error_that_access_provider_is_already_registered'))
    end

    local owner = Owner()
    local function Forward(method, request)
        local registered = accessProviders[name]
        local callback = registered and registered.implementation[method] or nil
        if callback == nil then
            return ChatResults.Err('provider_unavailable', ChatLocale.T('error_channel_access_is_unavailable'))
        end
        local called, result = pcall(callback, request)
        if not called or type(result) ~= 'table' or type(result.ok) ~= 'boolean' then
            return ChatResults.Err('provider_unavailable', ChatLocale.T('error_channel_access_is_unavailable'))
        end
        return result
    end

    accessProviders[name] = { ownerResource=owner, implementation=implementation }
    local result = exports['feather-core']:RegisterProvider('chat-channel-access', name, {
        CanView=function(request) return Forward('CanView', request) end,
        CanSend=function(request) return Forward('CanSend', request) end,
        ResolveAudience=function(request) return Forward('ResolveAudience', request) end
    }, { contract=1, capabilities={ channelAccess=1 }, default=false })
    if type(result) ~= 'table' or result.ok ~= true then accessProviders[name] = nil end
    return result
end

local function RemoveAccessProvider(name, forcedOwner)
    local registered = accessProviders[name]
    if not registered then return ChatResults.Err('not_found', ChatLocale.T('error_access_provider_is_not_registered')) end
    if registered.ownerResource ~= (forcedOwner or Owner()) then
        return ChatResults.Err('forbidden', ChatLocale.T('error_only_the_access_provider_owner_may_remove_it'))
    end
    local result = exports['feather-core']:UnregisterProvider('chat-channel-access', name)
    if type(result) == 'table' and result.ok == true then accessProviders[name] = nil end
    return result
end

function ChatChannels.Start()
    local builtins = {
        { channelKey='local.say', label=ChatLocale.T('ui_say'), visibility='public', routing='proximity', radius='say',
            presentation={variant='speech',accentToken='channel.speech'}, input={aliases={'/say'},maximumLength=Config.Limits.maxMessageBytes} },
        { channelKey='local.whisper', label=ChatLocale.T('ui_whisper'), visibility='public', routing='proximity', radius='whisper',
            presentation={variant='whisper',accentToken='channel.whisper'}, input={aliases={'/whisper'},maximumLength=Config.Limits.maxMessageBytes} },
        { channelKey='local.shout', label=ChatLocale.T('ui_shout'), visibility='public', routing='proximity', radius='shout',
            presentation={variant='shout',accentToken='channel.shout'}, input={aliases={'/shout'},maximumLength=Config.Limits.maxMessageBytes} },
        { channelKey='roleplay.me', label='/me', visibility='public', routing='proximity', radius='roleplay', kind='action',
            presentation={variant='action',accentToken='channel.action'}, input={aliases={'/me'},maximumLength=Config.Limits.maxMessageBytes} },
        { channelKey='roleplay.do', label='/do', visibility='public', routing='proximity', radius='roleplay', kind='scene',
            presentation={variant='scene',accentToken='channel.scene'}, input={aliases={'/do'},maximumLength=Config.Limits.maxMessageBytes} }
    }
    for _, definition in ipairs(builtins) do
        local result = Register(definition, resourceName)
        if not result.ok then return result end
        local suggestion = RegisterSuggestion({
            key='builtin.' .. definition.channelKey, trigger=definition.input.aliases[1],
            description=ChatLocale.T('ui_send_to_channel'):gsub('{channel}', function() return definition.label end), channelKey=definition.channelKey
        }, resourceName)
        if not suggestion.ok then return suggestion end
    end
    return ChatResults.Ok(true)
end

function ChatChannels.RegisterRoutes()
    return exports['feather-core']:RegisterContractRPC('chat.channel.list.v1', function(_, _, context)
        return ChatChannels.List({ source=context.source, accountId=context.accountId,
            characterId=context.characterId, sessionId=context.sessionId })
    end, {
        contract=1, direction='client_to_server', requireCharacter=true,
        windowMs=2000, maxCalls=4, maxPayloadBytes=64, maxDepth=2, maxNodes=4,
        validatePayload=function(payload)
            return type(payload) == 'table' and next(payload) == nil,
                ChatResults.Err('invalid_input', ChatLocale.T('error_no_channel_list_fields_are_accepted'))
        end
    })
end

function ChatChannels.Get(key) return channels[key] and Copy(channels[key]) or nil end
function ChatChannels.ResolveAlias(alias) return aliases[alias] end
function ChatChannels.CanSend(channel, actor)
    return CallProvider(channel, 'CanSend', { channelKey=channel.channelKey, actor=actor })
end
function ChatChannels.ResolveAudience(channel, sender, connected)
    return CallProvider(channel, 'ResolveAudience', {
        channelKey=channel.channelKey, sender=sender, connectedSessions=connected
    })
end
function ChatChannels.List(actor)
    local list, visible = {}, {}
    for _, channel in pairs(channels) do
        local include = channel.visibility == 'public' or channel.visibility == 'discoverable'
        if channel.visibility == 'eligible' then
            local access = CallProvider(channel, 'CanView', { channelKey=channel.channelKey, actor=actor })
            include = access.ok and access.value and access.value.allowed == true
        end
        if include and channel.visibility ~= 'system' then
            list[#list + 1], visible[channel.channelKey] = Public(channel), true
        end
    end
    table.sort(list, function(a, b) return a.channelKey < b.channelKey end)
    local suggestionList = {}
    for _, suggestion in pairs(suggestions) do
        local include = suggestion.channelKey == nil or visible[suggestion.channelKey]
        if include and suggestion.accessProvider then
            local access = CallProvider(suggestion, 'CanView', { actor=actor, suggestionKey=suggestion.key })
            include = access.ok and access.value and access.value.allowed == true
        end
        if include then
            suggestionList[#suggestionList + 1] = {
                key=suggestion.key, trigger=suggestion.trigger,
                description=suggestion.description, descriptionKey=suggestion.descriptionKey, channelKey=suggestion.channelKey
            }
        end
    end
    table.sort(suggestionList, function(a, b) return a.trigger < b.trigger end)
    return ChatResults.Ok({ channels=list, suggestions=suggestionList, revision=revision })
end

exports('RegisterChannel', function(definition) return Register(definition) end)
exports('UpdateChannel', Update)
exports('UnregisterChannel', function(channelKey) return Remove(channelKey) end)
exports('RegisterChannelAccessProvider', RegisterAccessProvider)
exports('UnregisterChannelAccessProvider', function(name) return RemoveAccessProvider(name) end)
exports('RegisterSuggestion', function(definition) return RegisterSuggestion(definition) end)

function ChatChannels.SuggestionSmoke()
    local definition = { key='chat.suggestion.smoke', trigger='/SuggestionSmoke', description='Temporary suggestion smoke' }
    local registered = RegisterSuggestion(definition, 'chat-suggestion-smoke')
    local tests = {
        { 'mixed-case command accepted', registered.ok },
        { 'duplicate key rejected', not RegisterSuggestion(definition, 'chat-suggestion-smoke').ok },
        { 'foreign owner removal denied', not RemoveSuggestion(definition.key, 'another-owner').ok },
        { 'missing access provider denied', not RegisterSuggestion({ key='chat.suggestion.protected-smoke',
            trigger='/protected_smoke', description='Protected fixture', accessProvider='missing.smoke' }, 'chat-suggestion-smoke').ok }
    }
    tests[#tests + 1] = { 'owner cleanup succeeds', RemoveSuggestion(definition.key, 'chat-suggestion-smoke').ok }
    tests[#tests + 1] = { 'registration recovers after cleanup', RegisterSuggestion(definition, 'chat-suggestion-smoke').ok }
    RemoveSuggestion(definition.key, 'chat-suggestion-smoke')
    return tests
end
exports('RemoveSuggestion', function(key) return RemoveSuggestion(key) end)

function ChatChannels.Smoke()
    local definition = { channelKey='test.registry', label='Registry Test', visibility='public',
        routing='proximity', radius='say', presentation={variant='speech'},
        input={aliases={'/registrytest'},maximumLength=64} }
    local registered = Register(definition, 'chat-smoke-owner')
    local duplicate = Register(definition, 'other-owner')
    local removedWrong = Remove(definition.channelKey, 'other-owner')
    local removed = Remove(definition.channelKey, 'chat-smoke-owner')
    return {
        { 'owner registration', registered.ok == true },
        { 'duplicate rejected', duplicate.ok == false and duplicate.code == 'conflict' },
        { 'foreign remove rejected', removedWrong.ok == false and removedWrong.code == 'forbidden' },
        { 'owner cleanup', removed.ok == true and channels[definition.channelKey] == nil },
        { 'alias cleanup', aliases['/registrytest'] == nil }
    }
end

AddEventHandler('onResourceStop', function(stopped)
    if stopped == resourceName then return end
    local owned = {}
    for key, channel in pairs(channels) do
        if channel.ownerResource == stopped then owned[#owned + 1] = key end
    end
    for _, key in ipairs(owned) do Remove(key, stopped) end
    local ownedSuggestions = {}
    for key, suggestion in pairs(suggestions) do
        if suggestion.ownerResource == stopped then ownedSuggestions[#ownedSuggestions + 1] = key end
    end
    for _, key in ipairs(ownedSuggestions) do RemoveSuggestion(key, stopped) end
    local ownedProviders = {}
    for name, provider in pairs(accessProviders) do
        if provider.ownerResource == stopped then ownedProviders[#ownedProviders + 1] = name end
    end
    for _, name in ipairs(ownedProviders) do RemoveAccessProvider(name, stopped) end
end)
