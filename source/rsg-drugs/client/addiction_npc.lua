-- NPC addicts (client-side, visual only).
-- Ambient peds become weed addicts when a player sells them a weed_bag; their craving grows
-- over time and they stagger, brace against walls in withdrawal, and periodically feed their habit.
if not Config.Addiction.NPC.Enabled then return end
lib.locale()

local RSGCore = exports['rsg-core']:GetCoreObject()
local addicts = {}   -- [ped] = { key = 'weed', craving = 0-100, busyUntil = ms }
local tried = {}     -- [ped] = true, NPCs that already bought or refused (can't be asked again)

local function setDrunk(ped, level)
    Citizen.InvokeNative(0x406CCF555B04FAD3, ped, level > 0.0, level) -- _SET_PED_DRUNKNESS (natives/db/PED.md)
end

local function count()
    local n = 0
    for _ in pairs(addicts) do n = n + 1 end
    return n
end

local function release(ped)
    if DoesEntityExist(ped) then setDrunk(ped, 0.0) end
    addicts[ped] = nil
end

local function netIdOf(ped)
    return NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or 0
end

-- hooked = tracked locally (this client sold to it) or flagged by the server (anyone sold to it)
local function isAddictPed(ped)
    return addicts[ped] ~= nil or Entity(ped).state.rsgAddict ~= nil
end

local function playScenario(ped, name, duration)
    ClearPedTasks(ped)
    TaskStartScenarioInPlaceHash(ped, joaat(name), duration, true, 0, -1.0, false)
end

-- ambient human townsfolk only (excludes animals, players, script/shop NPCs, riders and the dead)
local function isAmbient(ped)
    return DoesEntityExist(ped) and not IsPedAPlayer(ped)
        and IsPedHuman(ped) and not Citizen.InvokeNative(0x9A100F1CF4546629, ped) -- GET_IS_ANIMAL
        and not IsEntityDead(ped) and not IsEntityAMissionEntity(ped) and not IsPedInAnyVehicle(ped, false)
        and not IsPedOnMount(ped)
end

-- NPCs only become addicted when sold a weed_bag.
-- Call from your selling code (client side) after a successful sale:
--   exports['rsg-drugs']:NpcSoldWeedBag(ped)
--   or TriggerEvent('rsg-drugs:client:npcSoldWeedBag', ped)
-- hooked: true/false from the server when it decided, nil = roll locally (export / non-networked ped)
local function soldWeedBag(ped, hooked)
    if not ped or not isAmbient(ped) then return false end
    if addicts[ped] then
        addicts[ped].craving = 0 -- just fed
        return true
    end
    if count() >= Config.Addiction.NPC.MaxTracked then return false end
    if hooked == false then return false end
    if hooked == nil and math.random(100) > (Config.Addiction.NPC.SaleChance or 100) then return false end
    addicts[ped] = { key = 'weed', craving = 0, busyUntil = 0 }
    return true
end
exports('NpcSoldWeedBag', soldWeedBag)
AddEventHandler('rsg-drugs:client:npcSoldWeedBag', function(ped) soldWeedBag(ped) end)

CreateThread(function()
    while true do
        Wait(Config.Addiction.NPC.ScanInterval)
        local myPos = GetEntityCoords(cache.ped)
        local now = GetGameTimer()

        -- forget invalid / far peds
        for ped in pairs(addicts) do
            if not DoesEntityExist(ped) or IsEntityDead(ped) or #(GetEntityCoords(ped) - myPos) > Config.Addiction.NPC.ScanRadius * 2 then
                release(ped)
            end
        end
        for ped in pairs(tried) do
            if not DoesEntityExist(ped) then tried[ped] = nil end
        end

        -- behaviour
        for ped, a in pairs(addicts) do
            if now >= a.busyUntil then
                a.craving = math.min(100, a.craving + Config.Addiction.NPC.CravingRate)
                if a.craving >= 60 and math.random(100) <= Config.Addiction.NPC.FeedChance then
                    -- feed the habit
                    playScenario(ped, Config.Addiction.NPC.Scenarios[a.key] or Config.Addiction.NPC.Scenarios.alcohol, Config.Addiction.NPC.FeedTime)
                    a.busyUntil = now + Config.Addiction.NPC.FeedTime
                    a.craving = 0
                    setDrunk(ped, a.key == 'alcohol' and 0.6 or 0.2)
                elseif a.craving >= 90 then
                    -- severe withdrawal
                    setDrunk(ped, 0.9)
                    if math.random(100) <= 40 then
                        playScenario(ped, Config.Addiction.NPC.Scenarios.withdrawal, 8000)
                        a.busyUntil = now + 8000
                    else
                        SetPedToRagdoll(ped, 1000, 2000, 0, false, false, false)
                    end
                elseif a.craving >= 60 then
                    setDrunk(ped, 0.5)
                elseif a.craving >= 30 then
                    setDrunk(ped, 0.25)
                else
                    setDrunk(ped, 0.0)
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- ox_target: inspect / send to rehab (lawmen & medics)
---------------------------------------------------------------------
-- keep a live copy of the job (rsg-multijob switches/removals fire OnJobUpdate)
local myJob = RSGCore.Functions.GetPlayerData().job
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() myJob = RSGCore.Functions.GetPlayerData().job end)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() myJob = nil end)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(job) myJob = job end)
RegisterNetEvent('RSGCore:Client:SetDuty', function(onDuty) if myJob then myJob.onduty = onDuty end end)
RegisterNetEvent('RSGCore:Player:SetPlayerData', function(data) if data and data.job then myJob = data.job end end)

