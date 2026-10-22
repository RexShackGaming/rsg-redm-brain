-- rsg-lumberjack - Client

local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local KEY_E = 0xCEFD9220

local PlayerData = {}

local State = {
    busy = false,               -- chopping / planting / watering
    carryingLog = false,
    logObj = nil,
    wagonLogEntities = {},      -- [wagon entity] = { prop, prop, ... } (bottom -> top)
    plantedTrees = {},          -- [id] = payload from server
    treeEntities = {},          -- [id] = entity (only while in render range)
    groundLogs = {},            -- [id] = entity
    woodPieces = {},            -- [id] = entity
    otherPlayersCarrying = {},  -- [serverId] = { prop, ped }
}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function Notify(key, args, ntype)
    lib.notify({
        title = locale('notify_title'),
        description = args and locale(key, table.unpack(args)) or locale(key),
        type = ntype or 'inform',
        duration = 5000
    })
end

local function NotifyError(key, args) Notify(key, args, 'error') end

local function DebugPrint(...)
    if Config.Debug then print('[rsg-lumberjack]', ...) end
end

local function LoadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    return HasModelLoaded(model)
end

local function SpawnLocalProp(model, x, y, z)
    if not LoadModel(model) then return nil end
    local obj = CreateObject(model, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 or not DoesEntityExist(obj) then return nil end
    SetEntityAsMissionEntity(obj, true, true)
    return obj
end

local function DeleteLocalProp(entity)
    if entity and DoesEntityExist(entity) then
        exports.ox_target:removeLocalEntity(entity)
        DeleteEntity(entity)
    end
end

local function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFontForCurrentCommand(1)
    SetTextColor(255, 255, 255, 215)
    SetTextCentre(true)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), sx, sy)
end

local function DrawTreeProgressBar(x, y, z, progress, label)
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end
    progress = math.max(0.0, math.min(1.0, progress))

    local barWidth, barHeight = 0.055, 0.011
    DrawText3D(x, y, z + 0.35, label)
    DrawRect(sx, sy, barWidth + 0.002, barHeight + 0.004, 0, 0, 0, 200)
    DrawRect(sx, sy, barWidth, barHeight, 15, 15, 15, 160)
    if progress > 0.0 then
        local fgWidth = barWidth * progress
        DrawRect(sx - (barWidth / 2.0) + (fgWidth / 2.0), sy, fgWidth, barHeight, 90, 200, 110, 220)
    end
end

local function SetBusy(busy)
    State.busy = busy
    LocalPlayer.state:set('inv_busy', busy, true)
end

-- Plays a scenario under an ox_lib progress bar. Returns true if completed.
local function RunScenarioProgress(scenario, duration, label)
    local ped = PlayerPedId()
    SetBusy(true)
    TaskStartScenarioInPlace(ped, scenario, 0, true)
    local ok = lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    ClearPedTasks(ped)
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    SetBusy(false)
    return ok
end

local function RequestSync()
    TriggerServerEvent('rsg-lumberjack:server:requestSync')
end

-- ============================================================================
-- PLAYER LOAD / UNLOAD
-- ============================================================================
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    PlayerData = RSGCore.Functions.GetPlayerData()
    RequestSync()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    PlayerData = {} -- server clears carry state on unload
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    PlayerData = RSGCore.Functions.GetPlayerData() or {}
    if PlayerData.citizenid then RequestSync() end
end)

-- ============================================================================
-- CARRYING
-- ============================================================================
local function AttachLogToPed(ped)
    local coords = GetEntityCoords(ped)
    local obj = SpawnLocalProp(Config.Models.CarryLog, coords.x, coords.y, coords.z)
    if not obj then return nil end
    local a = Config.Carry.AttachBox
    AttachEntityToEntity(obj, ped, a.bone, a.pos.x, a.pos.y, a.pos.z, a.rot.x, a.rot.y, a.rot.z, true, true, false, true, 1, true)
    return obj
end

