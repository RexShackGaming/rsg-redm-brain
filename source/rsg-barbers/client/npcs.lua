local RSGCore = exports['rsg-core']:GetCoreObject()
local spawnedPeds = {}
local blips = {}

local function loadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model, false)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function fade(ped, from, to, step)
    for i = from, to, step do
        if not DoesEntityExist(ped) then return end
        SetEntityAlpha(ped, i, false)
        Wait(50)
    end
end

local function spawnBarber(loc)
    if not loadModel(loc.npcmodel) then return nil end
    local c = loc.npccoords
    local ped = CreatePed(loc.npcmodel, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    SetModelAsNoLongerNeeded(loc.npcmodel)
    SetEntityAlpha(ped, Config.FadeIn and 0 or 255, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)

    if Config.UseTarget then
        exports['rsg-target']:addLocalEntity(ped, {
            {
                name = 'rsg_barbers_open',
                icon = 'fa-solid fa-scissors',
                label = locale('target_open'),
                distance = 2.0,
                onSelect = function() TriggerEvent('rsg-barbers:client:open', loc.barberid) end,
            },
        })
    end
    if Config.FadeIn then CreateThread(function() fade(ped, 0, 255, 51) end) end
    return ped
end

local function despawnBarber(ped, instant)
    if not ped then return end
    if Config.UseTarget then exports['rsg-target']:removeLocalEntity(ped) end
    if Config.FadeIn and not instant then fade(ped, 255, 0, -51) end
    if DoesEntityExist(ped) then DeletePed(ped) end
end

CreateThread(function()
    for _, loc in ipairs(Config.BarberLocations) do
        if not Config.UseTarget then
            exports['rsg-core']:createPrompt(loc.barberid, loc.coords, RSGCore.Shared.Keybinds[Config.Key], locale('target_open'), {
                type = 'client', event = 'rsg-barbers:client:open', args = { loc.barberid },
            })
        end
        if loc.showblip then
            local blip = BlipAddForCoords(1664425300, loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip, Config.BlipSprite, true)
            SetBlipScale(blip, Config.BlipScale)
            SetBlipName(blip, locale('blip_name', loc.name))
            blips[#blips + 1] = blip
        end
    end

    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, loc in ipairs(Config.BarberLocations) do
            local near = #(pos - loc.npccoords.xyz) < Config.DistanceSpawn
            if near and not spawnedPeds[i] then
                spawnedPeds[i] = spawnBarber(loc)
            elseif not near and spawnedPeds[i] then
                local ped = spawnedPeds[i]
                spawnedPeds[i] = nil
                CreateThread(function() despawnBarber(ped) end)
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for i, ped in pairs(spawnedPeds) do despawnBarber(ped, true); spawnedPeds[i] = nil end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    if not Config.UseTarget then
        for _, loc in ipairs(Config.BarberLocations) do exports['rsg-core']:deletePrompt(loc.barberid) end
    end
end)
