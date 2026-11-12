local RSGCore = exports['rsg-core']:GetCoreObject()
local spawnedPeds = {}

local function Fade(ped, from, to, step)
    if not Config.FadeIn then return end
    for i = from, to, step do
        SetEntityAlpha(ped, i, false)
        Wait(25)
    end
end

local function SpawnForeman(v)
    local modelHash = type(v.npcmodel) == 'string' and joaat(v.npcmodel) or v.npcmodel
    if not RSGCore.Functions.RequestModel(modelHash) then return nil end

    local c = v.npccoords
    local ped = CreatePed(modelHash, c.x, c.y, c.z - 1.0, c.w, false, false, 0, 0)
    SetModelAsNoLongerNeeded(modelHash)
    if not DoesEntityExist(ped) then return nil end

    SetEntityAlpha(ped, 0, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    TaskStartScenarioInPlace(ped, joaat(v.scenario), 0, true)

    Fade(ped, 0, 255, 51)
    SetEntityAlpha(ped, 255, false)

    exports['rsg-target']:addLocalEntity(ped, RocksWorkshopOptions())
    return ped
end

local function DespawnForeman(k)
    local ped = spawnedPeds[k]
    spawnedPeds[k] = nil
    if not ped or not DoesEntityExist(ped) then return end
    exports['rsg-target']:removeLocalEntity(ped)
    Fade(ped, 255, 0, -51)
    DeletePed(ped)
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        for k, v in ipairs(Config.WorkshopTents) do
            local near = #(playerCoords - v.npccoords.xyz) < Config.DistanceSpawn
            if near and not spawnedPeds[k] then
                spawnedPeds[k] = SpawnForeman(v)
            elseif not near and spawnedPeds[k] then
                DespawnForeman(k)
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            exports['rsg-target']:removeLocalEntity(ped)
            DeletePed(ped)
        end
    end
end)
