local currentLocale = 'en'
local localeData = {}

local function loadLocale(lang)
    local ok, data = pcall(lib.loadJson, ('locales.%s'):format(lang))
    if ok and data then
        localeData = data
        currentLocale = lang
        return true
    end
    return false
end

if not loadLocale(currentLocale) then
    loadLocale('en')
end

_G.locale = function(key, ...)
    local value = localeData[key]
    if value == nil then
        return key
    end
    if select('#', ...) > 0 then
        return value:format(...)
    end
    return value
end
