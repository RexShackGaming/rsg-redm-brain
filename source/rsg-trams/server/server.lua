local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- One client (the host) spawns the networked trolleys; the server owns the truth about
-- which trolleys exist and asks the host to respawn any that disappear.
local host = nil
local pending = {} -- [index] = GetGameTimer() when a spawn was requested
local SPAWN_TIMEOUT = 60000

GlobalState.rsgTrams = {}

local function tramEntity(netId)
    if not netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    return (ent ~= 0 and DoesEntityExist(ent)) and ent or 0
end

local function pickHost()
    host = nil
    -- prefer players with a loaded character, fall back to anyone connected
    for src in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do
        host = tonumber(src); break
    end
    if not host then
        local players = GetPlayers()
        host = players[1] and tonumber(players[1]) or nil
    end
    pending = {}
    if Config.Debug then print(('[rsg-trams] host: %s'):format(host or 'none')) end
end

local function hasPlayer(veh)
    for seat = -1, 8 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

-- delete vehicles (a set: [veh] = true) and the NPCs riding in them
local function deleteVehicles(set)
    if not next(set) then return end
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and set[GetVehiclePedIsIn(ped, false)] then DeleteEntity(ped) end
    end
    for veh in pairs(set) do
        if DoesEntityExist(veh) then DeleteEntity(veh) end
    end
end

