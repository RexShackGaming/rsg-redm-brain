------------------------------------------
-- trapper demand: weather / seasonal events (rsg-weather) change what trappers pay
------------------------------------------
HuntingDemand = {}

local function current()
    local w = GlobalState.rsgWeather
    local s = GlobalState.rsgSeason
    return w and w.weather and tostring(w.weather):lower() or nil, s and s.name or nil
end

local function ruleActive(rule, weather, season)
    if not rule.weather and not rule.season then return false end
    if rule.weather then
        local hit = false
        for _, w in ipairs(rule.weather) do if w == weather then hit = true break end end
        if not hit then return false end
    end
    if rule.season and rule.season ~= season then return false end
    return true
end

local function matches(rule, itemName)
    for _, part in ipairs(rule.match or {}) do
        if itemName:find(part, 1, true) then return true end
    end
    return false
end

-- price multiplier for an item right now (1.0 = no change)
function HuntingDemand.Multiplier(itemName)
    local cfg = Config.Demand
    if not cfg or not cfg.Enabled then return 1.0 end
    local weather, season = current()
    local best = 1.0
    for _, rule in ipairs(cfg.Rules or {}) do
        if (rule.mult or 1) > best and ruleActive(rule, weather, season) and matches(rule, itemName) then best = rule.mult end
    end
    return best
end

-- text for the rules that are active now: { { label, pct }, ... }
function HuntingDemand.Active()
    local cfg = Config.Demand
    local out = {}
    if not cfg or not cfg.Enabled then return out end
    local weather, season = current()
    for _, rule in ipairs(cfg.Rules or {}) do
        if (rule.mult or 1) > 1 and ruleActive(rule, weather, season) then
            out[#out + 1] = { label = rule.label, pct = math.floor(((rule.mult - 1) * 100) + 0.5) }
        end
    end
    return out
end
