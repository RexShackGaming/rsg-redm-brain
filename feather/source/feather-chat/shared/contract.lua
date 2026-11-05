ChatContract = {
    Name = 'feather.chat',
    Version = 1,
    Anchors = { ['top-left']=true, ['top-right']=true, ['bottom-left']=true, ['bottom-right']=true },
    Densities = { compact=true, comfortable=true },
    Themes = { ['feather.default']=true, ['feather.high_contrast']=true },
    ThemeFamilies = { default=true, system=true },
    ThemeTokenKeys = { 'speech', 'whisper', 'shout', 'action', 'scene',
        'organization', 'job', 'ooc', 'staff', 'system' },
    Channels = {
        ['local.say'] = { kind='player', radius='say', variant='speech' },
        ['local.whisper'] = { kind='player', radius='whisper', variant='whisper' },
        ['local.shout'] = { kind='player', radius='shout', variant='shout' },
        ['roleplay.me'] = { kind='action', radius='roleplay', variant='action' },
        ['roleplay.do'] = { kind='scene', radius='roleplay', variant='scene' }
    }
}

local function NumberInRange(value, minimum, maximum)
    return type(value) == 'number' and value >= minimum and value <= maximum
end

local function PositiveInteger(value, maximum)
    return type(value) == 'number' and value % 1 == 0 and value >= 1 and value <= maximum
end

local function ThemeKey(value)
    return type(value) == 'string' and #value >= 3 and #value <= 96
        and value:match('^[a-z][a-z0-9_.%-]+$') ~= nil
        and value:find('.', 1, true) ~= nil
end

local function Color(value)
    return type(value) == 'string'
        and (value:match('^#%x%x%x%x%x%x$') ~= nil or value:match('^#%x%x%x%x%x%x%x%x$') ~= nil)
end

local function ExactKeys(value, keys)
    if type(value) ~= 'table' then return false end
    local allowed = {}
    for _, key in ipairs(keys) do allowed[key] = true end
    for key in pairs(value) do if not allowed[key] then return false end end
    for _, key in ipairs(keys) do if value[key] == nil then return false end end
    return true
end

function ChatContract.ValidateTheme(theme)
    if type(theme) ~= 'table' or not ThemeKey(theme.themeKey) or theme.schemaVersion ~= 1
        or not ExactKeys(theme, { 'themeKey', 'schemaVersion', 'typography', 'surface',
            'text', 'channelTokens', 'shape', 'motion' })
        or not ExactKeys(theme.typography, { 'family', 'lineHeight' })
        or not ChatContract.ThemeFamilies[theme.typography.family]
        or not NumberInRange(theme.typography.lineHeight, 1.1, 2.0)
        or not ExactKeys(theme.surface, { 'background', 'panel', 'border' })
        or not Color(theme.surface.background) or not Color(theme.surface.panel)
        or not Color(theme.surface.border)
        or not ExactKeys(theme.text, { 'primary', 'muted', 'danger' })
        or not Color(theme.text.primary) or not Color(theme.text.muted)
        or not Color(theme.text.danger)
        or not ExactKeys(theme.channelTokens, ChatContract.ThemeTokenKeys)
        or not ExactKeys(theme.shape, { 'radius', 'borderWidth' })
        or not NumberInRange(theme.shape.radius, 0, 16)
        or not NumberInRange(theme.shape.borderWidth, 1, 3)
        or not ExactKeys(theme.motion, { 'enabled', 'durationMs' })
        or type(theme.motion.enabled) ~= 'boolean'
        or not NumberInRange(theme.motion.durationMs, 0, 500) then
        return false, ChatResults.Err('invalid_theme', ChatLocale.T('error_theme_document_is_invalid'))
    end
    for _, key in ipairs(ChatContract.ThemeTokenKeys) do
        if not Color(theme.channelTokens[key]) then
            return false, ChatResults.Err('invalid_theme', ChatLocale.T('error_theme_channel_token_is_invalid'), { token=key })
        end
    end
    return true
end

