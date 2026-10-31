AddEventHandler('rsg-target:client:debug', function(data)
    if data.entity and GetEntityType(data.entity) > 0 then
        data.archetype = GetEntityArchetypeName(data.entity)
        data.model = GetEntityModel(data.entity)
    end

	print(json.encode(data, {indent=true}))
end)

if not Config.Debug then return end

local target = exports['rsg-target']
local drawZones = true

target:addBoxZone({
    coords = vec3(442.5363, -1017.666, 28.85637),
    size = vec3(3, 3, 3),
    rotation = 45,
    debug = drawZones,
    drawSprite = true,
    options = {
        {
            name = 'box',
            event = 'rsg-target:client:debug',
            icon = 'fa-solid fa-cube',
            label = locale('debug_box'),
        }
    }
})

target:addSphereZone({
    coords = vec3(440.5363, -1015.666, 28.85637),
    radius = 3,
    debug = drawZones,
    drawSprite = true,
    options = {
        {
            name = 'sphere',
            event = 'rsg-target:client:debug',
            icon = 'fa-solid fa-circle',
            label = locale('debug_sphere'),
        }
    }
})

target:addGlobalPed({
    {
        name = 'ped',
        event = 'rsg-target:client:debug',
        icon = 'fa-solid fa-male',
        label = locale('debug_ped'),
    }
})

target:addGlobalVehicle({
    {
        name = 'vehicle',
        event = 'rsg-target:client:debug',
        icon = 'fa-solid fa-horse',
        label = locale('debug_vehicle'),
    }
})

target:addGlobalObject({
    {
        name = 'object',
        event = 'rsg-target:client:debug',
        icon = 'fa-solid fa-cube',
        label = locale('debug_object'),
    }
})