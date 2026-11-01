-- simple prop placer gizmo: ghost prop follows camera aim, rotate / raise, confirm or cancel
Placer = {}
local ghost

local K = Config.PlacerKeys

local function helpText()
    return locale('cl_place_help'):format(
        K.confirm.label, K.cancel.label, K.rotateLeft.label, K.rotateRight.label, K.raise.label, K.lower.label)
end

local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local n = math.abs(math.cos(x))
    return vector3(-math.sin(z) * n, math.cos(z) * n, math.sin(x))
end

local function raycast(dist)
    local camPos = GetGameplayCamCoord()
    local dest = camPos + rotToDir(GetGameplayCamRot(2)) * dist
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 1 | 16, cache.ped, 0)
    local _, hit, coords = GetShapeTestResult(ray)
    return hit == 1, coords
end

function Placer.Start(model, cb)
    if ghost then return end
    local hash = joaat(model)
    lib.requestModel(hash, 10000)
    local pc = GetEntityCoords(cache.ped)
    local help = helpText() -- built once, not every frame
    ghost = CreateObject(hash, pc.x, pc.y, pc.z, false, false, false)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    local heading, zOff = GetEntityHeading(cache.ped), 0.0
    local coords = pc

    CreateThread(function()
        while ghost do
            Wait(0)
            local hit, c = raycast(Config.PlacerMaxDistance)
            if hit then coords = c end
            if IsDisabledControlPressed(0, K.rotateLeft.hash) then heading = heading + Config.PlacerRotateSpeed end
            if IsDisabledControlPressed(0, K.rotateRight.hash) then heading = heading - Config.PlacerRotateSpeed end
            if IsDisabledControlPressed(0, K.raise.hash) then zOff = zOff + Config.PlacerHeightSpeed end
            if IsDisabledControlPressed(0, K.lower.hash) then zOff = zOff - Config.PlacerHeightSpeed end
            SetEntityCoordsNoOffset(ghost, coords.x, coords.y, coords.z + zOff, false, false, false)
            SetEntityHeading(ghost, heading)

            for _, k in pairs(K) do DisableControlAction(0, k.hash, true) end
            DisableControlAction(0, 0xB2F377E8, true) -- melee attack
            DisableControlAction(0, 0x8FFC75D6, true) -- sprint (shift)

            local txt = CreateVarString(10, 'LITERAL_STRING', help)
            SetTextScale(0.35, 0.35); SetTextCentre(true); SetTextColor(255, 255, 255, 230)
            BgDisplayText(txt, 0.5, 0.9)

            if IsDisabledControlJustPressed(0, K.confirm.hash) then
                local final = GetEntityCoords(ghost)
                Placer.Stop(); SetModelAsNoLongerNeeded(hash)
                cb({ x = final.x, y = final.y, z = final.z, heading = heading })
                return
            elseif IsDisabledControlJustPressed(0, K.cancel.hash) then
                Placer.Stop(); SetModelAsNoLongerNeeded(hash)
                cb(nil)
                return
            end
        end
    end)
end

function Placer.Stop()
    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    ghost = nil
end
