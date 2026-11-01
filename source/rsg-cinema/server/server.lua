local RSGCore = exports['rsg-core']:GetCoreObject()

-- config labels are locale keys: translate them once
for _, f in ipairs(Config.Films) do f.label = locale(f.label) end
for _, c in pairs(Config.Cinemas) do c.label = locale(c.label) end

local SELLER_RANGE = 5.0 -- must match the client's ticket UI range

---------------------------------------------------------------- saved picture settings (data/draw.json)
local DRAW_FILE = 'data/draw.json'

local function loadDraws()
    local raw = LoadResourceFile(GetCurrentResourceName(), DRAW_FILE)
    local ok, data = pcall(json.decode, raw or '{}')
    if not ok or type(data) ~= 'table' then return end
    for id, d in pairs(data) do
        if Config.Cinemas[id] and type(d) == 'table' then Config.Cinemas[id].draw = d end
    end
end

local function allDraws()
    local out = {}
    for id, cfg in pairs(Config.Cinemas) do out[id] = cfg.draw end
    return out
end

local function saveDraws()
    SaveResourceFile(GetCurrentResourceName(), DRAW_FILE, json.encode(allDraws(), { indent = true }), -1)
end

loadDraws()

RSGCore.Functions.CreateCallback('rsg-cinema:server:getDraws', function(_, cb) cb(allDraws()) end)

