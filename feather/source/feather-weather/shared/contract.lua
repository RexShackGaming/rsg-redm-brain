Weather = { WEEK = 604800, CONTRACT = 1 }
local W = Weather
W.types = {}
for name in ('blizzard clouds drizzle fog groundblizzard hail highpressure hurricane misty overcast overcastdark rain sandstorm shower sleet snow snowlight sunny thunder thunderstorm whiteout'):gmatch('%S+') do
    W.types[name] = true
end

function W.Ok(value) return { ok = true, value = value } end
function W.Err(code, message) return { ok = false, code = code, message = message } end
function W.Number(value, low, high, integer)
    return type(value) == 'number' and value == value and value >= low and value <= high
        and (not integer or value % 1 == 0)
end
function W.Copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = W.Copy(item) end
    return result
end
function W.Fields(value, allowed)
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end
function W.Clock(value)
    return W.Fields(value, { mode=true, seconds=true, rate=true, frozen=true, offsetSeconds=true })
        and (value.mode == 'simulated' or value.mode == 'wall')
        and W.Number(value.seconds, 0, W.WEEK) and value.seconds < W.WEEK
        and W.Number(value.rate, 0, 120) and type(value.frozen) == 'boolean'
        and W.Number(value.offsetSeconds, -86400, 86400, true)
end
function W.Weather(value)
    return W.Fields(value, { name=true, frozen=true, transitionSeconds=true, snow=true })
        and type(value.name) == 'string' and W.types[value.name] == true
        and type(value.frozen) == 'boolean' and type(value.snow) == 'boolean'
        and W.Number(value.transitionSeconds, 0, 300)
end
function W.Wind(value)
    return W.Fields(value, { direction=true, speed=true })
        and W.Number(value.direction, 0, 360) and value.direction < 360 and W.Number(value.speed, 0, 30)
end
W.seasonNames = { 'spring', 'summer', 'autumn', 'winter' }
function W.SeasonIndex(name)
    for i,v in ipairs(W.seasonNames) do if v==name then return i end end
end
function W.WindControl(value)
    return W.Fields(value,{automatic=true,frozen=true}) and type(value.automatic)=='boolean' and type(value.frozen)=='boolean'
end
function W.WindProgression(value)
    if value==nil then return true end
    local function range(r)
        return W.Fields(r,{min=true,max=true}) and W.Number(r.min,0,30) and W.Number(r.max,r.min,30)
    end
    if not W.Fields(value,{enabled=true,frozen=true,intervalSeconds=true,degreesPerSecond=true,speedPerSecond=true,default=true,profiles=true})
        or type(value.enabled)~='boolean' or type(value.frozen)~='boolean'
        or not W.Number(value.intervalSeconds,5,3600) or not W.Number(value.degreesPerSecond,0.01,90)
        or not W.Number(value.speedPerSecond,0.01,10) or not range(value.default)
        or type(value.profiles)~='table' or getmetatable(value.profiles) then return false end
    for name,r in pairs(value.profiles) do if not W.types[name] or not range(r) then return false end end
    return true
end
function W.Seasons(value)
    if value==nil then return true end
    if not W.Fields(value,{enabled=true,start=true,day=true,daysPerSeason=true,frozen=true,patterns=true})
        or type(value.enabled)~='boolean' or type(value.frozen)~='boolean' or not W.SeasonIndex(value.start)
        or not W.Number(value.daysPerSeason,1,365,true) or not W.Number(value.day,1,value.daysPerSeason,true)
        or not W.Fields(value.patterns,{spring=true,summer=true,autumn=true,winter=true}) then return false end
    for _,name in ipairs(W.seasonNames) do if not W.Pattern(value.patterns[name]) then return false end end
    return true
end
function W.SeasonState(value)
    return W.Fields(value,{enabled=true,frozen=true,name=true,day=true,seconds=true,daysPerSeason=true,cycle=true})
        and type(value.enabled)=='boolean' and type(value.frozen)=='boolean' and W.SeasonIndex(value.name)~=nil
        and W.Number(value.daysPerSeason,1,365,true) and W.Number(value.day,1,value.daysPerSeason,true)
        and W.Number(value.seconds,0,86400) and value.seconds<86400 and W.Number(value.cycle,0,9007199254740991,true)
end
function W.ProjectWind(wind,target,elapsed,directionRate,speedRate)
    local delta=(target.direction-wind.direction+180)%360-180
    local direction=wind.direction+math.max(-directionRate*elapsed,math.min(directionRate*elapsed,delta))
    local speedDelta=target.speed-wind.speed
    return {direction=direction%360,speed=wind.speed+math.max(-speedRate*elapsed,math.min(speedRate*elapsed,speedDelta))}
end
function W.WindMotion(value)
    return W.Fields(value,{target=true,degreesPerSecond=true,speedPerSecond=true}) and W.Wind(value.target)
        and W.Number(value.degreesPerSecond,0,90) and W.Number(value.speedPerSecond,0,10)
end
function W.Pattern(pattern)
    if type(pattern) ~= 'table' or getmetatable(pattern) then return false end
    local count = 0
    for name, row in pairs(pattern) do
        count = count + 1
        if not W.types[name] or type(row) ~= 'table' or getmetatable(row) then return false end
        local entries, sum = 0, 0
        for index, choice in pairs(row) do
            if not W.Number(index, 1, 21, true)
                or not W.Fields(choice, { name=true, weight=true })
                or type(choice.name) ~= 'string' or not W.types[choice.name]
                or type(pattern[choice.name]) ~= 'table' or not W.Number(choice.weight, 1, 100, true) then return false end
            entries, sum = entries + 1, sum + choice.weight
        end
        if entries < 1 or entries ~= #row or sum ~= 100 then return false end
    end
    return count >= 1 and count <= 21
