ActiveTrain = nil           -- entity handle
ActiveTrainBlip = nil
ActiveTrainData = nil       -- DB row data
ActiveTrainConfig = nil     -- config table reference
ActiveTrainStation = nil    -- station where it was spawned
EngineRunning = false
TrainFuel = 0
TrainWater = 0
TrainCondition = 0

---------------------------------------------------------------
-- CHECK IF A STATION'S SPAWN POINT IS CLEAR OF OTHER TRAINS
-- Used before auto-spawning a train for a mission, so we don't spawn
-- on top of / collide with a train already sitting at the station.
---------------------------------------------------------------
local trainModelHashSet = nil
local function GetTrainModelHashSet()
    if trainModelHashSet then return trainModelHashSet end
    trainModelHashSet = {}
    for _, tc in ipairs(Config.Trains) do
        trainModelHashSet[joaat(tc.model)] = true
    end
    return trainModelHashSet
end

function IsTrainSpawnClear(coords, radius)
    radius = radius or 20.0
    local hashes = GetTrainModelHashSet()
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and hashes[GetEntityModel(veh)] then
            if GetDistanceBetween(coords, GetEntityCoords(veh)) < radius then
                return false
            end
        end
    end
    return true
end

---------------------------------------------------------------
-- SPAWN PLAYER TRAIN
---------------------------------------------------------------
function SpawnPlayerTrain(trainDbId, directionReverse, station)
    if ActiveTrain and DoesEntityExist(ActiveTrain) then
        Notify(locale('train_already_spawned'), 'error')
        return
    end

    -- Get train data from server
    local trainData = lib.callback.await('rsg-railroad:getTrainById', false, trainDbId)
    if not trainData then
        Notify(locale('train_not_found'), 'error')
        return
    end

    local trainConfig = FindTrainConfig(trainData.train_model, trainData.company_id)
    if not trainConfig then
        Notify(locale('train_config_not_found'), 'error')
        return
    end

    local trainHash = joaat(trainData.train_model)
    LoadTrainCars(trainHash)

    local spawnCoords = station.spawnCoords
    local hasCarriages = trainConfig and trainConfig.hasPassengerCars or false
    ActiveTrain = Citizen.InvokeNative(0xC239DBD9A57D2A71, trainHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, directionReverse, hasCarriages, true, false)

    SetTrainSpeed(ActiveTrain, 0.0)
    SetTrainCruiseSpeed(ActiveTrain, 0.0)
    Citizen.InvokeNative(0x05254BA0B44ADC16, ActiveTrain, false) -- SetVehicleCanBeTargetted

    -- Blip
    ActiveTrainBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, Config.Blips.train.hash, ActiveTrain)
    SetBlipScale(ActiveTrainBlip, Config.Blips.train.scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, ActiveTrainBlip, trainConfig.label)

    -- Store state
    ActiveTrainData = trainData
    ActiveTrainConfig = trainConfig
    ActiveTrainStation = station
    TrainFuel = trainData.fuel
    TrainWater = trainData.water
    TrainCondition = trainData.condition
    EngineRunning = false

    -- Tell server we spawned
    TriggerServerEvent('rsg-railroad:setTrainSpawned', true, trainData.id, trainData.train_model)

    Notify(locale('train_spawned'), 'success')
    DebugPrint('Train spawned: ' .. trainConfig.label)

    -- Setup ox_target on the train
    SetupTrainTarget()
    SetupPassengerTarget()  -- passenger boarding option (passenger trains only)

    StartFuelDecrease()
    StartWaterDecrease()
    StartConditionDecrease()
    StartDistanceMonitor()
    StartMileageTracker()
end

