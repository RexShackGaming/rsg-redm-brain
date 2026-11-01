local spawnedPeds = {}

local function LoadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function FadePed(ped, from, to, step)
    for alpha = from, to, step do
        if not DoesEntityExist(ped) then return end
        SetEntityAlpha(ped, alpha, false)
        Wait(50)
    end
end

local function SpawnPortPed(portId, port)
    if not LoadModel(port.npcmodel) then return end
    local c = port.npccoords
    local ped = CreatePed(port.npcmodel, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(port.npcmodel)

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetEntityAlpha(ped, Config.FadeIn and 0 or 255, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'guarma_port_npc',
            icon = 'fa-solid fa-ferry',
            label = locale('open_menu'),
            distance = 3.0,
            onSelect = function() OpenTicketUI(portId) end,
        },
    })

    if Config.FadeIn then FadePed(ped, 0, 255, 51) end
    return ped
end

local function DespawnPed(portId, fade)
    local ped = spawnedPeds[portId]
    spawnedPeds[portId] = nil
    if not ped or not DoesEntityExist(ped) then return end
    exports.ox_target:removeLocalEntity(ped, 'guarma_port_npc')
    if fade then FadePed(ped, 255, 0, -51) end
    DeleteEntity(ped)
end

CreateThread(function()
    while true do
        local coords = GetEntityCoords(cache.ped)
        for portId, port in pairs(Config.Ports) do
            local dist = #(coords - port.npccoords.xyz)
            if dist < Config.DistanceSpawn then
                if not spawnedPeds[portId] then
                    spawnedPeds[portId] = SpawnPortPed(portId, port)
                end
            elseif spawnedPeds[portId] and dist > Config.DistanceSpawn + 10.0 then
                DespawnPed(portId, Config.FadeIn)
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for portId in pairs(spawnedPeds) do DespawnPed(portId, false) end
end)
