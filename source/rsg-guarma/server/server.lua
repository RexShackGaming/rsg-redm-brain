local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local buyCooldown, travelCooldown = {}, {}

local function Notify(src, title, nType, description)
    TriggerClientEvent('ox_lib:notify', src, { title = title, description = description, type = nType or 'inform', duration = 5000 })
end

local function OnCooldown(list, src, seconds)
    local now = os.time()
    if list[src] and now - list[src] < seconds then return true end
    return false
end

-- returns the port if the player is standing near it
local function GetNearPort(src, portId)
    local port = type(portId) == 'string' and Config.Ports[portId]
    if not port then return nil end
    local pedCoords = GetEntityCoords(GetPlayerPed(src))
    if #(pedCoords - port.npccoords.xyz) > Config.InteractRadius then return nil end
    return port
end

-------------------------------------
-- buy tickets
-------------------------------------
lib.callback.register('rsg-guarma:server:buyTicket', function(src, portId, amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    if not GetNearPort(src, portId) then Notify(src, locale('too_far'), 'error') return false end
    if OnCooldown(buyCooldown, src, Config.BuyCooldown) then Notify(src, locale('wait_buy'), 'error') return false end

    amount = math.tointeger(tonumber(amount))
    if not amount or amount < 1 or amount > Config.MaxTickets then
        Notify(src, locale('invalid_amount'), 'error')
        return false
    end
    buyCooldown[src] = os.time()

    if not exports['rsg-inventory']:CanAddItem(src, Config.TicketItem, amount) then
        Notify(src, locale('no_space'), 'error')
        return false
    end

    local totalCost = amount * Config.TicketCost
    if not Player.Functions.RemoveMoney('cash', totalCost, 'guarma-boat-tickets') then
        Notify(src, locale('not_enough_cash'), 'error')
        return false
    end

    exports['rsg-inventory']:AddItem(src, Config.TicketItem, amount, nil, nil, 'guarma-boat-tickets')
    Notify(src, locale('ticket_purchased'), 'success', locale('ticket_purchased_desc', amount, totalCost))
    print(('[rsg-guarma] ^2%s (%s) bought %d boat tickets for $%d^7'):format(GetPlayerName(src), Player.PlayerData.citizenid, amount, totalCost))
    return true
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
    if not port then return Notify(src, locale('too_far'), 'error') end
    if OnCooldown(travelCooldown, src, Config.TravelCooldown) then return Notify(src, locale('wait_travel'), 'error') end

    if not exports['rsg-inventory']:RemoveItem(src, Config.TicketItem, 1, nil, 'guarma-boat-travel') then
        return Notify(src, locale('no_ticket'), 'error')
    end
    travelCooldown[src] = os.time()

    TriggerClientEvent('rsg-guarma:client:performTravel', src, port.destination)
    print(('[rsg-guarma] ^3%s (%s) travelled to %s^7'):format(GetPlayerName(src), Player.PlayerData.citizenid, port.destination))
end)

-------------------------------------
-- guarma weather (one shared weather for the island)
-------------------------------------
local function PickIslandWeather()
    local total = 0
    for _, weight in pairs(Config.Weather.types) do total = total + weight end
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
    buyCooldown[source], travelCooldown[source] = nil, nil
end)
