local RSGCore = exports['rsg-core']:GetCoreObject()

local active = false     -- a placement session is running
local cancelFlag = false -- set by exports Cancel()
local session = nil      -- { ghost = ent } or { edit = ent, pos, rot, alpha } for cleanup on stop

-------------------------------------------------
-- helpers
-------------------------------------------------
local function dbg(...) if Config.Debug then print('[rsg-gizmo]', ...) end end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function merge(opts)
    local o = {}
    for k, v in pairs(Config.Defaults) do o[k] = v end
    for k, v in pairs(opts or {}) do o[k] = v end
    return o
end

local function rotToDir(rot)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

-- Camera ray. Returns hit, coords, normal
local function cameraRay(dist, ignore)
    local camPos = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local dest = camPos + rotToDir(camRot) * dist
    local ray = StartExpensiveSynchronousShapeTestLosProbe(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, -1, ignore, 7)
    local _, hit, coords, normal = GetShapeTestResult(ray)
    return hit == 1, coords, normal
end

local function ground(x, y, z)
    for _, up in ipairs({ 0.5, 2.0, 5.0 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + up, false)
        if found then return gz end
    end
    return z
end

local function colour(c) return c[1], c[2], c[3], c[4] end

local function drawAxes(ent, len)
    local o = GetEntityCoords(ent)
    local x = GetOffsetFromEntityInWorldCoords(ent, len, 0.0, 0.0)
    local y = GetOffsetFromEntityInWorldCoords(ent, 0.0, len, 0.0)
    local z = GetOffsetFromEntityInWorldCoords(ent, 0.0, 0.0, len)
    DrawLine(o.x, o.y, o.z, x.x, x.y, x.z, colour(Config.Colours.axisX))
    DrawLine(o.x, o.y, o.z, y.x, y.y, y.z, colour(Config.Colours.axisY))
    DrawLine(o.x, o.y, o.z, z.x, z.y, z.z, colour(Config.Colours.axisZ))
end

-- corner index = x*4 + y*2 + z + 1
local EDGES = { {1,2},{3,4},{5,6},{7,8}, {1,3},{2,4},{5,7},{6,8}, {1,5},{2,6},{3,7},{4,8} }
local corners = {}

local function drawBox(ent, mn, mx, valid)
    local r, g, b, a = colour(valid and Config.Colours.valid or Config.Colours.invalid)
    local i = 0
    for _, px in ipairs({ mn.x, mx.x }) do
        for _, py in ipairs({ mn.y, mx.y }) do
            for _, pz in ipairs({ mn.z, mx.z }) do
                i = i + 1
                corners[i] = GetOffsetFromEntityInWorldCoords(ent, px, py, pz)
            end
        end
    end
    local c = corners
    for _, e in ipairs(EDGES) do
        local p1, p2 = c[e[1]], c[e[2]]
        DrawLine(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, r, g, b, a)
    end
end

local function hudStrings(o)
    return {
        title = o.title or locale('hud_title'),
        modeFree = locale('hud_mode_free'), modeFine = locale('hud_mode_fine'),
        confirm = locale('hud_confirm'), cancel = locale('hud_cancel'),
        mode = locale('hud_mode'), ground = locale('hud_ground'), reset = locale('hud_reset'),
        move = locale('hud_move'), height = locale('hud_height'), rotate = locale('hud_rotate'),
        precise = locale('hud_precise'), valid = locale('hud_valid'),
        coords = locale('hud_coords'), rotation = locale('hud_rotation'),
        keys = { confirm = 'LMB', cancel = 'RMB', mode = 'R', ground = 'G', reset = 'Q',
                 move = '← ↑ → ↓', height = locale('key_scroll'), rotate = 'Shift', precise = 'Ctrl' },
    }
end

local function r2(n) return math.floor(n * 100 + 0.5) / 100 end

-------------------------------------------------
-- core session
-- ent      : entity to move (ghost or existing)
-- o        : merged options
-- returns  : result table or nil
-------------------------------------------------
local function run(ent, o)
    local ped = PlayerPedId()
    local C = Config.Controls
    local mn, mx = GetModelDimensions(GetEntityModel(ent))
    local baseOffset = -mn.z -- lift so the bottom of the model sits on the surface
    local axisLen = math.max(0.5, math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z) * 0.75)

    local pos = o.startCoords or GetEntityCoords(ent)
    local rot = o.startRotation or GetEntityRotation(ent, 2)
    local pitch, roll, yaw = rot.x, rot.y, rot.z
    local mode = o.startMode == 'fine' and 'fine' or 'free'
    local result

    SendNUIMessage({ action = 'show', strings = hudStrings(o), rotation = o.rotation, mode = mode })
    local last = {}

    while active do
        Wait(0)
        if cancelFlag then break end

        for _, c in pairs(C) do DisableControlAction(0, c, true) end
        for _, c in ipairs(Config.BlockControls) do DisableControlAction(0, c, true) end

        local dt = GetFrameTime()
        local mult = IsDisabledControlPressed(0, C.precise) and o.precision or 1.0
        local rotating = IsDisabledControlPressed(0, C.rotate)
        local wheel = (IsDisabledControlJustPressed(0, C.scrollUp) and 1 or 0) - (IsDisabledControlJustPressed(0, C.scrollDn) and 1 or 0)
        local ax = (IsDisabledControlPressed(0, C.right) and 1 or 0) - (IsDisabledControlPressed(0, C.left) and 1 or 0)
        local ay = (IsDisabledControlPressed(0, C.up) and 1 or 0) - (IsDisabledControlPressed(0, C.down) and 1 or 0)

        if IsDisabledControlJustPressed(0, C.mode) then
            mode = mode == 'free' and 'fine' or 'free'
            SendNUIMessage({ action = 'mode', mode = mode })
        end
        if IsDisabledControlJustPressed(0, C.reset) then pitch, roll = 0.0, 0.0 end

        -- rotation (Shift held, or free mode wheel/arrows)
        if rotating or mode == 'free' then
            if wheel ~= 0 then yaw = yaw + wheel * o.scrollRotate * mult end
            yaw = yaw - ax * o.rotateSpeed * dt * mult
            if rotating and o.rotation == 'all' then pitch = pitch + ay * o.rotateSpeed * dt * mult end
        end
        if o.rotation ~= 'all' then pitch, roll = 0.0, 0.0 end
        yaw = yaw % 360

        -- position
        if mode == 'free' then
            local hit, coords = cameraRay(o.rayDistance, ped)
            if hit then
                pos = o.snapToGround and vector3(coords.x, coords.y, coords.z + baseOffset) or coords
            end
        elseif not rotating then
            local camYaw = math.rad(GetGameplayCamRot(2).z)
            local fwd = vector3(-math.sin(camYaw), math.cos(camYaw), 0.0)
            local rgt = vector3(math.cos(camYaw), math.sin(camYaw), 0.0)
            pos = pos + (fwd * ay + rgt * ax) * o.moveSpeed * dt * mult
            if wheel ~= 0 then pos = pos + vector3(0.0, 0.0, wheel * o.scrollHeight * mult) end
        end

        if IsDisabledControlJustPressed(0, C.ground) then
            pos = vector3(pos.x, pos.y, ground(pos.x, pos.y, pos.z) + baseOffset)
            if o.rotation == 'all' then
                SetEntityCoordsNoOffset(ent, pos.x, pos.y, pos.z, false, false, false)
                PlaceObjectOnGroundProperly(ent, true)
                local gr = GetEntityRotation(ent, 2)
                pitch, roll = gr.x, gr.y
                pos = GetEntityCoords(ent)
            end
        end

        -- move first so water / interior checks use this frame's position
        SetEntityCoordsNoOffset(ent, pos.x, pos.y, pos.z, false, false, false)
        SetEntityRotation(ent, pitch, roll, yaw, 2, true)

        local valid, reason = true, nil
        if #(GetEntityCoords(ped) - pos) > o.maxDistance then
            valid, reason = false, locale('invalid_distance')
        elseif not o.allowWater and IsEntityInWater(ent) then
            valid, reason = false, locale('invalid_water')
        elseif not o.allowInterior and (GetInteriorFromEntity(ent) ~= 0 or GetInteriorFromEntity(ped) ~= 0) then
            valid, reason = false, locale('invalid_interior')
        elseif o.validate then
            local okCall, ok, why = pcall(o.validate, pos, vector3(pitch, roll, yaw))
            if not okCall then dbg('validate error', ok) end
            if not okCall or not ok then valid, reason = false, (okCall and why) or locale('invalid_generic') end
        end

        drawBox(ent, mn, mx, valid)
        if mode == 'fine' then drawAxes(ent, axisLen) end

        -- HUD (only when something changed)
        local px, py, pz, h = r2(pos.x), r2(pos.y), r2(pos.z), r2(yaw)
        if last.px ~= px or last.py ~= py or last.pz ~= pz or last.h ~= h or last.p ~= r2(pitch) or last.r ~= r2(roll) or last.valid ~= valid or last.reason ~= reason then
            last = { px = px, py = py, pz = pz, h = h, p = r2(pitch), r = r2(roll), valid = valid, reason = reason }
            SendNUIMessage({ action = 'update', valid = valid, reason = reason,
                coords = { px, py, pz }, rotation = { r2(pitch), r2(roll), h } })
        end

        if IsDisabledControlJustPressed(0, C.confirm) or IsDisabledControlJustPressed(0, C.confirm2) then
            if valid then
                result = { coords = pos, rotation = vector3(pitch, roll, yaw), heading = yaw }
                break
            end
            RSGCore.Functions.Notify({ title = o.title or locale('hud_title'), description = reason, type = 'error', duration = 4000 })
        end

        if IsDisabledControlJustPressed(0, C.cancel) or IsDisabledControlJustPressed(0, C.cancel2) or IsEntityDead(ped) then
            break
        end
    end

    return result
