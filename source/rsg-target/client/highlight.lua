-- Highlights nearby entities and zones that have target options while targeting is active.
local RSGCore = exports['rsg-core']:GetCoreObject()
local api = require 'client.api'
local utils = require 'client.utils'

local highlight = {}

local cfg = Config.Highlight
local found = {}      -- { entity = handle, z = height offset } | { coords = vector3, zone = CZone }
local foundN = 0
local lastScan = 0
local GetGameTimer = GetGameTimer

-- per player on/off switch (saved with KVP), the config value is the default
local KVP_KEY = 'rsg-target:highlight'
local enabled = cfg.Enabled
local saved = GetResourceKvpString(KVP_KEY)
if saved == 'on' then enabled = true elseif saved == 'off' then enabled = false end


---@return boolean
local function optionUsable(option, entity, distance, coords)
    if option.menuName then return false end -- only show top-level options
    if not utils.passesFilters(option) then return false end

    if option.canInteract then
        local ok, resp = pcall(option.canInteract, entity, distance, coords, option.name)
        if not ok or not resp then return false end
    end

    return true
end

local function anyUsable(list, entity, distance, coords)
    if not list then return false end
    for i = 1, #list do
        if optionUsable(list[i], entity, distance, coords) then return true end
    end
    return false
end

local function entityHasOptions(entity, entityType, playerCoords)
    local ok, model = pcall(GetEntityModel, entity)
    if not ok then return false end

    local opts = api.getTargetOptions(entity, entityType, model)
    local coords = GetEntityCoords(entity)
    local distance = #(playerCoords - coords)

    if anyUsable(opts.entity, entity, distance, coords)
        or anyUsable(opts.localEntity, entity, distance, coords)
        or anyUsable(opts.model, entity, distance, coords) then
        return true, model
    end

    if cfg.IncludeGlobal and anyUsable(opts.global, entity, distance, coords) then
        return true, model
    end

    return false
end

local function add(entry)
    if foundN >= cfg.MaxDrawn then return false end
    foundN += 1
    found[foundN] = entry
    return true
end

local function scanList(list, key, entityType, playerCoords, ped)
    for i = 1, #list do
        local entity = list[i][key]
        if entity ~= ped then
            local has, model = entityHasOptions(entity, entityType, playerCoords)
            -- option check first: LOS is a raycast, only pay for it when the entity is usable
            if has and (not cfg.RequireLineOfSight or HasEntityClearLosToEntity(ped, entity, 17)) then
                local _, max = GetModelDimensions(model)
                if not add({ entity = entity, z = max.z + cfg.HeightOffset }) then return end
            end
        end
    end
end

function highlight.isEnabled()
    return enabled
end

function highlight.scan()
    if not enabled then return end

    local now = GetGameTimer()
    if now - lastScan < cfg.ScanInterval then return end
    lastScan = now

    table.wipe(found)
    foundN = 0

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)

    if cfg.Peds then scanList(RSGCore.Functions.GetNearbyPeds(playerCoords, cfg.Radius), 'ped', 1, playerCoords, ped) end
    if cfg.Vehicles then scanList(RSGCore.Functions.GetNearbyVehicles(playerCoords, cfg.Radius, true), 'vehicle', 2, playerCoords, ped) end
    if cfg.Objects then scanList(RSGCore.Functions.GetNearbyObjects(playerCoords, cfg.Radius), 'object', 3, playerCoords, ped) end

    -- zones without their own sprite (drawSprite = false) are skipped
    if cfg.Zones and Zones then
        for _, zone in pairs(Zones) do
            local dist = zone.drawSprite ~= false and #(playerCoords - zone.coords)
            if dist and dist <= cfg.Radius and anyUsable(zone.options, nil, dist, zone.coords) then
                if not add({ coords = zone.coords, zone = zone }) then break end
            end
        end
    end
end

local GetScreenCoordFromWorldCoord = GetScreenCoordFromWorldCoord
local floor = math.floor
local markers = {}
local lastN, lastX, lastY, lastA = 0, {}, {}, {}
local style = { size = cfg.Size, pulse = cfg.Pulse, colour = cfg.Colour, hover = cfg.HoverColour }
local sentEmpty = true
local sentStyle = false

local function send(list)
    -- style only needs sending once, the NUI keeps it
    SendNuiMessage(json.encode({ event = 'markers', markers = list, style = not sentStyle and style or nil }))
    sentStyle = true
end

---true when the markers differ from the last batch sent (skips NUI traffic while nothing moved)
local function markersChanged(n)
    if n ~= lastN then return true end

    for i = 1, n do
        local m = markers[i]
        if m.x ~= lastX[i] or m.y ~= lastY[i] or m.a ~= lastA[i] then return true end
    end

    return false
end

---Projects every highlighted target to the screen and sends them to the NUI (eye icons).
---@param hovered number? entity aimed at that currently has usable options
---@param activeZones table? zones aimed at that currently have usable options
function highlight.draw(hovered, activeZones)
    if foundN == 0 then
        if not sentEmpty then send({}); sentEmpty = true; lastN = 0 end
        return
    end

    table.wipe(markers)
    local n = 0

    for i = 1, foundN do
        local e = found[i]
        local x, y, z
        local active = false

        if e.entity then
            active = hovered ~= nil and e.entity == hovered
            if DoesEntityExist(e.entity) then
                local c = GetEntityCoords(e.entity)
                x, y, z = c.x, c.y, c.z + e.z
            end
        else
            x, y, z = e.coords.x, e.coords.y, e.coords.z
            if activeZones then
                for j = 1, #activeZones do
                    if activeZones[j] == e.zone then active = true break end
                end
            end
        end

        if x then
            local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
            if onScreen then
                n += 1
                markers[n] = { x = floor(sx * 10000 + 0.5) / 10000, y = floor(sy * 10000 + 0.5) / 10000, a = active }
            end
        end
    end

    if markersChanged(n) then
        send(markers)

        for i = 1, n do
            local m = markers[i]
            lastX[i], lastY[i], lastA[i] = m.x, m.y, m.a
        end

        lastN = n
    end

    sentEmpty = n == 0 and lastN == 0
end

function highlight.clear()
    if not sentEmpty then send({}); sentEmpty = true end
    lastN = 0
    table.wipe(found)
    foundN = 0
    lastScan = 0
end

---@param value boolean
function highlight.setEnabled(value)
    enabled = value and true or false
    SetResourceKvp(KVP_KEY, enabled and 'on' or 'off')
    if not enabled then highlight.clear() end
end

return highlight
