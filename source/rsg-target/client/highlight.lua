-- Highlights nearby entities and zones that have target options while targeting is active.
local api = require 'client.api'
local utils = require 'client.utils'

local highlight = {}

local cfg = Config.Highlight
local found = {}      -- { entity = handle, z = height offset } | { coords = vector3, zone = CZone }
local foundN = 0
local lastScan = 0
local GetGameTimer = GetGameTimer


---@return boolean
local function optionUsable(option, entity, distance, coords)
    if option.menuName then return false end -- only show top-level options
    if option.groups and not utils.hasPlayerGotGroup(option.groups) then return false end
    if option.items and not utils.hasPlayerGotItems(option.items, option.anyItem) then return false end

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

local function scanList(list, key, entityType, playerCoords)
    for i = 1, #list do
        local entity = list[i][key]
        if entity ~= cache.ped and (not cfg.RequireLineOfSight or HasEntityClearLosToEntity(cache.ped, entity, 17)) then
            local has, model = entityHasOptions(entity, entityType, playerCoords)
            if has then
                local _, max = GetModelDimensions(model)
                if not add({ entity = entity, z = max.z + cfg.HeightOffset }) then return end
            end
        end
    end
end

function highlight.scan()
    if not cfg.Enabled then return end

    local now = GetGameTimer()
    if now - lastScan < cfg.ScanInterval then return end
    lastScan = now

    table.wipe(found)
    foundN = 0

    local playerCoords = GetEntityCoords(cache.ped)

    if cfg.Peds then scanList(lib.getNearbyPeds(playerCoords, cfg.Radius), 'ped', 1, playerCoords) end
    if cfg.Vehicles then scanList(lib.getNearbyVehicles(playerCoords, cfg.Radius, true), 'vehicle', 2, playerCoords) end
    if cfg.Objects then scanList(lib.getNearbyObjects(playerCoords, cfg.Radius), 'object', 3, playerCoords) end

    -- zones without their own sprite (drawSprite = false) are skipped
    if cfg.Zones and Zones then
        for _, zone in pairs(Zones) do
            if zone.drawSprite ~= false and #(playerCoords - zone.coords) <= cfg.Radius
                and anyUsable(zone.options, nil, #(playerCoords - zone.coords), zone.coords) then
                if not add({ coords = zone.coords, zone = zone }) then break end
            end
        end
    end
end

local GetScreenCoordFromWorldCoord = GetScreenCoordFromWorldCoord
local markers = {}
local style = { size = cfg.Size, pulse = cfg.Pulse, colour = cfg.Colour, hover = cfg.HoverColour }
local sentEmpty = true

local function send(list)
    SendNuiMessage(json.encode({ event = 'markers', markers = list, style = style }))
end

---Projects every highlighted target to the screen and sends them to the NUI (eye icons).
---@param hovered number? entity aimed at that currently has usable options
---@param activeZones table? zones aimed at that currently have usable options
function highlight.draw(hovered, activeZones)
    if foundN == 0 then
        if not sentEmpty then send({}); sentEmpty = true end
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
                markers[n] = { x = sx, y = sy, a = active }
            end
        end
    end

    send(markers)
    sentEmpty = n == 0
end

function highlight.clear()
    if not sentEmpty then send({}); sentEmpty = true end
    table.wipe(found)
    foundN = 0
    lastScan = 0
end

return highlight
