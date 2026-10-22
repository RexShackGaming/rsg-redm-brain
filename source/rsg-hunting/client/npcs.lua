lib.locale()

local spawnedPeds = {}
local lastPlayerCoords = vector3(0, 0, 0)
local coordsUpdateTimer = 0
local COORDS_UPDATE_INTERVAL = Config.Performance and Config.Performance.NpcCoordsUpdate or 2000
local DISTANCE_CHECK_INTERVAL = Config.Performance and Config.Performance.NpcDistanceCheck or 3000
local lastDistanceCheck = 0
local modelCache = {} -- Cache for loaded models
local fadeSteps = {} -- Cache fade step calculations

-- Pre-calculate fade steps
CreateThread(function()
    for i = 0, 255, 51 do
        fadeSteps[#fadeSteps + 1] = i
    end
end)

CreateThread(function()
    while true do
        local currentTime = GetGameTimer()

        -- Update player coordinates less frequently
        if currentTime - coordsUpdateTimer > COORDS_UPDATE_INTERVAL then
            lastPlayerCoords = GetEntityCoords(PlayerPedId())
            coordsUpdateTimer = currentTime
        end

        -- Check distances less frequently for better performance
        if currentTime - lastDistanceCheck > DISTANCE_CHECK_INTERVAL then
            for k, v in pairs(Config.ButcherLocations) do
                local distance = #(lastPlayerCoords - v.npccoords.xyz)
                local spawnDistance = Config.Performance and Config.Performance.NpcSpawnDistance or Config.DistanceSpawn or 20.0

                -- Spawn NPC if player is close and NPC doesn't exist
                if distance < spawnDistance and not spawnedPeds[k] then
                    spawnedPeds[k] = true -- placeholder to prevent duplicate spawns
                    CreateThread(function() -- Spawn in separate thread to prevent blocking
                        local spawnedPed = NearButcherPed(v.npcmodel, v.npccoords)
                        if spawnedPed then
                            spawnedPeds[k] = { spawnedPed = spawnedPed }
                            if Config.Debug then
                                print('[rsg-hunting] Spawned butcher NPC at ' .. v.name)
                            end
                        else
                            spawnedPeds[k] = nil -- clear placeholder on failure
                        end
                    end)
                end

                -- Despawn NPC if player is far and NPC exists
                if distance >= spawnDistance and spawnedPeds[k] then
                    local pedData = spawnedPeds[k]
                    if type(pedData) == 'table' and pedData.spawnedPed then
                        spawnedPeds[k] = nil -- clear immediately to prevent duplicate despawns
                        CreateThread(function() -- Despawn in separate thread
                            if DoesEntityExist(pedData.spawnedPed) then
                                if Config.FadeIn then
                                    -- Optimized fade out
                                    for i = 255, 0, -51 do
                                        SetEntityAlpha(pedData.spawnedPed, i, false)
                                        Wait(30) -- Reduced wait time for smoother fade
                                    end
                                end
                                DeletePed(pedData.spawnedPed)
                                if Config.Debug then
                                    print('[rsg-hunting] Despawned butcher NPC at ' .. v.name)
                                end
                            end
                        end)
                    end
                end
            end
            lastDistanceCheck = currentTime
        end

        Wait(1000) -- Main loop wait
    end
end)

function NearButcherPed(npcmodel, npccoords)
    -- Check if model is already cached/loaded
    if not modelCache[npcmodel] then
        RequestModel(npcmodel)
        local timeout = 0
        while not HasModelLoaded(npcmodel) and timeout < 100 do -- Add timeout to prevent infinite loop
            Wait(50)
            timeout = timeout + 1
        end

        if not HasModelLoaded(npcmodel) then
            print('[rsg-hunting] Failed to load butcher model: ' .. tostring(npcmodel))
            return nil
        end

        modelCache[npcmodel] = true
    end

    local spawnedPed = CreatePed(npcmodel, npccoords.x, npccoords.y, npccoords.z - 1.0, npccoords.w, false, false, 0, 0)

    if not DoesEntityExist(spawnedPed) then
        print('[rsg-hunting] Failed to create butcher ped with model: ' .. tostring(npcmodel))
        return nil
    end

    -- Batch set entity properties for better performance
    SetEntityAlpha(spawnedPed, Config.FadeIn and 0 or 255, false)
    SetRandomOutfitVariation(spawnedPed, true)
    SetEntityCanBeDamaged(spawnedPed, false)
    SetEntityInvincible(spawnedPed, true)
    FreezeEntityPosition(spawnedPed, true)
    SetBlockingOfNonTemporaryEvents(spawnedPed, true)
    SetPedCanBeTargetted(spawnedPed, false)
    SetPedFleeAttributes(spawnedPed, 0, false)

    -- Optimized fade in with pre-calculated steps
    if Config.FadeIn then
        CreateThread(function() -- Don't block the main function
            for _, alpha in ipairs(fadeSteps) do
                if DoesEntityExist(spawnedPed) then
                    SetEntityAlpha(spawnedPed, alpha, false)
                    Wait(Config.Performance and Config.Performance.NpcFadeSpeed or 40)
                else
                    break
                end
            end
        end)
    end

    -- Add target interaction if enabled
    if Config.EnableTarget then
        CreateThread(function() -- Don't block the main function
            exports.ox_target:addLocalEntity(spawnedPed, {
                {
                    name = 'npc_butcher',
                    icon = 'far fa-eye',
                    label = locale('open_butcher_shop'),
                    onSelect = function()
                        TriggerEvent('rsg-hunting:client:butcher:mainmenu')
                    end,
                    distance = 3.0
                }
            })
        end)
    end

    return spawnedPed
end

-- cleanup
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for k, v in pairs(spawnedPeds) do
        if type(v) == 'table' and v.spawnedPed then
            DeletePed(v.spawnedPed)
        end
        spawnedPeds[k] = nil
    end
end)
