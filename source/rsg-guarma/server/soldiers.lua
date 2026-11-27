-------------------------------------
-- Fussar's soldiers (server): networked peds everyone sees.
-- Server spawns/despawns them; the client that owns each ped runs its patrol/combat AI.
-- Routes from RDR2 region_law_guama_fussar.c
-------------------------------------
if not Config.Soldiers.enabled then return end

local routes = {} -- [routeIndex] = { ped, ped, ... }
local wipedAt = {} -- [routeIndex] = game time when the whole patrol was found dead
local counted = {} -- [ped] = true once its death has been processed

-------------------------------------
-- alert level (raised by killing soldiers)
-------------------------------------
local heat = 0.0
local alertLevel = 0

local function LevelFor(value)
    local level = 0
    for i, def in ipairs(Config.Alert.levels) do
        -- a small margin, so decay doesn't drop a level the instant it is reached
        if value > def.kills - 1 then level = i end
    end
    return level
end

function Guarma.AlertLevel()
    return alertLevel
end

local function PedsPerRoute()
    local def = alertLevel > 0 and Config.Alert.levels[alertLevel]
    return Config.Soldiers.pedsPerRoute + (def and def.extraPeds or 0)
end

local function ApplyReputation(src)
    local rep = Config.Alert.reputation
    if not Guarma.IsRunning('rsg-reputation') then return end
    if rep.standing ~= 0 then exports['rsg-reputation']:AddStanding(src, rep.region, rep.standing, 'guarma soldier killed') end
    if rep.honor ~= 0 then exports['rsg-reputation']:AddHonor(src, rep.honor, 'guarma soldier killed') end
end

-- the player who killed this soldier, or nil
local function FindKiller(ped)
    local killer = GetPedSourceOfDeath(ped)
    if not killer or killer == 0 then return nil end
    for _, id in ipairs(GetPlayers()) do
        if GetPlayerPed(id) == killer then return tonumber(id) end
    end
    return nil
end

local function SetAlertLevel(level)
    if level == alertLevel then return false end
    local raised = level > alertLevel
    alertLevel = level
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 then
            local c = GetEntityCoords(ped)
            if c.x >= 0.0 and c.y <= -4096.0 then
                if level == 0 then
                    Guarma.Notify(tonumber(id), locale('alert_title'), 'inform', locale('alert_calm'))
                else
                    Guarma.Notify(tonumber(id), locale('alert_title'), raised and 'warning' or 'inform', locale('alert_level', level))
                end
            end
        end
    end
    return raised
end

-- centre of each route, so players anywhere along it keep it active
local centres = {}
for index, route in ipairs(Config.Soldiers.routes) do
    local sum = vector3(0.0, 0.0, 0.0)
    for _, node in ipairs(route.nodes) do
        sum = sum + node
    end
    centres[index] = sum / #route.nodes
end

local function PublishNetIds()
    local list = {}
    for _, peds in pairs(routes) do
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
        -- skip players in other routing buckets (instances, character selection)
        if ped ~= 0 and GetPlayerRoutingBucket(id) == 0 then
            list[#list + 1] = GetEntityCoords(ped)
        end
    end
    return list
end

local function AnyNear(players, coords, radius)
    for i = 1, #players do
        if #(players[i] - coords) < radius then
            return true
        end
    end
    return false
end

-- keep a route alive while players are near its centre or near any of its soldiers (chases)
local function RouteInUse(players, index)
    if AnyNear(players, centres[index], Config.Soldiers.despawnDistance) then
        return true
    end
    local peds = routes[index]
    if not peds then return false end
    for i = 1, #peds do
        local ped = peds[i]
        if DoesEntityExist(ped) and AnyNear(players, GetEntityCoords(ped), Config.Soldiers.despawnDistance) then
            return true
        end
    end
    return false
end

-- adds soldiers until the route has `total`
local function FillRoute(index, route, total)
    local cfg = Config.Soldiers
    local peds = routes[index] or {}
    routes[index] = peds

    for i = #peds + 1, total do
        local node = (i - 1) % #route.nodes + 1
        local pos = route.nodes[node]
        -- CREATE_PED (CFX): pedType, model, x, y, z, heading, isNetwork, bScriptHostPed
        local ped = CreatePed(4, cfg.model, pos.x, pos.y, pos.z, 0.0, true, true)
        local timeout = GetGameTimer() + 3000
        while not DoesEntityExist(ped) and GetGameTimer() < timeout do
            Wait(0)
        end

        if DoesEntityExist(ped) then
            SetEntityOrphanMode(ped, 2) -- keep the ped when its owner leaves
            SetEntityDistanceCullingRadius(ped, cfg.despawnDistance)

            local state = Entity(ped).state
            state:set('fussarRoute', index, true)
            state:set('fussarNode', node % #route.nodes + 1, true)
            state:set(
                'fussarWeapon',
                route.sniper and cfg.sniperWeapon or cfg.weapons[math.random(#cfg.weapons)],
                true
            )
            peds[#peds + 1] = ped
        end
    end
end

local function DespawnRoute(index)
    local peds = routes[index]
    if not peds then return end
    for i = 1, #peds do
        local ped = peds[i]
        counted[ped] = nil
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    routes[index] = nil
    wipedAt[index] = nil
end

-- true once every soldier on the route has been dead (or gone) for respawnTime seconds
local function RouteNeedsRespawn(index)
    local delay = tonumber(Config.Soldiers.respawnTime) or 0
    if delay <= 0 then return false end

    local peds = routes[index]
    for i = 1, #peds do
        if DoesEntityExist(peds[i]) and GetEntityHealth(peds[i]) > 0 then
            wipedAt[index] = nil
            return false
        end
    end

    wipedAt[index] = wipedAt[index] or GetGameTimer()
    return GetGameTimer() - wipedAt[index] >= delay * 1000
end

-- counts new deaths, then lets the alert fade
local function UpdateAlert(elapsed)
    if not Config.Alert.enabled then return false end
    heat = math.max(0.0, heat - elapsed / (math.max(0.1, Config.Alert.decayMinutes) * 60000))

    for _, peds in pairs(routes) do
        for i = 1, #peds do
            local ped = peds[i]
            if not counted[ped] and DoesEntityExist(ped) and GetEntityHealth(ped) <= 0 then
                counted[ped] = true
                local killer = FindKiller(ped)
                -- only deaths caused by a player count
                if killer then
                    heat = heat + 1.0
                    ApplyReputation(killer)
                end
            end
        end
    end

    return SetAlertLevel(LevelFor(heat))
end

CreateThread(function()
    GlobalState.guarmaSoldiers = {}
    local lastTick = GetGameTimer()
    while true do
        local changed = false
        local players = GetPlayerCoords()

        local now = GetGameTimer()
        local raised = UpdateAlert(now - lastTick)
        lastTick = now

        for index, route in ipairs(Config.Soldiers.routes) do
            if route.enabled then
                if not routes[index] and AnyNear(players, centres[index], Config.Soldiers.spawnDistance) then
                    FillRoute(index, route, PedsPerRoute())
                    changed = true
                elseif routes[index] and (not RouteInUse(players, index) or RouteNeedsRespawn(index)) then
                    -- dead soldiers included: route respawns on a later pass if someone is near
                    DespawnRoute(index)
                    changed = true
                elseif raised and routes[index] and not wipedAt[index] then
                    -- reinforcements for patrols that are already out
                    FillRoute(index, route, PedsPerRoute())
                    changed = true
                end
            end
        end

        if changed then
            PublishNetIds()
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for index in pairs(routes) do
        DespawnRoute(index)
    end
    GlobalState.guarmaSoldiers = {}
end)
