local function findStation(stationId)
    for _, station in ipairs((Config.Crafting and Config.Crafting.stations) or {}) do
        if station.id == stationId then return station end
    end
    return nil
end

RegisterNetEvent('rsg-gangs:client:openCraftMenu', function(stationId)
    if not Config.Crafting or not Config.Crafting.enabled then return end
    local station = findStation(stationId)
    if not station then return end

    RSGGangsClient.OpenFocusOnly()
    SendNUIMessage({
        action = 'openCraft',
        data = {
            stationId = station.id,
            label = station.label,
            intro = station.intro,
            recipes = station.recipes,
        },
    })
end)
