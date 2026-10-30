---------------------------------------------------------------
-- TRAIN TICKETS (passenger side)
-- When the player boards a train they are NOT driving, the server
-- consumes a ticket (or charges the on-board markup). No ticket and no
-- cash = kicked off. Drivers of their own spawned train are never charged.
---------------------------------------------------------------
local onTrain = false
local ticketed = false -- true once this ride was paid for

local function GetTicketCompany(train)
    if train ~= 0 and ActiveTrain and train == ActiveTrain and ActiveTrainConfig then
        return ActiveTrainConfig.company
    end

    local pcoords = GetEntityCoords(cache.ped)
    local nearestDist, nearestCompany = math.huge, nil
    for _, station in ipairs(Config.Stations) do
        local dist = #(pcoords - station.coords)
        if dist < nearestDist then
            nearestDist, nearestCompany = dist, station.company
        end
    end
    return nearestCompany
end

local function KickOffTrain()
    SetTimeout(2000, function()
        local ped = cache.ped
        local coords = GetEntityCoords(ped)
        ClearPedTasksImmediately(ped)
        SetEntityCoords(ped, coords.x + 10.0, coords.y + 10.0, coords.z, false, false, false, false)
        Wait(500)
        PlaceEntityOnGroundProperly(ped)
    end)
end

local function CheckTicket(train)
    local result = lib.callback.await('rsg-railroad:server:useTicket', false, GetTicketCompany(train))

    ticketed = result == 'has_ticket' or result == 'bought_ticket'
    if result == 'has_ticket' then
        lib.notify({ title = locale('ticket_valid_title'), description = locale('ticket_valid_desc'), type = 'success', position = 'top-right', duration = 5000 })
    elseif result == 'bought_ticket' then
        lib.notify({
            title = locale('ticket_purchased_title'),
            description = locale('ticket_purchased_desc', string.format('%.2f', Config.MarkupPrice), string.format('%.2f', Config.TicketPrice)),
            type = 'warning', position = 'top-right', duration = 7000,
        })
    else
        lib.notify({
            title = locale('no_ticket_title'),
            description = locale('no_ticket_desc', string.format('%.2f', Config.MarkupPrice)),
            type = 'error', position = 'top-right', duration = 5000,
        })
        KickOffTrain()
    end
end

-- Trolleys run their own fare system (rsg-trams). Skip them by the state bag that
-- rsg-trams sets on every car, and fall back to the trolley model in case the bag
-- hasn't synced yet when the player boards.
local FREE_MODELS = {
    [`trolley01x`] = true,
}

local function IsOwnFareVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    if Entity(veh).state.ownFare or Entity(veh).state.rsgTram then return true end
    return FREE_MODELS[GetEntityModel(veh)] == true
end

-- While boarding, IsPedInAnyTrain is already true but GetVehiclePedIsIn(ped, false)
-- can still be 0, so try every way of finding the car the ped is getting into.
local function GetBoardedTrain(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = GetVehiclePedIsUsing(ped) end
    if veh == 0 then veh = GetVehiclePedIsIn(ped, true) end
    return veh
end

-- Backup: any rsg-trams trolley (or one of its cars) right next to the player
local function NearTrolley(ped)
    local pcoords = GetEntityCoords(ped)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if IsOwnFareVehicle(veh) and #(GetEntityCoords(veh) - pcoords) < 12.0 then return true end
    end
    return false
end

CreateThread(function()
    while true do
        local ped = cache.ped
        local inTrain = IsPedInAnyTrain(ped)

        if inTrain and not onTrain then
            onTrain = true
            local train = GetBoardedTrain(ped)
            -- Driving your own train is free, and trolleys (rsg-trams) charge their own fare
            if not (ActiveTrain and train == ActiveTrain) and not IsOwnFareVehicle(train) and not NearTrolley(ped) then
                CheckTicket(train)
            end
        elseif not inTrain and onTrain then
            onTrain = false
            if ticketed then
                ticketed = false
                lib.notify({ title = locale('journey_complete_title'), description = locale('journey_complete_desc'), type = 'success', position = 'top-right', duration = 5000 })
            end
        end

        Wait(1000)
    end
end)
