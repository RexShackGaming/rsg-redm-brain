ChatThemes = {}

local themes, revision = {}, 0
local resourceName = GetCurrentResourceName()

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

local function Public(theme, documentOnly)
    local result = Copy(theme)
    result.ownerResource = nil
    if documentOnly then result.revision = nil end
    return result
end

local function Publish()
    revision = revision + 1
    TriggerClientEvent('feather-chat:themes:v1', -1, revision)
end

local function Register(definition, forcedOwner)
    local valid, reason = ChatContract.ValidateTheme(definition)
    if not valid then return reason end
    if themes[definition.themeKey] then
        return ChatResults.Err('conflict', ChatLocale.T('error_that_theme_key_is_already_registered'))
    end
    local stored = Copy(definition)
    stored.ownerResource, stored.revision = forcedOwner or Owner(), 1
    themes[stored.themeKey] = stored
    Publish()
    return ChatResults.Ok(Public(stored), { themeRevision=revision })
end

local function Update(themeKey, definition, expectedRevision)
    local current = themes[themeKey]
    if not current then return ChatResults.Err('not_found', ChatLocale.T('error_theme_is_not_registered')) end
    if current.ownerResource ~= Owner() then
        return ChatResults.Err('forbidden', ChatLocale.T('error_only_the_theme_owner_may_update_it'))
    end
    if tonumber(expectedRevision) ~= current.revision or type(definition) ~= 'table'
        or definition.themeKey ~= themeKey then
        return ChatResults.Err('conflict', ChatLocale.T('error_theme_revision_changed'))
    end
    local candidate = Copy(definition)
    candidate.revision = nil
    local valid, reason = ChatContract.ValidateTheme(candidate)
    if not valid then return reason end
    local stored = candidate
    stored.ownerResource, stored.revision = current.ownerResource, current.revision + 1
    themes[themeKey] = stored
    Publish()
    return ChatResults.Ok(Public(stored), { themeRevision=revision })
end

local function Remove(themeKey, forcedOwner)
    local current = themes[themeKey]
    if not current then return ChatResults.Err('not_found', ChatLocale.T('error_theme_is_not_registered')) end
    if themeKey == 'feather.default' or themeKey == 'feather.high_contrast' then
        return ChatResults.Err('forbidden', ChatLocale.T('error_built_in_themes_cannot_be_removed'))
    end
    if current.ownerResource ~= (forcedOwner or Owner()) then
        return ChatResults.Err('forbidden', ChatLocale.T('error_only_the_theme_owner_may_remove_it'))
    end
    themes[themeKey] = nil
    Publish()
    return ChatResults.Ok({ themeKey=themeKey }, { themeRevision=revision })
end

local function ApprovedThemes()
    local approved = {}
    for _, themeKey in ipairs(Config.Theme.approved) do
        if themes[themeKey] then approved[#approved + 1] = Public(themes[themeKey], true) end
    end
    return approved
end

function ChatThemes.Start()
    local builtins = {
        {
            themeKey='feather.default', schemaVersion=1,
            typography={ family='default', lineHeight=1.35 },
            surface={ background='#16120FEB', panel='#211A16F5', border='#6E543A' },
            text={ primary='#F4EBDD', muted='#B7AA97', danger='#FFB1A8' },
            channelTokens={ speech='#D9B46F', whisper='#B7AA97', shout='#F0C879',
                action='#D7C2EB', scene='#C9D9B5', organization='#E7C66B',
                job='#9CC7FF', ooc='#9CC7FF', staff='#EF8C8C', system='#B7AA97' },
            shape={ radius=6, borderWidth=1 }, motion={ enabled=true, durationMs=140 }
        },
        {
            themeKey='feather.high_contrast', schemaVersion=1,
            typography={ family='default', lineHeight=1.4 },
            surface={ background='#000000FF', panel='#080808FF', border='#FFFFFF' },
            text={ primary='#FFFFFF', muted='#E8E8E8', danger='#FFB4AB' },
            channelTokens={ speech='#FFE866', whisper='#FFFFFF', shout='#FFE866',
                action='#E8CCFF', scene='#D8FFC7', organization='#FFE866',
                job='#B9DCFF', ooc='#B9DCFF', staff='#FFB4AB', system='#FFFFFF' },
            shape={ radius=6, borderWidth=2 }, motion={ enabled=false, durationMs=0 }
        }
    }
    for _, definition in ipairs(builtins) do
        if not themes[definition.themeKey] then
            local result = Register(definition, resourceName)
            if not result.ok then return result end
        end
    end
    if not themes[Config.Theme.default] then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_the_configured_default_theme_is_unavailable'))
    end
    return ChatResults.Ok(true)
end

function ChatThemes.RegisterRoutes()
    return exports['feather-core']:RegisterContractRPC('chat.theme.list.v1', function()
        return ChatResults.Ok({
            defaultTheme=Config.Theme.default,
            themes=ApprovedThemes(),
            revision=revision
        })
    end, {
        contract=1, direction='client_to_server', requireCharacter=true,
        windowMs=2000, maxCalls=4, maxPayloadBytes=64, maxDepth=2, maxNodes=4,
        validatePayload=function(payload)
            return type(payload) == 'table' and next(payload) == nil,
                ChatResults.Err('invalid_input', ChatLocale.T('error_no_theme_list_fields_are_accepted'))
        end
    })
end

function ChatThemes.Smoke()
    local valid = ChatContract.ValidateTheme({
        themeKey='test.valid', schemaVersion=1,
        typography={ family='default', lineHeight=1.4 },
        surface={ background='#000000CC', panel='#111111FF', border='#FFFFFF' },
        text={ primary='#FFFFFF', muted='#CCCCCC', danger='#FF0000' },
        channelTokens={ speech='#FFFFFF', whisper='#FFFFFF', shout='#FFFFFF',
            action='#FFFFFF', scene='#FFFFFF', organization='#FFFFFF', job='#FFFFFF',
            ooc='#FFFFFF', staff='#FFFFFF', system='#FFFFFF' },
        shape={ radius=4, borderWidth=1 }, motion={ enabled=true, durationMs=100 }
    })
    local invalid = ChatContract.ValidateTheme({ themeKey='test.invalid', schemaVersion=1 })
    return {
        { 'valid theme accepted', valid == true },
        { 'incomplete theme rejected', invalid == false },
        { 'built-in default available', themes['feather.default'] ~= nil },
        { 'built-in high contrast available', themes['feather.high_contrast'] ~= nil }
    }
end

exports('RegisterTheme', function(definition) return Register(definition) end)
exports('UpdateTheme', Update)
exports('UnregisterTheme', function(themeKey) return Remove(themeKey) end)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource == resourceName then return end
    local owned = {}
    for themeKey, theme in pairs(themes) do
        if theme.ownerResource == stoppedResource then owned[#owned + 1] = themeKey end
    end
    for _, themeKey in ipairs(owned) do Remove(themeKey, stoppedResource) end
end)