---------------------------------------------------------------
-- PARK TRAIN
-- V2: SPAWN FROM CONFIG (no DB record needed)
-- Trains belong to the company, not individual players
---------------------------------------------------------------
function SpawnConfigTrain(trainConfig, directionReverse, station)
    if ActiveTrain and DoesEntityExist(ActiveTrain) then
        Notify(locale('train_already_spawned'), 'error')
        return
    end

    local trainHash = joaat(trainConfig.model)
    LoadTrainCars(trainHash)

    local spawnCoords = station.spawnCoords
    local hasCarriages = trainConfig.hasPassengerCars or false
    ActiveTrain = Citizen.InvokeNative(0xC239DBD9A57D2A71, trainHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, directionReverse, hasCarriages, true, false)

    SetTrainSpeed(ActiveTrain, 0.0)
    SetTrainCruiseSpeed(ActiveTrain, 0.0)
    Citizen.InvokeNative(0x05254BA0B44ADC16, ActiveTrain, false)

    -- Blip
    ActiveTrainBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, Config.Blips.train.hash, ActiveTrain)
    SetBlipScale(ActiveTrainBlip, Config.Blips.train.scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, ActiveTrainBlip, trainConfig.label)

    -- Fetch company upgrade for this train model (if any)
    local compUpgrade = lib.callback.await('rsg-railroad:getTrainModelUpgrade', false, trainConfig.company, trainConfig.model)

    -- Store state (no DB data, use config + company upgrades)
    ActiveTrainData = {
        id = 0,
        train_model = trainConfig.model,
        company_id = trainConfig.company,
        label = trainConfig.label,
        fuel = math.floor(trainConfig.maxFuel * 0.5),
        water = math.floor(trainConfig.maxWater * 0.5),
        condition = math.floor(trainConfig.maxCondition * 0.5),
        upgrade_speed     = compUpgrade and (compUpgrade.upgrade_speed or 0)     or 0,
        upgrade_fuel_cap  = compUpgrade and (compUpgrade.upgrade_fuel_cap or 0)  or 0,
        upgrade_water_cap = compUpgrade and (compUpgrade.upgrade_water_cap or 0) or 0,
        upgrade_durability = compUpgrade and (compUpgrade.upgrade_durability or 0) or 0,
        total_miles = 0,
    }
    ActiveTrainConfig = trainConfig
    ActiveTrainStation = station
    TrainFuel = ActiveTrainData.fuel
    TrainWater = ActiveTrainData.water
    TrainCondition = ActiveTrainData.condition
    EngineRunning = false

    TriggerServerEvent('rsg-railroad:setTrainSpawned', true, 0, trainConfig.model)

    Notify(locale('train_spawned'), 'success')
    DebugPrint('Config train spawned: ' .. trainConfig.label)

    SetupTrainTarget()

    StartFuelDecrease()
    StartWaterDecrease()
    StartConditionDecrease()
    StartDistanceMonitor()
    StartMileageTracker()
end

---------------------------------------------------------------
-- TRAIN STORAGE: CONFIRM BEFORE A MANUAL PUT-AWAY
--
-- Train storage is wiped whenever the train leaves the world. This asks
-- for confirmation first on the DELIBERATE routes (park / despawn / send
-- to yard) so a player cannot destroy a full hold with one misclick.
-- Automatic routes (distance despawn, death, mission failure, disconnect)
-- intentionally do NOT call this -- there is nobody to ask.
--
-- Returns true if the put-away should proceed.
---------------------------------------------------------------
function ConfirmStoragePutAway()
    local cfg = Config.TrainStorage
    if not cfg or not cfg.Enabled or not cfg.ConfirmOnPutAway then return true end

    local state = lib.callback.await('rsg-railroad:getTrainStorageState', false)
    if not state or not state.active or (state.stacks or 0) <= 0 then return true end

    local answer = lib.alertDialog({
        header   = locale('storage_confirm_title'),
        content  = locale('storage_confirm_body', state.stacks),
        centered = true,
        cancel   = true,
        labels   = {
            confirm = locale('storage_confirm_yes'),
            cancel  = locale('storage_confirm_no'),
        },
    })
    return answer == 'confirm'
end

---------------------------------------------------------------
-- PARK TRAIN
---------------------------------------------------------------
function ParkPlayerTrain()
    if not ActiveTrain or not DoesEntityExist(ActiveTrain) then return end

    local station = GetCurrentStation()
    if not station then
        Notify(locale('must_be_at_station_park'), 'error')
        return
    end

    local pcoords = GetEntityCoords(PlayerPedId())
    local dist = GetDistanceBetween(pcoords, station.coords)
    if dist > 50 then
        Notify(locale('too_far_to_park'), 'error')
        return
    end

    -- Save state to DB
    TriggerServerEvent('rsg-railroad:parkTrain', ActiveTrainData.id, station.id, TrainFuel, TrainWater, TrainCondition)

    CleanupActiveTrain()
    Notify(locale('train_parked_msg', station.label), 'success')
end

