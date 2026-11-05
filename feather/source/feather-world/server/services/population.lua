local densityKeys = {
    'ambientPeds',
    'scenarioPeds',
    'vehicles',
    'parkedVehicles',
    'randomVehicles',
    'ambientAnimals',
    'ambientHumans',
    'scenarioAnimals',
    'scenarioHumans'
}

WorldPopulation = {}

local function Copy(input)
    local output = {}
    for key, value in pairs(input) do output[key] = value end
    return output
end

function WorldPopulation.ValidateDensityMultipliers(input)
    if type(input) ~= 'table' then
        return { ok = false, error = { code = 'invalid_density', message = 'DensityMultipliers must be a table.' } }
    end

    for _, key in ipairs(densityKeys) do
        local value = tonumber(input[key])
        if not value or value ~= value or value < 0 then
            return {
                ok = false,
                error = { code = 'invalid_density', message = ('Density multiplier %s must be zero or greater.'):format(key) }
            }
        end
    end

    return { ok = true }
end

function WorldPopulation.GetDensityMultipliers()
    return { ok = true, value = Copy(Config.DensityMultipliers) }
end

exports('GetDensityMultipliers', WorldPopulation.GetDensityMultipliers)