---------------------------------------------------------------- show state
-- Cinemas[id] = { filmIndex, nextShow (os.time), playing, public, startedAt, tickets = { [citizenid] = pricePaid } }
local Cinemas = {}

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('sv_title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local function currentFilm(id)
    return Config.Films[Config.Cinemas[id].films[Cinemas[id].filmIndex]]
end

local function publicState(id)
    local c = Cinemas[id]
    local film = currentFilm(id)
    local left = c.nextShow - os.time()
    return {
        id = id,
        film = film and film.label or '?',
        playlist = film and film.playlist or nil,
        playing = c.playing,
        startsIn = math.max(0, left),
        salesOpen = not c.playing and left <= Config.SalesWindow * 60,
    }
end

local function nextFilm(id)
    local c = Cinemas[id]
    c.filmIndex = c.filmIndex % #Config.Cinemas[id].films + 1
end

local function scheduleNext(id)
    Cinemas[id].nextShow = os.time() + Config.ShowInterval * 60
end

-- refunds every online ticket holder of a cancelled paid showing
local function refundTickets(id)
    local c = Cinemas[id]
    for cid, paid in pairs(c.tickets) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
        if P and type(paid) == 'number' and paid > 0 then
            P.Functions.AddMoney('cash', paid, 'cinema-refund')
            notify(P.PlayerData.source, locale('sv_refunded', Config.Cinemas[id].label), 'inform')
        end
    end
    c.tickets = {}
end

local function endShow(id)
    local c = Cinemas[id]
    if not c or not c.playing then return end
    c.playing, c.public = false, false
    c.tickets = {}
    TriggerClientEvent('rsg-cinema:client:stopFilm', -1, id)
    nextFilm(id)
    scheduleNext(id)
end

-- public = true (admin start): everyone inside sees it, no ticket needed
local function startShow(id, public)
    local c = Cinemas[id]
    if not c or c.playing then return end
    c.playing, c.public, c.startedAt = true, public == true, os.time()
    local st = publicState(id)
    if c.public then
        TriggerClientEvent('rsg-cinema:client:startFilm', -1, id, st.playlist, st.film, false)
        return
    end
    for cid in pairs(c.tickets) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
        if P then TriggerClientEvent('rsg-cinema:client:startFilm', P.PlayerData.source, id, st.playlist, st.film, true) end
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
            Cinemas[id] = { filmIndex = 1, playing = false, public = false, startedAt = 0, tickets = {} }
            scheduleNext(id)
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
                    scheduleNext(id)
                end
            end
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------- tickets
local function validCinema(id) return type(id) == 'string' and Cinemas[id] ~= nil end

local function ticketInfo(Player, id)
    local st = publicState(id)
    st.label = Config.Cinemas[id].label
    st.price = Config.TicketPrice
    st.hasTicket = Cinemas[id].tickets[Player.PlayerData.citizenid] ~= nil
    return st
end

local function nearSeller(src, id)
    local s = Config.Cinemas[id].seller.coords
    return #(GetEntityCoords(GetPlayerPed(src)) - vector3(s.x, s.y, s.z)) <= SELLER_RANGE + 1.0
end

RSGCore.Functions.CreateCallback('rsg-cinema:server:getInfo', function(src, cb, id)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not validCinema(id) or not nearSeller(src, id) then return cb(nil) end
    cb(ticketInfo(Player, id))
end)

local lastBuy = {}
RSGCore.Functions.CreateCallback('rsg-cinema:server:buyTicket', function(src, cb, id)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not validCinema(id) or not nearSeller(src, id) then return cb(nil) end
    local now = GetGameTimer()
    if lastBuy[src] and now - lastBuy[src] < 2000 then return cb(ticketInfo(Player, id)) end
    lastBuy[src] = now

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
    cb(ticketInfo(Player, id))
end)

-- A viewer's client reports the END_OF_MOVIE_MARKER; only accepted after the minimum runtime and from inside
RegisterNetEvent('rsg-cinema:server:filmEnded', function(id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not validCinema(id) then return end
    local c = Cinemas[id]
    if not c.playing or (not c.public and not c.tickets[Player.PlayerData.citizenid]) then return end
    if os.time() - c.startedAt < Config.MinShowLength then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - Config.Cinemas[id].centre) > Config.WatchRadius + 5.0 then return end
    endShow(id)
end)

-- Rejoin after relog while a show is running
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

AddEventHandler('playerDropped', function() lastBuy[source] = nil end)

---------------------------------------------------------------- admin panel
local function isAdmin(src)
    return RSGCore.Functions.HasPermission(src, Config.AdminPermission)
end

local function adminData()
    local list = {}
    for id, c in pairs(Cinemas) do
        local cfg = Config.Cinemas[id]
        local st = publicState(id)
        local films, sold = {}, 0
        for i, fi in ipairs(cfg.films) do films[#films + 1] = { index = i, label = Config.Films[fi].label } end
        for _ in pairs(c.tickets) do sold = sold + 1 end -- tickets is keyed by citizenid
        list[#list + 1] = {
            id = id, label = cfg.label, film = st.film, filmIndex = c.filmIndex, films = films,
            playing = c.playing, public = c.public, startsIn = st.startsIn,
            elapsed = c.playing and (os.time() - c.startedAt) or 0, tickets = sold, draw = cfg.draw,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

RSGCore.Functions.CreateCallback('rsg-cinema:server:adminData', function(src, cb)
    cb(isAdmin(src) and adminData() or nil)
end)

-- returns the refreshed panel data so the NUI never has to guess when the action finished
RSGCore.Functions.CreateCallback('rsg-cinema:server:adminAction', function(src, cb, action, id, filmIndex)
    if not isAdmin(src) then return cb(nil) end
    if not validCinema(id) then
        notify(src, locale('sv_bad_cinema'), 'error')
        return cb(adminData())
    end
    local c, label = Cinemas[id], Config.Cinemas[id].label
    if action == 'start' then
        if c.playing then
            notify(src, locale('sv_already_playing'), 'error')
        else
            filmIndex = math.tointeger(tonumber(filmIndex))
            if filmIndex and Config.Cinemas[id].films[filmIndex] then c.filmIndex = filmIndex end
            refundTickets(id) -- the free showing replaces the paid one: give holders their money back
            startShow(id, true)
            notify(src, locale('sv_started', label), 'success')
        end
    elseif action == 'stop' then
        if not c.playing then
            notify(src, locale('sv_not_playing'), 'error')
        else
            if not c.public then refundTickets(id) end -- paid showing cut short: refund online holders
            endShow(id)
            notify(src, locale('sv_stopped', label), 'success')
        end
    end
    cb(adminData())
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
