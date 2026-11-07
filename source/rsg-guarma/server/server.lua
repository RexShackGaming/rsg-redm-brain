local RSGCore = exports['rsg-core']:GetCoreObject()

local buyCooldown, travelCooldown = {}, {}

local function Notify(src, title, nType, description)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = title,
        description = description,
        type = nType or 'inform',
        duration = 5000,
    })
end

local function OnCooldown(list, src, seconds)
    local last = list[src]
    if not last then return false end
    return (os.time() - last) < seconds
end

-- returns the port if the player is standing near it
local function GetNearPort(src, portId)
    local port = type(portId) == 'string' and Config.Ports[portId]
    if not port then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    if #(GetEntityCoords(ped) - port.npccoords.xyz) > Config.InteractRadius then return nil end
    return port
end

-------------------------------------
-- buy tickets
-------------------------------------
RSGCore.Functions.CreateCallback('rsg-guarma:server:buyTicket', function(src, cb, portId, amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    if not GetNearPort(src, portId) then
        Notify(src, locale('too_far'), 'error')
        return cb(false)
    end

    if OnCooldown(buyCooldown, src, Config.BuyCooldown) then
        Notify(src, locale('wait_buy'), 'error')
        return cb(false)
    end

    amount = math.tointeger(tonumber(amount))
    if not amount or amount < 1 or amount > Config.MaxTickets then
        Notify(src, locale('invalid_amount'), 'error')
        return cb(false)
    end

    if not RSGCore.Shared.Items[Config.TicketItem] then
        Notify(src, locale('invalid_amount'), 'error')
        return cb(false)
    end

    if not exports['rsg-inventory']:CanAddItem(src, Config.TicketItem, amount) then
        Notify(src, locale('no_space'), 'error')
        return cb(false)
    end

    local totalCost = amount * Config.TicketCost
    if not Player.Functions.RemoveMoney('cash', totalCost, 'guarma-boat-tickets') then
        Notify(src, locale('not_enough_cash'), 'error')
        return cb(false)
    end

    local added = exports['rsg-inventory']:AddItem(src, Config.TicketItem, amount, nil, nil, 'guarma-boat-tickets')
    if not added then
        Player.Functions.AddMoney('cash', totalCost, 'guarma-boat-tickets-refund')
        Notify(src, locale('no_space'), 'error')
        return cb(false)
    end

    buyCooldown[src] = os.time()
    Notify(src, locale('ticket_purchased'), 'success', locale('ticket_purchased_desc', amount, totalCost))
    print(('[rsg-guarma] ^2%s (%s) bought %d boat tickets for $%d^7'):format(
        GetPlayerName(src),
        Player.PlayerData.citizenid,
        amount,
        totalCost
    ))
    cb(true)
end)

-------------------------------------
-- request travel
-------------------------------------
RegisterNetEvent('rsg-guarma:server:requestTravel', function(portId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local meta = Player.PlayerData.metadata
    if meta.isdead or meta.ishandcuffed or (tonumber(meta.injail) or 0) > 0 then
        return Notify(src, locale('cannot_travel'), 'error')
    end

    local port = GetNearPort(src, portId)
    if not port then
        return Notify(src, locale('too_far'), 'error')
    end

    if OnCooldown(travelCooldown, src, Config.TravelCooldown) then
        return Notify(src, locale('wait_travel'), 'error')
    end

    if not exports['rsg-inventory']:RemoveItem(src, Config.TicketItem, 1, nil, 'guarma-boat-travel') then
        return Notify(src, locale('no_ticket'), 'error')
    end

    travelCooldown[src] = os.time()
    TriggerClientEvent('rsg-guarma:client:performTravel', src, port.destination)
    print(('[rsg-guarma] ^3%s (%s) travelled to %s^7'):format(
        GetPlayerName(src),
        Player.PlayerData.citizenid,
        port.destination
    ))
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
            Wait(Config.Weather.interval * 60000)
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
end)
