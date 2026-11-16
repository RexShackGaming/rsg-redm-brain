local RSGCore = exports['rsg-core']:GetCoreObject()

-- [source] = { id = trainDbId (0 for company/config trains), model = string, tc = Config.Trains entry }
-- Filled in once at deploy time (after ownership is verified) so the frequent
-- state-sync events never have to hit the database to authorise the caller.
local ActiveTrains = {}
local lastMilesAt = {} -- [source] = os.time() of the last accepted addMiles

local SERVER_INTERACT_RADIUS = Config.ServerInteractRadius or 25.0 -- metres from a station for menu actions
local SPAWN_STATION_RADIUS   = 150.0                               -- deploy point is up to ~55 m from the station marker

---------------------------------------------------------------
-- SHARED SERVER HELPERS (globals used by the other server files)
---------------------------------------------------------------

-- Looks up the Config.Trains entry that matches a DB train row.
function GetTrainConfig(train)
    for _, tc in ipairs(Config.Trains) do
        if tc.model == train.train_model and tc.company == train.company_id then
            return tc
        end
    end
    return nil
end

-- true when this player currently has a train out (tracked server-side).
function HasActiveTrain(src)
    return ActiveTrains[src] ~= nil
end

-- Releases the player's train: forgets it, wipes its storage and drops any
-- half-finished mission leg.
function ClearActiveTrain(src)
    ActiveTrains[src] = nil
    lastMilesAt[src] = nil
    if TrainStorage then TrainStorage.OnPutAway(src) end
    if ClearMissionSession then ClearMissionSession(src) end
    if ClearRobberySession then ClearRobberySession(src) end
end

-- Server-authoritative player position (OneSync).
function GetPlayerCoordsServer(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- Returns the closest Config.Stations entry within `radius` of the player.
function GetNearbyStation(src, radius)
    local coords = GetPlayerCoordsServer(src)
    if not coords then return nil end
    local best, bestDist
    for _, station in ipairs(Config.Stations) do
        local dist = #(coords - station.coords)
        if dist <= radius and (not bestDist or dist < bestDist) then
            best, bestDist = station, dist
        end
    end
    return best
end

-- true (plus the station) when the player is standing at a station, optionally
-- one that belongs to `companyId`. Used to stop menu actions being fired from
-- anywhere on the map.
function IsAtStation(src, companyId, radius)
    local coords = GetPlayerCoordsServer(src)
    if not coords then return false end
    radius = radius or SERVER_INTERACT_RADIUS
    for _, station in ipairs(Config.Stations) do
        if (not companyId or station.company == companyId) and #(coords - station.coords) <= radius then
            return true, station
        end
    end
    return false
end

-- IsAtStation + a player notification on failure.
function RequireStation(src, companyId)
    if IsAtStation(src, companyId) then return true end
    NotifyPlayer(src, locale('not_at_station'), 'error')
    return false
end

-- Returns role ('owner' | 'driver' | nil), the ownership row and the employee row.
function GetCompanyRole(companyId, citizenid)
    if not companyId or not Config.Companies[companyId] then return nil end
    local ownership = DB.GetCompanyOwnership(companyId)
    if not ownership then return nil end
    if ownership.owner_citizenid == citizenid then return 'owner', ownership end
    local employee = DB.GetEmployeeByIds(companyId, citizenid)
    if employee and employee.status == 'approved' then return 'driver', ownership, employee end
    return nil, ownership
end

function CompanyLabel(companyId)
    return Config.Companies[companyId] and Config.Companies[companyId].label or tostring(companyId)
end

function NotifyPlayer(src, description, nType, duration)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'),
        description = description,
        type = nType or 'inform',
        duration = duration or 5000,
    })
end

local function Clamp(value, max)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > max then return max end
    return value
end

-- Returns the cached deployment when `trainId` is the personal (database) train
-- this player deployed. Ownership was verified at deploy time. Company trains
-- (id 0) have no database row, so there is nothing to persist for them.
local function GetAuthorizedTrain(src, trainId)
    local active = ActiveTrains[src]
    trainId = tonumber(trainId)
    if not active or active.id == 0 or not trainId or active.id ~= trainId then return nil end
    return active
end

local function FindConfigTrain(model)
    for _, tc in ipairs(Config.Trains) do
        if tc.model == model then return tc end
    end
    return nil
end

