local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local DOOR_LOCKED, DOOR_UNLOCKED = 3, 0
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local lockPrompt
local nearestDoor
local busy = false

Doors = {} -- shared with client/editor.lua

---------------------------------------------
-- door system helpers
---------------------------------------------
local function setDoorHash(hash, locked)
    if not IsDoorRegisteredWithSystem(hash) then
        Citizen.InvokeNative(0xD99229FE93B46286, hash, 1, 1, 0, 0, 0, 0) -- AddDoorToSystemNew
    end
    local wanted = locked and DOOR_LOCKED or DOOR_UNLOCKED
    if DoorSystemGetDoorState(hash) ~= wanted then
        DoorSystemSetDoorState(hash, wanted)
        if locked then DoorSystemSetOpenRatio(hash, 0.0, true) end
    end
end

-- custom / MLO door: find the object and freeze it shut
-- (tracks frozen state itself; IsEntityPositionFrozen is not a RedM native)
local customState = {} -- [entity] = true when we froze it

local function headingDiff(a, b)
    local d = math.abs((a - b) % 360.0)
    return d > 180.0 and 360.0 - d or d
end

local function dbg(...)
    if Config.Debug then print(('[rsg-doorlock] ' .. string.format(...))) end
end

-- find the MLO door object: native lookup first, then scan the object pool
local entCache = {} -- [doorHash] = entity
local function findCustomDoor(d)
    local cached = entCache[d.hash]
    if cached and DoesEntityExist(cached) then return cached end
    entCache[d.hash] = nil
    local c = d.coords
    local ent = GetClosestObjectOfType(c.x, c.y, c.z, 1.5, d.object, false, false, false)
    if ent and ent ~= 0 then entCache[d.hash] = ent return ent end
    local best, bestDist
    for _, obj in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(obj) == d.object then
            local dist = #(GetEntityCoords(obj) - c)
            if dist < 3.0 and (not bestDist or dist < bestDist) then best, bestDist = obj, dist end
        end
    end
    entCache[d.hash] = best
    return best
end

local warned = {}
local function setCustomDoor(d, locked)
    local ent = findCustomDoor(d)
    if not ent then
        if not warned[d.hash] then dbg('MLO door %s (model %s) not found near %.2f %.2f %.2f', d.hash, d.object, d.coords.x, d.coords.y, d.coords.z) warned[d.hash] = true end
        return
    end
    if locked then
        local closed = d.heading and headingDiff(GetEntityHeading(ent), d.heading) <= 1.0
        if not closed and d.heading then
            dbg('closing MLO door %s: heading %.1f -> %.1f', d.hash, GetEntityHeading(ent), d.heading)
            FreezeEntityPosition(ent, false)
            local r = GetEntityRotation(ent, 2)
            SetEntityRotation(ent, r.x, r.y, d.heading, 2, true)
            SetEntityHeading(ent, d.heading)
            customState[ent] = nil
        end
        if not customState[ent] then
            FreezeEntityPosition(ent, true)
            customState[ent] = true
            dbg('locked MLO door %s (entity %s)', d.hash, ent)
        end
    elseif customState[ent] ~= false then
        FreezeEntityPosition(ent, false)
        ActivatePhysics(ent)
        customState[ent] = false
        dbg('unlocked MLO door %s (entity %s)', d.hash, ent)
    end
end

local function applyDoor(door, forceUnlock)
    for i = 1, #door.doors do
        local d = door.doors[i]
        local locked = not forceUnlock and door.locked
        if d.object then setCustomDoor(d, locked) else setDoorHash(d.hash, locked) end
    end
end

---------------------------------------------
-- prompt
---------------------------------------------
local function createPrompt()
    lockPrompt = PromptRegisterBegin()
    PromptSetControlAction(lockPrompt, RSGCore.Shared.Keybinds['ENTER'])
    PromptSetText(lockPrompt, CreateVarString(10, 'LITERAL_STRING', locale('cl_use_door')))
    PromptSetEnabled(lockPrompt, true)
    PromptSetVisible(lockPrompt, true)
    PromptSetHoldMode(lockPrompt, true)
    PromptSetGroup(lockPrompt, promptGroup)
    PromptRegisterEnd(lockPrompt)
