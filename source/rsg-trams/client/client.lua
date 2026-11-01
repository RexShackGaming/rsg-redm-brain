lib.locale()

local blips = {}     -- [index] = { blip = handle, entity = train }
local stopState = {} -- [index] = { waiting, station, pending, driver, voice }

-- Natives (RDR3 VEHICLE namespace)
local function CreateMissionTrain(cfg, c, dir, pass, cond)
    return Citizen.InvokeNative(0xC239DBD9A57D2A71, cfg, c.x, c.y, c.z, dir, pass, true, cond) -- _CREATE_MISSION_TRAIN
end
local function IsSpawnValid(cfg, c, dir)
    return Citizen.InvokeNative(0xF05DFAF1ADFEF2CD, cfg, c.x, c.y, c.z, dir, false) -- _IS_SPAWN_POSITION_VALID_FOR_TRAIN
end
local function SetStopsForStations(t, b) Citizen.InvokeNative(0x4182C037AA1F0091, t, b) end -- _SET_TRAIN_STOPS_FOR_STATIONS
local function SetMaxSpeed(t, s)        Citizen.InvokeNative(0x9F29999DFDF2AEB8, t, s) end -- _SET_TRAIN_MAX_SPEED
local function SetCruiseSpeed(t, s)     Citizen.InvokeNative(0x01021EB2E96B793C, t, s) end -- SET_TRAIN_CRUISE_SPEED
local function SetTrainSpeed(t, s)     Citizen.InvokeNative(0xDFBA6BBFF7CCAFBB, t, s) end -- SET_TRAIN_SPEED
local function IsWaitingAtStation(t) return Citizen.InvokeNative(0xE887BD31D97793F6, t) end -- IS_TRAIN_WAITING_AT_STATION
local function DeleteMissionTrain(t)    Citizen.InvokeNative(0x0D3630FB07E8B570, Citizen.PointerValueIntInitialized(t)) end -- DELETE_MISSION_TRAIN

