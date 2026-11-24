local RSGCore = exports['rsg-core']:GetCoreObject()

local ELIGIBILITY_WINDOW = 5 * 60 * 1000 -- ms a spent bait stays valid for one minigame catch

local validBaits = {}
for i = 1, #Config.Baits do validBaits[Config.Baits[i]] = true end

-- model hash -> { item = 'a_c_fish...', label = 'Display name', minRaw, maxRaw = accepted raw weight range }
local fishByModel = {}
for model, data in pairs(Config.fishData) do
    local band = Config.WeightBands[data[2]] or Config.WeightBands.small
    fishByModel[joaat(model)] = {
        item   = model:lower(),
        label  = data[1],
        family = data[3],
        legendary = RegionSets.legendaryFamily[data[3]] == true,
        minRaw = band[1] * Config.WeightFactor / Config.FishWeightMultiplier * 0.95,
        maxRaw = band[2] * Config.WeightFactor / Config.FishWeightMultiplier * 1.05,
    }
end

-- bait -> set of fish model hashes it can catch (Config.EnforceBaitList)
local baitFish = {}
for bait, list in pairs(Config.BaitsPerFish) do
    local set = {}
    for i = 1, #list do set[joaat(list[i])] = true end
    baitFish[bait] = set
end

-- rsg-skills: award fishing XP (optional dependency)
local function awardSkillXP(src, amount, reason)
    if not Config.Skills.Enabled or amount <= 0 then return end
    if GetResourceState('rsg-skills') ~= 'started' then return end
    exports['rsg-skills']:AddXP(src, Config.Skills.Skill, amount, reason)
end

local FishingEligible = {} -- [src] = { expires, since, bait } of the last bait put on the rod
local LastCatch = {}       -- [src] = time of the last accepted catch
local GroundPickups = {}   -- [src] = { count, resetAt } ground pickups in the current window

local function reject(src, why)
    if Config.Debug then print(('[rsg-fishing] rejected catch from %s: %s'):format(src, why)) end
end

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

    if not exports['rsg-inventory']:RemoveItem(src, item, 1, nil, 'rsg-fishing:bait') then return end
    -- RemoveItem fires the ItemBox itself

    local now = GetGameTimer()
    FishingEligible[src] = { expires = now + ELIGIBILITY_WINDOW, since = now, bait = item }
end)

--[[
    Store a caught fish.
    Client-triggerable, so: whitelisted model, clamped weight, a minigame catch needs a
    bait spent in the last few minutes (one catch per bait), and catches are rate-limited.
    weight == 0 means a fish picked up off the ground (Config.GroundPickup).
]]
RegisterNetEvent('rsg-fishing:server:catchFish', function(fishModel, weight, region, spot)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local fish = fishByModel[fishModel]
    if not fish or type(weight) ~= 'number' or weight ~= weight then return reject(src, 'bad arguments') end

    if type(region) ~= 'string' or not RegionSets.valid[region] then region = nil end
    if type(spot) ~= 'string' then spot = nil end

    local now = GetGameTimer()
    if LastCatch[src] and now - LastCatch[src] < Config.CatchCooldown then return reject(src, 'cooldown') end

    local pickup
    if weight > 0 then
        local e = FishingEligible[src]
        if not e or now > e.expires then return reject(src, 'no bait spent') end
        if now - e.since < Config.MinCatchTime then return reject(src, 'caught too fast') end
        if Config.EnforceBaitList and not (baitFish[e.bait] and baitFish[e.bait][fishModel]) then
            return reject(src, 'fish not attracted by ' .. tostring(e.bait))
        end
        if Config.Regions.Enabled then
            -- the region comes from the client, so this only stops fish that cannot live there (the legendary one is also checked by position when the spot has coords)
            local pool = region and RegionSets.pools[region]
            if pool and not pool[fish.family] then return reject(src, 'fish not found in ' .. region) end
            if fish.legendary then
                local zone = spot and RegionSets.legendary[spot]
                if not zone then return reject(src, 'legendary fish away from its spots') end
                if zone.coords and #(GetEntityCoords(GetPlayerPed(src)) - zone.coords) > (zone.radius or 150.0) then
                    return reject(src, 'legendary fish too far from ' .. spot)
                end
            end
        end
        weight = math.max(fish.minRaw, math.min(weight, fish.maxRaw, Config.MaxRawFishWeight))
        pickup = false
    else
        if weight ~= 0 or not Config.GroundPickup then return reject(src, 'bad weight') end
        if fish.legendary then return reject(src, 'legendary fish cannot be picked up') end
        local g = GroundPickups[src]
        if not g or now > g.resetAt then
            g = { count = 0, resetAt = now + Config.GroundPickupLimit.Window * 1000 }
            GroundPickups[src] = g
        end
        if g.count >= Config.GroundPickupLimit.Max then return reject(src, 'ground pickup limit') end
        weight, pickup = 0, true
    end

    if not exports['rsg-inventory']:CanAddItem(src, fish.item, 1) then
        notify(src, locale('sv_inventory_full'), 'error')
        return
    end

    if not exports['rsg-inventory']:AddItem(src, fish.item, 1, { weight = string.format('%.2f', weight * Config.FishWeightMultiplier) }, nil, 'rsg-fishing:catch') then return end
    -- AddItem fires the ItemBox itself

    -- only spend the bait ticket / pickup allowance once the fish was really stored
    LastCatch[src] = now
    if pickup then GroundPickups[src].count = GroundPickups[src].count + 1 else FishingEligible[src] = nil end
    local kg = string.format('%.2f', weight * Config.FishWeightMultiplier)

    notify(src, locale('sv_you_got_fish_name') .. ' ' .. fish.label, 'success')

    -- journal, server records and reputation (fished fish only)
    if not pickup then Journal.OnCatch(src, Player, fish.family, tonumber(kg), region) end

    -- ground pickups are not fished, so they earn no XP
    if not pickup then awardSkillXP(src, Config.Skills.CatchXP, 'fishing catch') end

    if Config.Log then
        local ci = Player.PlayerData.charinfo
        TriggerEvent('rsg-log:server:CreateLog', 'fishing', locale('sv_discord_b'), 'green',
            ('%s %s (%s) %s %sKG %s'):format(ci.firstname, ci.lastname, Player.PlayerData.citizenid, locale('sv_discord_c'), kg, fish.label))
    end
end)

AddEventHandler('playerDropped', function()
    FishingEligible[source] = nil
    LastCatch[source] = nil
    GroundPickups[source] = nil
end)
