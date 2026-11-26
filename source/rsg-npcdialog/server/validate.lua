-- Turns any NPC definition (config, export, editor JSON) into a clean, safe table.
-- Used for every source, so the rest of the server can trust the shape.
Validate = {}

local MONEY = { cash = true, bank = true, gold = true, bloodmoney = true }
local MAX_NODES, MAX_CHOICES, MAX_OBJECTIVES = 100, 9, 10
local QUEST_STATES = { available = true, active = true, ready = true, completed = true, notcompleted = true }
local OBJECTIVES = { deliver = true, visit = true, talk = true, kill = true, custom = true }

local function fail(msg) error({ msg = msg }, 0) end

local function str(v, what, max, optional)
    if v == nil or v == '' then
        if optional then return nil end
        fail(what .. ' is required')
    end
    if type(v) ~= 'string' or #v > max then fail(what .. ' must be text up to ' .. max .. ' bytes') end
    return v
end

local function ident(v, what, optional)
    v = str(v, what, 50, optional)
    if v and not v:match('^[%w_%-]+$') then fail(what .. ' may only use letters, numbers, _ and -') end
    return v
end

local function num(v, what, min, max)
    v = tonumber(v)
    if not v or v ~= v or v < min or v > max then fail(('%s must be a number from %s to %s'):format(what, min, max)) end
    return v
end

local function int(v, what, min, max)
    v = num(v, what, min, max)
    if v % 1 ~= 0 then fail(what .. ' must be a whole number') end
    return math.floor(v)
end

local function list(v, what)
    if v == nil then return {} end
    if type(v) ~= 'table' then fail(what .. ' must be a list') end
    local count = 0
    for _ in pairs(v) do count = count + 1 end
    if count ~= #v or count > 30 then fail(what .. ' must be a list of up to 30 entries') end
    return v
end