---------------------------------------------------------------
-- CALLBACKS
---------------------------------------------------------------
RegisterCallback('rsg-railroad:getOwnedTrains', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end
    return DB.GetOwnedTrains(Player.PlayerData.citizenid) or {}
end)

-- Only returns the row when the caller owns it.
RegisterCallback('rsg-railroad:getTrainById', function(source, trainId)
    local Player = RSGCore.Functions.GetPlayer(source)
    trainId = tonumber(trainId)
    if not Player or not trainId then return nil end
    local train = DB.GetTrainById(trainId)
    if not train or train.citizenid ~= Player.PlayerData.citizenid then return nil end
    return train
end)

RegisterCallback('rsg-railroad:canSpawnTrain', function(source)
    return ActiveTrains[source] == nil
end)

RegisterCallback('rsg-railroad:getAmbientState', function()
    return DB.GetOwnedCompanyCount() == 0
end)

RegisterCallback('rsg-railroad:getMyCompanyMembership', function(source, companyId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return nil end
    return DB.GetCompanyMembership(Player.PlayerData.citizenid, companyId)
end)

---------------------------------------------------------------
-- BUY TRAIN
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:buyTrain', function(trainIndex)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local trainConfig = Config.Trains[tonumber(trainIndex) or -1]
    if not trainConfig then return end
    if not RequireStation(src, trainConfig.company) then return end

    if DB.CountTrains(citizenid) >= Config.MaxTrainsPerPlayer then
        NotifyPlayer(src, locale('train_limit_reached', Config.MaxTrainsPerPlayer), 'error')
        return
    end

    local requiredRankLabel = Config.Ranks[trainConfig.requiredRank] and Config.Ranks[trainConfig.requiredRank].label or locale('unknown')
    local membership = DB.GetCompanyMembership(citizenid, trainConfig.company)
    if (membership and membership.rank or 1) < trainConfig.requiredRank then
        NotifyPlayer(src, locale('rank_too_low', requiredRankLabel), 'error')
        return
    end

    if not Player.Functions.RemoveMoney('cash', trainConfig.cost, 'railroad-buy-train') then
        NotifyPlayer(src, locale('not_enough_money'), 'error')
        return
    end

    if not membership then DB.JoinCompany(citizenid, trainConfig.company) end

    -- New trains start at 50% fuel, water and condition
    DB.InsertTrain(citizenid, trainConfig.company, trainConfig.model, trainConfig.label,
        math.floor(trainConfig.maxFuel * 0.5), math.floor(trainConfig.maxWater * 0.5), math.floor(trainConfig.maxCondition * 0.5))
    NotifyPlayer(src, locale('train_bought_half', locale('train_bought')), 'success', 7000)

    Webhook.SendFields('economy', 'Train Purchased', {
        { 'Player', GetPlayerFullName(Player) .. ' (' .. citizenid .. ')' },
        { 'Company', CompanyLabel(trainConfig.company) },
        { 'Train', trainConfig.label },
        { 'Cost', '$' .. trainConfig.cost },
    }, 'success')
end)

---------------------------------------------------------------
-- SELL TRAIN
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:sellTrain', function(trainId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    trainId = tonumber(trainId)
    local citizenid = Player.PlayerData.citizenid
    local train = trainId and DB.GetTrainById(trainId)
    if not train or train.citizenid ~= citizenid then return end
    if not RequireStation(src) then return end

    if ActiveTrains[src] and ActiveTrains[src].id == trainId then
        NotifyPlayer(src, locale('park_before_selling'), 'error')
        return
    end

    local tc = GetTrainConfig(train)
    local sellPrice = tc and tc.sellPrice or 0

    -- Only pay out if this call actually deleted the row (blocks double-sell spam).
    if (DB.DeleteTrain(trainId, citizenid) or 0) < 1 then return end
    if sellPrice > 0 then Player.Functions.AddMoney('cash', sellPrice, 'railroad-sell-train') end
    NotifyPlayer(src, locale('train_sold', sellPrice), 'success')

    Webhook.SendFields('economy', 'Train Sold', {
        { 'Player', GetPlayerFullName(Player) .. ' (' .. citizenid .. ')' },
        { 'Train', train.train_model },
        { 'Sell Price', '$' .. sellPrice },
    }, 'info')
end)

