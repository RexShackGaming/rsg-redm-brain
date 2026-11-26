-- NPC registry, conversation sessions, public exports
local RSGCore = exports['rsg-core']:GetCoreObject()

NPCs = {}          -- id -> { def = clean npc, source = 'config'|'db'|'export', owner = resource }
local Actions = {} -- id -> { cb, owner } registered by export
local Sessions = {} -- src -> { npc, node, id, cid, remote, anchor, last }
local sessionSeq = 0
local Busy = {} -- src -> true while a reply is being applied (survives close / reopen)
local Opening = {} -- src -> true while a conversation is being opened by the client
local lastOpen = {} -- src -> game timer
local OPEN_COOLDOWN_MS = 750 -- stops open / close spam farming talk objectives and events
local lastMarkers = {} -- src -> json of the markers last sent

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'), description = desc, type = ntype or 'inform', duration = 5000,
    })
end

-------------------------------------------------
-- schedules: where an NPC is right now
-------------------------------------------------
-- returns the slot number (0 = no schedule, false = closed) and the position and scenario
local function currentSpot(def, hour)
    local base = { coords = def.coords, scenario = def.scenario }
    -- without a clock the NPC stays at its normal spot, rather than vanishing
    if not def.schedule or not hour then return 0, base end
    for i, slot in ipairs(def.schedule) do
        if World.InHours(hour, slot.from, slot.to) then
            return i, { coords = slot.coords or def.coords, scenario = slot.scenario or def.scenario }
        end
    end
    return false, nil
end

local function sameSpot(a, b)
    if not a or not b then return a == b end
    local p, q = a.coords, b.coords
    return a.scenario == b.scenario and p.x == q.x and p.y == q.y and p.z == q.z and p.w == q.w
end

local function place(entry, hour)
    entry.slot, entry.spot = currentSpot(entry.def, hour)
end

---For GPS routes: the NPC's current spot, or where it first appears when it is closed.
function NPCPosition(id)
    local e = NPCs[id]
    if not e or not e.def.enabled then return nil end
    if e.spot then return e.spot.coords end
    local first = e.def.schedule and e.def.schedule[1]
    return first and first.coords or e.def.coords
end

---The NPC where a quest is handed in (the first by id when there are several).
function TurnInNPC(questId)
    local best
    for id, e in pairs(NPCs) do
        if e.def.enabled and e.turnIns[questId] and (not best or id < best) then best = id end
    end
    return best
end

-------------------------------------------------
-- registry
-------------------------------------------------
local function publicList()
    local out = {}
    for id, e in pairs(NPCs) do
        local d = e.def
        if d.enabled and e.spot then
            out[#out + 1] = {
                id = id, name = d.name, model = d.model, coords = e.spot.coords,
                scenario = e.spot.scenario, distance = d.distance, blip = d.blip,
            }
        end
    end
    return out
end

local syncQueued = false
function SyncNPCs()
    if syncQueued then return end
    syncQueued = true
    SetTimeout(250, function() -- batches many registrations into one broadcast
        syncQueued = false
        TriggerClientEvent('rsg-npcdialog:client:sync', -1, publicList())
        QueueAllMarkers() -- an NPC that just appeared or changed should not wait for the next refresh
    end)
end

function AddNPC(def, source, owner)
    local clean, err = Validate.NPC(def)
    if not clean then return false, err end
    local existing = NPCs[clean.id]
    if existing and (existing.source ~= source or existing.owner ~= owner) then
        return false, ('id "%s" is already used by %s'):format(clean.id, existing.owner or existing.source)
    end
    CloseSessionsFor(clean.id)
    local entry = { def = clean, source = source, owner = owner, turnIns = {}, hasQuests = false }
    for _, node in pairs(clean.nodes) do
        for _, c in ipairs(node.choices) do
            if c.startQuest or c.turnInQuest then entry.hasQuests = true end
            if c.turnInQuest then entry.turnIns[c.turnInQuest] = true end
        end
    end
    place(entry, clean.schedule and World.Hour())
    NPCs[clean.id] = entry
    SyncNPCs()
    return true, clean.id
end

function RemoveNPCById(id)
    if not NPCs[id] then return false end
    CloseSessionsFor(id)
    NPCs[id] = nil
    SyncNPCs()
    return true
end

function ActionExists(name) return Config.Actions[name] ~= nil or Actions[name] ~= nil end

