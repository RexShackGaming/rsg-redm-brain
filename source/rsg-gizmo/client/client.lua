local RSGCore = exports['rsg-core']:GetCoreObject()

local active = false     -- a placement session is running
local cancelFlag = false -- set by exports Cancel()
local session = nil      -- { ghosts = { ent, ... } } or { edit = ent, pos, rot, alpha, frozen } for cleanup on stop
local memory = {}        -- last placement per calling resource + model (Config.Remember)

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
        if GetGameTimer() > timeout then
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
        Wait(10)
    end
    return hash
end

local function merge(opts)
    local o = {}
    for k, v in pairs(Config.Defaults) do o[k] = v end
    for k, v in pairs(opts or {}) do o[k] = v end
    if type(o.maxDistance) ~= 'number' then o.maxDistance = Config.Defaults.maxDistance end
    if Config.Limits.enabled then o.maxDistance = math.min(o.maxDistance, Config.Limits.maxDistance) end
    return o
end

local function rotToDir(rot)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * c, math.cos(rz) * c, math.sin(rx))
end

-- Camera ray that looks through the player and their mount. Returns hit, coords, normal
local function cameraRay(dist, skip, ped)
    local camPos = GetGameplayCamCoord()
    local dir = rotToDir(GetGameplayCamRot(2))
    local dest = camPos + dir * dist
    local from, ignore = camPos, ped
    for _ = 1, 4 do
        local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, dest.x, dest.y, dest.z, -1, ignore, 7)
        local _, hit, coords, normal, entity = GetShapeTestResult(ray)
        if hit ~= 1 then return false end
        if not entity or entity == 0 or not skip[entity] then return true, coords, normal end
        from, ignore = coords + dir * 0.05, entity -- hit our own ped / mount: carry on past it
    end
    return false
end

-- Surface normal straight below a point (used for the slope check in fine mode)
local function normalBelow(pos, ignore)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(pos.x, pos.y, pos.z + 1.0, pos.x, pos.y, pos.z - 2.0, -1, ignore, 7)
    local _, hit, _, normal = GetShapeTestResult(ray)
    if hit == 1 then return normal end
end

local function slopeAngle(normal)
    return math.deg(math.acos(math.max(-1.0, math.min(1.0, normal.z))))
end

local function ground(x, y, z)
    for _, up in ipairs({ 0.5, 2.0, 5.0 }) do
        local found, gz = GetGroundZFor_3dCoord(x, y, z + up, false)
        if found then return gz end
    end
    return z
end

