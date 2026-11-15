-- shared client helpers for rsg-farming (loaded first)
local RSGCore = exports['rsg-core']:GetCoreObject()

Utils = {
    busy     = false, -- one global busy flag so planting / pumps / tending can't overlap
    uiFocus  = false, -- true while the NUI owns mouse focus
    ownProps = {},    -- [entity] = true for props this resource spawned (never cleaned up as scenario props)
    blockers = {},    -- [plant entity] = invisible collision blocker entity
}

function Utils.notify(desc, ntype)
    if not desc then return end
    RSGCore.Functions.Notify({ title = locale('farming'), description = desc, type = ntype or 'inform', duration = 4000 })
end

function Utils.canAct()
    local ped = PlayerPedId()
    return not Utils.busy and not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) and not IsPedOnMount(ped)
end

-- runs fn with the busy flag set and ALWAYS clears it, even if fn errors (no stuck "busy" state)
function Utils.guard(fn, ...)
    Utils.busy = true
    local ok, err = pcall(fn, ...)
    Utils.busy = false
    if not ok then print(('^1[rsg-farming] %s^7'):format(tostring(err))) end
end

function Utils.face(x, y)
    TaskTurnPedToFaceCoord(PlayerPedId(), x, y, 0.0, 800)
    Wait(800)
end

---------------------------------
-- NUI focus (keeps push-to-talk working while the UI is open)
---------------------------------
function Utils.setNuiFocus(enable)
    Utils.uiFocus = enable
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then SetNuiFocusKeepInput(true) end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

CreateThread(function()
    while true do
        if Utils.uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            for _, c in ipairs(Config.PushToTalkControls or {}) do
                EnableControlAction(0, c, true)
                EnableControlAction(1, c, true)
                EnableControlAction(2, c, true)
            end
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and Utils.uiFocus then Utils.setNuiFocus(false) end
end)

---------------------------------
-- placement (rsg-gizmo)
---------------------------------
-- blocking: call from a thread/event handler. check(coords) -> ok, reason
-- returns coords, heading | nil when cancelled
function Utils.place(model, check)
    local res = exports['rsg-gizmo']:Place(model, {
        maxDistance = Config.PlaceMaxDistance,
        rotation = 'z',
        snapToGround = true,
        allowWater = false,
        validate = check and function(coords)
            local ok, reason = check(coords)
            return ok and true or false, reason
        end or nil,
    })
    if not res then return nil end
    return res.coords, res.heading
end

function Utils.inBlockedZone(coords)
    for _, z in ipairs(Config.NoPlantZones or {}) do
        if #(coords - z.coords) <= z.radius then return true end
    end
    return false
end

---------------------------------
-- scenarios
---------------------------------
local function snapshotObjects()
    local set = {}
    for _, obj in ipairs(GetGamePool('CObject')) do set[obj] = true end
    return set
end

-- removes props a scenario spawned (bucket, feed bag, tools) whether still held or dropped
local function cleanupScenarioProps(ped, before)
    local myId = PlayerId()
    local pedPos = GetEntityCoords(ped)
    for _, obj in ipairs(GetGamePool('CObject')) do
        if not before[obj] and not Utils.ownProps[obj] and DoesEntityExist(obj) then
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

-- plays a scenario with a progress bar, returns true if completed
function Utils.playScenario(scenario, duration, label)
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

---------------------------------
-- props
---------------------------------
function Utils.loadModel(model)
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

-- spawns a frozen, non-networked prop and registers it as ours
function Utils.spawnProp(model, x, y, z, heading)
    local hash = Utils.loadModel(model)
    if not hash then return nil end
    local obj = CreateObject(hash, x, y, z, false, false, false)
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    Utils.ownProps[obj] = true

    -- custom streamed props with no collision get an invisible blocker at the same spot
    if Config.CollisionProps and Config.CollisionProps[model] then
        local bHash = Utils.loadModel(Config.CollisionModel or 'p_invalid01x')
        if bHash then
            local blocker = CreateObject(bHash, x, y, z, false, false, false)
            PlaceObjectOnGroundProperly(blocker)
            SetEntityHeading(blocker, heading or 0.0)
            FreezeEntityPosition(blocker, true)
            SetEntityVisible(blocker, false, false)
            SetModelAsNoLongerNeeded(bHash)
            Utils.ownProps[blocker] = true
            Utils.blockers[obj] = blocker
        end
    end
    return obj
end

function Utils.deleteProp(obj)
    if not obj then return end
    Utils.ownProps[obj] = nil
    local blocker = Utils.blockers[obj]
    if blocker then
        Utils.blockers[obj] = nil
        Utils.ownProps[blocker] = nil
        if DoesEntityExist(blocker) then DeleteObject(blocker) end
    end
    if DoesEntityExist(obj) then DeleteObject(obj) end
end
