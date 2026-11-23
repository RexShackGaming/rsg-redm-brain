local RSGCore = exports['rsg-core']:GetCoreObject()

local CINEMATIC_CAM = 0x620A6C5E -- INPUT_VEH_CINEMATIC_CAM (V)
local MARKER_DISTANCE = 50.0

local spawnedBlips = {}
local Delivery = nil -- { wagon, endCoords, deadline }
local starting = false -- true while a start request is in flight
local PendingWagon = nil -- wagon of a just-finished delivery, waiting for the server's verdict
local ReturnOffer = nil -- { wagon, expires } while a return load is on offer

---@return boolean true while this player has an active delivery or one is being started
function IsDeliveryBusy() return Delivery ~= nil or starting end

local function SecondsToClock(seconds)
    return ('%02d:%02d:%02d'):format(seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function Notify(description, ntype, title, duration)
    RSGCore.Functions.Notify({ title = title or locale('delivery_title'), description = description, type = ntype, duration = duration or 5000 })
end

local function DeleteWagon(wagon, delay)
    if not wagon then return end
    SetTimeout(delay or 0, function()
        if DoesEntityExist(wagon) then DeleteVehicle(wagon) end
    end)
end

local function EndDelivery(deleteDelay, keepWagon)
    if not Delivery then return end
    if Config.ShowDeliveryTimerUI then exports['rsg-core']:HideText() end
    ClearGpsMultiRoute()
    if not keepWagon then DeleteWagon(Delivery.wagon, deleteDelay) end
    Delivery = nil
end

local function FailDelivery(reason, localeKey)
    Notify(locale(localeKey), 'error', locale('delivery_failed_title'), 7000)
    TriggerServerEvent('rsg-deliveries:server:faildelivery', reason)
    EndDelivery()
end

---------------------------------
-- hub blips
---------------------------------
CreateThread(function()
    for _, v in ipairs(Config.DeliveryLocations) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.cartSpawn.x, v.cartSpawn.y, v.cartSpawn.z) -- BlipAddForCoords
        SetBlipSprite(blip, joaat(Config.Blip.blipSprite), true)
        SetBlipScale(blip, Config.Blip.blipScale)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, v.label) -- SetBlipName
        spawnedBlips[#spawnedBlips + 1] = blip
    end
end)