---------------------------------------------------------------
-- DESPAWN TRAIN (no save - just remove)
---------------------------------------------------------------
function DespawnPlayerTrain()
    if not ActiveTrain or not DoesEntityExist(ActiveTrain) then return end

    -- Save current fuel/water/condition
    if ActiveTrainData then
        TriggerServerEvent('rsg-railroad:updateTrainState', ActiveTrainData.id, TrainFuel, TrainWater, TrainCondition)
        TriggerServerEvent('rsg-railroad:setTrainSpawned', false, ActiveTrainData.id)
    end

    CleanupActiveTrain()
    Notify(locale('train_despawned'), 'inform')
end

---------------------------------------------------------------
-- CLEANUP
---------------------------------------------------------------
function CleanupActiveTrain()
    -- Remove ox_target
    if ActiveTrain and DoesEntityExist(ActiveTrain) then
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_refuel')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_water')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_repair')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_engine')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_reverse')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_switch')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_check')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_sendyard')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_water_item')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_repair_item')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_board')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_unboard')
        exports.ox_target:removeLocalEntity(ActiveTrain, 'railroad_storage')
    end

    if ActiveTrainBlip then
        RemoveBlip(ActiveTrainBlip)
        ActiveTrainBlip = nil
    end
    if ActiveTrain and DoesEntityExist(ActiveTrain) then
        DeleteEntity(ActiveTrain)
    end
    ActiveTrain = nil
    ActiveTrainData = nil
    ActiveTrainConfig = nil
    ActiveTrainStation = nil
    EngineRunning = false
    TrainFuel = 0
    TrainWater = 0
    TrainCondition = 0

    -- Cleanup passenger system
    CleanupPassengerTarget()

    -- Cleanup any in-progress delivery cargo (attached or carried barrels)
    CleanupDeliveryCargo()

    -- Close HUD if open
    SendNUIMessage({ action = 'closeTrainHUD' })
end

---------------------------------------------------------------
-- FUEL DECREASE LOOP
---------------------------------------------------------------
function StartFuelDecrease()
    CreateThread(function()
        while ActiveTrain and DoesEntityExist(ActiveTrain) do
            Wait(Config.Fuel.decreaseInterval)
            if EngineRunning and TrainFuel > 0 then
                TrainFuel = math.max(0, TrainFuel - Config.Fuel.decreaseAmount)
                TriggerServerEvent('rsg-railroad:updateFuel', ActiveTrainData.id, TrainFuel)
                if TrainFuel <= 0 then
                    Notify(locale('fuel_empty'), 'error')
                    -- Gradual slowdown when fuel runs out
                    CreateThread(function()
                        for i = 1, 50 do
                            if not ActiveTrain or not DoesEntityExist(ActiveTrain) then break end
                            if TrainFuel > 0 then break end -- refueled mid-stop
                            local vel = GetEntitySpeed(ActiveTrain)
                            if vel < 0.5 then
                                SetTrainSpeed(ActiveTrain, 0.0)
                                break
                            end
                            local newVel = vel * 0.92 -- slow reduction
                            SetTrainSpeed(ActiveTrain, newVel)
                            Citizen.InvokeNative(0x9F29999DFDF2AEB8, ActiveTrain, newVel + 0.1)
                            Wait(200)
                        end
                        if ActiveTrain and DoesEntityExist(ActiveTrain) and TrainFuel <= 0 then
                            SetTrainSpeed(ActiveTrain, 0.0)
                            Citizen.InvokeNative(0x9F29999DFDF2AEB8, ActiveTrain, 0.0)
                        end
                    end)
                end
            end
        end
    end)
end

---------------------------------------------------------------
-- WATER DECREASE LOOP
---------------------------------------------------------------
function StartWaterDecrease()
    CreateThread(function()
        while ActiveTrain and DoesEntityExist(ActiveTrain) do
            Wait(Config.Water.decreaseInterval)
            if EngineRunning and TrainWater > 0 then
                TrainWater = math.max(0, TrainWater - Config.Water.decreaseAmount)
                TriggerServerEvent('rsg-railroad:updateWater', ActiveTrainData.id, TrainWater)
                if TrainWater <= 0 then
                    Notify(locale('water_empty'), 'warning')
                end
            end
        end
    end)
end