local function StartCarryLoop(ped)
    local dict, clip, flag = Config.Carry.AnimDict, Config.Carry.AnimClip, Config.Carry.AnimFlag
    lib.requestAnimDict(dict)

    local clipset = Config.Carry.MoveClipset
    if clipset and clipset ~= '' then
        lib.requestAnimSet(clipset)
        SetPedMovementClipset(ped, clipset, 0.0)
    end

    CreateThread(function()
        while State.carryingLog do
            if not IsEntityPlayingAnim(ped, dict, clip, 3) then
                TaskPlayAnim(ped, dict, clip, 2.0, 2.0, -1, flag, 0, false, false, false)
            end
            -- Drop prompt
            local c = GetEntityCoords(ped)
            DrawText3D(c.x, c.y, c.z + 1.1, locale('press_e_drop_log'))
            if IsControlJustPressed(0, KEY_E) then
                TriggerServerEvent('rsg-lumberjack:server:dropLog')
                Wait(500)
            end
            Wait(0)
        end
    end)
end

local function StopCarryingLocal()
    DeleteLocalProp(State.logObj)
    State.carryingLog = false
    State.logObj = nil
    local ped = PlayerPedId()
    if Config.Carry.MoveClipset and Config.Carry.MoveClipset ~= '' then ResetPedMovementClipset(ped, 0.0) end
    ClearPedTasks(ped)
end

-- Own carry state is driven by server events
RegisterNetEvent('rsg-lumberjack:client:startCarrying', function()
    if State.carryingLog then return end
    local ped = PlayerPedId()
    State.logObj = AttachLogToPed(ped)
    State.carryingLog = true
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    StartCarryLoop(ped)
end)

RegisterNetEvent('rsg-lumberjack:client:stopCarrying', StopCarryingLocal)

-- Other players' carried logs: reconciled from the replicated state bag, so
-- props appear when a carrying player streams in, follow ped changes
-- (respawn/model swap) and are removed when they stop or leave scope.
local function RemoveOtherCarry(serverId)
    local entry = State.otherPlayersCarrying[serverId]
    if entry then DeleteLocalProp(entry.prop) end
    State.otherPlayersCarrying[serverId] = nil
end

CreateThread(function()
    local me = PlayerId()
    while true do
        local seen = {}
        for _, player in ipairs(GetActivePlayers()) do
            if player ~= me then
                local serverId = GetPlayerServerId(player)
                if Player(serverId).state.lumberjackCarrying then
                    local ped = GetPlayerPed(player)
                    local entry = State.otherPlayersCarrying[serverId]
                    if not entry or entry.ped ~= ped or not DoesEntityExist(entry.prop) then
                        RemoveOtherCarry(serverId)
                        local prop = AttachLogToPed(ped)
                        if prop then State.otherPlayersCarrying[serverId] = { prop = prop, ped = ped } end
                    end
                    seen[serverId] = true
                end
            end
        end
        for serverId in pairs(State.otherPlayersCarrying) do
            if not seen[serverId] then RemoveOtherCarry(serverId) end
        end
        Wait(500)
    end
end)

-- ============================================================================
-- SECURE CHOP FLOW (wild tree / ground log / planted tree)
-- ============================================================================
local function CanStartAction()
    return not State.busy and not IsPedInAnyVehicle(PlayerPedId(), false)
end

