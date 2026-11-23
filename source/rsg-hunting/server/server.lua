local RSGCore = exports['rsg-core']:GetCoreObject()
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
RegisterNetEvent('rsg-hunting:server:giverewards', function(netId, quality)
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

    local model = GetEntityModel(carcass)
    local animal = AnimalByModel[model]
    if not animal or not animal.skinable then return end

    -- quality is read by the client: only known values count, and only when it is trusted
    if quality ~= 'poor' and quality ~= 'good' and quality ~= 'perfect' then quality = nil end
    if not Config.TrustClientQuality then quality = nil end

    -- skill gate: dangerous animals need the hunting level (the skinning already happened, so nothing is paid)
    local allowed, why, need = HuntingGates.Check(src, model)
    if not allowed then
        SkinnedCarcasses[netId] = os.time()
        return HuntingGates.Notify(src, why, need)
    end

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
            TriggerClientEvent('RSGCore:Client:Notify', src, {
                title = locale('inventory_full'),
                type = 'error',
                duration = 8000
            })
            return
        end
    end

    -- good / perfect carcasses give items that remember it (trappers pay more); poor ones stay plain
    local pelt = Config.PeltQuality and Config.PeltQuality.Enabled and (quality == 'good' or quality == 'perfect') and quality or nil
    for _, itemName in ipairs(toGive) do
        exports['rsg-inventory']:AddItem(src, itemName, 1, pelt and { pelt = pelt } or nil, nil, 'rsg-hunting-skinning')
    end

    -- perk: chance of a second main reward
    local chance = HuntingXP.GetPerks(src).extraSkinChance or 0
    if Config.Skills and Config.Skills.ExtraYield then chance = chance + SkillPerk(src, 'extra_yield') end -- rsg-skills perk
    local bonusItem = toGive[1]
    if chance > 0 and math.random(100) <= chance and exports['rsg-inventory']:CanAddItem(src, bonusItem, 1) then
        exports['rsg-inventory']:AddItem(src, bonusItem, 1, pelt and { pelt = pelt } or nil, nil, 'rsg-hunting-skinning-perk')
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('hunting_xp_title'), description = locale('hunting_perk_extraskin'), type = 'inform' })
    end

    local region = HuntingBounty.RegionAt(GetEntityCoords(GetPlayerPed(src)))
    local xp = HuntingXP.GetAnimalXP(model) * HuntingBounty.XPMultiplier(model, region)
    -- clean kill: perfect pelt quality is read by the client (the server can't),
    -- so it only ever adds a capped xp bonus, never items or cash
    local cleanMult = Config.HuntingXP.CleanKillMultiplier or 1
    if quality == 'perfect' and cleanMult > 1 then
        xp = xp * math.min(cleanMult, 3)
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('hunting_xp_title'), description = locale('hunting_clean_kill'), type = 'inform' })
    end
    xp = math.floor(xp)
    HuntingXP.Award(src, xp)

    -- trophy: a perfect skin of a listed animal can give a trophy item
    local trophy = Config.Trophies
    if trophy and trophy.Enabled and quality == 'perfect' and trophy.Animals[model] and RSGCore.Shared.Items[trophy.Item]
        and math.random(100) <= (trophy.Chance or 100) and exports['rsg-inventory']:CanAddItem(src, trophy.Item, 1) then
        exports['rsg-inventory']:AddItem(src, trophy.Item, 1, { animal = HuntingJournal.Name(model) }, nil, 'rsg-hunting-trophy')
        TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('hunting_xp_title'), description = locale('trophy_awarded', HuntingJournal.Name(model)), type = 'success', duration = 7000 })
    end

    HuntingJournal.RecordSkin(src, model, quality)
    HuntingContracts.OnSkin(src, model, quality)

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
