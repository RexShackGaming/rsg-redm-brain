local RSGCore = exports['rsg-core']:GetCoreObject()

BP = BP or {}

-- Shared helper: request a model (hash) with timeout. Returns true when loaded.
function BP.LoadModel(model, timeout)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end

    RequestModel(model)
    local limit = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(model) do
        if GetGameTimer() > limit then return false end
        Wait(10)
    end
    return true
end

local worn = nil -- { cfg = <backpack config>, serial = string, entity = entity, ped = ped }

---------------------------------------------
-- PROP
---------------------------------------------
local function RemoveBackpackProp()
    if worn and worn.entity and DoesEntityExist(worn.entity) then
        SetEntityAsMissionEntity(worn.entity, true, true)
        DeleteEntity(worn.entity)
    end
    worn = nil
end

local function EquipBackpackProp(cfg, serial)
    local ped = PlayerPedId()
    local model = joaat(cfg.model)

    if not BP.LoadModel(model) then return false end

    local coords = GetEntityCoords(ped)
    local entity = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(model)

    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    local bone = GetEntityBoneIndexByName(ped, 'CP_Back')
    AttachEntityToEntity(entity, ped, bone,
        cfg.position.x, cfg.position.y, cfg.position.z,
        cfg.rotation.x, cfg.rotation.y, cfg.rotation.z,
        false, false, false, false, 2, true) -- hard pinned, no collision

    worn = { cfg = cfg, serial = serial, entity = entity, ped = ped }
    return true
end

local function HoldsSerial(serial)
    local items = (RSGCore.Functions.GetPlayerData() or {}).items or {}
    for _, it in pairs(items) do
        if it and type(it.info) == 'table' and it.info.serie == serial then
            return true
        end
    end
    return false
end

---------------------------------------------
-- EVENTS
---------------------------------------------
-- Server validated the item / serial and opens the stash itself. The client only wears the prop
-- (put on, or swapped if another backpack is worn). Taking it off is done with /removebackpack.
RegisterNetEvent('rsg-backpacks:client:wear', function(itemName, serial)
    if type(itemName) ~= 'string' or type(serial) ~= 'string' then return end

    local cfg = Config.backpackByItem[itemName]
    if not cfg then
        lib.notify({
            title = locale('error_title'),
            description = locale('backpack_config_missing'),
            type = 'error',
            duration = 5000,
        })
        return
    end

    if worn and worn.serial == serial then return end
    if worn then RemoveBackpackProp() end
    EquipBackpackProp(cfg, serial)
end)

-- take the worn backpack off
RegisterCommand('removebackpack', function()
    if not worn then
        lib.notify({ title = locale('backpack_title'), description = locale('backpack_not_worn'), type = 'error', duration = 4000 })
        return
    end
    RemoveBackpackProp()
    lib.notify({ title = locale('backpack_title'), description = locale('backpack_taken_off'), type = 'inform', duration = 4000 })
end, false)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/removebackpack', locale('cmd_remove_help'))
end)

-- skin refresh recreates the ped: force the monitor thread to re-attach the prop
RegisterNetEvent('rsg:client:refreshSkin', function()
    if worn then worn.ped = 0 end
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    RemoveBackpackProp()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    RemoveBackpackProp()
end)

---------------------------------------------
-- MONITOR: ped changes / item lost
---------------------------------------------
CreateThread(function()
    local misses = 0

    while true do
        Wait(2500)

        if worn then
            local ped = PlayerPedId()

            if ped ~= worn.ped or not DoesEntityExist(worn.entity) then
                -- ped was recreated (skin refresh / respawn) or the prop vanished: re-attach
                local cfg, serial = worn.cfg, worn.serial
                RemoveBackpackProp()
                if not EquipBackpackProp(cfg, serial) then
                    worn = { cfg = cfg, serial = serial, entity = 0, ped = 0 } -- retry next tick
                end
                misses = 0
            else
                -- detect that THIS backpack (by serial) is gone: dropped, stolen, given away
                if not HoldsSerial(worn.serial) then
                    misses = misses + 1
                    if misses >= 2 then
                        RemoveBackpackProp()
                        misses = 0
                        lib.notify({
                            title = locale('backpack_title'),
                            description = locale('backpack_lost'),
                            type = 'warning',
                            duration = 5000,
                        })
                    end
                else
                    misses = 0
                end
            end
        else
            misses = 0
        end
    end
end)
