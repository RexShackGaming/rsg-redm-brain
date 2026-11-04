--------------------------------------------------------------------------------
-- rsg-trams client: one trolley per track (Config.Tracks).
-- GlobalState.rsgTrams[track] = lead netId, set by the server only.
--------------------------------------------------------------------------------
local blips     = {} -- [track] = { blip, entity }
local stopState = {} -- [track] = { waiting, station, pending, driver, voice }

local function dbg(msg, ...) if Config.Debug then print(('[rsg-trams] ' .. msg):format(...)) end end

-- Natives (RDR3 VEHICLE namespace)
local function CreateMissionTrain(cfg, c, dir, pass, cond)
    return Citizen.InvokeNative(0xC239DBD9A57D2A71, cfg, c.x, c.y, c.z, dir, pass, true, cond) -- _CREATE_MISSION_TRAIN
end
local function IsSpawnValid(cfg, c, dir)
    return Citizen.InvokeNative(0xF05DFAF1ADFEF2CD, cfg, c.x, c.y, c.z, dir, false) -- _IS_SPAWN_POSITION_VALID_FOR_TRAIN
end
local function SetStopsForStations(t, b) Citizen.InvokeNative(0x4182C037AA1F0091, t, b) end -- _SET_TRAIN_STOPS_FOR_STATIONS
local function SetMaxSpeed(t, s)         Citizen.InvokeNative(0x9F29999DFDF2AEB8, t, s) end -- _SET_TRAIN_MAX_SPEED
local function SetCruiseSpeed(t, s)      Citizen.InvokeNative(0x01021EB2E96B793C, t, s) end -- SET_TRAIN_CRUISE_SPEED
local function SetTrainSpeed(t, s)       Citizen.InvokeNative(0xDFBA6BBFF7CCAFBB, t, s) end -- SET_TRAIN_SPEED
local function IsWaitingAtStation(t)     return Citizen.InvokeNative(0xE887BD31D97793F6, t) end -- IS_TRAIN_WAITING_AT_STATION
local function GetCarriage(t, i)         return Citizen.InvokeNative(0xD0FB093A4CDB932C, t, i) end -- GET_TRAIN_CARRIAGE
local function GetCurrentStation(t)      return Citizen.InvokeNative(0x86FA6D8B48667D75, t) end -- GET_CURRENT_STATION_FOR_TRAIN
local function IsSpeechPlaying(p)        return Citizen.InvokeNative(0x729072355FA39EC9, p) end -- IS_ANY_SPEECH_PLAYING
local function IsHornActive(v)           return Citizen.InvokeNative(0x9D6BFC12B05C6121, v) end -- IS_HORN_ACTIVE
local function DeleteMissionTrain(t)     Citizen.InvokeNative(0x0D3630FB07E8B570, Citizen.PointerValueIntInitialized(t)) end -- DELETE_MISSION_TRAIN

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
-- Audio: force the trolley's audio game object on every car (re-applied on owner
-- change or when the trolley streams back in)
--------------------------------------------------------------------------------
local audioDone, audioSeen, audioNames = {}, {}, {}
for _, name in ipairs(Config.Audio and Config.Audio.models or {}) do audioNames[joaat(name)] = name end

local function applyAudio(veh, fresh)
    local owner = NetworkGetEntityOwner(veh)
    if not fresh and audioDone[veh] == owner then return end
    audioDone[veh] = owner
    local name = audioNames[GetEntityModel(veh)]
    if not name then return end
    Citizen.InvokeNative(0x4F0C413926060B38, veh, name) -- FORCE_USE_AUDIO_GAME_OBJECT
    Citizen.InvokeNative(0xE5564483E407F914, veh, true) -- SET_AUDIO_VEHICLE_PRIORITY
    Citizen.InvokeNative(0x76D683C108594D0E, veh, true) -- SET_HORN_ENABLED
end