-- every control disabled while a session runs (built once, not every frame)
local blocked = {}
for _, c in pairs(Config.Controls) do blocked[#blocked + 1] = c end
for _, c in ipairs(Config.BlockControls) do blocked[#blocked + 1] = c end

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

-- ring on the ground showing how far from the player a prop may be placed
local function drawRing(center, radius, z, r, g, b, a)
    local steps = 48
    local prev = vector3(center.x + radius, center.y, z)
    for i = 1, steps do
        local ang = (i / steps) * math.pi * 2
        local p = vector3(center.x + math.cos(ang) * radius, center.y + math.sin(ang) * radius, z)
        DrawLine(prev.x, prev.y, prev.z, p.x, p.y, p.z, r, g, b, a)
        prev = p
    end
end

local function hudStrings(o)
    local K = Config.KeyLabels
    return {
        title = o.title or locale('hud_title'),
        modeFree = locale('hud_mode_free'), modeFine = locale('hud_mode_fine'),
        confirm = locale('hud_confirm'), cancel = locale('hud_cancel'),
        mode = locale('hud_mode'), ground = locale('hud_ground'), reset = locale('hud_reset'),
        move = locale('hud_move'), height = locale('hud_height'), rotate = locale('hud_rotate'),
        precise = locale('hud_precise'), valid = locale('hud_valid'),
        coords = locale('hud_coords'), rotation = locale('hud_rotation'),
        roll = locale('hud_roll'), snap = locale('hud_snap'), snapOn = locale('hud_snap_on'),
        undo = locale('hud_undo'), redo = locale('hud_redo'),
        keys = {
            confirm = K.confirm, cancel = K.cancel, mode = K.mode, ground = K.ground, reset = K.reset,
            move = K.move, height = locale('key_scroll'), rotate = K.rotate, precise = K.precise,
            roll = K.roll, snap = K.snap, undo = K.undo, redo = K.redo,
        },
    }
end

local function r2(n) return math.floor(n * 100 + 0.5) / 100 end
local function snapTo(v, step) return math.floor(v / step + 0.5) * step end

-- place group children relative to the anchor (heading-only, same maths as Gizmo.GroupTransform)
local function updateChildren(items, pos, yaw)
    local rad = math.rad(yaw)
    local c, s = math.cos(rad), math.sin(rad)
    for i = 2, #items do
        local it = items[i]
        local off = it.offset
        SetEntityCoordsNoOffset(it.ent, pos.x + off.x * c - off.y * s, pos.y + off.x * s + off.y * c, pos.z + off.z, false, false, false)
        SetEntityRotation(it.ent, 0.0, 0.0, (yaw + it.heading) % 360, 2, true)
    end
end

-------------------------------------------------
-- core session
-- items : { { ent, offset, heading }, ... }  item 1 is the anchor (ghost, or the entity being edited)
-- o     : merged options
-- returns result table or nil, plus the final mode and snap state
-------------------------------------------------
local function run(items, o)
    local ped = PlayerPedId()
    local C = Config.Controls
    local anchor = items[1].ent
    local group = #items > 1
    for _, it in ipairs(items) do it.mn, it.mx = GetModelDimensions(GetEntityModel(it.ent)) end
    local mn, mx = items[1].mn, items[1].mx
    local baseOffset = -mn.z -- lift so the bottom of the model sits on the surface
    local axisLen = math.max(0.5, math.max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z) * 0.75)

    local pos = o.startCoords or GetEntityCoords(anchor)
    local rot = o.startRotation or GetEntityRotation(anchor, 2)
    local pitch, roll, yaw = rot.x, rot.y, rot.z
    local lockPitch, lockRoll = pitch, roll -- kept when rotation is 'z' so Edit never flattens a tilted prop
    local mode = o.startMode == 'fine' and 'fine' or 'free'
    local snapOn = o.snap == true
    local inputFrom = GetGameTimer() + Config.InputGrace -- ignore confirm/cancel while the opening key is still down
    local result

    local skip = {}                       -- entities the camera ray looks through (player, mount)
    local normal = nil                    -- surface normal under the prop (slope check)
    local ringZ, ringAt = 0.0, 0
    local lastDeny = 0
    local last = {}

    -- undo / redo: an edit becomes one step once the inputs have been idle for Config.HistoryDelay
    local undoStack, redoStack = {}, {}
    local activeUntil = 0
    local function cur() return { pos = pos, pitch = pitch, roll = roll, yaw = yaw, mode = mode } end
    local committed = cur()
    local function differs(s)
        return s.pitch ~= pitch or s.roll ~= roll or s.yaw ~= yaw or (mode == 'fine' and s.pos ~= pos)
    end
    local function flush()
        if differs(committed) then
            undoStack[#undoStack + 1] = committed
            if #undoStack > Config.History then table.remove(undoStack, 1) end
            redoStack = {}
        end
        committed = cur()
    end
    local function restore(s)
        pos, pitch, roll, yaw = s.pos, s.pitch, s.roll, s.yaw
        if s.mode ~= mode then
            mode = s.mode
            SendNUIMessage({ action = 'mode', mode = mode })
        end
        committed = cur()
    end

    SendNUIMessage({ action = 'show', strings = hudStrings(o), rotation = o.rotation, mode = mode, snap = snapOn })

    while active do
        Wait(0)
        if cancelFlag then break end

        for i = 1, #blocked do DisableControlAction(0, blocked[i], true) end

        local now = GetGameTimer()
        local dt = GetFrameTime()
        local mult = IsDisabledControlPressed(0, C.precise) and o.precision or 1.0
        local rotating = IsDisabledControlPressed(0, C.rotate)
        local rollHeld = o.rotation == 'all' and IsDisabledControlPressed(0, C.roll)
        local wheel = (IsDisabledControlJustPressed(0, C.scrollUp) and 1 or 0) - (IsDisabledControlJustPressed(0, C.scrollDn) and 1 or 0)
        local ax = (IsDisabledControlPressed(0, C.right) and 1 or 0) - (IsDisabledControlPressed(0, C.left) and 1 or 0)
        local ay = (IsDisabledControlPressed(0, C.up) and 1 or 0) - (IsDisabledControlPressed(0, C.down) and 1 or 0)
        if ax ~= 0 or ay ~= 0 or wheel ~= 0 then activeUntil = now + Config.HistoryDelay end

        if IsDisabledControlJustPressed(0, C.mode) then
            flush()
            mode = mode == 'free' and 'fine' or 'free'
            committed = cur()
            SendNUIMessage({ action = 'mode', mode = mode })
        end
        if IsDisabledControlJustPressed(0, C.snap) then snapOn = not snapOn end
        if IsDisabledControlJustPressed(0, C.reset) then
            pitch, roll = 0.0, 0.0
            activeUntil = now + Config.HistoryDelay
        end
        if IsDisabledControlJustPressed(0, C.undo) then
            flush()
            local s = table.remove(undoStack)
            if s then
                redoStack[#redoStack + 1] = cur()
                restore(s)
            end
        elseif IsDisabledControlJustPressed(0, C.redo) then
            flush()
            local s = table.remove(redoStack)
            if s then
                undoStack[#undoStack + 1] = cur()
                restore(s)
            end
        end

        -- rotation
        if rollHeld then
            roll = roll + ax * o.rotateSpeed * dt * mult + wheel * o.scrollRotate * mult
        elseif rotating or mode == 'free' then
            if wheel ~= 0 then yaw = yaw + wheel * o.scrollRotate * mult end
            yaw = yaw - ax * o.rotateSpeed * dt * mult
            if rotating and o.rotation == 'all' then pitch = pitch + ay * o.rotateSpeed * dt * mult end
        end
        if o.rotation ~= 'all' then
            pitch, roll = lockPitch, lockRoll
        else
            pitch, roll = pitch % 360, roll % 360
        end
        yaw = yaw % 360

        -- position
        for k in pairs(skip) do skip[k] = nil end
        skip[ped] = true
        local mount = GetMount(ped)
        if mount and mount ~= 0 then skip[mount] = true end

        if mode == 'free' then
            local hit, coords, n = cameraRay(o.rayDistance, skip, ped)
            if hit then
                pos = o.snapToGround and vector3(coords.x, coords.y, coords.z + baseOffset) or coords
                normal = n
            end
        elseif not rotating and not rollHeld then
            local camYaw = math.rad(GetGameplayCamRot(2).z)
            local fwd = vector3(-math.sin(camYaw), math.cos(camYaw), 0.0)
            local rgt = vector3(math.cos(camYaw), math.sin(camYaw), 0.0)
            pos = pos + (fwd * ay + rgt * ax) * o.moveSpeed * dt * mult
            if wheel ~= 0 then pos = pos + vector3(0.0, 0.0, wheel * o.scrollHeight * mult) end
        end

        if IsDisabledControlJustPressed(0, C.ground) then
            activeUntil = now + Config.HistoryDelay
            pos = vector3(pos.x, pos.y, ground(pos.x, pos.y, pos.z) + baseOffset)
            if o.rotation == 'all' then
                SetEntityCoordsNoOffset(anchor, pos.x, pos.y, pos.z, false, false, false)
                PlaceObjectOnGroundProperly(anchor, true)
                local gr = GetEntityRotation(anchor, 2)
                pitch, roll = gr.x, gr.y
                pos = GetEntityCoords(anchor)
            end
        end

        if now >= activeUntil and differs(committed) then flush() end

        -- snapping only affects what is placed, never the stored values, so slow nudges still accumulate
        local pPos, pPitch, pRoll, pYaw = pos, pitch, roll, yaw
        if snapOn then
            local grid, step = Config.Snap.grid, Config.Snap.angle
            pPos = vector3(snapTo(pos.x, grid), snapTo(pos.y, grid), mode == 'fine' and snapTo(pos.z, grid) or pos.z)
            pYaw = snapTo(yaw, step) % 360
            if o.rotation == 'all' then pPitch, pRoll = snapTo(pitch, step) % 360, snapTo(roll, step) % 360 end
        end

        -- move first so water / interior checks use this frame's position
        SetEntityCoordsNoOffset(anchor, pPos.x, pPos.y, pPos.z, false, false, false)
        SetEntityRotation(anchor, pPitch, pRoll, pYaw, 2, true)
        if group then updateChildren(items, pPos, pYaw) end

        local pedPos = GetEntityCoords(ped)
        local valid, reason = true, nil
        local inWater = false
        if not o.allowWater then
            for _, it in ipairs(items) do
                if IsEntityInWater(it.ent) then inWater = true break end
            end
        end
        local slope
        if o.maxSlope then
            local n = mode == 'fine' and normalBelow(pPos, anchor) or normal
            if n then slope = slopeAngle(n) end
        end

        if #(pedPos - pPos) > o.maxDistance then
            valid, reason = false, locale('invalid_distance')
        elseif inWater then
            valid, reason = false, locale('invalid_water')
        elseif not o.allowInterior and (GetInteriorFromEntity(anchor) ~= 0 or GetInteriorFromEntity(ped) ~= 0) then
            valid, reason = false, locale('invalid_interior')
        elseif slope and slope > o.maxSlope then
            valid, reason = false, locale('invalid_slope')
        elseif o.validate then
            local okCall, ok, why = pcall(o.validate, pPos, vector3(pPitch, pRoll, pYaw))
            if not okCall then dbg('validate error', ok) end
            if not okCall or not ok then valid, reason = false, (okCall and why) or locale('invalid_generic') end
        end

        for _, it in ipairs(items) do drawBox(it.ent, it.mn, it.mx, valid) end
        if mode == 'fine' then drawAxes(anchor, axisLen) end
        if o.showRange then
            if now >= ringAt then
                ringAt = now + 500
                ringZ = ground(pedPos.x, pedPos.y, pedPos.z) + 0.05
            end
            drawRing(pedPos, o.maxDistance, ringZ, colour(Config.Colours.range))
        end

        -- HUD (only when something changed)
        local px, py, pz, h, pp, rr = r2(pPos.x), r2(pPos.y), r2(pPos.z), r2(pYaw), r2(pPitch), r2(pRoll)
        if last.px ~= px or last.py ~= py or last.pz ~= pz or last.h ~= h or last.p ~= pp or last.r ~= rr
            or last.valid ~= valid or last.reason ~= reason or last.snap ~= snapOn then
            last = { px = px, py = py, pz = pz, h = h, p = pp, r = rr, valid = valid, reason = reason, snap = snapOn }
            SendNUIMessage({ action = 'update', valid = valid, reason = reason, snap = snapOn,
                coords = { px, py, pz }, rotation = { pp, rr, h } })
        end

        if IsEntityDead(ped) then break end

        if now >= inputFrom then
            if IsDisabledControlJustPressed(0, C.confirm) or IsDisabledControlJustPressed(0, C.confirm2) then
                if valid then
                    result = { coords = pPos, rotation = vector3(pPitch, pRoll, pYaw), heading = pYaw }
                    break
                end
                -- throttled so mashing LMB on an invalid spot cannot spam notifications
                if now >= lastDeny then
                    lastDeny = now + 1500
                    RSGCore.Functions.Notify({ title = o.title or locale('hud_title'), description = reason, type = 'error', duration = 4000 })
                end
            end

            if IsDisabledControlJustPressed(0, C.cancel) or IsDisabledControlJustPressed(0, C.cancel2) then
                break
            end
        end
    end

    return result, mode, snapOn
end

-- shared wrapper: always hides the HUD and clears state, even if run() errors
local function runSession(items, o)
    active, cancelFlag = true, false
    LocalPlayer.state:set('gizmoActive', true, false) -- lets other resources (e.g. rsg-voice) ignore input
    local ok, result, mode, snapOn = pcall(run, items, o)
    active = false
    LocalPlayer.state:set('gizmoActive', false, false)
    SendNUIMessage({ action = 'hide' })
    if not ok then dbg('error', result) return nil end
    return result, mode, snapOn
end

-------------------------------------------------
-- public API
-------------------------------------------------
local function notifyError(key)
    RSGCore.Functions.Notify({ title = locale('hud_title'), description = locale(key), type = 'error', duration = 4000 })
end

local function spawnGhost(hash, at, alpha)
    local ghost = CreateObject(hash, at.x, at.y, at.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAlpha(ghost, alpha, false)
    SetEntityCollision(ghost, false, false)
    SetEntityInvincible(ghost, true)
    FreezeEntityPosition(ghost, true)
    return ghost
end

-- last rotation / mode / snap used for this model by this resource becomes the next start
local function applyMemory(o, opts, key, ped)
    if not (Config.Remember and o.remember ~= false) then return end
    local m = memory[key]
    if not m then return end
    if not o.startRotation then
        local all = o.rotation == 'all'
        o.startRotation = vector3(all and m.rotation.x or 0.0, all and m.rotation.y or 0.0, m.rotation.z)
    end
    if not (opts and opts.startMode) then o.startMode = m.mode end
    if not (opts and opts.snap ~= nil) then o.snap = m.snap end
    if m.mode == 'fine' and not o.startCoords and #(GetEntityCoords(ped) - m.coords) <= o.maxDistance then
        o.startCoords = m.coords
    end
end

---Place one or more props as a group. Item 1 is the anchor; the rest keep their offset/heading relative to it.
---@param defs table[] { model, offset = vector3|nil, heading = number|nil }
---@param opts table|nil
---@param resName string|nil calling resource (for the placement memory)
local function placeDefs(defs, opts, resName)
    if active or type(defs) ~= 'table' or #defs == 0 then return nil end
    local o = merge(opts)
    local group = #defs > 1
    if group then o.rotation = 'z' end -- groups are heading-only so the server can rebuild them exactly

    local list, hashes = {}, {}
    for i, d in ipairs(defs) do
        local hash = loadModel(d.model)
        if not hash then
            for j = 1, i - 1 do SetModelAsNoLongerNeeded(hashes[j]) end
            notifyError('invalid_model')
            return nil
        end
        hashes[i] = hash
        list[i] = {
            model = d.model,
            offset = i == 1 and vector3(0.0, 0.0, 0.0) or (d.offset or vector3(0.0, 0.0, 0.0)),
            heading = i == 1 and 0.0 or (d.heading or 0.0),
        }
    end

    local ped = PlayerPedId()
    local key = ('%s:%s:%d'):format(resName or 'self', tostring(defs[1].model), #defs)
    applyMemory(o, opts, key, ped)
    if not o.startRotation then o.startRotation = vector3(0.0, 0.0, GetEntityHeading(ped)) end
    local start = o.startCoords or GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    o.startCoords = start

    local ghosts = {}
    for i, it in ipairs(list) do
        it.ent = spawnGhost(hashes[i], start, o.alpha)
        ghosts[i] = it.ent
    end

    session = { ghosts = ghosts }
    local result, mode, snapOn = runSession(list, o)
    session = nil

    for _, g in ipairs(ghosts) do
        if DoesEntityExist(g) then DeleteObject(g) end
    end
    if not result then return nil end

    if Config.Remember and o.remember ~= false then
        memory[key] = { rotation = result.rotation, mode = mode, snap = snapOn, coords = result.coords }
    end
    if group then result.items = Gizmo.GroupTransform(list, result.coords, result.heading) end
    return result
end

---Place a new prop. Blocks until confirmed or cancelled (call from a thread).
---@param model string|number
---@param opts table|nil
---@return table|nil { coords = vector3, rotation = vector3, heading = number }
local function Place(model, opts, resName)
    return placeDefs({ { model = model } }, opts, resName)
end

local function restoreEdit(entity, pos, rot, alpha, frozen, keep)
    if not DoesEntityExist(entity) then return end
    FreezeEntityPosition(entity, frozen)
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
    local origFrozen = IsEntityPositionFrozen(entity)
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

    session = { edit = entity, pos = origPos, rot = origRot, alpha = origAlpha, frozen = origFrozen }
    local result = runSession({ { ent = entity, offset = vector3(0.0, 0.0, 0.0), heading = 0.0 } }, o)
    session = nil

    restoreEdit(entity, origPos, origRot, origAlpha, origFrozen, result ~= nil)
    return result
end

exports('Place', function(model, opts) return Place(model, opts, GetInvokingResource()) end)
exports('PlaceMany', function(defs, opts) return placeDefs(defs, opts, GetInvokingResource()) end)
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

AddEventHandler('rsg-gizmo:client:placeMany', function(defs, opts, cb)
    CreateThread(function()
        local res = placeDefs(defs, opts)
        if cb then cb(res) end
    end)
end)

-------------------------------------------------
-- admin test commands (server checks permission)
-------------------------------------------------
RegisterNetEvent('rsg-gizmo:client:test', function(model)
    CreateThread(function()
        local res = Place(model or Config.TestCommand.model, { rotation = 'all', maxSlope = 35.0 })
        if not res then return end
        local c, r = res.coords, res.rotation
        print(('[rsg-gizmo] coords = vector3(%.2f, %.2f, %.2f), rotation = vector3(%.2f, %.2f, %.2f), heading = %.2f')
            :format(c.x, c.y, c.z, r.x, r.y, r.z, res.heading))
        RSGCore.Functions.Notify({ title = locale('hud_title'), description = locale('test_printed'), type = 'success', duration = 5000 })
    end)
end)

RegisterNetEvent('rsg-gizmo:client:testgroup', function()
    CreateThread(function()
        local res = placeDefs(Config.TestCommand.group)
        if not res then return end
        for i, it in ipairs(res.items) do
            print(('[rsg-gizmo] item %d %s coords = vector3(%.2f, %.2f, %.2f), heading = %.2f')
                :format(i, tostring(it.model), it.coords.x, it.coords.y, it.coords.z, it.heading))
        end
        RSGCore.Functions.Notify({ title = locale('hud_title'), description = locale('test_printed'), type = 'success', duration = 5000 })
    end)
end)

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    -- the session thread dies with the resource, so clean up here
    cancelFlag, active = true, false
    if session then
        for _, g in ipairs(session.ghosts or {}) do
            if DoesEntityExist(g) then DeleteObject(g) end
        end
        if session.edit then restoreEdit(session.edit, session.pos, session.rot, session.alpha, session.frozen, false) end
        session = nil
    end
    SendNUIMessage({ action = 'hide' })
end)
