-- Named weather patterns built by admins in the NUI, persisted to patterns.json
local API = RSGWeather
local FILE = 'patterns.json'
local Store = { active = 'default', patterns = {} }

local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(Store, { indent = true }), -1)
end

local function load()
    local raw = LoadResourceFile(GetCurrentResourceName(), FILE)
    local data = raw and json.decode(raw)
    if type(data) == 'table' and type(data.patterns) == 'table' then
        Store.active = data.active or 'default'
        Store.patterns = data.patterns
    end
end

local function sanitizeName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 32)
    if name == '' or name:lower() == 'default' or not name:match('^[%w%s%-%_]+$') then return nil end
    return name
end

-- returns cleaned pattern or nil, errorMessage
local function validate(pattern)
    if type(pattern) ~= 'table' or not next(pattern) then return nil, L('err_pattern_empty', 'Pattern is empty') end
    local clean = {}
    for from, choices in pairs(pattern) do
        if not IsValidWeather(from) then return nil, L('unknown_weather', 'Unknown weather type: %s', tostring(from)) end
        if type(choices) ~= 'table' or not next(choices) then return nil, L('err_no_next', '%s has no next weather', WeatherLabel(from)) end
        local sum = 0
        clean[from] = {}
        for to, chance in pairs(choices) do
            chance = math.floor(tonumber(chance) or 0)
            if not IsValidWeather(to) then return nil, L('unknown_weather', 'Unknown weather type: %s', tostring(to)) end
            if chance < 0 then return nil, L('err_negative', 'Chances cannot be negative') end
            if chance > 0 then clean[from][to] = chance; sum = sum + chance end
        end
        if sum ~= 100 then return nil, L('err_sum', '%s adds up to %d%%, must be 100%%', WeatherLabel(from), sum) end
    end
    -- every weather the pattern can move to must itself have an entry, or the chain dead-ends
    for _, choices in pairs(clean) do
        for to in pairs(choices) do
            if not clean[to] then return nil, L('err_missing_block', '%s is used but has no block of its own', WeatherLabel(to)) end
        end
    end
    return clean
end

local function applyActive()
    local p = Store.patterns[Store.active]
    if Store.active ~= 'default' and p then API.setWeatherPattern(p) else Store.active = 'default'; API.resetWeatherPattern() end
end

local function listForClient()
    return { active = Store.active, patterns = Store.patterns, default = Config.WeatherPattern }
end

lib.callback.register('rsg-weather:server:getPatterns', function(src)
    if not RSGWeatherIsAdmin(src) then RSGWeatherDeny(src, L('wh_what_pattern_list', 'pattern list')); return nil end
    return listForClient()
end)

lib.callback.register('rsg-weather:server:savePattern', function(src, name, pattern, apply)
    if not RSGWeatherIsAdmin(src) then RSGWeatherDeny(src, L('wh_what_save_pattern', 'save pattern')); return false, L('no_permission', 'No permission') end
    name = sanitizeName(name)
    if not name then return false, L('err_invalid_name', 'Invalid name (letters, numbers, spaces, - and _ only; not "default")') end
    local clean, err = validate(pattern)
    if not clean then return false, err end
    Store.patterns[name] = clean
    if apply or Store.active == name then Store.active = name; applyActive() end
    save()
    print(('[rsg-weather] %s saved weather pattern "%s"'):format(GetPlayerName(src) or 'console', name))
    local lines = {}
    for from, choices in pairs(clean) do
        local parts = {}
        for to, c in pairs(choices) do parts[#parts + 1] = ('%s %d%%'):format(WeatherLabel(to), c) end
        lines[#lines + 1] = ('**%s** → %s'):format(WeatherLabel(from), table.concat(parts, ', '))
    end
    table.sort(lines)
    RSGWeatherLog('patterns', apply and L('wh_pattern_saved_applied', '💾 Pattern saved & applied') or L('wh_pattern_saved', '💾 Pattern saved'), table.concat(lines, '\n'),
        { { name = L('wh_name', 'Name'), value = name }, { name = L('wh_active', 'Active'), value = Store.active } }, src)
    return true, listForClient()
end)

lib.callback.register('rsg-weather:server:deletePattern', function(src, name)
    if not RSGWeatherIsAdmin(src) then RSGWeatherDeny(src, L('wh_what_delete_pattern', 'delete pattern')); return false end
    if not Store.patterns[name] then return false end
    Store.patterns[name] = nil
    RSGWeatherLog('patterns', L('wh_pattern_deleted', '🗑️ Pattern deleted'), nil, { { name = L('wh_name', 'Name'), value = name } }, src)
    if Store.active == name then Store.active = 'default'; applyActive() end
    save()
    return true, listForClient()
end)

lib.callback.register('rsg-weather:server:applyPattern', function(src, name)
    if not RSGWeatherIsAdmin(src) then RSGWeatherDeny(src, L('wh_what_apply_pattern', 'apply pattern')); return false end
    if name ~= 'default' and not Store.patterns[name] then return false end
    Store.active = name
    RSGWeatherLog('patterns', L('wh_pattern_applied', '✅ Pattern applied'), nil, { { name = L('wh_name', 'Name'), value = name } }, src)
    applyActive(); save()
    return true, listForClient()
end)

AddEventHandler('rsg-weather:server:restorePattern', function()
    applyActive()
end)

AddEventHandler('rsg-weather:server:patternsReset', function()
    Store.active = 'default'
    save()
end)

exports('getActivePatternName', function() return Store.active end)
exports('getSavedPatterns', function() return Store.patterns end)

CreateThread(function()
    load()
    Wait(0)
    applyActive()
end)