function ActionNames()
    local seen, out = {}, {}
    for n in pairs(Config.Actions) do seen[n] = true end
    for n in pairs(Actions) do seen[n] = true end
    for n in pairs(seen) do out[#out + 1] = n end
    table.sort(out)
    return out
end

-------------------------------------------------
-- sessions
-------------------------------------------------
local function endSession(src)
    if not Sessions[src] then return end
    Sessions[src] = nil
    TriggerClientEvent('rsg-npcdialog:client:close', src)
end

function CloseSessionsFor(npcId)
    for src, s in pairs(Sessions) do
        if s.npc == npcId then endSession(src) end
    end
end

local function near(src, session, def)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    if session.remote then -- opened by another script: only require that the player stays put
        return #(pos - session.anchor) <= 5.0
    end
    local entry = NPCs[session.npc]
    local spot = entry and entry.spot
    if not spot then return false end -- closed
    return #(pos - vector3(spot.coords.x, spot.coords.y, spot.coords.z)) <= def.distance + Config.ServerLeeway
end

local function alive(Player)
    local m = Player.PlayerData.metadata or {}
    return not m.isdead and not m.ishandcuffed
end

local function key(npcId, node, choiceId) return ('%s:%s:%s'):format(npcId, node, choiceId) end

-- replies that start or hand in a quest are only usable when the quest allows it
local function questGate(src, Player, progress, c)
    if c.startQuest then return Quests.CanStart(src, Player, progress, c.startQuest) end
    if c.turnInQuest then
        if Quests.State(src, Player, progress, c.turnInQuest) ~= 'ready' then return false, locale('quest_not_ready') end
    end
    return true
end

-- builds what the player is allowed to see for the current node
local function nodeView(src, Player, progress, session)
    local def = NPCs[session.npc].def
    local node = def.nodes[session.node]
    local choices, now = {}, os.time()
    for i, c in ipairs(node.choices) do
        local k = key(def.id, session.node, c.id)
        if not (c.once and progress.once[k]) then
            local ok, why = Engine.Meets(src, Player, progress, c.requires, def.id)
            if ok and c.cooldown and (progress.cd[k] or 0) > now then
                ok, why = false, World.WaitText(progress.cd[k] - now)
            end
            if ok and c.action and not ActionExists(c.action) then ok, why = false, locale('req_unavailable') end
            if ok then ok, why = questGate(src, Player, progress, c) end
            if ok or c.lock == 'show' then
                choices[#choices + 1] = { index = i, label = c.label, locked = not ok, reason = why }
            end
        end
    end
    return { session = session.id, name = def.name, title = def.title, text = node.text, choices = choices }
end

-------------------------------------------------
-- quest markers: which NPCs have a quest to give or take back
-------------------------------------------------
local function markerFor(src, Player, progress, def)
    if not Engine.Meets(src, Player, progress, def.requires, def.id) then return nil end
    local found
    for nodeId, node in pairs(def.nodes) do
        for _, c in ipairs(node.choices) do
            if c.startQuest or c.turnInQuest then
                local k = key(def.id, nodeId, c.id)
                local usable = not (c.once and progress.once[k])
                    and not (c.cooldown and (progress.cd[k] or 0) > os.time())
                    and (not c.action or ActionExists(c.action))
                    and Engine.Meets(src, Player, progress, c.requires, def.id)
                    and questGate(src, Player, progress, c)
                if usable then
                    if c.turnInQuest then return 'turnin' end
                    found = 'offer'
                end
            end
        end
    end
    return found
end

local function sendMarkers(src, force)
    local Player = RSGCore.Functions.GetPlayer(src)
    local progress = Player and DB.Progress(Player.PlayerData.citizenid)
    if not progress then return end
    -- ids are copied first: loading or a custom condition may yield while the registry changes
    local ids = {}
    for id, e in pairs(NPCs) do
        if e.hasQuests and e.def.enabled and e.spot then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local markers, signature = {}, {}
    for _, id in ipairs(ids) do
        local e = NPCs[id]
        local state = e and markerFor(src, Player, progress, e.def)
        if state then
            markers[id] = state
            signature[#signature + 1] = id .. '=' .. state
        end
    end
    signature = table.concat(signature, ',')
    if not force and lastMarkers[src] == signature then return end
    lastMarkers[src] = signature
    TriggerClientEvent('rsg-npcdialog:client:markers', src, markers)
end

local queued = {} -- src -> true (or 'force') while a marker refresh is waiting to run

-- many changes in a short time become one refresh, which never holds up the caller
function QueueMarkers(src, force)
    if not Config.Markers.Enabled then return end
    if queued[src] then
        if force then queued[src] = 'force' end
        return
    end
    queued[src] = force and 'force' or true
    SetTimeout(250, function()
        local forced = queued[src] == 'force'
        queued[src] = nil
        local ok, err = pcall(sendMarkers, src, forced)
        if not ok then print('^1[rsg-npcdialog] quest markers: ' .. tostring(err) .. '^7') end
    end)
end

function QueueAllMarkers()
    for _, id in ipairs(GetPlayers()) do QueueMarkers(tonumber(id)) end
end

---@return table|nil view, string|nil reason
local function startSession(src, npcId, node, remote)
    local Player = RSGCore.Functions.GetPlayer(src)
    local entry = NPCs[npcId]
    if not Player or not entry or not entry.def.enabled then return nil end
    local def = entry.def
    local session = { npc = npcId, remote = remote, cid = Player.PlayerData.citizenid }
    if remote then
        local ped = GetPlayerPed(src)
        if ped == 0 then return nil end
        session.anchor = GetEntityCoords(ped)
    end
    if not near(src, session, def) or not alive(Player) then return nil end

    local progress = DB.Progress(session.cid)
    if not progress then return nil, locale('sv_failed') end
    if NPCs[npcId] ~= entry then return nil end -- edited while progress was loading

    local ok, why = Engine.Meets(src, Player, progress, def.requires, npcId)
    if not ok then return nil, why end

    if node then
        if not def.nodes[node] then return nil end
    else
        node = def.start
        for _, s in ipairs(def.starts or {}) do
            if Engine.Meets(src, Player, progress, s.requires, npcId) then node = s.node break end
        end
    end

    sessionSeq = sessionSeq + 1
    session.id, session.node = sessionSeq, node
    Sessions[src] = session
    Quests.OnTalk(src, npcId, node)
    TriggerEvent('rsg-npcdialog:server:opened', src, npcId)
    return nodeView(src, Player, progress, session)
end

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:getNPCs', function(_, cb)
    cb(publicList())
end)

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:open', function(source, cb, npcId)
    if type(npcId) ~= 'string' then return cb(nil) end
    local src = source
    local now = GetGameTimer()
    if Busy[src] or Opening[src] or (lastOpen[src] and now - lastOpen[src] < OPEN_COOLDOWN_MS) then return cb(nil) end
    Opening[src], lastOpen[src] = true, now
    local ok, view, why = pcall(startSession, src, npcId)
    Opening[src] = nil
    if not ok then
        print('^1[rsg-npcdialog] open error: ' .. tostring(view) .. '^7')
        view, why = nil, locale('sv_failed')
    end
    if why then notify(src, why, 'error') end
    cb(view)
end)

local function runAction(src, npcId, name)
    local reg = Actions[name]
    if reg then
        local ok, err = pcall(reg.cb, src, npcId)
        if not ok then print(('^1[rsg-npcdialog] action %s failed: %s^7'):format(name, tostring(err))) end
        return
    end
    local a = Config.Actions[name]
    if not a then return end
    if a.side == 'server' then
        TriggerEvent(a.event, src, npcId, a.args)
    else
        TriggerClientEvent(a.event, src, npcId, a.args)
    end
end

-- reply handling. Returns { view = ... } or { close = true }, either with an optional action
local function handleChoice(src, session, index)
    local Player = RSGCore.Functions.GetPlayer(src)
    local entry = NPCs[session.npc]
    if not Player or not entry or Player.PlayerData.citizenid ~= session.cid then return { close = true } end
    local def = entry.def
    if not near(src, session, def) or not alive(Player) then return { close = true } end
    local progress = DB.Progress(session.cid)
    if not progress then return { close = true } end

    local c = def.nodes[session.node].choices[index]
    if not c then return { close = true } end
    local k = key(def.id, session.node, c.id)

    -- check everything again: what the client was shown may be out of date or forged
    local ok, why = Engine.Meets(src, Player, progress, c.requires, def.id)
    if c.once and progress.once[k] then ok = false end
    if c.cooldown and (progress.cd[k] or 0) > os.time() then ok = false end
    if c.action and not ActionExists(c.action) then ok = false end
    if ok then ok, why = questGate(src, Player, progress, c) end
    if Sessions[src] ~= session then return { close = true } end
    if ok then
        if c.turnInQuest then
            -- delivery items, quest reward and the reply's own cost / reward succeed or fail together
            ok, why = Quests.Complete(src, c.turnInQuest, c.cost, c.reward)
        else
            ok, why = Engine.Transact(src, Player, c.cost, c.reward, 'rsg-npcdialog:' .. def.id)
        end
    end
    if not ok then
        notify(src, why or locale('req_unavailable'), 'error')
        return { view = nodeView(src, Player, progress, session) }
    end

    if c.once then DB.Set(session.cid, 'once', k, 1) end
    if c.cooldown then DB.Set(session.cid, 'cd', k, os.time() + c.cooldown) end
    for _, f in ipairs(c.clearFlags or {}) do DB.Set(session.cid, 'flag', f, nil) end
    for _, f in ipairs(c.setFlags or {}) do DB.Set(session.cid, 'flag', f, 1) end
    Engine.Progression(src, c.reward, 'rsg-npcdialog:' .. def.id)
    local fromNode = session.node
    Quests.OnTalk(src, def.id, fromNode, c.id) -- before startQuest, so the starting reply never counts for itself
    if c.startQuest then Quests.Start(src, c.startQuest) end
    TriggerEvent('rsg-npcdialog:server:choice', src, def.id, fromNode, c.id)

    local result
    if c.next and Sessions[src] == session then
        session.node = c.next
        Quests.OnNode(src, def.id, c.next)
        result = { view = nodeView(src, Player, progress, session) }
    else
        result = { close = true }
    end
    -- the action runs last; actions that open their own UI should be on a closing choice
    if c.action then result.action = c.action end
    return result
end

RSGCore.Functions.CreateCallback('rsg-npcdialog:server:choose', function(source, cb, sessionId, index)
    local src = source
    local session = Sessions[src]
    if not session or session.id ~= sessionId or type(index) ~= 'number' then return cb({ close = true }) end
    if Busy[src] then return cb(nil) end
    local now = GetGameTimer()
    if session.last and now - session.last < Config.ChoiceCooldownMs then return cb(nil) end
    Busy[src], session.last = true, now

    local ok, result = pcall(handleChoice, src, session, index)
    Busy[src] = nil
    if not ok then
        print('^1[rsg-npcdialog] choice error: ' .. tostring(result) .. '^7')
        notify(src, locale('sv_failed'), 'error')
        result = { close = true }
    end

    if result.close and Sessions[src] == session then Sessions[src] = nil end
    local action = result.action
    result.action = nil
    cb(result)
    QueueMarkers(src)
    if action then
        -- give the client time to release NUI focus before another UI opens
        if result.close then Wait(150) end
        runAction(src, session.npc, action)
    end
end)

RegisterNetEvent('rsg-npcdialog:server:closed', function(sessionId)
    local src = source
    if Sessions[src] and Sessions[src].id == sessionId then Sessions[src] = nil end
end)

-------------------------------------------------
-- exports
-------------------------------------------------
local function caller() return GetInvokingResource() or GetCurrentResourceName() end

exports('RegisterNPC', function(def) return AddNPC(def, 'export', caller()) end)

exports('RemoveNPC', function(id)
    local e = NPCs[id]
    if not e or e.source ~= 'export' or e.owner ~= caller() then return false end
    return RemoveNPCById(id)
end)

exports('OpenDialog', function(src, npcId, node)
    src = tonumber(src)
    if not src or Busy[src] then return false end
    local view = startSession(src, npcId, node, true)
    if not view then return false end
    TriggerClientEvent('rsg-npcdialog:client:show', src, npcId, view)
    return true
end)

exports('CloseDialog', function(src) endSession(tonumber(src)) end)

exports('RegisterAction', function(name, cb)
    if type(name) ~= 'string' or not name:match('^[%w_%-]+$') or not cb then return false end
    Actions[name] = { cb = cb, owner = caller() }
    return true
end)

exports('RegisterCondition', function(name, cb)
    if type(name) ~= 'string' or not name:match('^[%w_%-]+$') or not cb then return false end
    Engine.Conditions[name] = { cb = cb, owner = caller() }
    return true
end)

local function citizen(src)
    local Player = RSGCore.Functions.GetPlayer(tonumber(src))
    return Player and Player.PlayerData.citizenid
end

exports('HasFlag', function(src, flag)
    local cid = citizen(src)
    local p = cid and DB.Progress(cid)
    return p ~= nil and p.flag[flag] ~= nil
end)

local function setFlag(src, flag, value)
    local cid = citizen(src)
    if not cid or type(flag) ~= 'string' or not flag:match('^[%w_%-]+$') or #flag > 50 then return false end
    return DB.Set(cid, 'flag', flag, value)
end

exports('SetFlag', function(src, flag) return setFlag(src, flag, 1) end)
exports('ClearFlag', function(src, flag) return setFlag(src, flag, nil) end)

exports('ResetProgress', function(citizenid, npcId)
    if type(citizenid) ~= 'string' then return false end
    local ok = DB.Reset(citizenid, npcId)
    Quests.SyncAll()
    return ok
end)

-------------------------------------------------
-- lifecycle
-------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then return end
    for id, e in pairs(NPCs) do
        if e.owner == res then RemoveNPCById(id) end
    end
    for name, a in pairs(Actions) do
        if a.owner == res then Actions[name] = nil end
    end
    for name, c in pairs(Engine.Conditions) do
        if c.owner == res then Engine.Conditions[name] = nil end
    end
end)

