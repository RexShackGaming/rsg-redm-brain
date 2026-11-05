ChatPresentation = {}

local resourceName = GetCurrentResourceName()
local settingsGeneration = 0
local themes, defaultTheme, themeRevision = {}, Config.Theme.default, 0
local keys = {
    theme='presentation_theme', density='presentation_density',
    timestamps='presentation_timestamps', reducedMotion='presentation_reduced_motion',
    fontScale='presentation_font_scale', idleOpacity='presentation_idle_opacity'
}

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

local function Clamp(value, minimum, maximum, step)
    value = tonumber(value)
    if not value then return nil end
    value = math.max(minimum, math.min(maximum, value))
    return math.floor((value - minimum) / step + 0.5) * step + minimum
end

local function Saved(key)
    return GetResourceKvpString(keys[key])
end

local function Save(key, value)
    SetResourceKvp(keys[key], tostring(value))
end

local function SelectedTheme()
    local saved = Saved('theme')
    if Config.Preferences.theme and saved and themes[saved] then return saved end
    return themes[defaultTheme] and defaultTheme or Config.Theme.default
end

local function BooleanPreference(key, configured)
    local saved = Saved(key)
    if saved == 'true' then return true end
    if saved == 'false' then return false end
    return configured
end

local function NumberPreference(key, configured, bounds)
    local saved = Clamp(Saved(key), bounds.minimum, bounds.maximum, bounds.step)
    return saved or configured
end

local function EffectiveLayout()
    local layout = {}
    for key, value in pairs(Config.Layout) do layout[key] = value end
    if Config.Preferences.density then
        local saved = Saved('density')
        if ChatContract.Densities[saved] then layout.density = saved end
    end
    if Config.Preferences.timestamps then
        layout.timestamps = BooleanPreference('timestamps', layout.timestamps)
    end
    if Config.Preferences.reducedMotion then
        layout.reducedMotion = BooleanPreference('reducedMotion', layout.reducedMotion)
    end
    if Config.Preferences.fontScale.enabled then
        layout.fontScale = NumberPreference('fontScale', layout.fontScale,
            Config.Preferences.fontScale)
    end
    if Config.Preferences.idleOpacity.enabled then
        layout.idleOpacity = NumberPreference('idleOpacity', layout.idleOpacity,
            Config.Preferences.idleOpacity)
    end
    return layout
end

local function State()
    local themeKey = SelectedTheme()
    return {
        layout=EffectiveLayout(), theme=themeKey,
        themeDocument=Copy(themes[themeKey]), themeRevision=themeRevision
    }
end

local function Apply()
    SendNUIMessage({ type='chat:presentation', presentation=State() })
    TriggerEvent('chat.presentation.changed.v1', State())
end

local setters = {}

setters.theme = function(value)
    if not Config.Preferences.theme or type(value) ~= 'string' or not themes[value] then return false end
    Save('theme', value)
    Apply()
    return true
end

setters.density = function(value)
    if not Config.Preferences.density or not ChatContract.Densities[value] then return false end
    Save('density', value)
    Apply()
    return true
end

setters.timestamps = function(value)
    if not Config.Preferences.timestamps or (value ~= 'true' and value ~= 'false') then return false end
    Save('timestamps', value)
    Apply()
    return true
end

setters.reducedMotion = function(value)
    if not Config.Preferences.reducedMotion or (value ~= 'true' and value ~= 'false') then return false end
    Save('reducedMotion', value)
    Apply()
    return true
end

setters.fontScale = function(value)
    local bounds = Config.Preferences.fontScale
    if not bounds.enabled then return false end
    local normalized = Clamp(value, bounds.minimum, bounds.maximum, bounds.step)
    if not normalized then return false end
    Save('fontScale', normalized)
    Apply()
    return true
end