function ChatContract.ValidateConfig(config)
    if type(config) ~= 'table' then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_configuration_must_be_a_table'))
    end
    if type(config.Input) ~= 'table' or type(config.Input.command) ~= 'string'
        or config.Input.command == '' or #config.Input.command > 32
        or type(config.Input.defaultKey) ~= 'string' or config.Input.defaultKey == ''
        or #config.Input.defaultKey > 32 or type(config.Input.closeOnSubmit) ~= 'boolean' then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_input_configuration_is_invalid'))
    end
    if type(config.Channels) ~= 'table' or type(config.Channels.oocEnabled) ~= 'boolean'
        or type(config.Channels.proximity) ~= 'table' then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_channel_configuration_is_invalid'))
    end
    for _, key in ipairs({ 'whisper', 'say', 'roleplay', 'shout' }) do
        if not NumberInRange(config.Channels.proximity[key], 1.0, 100.0) then
            return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_proximity_configuration_is_invalid'), {
                field = 'Channels.proximity.' .. key
            })
        end
    end
    if type(config.Limits) ~= 'table'
        or not PositiveInteger(config.Limits.maxMessageBytes, 4000)
        or not PositiveInteger(config.Limits.maxMessageLines, 20)
        or not PositiveInteger(config.Limits.maxClientBuffer, 500)
        or not PositiveInteger(config.Limits.maxInputHistory, 100)
        or not PositiveInteger(config.Limits.callbackTimeoutMs, 30000) then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_limit_configuration_is_invalid'))
    end
    if type(config.RateLimit) ~= 'table'
        or not PositiveInteger(config.RateLimit.windowMs, 60000)
        or not PositiveInteger(config.RateLimit.maxMessages, 100)
        or not PositiveInteger(config.RateLimit.repeatedWindowMs, 60000)
        or not PositiveInteger(config.RateLimit.maxRepeatedMessages, 20)
        or type(config.RateLimit.channelProfiles) ~= 'table' then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_rate_limit_configuration_is_invalid'))
    end
    for channelKey, profile in pairs(config.RateLimit.channelProfiles) do
        if type(channelKey) ~= 'string' or type(profile) ~= 'table'
            or not PositiveInteger(profile.windowMs, 60000)
            or not PositiveInteger(profile.maxMessages, 100) then
            return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_channel_rate_limit_profile_is_invalid'))
        end
    end
    local moderation = config.Moderation
    local mutes = type(moderation) == 'table' and moderation.mutes or nil
    local controls = type(moderation) == 'table' and moderation.playerControls or nil
    local bypass = type(moderation) == 'table' and moderation.staffBypass or nil
    local audit = type(moderation) == 'table' and moderation.audit or nil
    local providers = type(moderation) == 'table' and moderation.providers or nil
    local trustedCallers = type(moderation) == 'table' and moderation.trustedCallers or nil
    local validScopes, seenScopes = { all=true, channel=true, ooc=true }, {}
    if type(mutes) ~= 'table' or type(mutes.enabled) ~= 'boolean'
        or type(mutes.allowedScopes) ~= 'table' or #mutes.allowedScopes < 1
        or #mutes.allowedScopes > 3 or type(mutes.permanentAllowed) ~= 'boolean'
        or not PositiveInteger(mutes.maximumDurationMinutes, 525600)
        or mutes.persistenceRequired ~= true then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_mute_configuration_is_invalid'))
    end
    for _, scope in ipairs(mutes.allowedScopes) do
        if not validScopes[scope] or seenScopes[scope] then
            return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_mute_scope_configuration_is_invalid'))
        end
        seenScopes[scope] = true
    end
    if type(controls) ~= 'table' or type(controls.ignoreEnabled) ~= 'boolean'
        or (controls.ignoreSubjectScope ~= 'account' and controls.ignoreSubjectScope ~= 'character')
        or not PositiveInteger(controls.maximumIgnoredSubjects, 500) then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_ignore_configuration_is_invalid'))
    end
    if type(bypass) ~= 'table' or bypass.system ~= true
        or bypass.moderation ~= true or bypass.staffChannel ~= true
        or bypass.staffCase ~= true or bypass.ordinaryPlayerChat ~= false
        or type(providers) ~= 'table' or type(providers.enabled) ~= 'boolean'
        or type(providers.required) ~= 'boolean'
        or (providers.required and not providers.enabled)
        or not PositiveInteger(providers.maximumRegistered, 32)
        or type(trustedCallers) ~= 'table'
        or type(audit) ~= 'table' or type(audit.enabled) ~= 'boolean'
        or audit.includeMessageBody ~= false then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_moderation_policy_is_invalid'))
    end
    local trustedCount = 0
    for resource, allowed in pairs(trustedCallers) do
        trustedCount = trustedCount + 1
        if type(resource) ~= 'string' or #resource < 3 or #resource > 64 or allowed ~= true then
            return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_moderation_caller_policy_is_invalid'))
        end
    end
    if trustedCount < 1 or trustedCount > 16 then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_requires_a_bounded_trusted_moderation_caller_list'))
    end
    if type(config.Layout) ~= 'table' or not ChatContract.Anchors[config.Layout.anchor]
        or not ChatContract.Densities[config.Layout.density]
        or not NumberInRange(config.Layout.widthVw, 20, 80)
        or not NumberInRange(config.Layout.maxHeightVh, 15, 80)
        or not NumberInRange(config.Layout.fadeDelayMs, 0, 60000)
        or not NumberInRange(config.Layout.idleOpacity, 0, 1)
        or not NumberInRange(config.Layout.fontScale, 0.75, 1.5)
        or type(config.Layout.timestamps) ~= 'boolean'
        or type(config.Layout.reducedMotion) ~= 'boolean' then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_layout_configuration_is_invalid'))
    end
    if type(config.Theme) ~= 'table' or not ThemeKey(config.Theme.default)
        or type(config.Theme.approved) ~= 'table' or #config.Theme.approved < 1
        or #config.Theme.approved > 16 then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_theme_configuration_is_invalid'))
    end
    local approvedThemes = {}
    for _, theme in ipairs(config.Theme.approved) do
        if not ThemeKey(theme) or approvedThemes[theme] then
            return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_approved_theme_is_invalid'), { theme=theme })
        end
        approvedThemes[theme] = true
    end
    if not approvedThemes[config.Theme.default] then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_default_theme_must_be_approved'))
    end
    local preferences = config.Preferences
    if type(preferences) ~= 'table' or type(preferences.theme) ~= 'boolean'
        or type(preferences.density) ~= 'boolean' or type(preferences.timestamps) ~= 'boolean'
        or type(preferences.reducedMotion) ~= 'boolean'
        or type(preferences.fontScale) ~= 'table'
        or type(preferences.fontScale.enabled) ~= 'boolean'
        or not NumberInRange(preferences.fontScale.minimum, 0.75, 1.5)
        or not NumberInRange(preferences.fontScale.maximum, 0.75, 1.5)
        or preferences.fontScale.minimum > preferences.fontScale.maximum
        or not NumberInRange(preferences.fontScale.step, 0.01, 0.25)
        or type(preferences.idleOpacity) ~= 'table'
        or type(preferences.idleOpacity.enabled) ~= 'boolean'
        or not NumberInRange(preferences.idleOpacity.minimum, 0.1, 1.0)
        or not NumberInRange(preferences.idleOpacity.maximum, 0.1, 1.0)
        or preferences.idleOpacity.minimum > preferences.idleOpacity.maximum
        or not NumberInRange(preferences.idleOpacity.step, 0.01, 0.25) then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_preference_configuration_is_invalid'))
    end
    if type(config.Features) ~= 'table' or type(config.Features.history) ~= 'boolean'
        or type(config.Features.privateMessages) ~= 'boolean'
        or type(config.Features.emojiPicker) ~= 'boolean' then
        return ChatResults.Err('invalid_configuration', ChatLocale.T('error_chat_feature_configuration_is_invalid'))
    end
    return ChatResults.Ok(true)
