local function exportHandler(exportName, func)
    exports(exportName, func)
end

---Merges a legacy job / gang / citizenid filter into a { name = minGrade } map
---@param groups table<string, number>
---@param value string | string[] | table<string, number> | nil
local function mergeGroups(groups, value)
    local t = type(value)

    if t == 'string' then
        groups[value] = groups[value] or 0
    elseif t == 'table' then
        for k, v in pairs(value) do
            if type(k) == 'number' then
                groups[v] = groups[v] or 0          -- array entry: any grade
            else
                groups[k] = tonumber(v) or 0        -- hash entry: minimum grade
            end
        end
    end
end

---Converts qb/legacy target options to the ox_target / rsg-target format
---@param data table
---@return table
local function convert(data)
    local distance = data and data.distance
    local input = data and data.options or {}
    local options = {}

    -- options may be passed as an array, a hashmap, or mixed
    for _, v in pairs(input) do
        if type(v) == 'table' then options[#options + 1] = v end
    end

    for i = 1, #options do
        local v = options[i]
        local groups = {}

        mergeGroups(groups, v.job)
        mergeGroups(groups, v.gang)
        mergeGroups(groups, v.citizenid)

        v.onSelect = v.action
        v.distance = v.distance or distance
        v.name = v.name or v.label
        v.items = v.item
        v.groups = next(groups) and groups or nil

        if v.event and v.type and v.type ~= 'client' then
            if v.type == 'server' then
                v.serverEvent = v.event
            elseif v.type == 'command' then
                v.command = v.event
            end

            v.event = nil
        end

        v.type = nil
        v.action = nil
        v.job = nil
        v.gang = nil
        v.citizenid = nil
        v.item = nil
        v.qtarget = true
    end

    return options
end

local api = require 'client.api'
local utils = require 'client.utils'

exportHandler('AddBoxZone', function(name, center, length, width, options, targetoptions)
    options = options or {}
    options.minZ = options.minZ or -100
    options.maxZ = options.maxZ or 800

    -- legacy minZ/maxZ are world heights: centre the box between them
    if not options.useZ then
        center = vec3(center.x, center.y, (options.minZ + options.maxZ) / 2)
    end

    return api.addBoxZone({
        name = name,
        coords = center,
        size = vec3(width, length, math.abs(options.maxZ - options.minZ)),
        debug = options.debugPoly,
        rotation = options.heading,
        options = convert(targetoptions),
    })
end)

exportHandler('AddPolyZone', function(name, points, options, targetoptions)
    options = options or {}
    options.minZ = options.minZ or -100
    options.maxZ = options.maxZ or 800
    local newPoints = table.create(#points, 0)
    local thickness = math.abs(options.maxZ - options.minZ)

    for i = 1, #points do
        local point = points[i]
        newPoints[i] = vec3(point.x, point.y, options.maxZ - (thickness / 2))
    end

    return api.addPolyZone({
        name = name,
        points = newPoints,
        thickness = thickness,
        debug = options.debugPoly,
        options = convert(targetoptions),
    })
end)

exportHandler('AddCircleZone', function(name, center, radius, options, targetoptions)
    options = options or {}
    return api.addSphereZone({
        name = name,
        coords = center,
        radius = radius,
        debug = options.debugPoly,
        options = convert(targetoptions),
    })
end)

exportHandler('RemoveZone', function(id)
    api.removeZone(id, true)
end)

exportHandler('AddTargetBone', function(_, options)
    -- bone targeting is not supported: options are added to all vehicles instead
    utils.warn('AddTargetBone: bones are not supported by rsg-target, options were added as global vehicle options.')
    api.addGlobalVehicle(convert(options))
end)

exportHandler('AddTargetEntity', function(entities, options)
    if type(entities) ~= 'table' then entities = { entities } end
    options = convert(options)

    for i = 1, #entities do
        local entity = entities[i]

        if NetworkGetEntityIsNetworked(entity) then
            api.addEntity(NetworkGetNetworkIdFromEntity(entity), options)
        else
            api.addLocalEntity(entity, options)
        end
    end
end)

exportHandler('RemoveTargetEntity', function(entities, labels)
    if type(entities) ~= 'table' then entities = { entities } end

    for i = 1, #entities do
        local entity = entities[i]

        if NetworkGetEntityIsNetworked(entity) then
            api.removeEntity(NetworkGetNetworkIdFromEntity(entity), labels)
        else
            api.removeLocalEntity(entity, labels)
        end
    end
end)

exportHandler('AddTargetModel', function(models, options)
    api.addModel(models, convert(options))
end)

exportHandler('RemoveTargetModel', function(models, labels)
    api.removeModel(models, labels)
end)

exportHandler('AddGlobalPed', function(options)
    api.addGlobalPed(convert(options))
end)

exportHandler('RemoveGlobalPed', function(labels)
    api.removeGlobalPed(labels)
end)

exportHandler('AddGlobalVehicle', function(options)
    api.addGlobalVehicle(convert(options))
end)

exportHandler('RemoveGlobalVehicle', function(labels)
    api.removeGlobalVehicle(labels)
end)

exportHandler('AddGlobalObject', function(options)
    api.addGlobalObject(convert(options))
end)

exportHandler('RemoveGlobalObject', function(labels)
    api.removeGlobalObject(labels)
end)

exportHandler('AddGlobalPlayer', function(options)
    api.addGlobalPlayer(convert(options))
end)

exportHandler('RemoveGlobalPlayer', function(labels)
    api.removeGlobalPlayer(labels)
end)

exportHandler('AddEntityZone', function()
    utils.warn('AddEntityZone is not supported by rsg-target - try using addEntity/addLocalEntity.')
end)

exportHandler('RemoveTargetBone', function()
    utils.warn('RemoveTargetBone is not supported by rsg-target.')
end)