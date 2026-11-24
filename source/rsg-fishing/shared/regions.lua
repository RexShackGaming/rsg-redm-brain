-- Lookup sets built once from Config.Regions (shared by client and server)
RegionSets = { pools = {}, valid = {}, legendary = {}, legendaryByZone = {} }

for zone, region in pairs(Config.Regions.StateZones) do RegionSets.valid[region] = true end

for region, list in pairs(Config.Regions.Pools) do
    local set = {}
    for i = 1, #list do set[list[i]] = true end
    RegionSets.pools[region] = set
end

for i = 1, #Config.Regions.LegendarySpots do
    local spot = Config.Regions.LegendarySpots[i]
    RegionSets.legendary[spot.zone] = spot
end

-- species families that only bite at a legendary spot
RegionSets.legendaryFamily = { salmonsockeye_legendary = true }
