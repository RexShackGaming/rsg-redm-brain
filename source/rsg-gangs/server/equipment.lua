local RSGCore = exports['rsg-core']:GetCoreObject()

local equipmentEntities = {} -- [gangName][itemId][instanceId] = netId
local pendingSpawns = {}     -- [instanceId] = os.time() the spawn request expires
local placementLocks = {}    -- ['gang|item'] = { src, expires }

local SPAWN_REQUEST_SECONDS = 20
local PLACEMENT_LOCK_SECONDS = 150

local function getEquipmentConfig(itemId)
    for _, cfg in ipairs(Config.GangEquipment) do
        if cfg.id == itemId then return cfg end
    end
    return nil
end

local function maxDeployedFor(cfg)
    return cfg.maxDeployed or 1
end

local function deployedCount(gang, itemId)
    return gang.equipment[itemId] and #gang.equipment[itemId] or 0
end

local function memberGang(src)
    local citizenid = RSGGangs.GetPlayerCitizenId(src)
    if not citizenid then return nil end
    return RSGGangs.FindGangByMember(citizenid), citizenid
end

local function entityFor(gangName, itemId, instanceId)
    local netId = equipmentEntities[gangName]
        and equipmentEntities[gangName][itemId]
        and equipmentEntities[gangName][itemId][instanceId]
    if not netId or netId == 0 then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return nil end
    return entity
end

local function forgetEntity(gangName, itemId, instanceId)
    if equipmentEntities[gangName] and equipmentEntities[gangName][itemId] then
        if equipmentEntities[gangName][itemId][instanceId] then
            equipmentEntities[gangName][itemId][instanceId] = nil
            TriggerClientEvent('rsg-gangs:client:equipmentUnregistered', -1, gangName, itemId, instanceId)
        end
    end
    pendingSpawns[instanceId] = nil
end

local function deleteTrackedEntity(gangName, itemId, instanceId)
    local entity = entityFor(gangName, itemId, instanceId)
    if entity then DeleteEntity(entity) end
    forgetEntity(gangName, itemId, instanceId)
end

-- True when the gang has at least one of `itemId` deployed (used by crafting/stash).
local function hasDeployed(gang, itemId)
    return gang.equipment[itemId] ~= nil and #gang.equipment[itemId] > 0
end

-- True when `src` is standing within `distance` of any deployed `itemId` of the gang.
local function playerNearEquipment(src, gang, itemId, distance)
    local list = gang.equipment[itemId]
    if not list then return false end
    for _, instance in ipairs(list) do
        if RSGGangs.IsNear(src, instance, distance) then return true end
    end
    return false
end

RSGGangs.HasDeployedEquipmentItem = hasDeployed
RSGGangs.PlayerNearEquipment = playerNearEquipment

RSGGangs.GangHasDeployedEquipment = function(gangName)
    local gang = RSGGangs.Gangs[gangName]
    if not gang then return false end
    for _, list in pairs(gang.equipment) do
        if #list > 0 then return true end
    end
    return false
end

RSGGangs.DeleteAllGangEquipment = function(gangName)
    local items = equipmentEntities[gangName]
    if not items then return end
    for itemId, instances in pairs(items) do
        for instanceId in pairs(instances) do
            deleteTrackedEntity(gangName, itemId, instanceId)
        end
    end
    equipmentEntities[gangName] = nil
end

-- Where the wagon is right now (live entity first, saved parking spot as fallback).
local function wagonReference(gang)
    if not gang.wagon then return nil end
    return vector3(gang.wagon.x, gang.wagon.y, gang.wagon.z)
end

local function lockKey(gangName, itemId) return gangName .. '|' .. itemId end

local function placementBusy(gangName, itemId, src)
    local lock = placementLocks[lockKey(gangName, itemId)]
    return lock ~= nil and lock.expires > os.time() and lock.src ~= src
end

local function clearPlacement(gangName, itemId, src)
    local key = lockKey(gangName, itemId)
    local lock = placementLocks[key]
    if lock and (lock.src == src or lock.expires <= os.time()) then placementLocks[key] = nil end
end

-- Asks `src` to spawn one deployed instance and gives it the single-use right to register it.
local function requestClientSpawn(src, gangName, itemId, instance)
    pendingSpawns[instance.id] = os.time() + SPAWN_REQUEST_SECONDS
    RSGGangs.Grant(src, 'equip:' .. instance.id, SPAWN_REQUEST_SECONDS + 30)
    TriggerClientEvent('rsg-gangs:client:spawnEquipmentAt', src, gangName, itemId, instance)
end

