-- Same Core-backed locale adapter used by Feather Inventory, in both contexts.
Feather = Feather or {}
Feather.Locale = {
    register = function(locale, translations)
        return exports['feather-core']:RegisterLocale(locale, translations)
    end,
    translate = function(source, key, ...)
        local result = exports['feather-core']:TranslateLocale(source, key, ...)
        return type(result) == 'table' and result.ok == true and result.value
            or ('Translation [%s] is unavailable'):format(tostring(key))
    end
}