end
function W.Merge(current, patch, validate)
    if type(patch) ~= 'table' or getmetatable(patch) then return nil end
    local nextValue = W.Copy(current)
    for key, value in pairs(patch) do
        -- Public patches contain scalars only. Reject tables before copying.
        if type(value) == 'table' then return nil end
        nextValue[key] = value
    end
    if not validate(nextValue) then return nil end
    return nextValue
end
function W.RegionalPolicy(policy)
    -- Absent policy preserves installations using the 0.1.x configuration.
    if policy == nil then return true end
    if not W.Fields(policy, {enabled=true,sampleIntervalMs=true,settleMs=true,transitionSeconds=true,rules=true})
        or type(policy.enabled) ~= 'boolean'
        or not W.Number(policy.sampleIntervalMs, 250, 10000, true)
        or not W.Number(policy.settleMs, 0, 30000, true)
        or not W.Number(policy.transitionSeconds, 0, 300)
        or type(policy.rules) ~= 'table' or getmetatable(policy.rules) then return false end
    local count, ids = 0, {}
    for index, rule in pairs(policy.rules) do
        if not W.Number(index,1,16,true) or not W.Fields(rule,
            {id=true,priority=true,zoneType=true,zones=true,autoSnow=true,weather=true})
            or type(rule.id) ~= 'string' or #rule.id < 1 or #rule.id > 48
            or rule.id == 'global' or not rule.id:match('^[a-z][a-z0-9_]*$') or ids[rule.id]
            or not W.Number(rule.priority,0,1000,true) or (rule.zoneType ~= 0 and rule.zoneType ~= 10)
            or type(rule.autoSnow) ~= 'boolean' or type(rule.zones) ~= 'table' or getmetatable(rule.zones)
            or type(rule.weather) ~= 'table' or getmetatable(rule.weather) then return false end
        ids[rule.id], count = true, count + 1
        local zoneCount, seen = 0, {}
        for zoneIndex, name in pairs(rule.zones) do
            if not W.Number(zoneIndex,1,16,true) or type(name) ~= 'string'
                or #name < 1 or #name > 64 or not name:match('^[%w_]+$') or seen[name:lower()] then return false end
            seen[name:lower()], zoneCount = true, zoneCount + 1
        end
        if zoneCount < 1 or zoneCount ~= #rule.zones then return false end
        for from, to in pairs(rule.weather) do
            if not W.types[from] or type(to) ~= 'string' or not W.types[to] then return false end
        end
    end
    return count == #policy.rules and (not policy.enabled or count > 0)
end
function W.Config(config)
    if type(config) ~= 'table' or not W.Clock(config.clock) or not W.Weather(config.weather)
        or not W.Wind(config.wind) or not W.Pattern(config.pattern)
        or not W.RegionalPolicy(config.regions) or not W.WindProgression(config.windProgression)
        or not W.Seasons(config.seasons) then return false end
    if not W.Number(config.weatherIntervalSeconds, 60, W.WEEK, true)
        or not W.Number(config.forecastCount, 1, 48, true)
        or not W.Number(config.syncIntervalMs, 1000, 60000, true)
        or not W.Number(config.tickIntervalMs, 50, 1000, true)
        or not W.Number(config.clientIntervalMs, 100, 1000, true)
        or not W.Number(config.maxCatchUpSteps, 1, 128, true)
        or not W.Number(config.maxOverrides, 1, 32, true)
        or not W.Number(config.maxOverrideSeconds, 1, 3600, true) then return false end
    if type(config.trustedResources) ~= 'table' or type(config.overrideOwners) ~= 'table'
        or type(config.conflictResources) ~= 'table' then return false end
    local function resourceName(name) return type(name) == 'string' and #name > 0 and #name <= 100 end
    for name, enabled in pairs(config.trustedResources) do
        if not resourceName(name) or type(enabled) ~= 'boolean' then return false end
    end
    for name, policy in pairs(config.overrideOwners) do
        if not resourceName(name) or not W.Fields(policy, { maxPriority=true })
            or not W.Number(policy.maxPriority, 0, 100, true) then return false end
    end
    local count = 0
    for index, name in pairs(config.conflictResources) do
        if not W.Number(index, 1, 32, true) or not resourceName(name) or name == 'feather-weather' then return false end
        count = count + 1
    end
    return count == #config.conflictResources
end
function W.Rate(clock) return clock.mode == 'wall' and 1 or clock.rate end
function W.Elapsed(now, before) return (now - before) % 4294967296 end
function W.TimeParts(seconds)
    seconds = math.floor(seconds) % W.WEEK
    return math.floor(seconds / 86400), math.floor(seconds / 3600) % 24,
        math.floor(seconds / 60) % 60, seconds % 60
end

function W.Snapshot(value)
    return W.Fields(value, { epoch=true, revision=true, clock=true, weather=true, wind=true,
        transitionId=true, transitionRemainingSeconds=true, scheduleGeneration=true, catchUpResets=true,
        season=true,windControl=true,windMotion=true })
        and type(value.epoch) == 'string' and #value.epoch > 0 and #value.epoch <= 100
        and W.Number(value.revision, 1, 9007199254740991, true)
        and W.Clock(value.clock) and W.Weather(value.weather) and W.Wind(value.wind)
        and W.Number(value.transitionId, 1, 9007199254740991, true)
        and W.Number(value.transitionRemainingSeconds, 0, 300)
        and W.Number(value.scheduleGeneration, 1, 9007199254740991, true)
        and W.Number(value.catchUpResets, 0, 9007199254740991, true)
        and (value.season==nil or W.SeasonState(value.season))
        and (value.windControl==nil or W.WindControl(value.windControl))
        and (value.windMotion==nil or W.WindMotion(value.windMotion))
end
