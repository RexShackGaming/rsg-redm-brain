-- Reference: spawn peds/props/blips with tracking and cleanup
local spawned = { peds = {}, objects = {}, blips = {} }

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function spawnPed(model, coords, heading)
    local hash = loadModel(model); if not hash then return end
    local ped = CreatePed(hash, coords.x, coords.y, coords.z, heading or 0.0, false, false, false, false)
    SetRandomOutfitVariation(ped, true) -- RedM: otherwise peds can spawn invisible
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(hash)
    spawned.peds[#spawned.peds + 1] = ped
    return ped
end

local function spawnObject(model, coords)
    local hash = loadModel(model); if not hash then return end
    local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    SetModelAsNoLongerNeeded(hash)
    spawned.objects[#spawned.objects + 1] = obj
    return obj
end

local function addBlip(coords, sprite, name)
    local blip = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z) -- 1664425300 = default coords blip style
    SetBlipSprite(blip, sprite, true)
    SetBlipName(blip, name)
    spawned.blips[#spawned.blips + 1] = blip
    return blip
end

AddEventHandler('onResourceStop', function(r)
    if r ~= GetCurrentResourceName() then return end
    for _, p in ipairs(spawned.peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    for _, o in ipairs(spawned.objects) do if DoesEntityExist(o) then DeleteEntity(o) end end
    for _, b in ipairs(spawned.blips) do RemoveBlip(b) end
end)

return { spawnPed = spawnPed, spawnObject = spawnObject, addBlip = addBlip }
