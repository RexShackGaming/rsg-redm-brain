local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local tickets = {}      -- [citizenid] = true (valid for the next show)
local cooldowns = {}    -- [src] = os.time()
local nextShowIndex = 1
local nextShowTime = 0
local showRunning = false
local showId = 0          -- increments every show, so stale timeouts/reports are ignored
local watching = {}        -- [src] = true while that player is watching the current show
local pendingStart = false -- an admin restart is waiting to start; keeps the scheduler out of the gap

local function getShowIndexById(id)
    for i, show in ipairs(Config.Shows) do
        if show.id == id then return i end
    end
end

local function pickNextShow()
    if Config.ShowOrder == 'random' then
        nextShowIndex = math.random(1, #Config.Shows)
    else
        nextShowIndex = (nextShowIndex % #Config.Shows) + 1
    end
end

local function notify(src, desc, type)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('sv_title'), description = desc, type = type })
end

local function endShow(id)
    if id ~= showId or not showRunning then return end
    showRunning = false
    watching = {}
end

local function startShow(index)
    if showRunning then return false end
    local show = Config.Shows[index]
    if not show then return false end
    showRunning = true
    showId = showId + 1
    local id = showId

    local audience = 0
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player then
            local cid = Player.PlayerData.citizenid
            local dist = #(GetEntityCoords(GetPlayerPed(src)) - Config.Stage)
            if dist <= Config.AudienceRadius then
                if tickets[cid] then
                    tickets[cid] = nil
                    audience = audience + 1
                    watching[src] = true
                    TriggerClientEvent('rsg-theatre:client:playShow', src, index)
                else
                    notify(src, locale('sv_no_ticket'), 'error')
                end
            end
        end
    end

    if Config.Debug then print(('[rsg-theatre] %s started for %d player(s)'):format(show.id, audience)) end

    if audience == 0 then
        endShow(id)                                            -- nobody watching, nothing to wait for
    else
        SetTimeout(Config.MaxShowLength * 1000, function() endShow(id) end) -- safety cap
    end
    return true
end

-- the show ends when every viewer's client has finished (or left)
local function viewerDone(src)
    if not watching[src] then return end
    watching[src] = nil
    if next(watching) == nil then endShow(showId) end
end

RegisterNetEvent('rsg-theatre:server:showFinished', function()
    viewerDone(source)
end)

-- scheduler
CreateThread(function()
    nextShowIndex = Config.ShowOrder == 'random' and math.random(1, #Config.Shows) or 1
    nextShowTime = os.time() + (Config.FirstShowDelay * 60)
    while true do
        Wait(5000)
        -- if an admin-forced show is still running, hold the scheduled one until it ends
        if not showRunning and not pendingStart and os.time() >= nextShowTime then
            startShow(nextShowIndex)
            pickNextShow()
            nextShowTime = os.time() + (Config.ShowInterval * 60)
        end
    end
end)

lib.callback.register('rsg-theatre:server:getPlaybill', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local show = Config.Shows[nextShowIndex]
    return {
        label = locale('show_' .. show.id),
        description = locale('show_' .. show.id .. '_desc'),
        minutes = math.max(0, math.ceil((nextShowTime - os.time()) / 60)),
        price = Config.TicketPrice,
        hasTicket = tickets[Player.PlayerData.citizenid] == true,
        running = showRunning,
    }
end)

RegisterNetEvent('rsg-theatre:server:buyTicket', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    if cooldowns[src] and now - cooldowns[src] < Config.TicketCooldown then return end
    cooldowns[src] = now

    local seller = Config.TicketSeller.coords
    if #(GetEntityCoords(GetPlayerPed(src)) - seller.xyz) > Config.TicketSeller.buyDistance then
        return
    end

    local cid = Player.PlayerData.citizenid
    if tickets[cid] then
        return notify(src, locale('sv_already_ticket'), 'inform')
    end

    if not Player.Functions.RemoveMoney('cash', Config.TicketPrice, 'theatre-ticket') then
        return notify(src, locale('sv_no_money'), 'error')
    end

    tickets[cid] = true
    notify(src, locale('sv_ticket_bought', locale('show_' .. Config.Shows[nextShowIndex].id)), 'success')
end)

lib.addCommand(Config.AdminCommand, {
    help = locale('cmd_help'),
    params = { { name = 'show', type = 'string', help = locale('cmd_param'), optional = true } },
    restricted = 'group.' .. Config.AdminPermission,
}, function(src, args)
    local index = args.show and getShowIndexById(args.show) or nextShowIndex
    if not index then
        local ids = {}
        for _, s in ipairs(Config.Shows) do ids[#ids + 1] = s.id end
        return notify(src, locale('cmd_unknown', table.concat(ids, ', ')), 'error')
    end
    -- admin gets a free ticket so they can watch
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then tickets[Player.PlayerData.citizenid] = true end
    if showRunning then
        -- stop the current show for everyone watching, then start the new one once they've cleaned up
        notify(src, locale('cmd_stopping'), 'inform')
        for viewer in pairs(watching) do TriggerClientEvent('rsg-theatre:client:stopShow', viewer) end
        endShow(showId)
        pendingStart = true
        SetTimeout(3000, function()
            pendingStart = false
            startShow(index)
        end)
        return
    end
    if pendingStart then
        return notify(src, locale('cmd_stopping'), 'inform')
    end
    startShow(index)
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
    viewerDone(source)
end)
