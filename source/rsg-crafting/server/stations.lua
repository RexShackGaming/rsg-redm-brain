---------------------------------------------
-- crafting stations: fixed ones from Config.Stations.Static and admin-placed ones saved in the database
---------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
CraftingServer = CraftingServer or {}

local placed = {} -- [id] = { id, type, coords = vector3, rotation = vector3 }

local function isFiniteNumber(n)
    return type(n) == 'number' and n == n and n > -math.huge and n < math.huge
end

local function isFiniteVector(v)
    return type(v) == 'vector3' and isFiniteNumber(v.x) and isFiniteNumber(v.y) and isFiniteNumber(v.z)
end

local function notify(src, description, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'), description = description, type = ntype or 'inform', duration = 5000,
    })
end

function CraftingServer.StationLabel(stationType)
    local def = Config.Stations.Types[stationType]
    return def and locale(def.label) or tostring(stationType)
end

-- true when the player stands within the station type's radius (+ extra) of any station of that type
function CraftingServer.IsNearStation(src, stationType, extra)
    local cfg = Config.Stations
    if not cfg or not cfg.Enabled then return true end -- stations switched off: station recipes are not restricted
    local def = cfg.Types[stationType]
    if not def then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local radius = (def.radius or 3.0) + (extra or 0.0)
    for _, s in ipairs(cfg.Static) do
        if s.type == stationType and #(pos - s.coords) <= radius then return true end
    end
    for _, s in pairs(placed) do
        if s.type == stationType and #(pos - s.coords) <= radius then return true end
    end
    return false
end

-- everything the clients need to build their targets / props
local function stationList()
    local list = {}
    for i, s in ipairs(Config.Stations.Static) do
        local h = s.heading or 0.0
        list[#list + 1] = { id = 's' .. i, type = s.type, coords = s.coords, rotation = vector3(0.0, 0.0, h) }
    end
    for id, s in pairs(placed) do
        list[#list + 1] = { id = tostring(id), type = s.type, coords = s.coords, rotation = s.rotation }
    end
    return list
end

RSGCore.Functions.CreateCallback('rsg-crafting:server:getStations', function(_, cb)
    cb(Config.Stations.Enabled and stationList() or {})
end)

CraftingServer.OnReady(function()
    local rows = MySQL.query.await('SELECT id, type, x, y, z, rx, ry, rz FROM rsg_crafting_stations') or {}
    for _, r in ipairs(rows) do
        if Config.Stations.Types[r.type] then
            placed[r.id] = { id = r.id, type = r.type, coords = vector3(r.x, r.y, r.z), rotation = vector3(r.rx, r.ry, r.rz) }
        end
    end
    TriggerClientEvent('rsg-crafting:client:setStations', -1, stationList())
end)

local function placedCount()
    local n = 0
    for _ in pairs(placed) do n = n + 1 end
    return n
end

RegisterNetEvent('rsg-crafting:server:createStation', function(stationType, coords, rotation)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not RSGCore.Functions.HasPermission(src, 'admin') then return end
    if not Config.Stations.Enabled or type(stationType) ~= 'string' or not Config.Stations.Types[stationType] then return end
    if not isFiniteVector(coords) then return end
    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, 10.0) then return end
    if placedCount() >= (Config.Stations.MaxPlaced or 100) then return end
    rotation = isFiniteVector(rotation) and exports['rsg-gizmo']:SanitiseRotation(rotation) or vector3(0.0, 0.0, 0.0)

    local id = MySQL.insert.await('INSERT INTO rsg_crafting_stations (type, x, y, z, rx, ry, rz) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { stationType, coords.x, coords.y, coords.z, rotation.x, rotation.y, rotation.z })
    if not id then return end

    placed[id] = { id = id, type = stationType, coords = coords, rotation = rotation }
    TriggerClientEvent('rsg-crafting:client:addStation', -1, { id = tostring(id), type = stationType, coords = coords, rotation = rotation })
    notify(src, locale('station_placed'), 'success')
end)

-- removes the closest admin-placed station within 3m of the admin; returns whether one was removed
function CraftingServer.RemoveNearestStation(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local bestId, bestDist = nil, 3.0
    for id, s in pairs(placed) do
        local d = #(pos - s.coords)
        if d <= bestDist then bestId, bestDist = id, d end
    end
    if not bestId then return false end
    MySQL.query.await('DELETE FROM rsg_crafting_stations WHERE id = ?', { bestId })
    placed[bestId] = nil
    TriggerClientEvent('rsg-crafting:client:removeStation', -1, tostring(bestId))
    return true
end

exports('IsNearStation', function(src, stationType)
    return CraftingServer.IsNearStation(src, stationType)
end)