local function trainModels(cfg)
    local models = {}
    for i = 0, (Citizen.InvokeNative(0x635423D55CA84FC8, cfg) or 0) - 1 do -- _GET_NUM_CARS_FROM_TRAIN_CONFIG
        local model = Citizen.InvokeNative(0x8DF5F6A19F99F0D5, cfg, i)  -- _GET_TRAIN_MODEL_FROM_TRAIN_CONFIG_BY_CAR_INDEX
        if model and model ~= 0 then models[#models + 1] = model end
    end
    return models
end

local function trainFromNetId(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return nil end
    local t = NetworkGetEntityFromNetworkId(netId)
    return (t ~= 0 and DoesEntityExist(t)) and t or nil
end


--------------------------------------------------------------------------------
-- Audio: script-created mission trains (and their network clones on other clients)
-- can come up without the trolley's engine/rail audio. Every client forces the
-- model's audio game object onto each car it sees, once per entity handle.
--------------------------------------------------------------------------------
local audioDone = {} -- [entity] = owner when the audio was applied
local audioSeen = {} -- [entity] = GetGameTimer() the trolley was last checked
local audioNames = {}
for _, name in ipairs(Config.Audio and Config.Audio.models or {}) do audioNames[joaat(name)] = name end

-- The game drops the forced audio when a car streams back in or changes owner, and
-- entity handles get reused, so re-apply whenever the owner changes or the trolley
-- wasn't seen on the previous checks.
local function applyAudio(veh, fresh)
    local owner = NetworkGetEntityOwner(veh)
    if not fresh and audioDone[veh] == owner then return end
    audioDone[veh] = owner
    local name = audioNames[GetEntityModel(veh)]
    if not name then
        if Config.Debug then print(('[rsg-trams] no audio name for model %s'):format(GetEntityModel(veh))) end
        return
    end
    Citizen.InvokeNative(0x4F0C413926060B38, veh, name)  -- FORCE_USE_AUDIO_GAME_OBJECT
    Citizen.InvokeNative(0xE5564483E407F914, veh, true)  -- SET_AUDIO_VEHICLE_PRIORITY
    Citizen.InvokeNative(0x76D683C108594D0E, veh, true)  -- SET_HORN_ENABLED
    if Config.Debug then print(('[rsg-trams] audio %s on %s'):format(name, veh)) end
end

local function applyTrainAudio(train)
    if not Config.Audio or not Config.Audio.enabled then return end
    local now = GetGameTimer()
    local fresh = not audioSeen[train] or now - audioSeen[train] > 5000
    audioSeen[train] = now
    applyAudio(train, fresh)
    for c = 0, 7 do
        local car = Citizen.InvokeNative(0xD0FB093A4CDB932C, train, c) -- GET_TRAIN_CARRIAGE
        if not car or car == 0 then break end
        if car ~= train and DoesEntityExist(car) then applyAudio(car, fresh) end
    end
end

--------------------------------------------------------------------------------
-- Host: spawn a line when the server asks for it
--------------------------------------------------------------------------------
local spawning = {}

RegisterNetEvent('rsg-trams:client:spawnLine', function(index)
    local line = Config.Lines[index]
    if not line or spawning[index] then return end
    spawning[index] = true

    local models = trainModels(line.config)
    for _, m in ipairs(models) do
        RequestModel(m)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(m) and GetGameTimer() < timeout do Wait(10) end
    end

    local tries = 0
    while not IsSpawnValid(line.config, line.coords, line.direction) and tries < 30 do
        tries += 1; Wait(1000)
    end

    local train = CreateMissionTrain(line.config, line.coords, line.direction, Config.Passengers, Config.Conductor)
    for _, m in ipairs(models) do SetModelAsNoLongerNeeded(m) end
    spawning[index] = nil

    if not train or train == 0 or not DoesEntityExist(train) then
        if Config.Debug then print(('[rsg-trams] failed to spawn %s'):format(line.name)) end
        return
    end

    SetStopsForStations(train, Config.StopForStations)
    SetMaxSpeed(train, Config.MaxSpeed)
    SetCruiseSpeed(train, Config.CruiseSpeed)
    SetEntityAsMissionEntity(train, true, true)
    if Config.Invincible then
        SetEntityInvincible(train, true)
        local driver = GetPedInVehicleSeat(train, -1)
        if driver ~= 0 then
            SetEntityInvincible(driver, true)
            SetBlockingOfNonTemporaryEvents(driver, true)
        end
    end
    applyTrainAudio(train)
    local netId = NetworkGetNetworkIdFromEntity(train)
    SetNetworkIdExistsOnAllMachines(netId, true)
    -- every car of the trolley, so the server can tag them all (cleanup, ticket exemption)
    local cars = {}
    for c = 0, #models - 1 do
        local car = Citizen.InvokeNative(0xD0FB093A4CDB932C, train, c) -- GET_TRAIN_CARRIAGE
        if car and car ~= 0 and car ~= train and DoesEntityExist(car) then
            local carNet = NetworkGetNetworkIdFromEntity(car)
            SetNetworkIdExistsOnAllMachines(carNet, true)
            cars[#cars + 1] = carNet
        end
    end
    TriggerServerEvent('rsg-trams:server:registerTram', index, netId, cars)
end)

-- Server cancelled a spawn we made: remove it with the proper train native
RegisterNetEvent('rsg-trams:client:deleteTrain', function(netId)
    local train = trainFromNetId(netId)
    if train and NetworkHasControlOfEntity(train) then DeleteMissionTrain(train) end
end)

--------------------------------------------------------------------------------
-- All clients: blips, keep-alive and conductor announcements (func_1278 / func_1279)
--------------------------------------------------------------------------------
-- medium_update func_1277: conductor voices. Drivers without one have no trolley lines.
local VOICES = {
    '0835_S_M_M_GenConductor_01_WHITE_01',
    '0835_S_M_M_GenConductor_01_WHITE_02',
    '0835_S_M_M_GenConductor_01_WHITE_03',
}

-- medium_update func_773: station index -> { line while waiting, line on departure }
local STATION_LINES = {
    [0] = { 'TROLLEY_ARRIVAL_WAREHOUSE_DISTRICT',  'CALL_OUT_NEUTRAL' },
    [1] = { 'TROLLEY_NEXT_MANSION_DISTRICT',       'CALL_OUT_NEUTRAL' },
    [2] = { 'TROLLEY_ARRIVAL_MANSION_DISTRICT',    'TROLLEY_NEXT_OLD_QUARTER' },
    [3] = { 'TROLLEY_ARRIVAL_OLD_QUARTER',         'TROLLEY_NEXT_ST_FRANCES' },
    [4] = { 'TROLLEY_ARRIVAL_ST_FRANCES',          'CALL_OUT_NEUTRAL' },
    [5] = { 'TROLLEY_NEXT_MARKET_DISTRICT',        'CALL_OUT_NEUTRAL' },
    [6] = { 'TROLLEY_ARRIVAL_MARKET_DISTRICT',     'TROLLEY_NEXT_COMMERICAL_DISTRICT' },
    [7] = { 'TROLLEY_ARRIVAL_COMMERICAL_DISTRICT', 'TROLLEY_NEXT_WAREHOUSE_DISTRICT' },
}

local function GetCurrentStation(t) return Citizen.InvokeNative(0x86FA6D8B48667D75, t) end -- GET_CURRENT_STATION_FOR_TRAIN
local function IsSpeechPlaying(p)   return Citizen.InvokeNative(0x729072355FA39EC9, p) end -- IS_ANY_SPEECH_PLAYING
local function IsHornActive(v)      return Citizen.InvokeNative(0x9D6BFC12B05C6121, v) end -- IS_HORN_ACTIVE

-- func_1279 / func_1120: PLAY_PED_AMBIENT_SPEECH_NATIVE with the conductor voice and
-- SPEECH_PARAMS_FORCE_SHOUTED_CLEAR. ScriptedSpeechParams = 7 x 8-byte fields.
-- Played locally on every nearby client (syncOverNetwork = 0) so it isn't duplicated.
local function shout(driver, voice, line)
    local p = DataView.ArrayBuffer(56)
    p:SetInt64(0, VarString(10, 'LITERAL_STRING', line))   -- speechName
    p:SetInt64(8, VarString(10, 'LITERAL_STRING', voice))  -- voiceName
    p:SetInt32(16, 0)                                       -- variation
    p:SetInt32(24, `SPEECH_PARAMS_FORCE_SHOUTED_CLEAR`)     -- speechParamHash
    p:SetInt32(32, 0)                                       -- listener
    p:SetInt32(40, 0)                                       -- syncOverNetwork
    p:SetInt32(48, 1)                                       -- f_6 (Rockstar passes 1)
    Citizen.InvokeNative(0x8E04FEDD28D42462, driver, p:Buffer())
end

--------------------------------------------------------------------------------
-- Spacing: mission trains ignore each other, so the owner of a trolley holds it
-- when another trolley is close ahead (e.g. one waiting at a stop) on the same heading.
--------------------------------------------------------------------------------
local held = {}    -- [train] = true while held
local lastDir = {} -- [train] = last travel direction (vector3)

local function travelDir(train)
    local v = GetEntityVelocity(train)
    if #v > 0.5 then lastDir[train] = v / #v end
    return lastDir[train]
end

local halfLen = {} -- [model] = half length of the car (front from centre)

local function frontOf(train, dir)
    local model = GetEntityModel(train)
    if not halfLen[model] then
        local mn, mx = GetModelDimensions(model)
        halfLen[model] = math.max(math.abs(mn.y), math.abs(mx.y))
    end
    return GetEntityCoords(train) + dir * halfLen[model]
end

-- distance along the track from the front, and sideways offset, of a point
local function corridor(front, dir, coords)
    local d = coords - front
    local along = dir.x * d.x + dir.y * d.y
    local lx, ly = d.x - dir.x * along, d.y - dir.y * along
    return along, math.sqrt(lx * lx + ly * ly), math.abs(d.z)
end

local function inPath(front, dir, coords, range)
    local along, side, dz = corridor(front, dir, coords)
    return along > -1.0 and along <= range and side <= Config.Avoid.width and dz <= 3.0
end

-- other trolleys close ahead going the same way (or stopped)
local function tramAhead(train, dir, pos, others)
    for _, other in ipairs(others) do
        if other ~= train then
            local delta = GetEntityCoords(other) - pos
            local dist = #delta
            if dist > 0.1 and dist <= Config.TrafficGap and dir.x * delta.x / dist + dir.y * delta.y / dist > 0.85 then
                local odir = lastDir[other] or travelDir(other)
                if #GetEntityVelocity(other) < 0.5 or not odir or (dir.x * odir.x + dir.y * odir.y) > 0 then return true end
            end
        end
    end
    return false
end

-- NPC-only things (never players, their horses/carts, or other scripts' entities)
local function isAmbientPed(ped)
    return not IsPedAPlayer(ped) and not IsEntityAMissionEntity(ped)
end

local function isAmbientVehicle(veh)
    if IsEntityAMissionEntity(veh) then return false end
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return false end
    end
    return true
end

-- living people, horses and carts on the rails in front of the trolley
-- returns the blocking entity list (empty table = clear)
local function obstaclesAhead(train, dir, isTram)
    local found = {}
    if not Config.Avoid.enabled then return found, math.huge end
    local front, range = frontOf(train, dir), Config.Avoid.distance
    local nearest = math.huge
    local function note(coords)
        local along = corridor(front, dir, coords)
        if along < nearest then nearest = along end
    end
    for _, ped in ipairs(GetGamePool('CPed')) do
        if inPath(front, dir, GetEntityCoords(ped), range)
            and not IsPedDeadOrDying(ped, true) and not IsPedOnSpecificVehicle(ped, train) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then
                found[#found + 1] = { ent = ped, ped = true }; note(GetEntityCoords(ped))
            elseif not (isTram[veh] or Entity(veh).state.rsgTram) then
                found[#found + 1] = { ent = veh }; note(GetEntityCoords(ped))
            end
        end
    end
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= train and inPath(front, dir, GetEntityCoords(veh), range)
            and not isTram[veh] and not Entity(veh).state.rsgTram then
            found[#found + 1] = { ent = veh }; note(GetEntityCoords(veh))
        end
    end
    return found, nearest
end

-- remove NPC traffic that has sat in front of the trolley too long
-- (entities owned by another client are requested now and removed on a later check)
local function deleteOwned(e)
    if not NetworkHasControlOfEntity(e) then NetworkRequestControlOfEntity(e); return end
    SetEntityAsMissionEntity(e, true, true)
    DeleteEntity(e)
end

local function clearAmbient(list)
    for _, o in ipairs(list) do
        local e = o.ent
        if DoesEntityExist(e) and (o.ped and isAmbientPed(e) or (not o.ped and isAmbientVehicle(e))) then
            if not o.ped then
                for seat = -1, 6 do
                    local p = GetPedInVehicleSeat(e, seat)
                    if p ~= 0 and isAmbientPed(p) then deleteOwned(p) end
                end
            end
            deleteOwned(e)
        end
    end
end

local speedNow = {}     -- [train] = speed we last commanded
local lastTick = {}     -- [train] = GetGameTimer() of the last speed update

-- ease toward a target speed: brake at Config.Avoid.brake m/s², pull away at .accel m/s²
local function driveTo(train, target, now)
    local dt = math.min((now - (lastTick[train] or now)) / 1000, 1.0)
    lastTick[train] = now
    local cur = speedNow[train]
    if not cur then cur = #GetEntityVelocity(train) end
    if target < cur then
        cur = math.max(target, cur - (Config.Avoid.brake or 1.5) * dt)
    else
        cur = math.min(target, cur + (Config.Avoid.accel or 0.8) * dt)
    end
    if cur < 0.05 then cur = 0.0 end
    speedNow[train] = cur
    SetCruiseSpeed(train, cur)
    SetTrainSpeed(train, cur)
end

local blockedSince = {} -- [train] = GetGameTimer() when it was first held
local pushUntil = {}    -- [train] = ignore blocks until this time

local function updateSpacing(train, others, isTram)
    local now = GetGameTimer()
    local target = Config.CruiseSpeed
    if not (pushUntil[train] and now < pushUntil[train]) then
        local dir = travelDir(train) or GetEntityForwardVector(train)
        local tram = tramAhead(train, dir, GetEntityCoords(train), others)
        local obs, nearest = obstaclesAhead(train, dir, isTram)
        if tram then target = 0.0 end
        if #obs > 0 then
            -- full speed at the edge of the look-ahead, stopped at stopGap metres
            local gap = Config.Avoid.stopGap or 3.0
            local f = (nearest - gap) / math.max(Config.Avoid.distance - gap, 0.1)
            target = math.min(target, Config.CruiseSpeed * math.max(0.0, math.min(1.0, f)))
        end
        if tram or #obs > 0 then
            blockedSince[train] = blockedSince[train] or now
            local waited = now - blockedSince[train]
            if #obs > 0 and Config.Avoid.clearNpcAfter and waited >= Config.Avoid.clearNpcAfter * 1000 then
                clearAmbient(obs)
            end
            if Config.Avoid.maxWait and waited >= Config.Avoid.maxWait * 1000 then
                pushUntil[train] = now + (Config.Avoid.pushTime or 8) * 1000
                target = Config.CruiseSpeed
                if Config.Debug then print(('[rsg-trams] %s waited %ds, pushing through'):format(train, waited // 1000)) end
            end
        else
            blockedSince[train] = nil
        end
    else
        blockedSince[train] = nil
    end

    if target >= Config.CruiseSpeed and not held[train] then
        -- clear road: hand speed back to the game (station stops keep working)
        if speedNow[train] then
            driveTo(train, target, now)
            if speedNow[train] >= Config.CruiseSpeed then speedNow[train], lastTick[train] = nil, nil end
        end
    else
        held[train] = target < Config.CruiseSpeed or nil
        driveTo(train, target, now)
    end
end

local function removeBlip(i)
    if blips[i] then RemoveBlip(blips[i].blip); blips[i] = nil end
end

-- Announce once on arrival and once on departure; if the conductor is busy talking
-- or the horn is going, keep the line queued and retry (as func_773 does).
local function updateAnnounce(i, train)
    local st = stopState[i] or {}
    local waiting = IsWaitingAtStation(train)
    if waiting ~= st.waiting then
        if waiting then st.station = GetCurrentStation(train) end
        local lines = st.station and STATION_LINES[st.station]
        if Config.Lines[i] and Config.Lines[i].callOutOnly then -- Rockstar's upper line only calls out
            st.pending = 'CALL_OUT_NEUTRAL'
        else
            st.pending = lines and lines[waiting and 1 or 2] or 'CALL_OUT_NEUTRAL'
        end
        st.waiting = waiting
    end
    if st.pending then
        local driver = GetPedInVehicleSeat(train, -1)
        if driver ~= 0 and not IsEntityDead(driver) and not IsSpeechPlaying(driver) and not IsHornActive(train) then
            if st.driver ~= driver then
                st.driver, st.voice = driver, VOICES[math.random(#VOICES)]
                Citizen.InvokeNative(0x6C8065A3B780185B, driver, st.voice) -- SET_AMBIENT_VOICE_NAME
            end
            shout(driver, st.voice, st.pending)
            st.pending = nil
        end
    end
    stopState[i] = st
end

CreateThread(function()
    while true do
        local sleep = 2000
        local pcoords = GetEntityCoords(cache.ped)
        local trams = GlobalState.rsgTrams or {}

        for i in pairs(blips) do
            if not trams[i] then removeBlip(i); stopState[i] = nil end
        end

        local live, isTram = {}, {}
        for _, netId in pairs(trams) do
            local t = trainFromNetId(netId)
            if t then live[#live + 1] = t; isTram[t] = true end
        end
        for t in pairs(lastDir) do if not DoesEntityExist(t) then lastDir[t] = nil end end
        for t in pairs(held) do if not DoesEntityExist(t) then held[t] = nil end end
        for t in pairs(blockedSince) do if not DoesEntityExist(t) then blockedSince[t] = nil end end
        for t in pairs(pushUntil) do if not DoesEntityExist(t) then pushUntil[t] = nil end end
        for t in pairs(speedNow) do if not DoesEntityExist(t) then speedNow[t], lastTick[t] = nil, nil end end
        for t in pairs(audioDone) do if not DoesEntityExist(t) then audioDone[t] = nil end end
        for t in pairs(audioSeen) do if not DoesEntityExist(t) then audioSeen[t] = nil end end

        for i, netId in pairs(trams) do
            local train = trainFromNetId(netId)
            if not train then
                removeBlip(i); stopState[i] = nil
            else
                applyTrainAudio(train)
                if Config.Blip and (not blips[i] or blips[i].entity ~= train) then
                    removeBlip(i)
                    local b = Citizen.InvokeNative(0x23F74C2FDA6E7C61, 1664425300, train) -- BLIP_ADD_FOR_ENTITY
                    SetBlipSprite(b, Config.BlipSprite, true)
                    Citizen.InvokeNative(0x662D364ABF16DE2F, b, Config.BlipModifier) -- BLIP_ADD_MODIFIER
                    Citizen.InvokeNative(0x9CB1A1623062F402, b, locale('tram_blip')) -- SET_BLIP_NAME
                    blips[i] = { blip = b, entity = train }
                end
                -- whoever owns the trolley after migration keeps it moving and spaced
                if NetworkHasControlOfEntity(train) then
                    -- the driver can sync in after spawn or after migration: protect it here
                    if Config.Invincible then
                        local driver = GetPedInVehicleSeat(train, -1)
                        if driver ~= 0 and NetworkHasControlOfEntity(driver) then
                            SetEntityInvincible(driver, true)
                            SetBlockingOfNonTemporaryEvents(driver, true)
                        end
                    end
                    updateSpacing(train, live, isTram)
                    sleep = math.min(sleep, Config.Avoid.interval)
                end
                if Config.Announce and #(pcoords - GetEntityCoords(train)) <= Config.AnnounceRange then
                    sleep = math.min(sleep, 500)
                    updateAnnounce(i, train)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i in pairs(blips) do removeBlip(i) end
    -- the owner removes its trolleys with the proper train native; the server sweeps the rest
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if Entity(veh).state.rsgTram and NetworkHasControlOfEntity(veh) then DeleteMissionTrain(veh) end
    end
end)
