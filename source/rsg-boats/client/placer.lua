-- Ghost boat placer: admin positions a translucent, non-colliding boat and saves it as the launch point
local RSGCore = exports['rsg-core']:GetCoreObject()
local placing = false
local ghost = nil

local function deleteGhost()
    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    ghost = nil
end

local function disableControls()
    local k = Config.Keys
    for _, key in pairs(k) do DisableControlAction(0, key, true) end
    DisableControlAction(0, `INPUT_COVER`, true)
    DisableControlAction(0, `INPUT_JUMP`, true)
end

function StartBoatPlacer(model, yardId)
    if placing then return end
    local hash = BoatsLoadModel(model)
    if not hash then
        BoatsNotify(locale('admin_bad_model', model), 'error')
        return BoatsReopenAdmin()
    end

    local ped = PlayerPedId()
    local start = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.Placer.startDistance, 0.0)
    local heading = GetEntityHeading(ped)

    ghost = CreateVehicle(hash, start.x, start.y, start.z, heading, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ghost or ghost == 0 then
        ghost = nil
        return BoatsReopenAdmin()
    end
    SetEntityAlpha(ghost, Config.Placer.alpha, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)
    SetVehicleDoorsLocked(ghost, 2)

    placing = true
    placingBoat = true
    SendNUIMessage({ action = 'placer', show = true, model = model, locales = BoatsUiLocales() })

    CreateThread(function()
        local pos = vector3(start.x, start.y, start.z)
        local cfg = Config.Placer
        local k = Config.Keys
        local saved = false
        local lastPos, lastHeading

        while placing do
            Wait(0)
            disableControls()

            local mult = IsDisabledControlPressed(0, k.fast) and cfg.fastMultiplier or 1.0
            local camH = math.rad(GetGameplayCamRot(2).z)
            local fwd = vector3(-math.sin(camH), math.cos(camH), 0.0)
            local rgt = vector3(math.cos(camH), math.sin(camH), 0.0)
            local step = cfg.moveStep * mult

            if IsDisabledControlPressed(0, k.forward) then pos = pos + fwd * step end
            if IsDisabledControlPressed(0, k.back) then pos = pos - fwd * step end
            if IsDisabledControlPressed(0, k.right) then pos = pos + rgt * step end
            if IsDisabledControlPressed(0, k.left) then pos = pos - rgt * step end
            if IsDisabledControlPressed(0, k.up) then pos = pos + vector3(0, 0, cfg.heightStep * mult) end
            if IsDisabledControlPressed(0, k.down) then pos = pos - vector3(0, 0, cfg.heightStep * mult) end
            if IsDisabledControlPressed(0, k.rotL) then heading = heading + cfg.rotateStep * mult end
            if IsDisabledControlPressed(0, k.rotR) then heading = heading - cfg.rotateStep * mult end
            heading = heading % 360.0

            -- keep the ghost within reach of the admin
            local pc = GetEntityCoords(PlayerPedId())
            if #(pos - pc) > cfg.maxDistance then
                pos = pc + (pos - pc) / #(pos - pc) * cfg.maxDistance
            end

            SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(ghost, heading)

            -- only update the HUD when something moved (not every frame)
            if pos ~= lastPos or heading ~= lastHeading then
                lastPos, lastHeading = pos, heading
                SendNUIMessage({ action = 'placerPos', x = pos.x, y = pos.y, z = pos.z, w = heading })
            end

            if IsDisabledControlJustReleased(0, k.confirm) then
                saved = RSGCore.Functions.AwaitCallback('rsg-boats:server:saveSpawn', nil,
                    { yard = yardId, x = pos.x, y = pos.y, z = pos.z, w = heading })
                if saved then placing = false end
            elseif IsDisabledControlJustReleased(0, k.cancel) then
                BoatsNotify(locale('place_cancel'), 'inform')
                placing = false
            end
        end

        deleteGhost()
        placingBoat = false
        SendNUIMessage({ action = 'placer', show = false })
        Wait(250) -- let the Enter/Backspace release clear before NUI takes focus
        BoatsReopenAdmin()
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    placing = false
    deleteGhost()
end)