local function map(v, what, fn)
    local out = {}
    for _, e in ipairs(list(v, what)) do
        if type(e) ~= 'table' then fail(what .. ' has a bad entry') end
        out[#out + 1] = fn(e)
    end
    return #out > 0 and out or nil
end

local function flags(v, what)
    local out = {}
    for _, f in ipairs(list(v, what)) do out[#out + 1] = ident(f, what) end
    return #out > 0 and out or nil
end

local function items(v, what)
    return map(v, what, function(e)
        return { name = ident(e.name, what .. ' item'), amount = int(e.amount or 1, what .. ' amount', 1, Config.Limits.items) }
    end)
end

local function money(v, what)
    return map(v, what, function(e)
        if not MONEY[e.type] then fail(what .. ': unknown money type') end
        local amount = num(e.amount, what .. ' amount', 0.01, Config.Limits.money)
        return { type = e.type, amount = math.floor(amount * 100 + 0.5) / 100 }
    end)
end

-- { job_name = minGrade }
local function grades(v, what)
    if v == nil then return nil end
    if type(v) ~= 'table' then fail(what .. ' must be a table') end
    local out
    for name, grade in pairs(v) do
        out = out or {}
        out[ident(name, what)] = int(grade, what .. ' grade', 0, 100)
    end
    return out
end

local WEATHERS = {}
for _, w in ipairs(World.Weathers) do WEATHERS[w] = true end

-- { from, to } in-game hours
local function hours(v, what)
    return {
        from = int(v.from, what .. ' from hour', 0, 23),
        to = int(v.to, what .. ' to hour', 0, 24) % 24,
    }
end

local function position(c, what)
    return {
        x = num(c.x, what .. ' x', -20000, 20000), y = num(c.y, what .. ' y', -20000, 20000),
        z = num(c.z, what .. ' z', -500, 3000), w = num(c.w or 0.0, what .. ' heading', -360, 360),
    }
end

local function requirements(r)
    if r == nil then return nil end
    if type(r) ~= 'table' then fail('requires must be a table') end
    local out = {
        job = grades(r.job, 'job'),
        gang = grades(r.gang, 'gang'),
        onduty = r.onduty == true or nil,
        items = items(r.items, 'required item'),
        money = money(r.money, 'required money'),
        anyJob = grades(r.anyJob, 'any job'),
        quests = map(r.quests, 'quest requirement', function(e)
            if not QUEST_STATES[e.state] then fail('quest requirement: unknown state') end
            return { id = ident(e.id, 'quest id'), state = e.state }
        end),
        flags = flags(r.flags, 'required flag'),
        notFlags = flags(r.notFlags, 'blocking flag'),
        skills = map(r.skills, 'skill requirement', function(e)
            return { skill = ident(e.skill, 'skill'), level = int(e.level, 'skill level', 1, 1000) }
        end),
        standing = map(r.standing, 'standing requirement', function(e)
            return {
                region = ident(e.region, 'region'),
                min = e.min ~= nil and num(e.min, 'standing min', -100000, 100000) or nil,
                max = e.max ~= nil and num(e.max, 'standing max', -100000, 100000) or nil,
            }
        end),
        weather = (function()
            local out = {}
            for _, w in ipairs(list(r.weather, 'weather')) do
                if not WEATHERS[w] then fail('weather: unknown type') end
                out[#out + 1] = w
            end
            return #out > 0 and out or nil
        end)(),
        custom = map(r.custom, 'custom condition', function(e)
            return { name = ident(e.name, 'condition name'), arg = str(e.arg, 'condition arg', 100, true) }
        end),
    }
    if r.time ~= nil then
        if type(r.time) ~= 'table' then fail('time must be a table') end
        out.time = hours(r.time, 'time')
    end
    if type(r.honor) == 'table' and (r.honor.min ~= nil or r.honor.max ~= nil) then
        out.honor = {
            min = r.honor.min ~= nil and num(r.honor.min, 'honor min', -100000, 100000) or nil,
            max = r.honor.max ~= nil and num(r.honor.max, 'honor max', -100000, 100000) or nil,
        }
    end
    return next(out) and out or nil
end

local function cost(c)
    if c == nil then return nil end
    if type(c) ~= 'table' then fail('cost must be a table') end
    local out = { money = money(c.money, 'cost'), items = items(c.items, 'cost') }
    return next(out) and out or nil
end

local function reward(r)
    if r == nil then return nil end
    if type(r) ~= 'table' then fail('reward must be a table') end
    local lim = Config.Limits
    local out = {
        money = money(r.money, 'reward'),
        items = items(r.items, 'reward'),
        skillXP = map(r.skillXP, 'skill XP', function(e)
            return { skill = ident(e.skill, 'skill'), amount = int(e.amount, 'XP', 1, lim.xp) }
        end),
        standing = map(r.standing, 'standing change', function(e)
            return { region = ident(e.region, 'region'), amount = int(e.amount, 'standing change', -lim.rep, lim.rep) }
        end),
    }
    if r.honor ~= nil and tonumber(r.honor) ~= 0 then out.honor = int(r.honor, 'honor change', -lim.rep, lim.rep) end
    return next(out) and out or nil
end

local function choice(c, i, nodes, where)
    if type(c) ~= 'table' then fail(where .. ': bad choice') end
    local out = {
        id = ident(c.id, where .. ' choice id', true),
        label = str(c.label, where .. ' choice text', 300),
        next = ident(c.next, where .. ' next', true),
        lock = c.lock == 'show' and 'show' or 'hide',
        once = c.once == true or nil,
        cooldown = (c.cooldown ~= nil and tonumber(c.cooldown) ~= 0) and int(c.cooldown, where .. ' cooldown', 1, 31536000) or nil,
        repeatable = c.repeatable == true or nil,
        requires = requirements(c.requires),
        cost = cost(c.cost),
        reward = reward(c.reward),
        setFlags = flags(c.setFlags, 'set flag'),
        clearFlags = flags(c.clearFlags, 'clear flag'),
        action = ident(c.action, where .. ' action', true),
        startQuest = ident(c.startQuest, where .. ' start quest', true),
        turnInQuest = ident(c.turnInQuest, where .. ' turn in quest', true),
    }
    if out.startQuest and out.turnInQuest then fail(where .. ': a choice cannot both start and turn in a quest') end
    if (out.once or out.cooldown) and not out.id then fail(where .. ': once/cooldown choices need an id') end
    -- stops a reward being farmed by accident
    -- (a turn-in is already limited by the quest's own repeat rules)
    if out.reward and not (out.once or out.cooldown or out.repeatable or out.turnInQuest) then
        fail(where .. ': a choice with a reward needs "once", a cooldown, or "repeatable"')
    end
    if out.next and type(nodes[out.next]) ~= 'table' then fail(where .. ': next node "' .. out.next .. '" does not exist') end
    out.id = out.id or ('c' .. i)
    return out
end

local function build(def)
    if type(def) ~= 'table' then fail('NPC must be a table') end
    local c = def.coords
    if type(c) ~= 'table' and type(c) ~= 'vector4' then fail('coords are required') end

    local out = {
        id = ident(def.id, 'id'),
        enabled = def.enabled ~= false,
        name = str(def.name, 'name', 100),
        title = str(def.title, 'title', 100, true),
        model = ident(def.model, 'model'),
        coords = position(c, 'coords'),
        scenario = ident(def.scenario, 'scenario', true),
        distance = num(def.distance or Config.InteractDistance, 'distance', 1.0, 10.0),
        start = ident(def.start, 'start node'),
        requires = requirements(def.requires),
    }
    if type(def.blip) == 'table' and def.blip.enabled then
        out.blip = { enabled = true, sprite = ident(def.blip.sprite or 'blip_ambient_npc', 'blip sprite') }
    end

    local schedule = list(def.schedule, 'schedule')
    if #schedule > 8 then fail('schedule: at most 8 time slots') end
    out.schedule = map(schedule, 'schedule', function(e)
        local slot = hours(e, 'schedule')
        if e.coords ~= nil then
            if type(e.coords) ~= 'table' and type(e.coords) ~= 'vector4' then fail('schedule: bad coords') end
            slot.coords = position(e.coords, 'schedule')
        end
        slot.scenario = ident(e.scenario, 'schedule scenario', true)
        return slot
    end)

    if type(def.nodes) ~= 'table' then fail('nodes are required') end
    out.nodes = {}
    local count = 0
    for key, node in pairs(def.nodes) do
        count = count + 1
        if count > MAX_NODES then fail('too many nodes') end
        ident(key, 'node id')
        if type(node) ~= 'table' then fail('node ' .. key .. ' is invalid') end
        local choices, seen = {}, {}
        local raw = list(node.choices, 'choices')
        if #raw > MAX_CHOICES then fail(key .. ': at most ' .. MAX_CHOICES .. ' choices') end
        for i, ch in ipairs(raw) do
            local clean = choice(ch, i, def.nodes, key)
            if seen[clean.id] then fail(key .. ': duplicate choice id ' .. clean.id) end
            seen[clean.id] = true
            choices[i] = clean
        end
        out.nodes[key] = { text = str(node.text, key .. ' text', 2000), choices = choices }
    end

    if not out.nodes[out.start] then fail('start node does not exist') end
    out.starts = map(def.starts, 'alternative start', function(e)
        local node = ident(e.node, 'start node')
        if not out.nodes[node] then fail('alternative start node "' .. node .. '" does not exist') end
        return { node = node, requires = requirements(e.requires) }
    end)
    return out
end

local function objective(o, seen)
    if type(o) ~= 'table' or not OBJECTIVES[o.type] then fail('objective: unknown type') end
    local out = { id = ident(o.id, 'objective id'), type = o.type, label = str(o.label, 'objective text', 200) }
    local where = 'objective ' .. out.id
    if seen[out.id] then fail(where .. ': duplicate id') end
    seen[out.id] = true
    -- visit and talk happen once: a talk count could be farmed by repeating the same conversation
    out.count = (o.type == 'visit' or o.type == 'talk') and 1 or int(o.count or 1, where .. ' count', 1, 1000)

    if o.type == 'deliver' then
        out.item = ident(o.item, where .. ' item')
    elseif o.type == 'visit' then
        local c = o.coords
        if type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' then fail(where .. ': coords are required') end
        out.coords = { x = num(c.x, 'x', -20000, 20000), y = num(c.y, 'y', -20000, 20000), z = num(c.z, 'z', -500, 3000) }
        out.radius = num(o.radius or 5.0, where .. ' radius', 1.0, 200.0)
        out.blip = o.blip ~= false
    elseif o.type == 'talk' then
        out.npc = ident(o.npc, where .. ' NPC')
        out.node = ident(o.node, where .. ' line', true)
        out.choice = ident(o.choice, where .. ' reply id', true)
        if out.choice and not out.node then fail(where .. ': a reply id also needs its line id') end
    elseif o.type == 'kill' then
        local models = {}
        for _, m in ipairs(list(o.models, where .. ' models')) do models[#models + 1] = ident(m, where .. ' model') end
        if #models == 0 then fail(where .. ': at least one ped model is required') end
        out.models = models
    end
    return out
end

local function buildQuest(def)
    if type(def) ~= 'table' then fail('quest must be a table') end
    local out = {
        id = ident(def.id, 'id'),
        enabled = def.enabled ~= false,
        name = str(def.name, 'name', 100),
        description = str(def.description, 'description', 1000, true),
        ordered = def.ordered == true,
        autoComplete = def.autoComplete == true,
        repeatable = def.repeatable == true,
        requires = requirements(def.requires),
        reward = reward(def.reward),
    }
    if def.reset ~= nil and def.reset ~= '' then
        if def.reset ~= 'daily' and def.reset ~= 'weekly' then fail('reset must be daily or weekly') end
        if not out.repeatable then fail('daily and weekly quests must be repeatable') end
        out.reset = def.reset
    end
    out.pool = ident(def.pool, 'pool', true)
    if out.pool and not out.reset then fail('a quest in a pool needs a daily or weekly reset') end
    if out.repeatable and not out.reset then
        local least = Config.Quests.MinRepeatCooldown
        out.cooldown = int(def.cooldown or 0, 'repeat cooldown (seconds)', least, 31536000)
    end
    local raw = list(def.objectives, 'objectives')
    if #raw == 0 or #raw > MAX_OBJECTIVES then fail('a quest needs 1 to ' .. MAX_OBJECTIVES .. ' objectives') end
    local seen = {}
    out.objectives = {}
    for i, o in ipairs(raw) do
        out.objectives[i] = objective(o, seen)
        if out.autoComplete and o.type == 'deliver' then
            fail('quests with deliver objectives must be turned in to an NPC (turn off auto complete)')
        end
    end
    return out
end

local function run(fn, def)
    local ok, res = pcall(fn, def)
    if ok then return res end
    return nil, type(res) == 'table' and res.msg or tostring(res)
end

---@return table|nil npc, string|nil err
function Validate.NPC(def) return run(build, def) end

---@return table|nil quest, string|nil err
function Validate.Quest(def) return run(buildQuest, def) end