setters.idleOpacity = function(value)
    local bounds = Config.Preferences.idleOpacity
    if not bounds.enabled then return false end
    local normalized = Clamp(value, bounds.minimum, bounds.maximum, bounds.step)
    if not normalized then return false end
    Save('idleOpacity', normalized)
    Apply()
    return true
end

for key, setter in pairs(setters) do
    AddEventHandler(('Feather:Chat:Settings:%s'):format(key), setter)
end

local function ThemeOptions()
    local options = {}
    for themeKey in pairs(themes) do
        options[#options + 1] = {
            value=themeKey,
            label=themeKey == 'feather.default' and ChatLocale.T('ui_feather_default')
                or themeKey == 'feather.high_contrast' and ChatLocale.T('ui_high_contrast') or themeKey
        }
    end
    table.sort(options, function(left, right) return left.label < right.label end)
    return options
end

local function RegisterChoice(spec)
    spec.ownerResource = resourceName
    spec.setEvent = ('Feather:Chat:Settings:%s'):format(spec.preference)
    spec.preference = nil
    local ok, registered, reason = pcall(function()
        return exports['feather-settings']:RegisterChoice(spec)
    end)
    if not ok or registered ~= true then
        print(ChatLocale.Format('operator_settings_registration_failed_id_value_reason_value',
            tostring(spec.id), ok and tostring(reason or ChatLocale.T('error_provider_rejected')) or tostring(registered)))
        return false
    end
    return true
end

local function RegisterSettings()
    if GetResourceState('feather-settings') ~= 'started' then return 'retry' end
    local state = State()
    local choices = {}
    if Config.Preferences.theme and #ThemeOptions() >= 2 then
        choices[#choices + 1] = { id='feather-chat:theme', label=ChatLocale.T('ui_chat_theme'),
            control='dropdown', options=ThemeOptions(), initialValue=state.theme, preference='theme' }
    end
    if Config.Preferences.density then
        choices[#choices + 1] = { id='feather-chat:density', label=ChatLocale.T('ui_chat_density'), control='arrows',
            options={{value='compact',label=ChatLocale.T('ui_compact')},{value='comfortable',label=ChatLocale.T('ui_comfortable')}},
            initialValue=state.layout.density, preference='density' }
    end
    if Config.Preferences.timestamps then
        choices[#choices + 1] = { id='feather-chat:timestamps', label=ChatLocale.T('ui_chat_timestamps'), control='arrows',
            options={{value='true',label=ChatLocale.T('ui_shown')},{value='false',label=ChatLocale.T('ui_hidden')}},
            initialValue=tostring(state.layout.timestamps), preference='timestamps' }
    end
    if Config.Preferences.reducedMotion then
        choices[#choices + 1] = { id='feather-chat:reduced-motion', label=ChatLocale.T('ui_chat_motion'), control='arrows',
            options={{value='false',label=ChatLocale.T('ui_standard')},{value='true',label=ChatLocale.T('ui_reduced')}},
            initialValue=tostring(state.layout.reducedMotion), preference='reducedMotion' }
    end
    if Config.Preferences.fontScale.enabled then
        local bounds = Config.Preferences.fontScale
        choices[#choices + 1] = { id='feather-chat:font-scale', label=ChatLocale.T('ui_chat_text_scale'), control='slider',
            min=bounds.minimum, max=bounds.maximum, step=bounds.step,
            initialValue=state.layout.fontScale, preference='fontScale' }
    end
    if Config.Preferences.idleOpacity.enabled then
        local bounds = Config.Preferences.idleOpacity
        choices[#choices + 1] = { id='feather-chat:idle-opacity', label=ChatLocale.T('ui_chat_idle_opacity'), control='slider',
            min=bounds.minimum, max=bounds.maximum, step=bounds.step,
            initialValue=state.layout.idleOpacity, preference='idleOpacity' }
    end
    for _, choice in ipairs(choices) do if not RegisterChoice(choice) then return 'rejected' end end
    return 'done'
end

