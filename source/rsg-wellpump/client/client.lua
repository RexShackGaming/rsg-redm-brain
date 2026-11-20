local RSGCore = exports['rsg-core']:GetCoreObject()

local Pumps    = {}   -- [id] = { id, x, y, z, h }
local Mine     = {}   -- [id] = true for pumps this character placed (sent by the server)
local Spawned  = {}   -- [id] = entity
local ownProps = {}   -- [entity] = true for props this resource spawned
local busy     = false
local placing  = false   -- true while this resource has an rsg-gizmo session open

---------------------------------
-- helpers
---------------------------------
local function notify(desc, ntype)
    if not desc then return end
    RSGCore.Functions.Notify({ title = locale('title'), description = desc, type = ntype or 'inform', duration = 4000 })
end

local function canAct()
    local ped = PlayerPedId()
    return not busy and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) and not IsPedOnMount(ped)
end

local function face(x, y)
    TaskTurnPedToFaceCoord(PlayerPedId(), x, y, 0.0, 800)
    Wait(800)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 5000 then
            SetModelAsNoLongerNeeded(hash)
            return nil
        end
        Wait(10)
    end
    return hash
end

---------------------------------
-- scenarios (the bucket scenario spawns a prop that can be left behind, so it is cleaned up)
---------------------------------
local function snapshotObjects()
    local set = {}
    for _, obj in ipairs(GetGamePool('CObject')) do set[obj] = true end
    return set
end

local function cleanupScenarioProps(ped, before)
    local myId = PlayerId()
    local pedPos = GetEntityCoords(ped)
    for _, obj in ipairs(GetGamePool('CObject')) do
        if not before[obj] and not ownProps[obj] and DoesEntityExist(obj) then
            local attached = IsEntityAttachedToEntity(obj, ped)
            local nearMine = #(GetEntityCoords(obj) - pedPos) < 3.0
                and (not NetworkGetEntityIsNetworked(obj) or NetworkGetEntityOwner(obj) == myId)
            if attached or nearMine then
                if attached then DetachEntity(obj, true, true) end
                SetEntityAsMissionEntity(obj, true, true)
                DeleteObject(obj)
                if DoesEntityExist(obj) then DeleteEntity(obj) end
            end
        end
    end
end

-- plays a scenario with a progress bar, returns true if it finished
local function playScenario(scenario, duration, label)
    local ped = PlayerPedId()
    local before = snapshotObjects()
    TaskStartScenarioInPlaceHash(ped, joaat(scenario), -1, true, false, false, false)
    local ok = RSGCore.Functions.ProgressBar({
        duration = duration, label = label, useWhileDead = false, canCancel = true,
        disable = { move = true, combat = true, mount = true },
    })
    ClearPedTasks(ped, true, true)
    Wait(1500) -- let the exit anim finish / drop the prop
    ClearPedTasksImmediately(ped)
    cleanupScenarioProps(ped, before)
    Wait(500)  -- second pass for props dropped late
    cleanupScenarioProps(ped, before)
    return ok
end

local function drinkScenario()
    return IsPedMale(PlayerPedId()) and Config.Drink.scenarioMale or Config.Drink.scenarioFemale
end

local function notThirsty()
    if (LocalPlayer.state.thirst or 0) >= Config.Drink.notThirstyAbove then
        notify(locale('not_thirsty'))
        return true
    end
    return false
end

-- the server decides the amount; thirst is raised client-side the way the rest of the server does it
RegisterNetEvent('rsg-wellpump:client:thirst', function(amount)
    amount = tonumber(amount)
    if not amount then return end
    TriggerEvent('hud:client:UpdateThirst', math.max(0, math.min(100, (LocalPlayer.state.thirst or 0) + amount)))
end)

---------------------------------
-- props
---------------------------------
local function spawnProp(model, x, y, z, heading)
    local hash = loadModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, x, y, z, false, false, false)
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    ownProps[obj] = true
    return obj
end

local function deleteProp(obj)
    if not obj then return end
    ownProps[obj] = nil
    if DoesEntityExist(obj) then DeleteObject(obj) end
end

---------------------------------
-- pump actions ('fill' | 'pack')
---------------------------------
local function pumpAction(action, id, cb, scenario, duration, label)
    local p = Pumps[id]
    if not p or not canAct() then return end
    busy = true
    CreateThread(function()
        local can, reason = RSGCore.Functions.AwaitCallback('rsg-wellpump:server:precheck', nil, action, id)
        if not can then
            notify(reason, 'error')
            busy = false
            return
        end
        face(p.x, p.y)
        if playScenario(scenario, duration, label) then
            local ok, msg = RSGCore.Functions.AwaitCallback(cb, nil, id)
            notify(msg, ok and 'success' or 'error')
        else
            notify(locale('cancelled'), 'error')
        end
        busy = false
    end)
end

---------------------------------
-- spawning / streaming
---------------------------------
local function despawn(id)
    local ent = Spawned[id]
    if ent then
        pcall(function() exports['rsg-target']:removeLocalEntity(ent) end)
        deleteProp(ent)
    end
    Spawned[id] = nil
end