---------------------------------------------------------------
-- TICKET REVENUE (continuous passenger system)
-- Paid when the driver stops at a station with passengers on board.
---------------------------------------------------------------
local TICKET_REVENUE_COOLDOWN = 30 -- seconds between payouts
local lastTicketRevenue = {}       -- [source] = { time = os.time(), station = id }

RegisterNetEvent('rsg-railroad:ticketRevenue', function(companyId, passengerCount)
    local src    = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local cfg = Config.PassengerSystem
    if not cfg or not cfg.Enabled then return end

    local citizenid = Player.PlayerData.citizenid
    local role = GetCompanyRole(companyId, citizenid)
    if not role then return end

    -- Must actually be driving a train, stopped at a real station (server-side
    -- position), and not the same station that paid out last time.
    if not HasActiveTrain(src) then return end
    local station = GetNearbyStation(src, cfg.StationStopRadius or 135.0)
    if not station then return end

    local now  = os.time()
    local last = lastTicketRevenue[src]
    if last and ((now - last.time) < TICKET_REVENUE_COOLDOWN or last.station == station.id) then return end

    passengerCount = math.floor(tonumber(passengerCount) or 0)
    if passengerCount <= 0 then return end
    passengerCount = math.min(passengerCount, cfg.MaxBoardPerStop or 10)
    lastTicketRevenue[src] = { time = now, station = station.id }

    local total       = passengerCount * cfg.TicketPrice
    local compShare   = math.floor(total * cfg.CompanyShare)
    local driverShare = math.floor(total - compShare)

    if driverShare > 0 then Player.Functions.AddMoney('cash', driverShare, 'railroad-ticket-revenue') end
    if compShare > 0 then DB.AddToCashRegister(companyId, compShare) end

    local xpGain = passengerCount * cfg.TicketXP
    AddCompanyXP(src, citizenid, companyId, xpGain)

    NotifyPlayer(src, locale('ticket_revenue_summary', driverShare, compShare, xpGain), 'success', 7000)
end)

---------------------------------------------------------------
-- SPAWN / DESPAWN TRACKING
---------------------------------------------------------------
-- `model` is sent by the client so train storage can size the stash per model.
RegisterNetEvent('rsg-railroad:setTrainSpawned', function(spawned, trainId, model)
    local src = source
    if not spawned then
        ClearActiveTrain(src)
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if ActiveTrains[src] then return end -- already has a train out (also covers 'Reverse Direction')

    -- A train can only be deployed from a station.
    if not GetNearbyStation(src, SPAWN_STATION_RADIUS) then return end

    -- trainId is 0 for company/config trains (no DB row); personal trains
    -- (trainId > 0) need ownership verification.
    trainId = tonumber(trainId) or 0
    local tc
    if trainId > 0 then
        local train = DB.GetTrainById(trainId)
        if not train or train.citizenid ~= Player.PlayerData.citizenid then return end
        DB.UnparkTrain(trainId)
        model = train.train_model
        tc = GetTrainConfig(train)
    else
        if type(model) ~= 'string' then return end
        tc = FindConfigTrain(model)
        if not tc then return end
    end

    ActiveTrains[src] = { id = trainId, model = model, tc = tc }
    lastMilesAt[src] = nil

    -- Fresh deployment, so create a fresh (empty) stash.
    if TrainStorage then TrainStorage.OnSpawn(src, model) end
end)

---------------------------------------------------------------
-- PARK / STATE UPDATES (personal trains only)
---------------------------------------------------------------
local function Limits(active)
    local tc = active.tc
    return tc and tc.maxFuel or 100, tc and tc.maxWater or 100, tc and tc.maxCondition or 100
end

RegisterNetEvent('rsg-railroad:parkTrain', function(trainId, _, fuel, water, condition)
    local src = source
    local active = ActiveTrains[src]
    if not active then return end

    -- Company trains have no database row: just release the slot.
    if active.id == 0 then
        ClearActiveTrain(src)
        return
    end
    if tonumber(trainId) ~= active.id then return end

    -- The parking station comes from the player's real position, never the client.
    local station = GetNearbyStation(src, 100.0)
    if not station then return end

    local maxFuel, maxWater, maxCondition = Limits(active)
    DB.ParkTrain(active.id, station.id, Clamp(fuel, maxFuel), Clamp(water, maxWater), Clamp(condition, maxCondition))
    ClearActiveTrain(src) -- STRICT: parking destroys anything left in train storage
end)