AddEventHandler('playerDropped', function()
    Sessions[source], Busy[source], Opening[source], lastOpen[source] = nil, nil, nil, nil
    lastMarkers[source] = nil
end)

-- free cached progress when a player leaves the server
AddEventHandler('RSGCore:Server:PlayerDropped', function(Player)
    if Player and Player.PlayerData then DB.Unload(Player.PlayerData.citizenid) end
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local cid = citizen(src)
    Sessions[src] = nil
    lastMarkers[src] = nil
    Quests.Forget(src)
    if cid then DB.Unload(cid) end
end)

-- moves, opens and closes scheduled NPCs
CreateThread(function()
    while true do
        Wait(Config.ScheduleCheckMs)
        local hour, asked, changed = nil, false, false
        for id, e in pairs(NPCs) do
            if e.def.schedule then
                if not asked then hour, asked = World.Hour(), true end
                local slot, spot = currentSpot(e.def, hour)
                if slot ~= e.slot then
                    local moved = not sameSpot(e.spot, spot)
                    e.slot, e.spot = slot, spot
                    -- back to back slots with the same spot change nothing the player can see
                    if moved then
                        changed = true
                        for src, s in pairs(Sessions) do
                            if s.npc == id and not s.remote then
                                notify(src, locale('npc_left'))
                                endSession(src)
                            end
                        end
                    end
                end
            end
        end
        if changed then SyncNPCs() end
    end
end)

