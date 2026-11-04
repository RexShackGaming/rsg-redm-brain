local RSGCore = exports['rsg-core']:GetCoreObject()

--------------------------------------------------------------------------------
-- One trolley per track.
-- The server is the single source of truth: GlobalState.rsgTrams[track] = lead netId.
-- One client (the host) creates trolleys when asked. A track never has more than one
-- spawn in flight, a late or second registration for a track is deleted, and any
-- tagged car that does not belong to the registered trolley is swept away.
--------------------------------------------------------------------------------
local host       = nil
local pending    = {} -- [track] = GetGameTimer() when the spawn was requested
local driverless = {} -- [track] = consecutive checks without a living driver
local enabled    = {} -- [track] = bool (config default, overridden by saved admin toggle)

GlobalState.rsgTrams = {}

local function dbg(msg, ...) if Config.Debug then print(('[rsg-trams] ' .. msg):format(...)) end end

local function sortedTracks()
    local list = {}
    for id, t in pairs(Config.Tracks) do list[#list + 1] = { id = id, order = t.order or 99 } end
    table.sort(list, function(a, b) return a.order < b.order end)
    return list
end

for id, t in pairs(Config.Tracks) do
    local saved = GetResourceKvpString('rsg-trams:track:' .. id)
    if saved == 'on' then enabled[id] = true
    elseif saved == 'off' then enabled[id] = false
    else enabled[id] = t.enabled ~= false end
end

local function entityFromNet(netId)
    if not netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    return (ent ~= 0 and DoesEntityExist(ent)) and ent or 0
end

local trolleyModel = {}
for _, m in ipairs(Config.TrolleyModels or { 'trolley01x' }) do trolleyModel[joaat(m)] = true end

-- Is any trolley already in the world? A tagged one we lost track of is re-adopted
-- instead of spawning a second; an untagged one (ambient/another script) blocks spawning.
local function existingTrolley()
    for _, veh in ipairs(GetAllVehicles()) do
        if trolleyModel[GetEntityModel(veh)] then
            local st = Entity(veh).state
            return veh, st.rsgTram, st.rsgTramId
        end
    end
end

local function setTram(track, netId)
    local trams = GlobalState.rsgTrams
    trams[track] = netId
    GlobalState.rsgTrams = trams
end

local function pickHost()
    host = nil
    for src in pairs(RSGCore.Functions.GetRSGPlayers() or {}) do host = tonumber(src); break end
    if not host then
        local players = GetPlayers()
        host = players[1] and tonumber(players[1]) or nil
    end
    pending = {}
    dbg('host: %s', host or 'none')
end

local function hasPlayer(veh)
    for seat = -1, 8 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return true end
    end
    return false
end

-- delete a set of vehicles ([veh] = true) and the NPCs riding them
local function deleteVehicles(set)
    if not next(set) then return end
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and set[GetVehiclePedIsIn(ped, false)] then DeleteEntity(ped) end
    end
    for veh in pairs(set) do if DoesEntityExist(veh) then DeleteEntity(veh) end end
end

-- remove every car tagged for a track (or every tagged car when track is nil)
local function removeTrack(track)
    local set = {}
    for _, veh in ipairs(GetAllVehicles()) do
        local tag = Entity(veh).state.rsgTram
        if tag and (track == nil or tag == track) then set[veh] = true end
    end
    for id, netId in pairs(GlobalState.rsgTrams or {}) do
        if track == nil or id == track then
            local ent = entityFromNet(netId)
            if ent ~= 0 then set[ent] = true end
        end
    end
    deleteVehicles(set)
    if track then
        setTram(track, nil)
        pending[track], driverless[track] = nil, nil
    else
        GlobalState.rsgTrams = {}
        pending, driverless = {}, {}
    end
end

-- remove tagged cars that are not part of the registered trolley for their track
local function sweepDuplicates()
    local trams, set = GlobalState.rsgTrams, {}
    for _, veh in ipairs(GetAllVehicles()) do
        local st = Entity(veh).state
        local track = st.rsgTram
        if track then
            if not Config.Tracks[track] or not enabled[track] or st.rsgTramId ~= trams[track] then
                if not hasPlayer(veh) then set[veh] = true end
            end
        end
    end
    if next(set) then dbg('sweeping %d stray trolley car(s)', (function() local n = 0 for _ in pairs(set) do n += 1 end return n end)()) end
    deleteVehicles(set)
end

RegisterNetEvent('rsg-trams:server:registerTram', function(track, netId, cars)
    local src = source
    netId = tonumber(netId)
    local cfg = type(track) == 'string' and Config.Tracks[track]
    local ent = entityFromNet(netId)
    if ent == 0 or GetEntityType(ent) ~= 2 then return end

    -- only the host, only for a spawn we asked for, only if the track is still empty
    if src ~= host or not cfg or not enabled[track] or not pending[track]
        or entityFromNet(GlobalState.rsgTrams[track]) ~= 0
        or (function() for _, v in ipairs(GetAllVehicles()) do
                if v ~= ent and trolleyModel[GetEntityModel(v)] and Entity(v).state.rsgTram then return true end
            end end)() then
        dbg('rejecting trolley for %s from %s', tostring(track), src)
        TriggerClientEvent('rsg-trams:client:deleteTrain', src, netId)
        return
    end

    SetEntityOrphanMode(ent, 2) -- keep the trolley when the host leaves
    local st = Entity(ent).state
    st:set('rsgTram', track, true)
    st:set('rsgTramId', netId, true)
    st:set('ownFare', true, true) -- ticket systems (rsg-railroad) skip trolleys

    if type(cars) == 'table' then
        local pos = GetEntityCoords(ent)
        for n = 1, math.min(#cars, 8) do
            local car = entityFromNet(tonumber(cars[n]))
            if car ~= 0 and car ~= ent and GetEntityType(car) == 2
                and #(GetEntityCoords(car) - pos) < 40.0 and not hasPlayer(car) then
                SetEntityOrphanMode(car, 2)
                local cs = Entity(car).state
                cs:set('rsgTram', track, true)
                cs:set('rsgTramId', netId, true)
                cs:set('ownFare', true, true)
            end
        end
    end

    pending[track] = nil
    setTram(track, netId)
    dbg('track %s trolley registered (%s)', track, netId)
end)

-- nothing (registered or spawning) within clearance of a spawn point
local function spawnClear(coords, now)
    for _, netId in pairs(GlobalState.rsgTrams) do
        local ent = entityFromNet(netId)
        if ent ~= 0 and #(GetEntityCoords(ent) - coords) < Config.SpawnClearance then return false end
    end
    for _, t in pairs(pending) do
        if now - t <= Config.SpawnTimeout then return false end -- one spawn at a time
    end
    return true
end

-- a trolley whose driver is gone stops dead: replace it
local function checkDriver(track, ent)
    local driver = GetPedInVehicleSeat(ent, -1)
    if driver ~= 0 and DoesEntityExist(driver) and GetEntityHealth(driver) > 0 then
        driverless[track] = nil
        SetEntityOrphanMode(driver, 2)
        return
    end
    driverless[track] = (driverless[track] or 0) + 1
    if driverless[track] >= (Config.DriverlessChecks or 2) then
        dbg('track %s has no driver, replacing', track)
        removeTrack(track)
    end
end

CreateThread(function()
    Wait(5000)
    while true do
        if not host or not GetPlayerName(host) then pickHost() end
        if host then
            local now = GetGameTimer()
            for _, item in ipairs(sortedTracks()) do
                local track, cfg = item.id, Config.Tracks[item.id]
                local netId = GlobalState.rsgTrams[track]
                local ent = entityFromNet(netId)
                if not enabled[track] then
                    if netId or ent ~= 0 then removeTrack(track) end
                elseif ent ~= 0 then
                    checkDriver(track, ent)
                else
                    if netId then setTram(track, nil); driverless[track] = nil end
                    local veh, tag, tagId = existingTrolley()
                    if veh then
                        -- a trolley already exists: never spawn another
                        if tag == track and tagId and entityFromNet(tagId) ~= 0 then
                            setTram(track, tagId)
                            dbg('re-adopted existing trolley on %s', track)
                        else
                            dbg('trolley already in the world, not spawning')
                        end
                    elseif (not pending[track] or now - pending[track] > Config.SpawnTimeout) and spawnClear(cfg.coords, now) then
                        pending[track] = now
                        TriggerClientEvent('rsg-trams:client:spawnTrack', host, track)
                        dbg('asking host %s to spawn %s', host, track)
                    end
                end
            end
            sweepDuplicates()
        end
        Wait(Config.HostCheckInterval)
    end
end)

AddEventHandler('playerDropped', function()
    if source == host then pickHost() end
end)

--------------------------------------------------------------------------------
-- /trams                  status of every track
-- /trams <track> on|off   enable or disable a track (saved)
-- /trams reset            remove all trolleys; they respawn on the next check
--------------------------------------------------------------------------------
local function notify(src, msg, kind)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('tram_title'), description = msg, type = kind or 'inform', duration = 6000 })
end

