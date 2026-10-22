local RSGCore = exports['rsg-core']:GetCoreObject()
local spawnedPeds = {}
local currentHub = nil

---------------------------------
-- contract board (NUI)
---------------------------------
local function GetItemImage(itemreward, itemData)
    if not Config.ShowRewardImages then return nil end
    if itemreward.image and itemreward.image ~= '' then
        return itemreward.image:find('://') and itemreward.image or (Config.ImagePath .. itemreward.image)
    end
    return Config.ImagePath .. (itemData and itemData.image or (itemreward.itemname .. '.png'))
end

local UI_KEYS = {
    'ui_deliveries', 'ui_choose_destination', 'ui_delivery_contract', 'ui_distance', 'ui_time_limit', 'ui_wagon',
    'ui_difficulty', 'ui_route_length', 'ui_rewards', 'ui_note', 'ui_close', 'ui_start', 'ui_no_contracts',
    'ui_cash_payment', 'ui_capped', 'ui_paid_on_arrival', 'ui_bonus_item', 'ui_guaranteed', 'ui_chance',
    'ui_no_reward', 'ui_easy', 'ui_moderate', 'ui_hard', 'ui_minutes',
}

local function BuildLang()
    local lang = {}
    for _, key in ipairs(UI_KEYS) do lang[key] = locale(key) end
    return lang
end

local function ShowDeliveryMenu(hubIndex)
    local location = Config.DeliveryLocations[hubIndex]
    local deliveries, maxDistance = {}, 0

    for i, destination in ipairs(location.deliveries) do
        local distance = GetRouteDistance(location, destination)
        maxDistance = math.max(maxDistance, distance)
        local cash, capped = CalculateCashReward(location, destination)

        local item
        local itemreward = destination.reward and destination.reward.itemreward
        if itemreward and itemreward.activation then
            local itemData = RSGCore.Shared.Items[itemreward.itemname]
            local amount = itemreward.itemamount
            item = {
                label = itemData and itemData.label or itemreward.itemname,
                amount = type(amount) == 'table' and (amount[1] .. '-' .. amount[2]) or tostring(amount or 1),
                chance = itemreward.chance,
                image = GetItemImage(itemreward, itemData),
            }
        end

        deliveries[#deliveries + 1] = {
            index = i,
            label = destination.label,
            description = destination.description,
            distance = distance,
            wagon = Config.WagonLabels[destination.wagonModel] or destination.wagonModel,
            cash = cash,
            capped = capped,
            item = item,
        }
    end

    currentHub = hubIndex
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        hub = location.label,
        deliveries = deliveries,
        config = { timeLimit = Config.DefaultDeliveryTime, maxDistance = maxDistance },
        lang = BuildLang(),
    })
end

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    currentHub = nil
    cb('ok')
end)

RegisterNUICallback('start', function(data, cb)
    SetNuiFocus(false, false)
    local hubIndex = currentHub
    currentHub = nil
    cb('ok')
    local destIndex = data and tonumber(data.index)
    if hubIndex and destIndex then StartDelivery(hubIndex, destIndex) end
end)

---------------------------------
-- foreman NPCs
---------------------------------
local function FadePed(ped, from, to)
    if not Config.FadeIn then return end
    local step = from < to and Config.FadeIncrement or -Config.FadeIncrement
    for alpha = from, to, step do
        SetEntityAlpha(ped, alpha, false)
        Wait(50)
    end
end

local function SpawnForeman(hubIndex, location)
    local coords = location.npccoords
    local modelHash = joaat(location.npcmodel)
    if not pcall(lib.requestModel, modelHash, 5000) then
        print(('^1[%s] Failed to load NPC model: %s^7'):format(GetCurrentResourceName(), location.npcmodel))
        return nil
    end

    local ped = CreatePed(modelHash, coords.x, coords.y, coords.z - 1.0, coords.w, false, false, 0, 0)
    SetModelAsNoLongerNeeded(modelHash)
    if not ped or ped == 0 then return nil end

    SetEntityAlpha(ped, Config.FadeIn and 0 or 255, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_CLIPBOARD'), 0, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'delivery_npc_' .. hubIndex,
            label = locale('talk_to_foreman'),
            icon = 'fa-solid fa-box',
            distance = Config.InteractionDistance,
            onSelect = function() ShowDeliveryMenu(hubIndex) end,
        }
    })

    FadePed(ped, 0, 255)
    return ped
end

local function DespawnForeman(hubIndex)
    local ped = spawnedPeds[hubIndex]
    spawnedPeds[hubIndex] = nil
    if not ped or not DoesEntityExist(ped) then return end
    FadePed(ped, 255, 0)
    DeletePed(ped)
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(cache.ped)
        for k, location in ipairs(Config.DeliveryLocations) do
            local near = #(playerCoords - location.npccoords.xyz) < Config.DistanceSpawn
            if near and not spawnedPeds[k] then
                spawnedPeds[k] = SpawnForeman(k, location)
            elseif not near and spawnedPeds[k] then
                DespawnForeman(k)
            end
        end
        Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SetNuiFocus(false, false)
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
end)
