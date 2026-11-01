---------------------------------------------------------------
-- TRAIN PREVIEW (full consist)
--
-- Shows the player what a train looks like before they deploy it,
-- driven by the "Preview Train" button in the station menu.
--
-- WHY IT WORKS THE WAY IT DOES:
-- Trains are not normal vehicles. 'appleseed_config' is a train CONFIG,
-- not a spawnable model, and CreateMissionTrain snaps to track -- so a
-- train cannot simply be dropped in front of a camera the way a horse or
-- wagon can.
--
-- Instead this walks the train config car by car (the same natives
-- LoadTrainCars in client/utils.lua uses), resolves each car's real model,
-- and spawns them as plain entities lined up end to end. Car lengths come
-- from GetModelDimensions, so the spacing is correct for any consist
-- rather than being hardcoded.
--
-- The rake is staged HIGH ABOVE THE PLAYER rather than at a fixed off-map
-- coordinate, which guarantees the area is already streamed in, and every
-- entity is non-networked + frozen + collisionless so no other player can
-- see it and nothing can collide.
--
-- The camera orbits the whole consist like a turntable. Orbiting the
-- camera (rather than rotating the entities) is what makes a multi-car
-- train work -- the cars stay correctly coupled in a straight line and
-- only the viewpoint moves.
---------------------------------------------------------------

local previewActive   = false
local previewEntities = {}
local previewCam      = nil

---------------------------------------------------------------
-- BOUNDED MODEL LOAD
-- Deliberately NOT using LoadModel() from client/utils.lua: that loops
-- forever if a model hash is invalid, which hangs the thread silently
-- with no error. A preview must fail loudly instead.
---------------------------------------------------------------
local function LoadModelBounded(hash, timeoutMs)
    if not hash or hash == 0 then return false end
    RequestModel(hash)
    local waited, step = 0, 50
    while not HasModelLoaded(hash) and waited < (timeoutMs or 5000) do
        Wait(step)
        waited = waited + step
    end
    return HasModelLoaded(hash)
end

