local RSGCore = exports['rsg-core']:GetCoreObject()

-- Admin rock placement with rsg-gizmo (/addrock)
local placing = false

local function Notify(description, nType, duration)
    RSGCore.Functions.Notify({
        title = locale('admin_title'),
        description = description,
        type = nType or 'inform',
        duration = duration or Config.NotificationDuration,
    })
end

-- rsg-gizmo places the ghost with SetEntityCoordsNoOffset, but rocks are spawned with
-- CreateObject (client.lua), which applies the model's own offset. Measure that offset
-- with a hidden test object and send coords that make the spawned rock land exactly
-- where the gizmo ghost was (existing rocks are left untouched).
local function CompensateSpawnOffset(pos, heading)
    local hash = RSGCore.Functions.RequestModel(Config.RockModel)
    if not hash then return pos end
    local probe = CreateObject(hash, pos.x, pos.y, pos.z, false, false, false)
    if not DoesEntityExist(probe) then return pos end
    SetEntityVisible(probe, false)
    SetEntityCollision(probe, false, false)
    SetEntityHeading(probe, heading or 0.0)
    local actual = GetEntityCoords(probe)
    DeleteObject(probe)
    SetModelAsNoLongerNeeded(hash)
    return pos - (actual - pos)
end

local function StartPlacing(oreType, radius)
    if placing or exports['rsg-gizmo']:IsActive() then return end
    oreType = oreType or 'rock'
    radius = radius or 2.0
    placing = true

    Notify(locale('admin_place_start', oreType, radius), 'inform', 7000)

    CreateThread(function()
        local maxDist = Config.AdminPlaceDistance or 15.0
        local res = exports['rsg-gizmo']:Place(Config.RockModel, {
            title = locale('admin_place_title', oreType),
            maxDistance = maxDist,
            rotation = 'z', -- rocks store a heading only
            snapToGround = true,
            allowInterior = Config.AdminPlaceAllowInterior ~= false, -- mines are interiors
            allowWater = false,
        })
        placing = false
        if not res then
            Notify(locale('admin_place_cancel'), 'inform')
            return
        end
        local coords = CompensateSpawnOffset(res.coords, res.heading)
        TriggerServerEvent('rsg-rocks:server:AdminAddRock', oreType, radius, coords, res.heading)
    end)
end

RegisterNetEvent('rsg-rocks:client:StartPlaceRock', function(oreType, radius)
    StartPlacing(oreType, radius)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if placing and exports['rsg-gizmo']:IsActive() then exports['rsg-gizmo']:Cancel() end
end)