---------------------------------
-- delivery loop: one thread handles timer, marker, wagon health and arrival
---------------------------------
local function RunDelivery()
    local nextSlowTick = 0
    while Delivery do
        local wagon, endCoords = Delivery.wagon, Delivery.endCoords
        local ped = PlayerPedId()
        local playerDist = #(GetEntityCoords(ped) - endCoords)
        local needFrame = false -- per-frame work is only needed in the wagon or near the drop-off

        if IsPedInVehicle(ped, wagon, false) then
            DisableControlAction(0, CINEMATIC_CAM, true)
            needFrame = true
        end

        if Config.DestinationMarker and playerDist < MARKER_DISTANCE then
            needFrame = true
            Citizen.InvokeNative(0x2A32FAA57B937173, 0x07DCE236, endCoords.x, endCoords.y, endCoords.z, 0, 0, 0, 0, 0, 0, 5.0, 5.0, 5.0, 163, 51, 13, 250, false, false, 2, false, false)
        end

        local now = GetGameTimer()
        if now >= nextSlowTick then
            nextSlowTick = now + 1000
            local remaining = math.max(0, (Delivery.deadline - now) // 1000)

            if remaining <= 0 then
                FailDelivery('timeout', 'delivery_failed_timeout')
                return
            elseif not DoesEntityExist(wagon) then
                FailDelivery('wagon_lost', 'delivery_failed_lost')
                return
            elseif IsEntityDead(ped) then
                FailDelivery('player_died', 'delivery_failed_died')
                return
            elseif not IsVehicleDriveable(wagon) then
                FailDelivery('damaged_wagon', 'delivery_failed_damaged')
                return
            end

            if Delivery.fragile and not Delivery.warned then
                local maxHealth = GetEntityMaxHealth(wagon)
                if maxHealth > 0 and (GetEntityHealth(wagon) / maxHealth) * 100 < Config.Fragile.WarnBelowPct then
                    Delivery.warned = true
                    Notify(locale('delivery_fragile_warning'), 'warning')
                end
            end

            local wagonDist = #(GetEntityCoords(wagon) - endCoords)
            if wagonDist < Config.CompleteDistance and playerDist < Config.CompleteDistance + 5.0 then
                TriggerServerEvent('rsg-deliveries:server:completedelivery', NetworkGetNetworkIdFromEntity(wagon))
                -- keep the wagon until the server answers: it may offer a return load, otherwise it is removed
                local finished = wagon
                PendingWagon = finished
                EndDelivery(nil, true)
                SetTimeout(10000, function()
                    if PendingWagon == finished then PendingWagon = nil DeleteWagon(finished) end
                end)
                return
            end

            if Config.ShowDeliveryTimerUI then
                exports['rsg-core']:DrawText(locale('delivery_time_remaining', SecondsToClock(remaining), math.floor(wagonDist)), Config.UIPosition)
            end
        end

        Wait(needFrame and 0 or 250)
    end
end

local function BeginTracking(wagon, endCoords, seconds, fragile)
    Delivery = { wagon = wagon, endCoords = endCoords, deadline = GetGameTimer() + seconds * 1000, fragile = fragile }
    starting = false

    StartGpsMultiRoute(joaat('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(endCoords.x, endCoords.y, endCoords.z)
    SetGpsMultiRouteRender(true)
    CreateThread(RunDelivery)
end

local function LoadModel(hash)
    return pcall(RSGCore.Functions.RequestModel, hash, 5000)
end

---Called from the NUI contract board (client/npcs.lua)
function StartDelivery(hubIndex, destIndex)
    if IsDeliveryBusy() then
        return Notify(locale('delivery_already_active'), 'error')
    end

    local location = Config.DeliveryLocations[hubIndex]
    local data = location and location.deliveries[destIndex]
    if not data then return end

    local spawn = location.cartSpawn
    local closestVeh, closestDist = RSGCore.Functions.GetClosestVehicle(spawn.xyz)
    if closestVeh and closestVeh ~= -1 and closestDist and closestDist <= Config.SpawnVehDistance then
        return Notify(locale('delivery_blocked'), 'error')
    end

    local cartHash = joaat(data.wagonModel)
    local cargoHash = data.cargo and data.cargo ~= '' and joaat(data.cargo) or nil
    local lightHash = data.light and data.light ~= '' and joaat(data.light) or nil

    starting = true
    if not LoadModel(cartHash) then
        starting = false
        return Notify(locale('delivery_spawn_failed'), 'error')
    end

    local contract = RSGCore.Functions.AwaitCallback('rsg-deliveries:server:startdelivery', 10000, hubIndex, destIndex)
    if not contract then
        SetModelAsNoLongerNeeded(cartHash)
        starting = false
        return
    end
    ReturnOffer = nil -- the server deleted the unclaimed return wagon when it accepted the new contract

    local vehicle = CreateVehicle(cartHash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetModelAsNoLongerNeeded(cartHash)
    if not vehicle or vehicle == 0 then
        starting = false
        TriggerServerEvent('rsg-deliveries:server:canceldelivery')
        return Notify(locale('delivery_spawn_failed'), 'error')
    end

    if cargoHash then AddPropSetForVehicle(vehicle, cargoHash) end
    if lightHash then AddLightPropSetToVehicle(vehicle, lightHash) end

    SetVehicleOnGroundProperly(vehicle)

    -- give the wagon a moment to get its network id before telling the server about it
    local netTimeout = GetGameTimer() + 5000
    while not NetworkGetEntityIsNetworked(vehicle) and GetGameTimer() < netTimeout do Wait(50) end
    TriggerServerEvent('rsg-deliveries:server:setwagon', NetworkGetNetworkIdFromEntity(vehicle))

    BeginTracking(vehicle, data.deliveryLoc, contract.seconds, contract.fragile)
    Notify(locale('delivery_started', data.label, math.floor(contract.seconds / 60)), 'inform')
end

---------------------------------
-- return trips
---------------------------------
RegisterNetEvent('rsg-deliveries:client:finished', function(offered, offerTime)
    local wagon = PendingWagon
    PendingWagon = nil
    if not wagon then return end
    if offered then
        ReturnOffer = { wagon = wagon, expires = GetGameTimer() + (offerTime or 60) * 1000 }
    else
        DeleteWagon(wagon, 1500)
    end
end)

RegisterCommand(Config.ReturnTrips.Command, function()
    if not Config.ReturnTrips.Enabled then return end
    if IsDeliveryBusy() then return Notify(locale('delivery_already_active'), 'error') end
    if not ReturnOffer or GetGameTimer() > ReturnOffer.expires or not DoesEntityExist(ReturnOffer.wagon) then
        ReturnOffer = nil
        return Notify(locale('delivery_return_none'), 'error')
    end

    starting = true
    local offer = ReturnOffer
    local result = RSGCore.Functions.AwaitCallback('rsg-deliveries:server:acceptreturn', 10000)
    ReturnOffer = nil
    if not result then
        starting = false
        return
    end
    BeginTracking(offer.wagon, result.endCoords, result.seconds, result.fragile)
    Notify(locale('delivery_return_started', result.label), 'inform')
end, false)

RegisterCommand('canceldelivery', function()
    if not Delivery then
        if ReturnOffer then
            ReturnOffer = nil
            TriggerServerEvent('rsg-deliveries:server:declinereturn')
            return Notify(locale('delivery_cancelled'), 'inform')
        end
        return Notify(locale('delivery_none_active'), 'error')
    end
    TriggerServerEvent('rsg-deliveries:server:canceldelivery')
    EndDelivery()
    Notify(locale('delivery_cancelled'), 'inform')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    EndDelivery()
    if PendingWagon then DeleteWagon(PendingWagon) end
    if ReturnOffer then DeleteWagon(ReturnOffer.wagon) end
    for _, blip in ipairs(spawnedBlips) do RemoveBlip(blip) end
end)
