TargetPractiseLocale = {}

-- The NUI needs every ui_* string. Key names are read from en.json (the master
-- file); values come from rsg-core's locale() so the server language applies.
local uiKeys
local function keys()
    if uiKeys then return uiKeys end
    uiKeys = {}
    local raw = LoadResourceFile(GetCurrentResourceName(), 'locales/en.json')
    local ok, data = pcall(json.decode, raw or '')
    if ok and type(data) == 'table' then
        for key in pairs(data) do
            if key:sub(1, 3) == 'ui_' then uiKeys[#uiKeys + 1] = key end
        end
    end
    return uiKeys
end

function TargetPractiseLocale.ui()
    local values = {}
    for _, key in ipairs(keys()) do values[key] = locale(key) end
    values.unknown_player = locale('unknown_player')
    return values
end
