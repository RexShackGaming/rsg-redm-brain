----------------------------------------------------------------------------
-- Shared herb spawn list
--
-- Client and server both build the exact same list from Config.Zones, in a
-- deterministic order (zones sorted by id, coords in file order), so a
-- spawn is identified on the network by its integer index alone.
--
-- Previously nodes were identified by a "%.1f_%.1f_%.1f" coordinate string
-- built independently on each side. Float formatting is not guaranteed to
-- match between client and server (float32 vs double, OS locale decimal
-- separators, etc.), which produced "unknown spawn key" rejections for
-- perfectly legitimate gathers.
----------------------------------------------------------------------------

function BuildHerbSpawns()
    local zoneIds = {}
    for zoneId in pairs(Config.Zones) do
        zoneIds[#zoneIds + 1] = zoneId
    end
    table.sort(zoneIds, function(a, b) return tostring(a) < tostring(b) end)

    local spawns = {}
    for _, zoneId in ipairs(zoneIds) do
        local zone = Config.Zones[zoneId]
        local plants = zone.plants
        if plants and #plants > 0 and zone.coords then
            for ci, c in ipairs(zone.coords) do
                local id = #spawns + 1
                spawns[id] = {
                    id = id,
                    zone = zoneId,
                    coord = vec3(c.x, c.y, c.z),
                    plant = plants[((ci - 1) % #plants) + 1],
                }
            end
        end
    end
    return spawns
end

function StripComposite(plant)
    return (plant:gsub('COMPOSITE_LOOTABLE_', ''):gsub('_INTERACTABLE', ''))
end