---------------------------------------------------------------
-- CONDITION DECREASE LOOP
---------------------------------------------------------------
function StartConditionDecrease()
    CreateThread(function()
        while ActiveTrain and DoesEntityExist(ActiveTrain) do
            Wait(Config.Condition.decreaseInterval)
            if EngineRunning and TrainCondition > 0 then
                local amount = Config.Condition.decreaseAmount
                -- Degrade faster if no water
                if TrainWater <= 0 then amount = amount * 2 end
                TrainCondition = math.max(0, TrainCondition - amount)
                TriggerServerEvent('rsg-railroad:updateCondition', ActiveTrainData.id, TrainCondition)
                if TrainCondition <= 0 then
                    Notify(locale('condition_critical'), 'error')
                    -- Cap speed
                    local maxSpd = ActiveTrainConfig.maxSpeed * Config.Condition.lowConditionSpeedCap
                    Citizen.InvokeNative(0x9F29999DFDF2AEB8, ActiveTrain, maxSpd + 0.1)
                end
            end
        end
    end)
end

---------------------------------------------------------------
-- DISTANCE MONITOR (despawn if too far)
---------------------------------------------------------------
function StartDistanceMonitor()
    CreateThread(function()
        -- Storage is wiped if the train auto-despawns, which is the most common
        -- cause of accidental loss. Warn while the player still has time to
        -- turn back, but only when they are actually carrying something.
        local storageCfg = Config.TrainStorage
        local warnAt = (storageCfg and storageCfg.Enabled and storageCfg.DistanceWarnPercent)
            and (Config.TrainDespawnDist * storageCfg.DistanceWarnPercent) or nil
        local warnInterval = (storageCfg and storageCfg.DistanceWarnInterval) or 15000
        local lastWarn = 0

        while ActiveTrain and DoesEntityExist(ActiveTrain) do
            Wait(5000)
            local pcoords = GetEntityCoords(PlayerPedId())
            local tcoords = GetEntityCoords(ActiveTrain)
            local dist = GetDistanceBetween(pcoords, tcoords)

            if warnAt and dist > warnAt and dist <= Config.TrainDespawnDist then
                local now = GetGameTimer()
                if now - lastWarn > warnInterval then
                    lastWarn = now
                    local state = lib.callback.await('rsg-railroad:getTrainStorageState', false)
                    if state and state.active and (state.stacks or 0) > 0 then
                        Notify(locale('storage_distance_warning'), 'warning', 8000)
                    end
                end
            end

            if dist > Config.TrainDespawnDist then
                Notify(locale('train_too_far'), 'error')
                DespawnPlayerTrain()
                break
            end
        end
    end)
end

---------------------------------------------------------------
-- MILEAGE TRACKER
---------------------------------------------------------------
function StartMileageTracker()
    CreateThread(function()
        local lastCoords = GetEntityCoords(ActiveTrain)
        while ActiveTrain and DoesEntityExist(ActiveTrain) do
            Wait(10000)
            if EngineRunning then
                local curCoords = GetEntityCoords(ActiveTrain)
                local dist = GetDistanceBetween(lastCoords, curCoords)
                if dist > 5 then
                    local miles = dist / 100.0 -- rough conversion
                    TriggerServerEvent('rsg-railroad:addMiles', ActiveTrainData.id, miles)
                end
                lastCoords = curCoords
            end
        end
    end)
end

