-- Gizmo-style placement: the ghost prop follows where you aim,
-- with drawn X/Y/Z axis handles, rotation and height adjustment.
Placement = {}

local CONTROLS = {
    place   = 0x07CE1E61, -- LMB
    cancel  = 0xF84FA74F, -- RMB
    cancel2 = 0x156F7119, -- Backspace
    rotL    = 0xDE794E3E, -- Q
    rotR    = 0xCEFD9220, -- E
    up      = 0x6319DB71, -- Arrow Up
    down    = 0x05CA7C52, -- Arrow Down
}

local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

local function camRaycast(dist, ignore)
    local camPos = GetGameplayCamCoord()
    local dest = camPos + rotToDir(GetGameplayCamRot(2)) * dist
    local handle = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 1, ignore, 0)
    local status, hit, endCoords, normal = 1, false, vector3(0, 0, 0), vector3(0, 0, 0)
    repeat
        status, hit, endCoords, normal = GetShapeTestResult(handle)
        if status == 1 then Wait(0) end
    until status ~= 1
    return hit == 1 or hit == true, endCoords, normal
end

local function drawAxis(origin, heading)
    local r = math.rad(heading)
    local fwd   = vector3(-math.sin(r), math.cos(r), 0.0)
    local right = vector3(math.cos(r), math.sin(r), 0.0)
    local len = 0.8
    local o = origin + vector3(0, 0, 0.05)
    DrawLine(o.x, o.y, o.z, o.x + right.x * len, o.y + right.y * len, o.z, 230, 70, 70, 255)   -- X
    DrawLine(o.x, o.y, o.z, o.x + fwd.x * len,   o.y + fwd.y * len,   o.z, 90, 210, 90, 255)   -- Y
    DrawLine(o.x, o.y, o.z, o.x, o.y, o.z + len, 80, 140, 240, 255)                            -- Z
end

local function drawRing(origin, radius, valid)
    local cr, cg, cb = 111, 191, 115
    if not valid then cr, cg, cb = 224, 85, 79 end
    local seg = 24
    for i = 0, seg - 1 do
        local a1, a2 = (i / seg) * math.pi * 2, ((i + 1) / seg) * math.pi * 2
        DrawLine(origin.x + math.cos(a1) * radius, origin.y + math.sin(a1) * radius, origin.z + 0.03,
                 origin.x + math.cos(a2) * radius, origin.y + math.sin(a2) * radius, origin.z + 0.03, cr, cg, cb, 220)
    end
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 5000 then return nil end
        Wait(10)
    end
    return hash
end
Placement.LoadModel = loadModel

---Starts placement. checkFn(coords) -> ok, reason
---@return vector3|nil coords, number|nil heading
function Placement.Start(model, checkFn, invalidMsg)
    local hash = loadModel(model)
    if not hash then return nil end

    local ped = PlayerPedId()
    local start = GetEntityCoords(ped)
    local ghost = CreateObject(hash, start.x, start.y, start.z - 5.0, false, false, false)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetModelAsNoLongerNeeded(hash)

    local heading, heightOffset = GetEntityHeading(ped), 0.0
    local result, resultHeading = nil, nil
    lib.showTextUI(locale('place_help'), { position = 'left-center' })

    while true do
        Wait(0)
        for _, c in pairs(CONTROLS) do DisableControlAction(0, c, true) end
        DisableControlAction(0, 0xB2F377E8, true) -- melee attack
        DisableControlAction(0, 0x8FFC75D6, true) -- sprint

        local hit, coords = camRaycast(Config.PlaceMaxDistance + 6.0, ghost)
        local pedPos = GetEntityCoords(ped)
        local valid, reason = false, nil

        if hit then
            local pos = coords + vector3(0, 0, heightOffset)
            SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(ghost, heading)

            if #(pedPos - coords) > Config.PlaceMaxDistance then
                reason = locale('place_too_far')
            else
                valid, reason = true, nil
                if checkFn then valid, reason = checkFn(pos) end
            end

            drawAxis(pos, heading)
            drawRing(pos, 0.45, valid)
        end

        -- frame-rate independent: 90 deg/s rotate, 0.3 m/s height
        local dt = GetFrameTime()
        if IsDisabledControlPressed(0, CONTROLS.rotL) then heading = (heading + 90.0 * dt) % 360 end
        if IsDisabledControlPressed(0, CONTROLS.rotR) then heading = (heading - 90.0 * dt) % 360 end
        if IsDisabledControlPressed(0, CONTROLS.up)   then heightOffset = math.min(heightOffset + 0.3 * dt, 0.5) end
        if IsDisabledControlPressed(0, CONTROLS.down) then heightOffset = math.max(heightOffset - 0.3 * dt, -0.5) end

        if IsDisabledControlJustPressed(0, CONTROLS.place) then
            if hit and valid then
                result, resultHeading = GetEntityCoords(ghost), heading
                break
            else
                Utils.notify(reason or invalidMsg or locale('place_invalid'), 'error')
            end
        end

        if IsDisabledControlJustPressed(0, CONTROLS.cancel) or IsDisabledControlJustPressed(0, CONTROLS.cancel2)
            or IsEntityDead(ped) then
            break
        end
    end

    lib.hideTextUI()
    if DoesEntityExist(ghost) then DeleteObject(ghost) end
    return result, resultHeading
end
