local notify = RSGGangsClient.Notify

local knownEquipment = {}   -- [netId] = { gangName, itemId }
local targeted = {}         -- [entity] = true
local placementActive = false

local function equipmentConfigById(itemId)
    for _, cfg in ipairs(Config.GangEquipment) do
        if cfg.id == itemId then return cfg end
    end
    return nil
end

local function stationForItem(itemId)
    if not Config.Crafting or not Config.Crafting.enabled then return nil end
    for _, station in ipairs(Config.Crafting.stations or {}) do
        if station.equipmentId == itemId then return station end
    end
    return nil
end

local function stashForItem(itemId)
    if Config.GangStash and Config.GangStash.enabled and Config.GangStash.equipmentId == itemId then
        return Config.GangStash
    end
    return nil
end

---------------------------------------------------------------------
-- Targets on the crafting station / strongbox props
---------------------------------------------------------------------
local function isMine(targetEntity, fallbackGang)
    if not DoesEntityExist(targetEntity) then return false end
    local info = knownEquipment[NetworkGetNetworkIdFromEntity(targetEntity)]
    local owner = info and info.gangName or fallbackGang
    return owner ~= nil and owner == RSGGangsClient.gangName
end

local function addTarget(entity, gangName, option)
    if targeted[entity] then return end
    targeted[entity] = true
    option.distance = option.distance or Config.StationInteractDistance
    option.canInteract = function(targetEntity) return isMine(targetEntity, gangName) end
    RSGGangsClient.AddEntityTarget(entity, { option })
end

local function trackAndTarget(gangName, itemId, netId)
    if not gangName or not itemId or not netId or netId == 0 then return end
    knownEquipment[netId] = { gangName = gangName, itemId = itemId }

    local station = stationForItem(itemId)
    local stash = not station and stashForItem(itemId) or nil
    if not station and not stash then return end

    CreateThread(function()
        local waited = 0
        local entity = NetworkGetEntityFromNetworkId(netId)
        while (entity == 0 or not DoesEntityExist(entity)) and waited < 30000 do
            Wait(500)
            waited = waited + 500
            entity = NetworkGetEntityFromNetworkId(netId)
        end
        if entity == 0 or not DoesEntityExist(entity) then return end

        if station then
            addTarget(entity, gangName, {
                name = 'rsg_gangs_craft_' .. station.id,
                icon = station.targetIcon or 'fa-solid fa-hammer',
                label = station.targetLabel or locale('notify_target_craft'),
                onSelect = function() TriggerEvent('rsg-gangs:client:openCraftMenu', station.id) end,
            })
        else
            addTarget(entity, gangName, {
                name = 'rsg_gangs_stash_strongbox',
                icon = stash.targetIcon or 'fa-solid fa-box',
                label = stash.targetLabel or locale('notify_target_open_stash'),
                onSelect = function() TriggerServerEvent('rsg-gangs:server:openGangStash') end,
            })
        end
    end)
end

RegisterNetEvent('rsg-gangs:client:equipmentRegistered', function(gangName, itemId, _, netId)
    trackAndTarget(gangName, itemId, netId)
end)

RegisterNetEvent('rsg-gangs:client:equipmentUnregistered', function(gangName, itemId, instanceId)
    -- Net ids are not reused for a different prop, so stale entries are simply pruned by gang/item.
    for netId, info in pairs(knownEquipment) do
        if info.gangName == gangName and info.itemId == itemId then
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity == 0 or not DoesEntityExist(entity) then
                knownEquipment[netId] = nil
                if entity ~= 0 then targeted[entity] = nil end
            end
        end
    end
end)

RegisterNetEvent('rsg-gangs:client:equipmentRegistrySync', function(registry)
    for _, entry in ipairs(registry or {}) do
        trackAndTarget(entry.gangName, entry.itemId, entry.netId)
    end
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('rsg-gangs:server:requestEquipmentRegistry')
end)

---------------------------------------------------------------------
-- Spawning a saved or freshly placed instance
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:client:spawnEquipmentAt', function(gangName, itemId, instance)
    if type(gangName) ~= 'string' or type(instance) ~= 'table' or not instance.x or not instance.id then return end
    local cfg = equipmentConfigById(itemId)
    if not cfg then return end

    local modelHash = joaat(cfg.prop)
    if not RSGGangsClient.LoadModel(modelHash) then
        notify(locale('notify_equipment_model_failed', cfg.label), 'error')
        return
    end

    local obj = CreateObject(modelHash, instance.x, instance.y, instance.z, true, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(obj) then
        notify(locale('notify_equipment_spawn_failed', cfg.label), 'error')
        return
    end

    SetEntityCoords(obj, instance.x, instance.y, instance.z, false, false, false, false)
    SetEntityHeading(obj, instance.heading or 0.0)
    -- Settle the prop before freezing, otherwise it keeps its flat creation pitch/roll.
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)

    local netId = RSGGangsClient.GetValidNetworkId(obj, 15000)
    if netId == 0 then
        print(('^3[rsg-gangs] no network id for %s, deleting it so the server can retry^7'):format(cfg.label))
        DeleteEntity(obj)
        return
    end

    TriggerServerEvent('rsg-gangs:server:equipmentSpawned', gangName, itemId, instance.id, netId)
end)

---------------------------------------------------------------------
-- Interactive placement with rsg-gizmo
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:client:startEquipmentPlacement', function(_, itemId, wagon)
    if placementActive then
        TriggerServerEvent('rsg-gangs:server:equipmentPlacementCancelled', itemId)
        return
    end

    local cfg = equipmentConfigById(itemId)
    if not cfg or type(wagon) ~= 'table' or not wagon.x then
        TriggerServerEvent('rsg-gangs:server:equipmentPlacementCancelled', itemId)
        return
    end

    placementActive = true
    local wagonCoords = vector3(wagon.x, wagon.y, wagon.z)
    local maxDistance = cfg.maxPlacementDistance or 10.0

    CreateThread(function()
        local result = exports['rsg-gizmo']:Place(cfg.prop, {
            title = locale('notify_placement_title', cfg.label),
            maxDistance = maxDistance + 5.0,
            rotation = 'z',
            validate = function(coords)
                if #(vector3(coords.x, coords.y, coords.z) - wagonCoords) > maxDistance then
                    return false, locale('notify_placement_too_far')
                end
                return true
            end,
        })
        placementActive = false

        if not result then
            TriggerServerEvent('rsg-gangs:server:equipmentPlacementCancelled', itemId)
            notify(locale('notify_equipment_placement_cancelled'), 'error')
            return
        end

        TriggerServerEvent('rsg-gangs:server:equipmentPlaced', itemId, result.coords, result.heading or 0.0)
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for entity in pairs(targeted) do
        if DoesEntityExist(entity) then RSGGangsClient.RemoveEntityTarget(entity) end
    end
end)