---------------------------------------------------------------------
-- Deploy: step 1, the server approves a placement session
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:deployEquipment', function(itemId)
    local src = source
    if RSGGangs.OnCooldown(src, 'deploy', 1500) then return end
    if type(itemId) ~= 'string' then return end

    local gang, citizenid = memberGang(src)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end

    if not RSGGangs.HasPermission(gang.members[citizenid].rank, 'equipment') then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return
    end

    local cfg = getEquipmentConfig(itemId)
    if not cfg then return end

    local wagon = wagonReference(gang)
    if not wagon then RSGGangs.Notify(src, locale('error_equipment_no_wagon'), 'error') return end
    if not RSGGangs.IsNear(src, wagon, Config.WagonInteractDistance) then
        RSGGangs.Notify(src, locale('error_too_far'), 'error')
        return
    end

    local maxAllowed = maxDeployedFor(cfg)
    if deployedCount(gang, itemId) >= maxAllowed then
        RSGGangs.Notify(src, locale('error_equipment_max_deployed', cfg.label, maxAllowed), 'error')
        return
    end

    if placementBusy(gang.name, itemId, src) then
        RSGGangs.Notify(src, locale('error_equipment_placement_busy', cfg.label), 'error')
        return
    end

    placementLocks[lockKey(gang.name, itemId)] = { src = src, expires = os.time() + PLACEMENT_LOCK_SECONDS }
    RSGGangs.Grant(src, 'place:' .. lockKey(gang.name, itemId), PLACEMENT_LOCK_SECONDS)

    TriggerClientEvent('rsg-gangs:client:closeMenu', src)
    TriggerClientEvent('rsg-gangs:client:startEquipmentPlacement', src, gang.name, itemId, gang.wagon)
end)

RegisterNetEvent('rsg-gangs:server:equipmentPlacementCancelled', function(itemId)
    local src = source
    local gang = memberGang(src)
    if not gang or type(itemId) ~= 'string' then return end

    RSGGangs.ConsumeGrant(src, 'place:' .. lockKey(gang.name, itemId))
    clearPlacement(gang.name, itemId, src)
end)

---------------------------------------------------------------------
-- Deploy: step 2, the player confirmed a spot. Everything is re-checked here.
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:equipmentPlaced', function(itemId, coords, heading)
    local src = source
    if type(itemId) ~= 'string' or not RSGGangs.ValidCoords(coords) or not RSGGangs.IsFinite(heading) then return end

    local gang, citizenid = memberGang(src)
    if not gang then return end

    local key = lockKey(gang.name, itemId)
    if not RSGGangs.ConsumeGrant(src, 'place:' .. key) then return end
    clearPlacement(gang.name, itemId, src)

    if not RSGGangs.HasPermission(gang.members[citizenid].rank, 'equipment') then return end

    local cfg = getEquipmentConfig(itemId)
    local wagon = wagonReference(gang)
    if not cfg or not wagon then return end

    local pos = vector3(coords.x, coords.y, coords.z)

    -- The spot has to be close to the wagon (per item) and close to the player who chose it.
    if #(pos - wagon) > cfg.maxPlacementDistance + 1.0 then
        RSGGangs.Notify(src, locale('error_equipment_too_far'), 'error')
        return
    end
    if not RSGGangs.IsNear(src, pos, math.max(cfg.maxPlacementDistance, 15.0) + 10.0) then
        RSGGangs.Notify(src, locale('error_too_far'), 'error')
        return
    end

    local maxAllowed = maxDeployedFor(cfg)
    if deployedCount(gang, itemId) >= maxAllowed then
        RSGGangs.Notify(src, locale('error_equipment_max_deployed', cfg.label, maxAllowed), 'error')
        return
    end

    local ok, instanceId = pcall(MySQL.insert.await, [[
        INSERT INTO rsg_gang_equipment (gang_name, item_id, x, y, z, heading)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { gang.name, itemId, coords.x, coords.y, coords.z, heading })
    if not ok or not instanceId then
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end

    local instance = { id = instanceId, x = coords.x, y = coords.y, z = coords.z, heading = heading }
    gang.equipment[itemId] = gang.equipment[itemId] or {}
    table.insert(gang.equipment[itemId], instance)

    requestClientSpawn(src, gang.name, itemId, instance)
    RSGGangs.AddLog(gang, RSGGangs.GetPlayerCitizenId(src), 'equip_deploy', cfg.label)
    RSGGangs.Notify(src, locale('success_equipment_deployed', cfg.label), 'success')
    RSGGangs.BroadcastGangUpdate(gang)
end)

---------------------------------------------------------------------
-- A client reports the prop it spawned for an instance
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:equipmentSpawned', function(gangName, itemId, instanceId, netId)
    local src = source
    if type(gangName) ~= 'string' or type(itemId) ~= 'string' or type(instanceId) ~= 'number' or type(netId) ~= 'number' then return end
    if not RSGGangs.ConsumeGrant(src, 'equip:' .. instanceId) then return end

    local gang = RSGGangs.Gangs[gangName]
    local cfg = getEquipmentConfig(itemId)
    if not gang or not cfg then return end

    local known = false
    for _, instance in ipairs(gang.equipment[itemId] or {}) do
        if instance.id == instanceId then known = true break end
    end
    if not known then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 3 or GetEntityModel(entity) ~= joaat(cfg.prop) then
        DeleteEntity(entity)
        return
    end

    -- Duplicate spawn (two clients answered): keep the first, remove this one.
    local existing = entityFor(gangName, itemId, instanceId)
    if existing and existing ~= entity then
        DeleteEntity(entity)
        pendingSpawns[instanceId] = nil
        return
    end

    equipmentEntities[gangName] = equipmentEntities[gangName] or {}
    equipmentEntities[gangName][itemId] = equipmentEntities[gangName][itemId] or {}
    equipmentEntities[gangName][itemId][instanceId] = netId
    pendingSpawns[instanceId] = nil
    TriggerClientEvent('rsg-gangs:client:equipmentRegistered', -1, gangName, itemId, instanceId, netId)
end)