local function spawn(p)
    local ent = spawnProp(Config.Prop, p.x, p.y, p.z, p.h + 0.0)
    if not ent then return end
    Spawned[p.id] = ent

    exports['rsg-target']:addLocalEntity(ent, {
        {
            name = ('rsg_wellpump_fill_%s'):format(p.id),
            label = locale('target_fill'),
            icon = Config.TargetIcons.fill,
            distance = Config.InteractDist,
            canInteract = function() return not busy end,
            onSelect = function()
                pumpAction('fill', p.id, 'rsg-wellpump:server:fill', Config.FillScenario, Config.FillTime, locale('progress_fill'))
            end,
        },
        {
            name = ('rsg_wellpump_drink_%s'):format(p.id),
            label = locale('target_drink'),
            icon = Config.TargetIcons.drink,
            distance = Config.InteractDist,
            canInteract = function() return not busy and Config.Drink.enabled end,
            onSelect = function()
                if notThirsty() then return end
                pumpAction('drink', p.id, 'rsg-wellpump:server:drink', drinkScenario(), Config.Drink.time, locale('progress_drink'))
            end,
        },
        {
            name = ('rsg_wellpump_pack_%s'):format(p.id),
            label = locale('target_pack'),
            icon = Config.TargetIcons.pack,
            distance = Config.InteractDist,
            canInteract = function()
                return not busy and (not Config.OwnerOnlyPackup or Mine[p.id] == true)
            end,
            onSelect = function()
                pumpAction('pack', p.id, 'rsg-wellpump:server:pack', Config.PackScenario, Config.PackTime, locale('progress_pack'))
            end,
        },
    })
end

local function applySync(list, owned)
    local fresh = {}
    for _, p in ipairs(list or {}) do fresh[p.id] = p end
    for id in pairs(Spawned) do
        if not fresh[id] then despawn(id) end
    end
    Pumps = fresh
    Mine = {}
    for _, id in ipairs(owned or {}) do Mine[id] = true end
end

RegisterNetEvent('rsg-wellpump:client:sync', applySync)

local function requestPumps()
    local list, owned = RSGCore.Functions.AwaitCallback('rsg-wellpump:server:getPumps', nil)
    applySync(list, owned)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', requestPumps)

CreateThread(function()
    Wait(1000)
    requestPumps()
end)

-- distance streaming
CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for id, p in pairs(Pumps) do
            local near = #(pc - vector3(p.x, p.y, p.z)) < Config.RenderDistance
            if near and not Spawned[id] then spawn(p)
            elseif not near and Spawned[id] then despawn(id) end
        end
        Wait(1000)
    end
end)

---------------------------------
-- placement (rsg-gizmo)
---------------------------------
RegisterNetEvent('rsg-wellpump:client:place', function()
    if not canAct() then return end
    busy = true
    CreateThread(function()
        placing = true
        local res = exports['rsg-gizmo']:Place(Config.Prop, {
            title = locale('place_title'),
            maxDistance = Config.PlaceMaxDistance,
            rotation = 'z',
            validate = function(coords)
                for _, p in pairs(Pumps) do
                    if #(vector3(p.x, p.y, p.z) - vector3(coords.x, coords.y, coords.z)) < Config.MinDistance then
                        return false, locale('too_close')
                    end
                end
                return true
            end,
        })
        placing = false

        if res then
            face(res.coords.x, res.coords.y)
            if playScenario(Config.PackScenario, Config.PackTime, locale('progress_place')) then
                local ok, msg = RSGCore.Functions.AwaitCallback('rsg-wellpump:server:placePump', nil, res.coords, res.heading or 0.0)
                notify(msg, ok and 'success' or 'error')
            else
                notify(locale('cancelled'), 'error')
            end
        end
        busy = false
    end)
end)

---------------------------------
-- exports for other resources
---------------------------------
-- PlayFill() -> true when the player finished filling. Checks they carry an empty bucket, plays the
-- bucket scenario with a progress bar and cleans up the scenario prop. Call it from a thread, then
-- ask your own server event to do the fill (it should call exports['rsg-wellpump']:FillBucket).
exports('PlayFill', function()
    if busy or not canAct() then return false end
    if not RSGCore.Functions.HasItem(Config.EmptyItem, 1) then
        notify(locale('no_bucket'), 'error')
        return false
    end
    busy = true
    local ok = playScenario(Config.FillScenario, Config.FillTime, locale('progress_fill'))
    busy = false
    if not ok then notify(locale('cancelled'), 'error') end
    return ok
end)

-- PlayDrink() -> true when the player finished drinking. Plays the drink scenario with a progress bar.
-- Then ask your own server event to call exports['rsg-wellpump']:Drink(src), which raises thirst.
exports('PlayDrink', function()
    if busy or not canAct() or not Config.Drink.enabled or notThirsty() then return false end
    busy = true
    local ok = playScenario(drinkScenario(), Config.Drink.time, locale('progress_drink'))
    busy = false
    if not ok then notify(locale('cancelled'), 'error') end
    return ok
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Spawned) do despawn(id) end
    if placing then exports['rsg-gizmo']:Cancel() end
end)
