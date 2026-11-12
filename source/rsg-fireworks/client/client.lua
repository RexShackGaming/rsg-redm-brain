local RSGCore = exports['rsg-core']:GetCoreObject()

-- All firework-specific values live here so the big/small logic is not duplicated.
local FireworkTypes = {
    big = {
        item = 'firework_big',
        model = 's_firework01x',
        asset = 'scr_ind1',
        particle = 'scr_ind1_firework',
        particleScale = 1.0,
        explosionType = 25,
        zOffset = 60.0,
        duration = Config.BigFireworkTime,
    },
    small = {
        item = 'firework_small',
        model = 's_firework01x',
        asset = 'anm_ind',
        particle = 'ent_anim_ind_firework',
        particleScale = 0.20,
        explosionType = 12,
        zOffset = 10.0,
        duration = Config.SmallFireworkTime,
    },
}

local activeParticles = {}
local activeObjects = {}

local function loadPtfxAsset(asset)
    local hash = joaat(asset)
    if not HasNamedPtfxAssetLoaded(hash) then
        RequestNamedPtfxAsset(hash)
        local timeout = GetGameTimer() + 5000
        while not HasNamedPtfxAssetLoaded(hash) and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    if not HasNamedPtfxAssetLoaded(hash) then
        return false
    end

    UseParticleFxAsset(asset)
    return true
end

local function stopParticle(handle)
    if not handle or handle == 0 then
        return
    end

    StopParticleFxLooped(handle, true)

    for i = #activeParticles, 1, -1 do
        if activeParticles[i] == handle then
            table.remove(activeParticles, i)
            break
        end
    end
end

local function deleteObject(object)
    if not object then
        return
    end

    if DoesEntityExist(object) then
        DeleteObject(object)
    end

    for i = #activeObjects, 1, -1 do
        if activeObjects[i] == object then
            table.remove(activeObjects, i)
            break
        end
    end
end

local function startExplosionLoop(coords, firework)
    local stop = false
    SetTimeout(firework.duration * 1000, function()
        stop = true
    end)

    repeat
        AddExplosionWithUserVfx(coords.x, coords.y, coords.z, 32, 0x2FDA2B4A, 0.0, Config.EnableSound, false, 0.0)
        Wait(100)
        AddExplosionWithUserVfx(coords.x, coords.y, coords.z + firework.zOffset, firework.explosionType, 0x2FDA2B4A, 0.0, Config.EnableSound, true, 0.0)
        Wait(math.random(100, 800))
    until stop

    Wait(500)
    AddExplosionWithUserVfx(coords.x, coords.y, coords.z, 32, 0x2FDA2B4A, 0.0, Config.EnableSound, false, 0.0)
    Wait(100)
    AddExplosionWithUserVfx(coords.x, coords.y, coords.z + firework.zOffset, firework.explosionType, 0x2FDA2B4A, 0.0, Config.EnableSound, true, 0.0)
end

