TargetPractiseLocale = {}

function TargetPractiseLocale.ui()
    local values = {}
    local locales = lib.getLocales and lib.getLocales() or {}

    for key, value in pairs(locales) do
        if key:sub(1, 3) == 'ui_' then values[key] = value end
    end

    values.unknown_player = locale('unknown_player')
    return values
end
