-- rsg-reputation: read-only mirror of the player's reputation (the server owns every change)
local RSGCore = exports['rsg-core']:GetCoreObject()

local mirror = { honor = Config.Honor.Start, standing = {} }

local function sortedTiers(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    table.sort(out, function(a, b) return a.min < b.min end)
    return out
end

local HonorTiers = sortedTiers(Config.Honor.Tiers)
local StandingTiers = sortedTiers(Config.Standing.Tiers)

local function tierOf(tiers, value)
    local idx = 1
    for i = 1, #tiers do
        if value >= tiers[i].min then idx = i end
    end
    local t = tiers[idx]
    return {
        index = idx, label = locale(t.label), priceModifier = t.priceModifier or 0.0, hostile = t.hostile == true,
    }
end

RegisterNetEvent('rsg-reputation:client:sync', function(data)
    if type(data) ~= 'table' then return end
    mirror.honor = tonumber(data.honor) or mirror.honor
    mirror.standing = type(data.standing) == 'table' and data.standing or {}
    TriggerEvent('rsg-reputation:client:changed', mirror.honor)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    mirror = { honor = Config.Honor.Start, standing = {} }
    RSGCore.Functions.TriggerCallback('rsg-reputation:server:requestSync', function() end)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    mirror = { honor = Config.Honor.Start, standing = {} }
end)

-- a player who is already in the game when this resource (re)starts asks for the data
CreateThread(function()
    Wait(2000)
    if LocalPlayer.state.isLoggedIn then
        RSGCore.Functions.TriggerCallback('rsg-reputation:server:requestSync', function() end)
    end
end)

exports('GetHonor', function() return mirror.honor end)
exports('GetHonorTier', function() return tierOf(HonorTiers, mirror.honor) end)
exports('GetStanding', function(region)
    if not Config.Regions[region] then return nil end
    return mirror.standing[region] or Config.Standing.Start
end)
exports('GetStandingTier', function(region)
    if not Config.Regions[region] then return nil end
    return tierOf(StandingTiers, mirror.standing[region] or Config.Standing.Start)
end)
exports('GetPriceModifier', function(region)
    if not Config.Regions[region] then return 0.0 end
    return tierOf(StandingTiers, mirror.standing[region] or Config.Standing.Start).priceModifier
end)
exports('IsHostile', function(region)
    if not Config.Regions[region] then return false end
    return tierOf(StandingTiers, mirror.standing[region] or Config.Standing.Start).hostile
end)