--------------------------------------------------------------
-- OX_TARGET: MAINTENANCE ACTIONS ON TRAIN
---------------------------------------------------------------
function SetupTrainTarget()
    if not ActiveTrain or not DoesEntityExist(ActiveTrain) then return end

    -- Shovel & Animation Config (easy to change later)
    local shovelModel = "p_shovel02x"
    local shovelAnim = { dict = "amb_work@world_human_gravedig@working@male_b@idle_a", name = "idle_a" }
    local shovelBone = "skel_r_hand"

    exports.ox_target:addLocalEntity(ActiveTrain, {
        -- 1. Start / Stop Engine
        {
            name = 'railroad_engine',
            label = locale('menu_start_stop_engine'),
            icon = 'fas fa-power-off',
            distance = 4.0,
            onSelect = function() ToggleEngine() end,
        },

        -- 2. Add Coal (+10% Fuel)
        {
            name = 'railroad_refuel',
            label = locale('menu_add_coal'),
            icon = 'fas fa-fire',
            distance = 4.0,
            onSelect = function()
                if not ActiveTrainData or not ActiveTrainConfig then return end
                if TrainFuel >= ActiveTrainConfig.maxFuel then
                    Notify(locale('fuel_tank_full'), 'error')
                    return
                end

                local hasItem = exports['rsg-core']:GetCoreObject().Functions.HasItem(Config.Fuel.item, 1)
                if not hasItem then
                    Notify(locale('need_item_1x', Config.Fuel.itemLabel), 'error')
                    return
                end

                local ped = PlayerPedId()
                SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                FreezeEntityPosition(ped, true)

                -- Load and attach shovel
                local shovelHash = joaat(shovelModel)
                RequestModel(shovelHash)
                while not HasModelLoaded(shovelHash) do Wait(10) end

                local shovel = CreateObject(shovelHash, 0, 0, 0, true, true, true)
                local boneIndex = GetEntityBoneIndexByName(ped, shovelBone)

                AttachEntityToEntity(shovel, ped, boneIndex, 
                    0.06, -0.06, -0.03,    -- position
                    270.0, 165.0, 150.0,   -- rotation
                    false, false, false, false, 2, true)

                -- Play animation
                RequestAnimDict(shovelAnim.dict)
                while not HasAnimDictLoaded(shovelAnim.dict) do Wait(10) end
                TaskPlayAnim(ped, shovelAnim.dict, shovelAnim.name, 8.0, -8.0, -1, 1, 0, false, false, false)

                -- Progress bar
                if lib.progressBar({
                    duration = 5000,
                    label = locale('progress_shoveling_coal'),
                    useWhileDead = false,
                    canCancel = true,
                    disable = { move = true, combat = true }
                }) then
                    TriggerServerEvent('rsg-railroad:useMaintenanceItem', 'fuel', ActiveTrainData and ActiveTrainData.id or 0)
                end

                -- Cleanup
                ClearPedTasks(ped)
                if DoesEntityExist(shovel) then DeleteEntity(shovel) end
                SetModelAsNoLongerNeeded(shovelHash)
                RemoveAnimDict(shovelAnim.dict)
                FreezeEntityPosition(ped, false)
            end,
        },
        -- 3. Check Train Condition
        {
            name = 'railroad_check',
            label = locale('menu_check_condition'),
            icon = 'fas fa-clipboard-check',
            distance = 4.0,
            onSelect = function() OpenConditionMenu() end,
        },
        -- Train Storage (per-deployment cargo hold).
        -- NOTE: the stash identifier is resolved server-side from the player's
        -- active deployment -- the client deliberately sends nothing, so a stash
        -- id cannot be forged.
        {
            name = 'railroad_storage',
            label = locale('storage_target'),
            icon = 'fas fa-box-open',
            distance = 4.0,
            canInteract = function()
                return Config.TrainStorage ~= nil and Config.TrainStorage.Enabled
            end,
            onSelect = function()
                TriggerServerEvent('rsg-railroad:openTrainStorage')
            end,
        },
        -- 4. Toggle Track Switches
        {
            name = 'railroad_switch',
            label = locale('menu_toggle_switches'),
            icon = 'fas fa-random',
            distance = 4.0,
            onSelect = function() ToggleTrackSwitches() end,
        },
        -- 5. Fill Water [Water Tower]
        {
            name = 'railroad_water',
            label = locale('menu_fill_water_tower'),
            icon = 'fas fa-tint',
            distance = 4.0,
            onSelect = function()
                if not ActiveTrainData or not ActiveTrainConfig then return end
                if not IsNearWaterTower() then
                    Notify(locale('must_near_water_tower'), 'error')
                    return
                end
                if TrainWater >= ActiveTrainConfig.maxWater then
                    Notify(locale('water_tank_full'), 'error')
                    return
                end
                local ped = PlayerPedId()
                FreezeEntityPosition(ped, true)
                TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_BUCKET_POUR_LOW'), 0, true, false, false, false)
                if lib.progressBar({ duration = 8000, label = locale('progress_filling_water_tower'), useWhileDead = false, canCancel = true, disable = { move = true, combat = true } }) then
                    TrainWater = ActiveTrainConfig.maxWater
                    Notify(locale('water_tank_filled_full'), 'success')
                end
                ClearPedTasks(ped)
                SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                FreezeEntityPosition(ped, false)
            end,
        },
        -- 6. Full Repair [Depot]
        {
            name = 'railroad_repair',
            label = locale('menu_full_repair_depot'),
            icon = 'fas fa-wrench',
            distance = 4.0,
            onSelect = function()
                if not ActiveTrainData or not ActiveTrainConfig then return end
                if not IsNearMaintenanceDepot() then
                    Notify(locale('must_near_maintenance_depot'), 'error')
                    return
                end
                if TrainCondition >= ActiveTrainConfig.maxCondition then
                    Notify(locale('condition_full'), 'error')
                    return
                end
                local ped = PlayerPedId()
                FreezeEntityPosition(ped, true)
                TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), 0, true, false, false, false)
                if lib.progressBar({ duration = 10000, label = locale('progress_full_maintenance_repair'), useWhileDead = false, canCancel = true, disable = { move = true, combat = true } }) then
                    TrainCondition = ActiveTrainConfig.maxCondition
                    Notify(locale('train_fully_repaired_full'), 'success')
                end
                ClearPedTasks(ped)
                FreezeEntityPosition(ped, false)
            end,
        },
        -- 7. Emergency Water (only when water = 0)
        {
            name = 'railroad_water_item',
            label = locale('menu_emergency_water'),
            icon = 'fas fa-tint',
            distance = 4.0,
            canInteract = function() return TrainWater <= 0 end,
            onSelect = function()
                if not ActiveTrainData or not ActiveTrainConfig then return end
                local hasItem = exports['rsg-core']:GetCoreObject().Functions.HasItem(Config.Water.item, 1)
                if not hasItem then
                    Notify(locale('need_item_1x', Config.Water.itemLabel), 'error')
                    return
                end
                local ped = PlayerPedId()
                FreezeEntityPosition(ped, true)
                TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_BUCKET_POUR_LOW'), 0, true, false, false, false)
                if lib.progressBar({ duration = 4000, label = locale('progress_emergency_water'), useWhileDead = false, canCancel = true, disable = { move = true, combat = true } }) then
                    TriggerServerEvent('rsg-railroad:useMaintenanceItem', 'water', ActiveTrainData and ActiveTrainData.id or 0)
                end
                ClearPedTasks(ped)
                SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                FreezeEntityPosition(ped, false)
            end,
        },
        -- 8. Emergency Repair (only when condition = 0)
        {
            name = 'railroad_repair_item',
            label = locale('menu_emergency_repair'),
            icon = 'fas fa-wrench',
            distance = 4.0,
            canInteract = function() return TrainCondition <= 0 end,
            onSelect = function()
                if not ActiveTrainData or not ActiveTrainConfig then return end
                local hasItem = exports['rsg-core']:GetCoreObject().Functions.HasItem(Config.Condition.item, 1)
                if not hasItem then
                    Notify(locale('need_item_1x', Config.Condition.itemLabel), 'error')
                    return
                end
                local ped = PlayerPedId()
                FreezeEntityPosition(ped, true)
                TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), 0, true, false, false, false)
                if lib.progressBar({ duration = 4000, label = locale('progress_emergency_repair'), useWhileDead = false, canCancel = true, disable = { move = true, combat = true } }) then
                    TriggerServerEvent('rsg-railroad:useMaintenanceItem', 'condition', ActiveTrainData and ActiveTrainData.id or 0)
                end
                ClearPedTasks(ped)
                FreezeEntityPosition(ped, false)
            end,
        },
        -- (Passenger boarding/unboarding via ox_target removed - now handled by the
        --  continuous passenger system in passengers.lua via 'All Aboard' option)
        -- 11. Reverse Direction
        {
            name = 'railroad_reverse',
            label = locale('menu_reverse_direction'),
            icon = 'fas fa-exchange-alt',
            distance = 4.0,
            onSelect = function()
                if not ActiveTrain or not DoesEntityExist(ActiveTrain) then return end
                if not ActiveTrainConfig then return end
                local currentSpeed = GetEntitySpeed(ActiveTrain)
                if currentSpeed > 1 then
                    Notify(locale('stop_before_reversing'), 'error')
                    return
                end
                -- Despawn and respawn in opposite direction
                local trainCoords = GetEntityCoords(ActiveTrain)
                local wasReversed = ActiveTrainData._reversed or false
                local newReversed = not wasReversed
                -- Save current state
                local savedFuel = TrainFuel
                local savedWater = TrainWater
                local savedCond = TrainCondition
                local savedConfig = ActiveTrainConfig
                local savedStation = ActiveTrainStation
                -- Cleanup current train
                CleanupActiveTrain()
                -- Respawn at same location, flipped
                local trainHash = joaat(savedConfig.model)
                LoadTrainCars(trainHash)
                local hasCarriages = savedConfig.hasPassengerCars or false
                ActiveTrain = Citizen.InvokeNative(0xC239DBD9A57D2A71, trainHash, trainCoords.x, trainCoords.y, trainCoords.z, newReversed, hasCarriages, true, false)
                SetTrainSpeed(ActiveTrain, 0.0)
                SetTrainCruiseSpeed(ActiveTrain, 0.0)
                Citizen.InvokeNative(0x05254BA0B44ADC16, ActiveTrain, false)
                -- Blip
                ActiveTrainBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, Config.Blips.train.hash, ActiveTrain)
                SetBlipScale(ActiveTrainBlip, Config.Blips.train.scale)
                Citizen.InvokeNative(0x9CB1A1623062F402, ActiveTrainBlip, savedConfig.label)
                -- Restore state
                ActiveTrainConfig = savedConfig
                ActiveTrainStation = savedStation
                ActiveTrainData = {
                    id = 0,
                    train_model = savedConfig.model,
                    company_id = savedConfig.company,
                    label = savedConfig.label,
                    fuel = savedFuel,
                    water = savedWater,
                    condition = savedCond,
                    upgrade_speed = 0, upgrade_fuel_cap = 0, upgrade_water_cap = 0, upgrade_durability = 0,
                    total_miles = 0,
                    _reversed = newReversed,
                }
                TrainFuel = savedFuel
                TrainWater = savedWater
                TrainCondition = savedCond
                EngineRunning = false
                -- Reversing re-fires setTrainSpawned, but the server already has
                -- this player registered as having a train out, so it returns
                -- early and the existing stash (and its load) is preserved.
                TriggerServerEvent('rsg-railroad:setTrainSpawned', true, 0, savedConfig.model)
                SetupTrainTarget()
                StartFuelDecrease()
                StartWaterDecrease()
                StartConditionDecrease()
                StartDistanceMonitor()
                StartMileageTracker()
                Notify(locale('train_reversed'), 'success')
            end,
        },
        -- All Aboard (passenger trains only, stopped at a station)
        {
            name = 'railroad_all_aboard',
            label    = locale('menu_all_aboard'),
            icon     = 'fas fa-users',
            distance = 6.0,
            canInteract = function()
                return ActiveTrainConfig
                    and ActiveTrainConfig.hasPassengerCars == true
                    and GetNearestStoppedStation ~= nil
                    and GetNearestStoppedStation() ~= nil
            end,
            onSelect = function()
                if TriggerAllAboard then TriggerAllAboard() end
            end,
        },
        -- Send Train to Yard
        {
            name = 'railroad_sendyard',
            label = locale('menu_send_train_yard'),
            icon = 'fas fa-warehouse',
            distance = 4.0,
            onSelect = function()
                -- Deliberate put-away: confirm before destroying a loaded hold.
                if not ConfirmStoragePutAway() then return end
                SendTrainToYard()
            end,
        },
    })