end

function ChatContract.ValidateSubmission(payload, limits)
    local allowed = { channelKey=true, text=true, submissionId=true }
    if type(payload) ~= 'table' or type(payload.channelKey) ~= 'string'
        or #payload.channelKey < 3 or #payload.channelKey > 96
        or payload.channelKey:match('^[a-z][a-z0-9_.%-]+$') == nil
        or payload.channelKey:find('.', 1, true) == nil
        or type(payload.text) ~= 'string' or type(payload.submissionId) ~= 'string'
        or #payload.submissionId < 1 or #payload.submissionId > 64
        or payload.submissionId:match('^[%w:_%-]+$') == nil then
        return false, ChatResults.Err('invalid_input', ChatLocale.T('error_chat_submission_is_invalid'))
    end
    for key in pairs(payload) do
        if allowed[key] ~= true then
            return false, ChatResults.Err('invalid_input', ChatLocale.T('error_chat_submission_contains_an_unknown_field'))
        end
    end
    if #payload.text < 1 or #payload.text > limits.maxMessageBytes then
        return false, ChatResults.Err('invalid_message', ChatLocale.T('error_message_length_is_invalid'))
    end
    return true
end

function ChatContract.ValidateIgnoreRequest(payload)
    if type(payload) ~= 'table' or type(payload.messageId) ~= 'string'
        or #payload.messageId ~= 36
        or payload.messageId:match('^[0-9a-fA-F%-]+$') == nil then
        return false, ChatResults.Err('invalid_input', ChatLocale.T('error_ignore_request_is_invalid'))
    end
    for key in pairs(payload) do
        if key ~= 'messageId' then
            return false, ChatResults.Err('invalid_input', ChatLocale.T('error_ignore_request_contains_an_unknown_field'))
        end
    end
    return true
end

function ChatContract.ValidateIgnoreRemove(payload)
    if type(payload) ~= 'table' or type(payload.ignoreId) ~= 'string'
        or #payload.ignoreId ~= 36 or payload.ignoreId:match('^[0-9a-fA-F%-]+$') == nil then
        return false, ChatResults.Err('invalid_input', ChatLocale.T('error_ignore_removal_request_is_invalid'))
    end
    for key in pairs(payload) do
        if key ~= 'ignoreId' then
            return false, ChatResults.Err('invalid_input', ChatLocale.T('error_ignore_removal_contains_an_unknown_field'))
        end
    end
    return true
end