local function ScheduleSettingsRegistration()
    settingsGeneration = settingsGeneration + 1
    local generation = settingsGeneration
    CreateThread(function()
        while generation == settingsGeneration do
            local outcome = RegisterSettings()
            if outcome == 'done' or outcome == 'rejected' then return end
            Wait(250)
        end
    end)
end

function ChatPresentation.RefreshThemes()
    local result = exports['feather-core']:CallRPCAsync(
        'chat.theme.list.v1', {}, nil, Config.Limits.callbackTimeoutMs)
    if type(result) ~= 'table' or not result.ok or type(result.value) ~= 'table'
        or type(result.value.themes) ~= 'table' then return result end
    local refreshed = {}
    for _, theme in ipairs(result.value.themes) do
        local valid = ChatContract.ValidateTheme(theme)
        if valid then refreshed[theme.themeKey] = theme end
    end
    themes = refreshed
    defaultTheme = type(result.value.defaultTheme) == 'string'
        and result.value.defaultTheme or Config.Theme.default
    themeRevision = tonumber(result.value.revision) or themeRevision
    Apply()
    ScheduleSettingsRegistration()
    return result
end

function ChatPresentation.GetState() return State() end
AddEventHandler('feather-core:locale:changed', ScheduleSettingsRegistration)
function ChatPresentation.Apply() Apply() end

exports('GetPresentation', function()
    return ChatResults.Ok(State())
end)

exports('SetPresentationPreference', function(key, value)
    local setter = type(key) == 'string' and setters[key] or nil
    if not setter then
        return ChatResults.Err('invalid_input', ChatLocale.T('error_chat_presentation_preference_is_unknown'))
    end
    if not setter(value) then
        return ChatResults.Err('invalid_preference', ChatLocale.T('error_chat_presentation_preference_was_rejected'))
    end
    return ChatResults.Ok(State())
end)

RegisterCommand('ChatPresentationSmokeTest', function()
    local state = State()
    local themeValid = state.themeDocument
        and ChatContract.ValidateTheme(state.themeDocument) == true
    local layout = state.layout
    local tests = {
        { 'validated active theme', themeValid },
        { 'approved theme selected', themes[state.theme] ~= nil },
        { 'font scale bounded', type(layout.fontScale) == 'number'
            and layout.fontScale >= Config.Preferences.fontScale.minimum
            and layout.fontScale <= Config.Preferences.fontScale.maximum },
        { 'idle opacity bounded', type(layout.idleOpacity) == 'number'
            and layout.idleOpacity >= Config.Preferences.idleOpacity.minimum
            and layout.idleOpacity <= Config.Preferences.idleOpacity.maximum },
        { 'accessibility flags typed', type(layout.timestamps) == 'boolean'
            and type(layout.reducedMotion) == 'boolean' }
    }
    local passed = 0
    for _, test in ipairs(tests) do
        if test[2] then passed = passed + 1 end
        print(('[ChatPresentationSmokeTest] %-28s %s'):format(
            test[1], test[2] and 'PASS' or 'FAIL'))
    end
    print(('[ChatPresentationSmokeTest] done %d/%d passed'):format(passed, #tests))
end, false)

RegisterNetEvent('feather-chat:themes:v1', function(serverRevision)
    if tonumber(serverRevision) and tonumber(serverRevision) <= themeRevision then return end
    ChatPresentation.RefreshThemes()
end)

RegisterNetEvent('Feather:Character:Spawned', function()
    ChatPresentation.RefreshThemes()
end)

AddEventHandler('onClientResourceStart', function(startedResource)
    if startedResource == 'feather-settings' then ScheduleSettingsRegistration() end
end)

AddEventHandler('onClientResourceStop', function(stoppedResource)
    if stoppedResource == 'feather-settings' then settingsGeneration = settingsGeneration + 1 end
end)

CreateThread(function()
    Wait(0)
    ChatPresentation.RefreshThemes()
    ScheduleSettingsRegistration()
end)
