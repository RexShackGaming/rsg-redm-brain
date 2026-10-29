-------------------------------------
-- Fussar's soldiers (server): networked peds everyone sees.
-- Server spawns/despawns them; the client that owns each ped runs its patrol/combat AI.
-- Routes from RDR2 region_law_guama_fussar.c
-------------------------------------
if not Config.Soldiers.enabled then return end

local routes = {}   -- [routeIndex] = { ped, ped, ... }

-- centre of each route, so players anywhere along it keep it active
local centres = {}
for index, route in ipairs(Config.Soldiers.routes) do
    local sum = vector3(0.0, 0.0, 0.0)
    for _, node in ipairs(route.nodes) do sum = sum + node end
    centres[index] = sum / #route.nodes
end

local function PublishNetIds()
    local list = {}
    for index, peds in pairs(routes) do
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) then
                list[#list + 1] = NetworkGetNetworkIdFromEntity(ped)
            end
        end
    end
    GlobalState.guarmaSoldiers = list
end

local function GetPlayerCoords()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 then list[#list + 1] = GetEntityCoords(ped) end
    end
    return list
end

local function AnyNear(players, coords, radius)
    for _, pos in ipairs(players) do
        if #(pos - coords) < radius then return true end
    end
    return false
end

-- keep a route alive while players are near its centre or near any of its soldiers (chases)
local function RouteInUse(players, index)
    if AnyNear(players, centres[index], Config.Soldiers.despawnDistance) then return true end
    for _, ped in ipairs(routes[index] or {}) do
        if DoesEntityExist(ped) and AnyNear(players, GetEntityCoords(ped), Config.Soldiers.despawnDistance) then
            return true
        end
    end
    return false
end

local function SpawnRoute(index, route)
    local cfg = Config.Soldiers
    local peds = {}
    for i = 1, cfg.pedsPerRoute do
        local node = (i - 1) % #route.nodes + 1
        local pos = route.nodes[node]
        -- CREATE_PED (CFX, natives/db/CFX.md): pedType, model, x, y, z, heading, isNetwork, bScriptHostPed
        local ped = CreatePed(4, cfg.model, pos.x, pos.y, pos.z, 0.0, true, true)
        local timeout = GetGameTimer() + 3000
        while not DoesEntityExist(ped) and GetGameTimer() < timeout do Wait(0) end
        if DoesEntityExist(ped) then
            SetEntityOrphanMode(ped, 2)                    -- keep the ped when its owner leaves
            SetEntityDistanceCullingRadius(ped, cfg.despawnDistance)
            local state = Entity(ped).state
            state:set('fussarRoute', index, true)
            state:set('fussarNode', node % #route.nodes + 1, true)
            state:set('fussarWeapon', route.sniper and cfg.sniperWeapon or cfg.weapons[math.random(#cfg.weapons)], true)
            peds[#peds + 1] = ped
        end
    end
    routes[index] = peds
end

local function DespawnRoute(index)
    for _, ped in ipairs(routes[index] or {}) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    routes[index] = nil
end

CreateThread(function()
    GlobalState.guarmaSoldiers = {}
    while true do
        local changed = false
        local players = GetPlayerCoords()
        for index, route in ipairs(Config.Soldiers.routes) do
            if route.enabled then
                if not routes[index] and AnyNear(players, centres[index], Config.Soldiers.spawnDistance) then
                    SpawnRoute(index, route); changed = true
                elseif routes[index] and not RouteInUse(players, index) then
                    DespawnRoute(index); changed = true   -- dead soldiers respawn next time someone comes back
                end
            end
        end
        if changed then PublishNetIds() end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for index in pairs(routes) do DespawnRoute(index) end
    GlobalState.guarmaSoldiers = {}
end)