-- lawmen / medics only, and only while on duty (same rule the server uses)
local function canAdmit()
    local job = myJob
    if not job or job.onduty == false then return false end
    return (Config.Addiction.Rehab.AllowedJobTypes[job.type] or Config.Addiction.Rehab.AllowedJobs[job.name]) and true or false
end

exports.ox_target:addGlobalPed({
    {
        name = 'rsg_addiction_npc_inspect',
        icon = 'fa-solid fa-eye',
        label = locale('npc_inspect'),
        distance = 2.5,
        canInteract = function(entity) return canAdmit() and isAmbient(entity) end,
        onSelect = function(data)
            local key = addicts[data.entity] and addicts[data.entity].key or Entity(data.entity).state.rsgAddict
            if key and Config.Addiction.Substances[key] then
                lib.notify({ title = locale('addiction_title'), description = locale('npc_addict', Config.Addiction.Substances[key].label), type = 'warning' })
            else
                lib.notify({ title = locale('addiction_title'), description = locale('npc_clean'), type = 'inform' })
            end
        end,
    },
    {
        name = 'rsg_addiction_npc_rehab',
        icon = 'fa-solid fa-hand-holding-medical',
        label = locale('npc_rehab'),
        distance = 2.5,
        canInteract = function(entity) return canAdmit() and isAmbient(entity) and isAddictPed(entity) end,
        onSelect = function(data)
            local ped = data.entity
            TriggerServerEvent('rsg-drugs:server:npcRehab', netIdOf(ped))
            release(ped)
            ClearPedTasks(ped)
            TaskWanderStandard(ped, 1.0, 0)
            lib.notify({ title = locale('addiction_title'), description = locale('npc_sent'), type = 'success' })
        end,
    },
})

---------------------------------------------------------------------
-- ox_target: sell weed bag
---------------------------------------------------------------------
local alertBlips = {}

-- canInteract runs every frame per ped, so cache the inventory lookup for a second
local sellItemCache, sellItemAt = false, 0
local function hasSellItem()
    local now = GetGameTimer()
    if now - sellItemAt > 1000 then
        sellItemAt = now
        sellItemCache = exports['rsg-inventory']:HasItem(Config.Addiction.Selling.Item, 1) and true or false
    end
    return sellItemCache
end

local selling = false

exports.ox_target:addGlobalPed({
    {
        name = 'rsg_addiction_npc_sell',
        icon = 'fa-solid fa-cannabis',
        label = locale('sell_weed'),
        distance = 2.0,
        canInteract = function(entity)
            return not selling and not tried[entity] and isAmbient(entity) and hasSellItem()
        end,
        onSelect = function(data)
            local ped = data.entity
            selling = true
            local result, hooked = lib.callback.await('rsg-drugs:server:sellWeedBag', false, netIdOf(ped))
            -- one sale per NPC; addicts come back for more (server enforces the rebuy cooldown)
            if result == 'done' or (result == 'sold' and not hooked) then tried[ped] = true end
            if result == 'sold' then
                DrugsHandover(ped)
                soldWeedBag(ped, hooked)
                local a = addicts[ped]
                if a then
                    playScenario(ped, Config.Addiction.NPC.Scenarios.weed, Config.Addiction.NPC.FeedTime)
                    a.busyUntil = GetGameTimer() + Config.Addiction.NPC.FeedTime
                end
            elseif result == 'refused' then
                tried[ped] = true
                ClearPedTasks(ped)
                TaskSmartFleePed(ped, cache.ped, 50.0, 10000, 0, 0, 0)
            end
            sellItemAt = 0 -- re-check stock after a sale
            selling = false
        end,
    },
})

RegisterNetEvent('rsg-drugs:client:sellAlert', function(coords)
    local S = Config.Addiction.Selling
    local blip = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, coords.x, coords.y, coords.z, S.AlertRadius) -- BlipAddForRadius
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, joaat('BLIP_MODIFIER_AREA_PULSE'))  -- BlipAddModifier
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, locale('sell_hotspot'))            -- SetBlipName
    alertBlips[blip] = true
    lib.notify({ title = locale('sell_alert_title'), description = locale('sell_alert'), type = 'warning', duration = 8000 })
    SetTimeout(S.AlertDuration * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        alertBlips[blip] = nil
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for ped in pairs(addicts) do release(ped) end
    for b in pairs(alertBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    exports.ox_target:removeGlobalPed({ 'rsg_addiction_npc_inspect', 'rsg_addiction_npc_rehab', 'rsg_addiction_npc_sell' })
end)