end

local function canUseDoors()
    local ped = cache.ped
    return not (IsEntityDead(ped)
        or IsPedCuffed(ped)
        or Citizen.InvokeNative(0x3AA24CCC0D451379, ped) -- IsPedHogtied
        or Citizen.InvokeNative(0x9682F850056C9ADE, ped)) -- IsPedLassoed
end

---------------------------------------------
-- init
---------------------------------------------
CreateThread(function()
    for _, hash in ipairs(Config.JailDoors) do
        Citizen.InvokeNative(0xD99229FE93B46286, hash, 1, 1, 0, 0, 0, 0)
        DoorSystemSetDoorState(hash, 1)
    end
    Doors = lib.callback.await('rsg-doorlock:server:getDoors', false) or {}
    createPrompt()
end)

-- slow loop: find nearest door, keep nearby doors in the right state
CreateThread(function()
    while true do
        local coords = GetEntityCoords(cache.ped)
        local closest, closestDist
        for id, door in pairs(Doors) do
            local dist = #(coords - door.textCoords)
            if dist < Config.SyncDistance then
                applyDoor(door)
                if dist < door.distance and (not closestDist or dist < closestDist) then
                    closest, closestDist = id, dist
                end
            end
        end
        nearestDoor = closest
        for ent in pairs(customState) do
            if not DoesEntityExist(ent) then customState[ent] = nil end
        end
        Wait(500)
    end
end)

-- fast loop: only runs while next to a door
CreateThread(function()
    while true do
        local door = nearestDoor and Doors[nearestDoor]
        if door and lockPrompt and not busy and not LocalPlayer.state.doorEditor and canUseDoors() then
            local status = door.locked and locale('cl_door_status_lock') or locale('cl_door_status_unlock')
            PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', locale('cl_door_status_base', status)))
            if PromptHasHoldModeCompleted(lockPrompt) then
                busy = true
                TriggerServerEvent('rsg-doorlock:server:requestToggle', nearestDoor)
                -- wait for the key to be released so one long hold can't toggle twice
                CreateThread(function()
                    Wait(1500)
                    while PromptHasHoldModeCompleted(lockPrompt) do Wait(50) end
                    busy = false
                end)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

---------------------------------------------
-- events
---------------------------------------------
RegisterNetEvent('rsg-doorlock:client:playKeyAnim', function(doorID)
    local door = Doors[doorID]
    if not door then return end
    busy = true

    local ped = cache.ped
    local dict = 'script_common@jail_cell@unlock@key'
    local pedCoords = GetEntityCoords(ped)
    SetPedDesiredHeading(ped, GetHeadingFromVector_2d(door.textCoords.x - pedCoords.x, door.textCoords.y - pedCoords.y))

    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, 'action', 8.0, -8.0, 2500, 31, 0, true, 0, false, 0, false)
    RemoveAnimDict(dict)

    local model = `P_KEY02X`
    lib.requestModel(model)
    Wait(750)
    local prop = CreateObject(model, pedCoords.x, pedCoords.y, pedCoords.z + 0.2, false, false, false)
    SetModelAsNoLongerNeeded(model)
    AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Finger12'), 0.02, 0.012, -0.0085, 0.024, -160.0, 200.0, true, true, false, true, 1, true)
    Wait(1750)
    ClearPedSecondaryTask(ped)
    DeleteObject(prop)
    busy = false
end)

RegisterNetEvent('rsg-doorlock:client:setState', function(doorID, locked)
    local door = Doors[doorID]
    if not door then return end
    door.locked = locked
    applyDoor(door)
end)

RegisterNetEvent('rsg-doorlock:client:syncAll', function(all)
    Doors = all or {}
end)

-- admin created / edited / deleted a door
RegisterNetEvent('rsg-doorlock:client:syncDoor', function(id, door, old)
    if old then applyDoor(old, true) end -- release hashes that may no longer be managed
    Doors[id] = door
    if door then applyDoor(door) end
    TriggerEvent('rsg-doorlock:client:editorRefresh')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if lockPrompt then PromptDelete(lockPrompt) end
    for ent in pairs(customState) do
        if DoesEntityExist(ent) then FreezeEntityPosition(ent, false) end
    end
end)
