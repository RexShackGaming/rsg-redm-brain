lib.locale()

--------------------------------------
-- butcher npcs: spawn when close, despawn when far
--------------------------------------
local spawnedPeds = {} -- [index] = ped | true while spawning

local function fade(ped, from, to)
    local step = from < to and 51 or -51
    for alpha = from, to, step do
        if not DoesEntityExist(ped) then return end
        SetEntityAlpha(ped, alpha, false)
        Wait(40)
    end
end

local function spawnButcher(v)
    local model = v.npcmodel
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(model) then
        print(('[rsg-hunting] failed to load butcher model %s'):format(tostring(model)))
        return nil
    end

    local c = v.npccoords
    local ped = CreatePed(model, c.x, c.y, c.z - 1.0, c.w, false, false, 0, 0)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return nil end

    SetEntityAlpha(ped, Config.FadeIn and 0 or 255, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)

    if Config.EnableTarget then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'npc_butcher',
                icon = 'fa-solid fa-paw',
                label = locale('open_butcher_shop'),
                distance = 3.0,
                onSelect = OpenButcherMenu,
            }
        })
    end

    if Config.FadeIn then fade(ped, 0, 255) end
    return ped
end

local function despawnButcher(ped)
    if not DoesEntityExist(ped) then return end
    if Config.EnableTarget then exports.ox_target:removeLocalEntity(ped, 'npc_butcher') end
    if Config.FadeIn then fade(ped, 255, 0) end
    DeletePed(ped)
end

CreateThread(function()
    local range = Config.DistanceSpawn or 20.0
    while true do
        local coords = GetEntityCoords(cache.ped)
        for k, v in ipairs(Config.ButcherLocations) do
            local near = #(coords - v.npccoords.xyz) < range
            local current = spawnedPeds[k]

            if near and not current then
                spawnedPeds[k] = true
                CreateThread(function()
                    spawnedPeds[k] = spawnButcher(v)
                end)
            elseif not near and type(current) == 'number' then
                spawnedPeds[k] = nil
                CreateThread(function() despawnButcher(current) end)
            end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, ped in pairs(spawnedPeds) do
        if type(ped) == 'number' and DoesEntityExist(ped) then DeletePed(ped) end
    end
end)