---------------------------------------------------------------
-- COLLECT EVERY CAR IN A TRAIN CONFIG
-- Returns a list of { model, length } in coupling order.
---------------------------------------------------------------
local function CollectConsist(trainModelName)
    local cfg = Config.TrainPreview
    local configHash = joaat(trainModelName)

    local carCount = GetNumCarsFromTrainConfig(configHash)
    if not carCount or carCount <= 0 then
        DebugPrint('[preview] GetNumCarsFromTrainConfig returned ' .. tostring(carCount) .. ' for ' .. tostring(trainModelName))
        return {}
    end

    -- Single-car mode: just the one index.
    if not cfg.ShowFullConsist then
        local idx = cfg.CarIndex or 0
        if idx >= carCount then idx = 0 end
        local m = GetTrainModelFromTrainConfigByCarIndex(configHash, idx)
        if not LoadModelBounded(m, cfg.LoadTimeout) then return {} end
        local mn, mx = GetModelDimensions(m)
        return { { model = m, length = math.max(math.abs(mx.y - mn.y), 1.0) } }
    end

    local maxCars = cfg.MaxCars or 12
    local cars = {}

    for i = 0, carCount - 1 do
        if #cars >= maxCars then break end

        local m = GetTrainModelFromTrainConfigByCarIndex(configHash, i)
        if m and m ~= 0 and LoadModelBounded(m, cfg.LoadTimeout) then
            local mn, mx = GetModelDimensions(m)
            -- Trains are modelled along Y, so that span is the car's length.
            local len = math.abs(mx.y - mn.y)
            if len < 1.0 then len = 10.0 end -- guard against a bad bounding box
            cars[#cars + 1] = { model = m, length = len }
        else
            DebugPrint('[preview] skipped car index ' .. i .. ' (model ' .. tostring(m) .. ')')
        end
    end

    return cars
end

---------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------
function EndTrainPreview()
    if not previewActive then return end
    previewActive = false

    lib.hideTextUI()

    RenderScriptCams(false, false, 0, true, true)
    if previewCam then
        DestroyCam(previewCam, true)
        previewCam = nil
    end

    for _, ent in ipairs(previewEntities) do
        if ent and DoesEntityExist(ent) then
            SetEntityAsNoLongerNeeded(ent)
            DeleteEntity(ent)
        end
    end
    previewEntities = {}

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    DisplayRadar(true)
end

---------------------------------------------------------------
-- START PREVIEW (blocks until the player exits)
---------------------------------------------------------------
function StartTrainPreview(trainConfig)
    if previewActive then return end

    local cfg = Config.TrainPreview
    if not cfg or not cfg.Enabled then
        Notify(locale('preview_unavailable'), 'error')
        return
    end
    if not trainConfig or not trainConfig.model then
        Notify(locale('preview_no_config'), 'error')
        return
    end

    local cars = CollectConsist(trainConfig.model)
    if #cars == 0 then
        Notify(locale('preview_failed'), 'error', 7000)
        return
    end

    -- Total length including coupling gaps.
    local gap = cfg.CarGap or 0.4
    local total = 0.0
    for _, car in ipairs(cars) do total = total + car.length end
    total = total + gap * math.max(#cars - 1, 0)

    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    -- Staged above the player so the cell is already streamed.
    local centre = vector3(pcoords.x, pcoords.y, pcoords.z + (cfg.HeightOffset or 90.0))

    -- Lay the rake out along Y, centred on `centre`, so the orbit pivot is
    -- the middle of the train rather than the nose of the engine.
    local cursor = -total / 2.0
    previewEntities = {}

    for _, car in ipairs(cars) do
        local y = centre.y + cursor + (car.length / 2.0)

        -- isNetwork = false keeps these purely local: invisible to everyone
        -- else, and they never become networked objects that could linger.
        local ent = CreateVehicle(car.model, centre.x, y, centre.z, 0.0, false, false)
        SetModelAsNoLongerNeeded(car.model)

        if ent and DoesEntityExist(ent) then
            SetEntityCollision(ent, false, false)
            FreezeEntityPosition(ent, true)
            SetEntityInvincible(ent, true)
            SetEntityCanBeDamaged(ent, false)
            previewEntities[#previewEntities + 1] = ent
        end

        cursor = cursor + car.length + gap
    end

    if #previewEntities == 0 then
        Notify(locale('preview_failed'), 'error', 7000)
        return
    end

    -- Frame the whole rake: longer trains get a wider, higher orbit.
    local radius = math.max(total * (cfg.OrbitRadiusMult or 0.60), cfg.MinOrbitRadius or 15.0)
    local camZ   = centre.z + math.max(total * (cfg.CameraHeightMult or 0.20), cfg.MinCameraHeight or 4.5)

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, centre.x + radius, centre.y, camZ)
    PointCamAtCoord(previewCam, centre.x, centre.y, centre.z)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 0, true, true)

    FreezeEntityPosition(ped, true)
    DisplayRadar(false)

    previewActive = true
    lib.showTextUI(locale('preview_hint'))

    DebugPrint(('[preview] %s: %d car(s), %.1fm long, orbit radius %.1f')
        :format(trainConfig.label or trainConfig.model, #previewEntities, total, radius))

    local angle = 0.0
    local rotSpeed = cfg.RotateSpeed or 0.25
    local exitControl = cfg.ExitControl or 0xCEFD9220

    while previewActive do
        Wait(0)

        if rotSpeed > 0 then
            angle = (angle + rotSpeed) % 360.0
            local rad = math.rad(angle)
            SetCamCoord(previewCam,
                centre.x + math.cos(rad) * radius,
                centre.y + math.sin(rad) * radius,
                camZ)
            PointCamAtCoord(previewCam, centre.x, centre.y, centre.z)
        end

        if IsControlJustPressed(0, exitControl) then break end

        -- Safety: bail out if the player somehow dies mid-preview.
        if IsEntityDead(PlayerPedId()) then break end
    end

    EndTrainPreview()
end

---------------------------------------------------------------
-- NUI CALLBACK: PREVIEW FROM THE STATION MENU
-- Closes the menu, runs the preview, then reopens the menu so the player
-- lands back where they were and can hit Deploy.
---------------------------------------------------------------
RegisterNUICallback('previewTrain', function(data, cb)
    cb({ success = true })

    local trainConfig = data and data.trainIndex and Config.Trains[data.trainIndex]
    if not trainConfig then
        Notify(locale('preview_no_config'), 'error')
        return
    end

    SendNUIMessage({ action = 'closeStation' })
    SetNuiFocus(false, false)
    Wait(150) -- let the NUI actually hide before the camera takes over

    StartTrainPreview(trainConfig)

    -- Reopen the station menu where they left off.
    local station = GetCurrentStation and GetCurrentStation() or nil
    if station then
        Wait(100)
        OpenStationHUD(station)
    end
end)

---------------------------------------------------------------
-- SAFETY: never leave a camera or entities behind
---------------------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    EndTrainPreview()
end)