RegisterNetEvent('rsg-trams:server:registerTram', function(index, netId, cars)
    local src = source
    if src ~= host then return end
    index, netId = tonumber(index), tonumber(netId)
    local line = index and Config.Lines[index]
    if not line or not line.enabled or not netId then return end
    local ent = tramEntity(netId)
    if ent == 0 then return end
    if GetEntityType(ent) ~= 2 then return end
    if not pending[index] then
        -- spawn was cancelled (admin lowered the limit / host changed): the host owns the
        -- new train, so it deletes it with the proper train native
        TriggerClientEvent('rsg-trams:client:deleteTrain', src, netId)
        return
    end
    -- tag the trolley and its cars (replicated to all clients) with the line index so
    -- cleanup recognises every car; 'ownFare' tells ticket systems (rsg-railroad) to skip it
    SetEntityOrphanMode(ent, 2) -- keep the trolley when the host leaves
    Entity(ent).state:set('rsgTram', index, true)
    Entity(ent).state:set('ownFare', true, true)
    if type(cars) == 'table' then
        local pos = GetEntityCoords(ent)
        for n = 1, math.min(#cars, 8) do
            local car = tramEntity(tonumber(cars[n]))
            -- only accept unoccupied-by-players vehicles coupled to this trolley
            if car ~= 0 and GetEntityType(car) == 2 and #(GetEntityCoords(car) - pos) < 40.0
                and not hasPlayer(car) then
                SetEntityOrphanMode(car, 2)
                Entity(car).state:set('rsgTram', index, true)
                Entity(car).state:set('ownFare', true, true)
            end
        end
    end
    pending[index] = nil
    local trams = GlobalState.rsgTrams
    trams[index] = netId
    GlobalState.rsgTrams = trams
end)

-- Don't spawn on top of another trolley (upper and inner share a spawn point)
local function spawnClear(coords, trams)
    for _, netId in pairs(trams) do
        local ent = tramEntity(netId)
        if ent ~= 0 and #(GetEntityCoords(ent) - coords) < Config.SpawnClearance then return false end
    end
    for _, t in pairs(pending) do
        if GetGameTimer() - t <= SPAWN_TIMEOUT then return false end -- one spawn at a time
    end
    return true
end

--------------------------------------------------------------------------------
-- Tram limit: admins set how many trolleys run at once (/trams <number>).
-- Saved with KVP so it survives restarts; lines spawn in Config.Lines order.
--------------------------------------------------------------------------------
local function enabledCount()
    local n = 0
    for _, line in ipairs(Config.Lines) do if line.enabled then n += 1 end end
    return n
end

local maxTrams = tonumber(GetResourceKvpString('rsg-trams:max')) or Config.MaxTrams or enabledCount()

local function removeTram(i)
    local set = {}
    for _, veh in ipairs(GetAllVehicles()) do
        if Entity(veh).state.rsgTram == i then set[veh] = true end
    end
    deleteVehicles(set)
    local trams = GlobalState.rsgTrams
    trams[i] = nil
    GlobalState.rsgTrams = trams
end

-- drop the highest-numbered trolleys until we're within the limit
local function enforceLimit()
    local trams, live = GlobalState.rsgTrams, {}
    for i in pairs(trams) do live[#live + 1] = i end
    table.sort(live)
    for n = #live, maxTrams + 1, -1 do removeTram(live[n]) end
    -- cancel spawns in flight; the host's late registration is then cleaned up
    if #live >= maxTrams then pending = {} end
end

lib.addCommand('trams', {
    help = locale('cmd_help'),
    params = { { name = 'amount', type = 'number', help = locale('cmd_param'), optional = true } },
    restricted = Config.AdminGroup or 'group.admin',
}, function(src, args)
    local total = enabledCount()
    if not args.amount then
        local running = 0
        for _ in pairs(GlobalState.rsgTrams) do running += 1 end
        TriggerClientEvent('ox_lib:notify', src, { title = locale('tram_title'), description = locale('cmd_status', running, maxTrams, total), type = 'inform' })
        return
    end
    local amount = math.floor(math.max(0, math.min(args.amount, total)))
    maxTrams = amount
    SetResourceKvp('rsg-trams:max', tostring(amount))
    enforceLimit()
    TriggerClientEvent('ox_lib:notify', src, { title = locale('tram_title'), description = locale('cmd_set', amount, total), type = 'success' })
end)

-- Driver watchdog: a mission trolley with no living driver stops dead and blocks every
-- trolley behind it. Keep drivers alive when their owner leaves, and replace any
-- trolley whose driver is gone (removed here, respawned by the health check).
local driverless = {} -- [index] = consecutive checks without a living driver

local function checkDrivers(trams)
    for i, netId in pairs(trams) do
        local ent = tramEntity(netId)
        if ent ~= 0 then
            local driver = GetPedInVehicleSeat(ent, -1)
            if driver ~= 0 and DoesEntityExist(driver) and GetEntityHealth(driver) > 0 then
                driverless[i] = nil
                SetEntityOrphanMode(driver, 2) -- don't cull the driver when the host drops
            else
                driverless[i] = (driverless[i] or 0) + 1
                if driverless[i] >= (Config.DriverlessChecks or 2) then
                    if Config.Debug then print(('[rsg-trams] line %s has no driver, replacing'):format(i)) end
                    driverless[i] = nil
                    removeTram(i)
                end
            end
        else
            driverless[i] = nil
        end
    end
end

-- Health check: spawn missing trolleys through the host
CreateThread(function()
    Wait(5000)
    while true do
        if host and not GetPlayerName(host) then pickHost() end
        if not host then pickHost() end
        if host then
            checkDrivers(GlobalState.rsgTrams)
            local trams, now, changed = GlobalState.rsgTrams, GetGameTimer(), false
            -- running + spawning counts against the admin limit
            local count = 0
            for _, netId in pairs(trams) do if tramEntity(netId) ~= 0 then count += 1 end end
            for _, t in pairs(pending) do if now - t <= SPAWN_TIMEOUT then count += 1 end end
            for i, line in ipairs(Config.Lines) do
                if line.enabled and tramEntity(trams[i]) == 0 then
                    if trams[i] then trams[i] = nil; changed = true end
                    if count < maxTrams and (not pending[i] or now - pending[i] > SPAWN_TIMEOUT) and spawnClear(line.coords, trams) then
                        count += 1
                        pending[i] = now
                        TriggerClientEvent('rsg-trams:client:spawnLine', host, i)
                    end
                end
            end
            if changed then GlobalState.rsgTrams = trams end
        end
        Wait(Config.HostCheckInterval)
    end
end)

AddEventHandler('playerDropped', function()
    if source == host then pickHost() end
end)

-- Remove every tagged trolley plus its driver and passengers. Trolleys are kept alive
-- when their owner leaves, so without this they would survive a resource restart.
local function removeAllTrams()
    local set = {}
    for _, veh in ipairs(GetAllVehicles()) do
        if Entity(veh).state.rsgTram then set[veh] = true end
    end
    for _, netId in pairs(GlobalState.rsgTrams or {}) do
        local ent = tramEntity(netId)
        if ent ~= 0 then set[ent] = true end
    end
    deleteVehicles(set)
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeAllTrams() -- leftovers from a previous run
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeAllTrams()
    GlobalState.rsgTrams = {}
end)
