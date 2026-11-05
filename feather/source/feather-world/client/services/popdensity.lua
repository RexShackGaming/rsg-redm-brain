local multipliers = Config.DensityMultipliers
local started = false

WorldPopulationActive = false
WorldPopulationFrames = 0

local function SetAmbientAnimalDensity(value)
    Citizen.InvokeNative(0xC0258742B034DFAF, value)
end

local function SetAmbientHumanDensity(value)
    Citizen.InvokeNative(0xBA0980B5C0A11924, value)
end

local function SetAmbientPedDensity(value)
    Citizen.InvokeNative(0xAB0D553FE20A6E25, value)
end

local function SetScenarioAnimalDensity(value)
    Citizen.InvokeNative(0xDB48E99F8E064E56, value)
end

local function SetScenarioHumanDensity(value)
    Citizen.InvokeNative(0x28CB6391ACEDD9DB, value)
end

local function ApplyDensityFrame()
    SetAmbientAnimalDensity(multipliers.ambientAnimals)
    SetAmbientHumanDensity(multipliers.ambientHumans)
    SetAmbientPedDensity(multipliers.ambientPeds)
    SetScenarioAnimalDensity(multipliers.scenarioAnimals)
    SetScenarioHumanDensity(multipliers.scenarioHumans)
    SetScenarioPedDensityMultiplierThisFrame(multipliers.scenarioPeds)
    SetParkedVehicleDensityMultiplierThisFrame(multipliers.parkedVehicles)
    SetRandomVehicleDensityMultiplierThisFrame(multipliers.randomVehicles)
    SetVehicleDensityMultiplierThisFrame(multipliers.vehicles)
end

function StartPopulationDensity()
    if started then return end
    started = true
    WorldPopulationActive = true

    CreateThread(function()
        while WorldPopulationActive do
            ApplyDensityFrame()
            WorldPopulationFrames = WorldPopulationFrames + 1
            Wait(0)
        end
    end)
end
