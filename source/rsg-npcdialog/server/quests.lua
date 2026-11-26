-- Quest registry, progress and rewards. All progress is decided here.
Quests = { List = {} } -- id -> { def, source = 'config'|'db'|'export', owner }

local RSGCore = exports['rsg-core']:GetCoreObject()
local killed = {}      -- entity -> true : a body only ever counts once
local lastKill = {}    -- src -> game timer
local lastRequest = {} -- src -> game timer : journal data requests
local blocked = {}     -- cid .. quest -> true : auto-complete already told the player it is stuck
local completing = {}  -- cid .. quest -> true : a payout is running
local depth = setmetatable({}, { __mode = 'k' }) -- coroutine -> nested quest requirement checks

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('quest_title'), description = desc, type = ntype or 'inform', duration = 6000,
    })
end

local function text(s)
    if type(s) == 'string' and s:sub(1, 1) == '@' then return locale(s:sub(2)) end
    return s
end

local function getPlayer(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    return Player, Player.PlayerData.citizenid
end

local function def(id)
    local e = Quests.List[id]
    return e and e.def.enabled and e.def or nil
end

-------------------------------------------------
-- registry
-------------------------------------------------
function Quests.Add(raw, source, owner)
    local clean, err = Validate.Quest(raw)
    if not clean then return false, err end
    local existing = Quests.List[clean.id]
    if existing and (existing.source ~= source or existing.owner ~= owner) then
        return false, ('id "%s" is already used by %s'):format(clean.id, existing.owner or existing.source)
    end
    Quests.List[clean.id] = { def = clean, source = source, owner = owner }
    Quests.SyncAll()
    return true, clean.id
end

function Quests.Remove(id)
    if not Quests.List[id] then return false end
    Quests.List[id] = nil -- saved progress is kept in case the quest comes back
    Quests.SyncAll()
    return true
end

-------------------------------------------------
-- state helpers
-------------------------------------------------
local function countOf(src, state, o)
    if o.type == 'deliver' then -- what the player is carrying right now
        return math.min(o.count, exports['rsg-inventory']:GetItemCount(src, o.item) or 0)
    end
    return math.min(o.count, tonumber(state.progress[o.id]) or 0)
end

-- every objective met? (deliver = the items are in the inventory)
local function isReady(src, q, state)
    local need = {}
    for _, o in ipairs(q.objectives) do
        if o.type == 'deliver' then
            need[o.item] = (need[o.item] or 0) + o.count
        elseif countOf(src, state, o) < o.count then
            return false
        end
    end
    for item, amount in pairs(need) do
        if (exports['rsg-inventory']:GetItemCount(src, item) or 0) < amount then return false end
    end
    return true
end

-- in ordered quests only the first unfinished objective can progress
local function isOpen(src, q, state, index)
    if not q.ordered then return true end
    for i = 1, index - 1 do
        local o = q.objectives[i]
        if countOf(src, state, o) < o.count then return false end
    end
    return true
end

local function activeCount(states)
    local n = 0
    for id, s in pairs(states) do
        if s.active and def(id) then n = n + 1 end
    end
    return n
end

-- is this quest one of the pool's picks for the current day / week?
local function picked(id, q)
    local period = World.Period(q.reset, os.time())
    local function rank(questId) return World.Hash(('%s|%d|%s'):format(q.pool, period, questId)) end
    local mine, ahead = rank(id), 0
    for otherId in pairs(Quests.List) do
        local other = otherId ~= id and def(otherId)
        if other and other.pool == q.pool and other.reset == q.reset then
            local theirs = rank(otherId)
            if theirs < mine or (theirs == mine and otherId < id) then ahead = ahead + 1 end
        end
    end
    return ahead < (Config.Quests.Pools[q.pool] or 1)
end

-- unix time a finished repeatable quest can be taken again
local function availableAt(q, state)
    local done = state.completedAt or 0
    if q.reset then
        if World.Period(q.reset, done) < World.Period(q.reset, os.time()) then return 0 end
        return World.NextReset(q.reset, os.time())
    end
    return done + q.cooldown
end

---@return string|nil 'available' | 'active' | 'ready' | 'completed' | 'cooldown' | 'locked'  (nil = unknown quest or not loaded)
function Quests.State(src, Player, progress, id)
    local q = def(id)
    if not q then return nil end
    local states = DB.QuestStates(Player.PlayerData.citizenid)
    if not states then return nil end
    local s = states[id]
    if s and s.active then return isReady(src, q, s) and 'ready' or 'active' end
    if s and (s.times or 0) > 0 then
        if not q.repeatable then return 'completed' end
        if os.time() < availableAt(q, s) then return 'cooldown' end
    end
    if q.pool and not picked(id, q) then return 'locked' end
    -- quest requirements are not allowed to depend on themselves
    if q.requires then
        for _, r in ipairs(q.requires.quests or {}) do
            if r.id == id then return 'locked' end
        end
        -- counted per thread: a custom condition may yield while other players are being checked
        local thread = coroutine.running()
        local level = depth[thread] or 0
        if level > 5 then return 'locked' end
        depth[thread] = level + 1
        local ok = Engine.Meets(src, Player, progress, q.requires)
        depth[thread] = level > 0 and level or nil
        if not ok then return 'locked' end
    end
    return 'available'
end

function Quests.EverCompleted(Player, id)
    local states = DB.QuestStates(Player.PlayerData.citizenid)
    local s = states and states[id]
    if not states then return true end -- not loaded: fail closed for "not completed" rules
    return s ~= nil and (s.times or 0) > 0
end

-------------------------------------------------
-- client mirror (journal, tracker, blips, kill watch)
-------------------------------------------------
-- where a GPS route for this quest should lead, or nil when there is no one place
local function routeTarget(src, id, q, state, ready)
    if ready and not q.autoComplete then
        local npc = TurnInNPC(id)
        return npc and NPCPosition(npc)
    end
    for i, o in ipairs(q.objectives) do
        if isOpen(src, q, state, i) and countOf(src, state, o) < o.count then
            -- hidden visit places (blip = false) are never given away
            if o.type == 'visit' and o.blip then return o.coords end
            if o.type == 'talk' then
                local position = NPCPosition(o.npc)
                if position then return position end
            end
        end
    end
    return nil
end

function Quests.View(src)
    local Player, cid = getPlayer(src)
    if not Player then return nil end
    local states = DB.QuestStates(cid)
    if not states then return nil end
    local out = { active = {}, completed = {} }
    for id, s in pairs(states) do
        local q = def(id)
        if q and s.active then
            local objectives = {}
            for i, o in ipairs(q.objectives) do
                local n = countOf(src, s, o)
                local open = isOpen(src, q, s, i)
                objectives[i] = {
                    id = o.id, type = o.type, label = o.label, current = n, count = o.count, done = n >= o.count, open = open,
                    coords = (open and o.blip and n < o.count) and o.coords or nil,
                    models = (open and o.type == 'kill' and n < o.count) and o.models or nil,
                }
            end
            local ready = isReady(src, q, s)
            out.active[#out.active + 1] = {
                id = id, name = q.name, description = q.description, started = s.started or 0, reset = q.reset,
                ready = ready, autoComplete = q.autoComplete, objectives = objectives,
                target = routeTarget(src, id, q, s, ready),
            }
        end
        if q and (s.times or 0) > 0 then
            out.completed[#out.completed + 1] = { id = id, name = q.name, times = s.times }
        end
    end
    table.sort(out.active, function(a, b)
        if a.started ~= b.started then return a.started < b.started end
        return a.id < b.id
    end)
    table.sort(out.completed, function(a, b) return a.id < b.id end)
    return out
end

local lastSent = {}
function Quests.Sync(src, force)
    local view = Quests.View(src)
    if not view then return end
    local encoded = json.encode(view)
    if not force and lastSent[src] == encoded then return end
    lastSent[src] = encoded
    TriggerClientEvent('rsg-npcdialog:client:quests', src, view)
    QueueMarkers(src)
end

local syncQueued = false
function Quests.SyncAll()
    if syncQueued then return end
    syncQueued = true
    SetTimeout(500, function()
        syncQueued = false
        for _, id in ipairs(GetPlayers()) do Quests.Sync(tonumber(id)) end
    end)
end

-------------------------------------------------
-- start / abandon / complete
-------------------------------------------------
---@return boolean ok, string|nil reason
function Quests.CanStart(src, Player, progress, id)
    local state = Quests.State(src, Player, progress, id)
    if state == 'cooldown' then
        local s = DB.QuestStates(Player.PlayerData.citizenid)[id]
        return false, World.WaitText(availableAt(def(id), s) - os.time())
    end
    if state ~= 'available' then return false, locale('req_unavailable') end
    if activeCount(DB.QuestStates(Player.PlayerData.citizenid)) >= Config.Quests.MaxActive then
        return false, locale('quest_too_many')
    end
    return true
end

---@return boolean ok, string|nil reason
function Quests.Start(src, id)
    local Player, cid = getPlayer(src)
    if not Player then return false end
    local progress = DB.Progress(cid)
    if not progress then return false, locale('sv_failed') end
    local ok, why = Quests.CanStart(src, Player, progress, id)
    if not ok then return false, why end
    local old = DB.QuestStates(cid)[id]
    DB.SaveQuestState(cid, id, {
        active = true, progress = {}, started = os.time(),
        times = old and old.times or 0, completedAt = old and old.completedAt or 0,
    })
    blocked[cid .. id] = nil
    notify(src, locale('quest_started', text(def(id).name)), 'inform')
    TriggerEvent('rsg-npcdialog:server:questStarted', src, id)
    Quests.Sync(src)
    return true
end

function Quests.Abandon(src, id)
    local Player, cid = getPlayer(src)
    local states = Player and DB.QuestStates(cid)
    local s = states and states[id]
    if not s or not s.active then return false end
    if (s.times or 0) > 0 then
        -- keep the history so abandoning can never skip a repeat cooldown
        DB.SaveQuestState(cid, id, { active = false, progress = {}, times = s.times, completedAt = s.completedAt })
    else
        DB.SaveQuestState(cid, id, nil)
    end
    TriggerEvent('rsg-npcdialog:server:questAbandoned', src, id)
    Quests.Sync(src)
    return true
end

-- the deliver items of a quest as a transaction cost
local function deliveryCost(q)
    local items = {}
    for _, o in ipairs(q.objectives) do
        if o.type == 'deliver' then items[#items + 1] = { name = o.item, amount = o.count } end
    end
    return items
end

local function join(a, b)
    local out = {}
    for _, v in ipairs(a or {}) do out[#out + 1] = v end
    for _, v in ipairs(b or {}) do out[#out + 1] = v end
    return out
end

---Hands in a ready quest, optionally together with a reply's own cost and reward, as one transaction.
---@return boolean ok, string|nil reason
local function complete(src, id, extraCost, extraReward)
    local Player, cid = getPlayer(src)
    if not Player then return false end
    local q = def(id)
    local states = DB.QuestStates(cid)
    local s = states and states[id]
    if not q or not s or not s.active or not isReady(src, q, s) then return false, locale('quest_not_ready') end

    extraCost, extraReward = extraCost or {}, extraReward or {}
    local questReward = q.reward or {}
    local ok, why = Engine.Transact(src, Player,
        { money = extraCost.money, items = join(extraCost.items, deliveryCost(q)) },
        { money = join(questReward.money, extraReward.money), items = join(questReward.items, extraReward.items) },
        'rsg-npcdialog:quest-' .. id)
    if not ok then return false, why end

    -- marked done before anything that could yield
    DB.SaveQuestState(cid, id, { active = false, progress = {}, times = (s.times or 0) + 1, completedAt = os.time() })
    notify(src, locale('quest_completed', text(q.name)), 'success')
    Engine.Progression(src, q.reward, 'rsg-npcdialog:quest-' .. id)
    TriggerEvent('rsg-npcdialog:server:questCompleted', src, id)
    Quests.Sync(src)
    return true
end

---@return boolean ok, string|nil reason
function Quests.Complete(src, id, extraCost, extraReward)
    local _, cid = getPlayer(src)
    if not cid or type(id) ~= 'string' then return false end
    -- paying out fires money and item events: a handler must not be able to hand the same quest in again
    local lock = cid .. id
    if completing[lock] then return false, locale('quest_not_ready') end
    completing[lock] = true
    local called, ok, why = pcall(complete, src, id, extraCost, extraReward)
    completing[lock] = nil
    if not called then
        print('^1[rsg-npcdialog] quest completion failed: ' .. tostring(ok) .. '^7')
        return false, locale('sv_failed')
    end
    return ok, why
end

local function tryAutoComplete(src, cid, id)
    local q = def(id)
    local s = (DB.QuestStates(cid) or {})[id]
    if not q or not q.autoComplete or not s or not s.active or not isReady(src, q, s) then return end
    local ok, why = Quests.Complete(src, id)
    if not ok and not blocked[cid .. id] then
        blocked[cid .. id] = true
        notify(src, why or locale('sv_failed'), 'error') -- retried by the tick until there is room
    end
end

-------------------------------------------------
-- progress
-------------------------------------------------
-- calls match(objective) for every open objective of every active quest and adds what it returns
local function advance(src, match, once)
    local Player, cid = getPlayer(src)
    local states = Player and DB.QuestStates(cid)
    if not states then return false end
    local touched = {}
    for id, s in pairs(states) do
        local q = def(id)
        if q and s.active then
            -- decide which objectives were open before this event, so one event cannot run down an ordered chain
            local open = {}
            for i in ipairs(q.objectives) do open[i] = isOpen(src, q, s, i) end
            for i, o in ipairs(q.objectives) do
                local current = tonumber(s.progress[o.id]) or 0
                if open[i] and o.type ~= 'deliver' and current < o.count then
                    local add = match(o, id)
                    if add and add > 0 then
                        s.progress[o.id] = math.min(o.count, current + add)
                        touched[id] = true
                        local label = text(o.label)
                        notify(src, ('%s (%d/%d)'):format(label, s.progress[o.id], o.count), 'inform')
                        if once then break end
                    end
                end
            end
            if touched[id] then
                DB.SaveQuestState(cid, id, s)
                if once then break end
            end
        end
    end
    if not next(touched) then return false end
    Quests.Sync(src)
    for id in pairs(touched) do tryAutoComplete(src, cid, id) end
    return true
end

-- a conversation was opened (choice = nil) or a reply was accepted
function Quests.OnTalk(src, npcId, node, choice)
    advance(src, function(o)
        if o.type ~= 'talk' or o.npc ~= npcId then return end
        if choice then
            if o.node == node and o.choice == choice then return 1 end
            return
        end
        if not o.choice and (not o.node or o.node == node) then return 1 end
    end)
end

function Quests.OnNode(src, npcId, node)
    advance(src, function(o)
        if o.type == 'talk' and o.npc == npcId and not o.choice and o.node == node then return 1 end
    end)
end

---For other scripts: custom objectives only.
function Quests.AddProgress(src, questId, objectiveId, amount)
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then return false end
    return advance(src, function(o, id)
        if id == questId and o.id == objectiveId and o.type == 'custom' then return amount end
    end)
end

-- visits are checked entirely on the server
local function tick(src)
    local Player, cid = getPlayer(src)
    if not Player then return end
    local states = DB.QuestStates(cid)
    if not states then return end
    local busy = false
    for _, s in pairs(states) do
        if s.active then busy = true break end
    end
    if not busy then return end -- nothing to check for this player
    local ped = GetPlayerPed(src)
    local meta = Player.PlayerData.metadata or {}
    if ped ~= 0 and not meta.isdead then
        local pos = GetEntityCoords(ped)
        advance(src, function(o)
            if o.type == 'visit' and #(pos - vector3(o.coords.x, o.coords.y, o.coords.z)) <= o.radius then return 1 end
        end)
    end
    -- ids are copied first: completing one can let another script start a quest
    local ids = {}
    for id, s in pairs(states) do
        if s.active then ids[#ids + 1] = id end
    end
    for _, id in ipairs(ids) do tryAutoComplete(src, cid, id) end
    Quests.Sync(src) -- only sends when something changed, such as carried delivery items
end

CreateThread(function()
    while true do
        Wait(Config.Quests.TickMs)
        for _, id in ipairs(GetPlayers()) do
            local ok, err = pcall(tick, tonumber(id))
            if not ok then print('^1[rsg-npcdialog] quest tick: ' .. tostring(err) .. '^7') end
        end
        -- entity handles are reused, so forget a body as soon as it is gone
        for ent in pairs(killed) do
            if not DoesEntityExist(ent) then killed[ent] = nil end
        end
    end
end)

-------------------------------------------------
-- kills: the client only names a body, everything about it is checked here
-------------------------------------------------
RegisterNetEvent('rsg-npcdialog:server:questKill', function(netId)
    local src = source
    local now = GetGameTimer()
    if lastKill[src] and now - lastKill[src] < 750 then return end
    lastKill[src] = now
    netId = math.tointeger(tonumber(netId))
    if not netId or netId <= 0 then return end

    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 1 or IsPedAPlayer(ent) then return end
    if killed[ent] or GetEntityHealth(ent) > 0 then return end
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - GetEntityCoords(ent)) > Config.Quests.KillRange then return end
    -- when the server knows who killed it, it has to be this player
    if Config.Quests.CheckKiller then
        local killer = GetPedSourceOfDeath(ent)
        if killer and killer ~= 0 and killer ~= ped then
            -- a trampling kill names the horse: accept a non-player ped that is right where the player is
            local isMount = DoesEntityExist(killer) and GetEntityType(killer) == 1 and not IsPedAPlayer(killer)
                and #(GetEntityCoords(killer) - GetEntityCoords(ped)) <= 2.0
            if not isMount then return end
        end
    end

    local model = GetEntityModel(ent) & 0xFFFFFFFF
    killed[ent] = true -- claimed before counting, so no one else can count it meanwhile
    local counted = advance(src, function(o)
        if o.type ~= 'kill' then return end
        for _, m in ipairs(o.models) do
            if (joaat(m) & 0xFFFFFFFF) == model then return 1 end
        end
    end, true) -- one body counts for one objective
    if not counted then killed[ent] = nil end
end)

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:getQuests', function(source, cb)
    local src = source
    -- building the view and the markers is not free: stop it being spammed
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 500 then return cb(nil) end
    lastRequest[src] = now
    cb(Quests.View(src))
    QueueMarkers(src, true) -- forced: a client that just loaded has none yet
end)

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:abandonQuest', function(source, cb, id)
    cb(type(id) == 'string' and Quests.Abandon(source, id) or false)
end)

-------------------------------------------------
-- exports
-------------------------------------------------
local function caller() return GetInvokingResource() or GetCurrentResourceName() end

exports('RegisterQuest', function(raw) return Quests.Add(raw, 'export', caller()) end)
exports('RemoveQuest', function(id)
    local e = Quests.List[id]
    if not e or e.source ~= 'export' or e.owner ~= caller() then return false end
    return Quests.Remove(id)
end)
exports('StartQuest', function(src, id) return Quests.Start(tonumber(src), id) end)
exports('AbandonQuest', function(src, id) return Quests.Abandon(tonumber(src), id) end)
exports('CompleteQuest', function(src, id) return Quests.Complete(tonumber(src), id) end)
exports('AddQuestProgress', function(src, questId, objectiveId, amount)
    return Quests.AddProgress(tonumber(src), questId, objectiveId, amount)
end)
exports('GetQuestState', function(src, id)
    src = tonumber(src)
    local Player, cid = getPlayer(src)
    local progress = cid and DB.Progress(cid)
    if not progress then return nil end
    return Quests.State(src, Player, progress, id)
end)

function Quests.Forget(src)
    lastSent[src] = nil
end

AddEventHandler('playerDropped', function()
    lastKill[source], lastSent[source], lastRequest[source] = nil, nil, nil
end)

AddEventHandler('RSGCore:Server:PlayerDropped', function(Player)
    local cid = Player and Player.PlayerData and Player.PlayerData.citizenid
    if not cid then return end
    for k in pairs(blocked) do
        if k:sub(1, #cid) == cid then blocked[k] = nil end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then return end
    for id, e in pairs(Quests.List) do
        if e.owner == res then Quests.Remove(id) end
    end
end)

for _, q in ipairs(Config.QuestList or {}) do
    local ok, err = Quests.Add(q, 'config')
    if not ok then print(('^1[rsg-npcdialog] config quest "%s": %s^7'):format(tostring(q.id), err)) end
end