---------------------------------------------------------------------
-- Pack away (most recently deployed instance of that item first)
---------------------------------------------------------------------
RegisterNetEvent('rsg-gangs:server:packEquipment', function(itemId)
    local src = source
    if RSGGangs.OnCooldown(src, 'pack', 1000) then return end
    if type(itemId) ~= 'string' then return end

    local gang, citizenid = memberGang(src)
    if not gang then RSGGangs.Notify(src, locale('error_no_gang'), 'error') return end

    if not RSGGangs.HasPermission(gang.members[citizenid].rank, 'equipment') then
        RSGGangs.Notify(src, locale('error_no_permission'), 'error')
        return
    end

    local cfg = getEquipmentConfig(itemId)
    if not cfg then return end

    local list = gang.equipment[itemId]
    if not list or #list == 0 then
        RSGGangs.Notify(src, locale('error_equipment_already_stored', cfg.label), 'error')
        return
    end

    local wagon = wagonReference(gang)
    if not wagon or not RSGGangs.IsNear(src, wagon, Config.WagonInteractDistance) then
        RSGGangs.Notify(src, locale('error_too_far'), 'error')
        return
    end

    local instance = list[#list]
    if not RSGGangs.DbOk('DELETE FROM rsg_gang_equipment WHERE id = ?', { instance.id }) then
        RSGGangs.Notify(src, locale('error_generic'), 'error')
        return
    end
    table.remove(list)
    deleteTrackedEntity(gang.name, itemId, instance.id)

    RSGGangs.AddLog(gang, RSGGangs.GetPlayerCitizenId(src), 'equip_pack', cfg.label)
    RSGGangs.Notify(src, locale('success_equipment_packed', cfg.label), 'success')
    RSGGangs.BroadcastGangUpdate(gang)
end)

RegisterNetEvent('rsg-gangs:server:requestEquipmentRegistry', function()
    local src = source
    if RSGGangs.OnCooldown(src, 'equipRegistry', 2000) then return end

    local registry = {}
    for gangName, items in pairs(equipmentEntities) do
        for itemId, instances in pairs(items) do
            for instanceId, netId in pairs(instances) do
                registry[#registry + 1] = { gangName = gangName, itemId = itemId, instanceId = instanceId, netId = netId }
            end
        end
    end
    TriggerClientEvent('rsg-gangs:client:equipmentRegistrySync', src, registry)
end)

---------------------------------------------------------------------
-- Proximity streaming: props exist only while someone is near them.
---------------------------------------------------------------------
CreateThread(function()
    while not RSGGangs.Loaded do Wait(100) end

    while true do
        local positions = RSGGangs.PlayerPositions()
        local now = os.time()

        for gangName, gang in pairs(RSGGangs.Gangs) do
            for itemId, list in pairs(gang.equipment) do
                for _, instance in ipairs(list) do
                    local coords = vector3(instance.x, instance.y, instance.z)

                    if entityFor(gangName, itemId, instance.id) then
                        if not RSGGangs.NearestPlayer(positions, coords, Config.DespawnProximityRadius) then
                            deleteTrackedEntity(gangName, itemId, instance.id)
                        end
                    else
                        -- Entity is gone: drop the stale net id, then respawn once someone is close.
                        forgetEntity(gangName, itemId, instance.id)

                        local waiting = pendingSpawns[instance.id]
                        if not waiting or waiting < now then
                            pendingSpawns[instance.id] = nil
                            local src = RSGGangs.NearestPlayer(positions, coords, Config.RespawnProximityRadius)
                            if src then
                                requestClientSpawn(src, gangName, itemId, instance)
                                Wait(500) -- stagger so a burst of nearby props does not spawn on one tick
                            end
                        end
                    end
                end
            end
        end

        Wait(Config.ProximityCheckInterval)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for gangName in pairs(equipmentEntities) do
        RSGGangs.DeleteAllGangEquipment(gangName)
    end
end)