-- time, weather, money and cooldowns change without any event, so markers are rechecked
CreateThread(function()
    while Config.Markers.Enabled do
        Wait(Config.Markers.RefreshMs)
        for _, id in ipairs(GetPlayers()) do
            QueueMarkers(tonumber(id))
            Wait(50) -- spread the work over several frames
        end
    end
end)

-- config NPCs load first so exports and the editor cannot take their ids
for _, def in ipairs(Config.NPCs or {}) do
    local ok, err = AddNPC(def, 'config')
    if not ok then print(('^1[rsg-npcdialog] config NPC "%s": %s^7'):format(tostring(def.id), err)) end
end

MySQL.ready(function()
    CreateThread(function()
        if not DB.Setup() then return end
        for _, row in ipairs(DB.LoadNPCs()) do
            local decoded, data = pcall(json.decode, row.data)
            local ok, err = false, 'bad JSON'
            if decoded then ok, err = AddNPC(data, 'db') end
            if not ok then print(('^1[rsg-npcdialog] saved NPC "%s" skipped: %s^7'):format(row.id, err)) end
        end
        SyncNPCs()
        for _, row in ipairs(DB.LoadQuests()) do
            local decoded, data = pcall(json.decode, row.data)
            local ok, err = false, 'bad JSON'
            if decoded then ok, err = Quests.Add(data, 'db') end
            if not ok then print(('^1[rsg-npcdialog] saved quest "%s" skipped: %s^7'):format(row.id, err)) end
        end
        Quests.SyncAll()
    end)
end)