RSGCore.Commands.Add('trams', locale('cmd_help'), {
    { name = 'track', help = locale('cmd_param_track') },
    { name = 'state', help = locale('cmd_param_state') },
}, false, function(src, args)
    local track, state = args[1] and args[1]:lower(), args[2] and args[2]:lower()

    if not track then
        local parts = {}
        for _, item in ipairs(sortedTracks()) do
            local id = item.id
            local status = not enabled[id] and locale('status_off')
                or entityFromNet(GlobalState.rsgTrams[id]) ~= 0 and locale('status_running')
                or locale('status_spawning')
            parts[#parts + 1] = ('%s: %s'):format(id, status)
        end
        notify(src, table.concat(parts, ' | '))
        return
    end

    if track == 'reset' then
        removeTrack(nil)
        notify(src, locale('cmd_reset'), 'success')
        return
    end

    if not Config.Tracks[track] then
        local ids = {}
        for _, item in ipairs(sortedTracks()) do ids[#ids + 1] = item.id end
        notify(src, locale('cmd_bad_track', table.concat(ids, ', ')), 'error')
        return
    end
    if state ~= 'on' and state ~= 'off' then
        notify(src, locale('cmd_bad_state'), 'error')
        return
    end

    enabled[track] = state == 'on'
    SetResourceKvp('rsg-trams:track:' .. track, state)
    if not enabled[track] then removeTrack(track) end
    notify(src, locale(enabled[track] and 'cmd_on' or 'cmd_off', track), 'success')
end, Config.AdminPermission or 'admin')

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then removeTrack(nil) end -- leftovers from a previous run
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then removeTrack(nil) end
end)