local function RunChopFlow(kind, targetId)
    if not CanStartAction() then return end
    State.busy = true -- block double-clicks while the callback is in flight

    local result
    RSGCore.Functions.TriggerCallback('rsg-lumberjack:server:requestChop', function(res) result = res or { ok = false } end, kind, targetId)
    while not result do Wait(0) end

    if not result.ok then
        State.busy = false
        if result.reason then NotifyError(result.reason, result.args) end
        return
    end

    SetBusy(true)
    SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true) -- avoid a held weapon clipping with the axe prop
    local isLog = kind == 'groundlog'
    local success = lib.progressBar({
        duration = result.duration,
        label = isLog and locale('chop_log_label') or locale('chop_tree_label'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = isLog and {
            dict = 'amb_work@prop_human_wood_chop@pre_chop@male_a@trans',
            clip = 'prechop_trans_postchop_07_08_a',
            flag = 15,
        } or {
            dict = 'amb_work@world_human_tree_chop_new@working@pre_swing@male_a@trans',
            clip = 'pre_swing_trans_after_swing',
            flag = 17,
        },
        prop = {
            model = `p_axe02x`,
            bone = 7966,
            pos = vec3(0.03, 0.03, 0.02),
            rot = vec3(0.0, 0.0, -1.5)
        },
    })
    SetBusy(false)

    if success then
        TriggerServerEvent('rsg-lumberjack:server:completeChop', kind, targetId)
    else
        TriggerServerEvent('rsg-lumberjack:server:cancelChop')
        NotifyError('chop_cancelled')
    end
end

-- Wild trees
CreateThread(function()
    local plantedModels = {}
    for _, model in ipairs(Config.Planting.StageModels) do
        plantedModels[joaat(model)] = true
    end

    local wildTrees = {}
    for _, model in ipairs(Config.Trees) do
        if not plantedModels[model] then wildTrees[#wildTrees + 1] = model end
    end
    if #wildTrees == 0 then return end

    exports.ox_target:addModel(wildTrees, {
        {
            name = 'rsg_lumberjack_chop_wild',
            icon = 'fas fa-tree',
            label = locale('target_chop_tree'),
            distance = Config.Chopping.InteractDistance,
            canInteract = function() return not State.carryingLog and not State.busy end,
            onSelect = function() RunChopFlow('wildtree', 0) end,
        },
    })
    DebugPrint('Added targets to', #wildTrees, 'wild tree models')
end)

-- ============================================================================
-- GROUND LOGS
-- ============================================================================
local function SpawnGroundLog(log)
    local obj = SpawnLocalProp(Config.Models.GroundLog, log.x, log.y, log.z)
    if not obj then return end
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    exports.ox_target:addLocalEntity(obj, {
        {
            icon = 'fas fa-hammer',
            label = locale('target_process_log'),
            distance = 2.0,
            canInteract = function() return not State.carryingLog and not State.busy end,
            onSelect = function() RunChopFlow('groundlog', log.id) end,
        },
        {
            icon = 'fas fa-hand-paper',
            label = locale('target_pickup_log'),
            distance = 2.0,
            canInteract = function() return not State.carryingLog and not State.busy end,
            onSelect = function() TriggerServerEvent('rsg-lumberjack:server:pickupLog', log.id) end,
        },
    })
    State.groundLogs[log.id] = obj
end

local function RemoveGroundLog(id)
    DeleteLocalProp(State.groundLogs[id])
    State.groundLogs[id] = nil
end

RegisterNetEvent('rsg-lumberjack:client:syncGroundLogs', function(logs)
    for id in pairs(State.groundLogs) do RemoveGroundLog(id) end
    for _, log in ipairs(logs) do SpawnGroundLog(log) end
end)

RegisterNetEvent('rsg-lumberjack:client:addGroundLog', SpawnGroundLog)
RegisterNetEvent('rsg-lumberjack:client:removeGroundLog', RemoveGroundLog)

-- ============================================================================
-- WOOD PILES
-- ============================================================================
local function SpawnWood(wood)
    local obj = SpawnLocalProp(Config.Models.WoodProp, wood.x, wood.y, wood.z)
    if not obj then return end
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    exports.ox_target:addLocalEntity(obj, {
        {
            icon = 'fas fa-hand-paper',
            label = locale('target_pickup_wood'),
            distance = 2.0,
            canInteract = function() return not State.carryingLog end,
            onSelect = function() TriggerServerEvent('rsg-lumberjack:server:pickupWood', wood.id) end,
        },
    })
    State.woodPieces[wood.id] = obj
end

local function RemoveWood(id)
    DeleteLocalProp(State.woodPieces[id])
    State.woodPieces[id] = nil
end

RegisterNetEvent('rsg-lumberjack:client:syncWoodPieces', function(woods)
    for id in pairs(State.woodPieces) do RemoveWood(id) end
    for _, wood in ipairs(woods) do SpawnWood(wood) end
end)

RegisterNetEvent('rsg-lumberjack:client:addWoodPiece', SpawnWood)
RegisterNetEvent('rsg-lumberjack:client:removeWoodPiece', RemoveWood)

-- ============================================================================
-- WAGON (load / unload / sell)
-- ============================================================================
-- Wagon log props are reconciled from the wagon's replicated state bag, so
-- they appear for players who stream in later and vanish when the wagon is
-- deleted, sold or leaves range.
local WAGON_RENDER_DIST = 80.0

local function AddWagonLogProp(wagon, entry, posIndex)
    local pos = Config.Wagon.LogPositions[posIndex]
    local prop = SpawnLocalProp(Config.Wagon.LogStackModel, 0.0, 0.0, 0.0)
    if not prop then return false end
    AttachEntityToEntity(prop, wagon, 0, pos.x, pos.y, pos.z, pos.rotX, pos.rotY, pos.rotZ, true, true, true, true, 1, true)
    exports.ox_target:addLocalEntity(prop, {
        {
            icon = 'fas fa-hand-paper',
            label = locale('target_remove_log'),
            distance = 3.0,
            canInteract = function() return not State.carryingLog and not State.busy end,
            onSelect = function()
                TriggerServerEvent('rsg-lumberjack:server:removeLogFromWagon', NetworkGetNetworkIdFromEntity(wagon))
            end,
        },
    })
    entry[#entry + 1] = prop
    return true
end

local function ClearWagonLogProps(wagon)
    for _, prop in ipairs(State.wagonLogEntities[wagon] or {}) do DeleteLocalProp(prop) end
    State.wagonLogEntities[wagon] = nil
end

local function GetWagonLogCount(wagon)
    local count = tonumber(Entity(wagon).state.lumberjackLogs) or 0
    return math.max(0, math.min(count, Config.Wagon.MaxLogsOnWagon, #Config.Wagon.LogPositions))
end

local function ReconcileWagon(wagon, count)
    local entry = State.wagonLogEntities[wagon] or {}
    while #entry > count do DeleteLocalProp(table.remove(entry)) end
    while #entry < count do
        if not AddWagonLogProp(wagon, entry, #entry + 1) then break end
    end
    State.wagonLogEntities[wagon] = #entry > 0 and entry or nil
end

-- Immediate updates for wagons already in range
AddStateBagChangeHandler('lumberjackLogs', nil, function(bagName, _, value)
    local wagon = GetEntityFromStateBagName(bagName)
    if wagon == 0 or GetEntityModel(wagon) ~= Config.Wagon.Model then return end
    ReconcileWagon(wagon, math.max(0, math.min(tonumber(value) or 0, Config.Wagon.MaxLogsOnWagon, #Config.Wagon.LogPositions)))
end)

-- Periodic pass for wagons streaming in/out
CreateThread(function()
    while true do
        local pCoords = GetEntityCoords(PlayerPedId())
        local nearby = {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if GetEntityModel(veh) == Config.Wagon.Model and #(pCoords - GetEntityCoords(veh)) <= WAGON_RENDER_DIST then
                nearby[veh] = true
                ReconcileWagon(veh, GetWagonLogCount(veh))
            end
        end
        for wagon in pairs(State.wagonLogEntities) do
            if not nearby[wagon] then ClearWagonLogProps(wagon) end
        end
        Wait(1000)
    end
end)

exports.ox_target:addModel({ Config.Wagon.Model }, {
    {
        name = 'rsg_lumberjack_wagon_load',
        icon = 'fas fa-truck-loading',
        label = locale('target_load_wagon'),
        distance = 3.0,
        canInteract = function() return State.carryingLog end,
        onSelect = function(data)
            TriggerServerEvent('rsg-lumberjack:server:addLogToWagon', NetworkGetNetworkIdFromEntity(data.entity))
        end,
    },
    {
        name = 'rsg_lumberjack_wagon_check',
        icon = 'fas fa-clipboard-check',
        label = locale('target_check_wagon'),
        distance = 3.0,
        onSelect = function(data)
            Notify('wagon_check', { GetWagonLogCount(data.entity), Config.Wagon.MaxLogsOnWagon })
        end,
    },
})

-- Sell points: blips + a single proximity loop that only runs fast while
-- the player is driving a log wagon near a buyer.
CreateThread(function()
    for _, location in ipairs(Config.WagonSellLocations) do
        if location.blip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, location.coords.x, location.coords.y, location.coords.z) -- BlipAddForCoords
            SetBlipSprite(blip, location.blip.sprite, true)
            SetBlipScale(blip, location.blip.scale or 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, location.blip.label or locale('blip_sell_logs')) -- SetBlipName
        end
    end

    local shown = false
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local nearSell = false

        if vehicle ~= 0 and GetEntityModel(vehicle) == Config.Wagon.Model then
            local coords = GetEntityCoords(ped)
            for _, location in ipairs(Config.WagonSellLocations) do
                local dist = #(coords - location.coords)
                if dist < location.radius then
                    nearSell = true
                    break
                elseif dist < location.radius + 50.0 then
                    sleep = 250
                end
            end
        end

        if nearSell then
            sleep = 0
            if not shown then
                lib.showTextUI(locale('press_e_sell'))
                shown = true
            end
            if IsControlJustPressed(0, KEY_E) then
                TriggerServerEvent('rsg-lumberjack:server:sellWagonLoad')
                Wait(1000)
            end
        elseif shown then
            lib.hideTextUI()
            shown = false
        end

        Wait(sleep)
    end
end)

-- ============================================================================
-- TREE PLANTING
-- ============================================================================
RegisterNetEvent('rsg-lumberjack:client:useSeed', function()
    if not CanStartAction() or State.carryingLog then return NotifyError('busy') end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local target = coords + fwd * (Config.Chopping.RaycastDistance - 0.5)
    local found, groundZ = GetGroundZFor_3dCoord(target.x, target.y, target.z + 1.0, false)
    if not found then return NotifyError('invalid_location') end

    if not RunScenarioProgress(`WORLD_HUMAN_FARMER_WEEDING`, Config.Planting.PlantDuration, locale('planting_label')) then
        return NotifyError('action_cancelled')
    end

    TriggerServerEvent('rsg-lumberjack:server:plantTree', { x = target.x, y = target.y, z = groundZ }, GetEntityHeading(ped))
end)

local function WaterTree(id)
    if not CanStartAction() or State.carryingLog then return NotifyError('busy') end
    if Config.Planting.RequireWater and not RSGCore.Functions.HasItem(Config.Planting.WaterItem, 1) then
        return NotifyError('need_water')
    end
    if not RunScenarioProgress(`WORLD_HUMAN_BUCKET_POUR_LOW`, Config.Planting.WaterDuration, locale('watering_label')) then
        return NotifyError('action_cancelled')
    end
    TriggerServerEvent('rsg-lumberjack:server:waterTree', id)
end

local function NeedsWater(t)
    return t.stage < 4 and t.state ~= 'growing' and t.watered == 0
end

RegisterNetEvent('rsg-lumberjack:client:useWater', function()
    local pcoords = GetEntityCoords(PlayerPedId())
    local nearestId, nearestDist = nil, Config.Chopping.InteractDistance + 1.5
    for id, t in pairs(State.plantedTrees) do
        if NeedsWater(t) then
            local dist = #(pcoords - vector3(t.x, t.y, t.z))
            if dist <= nearestDist then nearestId, nearestDist = id, dist end
        end
    end
    if not nearestId then return NotifyError('no_tree_nearby_water') end
    WaterTree(nearestId)
end)

-- ============================================================================
-- PLANTED TREES (streamed props)
-- ============================================================================
local function RegisterPlantedTreeTarget(ent, tree)
    exports.ox_target:removeLocalEntity(ent)
    local options = {}
    if tree.stage == 4 and tree.state == 'ready' then
        options[1] = {
            icon = 'fas fa-tree',
            label = locale('target_chop_tree'),
            distance = Config.Chopping.InteractDistance,
            canInteract = function() return not State.carryingLog and not State.busy end,
            onSelect = function() RunChopFlow('plantedtree', tree.id) end,
        }
    elseif NeedsWater(tree) and Config.Planting.RequireWater then
        options[1] = {
            icon = 'fas fa-droplet',
            label = locale('target_water_tree'),
            distance = Config.Chopping.InteractDistance,
            canInteract = function() return not State.busy end,
            onSelect = function() WaterTree(tree.id) end,
        }
    end
    if #options > 0 then exports.ox_target:addLocalEntity(ent, options) end
end

local function DespawnPlantedTree(id)
    DeleteLocalProp(State.treeEntities[id])
    State.treeEntities[id] = nil
end

local function SpawnOrUpdatePlantedTree(tree)
    local model = joaat(Config.Planting.StageModels[tree.stage] or Config.Planting.StageModels[4])
    local current = State.treeEntities[tree.id]

    if current and DoesEntityExist(current) then
        if GetEntityModel(current) == model then
            RegisterPlantedTreeTarget(current, tree) -- options depend on state/watered
            return
        end
        DespawnPlantedTree(tree.id)
    end

    local obj = SpawnLocalProp(model, tree.x, tree.y, tree.z)
    if not obj then return end
    SetEntityHeading(obj, tree.heading or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    State.treeEntities[tree.id] = obj
    RegisterPlantedTreeTarget(obj, tree)
end

local function StoreTree(tree)
    tree.stage = tonumber(tree.stage) or 1
    tree.watered = tonumber(tree.watered) or 0
    tree.receivedAt = GetGameTimer() -- local countdown base for the progress bar
    State.plantedTrees[tree.id] = tree
end

RegisterNetEvent('rsg-lumberjack:client:updateTreeVisual', function(tree)
    StoreTree(tree)
    if State.treeEntities[tree.id] then SpawnOrUpdatePlantedTree(tree) end
end)

RegisterNetEvent('rsg-lumberjack:client:setTrees', function(list)
    for id in pairs(State.treeEntities) do DespawnPlantedTree(id) end
    State.plantedTrees = {}
    for _, t in ipairs(list or {}) do StoreTree(t) end
end)

RegisterNetEvent('rsg-lumberjack:client:removeTree', function(id)
    DespawnPlantedTree(id)
    State.plantedTrees[id] = nil
end)

-- Streaming: only render tree props near the player
CreateThread(function()
    while true do
        Wait(1000)
        local pCoords = GetEntityCoords(PlayerPedId())
        local renderDist = Config.Planting.RenderDistance
        for id, t in pairs(State.plantedTrees) do
            local inRange = #(pCoords - vector3(t.x, t.y, t.z)) <= renderDist
            local ent = State.treeEntities[id]
            if inRange and not (ent and DoesEntityExist(ent)) then
                SpawnOrUpdatePlantedTree(t)
            elseif not inRange and ent then
                DespawnPlantedTree(id)
            end
        end
    end
end)

-- Owner growth progress bar
CreateThread(function()
    while true do
        local sleep = 1000
        local cid = PlayerData.citizenid
        if cid then
            local pCoords = GetEntityCoords(PlayerPedId())
            local barDist = Config.Planting.ProgressBarDistance
            for _, t in pairs(State.plantedTrees) do
                if t.owner_citizenid == cid and t.state == 'growing' and t.growth_remaining
                    and #(pCoords - vector3(t.x, t.y, t.z)) <= barDist then
                    sleep = 0
                    local elapsed = (GetGameTimer() - t.receivedAt) / 1000.0
                    local progress = 1.0 - (math.max(0, t.growth_remaining - elapsed) / t.growth_duration)
                    DrawTreeProgressBar(t.x, t.y, t.z + 2.3, progress, locale('tree_growing_label', math.floor(progress * 100)))
                end
            end
        end
        Wait(sleep)
    end
end)

-- ============================================================================
-- DEBUG
-- ============================================================================
if Config.Debug then
    RegisterCommand('spawnwagon', function()
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped) + GetEntityForwardVector(ped) * 5.0
        if not LoadModel(Config.Wagon.Model) then return end
        local wagon = CreateVehicle(Config.Wagon.Model, pos.x, pos.y, pos.z, GetEntityHeading(ped), true, true)
        SetModelAsNoLongerNeeded(Config.Wagon.Model)
        SetEntityAsMissionEntity(wagon, true, true)
    end, false)
end

-- ============================================================================
-- RESOURCE STOP
-- ============================================================================
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if State.carryingLog then StopCarryingLocal() end
    if State.busy then LocalPlayer.state:set('inv_busy', false, true) end
    lib.hideTextUI()

    for serverId in pairs(State.otherPlayersCarrying) do RemoveOtherCarry(serverId) end
    for _, e in pairs(State.groundLogs) do DeleteLocalProp(e) end
    for _, e in pairs(State.woodPieces) do DeleteLocalProp(e) end
    for _, e in pairs(State.treeEntities) do DeleteLocalProp(e) end
    for wagon in pairs(State.wagonLogEntities) do ClearWagonLogProps(wagon) end
end)