end

-- shared wrapper: always hides the HUD and clears state, even if run() errors
local function runSession(ent, o)
    active, cancelFlag = true, false
    LocalPlayer.state:set('gizmoActive', true, false) -- lets other resources (e.g. rsg-voice) ignore input
    local ok, result = pcall(run, ent, o)
    active = false
    LocalPlayer.state:set('gizmoActive', false, false)
    SendNUIMessage({ action = 'hide' })
    if not ok then dbg('error', result) return nil end
    return result
end

-------------------------------------------------
-- public API
-------------------------------------------------

---Place a new prop. Blocks until confirmed or cancelled (call from a thread).
---@param model string|number
---@param opts table|nil
---@return table|nil { coords = vector3, rotation = vector3, heading = number }
local function Place(model, opts)
    if active then return nil end
    local o = merge(opts)
    local hash = loadModel(model)
    if not hash then
        RSGCore.Functions.Notify({ title = locale('hud_title'), description = locale('invalid_model'), type = 'error', duration = 4000 })
        return nil
    end

    local ped = PlayerPedId()
    local start = o.startCoords or GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    local ghost = CreateObject(hash, start.x, start.y, start.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(ghost, o.alpha, false)
    SetEntityCollision(ghost, false, false)
    SetEntityInvincible(ghost, true)
    FreezeEntityPosition(ghost, true)
    if not o.startRotation then o.startRotation = vector3(0.0, 0.0, GetEntityHeading(ped)) end
    o.startCoords = start

    session = { ghost = ghost }
    local result = runSession(ghost, o)
    session = nil

    if DoesEntityExist(ghost) then DeleteObject(ghost) end
    return result
end

local function restoreEdit(entity, pos, rot, alpha, keep)
    if not DoesEntityExist(entity) then return end
    if alpha >= 255 then ResetEntityAlpha(entity) else SetEntityAlpha(entity, alpha, false) end
    SetEntityCollision(entity, true, true)
    if not keep then
        SetEntityCoordsNoOffset(entity, pos.x, pos.y, pos.z, false, false, false)
        SetEntityRotation(entity, rot.x, rot.y, rot.z, 2, true)
    end
end

---Move an existing (local or networked) entity. On cancel it goes back where it was.
---@param entity number
---@param opts table|nil
---@return table|nil
local function Edit(entity, opts)
    if active or not DoesEntityExist(entity) then return nil end
    local o = merge(opts)
    local origPos, origRot = GetEntityCoords(entity), GetEntityRotation(entity, 2)
    local origAlpha = GetEntityAlpha(entity)
    o.startCoords, o.startRotation = o.startCoords or origPos, o.startRotation or origRot
    o.startMode = opts and opts.startMode or 'fine'

    if NetworkGetEntityIsNetworked(entity) and not NetworkHasControlOfEntity(entity) then
        NetworkRequestControlOfEntity(entity)
        local timeout = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do Wait(10) end
        if not NetworkHasControlOfEntity(entity) then dbg('no network control of entity', entity) return nil end
    end
    SetEntityAlpha(entity, o.alpha, false)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)

    session = { edit = entity, pos = origPos, rot = origRot, alpha = origAlpha }
    local result = runSession(entity, o)
    session = nil

    restoreEdit(entity, origPos, origRot, origAlpha, result ~= nil)
    return result
