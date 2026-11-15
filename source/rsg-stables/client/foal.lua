-- rsg-stables: foal growth (client)
-- Foals are scaled down and grow over real time until they reach adult size; they can't be ridden until then.
-- Rules live in shared/foal.lua (GetFoalState) and Config.FoalGrowth.
-- Natives (natives database, VORPCORE/RDR3natives):
--   _SET_PED_SCALE 0x25ACFC650B65C538 (ped, float scale), called as SetPedScale like rsg-ranch does
--   SET_PED_CONFIG_FLAG 0x1913FE4CBF41C463, flag 136 = CannotBeMounted (rsg-redm-brain ped config flags)
--   GET_MOUNT 0xE7E11B8DCBED1058, TASK_DISMOUNT_ANIMAL 0x48E92D3DDE23C23A
local RSGCore = exports['rsg-core']:GetCoreObject()

local G = Config.FoalGrowth
if not (G and G.enabled) then return end

local CANNOT_BE_MOUNTED <const> = 136
local STATE_KEY <const> = 'rsgFoalScale'

local growthToken = 0 -- bumped on every spawn / stop so old growth threads exit

local function applyScale(entity, scale)
    if entity and entity ~= 0 and DoesEntityExist(entity) and type(scale) == 'number' then
        SetPedScale(entity, math.min(math.max(scale + 0.0, 0.1), 2.0))
    end
end

-- other players' clients apply the size the owner publishes on the entity's state bag
AddStateBagChangeHandler(STATE_KEY, nil, function(bagName, _, value)
    if type(value) ~= 'number' then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity and entity ~= 0 then applyScale(entity, value) end
end)

local function publishScale(entity, scale)
    applyScale(entity, scale)
    if NetworkGetEntityIsNetworked(entity) then
        Entity(entity).state:set(STATE_KEY, scale + 0.0, true)
    end
end

--- called when an owned horse has spawned (fired from client.lua spawnHorse)
AddEventHandler('rsg-stables:client:horseSpawned', function(entity, horseRow)
    growthToken = growthToken + 1
    local token = growthToken

    local isFoal, scale = GetFoalState(horseRow)
    if not isFoal then return end

    local bornAt = GetGameTimer()
    local baseAge = tonumber(horseRow.age_seconds) or 0
    local horseName = horseRow.name

    publishScale(entity, scale)
    if G.blockRiding then SetPedConfigFlag(entity, CANNOT_BE_MOUNTED, true) end

    CreateThread(function()
        local lastUpdate = GetGameTimer()
        while token == growthToken and DoesEntityExist(entity) do
            Wait(500)
            local ped = PlayerPedId()

            -- a foal can't carry a rider: step the player off if they got on anyway
            if G.blockRiding and GetMount(ped) == entity then
                TaskDismountAnimal(ped, 0, 0, 0, 0, 0)
                RSGCore.Functions.Notify({ description = locale('foal_cannot_ride'), type = 'error' })
                SetPedConfigFlag(entity, CANNOT_BE_MOUNTED, true)
            end

            if GetGameTimer() - lastUpdate >= (G.updateInterval or 30000) then
                lastUpdate = GetGameTimer()
                local aged = baseAge + (lastUpdate - bornAt) / 1000
                local stillFoal, newScale = GetFoalState({ born = horseRow.born, age_seconds = aged })
                if stillFoal then
                    publishScale(entity, newScale)
                else
                    publishScale(entity, G.adultScale or 1.0)
                    SetPedConfigFlag(entity, CANNOT_BE_MOUNTED, false)
                    if G.notifyGrown ~= false then
                        RSGCore.Functions.Notify({ description = locale('foal_grown_up', horseName or locale('your_horse')), type = 'success' })
                    end
                    break
                end
            end
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then growthToken = growthToken + 1 end
end)
