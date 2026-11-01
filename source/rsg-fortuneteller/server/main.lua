local RSGCore = exports['rsg-core']:GetCoreObject()
local RES = GetCurrentResourceName()

local sessions      = {} -- machineKey -> session
local bySource      = {} -- player src -> session
local cooldownUntil = {} -- machineKey -> os.time()
local lastRequest   = {} -- player src -> GetGameTimer()
local nextId        = 0

local function deny(src, msgKey, arg)
    TriggerClientEvent(RES .. ':client:deny', src, msgKey, arg)
end

local function distanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - coords)
end

-- ---------------------------------------------------------------------------
-- Lines
-- ---------------------------------------------------------------------------
local function collect(list)
    local out = {}
    for _, l in ipairs(list or {}) do
        if l.enabled ~= false then
            if l.file then
                out[#out + 1] = { id = l.id, file = l.file, duration = l.duration or 5.0, volume = l.volume or 1.0 }
            elseif l.speech then
                out[#out + 1] = { id = l.id, speech = l.speech, variation = l.variation or 1, duration = l.duration or 5.0 }
            end
        end
    end
    return out
end

-- Pool is static config, so build it once
local linePool = collect(Config.Lines)
for _, l in ipairs(collect(Config.CustomLines)) do linePool[#linePool + 1] = l end
local introLines = collect(Config.IntroLines)

local function buildSequence()
    if #linePool == 0 then return nil end
    local seq = {}
    for i = 1, #introLines do seq[i] = introLines[i] end
    seq[#seq + 1] = linePool[math.random(#linePool)]

    -- Respect MaxReadingSeconds by dropping intro lines from the front
    while #seq > 1 and Fortune.TotalSeconds(seq) > Config.MaxReadingSeconds do
        table.remove(seq, 1)
    end
    return seq
end

-- ---------------------------------------------------------------------------
-- Machine lookup. The key is derived on the server, never trusted from the client.
-- ---------------------------------------------------------------------------
local configured = {}
for _, m in ipairs(Config.Machines) do
    if m.enabled ~= false then
        configured[m.id] = vector3(m.coords.x, m.coords.y, m.coords.z)
    end
end

local function resolveMachine(key, x, y, z)
    if Config.UseConfiguredMachines and configured[key] then
        return key, configured[key]
    end
    if Config.AutoDetectExistingProps and math.type(x) and math.type(y) and math.type(z) then
        local c = vector3(x + 0.0, y + 0.0, z + 0.0)
        -- A world prop sitting on a configured machine must use that machine's key
        if Config.UseConfiguredMachines then
            for id, mc in pairs(configured) do
                if #(c - mc) < 1.5 then return id, mc end
            end
        end
        return Fortune.WorldKey(x, y, z), c
    end
    return nil
end

local function listenersFor(coords, starter)
    local out, range = {}, Config.HearingDistance + 10.0
    for _, id in ipairs(GetPlayers()) do
        local p = tonumber(id)
        if p == starter or distanceTo(p, coords) <= range then
            out[#out + 1] = p
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Session lifecycle
-- ---------------------------------------------------------------------------
local function release(session, notifyStop)
    if sessions[session.key] ~= session then return end
    sessions[session.key] = nil
    if bySource[session.src] == session then bySource[session.src] = nil end

    if session.state == 'playing' and Config.CooldownSeconds > 0 then
        cooldownUntil[session.key] = os.time() + Config.CooldownSeconds
    end

    if notifyStop then
        for _, p in ipairs(session.listeners or {}) do
            TriggerClientEvent(RES .. ':client:stop', p, session.id)
        end
    end
end

RegisterNetEvent(RES .. ':server:request', function(clientKey, x, y, z)
    local src = source
    if type(clientKey) ~= 'string' or #clientKey > 64 then return end

    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < Config.RequestCooldown * 1000 then
        return deny(src, 'slowDown')
    end
    lastRequest[src] = now

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local key, coords = resolveMachine(clientKey, x, y, z)
    if not key then return deny(src, 'unavailable') end
    if bySource[src] or sessions[key] then return deny(src, 'busy') end
    if distanceTo(src, coords) > Config.InteractionDistance + 3.0 then return deny(src, 'tooFar') end

    local left = (cooldownUntil[key] or 0) - os.time()
    if left > 0 then return deny(src, 'cooldown', left) end

    if Config.Price > 0 and Player.Functions.GetMoney('cash') < Config.Price then
        return deny(src, 'noMoney', Config.Price)
    end

    local sequence = buildSequence()
    if not sequence then return deny(src, 'unavailable') end

    nextId = nextId + 1
    local session = { id = nextId, key = key, src = src, coords = coords, sequence = sequence, state = 'preparing' }
    sessions[key] = session
    bySource[src] = session

    TriggerClientEvent(RES .. ':client:begin', src, session.id, coords, sequence)

    -- If the client never answers, free the machine (nobody was charged yet)
    SetTimeout((Config.PrepareTimeoutSeconds + 5) * 1000, function()
        if sessions[key] == session and session.state == 'preparing' then
            release(session, false)
            deny(src, 'setupFailed')
        end
    end)
end)

RegisterNetEvent(RES .. ':server:failed', function(id)
    local session = bySource[source]
    if session and session.id == id and session.state == 'preparing' then
        release(session, false) -- no charge
    end
end)

RegisterNetEvent(RES .. ':server:ready', function(id)
    local src = source
    local session = bySource[src]
    if not session or session.id ~= id or session.state ~= 'preparing' then return end

    -- Re-check position: the player may have walked off while loading
    if distanceTo(src, session.coords) > Config.InteractionDistance + 3.0 then
        release(session, false)
        return deny(src, 'tooFar')
    end

    -- Charge only now, after audio/anim are confirmed loaded
    if Config.Price > 0 then
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player or not Player.Functions.RemoveMoney('cash', Config.Price, 'fortune-teller') then
            release(session, false)
            return deny(src, 'paymentFailed')
        end
    end

    session.state = 'playing'
    session.listeners = listenersFor(session.coords, src)

    for _, p in ipairs(session.listeners) do
        TriggerClientEvent(RES .. ':client:play', p, session.id, session.coords, session.sequence, src)
    end

    local total = Fortune.TotalSeconds(session.sequence)
    SetTimeout(math.ceil((total + 1.0) * 1000), function() release(session, false) end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastRequest[src] = nil
    local session = bySource[src]
    if session then release(session, true) end
end)