local function playParticleFirework(coords, firework, withExplosions)
    if not loadPtfxAsset(firework.asset) then
        return
    end

    local handle = StartParticleFxLoopedAtCoord(
        firework.particle,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        firework.particleScale,
        false, false, false, true
    )

    if handle and handle ~= 0 then
        activeParticles[#activeParticles + 1] = handle
    end

    if withExplosions then
        startExplosionLoop(coords, firework)
        stopParticle(handle)
    else
        Wait(firework.duration * 1000)
        stopParticle(handle)
    end
end

local function getFireworkByItem(item)
    for _, firework in pairs(FireworkTypes) do
        if firework.item == item then
            return firework
        end
    end
end

local function notify(titleKey, descriptionKey, notifyType)
    RSGCore.Functions.Notify({
        title = locale(titleKey),
        description = locale(descriptionKey),
        type = notifyType or 'inform',
        duration = 5000,
    })
end

local function placeFirework(firework)
    if exports['rsg-gizmo']:IsActive() then
        TriggerServerEvent('rsg-fireworks:server:cancel', firework.item)
        return
    end

    local result = exports['rsg-gizmo']:Place(firework.model, {
        title = locale('place_firework'),
        maxDistance = Config.PlacementDistance or 6.0,
        rotation = 'z',
        snapToGround = true,
        allowInterior = Config.AllowInteriorPlacement == true,
    })

    if not result then
        TriggerServerEvent('rsg-fireworks:server:cancel', firework.item)
        notify('firework_in_progress_title', 'placement_cancelled', 'inform')
        return
    end

    TriggerServerEvent('rsg-fireworks:server:place', firework.item, result.coords, result.rotation)
end

local function igniteFirework(firework, coords, rotation)
    local model = joaat(firework.model)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end

    if not HasModelLoaded(model) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    local object = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(model)

    if not object or object == 0 then
        return
    end

    activeObjects[#activeObjects + 1] = object

    if rotation then
        SetEntityRotation(object, rotation.x, rotation.y, rotation.z, 2, true)
    end

    Wait(Config.FuseTime or 5000)

    local igniteCoords = GetEntityCoords(object)
    startExplosionLoop(igniteCoords, firework)

    Wait(10000)
    deleteObject(object)
end

---------------------------------------
-- player-triggered fireworks
---------------------------------------
RegisterNetEvent('rsg-fireworks:client:firework_big', function()
    CreateThread(function()
        placeFirework(FireworkTypes.big)
    end)
end)

RegisterNetEvent('rsg-fireworks:client:firework_small', function()
    CreateThread(function()
        placeFirework(FireworkTypes.small)
    end)
end)

RegisterNetEvent('rsg-fireworks:client:ignite', function(item, coords, rotation)
    local firework = getFireworkByItem(item)
    if not firework or type(coords) ~= 'vector3' then
        return
    end

    if type(rotation) ~= 'vector3' then
        rotation = nil
    end

    CreateThread(function()
        igniteFirework(firework, coords, rotation)
    end)
end)

---------------------------------------
-- networked particle-only effects (seen by all players)
---------------------------------------
RegisterNetEvent('rsg-fireworks:client:big_fireworks_players', function(coords)
    if type(coords) ~= 'vector3' then return end
    playParticleFirework(coords, FireworkTypes.big, false)
end)

RegisterNetEvent('rsg-fireworks:client:small_fireworks_players', function(coords)
    if type(coords) ~= 'vector3' then return end
    playParticleFirework(coords, FireworkTypes.small, false)
end)

---------------------------------------
-- firework displays
---------------------------------------
local function getDisplay(displayName)
    for _, display in ipairs(Config.Displays) do
        if display.name == displayName then
            return display
        end
    end
end

RegisterNetEvent('rsg-fireworks:client:display', function(displayName)
    local display = getDisplay(displayName)
    if not display then
        print(locale('display_not_found') .. tostring(displayName))
        return
    end

    for _, entry in ipairs(display.fireworks) do
        if FireworkTypes[entry.type] then
            SetTimeout(entry.delay or 0, function()
                local eventName = entry.type == 'big'
                    and 'rsg-fireworks:client:display_big_firework'
                    or 'rsg-fireworks:client:display_small_firework'
                TriggerEvent(eventName, entry.coords)
            end)
        end
    end
end)

RegisterNetEvent('rsg-fireworks:client:display_big_firework', function(coords)
    if type(coords) ~= 'vector3' then return end
    playParticleFirework(coords, FireworkTypes.big, true)
end)

RegisterNetEvent('rsg-fireworks:client:display_small_firework', function(coords)
    if type(coords) ~= 'vector3' then return end
    playParticleFirework(coords, FireworkTypes.small, true)
end)

---------------------------------------
-- one command per configured display (permission checked server side)
---------------------------------------
local registeredCommands = {}
for _, display in ipairs(Config.Displays) do
    local command = display.command
    if type(command) == 'string' and command ~= '' and type(display.name) == 'string' and not registeredCommands[command] then
        registeredCommands[command] = true
        RegisterCommand(command, function()
            TriggerServerEvent('rsg-fireworks:server:display', display.name)
        end, false)
    end
end

---------------------------------------
-- cleanup
---------------------------------------
local function cleanupFireworks()
    for i = #activeParticles, 1, -1 do
        local handle = activeParticles[i]
        if handle then
            StopParticleFxLooped(handle, false)
        end
    end
    activeParticles = {}

    for i = #activeObjects, 1, -1 do
        local object = activeObjects[i]
        if DoesEntityExist(object) then
            DeleteObject(object)
        end
    end
    activeObjects = {}
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        cleanupFireworks()
    end
end)
