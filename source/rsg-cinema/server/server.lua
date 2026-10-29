local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- config labels are locale keys: translate them once
for _, f in ipairs(Config.Films) do f.label = locale(f.label) end
for _, c in pairs(Config.Cinemas) do c.label = locale(c.label) end

-- Saved picture adjustments (admin panel) live in data/draw.json
local DRAW_FILE = 'data/draw.json'
local function loadDraws()
    local raw = LoadResourceFile(GetCurrentResourceName(), DRAW_FILE)
    local ok, data = pcall(json.decode, raw or '{}')
    if not ok or type(data) ~= 'table' then return end
    for id, d in pairs(data) do
        if Config.Cinemas[id] and type(d) == 'table' then Config.Cinemas[id].draw = d end
    end
end
local function saveDraws()
    local out = {}
    for id, cfg in pairs(Config.Cinemas) do out[id] = cfg.draw end
    SaveResourceFile(GetCurrentResourceName(), DRAW_FILE, json.encode(out, { indent = true }), -1)
end
loadDraws()

lib.callback.register('rsg-cinema:server:getDraws', function()
    local out = {}
    for id, cfg in pairs(Config.Cinemas) do out[id] = cfg.draw end
    return out
end)

-- State per cinema: { filmIndex, nextShow (os.time), playing, public, startedAt, tickets = { [citizenid] = pricePaid } }
local Cinemas = {}

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_title'), description = desc, type = ntype or 'inform' })
end

local function publicState(id)
    local c = Cinemas[id]
    if not c then return nil end
    local film = Config.Films[Config.Cinemas[id].films[c.filmIndex]]
    return {
        id = id,
        film = film and film.label or '?',
        playlist = film and film.playlist or nil,
        playing = c.playing,
        startsIn = math.max(0, c.nextShow - os.time()),
        salesOpen = not c.playing and (c.nextShow - os.time()) <= Config.SalesWindow * 60,
    }
end

local function nextFilm(id)
    local c = Cinemas[id]
    c.filmIndex = c.filmIndex % #Config.Cinemas[id].films + 1
end

local function sendToHolders(id, event, ...)
    local c = Cinemas[id]
    for _, src in ipairs(GetPlayers()) do
        local Player = RSGCore.Functions.GetPlayer(tonumber(src))
        if Player and c.tickets[Player.PlayerData.citizenid] then
            TriggerClientEvent(event, tonumber(src), ...)
        end
    end
end

local function endShow(id)
    local c = Cinemas[id]
    if not c or not c.playing then return end
    c.playing = false
    c.public = false
    TriggerClientEvent('rsg-cinema:client:stopFilm', -1, id)
    c.tickets = {}
    nextFilm(id)
    c.nextShow = os.time() + Config.ShowInterval * 60
end

-- public = true (admin start): everyone inside sees it, no ticket needed
local function startShow(id, public)
    local c = Cinemas[id]
    if not c or c.playing then return end
    c.playing = true
    c.public = public == true
    c.startedAt = os.time()
    local st = publicState(id)
    if c.public then
        TriggerClientEvent('rsg-cinema:client:startFilm', -1, id, st.playlist, st.film, false)
    else
        sendToHolders(id, 'rsg-cinema:client:startFilm', id, st.playlist, st.film, true)
    end
end

CreateThread(function()
    for id, cfg in pairs(Config.Cinemas) do
        -- drop film indexes that don't exist in Config.Films
        local valid = {}
        for _, fi in ipairs(cfg.films or {}) do
            if Config.Films[fi] then valid[#valid + 1] = fi
            else print(('[rsg-cinema] ^3cinema %s: film index %s does not exist, skipped^7'):format(id, tostring(fi))) end
        end
        cfg.films = valid
        if cfg.enabled and #cfg.films > 0 then
            Cinemas[id] = { filmIndex = 1, nextShow = os.time() + Config.ShowInterval * 60, playing = false, startedAt = 0, tickets = {} }
        end
    end
    while true do
        local now = os.time()
        for id, c in pairs(Cinemas) do
            if c.playing then
                if now - c.startedAt >= Config.MaxShowLength then endShow(id) end
            elseif now >= c.nextShow then
                if next(c.tickets) then
                    startShow(id)
                else -- nobody bought a ticket: skip to the next showing
                    nextFilm(id)
                    c.nextShow = now + Config.ShowInterval * 60
                end
            end
        end
        Wait(1000)
    end
end)

local function ticketInfo(src, id)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local st = publicState(id)
    st.label = Config.Cinemas[id].label
    st.price = Config.TicketPrice
    st.hasTicket = Cinemas[id].tickets[Player.PlayerData.citizenid] ~= nil
    return st
end

local function nearSeller(src, id)
    local s = Config.Cinemas[id].seller.coords
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(s.x, s.y, s.z)) <= 5.0
end

lib.callback.register('rsg-cinema:server:getInfo', function(src, id)
    if type(id) ~= 'string' or not Cinemas[id] then return nil end
    return ticketInfo(src, id)
end)

