ChatLocale = {}
local english = {}
for key, value in pairs(ChatLocaleEnglish) do english[key:sub(#'feather_chat_' + 1)] = value end
local messageKeys = {}

function ChatLocale.Resolve(base, override)
    local resolved = {}
    for key, value in pairs(base) do
        resolved[key] = type(override) == 'table' and type(override[key]) == 'string'
            and override[key] ~= '' and override[key] or value
    end
    return resolved
end

function ChatLocale.Render(dictionary, key, variables)
    local text = dictionary[key] or key
    return text:gsub('{([%w_]+)}', function(name)
        local value = variables and variables[name]
        return value ~= nil and tostring(value) or ('{' .. name .. '}')
    end)
end

-- Core chooses the player's saved account language on the client. Server callers
-- may supply a source; source 0 uses the framework's configured default language.
function ChatLocale.T(key, variables, source)
    local ok, translated = pcall(Feather.Locale.translate, source or 0, 'feather_chat_' .. key)
    if not ok or type(translated) ~= 'string' or translated == ''
        or translated:match('^Translation %[') or translated:match('^Locale %[') then
        translated = english[key] or key
    end
    if key:sub(1, 6) == 'error_' then messageKeys[translated] = key end
    return ChatLocale.Render({ [key]=translated }, key, variables)
end

function ChatLocale.Dictionary()
    local dictionary = {}
    for key in pairs(english) do
        if key:sub(1, 9) ~= 'operator_' then dictionary[key] = ChatLocale.T(key) end
    end
    return dictionary
end

function ChatLocale.MessageKey(message) return messageKeys[message] end
function ChatLocale.LocalizeResult(result)
    if type(result) == 'table' and result.ok == false and type(result.messageKey) == 'string' then
        result.message = ChatLocale.T(result.messageKey)
    end
    return result
end

function ChatLocale.Smoke()
    local fixture = ChatLocale.Resolve({ greeting='Hello {name}', fallback='Fallback' },
        { greeting='Welcome {name}', fallback=false })
    return {
        { 'translation override selected', fixture.greeting == 'Welcome {name}' },
        { 'invalid translation falls back', fixture.fallback == 'Fallback' },
        { 'missing translation falls back', ChatLocale.Resolve({ text='English' }).text == 'English' },
        { 'replacement is literal', ChatLocale.Render(fixture, 'greeting', {name='100% <text>'}) == 'Welcome 100% <text>' },
        { 'unknown key remains visible', ChatLocale.T('missing.smoke') == 'missing.smoke' },
        { 'operator format accepts arguments', ChatLocale.Format('operator_moderation_operation_failed_value', 'smoke'):find('smoke', 1, true) ~= nil },
        { 'Core locale registry available', exports['feather-core']:TranslateLocale(0, 'feather_chat_ui_staff').ok == true }
    }
end


-- Operator messages retain structured codes/markers and use the Core default
-- language. Format arguments are passed through the standard locale adapter.
function ChatLocale.Format(key, ...)
    local ok, text = pcall(Feather.Locale.translate, 0, 'feather_chat_' .. key, ...)
    if not ok or type(text) ~= 'string' or text == ''
        or text:match('^Translation %[') or text:match('^Locale %[') then
        return string.format(english[key] or key, ...)
    end
    return text
end
