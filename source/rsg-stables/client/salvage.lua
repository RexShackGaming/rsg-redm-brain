-- ===================== FIELD SALVAGE =====================
-- After an uninsured horse dies in the world the server deletes the networked entity (anti-exploit),
-- so a local, non-networked body is placed where it fell for Config.HorseSalvage.duration seconds.
-- Searching it opens the horse's saddlebag stash (server re-checks distance and timer).
-- Interaction_LootSaddleBags: rdr3_discoveries tasks/TASK_ANIMAL_INTERACTION. Outfit native
-- 0x77FF8D35EEC6BBC4 (_EQUIP_META_PED_OUTFIT_PRESET) as used in client.lua.
local RSGCore = exports['rsg-core']:GetCoreObject()

local S = Config.HorseSalvage
if not (S and S.enabled) then return end

local corpse = nil -- { ped, horseId, expires }

local function clearCorpse()
    if corpse and DoesEntityExist(corpse.ped) then
        exports['rsg-target']:removeLocalEntity(corpse.ped, { 'rsg_stables_salvage' })
        DeleteEntity(corpse.ped)
    end
    corpse = nil
end

RegisterNetEvent('rsg-stables:client:fieldCorpse', function(data)
    if type(data) ~= 'table' or not data.coords then return end
    clearCorpse()
    local model = math.floor(tonumber(data.model) or 0)
    if not IsModelValid(model) then return end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(50) end
    if not HasModelLoaded(model) then return end

    local c = data.coords
    local ped = CreatePed(model, c.x, c.y, c.z, data.heading or 0.0, false, false, 0, 0)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, math.floor(tonumber(data.outfit) or 0), true)
    PlaceEntityOnGroundProperly(ped)
    SetEntityHealth(ped, 0)
    SetBlockingOfNonTemporaryEvents(ped, true)

    corpse = { ped = ped, horseId = data.horseId, expires = GetGameTimer() + (tonumber(data.duration) or S.duration) * 1000 }
    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = 'rsg_stables_salvage',
            icon = 'fas fa-box-open',
            label = locale('salvage_target', data.name or locale('your_horse')),
            distance = S.distance or 3.0,
            onSelect = function()
                if not corpse then return end
                TaskAnimalInteraction(PlayerPedId(), corpse.ped, joaat('Interaction_LootSaddleBags'), 0, 0)
                Wait(1500)
                TriggerServerEvent('rsg-stables:server:openFieldSaddlebags', corpse.horseId)
            end,
        },
    })
    RSGCore.Functions.Notify({ description = locale('salvage_available', math.floor(((tonumber(data.duration) or S.duration)) / 60)), type = 'inform', duration = 8000 })
end)

CreateThread(function()
    while true do
        Wait(5000)
        if corpse and GetGameTimer() > corpse.expires then clearCorpse() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearCorpse() end
end)