end

---------------------------------------------------------------
-- OX_LIB MENU: CHECK TRAIN CONDITION
---------------------------------------------------------------
function OpenConditionMenu()
    if not ActiveTrainData or not ActiveTrainConfig then
        Notify(locale('no_active_train'), 'error')
        return
    end

    local maxFuel = ActiveTrainConfig.maxFuel
    local maxWater = ActiveTrainConfig.maxWater
    local maxCond = ActiveTrainConfig.maxCondition

    -- Apply upgrade bonuses to max values
    if ActiveTrainData.upgrade_fuel_cap and ActiveTrainData.upgrade_fuel_cap > 0 and Config.Upgrades.fuel_cap[ActiveTrainData.upgrade_fuel_cap] then
        maxFuel = maxFuel + Config.Upgrades.fuel_cap[ActiveTrainData.upgrade_fuel_cap].bonus
    end
    if ActiveTrainData.upgrade_water_cap and ActiveTrainData.upgrade_water_cap > 0 and Config.Upgrades.water_cap[ActiveTrainData.upgrade_water_cap] then
        maxWater = maxWater + Config.Upgrades.water_cap[ActiveTrainData.upgrade_water_cap].bonus
    end

    local fuelPct = math.floor((TrainFuel / maxFuel) * 100)
    local waterPct = math.floor((TrainWater / maxWater) * 100)
    local condPct = math.floor((TrainCondition / maxCond) * 100)

    local fuelBar = GetBarDisplay(fuelPct)
    local waterBar = GetBarDisplay(waterPct)
    local condBar = GetBarDisplay(condPct)

    lib.registerContext({
        id = 'railroad_condition_menu',
        title = locale('report_condition_title'),
        options = {
            { title = locale('report_fuel_title'), description = fuelBar .. '  ' .. TrainFuel .. '/' .. maxFuel .. ' (' .. fuelPct .. '%)',  icon = 'fire' },
            { title = locale('report_water_title'), description = waterBar .. '  ' .. TrainWater .. '/' .. maxWater .. ' (' .. waterPct .. '%)', icon = 'tint' },
            { title = locale('report_condition_row_title'), description = condBar .. '  ' .. TrainCondition .. '/' .. maxCond .. ' (' .. condPct .. '%)',  icon = 'wrench' },
            { title = locale('report_engine_title'), description = EngineRunning and locale('report_engine_running') or locale('report_engine_stopped'), icon = 'cog' },
            { title = locale('report_speed_title'), description = GetCurrentSpeed() .. ' / ' .. GetMaxTrainSpeed() .. ' max', icon = 'tachometer-alt' },
            { title = locale('report_miles_title'), description = string.format('%.1f', ActiveTrainData.total_miles or 0), icon = 'road' },
            { title = locale('report_company_title'), description = Config.Companies[ActiveTrainConfig.company] and Config.Companies[ActiveTrainConfig.company].label or locale('report_company_unknown'), icon = 'building' },
        },
    })
    lib.showContext('railroad_condition_menu')
