-- Launch point placer: a translucent boat is moved with rsg-gizmo and its position is saved as the yard's launch point
local RSGCore = exports['rsg-core']:GetCoreObject()
local ghost = nil

local function deleteGhost()
    if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
    ghost = nil
end

function StartBoatPlacer(model, yardId, yardCoords)
    if placingBoat or exports['rsg-gizmo']:IsActive() then return end
    local hash = BoatsLoadModel(model)
    if not hash then
        BoatsNotify(locale('admin_bad_model', model), 'error')
        return BoatsReopenAdmin()
    end

    local ped = PlayerPedId()
    local start = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.Placer.startDistance, 0.0)
    ghost = CreateVehicle(hash, start.x, start.y, start.z, GetEntityHeading(ped), false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ghost or ghost == 0 then
        ghost = nil
        return BoatsReopenAdmin()
    end
    SetVehicleDoorsLocked(ghost, 2)
    placingBoat = true

    CreateThread(function()
        local cfg = Config.Placer
        while true do
            -- rsg-gizmo draws the HUD and handles every control; the ghost keeps its place after a confirm
            local res = exports['rsg-gizmo']:Edit(ghost, {
                title = locale('ui_spawn_assistant'),
                rotation = 'z',
                allowWater = true,
                maxDistance = cfg.maxDistance,
                alpha = cfg.alpha,
                startMode = 'fine',
                validate = function(coords)
                    if yardCoords and #(coords - yardCoords.xyz) > Config.MaxPointDistance then
                        return false, locale('too_far')
                    end
                    return true
                end,
            })
            if not res then
                BoatsNotify(locale('place_cancel'), 'inform')
                break
            end
            -- the server re-checks the distance to the yard; if it refuses, keep editing
            local saved = RSGCore.Functions.AwaitCallback('rsg-boats:server:saveSpawn', nil,
                { yard = yardId, x = res.coords.x, y = res.coords.y, z = res.coords.z, w = res.heading })
            if saved then break end
        end

        deleteGhost()
        placingBoat = false
        Wait(250) -- let the confirm key release before the panel takes focus
        BoatsReopenAdmin()
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteGhost()
end)