RegisterNetEvent('rsg-railroad:updateTrainState', function(trainId, fuel, water, condition)
    local active = GetAuthorizedTrain(source, trainId)
    if not active then return end
    local maxFuel, maxWater, maxCondition = Limits(active)
    DB.UpdateTrainState(active.id, Clamp(fuel, maxFuel), Clamp(water, maxWater), Clamp(condition, maxCondition))
end)

RegisterNetEvent('rsg-railroad:updateFuel', function(trainId, fuel)
    local active = GetAuthorizedTrain(source, trainId)
    if not active then return end
    DB.UpdateTrainFuel(active.id, Clamp(fuel, (Limits(active))))
end)

RegisterNetEvent('rsg-railroad:updateWater', function(trainId, water)
    local active = GetAuthorizedTrain(source, trainId)
    if not active then return end
    local _, maxWater = Limits(active)
    DB.UpdateTrainWater(active.id, Clamp(water, maxWater))
end)

RegisterNetEvent('rsg-railroad:updateCondition', function(trainId, condition)
    local active = GetAuthorizedTrain(source, trainId)
    if not active then return end
    local _, _, maxCondition = Limits(active)
    DB.UpdateTrainCondition(active.id, Clamp(condition, maxCondition))
end)

-- total_miles drives milestone rewards, so credit is capped by how far the
-- train could physically have travelled since the last accepted report.
local MIN_MILES_INTERVAL = 5 -- seconds between accepted reports (client reports every 10 s)
local MAX_MILES_WINDOW   = 30 -- seconds of travel credited at most per report

RegisterNetEvent('rsg-railroad:addMiles', function(trainId, miles)
    local src = source
    local active = GetAuthorizedTrain(src, trainId)
    if not active then return end

    miles = tonumber(miles)
    if not miles or miles ~= miles or miles <= 0 then return end

    local now = os.time()
    local elapsed = math.min(now - (lastMilesAt[src] or (now - 10)), MAX_MILES_WINDOW)
    if elapsed < MIN_MILES_INTERVAL then return end
    lastMilesAt[src] = now

    -- Client conversion is metres / 100; allow 1.5x the train's top speed for upgrades.
    local topSpeed = (active.tc and active.tc.maxSpeed or 30) * 1.5
    DB.AddMiles(active.id, math.min(miles, topSpeed * elapsed / 100.0))
end)

---------------------------------------------------------------
-- MAINTENANCE (coal / water / oil) - works for config + DB trains
-- The item is picked by the server from the maintenance type, never
-- taken from the client. Each item adds 10% of max capacity.
---------------------------------------------------------------
local MAINTENANCE = {
    fuel      = { cfg = 'Fuel',      col = 'fuel',      max = 'maxFuel',      update = 'UpdateTrainFuel' },
    water     = { cfg = 'Water',     col = 'water',     max = 'maxWater',     update = 'UpdateTrainWater' },
    condition = { cfg = 'Condition', col = 'condition', max = 'maxCondition', update = 'UpdateTrainCondition' },
}

RegisterNetEvent('rsg-railroad:useMaintenanceItem', function(mType, trainId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local m = MAINTENANCE[mType]
    if not Player or not m then return end

    local function fail()
        TriggerClientEvent('rsg-railroad:maintenanceResult', src, mType, false)
    end

    -- The train is the one this player deployed; the client-sent id is ignored.
    local active = ActiveTrains[src]
    if not active then return fail() end

    local train = active.id > 0 and DB.GetTrainById(active.id) or nil
    if active.id > 0 and not train then return fail() end

    local itemName = Config[m.cfg].item
    if not exports['rsg-inventory']:RemoveItem(src, itemName, 1, nil, 'railroad-maintenance') then
        NotifyPlayer(src, locale('missing_required_item'), 'error')
        return fail()
    end

    if train then
        local maxVal = active.tc and active.tc[m.max] or 100
        DB[m.update](train.id, math.min((train[m.col] or 0) + math.floor(maxVal * 0.10), maxVal))
    end

    TriggerClientEvent('rsg-railroad:maintenanceResult', src, mType, true)
end)

---------------------------------------------------------------
-- CLEANUP ON DISCONNECT
---------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    ActiveTrains[src] = nil
    lastMilesAt[src] = nil
    lastTicketRevenue[src] = nil
    if ClearMissionSession then ClearMissionSession(src) end
end)
