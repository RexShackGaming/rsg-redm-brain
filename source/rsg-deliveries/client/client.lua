lib.locale()

local CINEMATIC_CAM = 0x620A6C5E -- INPUT_VEH_CINEMATIC_CAM (V)
local MARKER_DISTANCE = 50.0

local spawnedBlips = {}
local Delivery = nil -- { wagon, endCoords, deadline }

local function SecondsToClock(seconds)
    return ('%02d:%02d:%02d'):format(seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function Notify(description, ntype, title, duration)
    lib.notify({ title = title or locale('delivery_title'), description = description, type = ntype, duration = duration or 5000 })
end

local function DeleteWagon(wagon, delay)
    if not wagon then return end
    SetTimeout(delay or 0, function()
        if DoesEntityExist(wagon) then DeleteVehicle(wagon) end
    end)
end

local function EndDelivery(deleteDelay)
    if not Delivery then return end
    lib.hideTextUI()
    ClearGpsMultiRoute()
    DeleteWagon(Delivery.wagon, deleteDelay)
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
        DisableControlAction(0, CINEMATIC_CAM, true)

        local wagon, endCoords = Delivery.wagon, Delivery.endCoords
        local playerCoords = GetEntityCoords(cache.ped)
        local playerDist = #(playerCoords - endCoords)

        if Config.DestinationMarker and playerDist < MARKER_DISTANCE then
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
            elseif not IsVehicleDriveable(wagon) then
                FailDelivery('damaged_wagon', 'delivery_failed_damaged')
                return
            end

            local wagonDist = #(GetEntityCoords(wagon) - endCoords)
            if wagonDist < Config.CompleteDistance and playerDist < Config.CompleteDistance + 5.0 then
                TriggerServerEvent('rsg-deliveries:server:completedelivery')
                EndDelivery(3000) -- leave the wagon briefly so the server can verify it
                return
            end

            if Config.ShowDeliveryTimerUI then
                lib.showTextUI(locale('delivery_time_remaining', SecondsToClock(remaining), math.floor(wagonDist)), {
                    position = Config.UIPosition,
                    icon = 'fa-regular fa-clock',
                })
            end
        end

        Wait(0)
    end
end

local function LoadModel(hash)
    return pcall(lib.requestModel, hash, 5000)
end

---Called from the NUI contract board (client/npcs.lua)
function StartDelivery(hubIndex, destIndex)
    if Delivery then
        return Notify(locale('delivery_already_active'), 'error')
    end

    local location = Config.DeliveryLocations[hubIndex]
    local data = location and location.deliveries[destIndex]
    if not data then return end

    local spawn = location.cartSpawn
    if lib.getClosestVehicle(spawn.xyz, Config.SpawnVehDistance) then
        return Notify(locale('delivery_blocked'), 'error')
    end

    local cartHash = joaat(data.wagonModel)
    local cargoHash = data.cargo and data.cargo ~= '' and joaat(data.cargo) or nil
    local lightHash = data.light and data.light ~= '' and joaat(data.light) or nil

    if not LoadModel(cartHash) then
        return Notify(locale('delivery_spawn_failed'), 'error')
    end

    if not lib.callback.await('rsg-deliveries:server:startdelivery', false, hubIndex, destIndex) then
        SetModelAsNoLongerNeeded(cartHash)
        return
    end

    local vehicle = CreateVehicle(cartHash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetModelAsNoLongerNeeded(cartHash)
    if not vehicle or vehicle == 0 then
        TriggerServerEvent('rsg-deliveries:server:canceldelivery')
        return Notify(locale('delivery_spawn_failed'), 'error')
    end

    if cargoHash then AddPropSetForVehicle(vehicle, cargoHash) end
    if lightHash then AddLightPropSetToVehicle(vehicle, lightHash) end

    TriggerServerEvent('rsg-deliveries:server:setwagon', NetworkGetNetworkIdFromEntity(vehicle))

    Delivery = {
        wagon = vehicle,
        endCoords = data.deliveryLoc,
        deadline = GetGameTimer() + Config.DefaultDeliveryTime * 60000,
    }

    StartGpsMultiRoute(joaat('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(data.deliveryLoc.x, data.deliveryLoc.y, data.deliveryLoc.z)
    SetGpsMultiRouteRender(true)

    Notify(locale('delivery_started', data.label, Config.DefaultDeliveryTime), 'inform')
    CreateThread(RunDelivery)
end

RegisterCommand('canceldelivery', function()
    if not Delivery then
        return Notify(locale('delivery_none_active'), 'error')
    end
    TriggerServerEvent('rsg-deliveries:server:canceldelivery')
    EndDelivery()
    Notify(locale('delivery_cancelled'), 'inform')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    EndDelivery()
    for _, blip in ipairs(spawnedBlips) do RemoveBlip(blip) end
end)
