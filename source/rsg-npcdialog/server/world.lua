-- In-game clock, weather (rsg-weather) and real-time quest reset periods. Server only.
World = {}

World.Weathers = {
    'blizzard', 'clouds', 'drizzle', 'fog', 'groundblizzard', 'hail', 'highpressure', 'hurricane', 'misty',
    'overcast', 'overcastdark', 'rain', 'sandstorm', 'shower', 'sleet', 'snow', 'snowlight', 'sunny',
    'thunder', 'thunderstorm', 'whiteout',
}

local warned = false
local function weather(fn)
    if GetResourceState('rsg-weather') == 'started' then
        local ok, result = pcall(fn)
        if ok then return result end
    end
    if not warned then
        warned = true
        print('^3[rsg-npcdialog] time / weather rules need rsg-weather, which is not available^7')
    end
    return nil
end

---@return integer|nil hour in-game hour 0-23
function World.Hour()
    local t = weather(function() return exports['rsg-weather']:getTime() end)
    return t and t.hour
end

---@return string|nil weather the server weather type (regional changes are client side only)
function World.Weather()
    local w = weather(function() return exports['rsg-weather']:getWeather() end)
    return type(w) == 'string' and w:lower() or nil
end

-- 'from' is included, 'to' is not. Wraps past midnight; equal values mean all day.
function World.InHours(hour, from, to)
    if from == to then return true end
    if from < to then return hour >= from and hour < to end
    return hour >= from or hour < to
end

-------------------------------------------------
-- daily / weekly periods
-------------------------------------------------
-- seconds added to a unix time so that a period boundary falls on a whole day
local function shift()
    local r = Config.Quests.Reset
    return math.floor((r.UtcOffset - r.Hour) * 3600)
end

-- 1 January 1970 was a Thursday: 3 days after Monday
local function weekOffset() return 3 - (Config.Quests.Reset.WeekDay - 1) end

---@param kind 'daily'|'weekly'
---@return integer period number that changes at each reset
function World.Period(kind, at)
    local day = (at + shift()) // 86400
    if kind == 'weekly' then return (day + weekOffset()) // 7 end
    return day
end

---@return integer unix time of the next reset
function World.NextReset(kind, now)
    local nextPeriod = World.Period(kind, now) + 1
    local day = nextPeriod
    if kind == 'weekly' then day = nextPeriod * 7 - weekOffset() end
    return day * 86400 - shift()
end

-- FNV-1a with a final mix: the same pick for everyone, with nothing to save
function World.Hash(s)
    local h = 2166136261
    for i = 1, #s do h = ((h ~ s:byte(i)) * 16777619) & 0xFFFFFFFF end
    h = ((h ~ (h >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
    return h ~ (h >> 16)
end

-- "Come back in ..." text for a wait in seconds
function World.WaitText(seconds)
    local minutes = math.max(1, math.ceil(seconds / 60))
    if minutes < 60 then return locale('req_cooldown', minutes) end
    return locale('req_cooldown_hours', minutes // 60, minutes % 60)
end
