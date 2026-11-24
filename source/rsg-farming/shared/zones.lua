-- shared zone checks for rsg-farming (client placement preview + server validation use the same rules)
Zones = {}

-- true when coords sit inside a Config.NoPlantZones entry
function Zones.blocked(coords)
    for _, z in ipairs(Config.NoPlantZones or {}) do
        if #(coords - z.coords) <= z.radius then return true end
    end
    return false
end

-- true when planting is allowed here: always, unless Config.RequirePlantZone is on and coords are outside every Config.PlantZones entry
function Zones.farmland(coords)
    if not Config.RequirePlantZone then return true end
    for _, z in ipairs(Config.PlantZones or {}) do
        if #(coords - z.coords) <= z.radius then return true end
    end
    return false
end
