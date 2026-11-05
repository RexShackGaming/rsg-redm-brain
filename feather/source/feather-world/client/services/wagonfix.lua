local GET_PED_IN_DRAFT_HARNESS = 0xA8BA0BAE0173457B
local GET_DRIVER_OF_VEHICLE = 0x2963B5C1637E8A27
local REMOVE_VEHICLE_LIGHT_PROP_SETS = 0xE31C0CB1C3186D40
local REMOVE_VEHICLE_PROP_SETS = 0x3BCF32FF37EA9F1D
local SET_VEHICLE_UNDRIVEABLE = 0x16B5E274BDE402F8

local wagonConfig = Config.WagonFix
local componentModels = {}

WagonFixActive = false

for _, modelName in ipairs(wagonConfig.components) do
    componentModels[GetHashKey(modelName)] = true
end

local function WagonLog(message)
    if Config.DevMode then
        print(('[feather-world] wagon cleanup: %s'):format(message))
    end
end

local function IsProtectedPed(ped)
    return ped == PlayerPedId() or IsPedAPlayer(ped) or IsEntityAMissionEntity(ped)
end

local function RequestEntityControl(entity)
    if not DoesEntityExist(entity) then return false end

    if not NetworkGetEntityIsNetworked(entity) or NetworkHasControlOfEntity(entity) then return true end

    local control = wagonConfig.networkControl
    for _ = 1, control.maxAttempts do
        NetworkRequestControlOfEntity(entity)
        if NetworkHasControlOfEntity(entity) then return true end

        Wait(control.waitMs)
    end

    return NetworkHasControlOfEntity(entity)
end

local function DeleteAmbientEntity(entity, label)
    if not DoesEntityExist(entity) or IsEntityAMissionEntity(entity) then return false end

    if IsEntityAPed(entity) and IsProtectedPed(entity) then return false end

    if not RequestEntityControl(entity) then
        WagonLog(('could not gain control of %s'):format(label))
        return false
    end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
    if DoesEntityExist(entity) then
        WagonLog(('could not delete %s'):format(label))
        return false
    end

    return true
end

local function HasPlayerOccupant(wagon)
    for _, ped in ipairs(GetGamePool('CPed') or {}) do
        if DoesEntityExist(ped) and IsPedAPlayer(ped) then
            if GetVehiclePedIsIn(ped, false) == wagon or IsEntityAttachedToEntity(ped, wagon) then
                return true
            end
        end
    end

    return false
end

local function ShouldRemoveWagon(wagon)
    if not DoesEntityExist(wagon) or not IsEntityAVehicle(wagon) then return false end

    if not IsVehicleStopped(wagon) or IsEntityAMissionEntity(wagon) then return false end

    if HasPlayerOccupant(wagon) then return false end

    local horse = Citizen.InvokeNative(GET_PED_IN_DRAFT_HARNESS, wagon, 0)
    return DoesEntityExist(horse) and IsPedWalking(horse) and not IsProtectedPed(horse)
end

local function RemoveHarnessHorses(wagon)
    local removed = 0
    for harnessIndex = 0, 5 do
        local horse = Citizen.InvokeNative(GET_PED_IN_DRAFT_HARNESS, wagon, harnessIndex)
        if DoesEntityExist(horse) and not IsProtectedPed(horse)
            and DeleteAmbientEntity(horse, ('harness horse %d'):format(harnessIndex)) then
            removed = removed + 1
        end
    end

    return removed
end

local function RemoveWagonOccupants(wagon, wagonCoords)
    local removed = 0
    for _, ped in ipairs(GetGamePool('CPed') or {}) do
        if DoesEntityExist(ped) and not IsProtectedPed(ped) then
            local distance = #(wagonCoords - GetEntityCoords(ped))
            if distance <= wagonConfig.occupantDistance
                and (GetVehiclePedIsIn(ped, false) == wagon or IsEntityAttachedToEntity(ped, wagon))
                and DeleteAmbientEntity(ped, 'wagon occupant') then
                removed = removed + 1
            end
        end
    end

    return removed
end

local function RemoveWagonObjects(wagon, wagonCoords)
    local removed = 0
    for _, object in ipairs(GetGamePool('CObject') or {}) do
        if DoesEntityExist(object) and not IsEntityAMissionEntity(object) then
            local attached = IsEntityAttachedToEntity(object, wagon)
            local knownNearby = componentModels[GetEntityModel(object)] == true
                and #(wagonCoords - GetEntityCoords(object)) <= wagonConfig.componentDistance
            if (attached or knownNearby) and DeleteAmbientEntity(object, 'wagon component') then
                removed = removed + 1
            end
        end
    end

    return removed
end

local function ProcessStuckWagon(wagon)
    if not ShouldRemoveWagon(wagon) then return end

    local wagonCoords = GetEntityCoords(wagon)
    local removed = RemoveHarnessHorses(wagon)
        + RemoveWagonOccupants(wagon, wagonCoords)
        + RemoveWagonObjects(wagon, wagonCoords)

    local driver = Citizen.InvokeNative(GET_DRIVER_OF_VEHICLE, wagon)
    if DoesEntityExist(driver) and not IsProtectedPed(driver)
        and DeleteAmbientEntity(driver, 'wagon driver') then
        removed = removed + 1
    end

    Citizen.InvokeNative(REMOVE_VEHICLE_LIGHT_PROP_SETS, wagon)
    Citizen.InvokeNative(REMOVE_VEHICLE_PROP_SETS, wagon)
    Citizen.InvokeNative(SET_VEHICLE_UNDRIVEABLE, wagon, true)

    if DeleteAmbientEntity(wagon, 'stuck wagon') then
        WagonLog(('removed stuck wagon and %d associated entities'):format(removed))
    end
end

local function RemoveOrphanedComponents()
    local vehicles = GetGamePool('CVehicle') or {}
    for _, object in ipairs(GetGamePool('CObject') or {}) do
        if DoesEntityExist(object) and not IsEntityAMissionEntity(object)
            and componentModels[GetEntityModel(object)] then
            local objectCoords = GetEntityCoords(object)
            local belongsToVehicle = false
            for _, vehicle in ipairs(vehicles) do
                if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle)
                    and (IsEntityAttachedToEntity(object, vehicle)
                        or #(objectCoords - GetEntityCoords(vehicle)) <= wagonConfig.componentDistance) then
                    belongsToVehicle = true
                    break
                end
            end

            if not belongsToVehicle then
                DeleteAmbientEntity(object, 'orphaned wagon component')
            end
        end
    end
end

function StartWagonFix()
    if WagonFixActive then return end
    WagonFixActive = true

    CreateThread(function()
        while WagonFixActive do
            for _, wagon in ipairs(GetGamePool('CVehicle') or {}) do
                ProcessStuckWagon(wagon)
            end
            Wait(wagonConfig.checkIntervalMs)
        end
    end)

    if wagonConfig.removeOrphanedComponents then
        CreateThread(function()
            while WagonFixActive do
                Wait(wagonConfig.orphanCheckIntervalMs)
                if WagonFixActive then RemoveOrphanedComponents() end
            end
        end)
    end
end