end

exports('Place', Place)
exports('Edit', Edit)
exports('IsActive', function() return active end)
exports('Cancel', function() if active then cancelFlag = true end end)

-- Event form for scripts that prefer events: cb(result|nil)
AddEventHandler('rsg-gizmo:client:place', function(model, opts, cb)
    CreateThread(function()
        local res = Place(model, opts)
        if cb then cb(res) end
    end)
end)

-------------------------------------------------
-- admin test command (server checks permission)
-------------------------------------------------
RegisterNetEvent('rsg-gizmo:client:test', function(model)
    CreateThread(function()
        local res = Place(model or Config.TestCommand.model, { rotation = 'all' })
        if not res then return end
        local c, r = res.coords, res.rotation
        print(('[rsg-gizmo] coords = vector3(%.2f, %.2f, %.2f), rotation = vector3(%.2f, %.2f, %.2f), heading = %.2f')
            :format(c.x, c.y, c.z, r.x, r.y, r.z, res.heading))
        RSGCore.Functions.Notify({ title = locale('hud_title'), description = locale('test_printed'), type = 'success', duration = 5000 })
    end)
end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    -- the session thread dies with the resource, so clean up here
    cancelFlag, active = true, false
    if session then
        if session.ghost and DoesEntityExist(session.ghost) then DeleteObject(session.ghost) end
        if session.edit then restoreEdit(session.edit, session.pos, session.rot, session.alpha, false) end
        session = nil
    end
    SendNUIMessage({ action = 'hide' })
end)