local function applyTrainAudio(train)
    if not Config.Audio or not Config.Audio.enabled then return end
    local now = GetGameTimer()
    local fresh = not audioSeen[train] or now - audioSeen[train] > 5000
    audioSeen[train] = now
    applyAudio(train, fresh)
    for c = 0, 7 do
        local car = GetCarriage(train, c)
        if not car or car == 0 then break end
        if car ~= train and DoesEntityExist(car) then applyAudio(car, fresh) end
    end
end

--------------------------------------------------------------------------------
-- Host: spawn a track's trolley when the server asks
--------------------------------------------------------------------------------
local spawning = {}
local trolleyModel = {}
for _, m in ipairs(Config.TrolleyModels or { 'trolley01x' }) do trolleyModel[joaat(m)] = true end

-- any trolley this client can see (ours, ambient or another script's)
local function trolleyNearby()
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if trolleyModel[GetEntityModel(veh)] then return true end
    end
    return false
end

RegisterNetEvent('rsg-trams:client:spawnTrack', function(track)
    local cfg = Config.Tracks[track]
    if not cfg or spawning[track] then return end
    if trainFromNetId((GlobalState.rsgTrams or {})[track]) or trolleyNearby() then return end -- already running
    spawning[track] = true

    local models = trainModels(cfg.config)
    for _, m in ipairs(models) do
        RequestModel(m)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(m) and GetGameTimer() < timeout do Wait(10) end
    end

    local tries = 0
    while not IsSpawnValid(cfg.config, cfg.coords, cfg.direction) and tries < 30 do
        tries += 1; Wait(1000)
    end

    -- the track may have been filled while we waited, or a trolley is already here
    if trainFromNetId((GlobalState.rsgTrams or {})[track]) or trolleyNearby() then
        for _, m in ipairs(models) do SetModelAsNoLongerNeeded(m) end
        spawning[track] = nil
        return
    end

    local train = CreateMissionTrain(cfg.config, cfg.coords, cfg.direction, Config.Passengers, Config.Conductor)
    for _, m in ipairs(models) do SetModelAsNoLongerNeeded(m) end
    spawning[track] = nil

    if not train or train == 0 or not DoesEntityExist(train) then
        dbg('failed to spawn %s', track)
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
    local cars = {}
    for c = 0, #models - 1 do
        local car = GetCarriage(train, c)
        if car and car ~= 0 and car ~= train and DoesEntityExist(car) then
            local carNet = NetworkGetNetworkIdFromEntity(car)
            SetNetworkIdExistsOnAllMachines(carNet, true)
            cars[#cars + 1] = carNet
        end
    end
    TriggerServerEvent('rsg-trams:server:registerTram', track, netId, cars)
end)

-- server rejected a trolley we made: remove it with the train native
RegisterNetEvent('rsg-trams:client:deleteTrain', function(netId)
    local train = trainFromNetId(netId)
    if train and NetworkHasControlOfEntity(train) then DeleteMissionTrain(train) end
end)

--------------------------------------------------------------------------------
-- Conductor announcements (medium_update func_773 / func_1277 / func_1279)
--------------------------------------------------------------------------------
local VOICES = {
    '0835_S_M_M_GenConductor_01_WHITE_01',
    '0835_S_M_M_GenConductor_01_WHITE_02',
    '0835_S_M_M_GenConductor_01_WHITE_03',
}

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

-- PLAY_PED_AMBIENT_SPEECH_NATIVE, played locally on each nearby client
local function shout(driver, voice, line)
    local p = DataView.ArrayBuffer(56)
    p:SetInt64(0, VarString(10, 'LITERAL_STRING', line))
    p:SetInt64(8, VarString(10, 'LITERAL_STRING', voice))
    p:SetInt32(16, 0)
    p:SetInt32(24, `SPEECH_PARAMS_FORCE_SHOUTED_CLEAR`)
    p:SetInt32(32, 0)
    p:SetInt32(40, 0)
    p:SetInt32(48, 1)
    Citizen.InvokeNative(0x8E04FEDD28D42462, driver, p:Buffer())
end

local function updateAnnounce(track, train)
    local st = stopState[track] or {}
    local waiting = IsWaitingAtStation(train)
    if waiting ~= st.waiting then
        if waiting then st.station = GetCurrentStation(train) end
        local lines = st.station and STATION_LINES[st.station]
        if Config.Tracks[track] and Config.Tracks[track].callOutOnly then
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
    stopState[track] = st
end

--------------------------------------------------------------------------------
-- Obstacle braking (owner of the trolley only). People, horses, carts and any
-- other trolley on the rails ahead slow and stop it; it moves off when clear.
--------------------------------------------------------------------------------
local lastDir, halfLen = {}, {}
local speedNow, lastTick, blockedSince, pushUntil = {}, {}, {}, {}

local function travelDir(train)
    local v = GetEntityVelocity(train)
    if #v > 0.5 then lastDir[train] = v / #v end
    return lastDir[train]
end

local function frontOf(train, dir)
    local model = GetEntityModel(train)
    if not halfLen[model] then
        local mn, mx = GetModelDimensions(model)
        halfLen[model] = math.max(math.abs(mn.y), math.abs(mx.y))
    end
    return GetEntityCoords(train) + dir * halfLen[model]
end

local function corridor(front, dir, coords)
    local d = coords - front
    local along = dir.x * d.x + dir.y * d.y
    local lx, ly = d.x - dir.x * along, d.y - dir.y * along
    return along, math.sqrt(lx * lx + ly * ly), math.abs(d.z)
end

local function inPath(front, dir, coords)
    local along, side, dz = corridor(front, dir, coords)
    return along > -1.0 and along <= Config.Avoid.distance and side <= Config.Avoid.width and dz <= 3.0
end

local function isAmbientPed(ped) return not IsPedAPlayer(ped) and not IsEntityAMissionEntity(ped) end

local function isAmbientVehicle(veh)
    if IsEntityAMissionEntity(veh) or Entity(veh).state.rsgTram then return false end
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then return false end
    end
    return true
end

-- a vehicle belongs to this trolley if it carries the same track tag
local function ownCar(veh, track) return Entity(veh).state.rsgTram == track end

local function obstaclesAhead(train, track, dir)
    local found, nearest = {}, math.huge
    local front = frontOf(train, dir)
    local function add(ent, isPed, coords)
        found[#found + 1] = { ent = ent, ped = isPed }
        local along = corridor(front, dir, coords)
        if along < nearest then nearest = along end
    end
    for _, ped in ipairs(GetGamePool('CPed')) do
        local pc = GetEntityCoords(ped)
        if inPath(front, dir, pc) and not IsPedDeadOrDying(ped, true) and not IsPedOnSpecificVehicle(ped, train) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh == 0 then add(ped, true, pc)
            elseif not ownCar(veh, track) then add(veh, false, pc) end
        end
    end
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local vc = GetEntityCoords(veh)
        if veh ~= train and not ownCar(veh, track) and inPath(front, dir, vc) then add(veh, false, vc) end
    end
    return found, nearest
end

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

local function driveTo(train, target, now)
    local dt = math.min((now - (lastTick[train] or now)) / 1000, 1.0)
    lastTick[train] = now
    local cur = speedNow[train] or #GetEntityVelocity(train)
    if target < cur then cur = math.max(target, cur - Config.Avoid.brake * dt)
    else cur = math.min(target, cur + Config.Avoid.accel * dt) end
    if cur < 0.05 then cur = 0.0 end
    speedNow[train] = cur
    SetCruiseSpeed(train, cur)
    SetTrainSpeed(train, cur)
end

local function updateAvoid(train, track)
    if not Config.Avoid.enabled then return end
    local now, target = GetGameTimer(), Config.CruiseSpeed

    if pushUntil[train] and now < pushUntil[train] then
        blockedSince[train] = nil
    else
        local dir = travelDir(train) or GetEntityForwardVector(train)
        local obs, nearest = obstaclesAhead(train, track, dir)
        if #obs > 0 then
            local gap = Config.Avoid.stopGap
            local f = (nearest - gap) / math.max(Config.Avoid.distance - gap, 0.1)
            target = Config.CruiseSpeed * math.max(0.0, math.min(1.0, f))
            blockedSince[train] = blockedSince[train] or now
            local waited = now - blockedSince[train]
            if Config.Avoid.clearNpcAfter and waited >= Config.Avoid.clearNpcAfter * 1000 then clearAmbient(obs) end
            if Config.Avoid.maxWait and waited >= Config.Avoid.maxWait * 1000 then
                pushUntil[train] = now + Config.Avoid.pushTime * 1000
                target = Config.CruiseSpeed
                dbg('%s waited %ds, pushing through', track, waited // 1000)
            end
        else
            blockedSince[train] = nil
        end
    end

    if target >= Config.CruiseSpeed then
        -- clear road: ease back up, then hand speed back to the game (station stops work)
        if speedNow[train] then
            driveTo(train, target, now)
            if speedNow[train] >= Config.CruiseSpeed then speedNow[train], lastTick[train] = nil, nil end
        end
    else
        driveTo(train, target, now)
    end
end

--------------------------------------------------------------------------------
-- Main loop (all clients)
--------------------------------------------------------------------------------
local function removeBlip(track)
    if blips[track] then RemoveBlip(blips[track].blip); blips[track] = nil end
end

local function addBlip(track, train)
    removeBlip(track)
    local b = Citizen.InvokeNative(0x23F74C2FDA6E7C61, 1664425300, train) -- BLIP_ADD_FOR_ENTITY
    SetBlipSprite(b, Config.BlipSprite, true)
    Citizen.InvokeNative(0x662D364ABF16DE2F, b, Config.BlipModifier) -- BLIP_ADD_MODIFIER
    Citizen.InvokeNative(0x9CB1A1623062F402, b, locale('tram_blip'))  -- SET_BLIP_NAME
    blips[track] = { blip = b, entity = train }
end

local function pruneCaches()
    for _, cache in ipairs({ lastDir, speedNow, lastTick, blockedSince, pushUntil, audioDone, audioSeen }) do
        for ent in pairs(cache) do if not DoesEntityExist(ent) then cache[ent] = nil end end
    end
end

CreateThread(function()
    while true do
        local sleep = 2000
        local pcoords = GetEntityCoords(PlayerPedId())
        local trams = GlobalState.rsgTrams or {}

        for track in pairs(blips) do
            if not trams[track] then removeBlip(track); stopState[track] = nil end
        end
        pruneCaches()

        for track, netId in pairs(trams) do
            local train = trainFromNetId(netId)
            if not train then
                removeBlip(track); stopState[track] = nil
            else
                applyTrainAudio(train)
                if Config.Blip and (not blips[track] or blips[track].entity ~= train) then addBlip(track, train) end

                if NetworkHasControlOfEntity(train) then
                    if Config.Invincible then
                        local driver = GetPedInVehicleSeat(train, -1)
                        if driver ~= 0 and NetworkHasControlOfEntity(driver) then
                            SetEntityInvincible(driver, true)
                            SetBlockingOfNonTemporaryEvents(driver, true)
                        end
                    end
                    updateAvoid(train, track)
                    sleep = math.min(sleep, Config.Avoid.interval)
                end

                if Config.Announce and #(pcoords - GetEntityCoords(train)) <= Config.AnnounceRange then
                    sleep = math.min(sleep, 500)
                    updateAnnounce(track, train)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for track in pairs(blips) do removeBlip(track) end
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if Entity(veh).state.rsgTram and NetworkHasControlOfEntity(veh) then DeleteMissionTrain(veh) end
    end
end)
