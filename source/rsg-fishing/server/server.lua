local RSGCore = exports['rsg-core']:GetCoreObject()

local ELIGIBILITY_WINDOW = 5 * 60 * 1000 -- ms a spent bait stays valid for one minigame catch

local validBaits = {}
for i = 1, #Config.Baits do validBaits[Config.Baits[i]] = true end

-- model hash -> { item = 'a_c_fish...', label = 'Display name' }
local fishByModel = {}
for model, data in pairs(Config.fishData) do
    fishByModel[joaat(model)] = { item = model:lower(), label = data[1] }
end

local FishingEligible = {} -- [src] = expiry time of the last spent bait
local LastCatch = {}       -- [src] = time of the last accepted catch

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('cl_fishing'), description = desc, type = ntype, duration = 5000 })
end

for i = 1, #Config.Baits do
    RSGCore.Functions.CreateUseableItem(Config.Baits[i], function(source, item)
        if not RSGCore.Functions.GetPlayer(source) then return end
        TriggerClientEvent('rsg-fishing:client:usebait', source, item.name)
    end)
end

-- bait put on the rod
RegisterNetEvent('rsg-fishing:server:removeBaitItem', function(item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(item) ~= 'string' or not validBaits[item] then return end

    if not Player.Functions.RemoveItem(item, 1, nil, 'rsg-fishing:bait') then return end
    -- RemoveItem fires the ItemBox itself

    FishingEligible[src] = GetGameTimer() + ELIGIBILITY_WINDOW
end)

--[[
    Store a caught fish.
    Client-triggerable, so: whitelisted model, clamped weight, a minigame catch needs a
    bait spent in the last few minutes (one catch per bait), and catches are rate-limited.
    weight == 0 means a fish picked up off the ground (Config.GroundPickup).
]]
RegisterNetEvent('rsg-fishing:server:catchFish', function(fishModel, weight)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local fish = fishByModel[fishModel]
    if not fish or type(weight) ~= 'number' or weight ~= weight then return end

    local now = GetGameTimer()
    if LastCatch[src] and now - LastCatch[src] < Config.CatchCooldown then return end

    if weight > 0 then
        local eligibleUntil = FishingEligible[src]
        if not eligibleUntil or now > eligibleUntil then return end
        FishingEligible[src] = nil
        weight = math.min(weight, Config.MaxRawFishWeight)
    else
        if not Config.GroundPickup then return end
        weight = 0
    end

    if not exports['rsg-inventory']:CanAddItem(src, fish.item, 1) then
        notify(src, locale('sv_inventory_full'), 'error')
        return
    end

    LastCatch[src] = now
    local kg = string.format('%.2f', weight * Config.FishWeightMultiplier)

    if not Player.Functions.AddItem(fish.item, 1, nil, { weight = kg }, 'rsg-fishing:catch') then return end
    -- AddItem fires the ItemBox itself

    notify(src, locale('sv_you_got_fish_name') .. ' ' .. fish.label, 'success')

    if Config.Log then
        local ci = Player.PlayerData.charinfo
        TriggerEvent('rsg-log:server:CreateLog', 'fishing', locale('sv_discord_b'), 'green',
            ('%s %s (%s) %s %sKG %s'):format(ci.firstname, ci.lastname, Player.PlayerData.citizenid, locale('sv_discord_c'), kg, fish.label))
    end
end)

AddEventHandler('playerDropped', function()
    FishingEligible[source] = nil
    LastCatch[source] = nil
end)
