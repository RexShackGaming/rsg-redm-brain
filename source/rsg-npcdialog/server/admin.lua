-- In-game editor (server side). Every request re-checks permission.
local RSGCore = exports['rsg-core']:GetCoreObject()

local function allowed(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function log(src, text)
    TriggerEvent('rsg-log:server:CreateLog', 'default', 'NPC Dialog', 'orange',
        ('%s (id %s) %s'):format(GetPlayerName(src) or '?', src, text))
end

-- fits the VARCHAR(50) column without cutting a multi-byte character in half
local function editorName(src)
    local name = GetPlayerName(src) or '?'
    local length = utf8.len(name)
    if not length then return (name:gsub('[\128-\255]', '')):sub(1, 50) end
    if length > 50 then return name:sub(1, utf8.offset(name, 51) - 1) end
    return name
end

-------------------------------------------------
-- lists for the editor dropdowns (empty list = not available, so not checked)
-------------------------------------------------
local function optional(resource, fn)
    if GetResourceState(resource) ~= 'started' then return {} end
    local ok, res = pcall(fn)
    return ok and type(res) == 'table' and res or {}
end

local function pairsList(t, label)
    local out = {}
    for key, v in pairs(t or {}) do
        out[#out + 1] = { tostring(key), type(v) == 'table' and label(v, key) or tostring(key) }
    end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    return out
end

local function lookups()
    local byLabel = function(v, k) return v.label or tostring(k) end
    local skills = {}
    for _, s in ipairs(optional('rsg-skills', function() return exports['rsg-skills']:GetSkillDefinitions() end)) do
        skills[#skills + 1] = { s.key, s.label or s.key }
    end
    local _, jobs = pcall(function() return exports['rsg-core']:GetJobDefinitions() end)
    return {
        item = pairsList(RSGCore.Shared.Items, byLabel),
        job = pairsList(type(jobs) == 'table' and jobs or {}, byLabel),
        gang = pairsList(RSGCore.Shared.Gangs, byLabel),
        skill = skills,
        weather = (function()
            local out = {}
            for _, w in ipairs(World.Weathers) do out[#out + 1] = { w, w } end
            return out
        end)(),
        region = pairsList(optional('rsg-reputation', function() return exports['rsg-reputation']:GetRegions() end), byLabel),
    }
end

-- text for '@key' strings, so the preview can show real wording
local function collectLocale(v, out)
    if type(v) == 'string' then
        if v:sub(1, 1) == '@' then out[v] = locale(v:sub(2)) end
    elseif type(v) == 'table' then
        for _, x in pairs(v) do collectLocale(x, out) end
    end
end

local function entries(registry)
    local out = {}
    for _, e in pairs(registry) do
        out[#out + 1] = { source = e.source, owner = e.owner, def = e.def }
    end
    table.sort(out, function(a, b) return a.def.id < b.def.id end)
    return out
end

local function editorData(withLookups)
    local data = { npcs = entries(NPCs), quests = entries(Quests.List), actions = ActionNames(), conditions = {}, strings = {} }
    for name in pairs(Engine.Conditions) do data.conditions[#data.conditions + 1] = { name, name } end
    collectLocale(data.npcs, data.strings)
    collectLocale(data.quests, data.strings)
    if withLookups then data.lookups = lookups() end
    return data
end

-------------------------------------------------
-- reference checks, so typos are caught while the admin is looking at the form
-------------------------------------------------
local function checker()
    local sets = {}
    for kind, entriesList in pairs(lookups()) do
        if #entriesList > 0 then
            sets[kind] = {}
            for _, e in ipairs(entriesList) do sets[kind][e[1]] = true end
        end
    end
    return function(kind, value)
        if kind == 'item' then return RSGCore.Shared.Items[value] ~= nil end
        return not sets[kind] or sets[kind][value] == true
    end
end

---@return string|nil err
local function checkBlocks(known, where, req, cost, rew, selfQuest)
    local function bad(kind, value) return where .. ': ' .. locale('adm_unknown', kind, value) end
    req, cost, rew = req or {}, cost or {}, rew or {}
    for _, group in ipairs({ req.items or {}, cost.items or {}, rew.items or {} }) do
        for _, it in ipairs(group) do
            if not known('item', it.name) then return bad('item', it.name) end
        end
    end
    for _, pair in ipairs({ { 'job', req.job }, { 'job', req.anyJob }, { 'gang', req.gang } }) do
        for name in pairs(pair[2] or {}) do
            if not known(pair[1], name) then return bad(pair[1], name) end
        end
    end
    for _, group in ipairs({ req.skills or {}, rew.skillXP or {} }) do
        for _, s in ipairs(group) do
            if not known('skill', s.skill) then return bad('skill', s.skill) end
        end
    end
    for _, group in ipairs({ req.standing or {}, rew.standing or {} }) do
        for _, s in ipairs(group) do
            if not known('region', s.region) then return bad('region', s.region) end
        end
    end
    for _, q in ipairs(req.quests or {}) do
        if not Quests.List[q.id] and q.id ~= selfQuest then return bad('quest', q.id) end
    end
end

local function checkNPC(def)
    local known = checker()
    local err = checkBlocks(known, def.id, def.requires)
    for _, s in ipairs(def.starts or {}) do err = err or checkBlocks(known, s.node, s.requires) end
    for nodeId, node in pairs(def.nodes) do
        for _, c in ipairs(node.choices) do
            err = err or checkBlocks(known, nodeId, c.requires, c.cost, c.reward)
            if c.action and not ActionExists(c.action) then err = err or locale('adm_unknown_action', c.action) end
            for _, q in ipairs({ c.startQuest or false, c.turnInQuest or false }) do
                if q and not Quests.List[q] then err = err or (nodeId .. ': ' .. locale('adm_unknown', 'quest', q)) end
            end
        end
    end
    return err
end

local function checkQuest(def)
    local known = checker()
    local err = checkBlocks(known, def.id, def.requires, nil, def.reward, def.id)
    for _, o in ipairs(def.objectives) do
        if o.item and not known('item', o.item) then err = err or (o.id .. ': ' .. locale('adm_unknown', 'item', o.item)) end
        if o.type == 'talk' then
            local npc = NPCs[o.npc]
            local node = npc and o.node and npc.def.nodes[o.node]
            local found = npc ~= nil and (not o.node or node ~= nil)
            if found and o.choice then
                found = false
                for _, c in ipairs(node.choices) do
                    if c.id == o.choice then found = true end
                end
            end
            if not found then err = err or (o.id .. ': ' .. locale('adm_unknown', 'npc / node / reply', o.npc)) end
        end
    end
    return err
end

-- what differs between the two editable things
local KINDS = {
    npc = {
        registry = function() return NPCs end, validate = Validate.NPC, check = checkNPC,
        save = function(...) return DB.SaveNPC(...) end, delete = function(id) return DB.DeleteNPC(id) end,
        add = function(def) return AddNPC(def, 'db') end, remove = function(id) return RemoveNPCById(id) end,
    },
    quest = {
        registry = function() return Quests.List end, validate = Validate.Quest, check = checkQuest,
        save = function(...) return DB.SaveQuest(...) end, delete = function(id) return DB.DeleteQuest(id) end,
        add = function(def) return Quests.Add(def, 'db') end, remove = function(id) return Quests.Remove(id) end,
    },
}

RSGCore.Commands.Add(Config.AdminCommand, locale('cmd_help'), {}, false, function(source)
    if source == 0 then return end
    TriggerClientEvent('rsg-npcdialog:client:openEditor', source)
end, Config.AdminPermission)

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:canEdit', function(source, cb)
    cb(allowed(source))
end)

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:editorData', function(source, cb)
    if not allowed(source) then return cb(nil) end
    cb(editorData(true))
end)

-- sent as a JSON string so lists and numeric keys arrive exactly as written
RSGCore.Functions.CreateCallback('rsg-npcdialog:server:save', function(source, cb, kindName, payload, isNew)
    local src = source
    if not allowed(src) then return cb({ ok = false, error = locale('adm_no_permission') }) end
    local kind = type(kindName) == 'string' and rawget(KINDS, kindName)
    if not kind then return cb({ ok = false, error = locale('sv_failed') }) end
    if not DB.ready then return cb({ ok = false, error = locale('adm_db_not_ready') }) end
    if type(payload) ~= 'string' or #payload > 200000 then return cb({ ok = false, error = locale('adm_too_big') }) end
    local decoded, def = pcall(json.decode, payload)
    if not decoded then return cb({ ok = false, error = 'bad JSON' }) end

    local clean, err = kind.validate(def)
    if not clean then return cb({ ok = false, error = err }) end
    local existing = kind.registry()[clean.id]
    if existing and (isNew or existing.source ~= 'db') then
        return cb({ ok = false, error = locale('adm_id_taken') })
    end
    local problem = kind.check(clean)
    if problem then return cb({ ok = false, error = problem }) end

    local saved, saveErr = pcall(kind.save, clean.id, clean, editorName(src))
    if not saved then
        print('^1[rsg-npcdialog] save failed: ' .. tostring(saveErr) .. '^7')
        return cb({ ok = false, error = locale('sv_failed') })
    end
    local ok, addErr = kind.add(clean)
    if not ok then return cb({ ok = false, error = addErr }) end
    log(src, ('saved %s %s'):format(kindName, clean.id))
    cb({ ok = true, data = editorData(false), id = clean.id })
end)

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:delete', function(source, cb, kindName, id)
    if not allowed(source) then return cb({ ok = false, error = locale('adm_no_permission') }) end
    local kind = type(kindName) == 'string' and rawget(KINDS, kindName)
    local e = kind and type(id) == 'string' and kind.registry()[id]
    if not e or e.source ~= 'db' then return cb({ ok = false, error = locale('adm_read_only') }) end
    if not DB.ready or not pcall(kind.delete, id) then return cb({ ok = false, error = locale('sv_failed') }) end
    kind.remove(id)
    log(source, ('deleted %s %s'):format(kindName, id))
    cb({ ok = true, data = editorData(false) })
end)