end

---------------------------------------------------------------
-- SEND TRAIN TO YARD (despawn + save state, ready to redeploy)
---------------------------------------------------------------
function SendTrainToYard()
    if not ActiveTrain or not DoesEntityExist(ActiveTrain) then
        Notify(locale('no_active_train'), 'error')
        return
    end
    if not ActiveTrainData then return end

    -- Save current state to DB
    TriggerServerEvent('rsg-railroad:updateTrainState', ActiveTrainData.id, TrainFuel, TrainWater, TrainCondition)
    TriggerServerEvent('rsg-railroad:setTrainSpawned', false, ActiveTrainData.id)

    CleanupActiveTrain()
    Notify(locale('train_despawned'), 'success')
end

-- Helper: visual bar for condition menu
function GetBarDisplay(pct)
    local filled = math.floor(pct / 10)
    local empty = 10 - filled
    return string.rep('█', filled) .. string.rep('░', empty)
end

---------------------------------------------------------------
-- MAINTENANCE RESULT (server removed item, apply locally)
---------------------------------------------------------------
RegisterNetEvent('rsg-railroad:maintenanceResult', function(mType, success)
    if not success or not ActiveTrainConfig then return end
    local addPct = 0.10 -- 10%
    if mType == 'fuel' then
        local add = math.floor(ActiveTrainConfig.maxFuel * addPct)
        TrainFuel = math.min(TrainFuel + add, ActiveTrainConfig.maxFuel)
        local pct = math.floor((TrainFuel / ActiveTrainConfig.maxFuel) * 100)
        Notify(locale('fuel_added_pct', pct), 'success')
    elseif mType == 'water' then
        local add = math.floor(ActiveTrainConfig.maxWater * addPct)
        TrainWater = math.min(TrainWater + add, ActiveTrainConfig.maxWater)
        local pct = math.floor((TrainWater / ActiveTrainConfig.maxWater) * 100)
        Notify(locale('water_added_pct', pct), 'success')
    elseif mType == 'condition' then
        local add = math.floor(ActiveTrainConfig.maxCondition * addPct)
        TrainCondition = math.min(TrainCondition + add, ActiveTrainConfig.maxCondition)
        local pct = math.floor((TrainCondition / ActiveTrainConfig.maxCondition) * 100)
        Notify(locale('condition_repaired_pct', pct), 'success')
    end
end)
