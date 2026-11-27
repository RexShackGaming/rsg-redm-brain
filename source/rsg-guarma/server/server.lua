local RSGCore = exports['rsg-core']:GetCoreObject()

local buyCooldown, travelCooldown, actionCooldown = {}, {}, {}
local passengers = {} -- [src] = { portId, citizenid } waiting for the next sailing
local departing = {}  -- [src] = true while a departure is being processed

-- seconds left on a cooldown (0 = ready)
local function CooldownLeft(list, src, seconds)
    local last = list[src]
    if not last then return 0 end
    return math.max(0, seconds - (os.time() - last))
end

-------------------------------------
-- sailing schedule
-------------------------------------
local function SailInterval()
    return math.floor(math.max(1, tonumber(Config.Schedule.interval) or 10) * 60)
end

-- seconds to the next departure, and whether boarding is open
local function SailingState()
    local interval = SailInterval()
    local left = interval - (os.time() % interval)
    return left, left <= Config.Schedule.boarding
end

-------------------------------------
-- ticket office data
-------------------------------------
local function RescueState(src, Player, portId)
    if not Config.Rescue.enabled or not Config.Ports[portId].rescue then return nil end
    local money = (Player.Functions.GetMoney('cash') or 0) + (Player.Functions.GetMoney('bank') or 0)
    return money < Guarma.Price(Player, Config.TicketCost)
        and Guarma.ItemCount(src, Config.TicketItem) == 0
end

local function OfficeData(src, Player, portId)
    local schedule
    if Config.Schedule.enabled then
        local left, open = SailingState()
        schedule = {
            departIn = left,
            boardingIn = math.max(0, left - Config.Schedule.boarding),
            open = open,
            boarded = passengers[src] ~= nil,
        }
    end

    return {
        price = Guarma.Price(Player, Config.TicketCost),
        returnPrice = Config.ReturnTicket.enabled and Config.MaxTickets >= 2
            and Guarma.Price(Player, Config.ReturnTicket.price) or nil,
        discount = math.floor(Guarma.Discount(Player) * 100 + 0.5),
        max = Config.MaxTickets,
        cash = Player.Functions.GetMoney('cash'),
        owned = Guarma.ItemCount(src, Config.TicketItem),
        closed = Guarma.ClosedReason(portId),
        schedule = schedule,
        rescue = RescueState(src, Player, portId) or false,
        cargo = Guarma.CargoList and Guarma.CargoList(src, portId) or nil,
        alert = Guarma.AlertLevel and Config.Ports[portId].guarma and Guarma.AlertLevel() or 0,
    }
end

