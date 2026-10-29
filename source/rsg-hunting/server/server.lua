local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

------------------------------------------
-- server-side animal lookup: rewards come from the carcass model the
-- SERVER sees, never from a list the client sends
------------------------------------------
local AnimalByModel = {}

for _, animal in ipairs(Config.Animals) do
    AnimalByModel[animal.modelhash] = animal
end

------------------------------------------
-- anti-spam + one payout per carcass
------------------------------------------
local PlayerCooldowns = {}
local SkinnedCarcasses = {} -- [netId] = os.time() it was paid out
local REWARD_COOLDOWN = Config.ServerCooldown or 2000
local MAX_SKIN_DISTANCE = 6.0

local function isOnCooldown(src)
    local now = GetGameTimer()
    local last = PlayerCooldowns[src]
    if last and (now - last) < REWARD_COOLDOWN then
        return true
    end
    PlayerCooldowns[src] = now
    return false
end

-- forget old carcass ids so recycled net ids work again later
CreateThread(function()
    while true do
        Wait(300000)
        local now = os.time()
        for id, t in pairs(SkinnedCarcasses) do
            if now - t > 1800 then SkinnedCarcasses[id] = nil end
        end
    end
end)

local function suspicious(src, why, alert)
    print(('[rsg-hunting] giverewards rejected for %s (%s): %s'):format(GetPlayerName(src) or src, src, why))
    if alert ~= false then HuntingWebhook.Security(src, locale('wh_where_skinning'), why) end
end

------------------------------------------
-- give rewards (client sends only the skinned carcass's network id)
------------------------------------------
RegisterNetEvent('rsg-hunting:server:giverewards', function(netId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    netId = math.tointeger(tonumber(netId))
    if not netId or netId <= 0 then return suspicious(src, locale('reason_no_netid'), false) end
    if isOnCooldown(src) then return end
    if SkinnedCarcasses[netId] then return suspicious(src, locale('reason_already_skinned')) end

    local carcass = NetworkGetEntityFromNetworkId(netId)
    if not carcass or carcass == 0 or not DoesEntityExist(carcass) or GetEntityType(carcass) ~= 1 then
        return suspicious(src, locale('reason_no_carcass'), false)
    end
    if IsPedAPlayer(carcass) then return suspicious(src, locale('reason_skin_player')) end
    if GetEntityHealth(carcass) > 0 then return suspicious(src, locale('reason_alive')) end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(carcass))
    if dist > MAX_SKIN_DISTANCE then return suspicious(src, locale('reason_too_far', ('%.1f'):format(dist))) end

    local animal = AnimalByModel[GetEntityModel(carcass)]
    if not animal or not animal.skinable then return end

    -- claim the carcass before giving anything
    SkinnedCarcasses[netId] = os.time()

    local toGive = {}
    for i = 1, 5 do
        local itemName = animal['rewarditem' .. i]
        if itemName and RSGCore.Shared.Items[itemName] then
            toGive[#toGive + 1] = itemName
        end
    end
    if #toGive == 0 then return end

    for _, itemName in ipairs(toGive) do
        if not exports['rsg-inventory']:CanAddItem(src, itemName, 1) then
            SkinnedCarcasses[netId] = nil -- let them try again once they have space
            TriggerClientEvent('ox_lib:notify', src, {
                title = locale('inventory_full'),
                type = 'error',
                duration = 8000
            })
            return
        end
    end

    for _, itemName in ipairs(toGive) do
        exports['rsg-inventory']:AddItem(src, itemName, 1, nil, nil, 'rsg-hunting-skinning')
    end

    -- perk: chance of a second main reward
    local chance = HuntingXP.GetPerks(src).extraSkinChance or 0
    local bonusItem = toGive[1]
    if chance > 0 and math.random(100) <= chance and exports['rsg-inventory']:CanAddItem(src, bonusItem, 1) then
        exports['rsg-inventory']:AddItem(src, bonusItem, 1, nil, nil, 'rsg-hunting-skinning-perk')
        TriggerClientEvent('ox_lib:notify', src, { title = locale('hunting_xp_title'), description = locale('hunting_perk_extraskin'), type = 'inform' })
    end

    local model = GetEntityModel(carcass)
    local xp = HuntingXP.GetAnimalXP(model)
    HuntingXP.Award(src, xp)

    local labels = {}
    for _, itemName in ipairs(toGive) do labels[#labels + 1] = RSGCore.Shared.Items[itemName].label or itemName end
    HuntingWebhook.Skin(src, RSGCore.Shared.Items[toGive[1]].label or ('model ' .. model), labels, xp)
end)

--------------------------------------
-- cleanup on player disconnect
--------------------------------------
AddEventHandler('playerDropped', function()
    PlayerCooldowns[source] = nil
end)