local lastBuy = {}
lib.callback.register('rsg-cinema:server:buyTicket', function(src, id)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(id) ~= 'string' or not Cinemas[id] then return nil end
    if lastBuy[src] and GetGameTimer() - lastBuy[src] < 2000 then return ticketInfo(src, id) end
    lastBuy[src] = GetGameTimer()
    if not nearSeller(src, id) then return nil end

    local c, st = Cinemas[id], publicState(id)
    local cid = Player.PlayerData.citizenid
    if not st.salesOpen then
        notify(src, locale('sv_sales_closed'), 'error')
    elseif c.tickets[cid] then
        notify(src, locale('sv_already_ticket'), 'error')
    elseif not Player.Functions.RemoveMoney('cash', Config.TicketPrice, 'cinema-ticket') then
        notify(src, locale('sv_no_money'), 'error')
    else
        c.tickets[cid] = Config.TicketPrice -- price paid, used for refunds
        notify(src, locale('sv_ticket_bought', st.film), 'success')
    end
    return ticketInfo(src, id)
end)

-- A ticket holder's client reports the END_OF_MOVIE_MARKER; only accepted after the minimum runtime
RegisterNetEvent('rsg-cinema:server:filmEnded', function(id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(id) ~= 'string' then return end
    local c = Cinemas[id]
    if not c or not c.playing or (not c.public and not c.tickets[Player.PlayerData.citizenid]) then return end
    if os.time() - c.startedAt < Config.MinShowLength then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - Config.Cinemas[id].centre) > Config.WatchRadius + 5.0 then return end
    endShow(id)
end)

-- Rejoin after relog/resource restart while a show is running
RegisterNetEvent('rsg-cinema:server:sync', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    for id, c in pairs(Cinemas) do
        if c.playing and (c.public or c.tickets[Player.PlayerData.citizenid]) then
            local st = publicState(id)
            TriggerClientEvent('rsg-cinema:client:startFilm', src, id, st.playlist, st.film, not c.public)
        end
    end
end)

---------------------------------------------------------------- admin panel
local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function adminData()
    local list = {}
    for id, c in pairs(Cinemas) do
        local cfg = Config.Cinemas[id]
        local st = publicState(id)
        local films = {}
        for i, fi in ipairs(cfg.films) do films[#films + 1] = { index = i, label = Config.Films[fi].label } end
        local sold = 0
        for _ in pairs(c.tickets) do sold = sold + 1 end -- tickets is keyed by citizenid
        list[#list + 1] = {
            id = id, label = cfg.label, film = st.film, filmIndex = c.filmIndex, films = films,
            playing = c.playing, public = c.public == true, startsIn = st.startsIn,
            elapsed = c.playing and (os.time() - c.startedAt) or 0, tickets = sold, draw = cfg.draw,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

lib.callback.register('rsg-cinema:server:adminData', function(src)
    if not isAdmin(src) then return nil end
    return adminData()
end)

RegisterNetEvent('rsg-cinema:server:adminAction', function(action, id, filmIndex)
    local src = source
    if not isAdmin(src) then return end
    if type(id) ~= 'string' or not Cinemas[id] then return notify(src, locale('sv_bad_cinema'), 'error') end
    local c = Cinemas[id]
    if action == 'start' then
        if c.playing then return notify(src, locale('sv_already_playing'), 'error') end
        filmIndex = math.tointeger(tonumber(filmIndex or '') or 0)
        if filmIndex and Config.Cinemas[id].films[filmIndex] then c.filmIndex = filmIndex end
        startShow(id, true)
        notify(src, locale('sv_started', Config.Cinemas[id].label), 'success')
    elseif action == 'stop' then
        if not c.playing then return notify(src, locale('sv_not_playing'), 'error') end
        if not c.public then -- paid showing cut short by an admin: refund online ticket holders
            for cid, paid in pairs(c.tickets) do
                local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
                if P and type(paid) == 'number' and paid > 0 then
                    P.Functions.AddMoney('cash', paid, 'cinema-refund')
                    notify(P.PlayerData.source, locale('sv_refunded', Config.Cinemas[id].label), 'inform')
                end
            end
        end
        endShow(id)
        notify(src, locale('sv_stopped', Config.Cinemas[id].label), 'success')
    end
end)

local function num(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return math.min(hi, math.max(lo, math.floor(v * 1000 + 0.5) / 1000))
end

RegisterNetEvent('rsg-cinema:server:adminSetDraw', function(id, d)
    local src = source
    if not isAdmin(src) then return end
    if type(id) ~= 'string' or not Config.Cinemas[id] or type(d) ~= 'table' then return end
    local draw = { x = num(d.x, 0, 1), y = num(d.y, 0, 1), w = num(d.w, 0.1, 2), h = num(d.h, 0.1, 2) }
    if not (draw.x and draw.y and draw.w and draw.h) then return end
    Config.Cinemas[id].draw = draw
    saveDraws()
    TriggerClientEvent('rsg-cinema:client:setDraw', -1, id, draw)
    notify(src, locale('sv_draw_saved', Config.Cinemas[id].label), 'success')
end)

RSGCore.Commands.Add(Config.AdminCommand, locale('sv_cmd_help'), {}, false, function(src)
    TriggerClientEvent('rsg-cinema:client:openAdmin', src)
end, Config.AdminPermission)

AddEventHandler('playerDropped', function() lastBuy[source] = nil end)
