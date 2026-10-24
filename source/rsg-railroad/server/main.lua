local RSGCore = exports['rsg-core']:GetCoreObject()
local ActiveTrains = {} -- [source] = trainDbId (0 for company/config trains)

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
    TriggerClientEvent('ox_lib:notify', src, {
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

-- Verifies the caller owns `trainId` and is the one currently driving it.
local function GetAuthorizedTrain(src, trainId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    trainId = tonumber(trainId)
    if not trainId or ActiveTrains[src] ~= trainId then return nil end
    local train = DB.GetTrainById(trainId)
    if not train or train.citizenid ~= Player.PlayerData.citizenid then return nil end
    return train, GetTrainConfig(train)
end

---------------------------------------------------------------
-- CALLBACKS
---------------------------------------------------------------
lib.callback.register('rsg-railroad:getOwnedTrains', function(source)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return {} end
    return DB.GetOwnedTrains(Player.PlayerData.citizenid) or {}
end)

-- Only returns the row when the caller owns it.
lib.callback.register('rsg-railroad:getTrainById', function(source, trainId)
    local Player = RSGCore.Functions.GetPlayer(source)
    trainId = tonumber(trainId)
    if not Player or not trainId then return nil end
    local train = DB.GetTrainById(trainId)
    if not train or train.citizenid ~= Player.PlayerData.citizenid then return nil end
    return train
end)

lib.callback.register('rsg-railroad:canSpawnTrain', function(source)
    return ActiveTrains[source] == nil
end)

lib.callback.register('rsg-railroad:getAmbientState', function()
    return DB.GetOwnedCompanyCount() == 0
end)

lib.callback.register('rsg-railroad:getMyCompanyMembership', function(source, companyId)
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

    if ActiveTrains[src] == trainId then
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
-- It is optional: older call sites just fall back to the default capacity.
RegisterNetEvent('rsg-railroad:setTrainSpawned', function(spawned, trainId, model)
    local src = source
    if not spawned then
        ActiveTrains[src] = nil
        -- STRICT: the train left the world, so its storage is destroyed.
        if TrainStorage then TrainStorage.OnPutAway(src) end
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if ActiveTrains[src] then return end -- already has a train out

    -- trainId is 0 for company/config trains (no DB row); only personal
    -- trains (trainId > 0) need ownership verification.
    trainId = tonumber(trainId) or 0
    if trainId > 0 then
        local train = DB.GetTrainById(trainId)
        if not train or train.citizenid ~= Player.PlayerData.citizenid then return end
        DB.UnparkTrain(trainId)
    end
    ActiveTrains[src] = trainId

    -- Fresh deployment, so create a fresh (empty) stash. Note the guard above
    -- means a 'Reverse Direction' re-spawn returns early and never reaches
    -- here, which is exactly what preserves the train's load.
    if TrainStorage then TrainStorage.OnSpawn(src, model) end
end)

---------------------------------------------------------------
-- PARK / STATE UPDATES (personal trains only)
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:parkTrain', function(trainId, stationId, fuel, water, condition)
    local src = source
    local train, tc = GetAuthorizedTrain(src, trainId)
    if not train then return end

    DB.ParkTrain(train.id, stationId,
        Clamp(fuel, tc and tc.maxFuel or 100), Clamp(water, tc and tc.maxWater or 100), Clamp(condition, tc and tc.maxCondition or 100))
    ActiveTrains[src] = nil
    -- STRICT: parking destroys anything left in train storage.
    if TrainStorage then TrainStorage.OnPutAway(src) end
end)

RegisterNetEvent('rsg-railroad:updateTrainState', function(trainId, fuel, water, condition)
    local train, tc = GetAuthorizedTrain(source, trainId)
    if not train then return end
    DB.UpdateTrainState(train.id,
        Clamp(fuel, tc and tc.maxFuel or 100), Clamp(water, tc and tc.maxWater or 100), Clamp(condition, tc and tc.maxCondition or 100))
end)

RegisterNetEvent('rsg-railroad:updateFuel', function(trainId, fuel)
    local train, tc = GetAuthorizedTrain(source, trainId)
    if not train then return end
    DB.UpdateTrainFuel(train.id, Clamp(fuel, tc and tc.maxFuel or 100))
end)

RegisterNetEvent('rsg-railroad:updateWater', function(trainId, water)
    local train, tc = GetAuthorizedTrain(source, trainId)
    if not train then return end
    DB.UpdateTrainWater(train.id, Clamp(water, tc and tc.maxWater or 100))
end)

RegisterNetEvent('rsg-railroad:updateCondition', function(trainId, condition)
    local train, tc = GetAuthorizedTrain(source, trainId)
    if not train then return end
    DB.UpdateTrainCondition(train.id, Clamp(condition, tc and tc.maxCondition or 100))
end)

-- Sanity cap on miles credited per call (total_miles drives milestone rewards).
local MAX_MILES_PER_CALL = 25

RegisterNetEvent('rsg-railroad:addMiles', function(trainId, miles)
    local train = GetAuthorizedTrain(source, trainId)
    if not train then return end
    miles = tonumber(miles) or 0
    if miles <= 0 then return end
    DB.AddMiles(train.id, math.min(miles, MAX_MILES_PER_CALL))
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

    if not HasActiveTrain(src) then return fail() end

    local train
    trainId = tonumber(trainId) or 0
    if trainId > 0 then
        train = DB.GetTrainById(trainId)
        if not train or train.citizenid ~= Player.PlayerData.citizenid then return fail() end
    end

    local itemName = Config[m.cfg].item
    if not exports['rsg-inventory']:RemoveItem(src, itemName, 1, nil, 'railroad-maintenance') then
        NotifyPlayer(src, locale('missing_required_item'), 'error')
        return fail()
    end

    if train then
        local tc = GetTrainConfig(train)
        local maxVal = tc and tc[m.max] or 100
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
    lastTicketRevenue[src] = nil
end)