RSGCore.Functions.CreateCallback('rsg-guarma:server:getOffice', function(src, cb, portId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Guarma.GetNearPort(src, portId) then return cb(false) end
    -- this builds inventory and price data, so limit how fast it can be requested
    local now = GetGameTimer()
    if actionCooldown[src] and now - actionCooldown[src] < 100 then return cb(false) end
    actionCooldown[src] = now
    cb(OfficeData(src, Player, portId))
end)

-------------------------------------
-- buy tickets (kind: 'single' or 'return')
-------------------------------------
RSGCore.Functions.CreateCallback('rsg-guarma:server:buyTicket', function(src, cb, portId, amount, kind)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local function fail(message)
        Guarma.Notify(src, message, 'error')
        cb(false)
    end

    if not Guarma.GetNearPort(src, portId) then return fail(locale('too_far')) end

    local wait = CooldownLeft(buyCooldown, src, Config.BuyCooldown)
    if wait > 0 then return fail(locale('wait_buy', wait)) end

    local basePrice
    if kind == 'return' then
        if not Config.ReturnTicket.enabled or Config.MaxTickets < 2 then return cb(false) end
        amount, basePrice = 2, Config.ReturnTicket.price
    else
        amount = math.tointeger(tonumber(amount))
        if not amount or amount < 1 or amount > Config.MaxTickets then return fail(locale('invalid_amount')) end
        basePrice = amount * Config.TicketCost
    end

    if not exports['rsg-inventory']:CanAddItem(src, Config.TicketItem, amount) then return fail(locale('no_space')) end

    local totalCost = Guarma.Price(Player, basePrice)
    if totalCost > 0 and not Player.Functions.RemoveMoney('cash', totalCost, 'guarma-boat-tickets') then
        return fail(locale('not_enough_cash'))
    end

    if not exports['rsg-inventory']:AddItem(src, Config.TicketItem, amount, nil, nil, 'guarma-boat-tickets') then
        if totalCost > 0 then Player.Functions.AddMoney('cash', totalCost, 'guarma-boat-tickets-refund') end
        return fail(locale('no_space'))
    end

    buyCooldown[src] = os.time()
    Guarma.PayPortIncome(portId, totalCost)
    Guarma.Notify(src, locale('ticket_purchased'), 'success', locale('ticket_purchased_desc', amount, totalCost))
    print(('[rsg-guarma] ^2%s (%s) bought %d boat tickets for $%s^7'):format(
        GetPlayerName(src), Player.PlayerData.citizenid, amount, totalCost))
    cb(true)
end)

-------------------------------------
-- departure
-------------------------------------
-- shared checks for boarding and departing; returns the port, or nil and the message to show
local function CheckTraveller(src, Player, portId, radius)
    if not Guarma.CanAct(Player) then return nil, locale('cannot_travel') end

    local port = Guarma.GetNearPort(src, portId, radius)
    if not port then return nil, locale('too_far') end

    -- checked before any ticket is taken
    if not Config.Ports[port.destination] then
        print(('[rsg-guarma] ^1port "%s" has an unknown destination "%s"^7'):format(portId, tostring(port.destination)))
        return nil, locale('cannot_travel')
    end

    if Guarma.ClosedReason(portId) then return nil, locale('port_closed') end
    return port
end

local function SendOnVoyage(src, destId, duration)
    travelCooldown[src] = os.time()
    local report = Guarma.CustomsSearch(src, destId)
    TriggerClientEvent('rsg-guarma:client:performTravel', src, destId, duration)
    if report then
        local cid = RSGCore.Functions.GetPlayer(src).PlayerData.citizenid
        -- after the fade out, the crossing and the fade in
        SetTimeout(math.floor(duration * 1000) + 4000, function()
            local Player = RSGCore.Functions.GetPlayer(src)
            if Player and Player.PlayerData.citizenid == cid then report() end
        end)
    end
end

local function VoyageSeconds()
    return Config.Voyage.enabled and Config.Voyage.duration or Config.TravelTime / 1000
end

local function Depart(src, portId, radius)
    if departing[src] then return end
    departing[src] = true

    local ok, err = pcall(function()
        local Player = RSGCore.Functions.GetPlayer(src)
        if not Player then return end
        local cid = Player.PlayerData.citizenid

        -- mounted / hogtied / lassoed are only known to the player's own client
        local clientReady = RSGCore.Functions.AwaitClientCallback('rsg-guarma:client:canBoard', src, 3000)

        -- everything is checked again after waiting for the client
        Player = RSGCore.Functions.GetPlayer(src)
        if not Player or Player.PlayerData.citizenid ~= cid then return end
        if clientReady ~= true then return Guarma.Notify(src, locale('missed_boat'), 'error') end

        local port, reason = CheckTraveller(src, Player, portId, radius)
        if not port then return Guarma.Notify(src, reason, 'error') end

        if not exports['rsg-inventory']:RemoveItem(src, Config.TicketItem, 1, nil, 'guarma-boat-travel') then
            return Guarma.Notify(src, locale('no_ticket'), 'error')
        end

        SendOnVoyage(src, port.destination, VoyageSeconds())
        print(('[rsg-guarma] ^3%s (%s) sailed to %s^7'):format(GetPlayerName(src), cid, port.destination))
    end)

    departing[src] = nil
    if not ok then print(('^1[rsg-guarma] departure failed: %s^7'):format(err)) end
end

-- travel now, or board the next sailing when the schedule is on
RegisterNetEvent('rsg-guarma:server:requestTravel', function(portId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or passengers[src] or departing[src] then return end

    local port, reason = CheckTraveller(src, Player, portId)
    if not port then return Guarma.Notify(src, reason, 'error') end

    local wait = CooldownLeft(travelCooldown, src, Config.TravelCooldown)
    if wait > 0 then return Guarma.Notify(src, locale('wait_travel', wait), 'error') end

    if Guarma.ItemCount(src, Config.TicketItem) < 1 then
        return Guarma.Notify(src, locale('no_ticket'), 'error')
    end

    if not Config.Schedule.enabled then
        return Depart(src, portId, Config.InteractRadius)
    end

    local left, open = SailingState()
    if not open then
        return Guarma.Notify(src, locale('boarding_not_open', left - Config.Schedule.boarding), 'error')
    end

    passengers[src] = { portId = portId, citizenid = Player.PlayerData.citizenid }
    Guarma.Notify(src, locale('boarded'), 'success', locale('boarded_desc'))
    TriggerClientEvent('rsg-guarma:client:boarded', src, portId, left)
end)

RegisterNetEvent('rsg-guarma:server:cancelBoarding', function()
    local src = source
    if not passengers[src] then return end
    passengers[src] = nil
    TriggerClientEvent('rsg-guarma:client:boardingEnded', src)
    Guarma.Notify(src, locale('boarding_cancelled'), 'inform')
end)

if Config.Schedule.enabled then
    CreateThread(function()
        local lastSailing = os.time() // SailInterval()
        while true do
            Wait(1000)
            local sailing = os.time() // SailInterval()
            if sailing ~= lastSailing then
                lastSailing = sailing
                local leaving = passengers
                passengers = {}
                for src, passenger in pairs(leaving) do
                    -- one thread each, so a slow client doesn't delay the others
                    CreateThread(function()
                        local Player = RSGCore.Functions.GetPlayer(src)
                        if not Player or Player.PlayerData.citizenid ~= passenger.citizenid then return end
                        TriggerClientEvent('rsg-guarma:client:boardingEnded', src)
                        Depart(src, passenger.portId, Config.Schedule.boardRadius)
                    end)
                end
            end
        end
    end)
end

-------------------------------------
-- rescue passage
-------------------------------------
local rescueBusy = {}

local function Rescue(src, portId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or passengers[src] or departing[src] then return end
    if not Config.Rescue.enabled then return end
    local cid = Player.PlayerData.citizenid

    local record = Guarma.GetRecord(cid) -- may yield, so every check comes after it
    if not record then return Guarma.Notify(src, locale('trade_unavailable'), 'error') end
    Player = RSGCore.Functions.GetPlayer(src)
    if not Player or Player.PlayerData.citizenid ~= cid or departing[src] then return end

    local port, reason = CheckTraveller(src, Player, portId)
    if not port then return Guarma.Notify(src, reason, 'error') end
    if not RescueState(src, Player, portId) then return Guarma.Notify(src, locale('rescue_not_stranded'), 'error') end
    if Guarma.CargoCount and Guarma.CargoCount(src) > 0 then
        return Guarma.Notify(src, locale('rescue_no_cargo'), 'error')
    end

    local wait = record.rescueAt + Config.Rescue.cooldown * 60 - os.time()
    if wait > 0 then return Guarma.Notify(src, locale('rescue_wait', math.ceil(wait / 60)), 'error') end

    -- the travel cooldown also covers the whole crossing
    local travelWait = CooldownLeft(travelCooldown, src, math.max(Config.TravelCooldown, Config.Rescue.voyage + 10))
    if travelWait > 0 then return Guarma.Notify(src, locale('wait_travel', travelWait), 'error') end

    record.rescueAt = os.time()
    Guarma.SaveRecord(cid)
    SendOnVoyage(src, port.destination, Config.Rescue.voyage)
    print(('[rsg-guarma] ^3%s (%s) took the rescue passage to %s^7'):format(GetPlayerName(src), cid, port.destination))
end

RegisterNetEvent('rsg-guarma:server:requestRescue', function(portId)
    local src = source
    if rescueBusy[src] then return end
    rescueBusy[src] = true
    local ok, err = pcall(Rescue, src, portId)
    rescueBusy[src] = nil
    if not ok then print(('^1[rsg-guarma] rescue passage failed: %s^7'):format(err)) end
end)

-------------------------------------
-- guarma weather (one shared weather for the island)
-------------------------------------
local function PickIslandWeather()
    local total = 0
    for _, weight in pairs(Config.Weather.types) do
        total = total + weight
    end
    if total <= 0 then return 'highpressure' end

    local roll = math.random() * total
    for weather, weight in pairs(Config.Weather.types) do
        roll = roll - weight
        if roll <= 0 then return weather end
    end
    return 'highpressure'
end

if Config.Weather.enabled then
    CreateThread(function()
        while true do
            GlobalState.guarmaWeather = PickIslandWeather()
            -- never below 1 minute, so a bad config value can't spin the server
            Wait(math.floor(math.max(1, tonumber(Config.Weather.interval) or 20) * 60000))
        end
    end)
end

-------------------------------------
-- cleanup
-------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    buyCooldown[src] = nil
    travelCooldown[src] = nil
    actionCooldown[src] = nil
    passengers[src] = nil
end)
