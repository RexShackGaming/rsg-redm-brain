local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------
-- daily bounties: a few animals each (UTC) day pay extra at the
-- butcher and give extra xp. the pick is the same all day and
-- survives restarts (worked out from the day number, no storage).
-- with Config.Bounty.PerRegion every butcher region has its own pick
------------------------------------------
HuntingBounty = {}

local Cfg = Config.Bounty or {}
local byRegion = {} -- [region] = { day, list, set }
local ALL = '_all'

local function dayNumber()
    return os.time() // 86400
end

local function hashString(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return h
end

local function pick(day, region)
    local pool, list, set = {}, {}, {}
    if Cfg.Animals and #Cfg.Animals > 0 then
        for i, a in ipairs(Cfg.Animals) do pool[i] = a end
    else
        -- default: any butcher animal (Config.Animal) that pays at least MinReward, legendaries excluded
        for _, a in ipairs(Config.Animal) do
            if (a.rewardmoney or 0) >= (Cfg.MinReward or 0) and not a.name:find('Legendary') then
                pool[#pool + 1] = { model = a.model, label = a.name }
            end
        end
    end
    local seed = (day * 2654435761 + hashString(region)) % 4294967296 -- small LCG so math.random isn't reseeded
    for _ = 1, math.min(Cfg.Count or 1, #pool) do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local a = table.remove(pool, seed % #pool + 1)
        list[#list + 1] = a
        set[a.model] = a
    end
    return list, set
end

local function regionKey(region)
    return (Cfg.PerRegion and region) or ALL
end

local function today(region)
    local key = regionKey(region)
    local day = dayNumber()
    local s = byRegion[key]
    if not s or s.day ~= day then
        local list, set = pick(day, key)
        s = { day = day, list = list, set = set }
        byRegion[key] = s
    end
    return s
end

-- region (butcher region id) closest to a point: used for trappers and for where a player is skinning
function HuntingBounty.RegionAt(coords)
    local best, bestDist
    for _, b in ipairs(Config.ButcherLocations) do
        local d = #(coords - b.coords)
        if not bestDist or d < bestDist then best, bestDist = b.region, d end
    end
    return best
end

-- bounty entry for a model in a region, or nil
function HuntingBounty.Get(model, region)
    if not Cfg.Enabled then return nil end
    return today(region).set[model]
end

-- labels for the ui / notify (no region + PerRegion = every region's animals, once each)
function HuntingBounty.List(region)
    if not Cfg.Enabled then return {} end
    local out = {}
    if Cfg.PerRegion and not region then
        local seen = {}
        for _, b in ipairs(Config.ButcherLocations) do
            for _, a in ipairs(today(b.region).list) do
                if not seen[a.label] then seen[a.label] = true; out[#out + 1] = a.label end
            end
        end
        return out
    end
    for i, a in ipairs(today(region).list) do out[i] = a.label end
    return out
end

function HuntingBounty.XPMultiplier(model, region)
    return HuntingBounty.Get(model, region) and (Cfg.XPMultiplier or 1) or 1
end

function HuntingBounty.ButcherBonus(model, region)
    return HuntingBounty.Get(model, region) and (Cfg.ButcherBonus or 0) / 100 or 0
end

-- bounties of the region around a trapper (vendorIndex) or, without one, around the player
RSGCore.Functions.CreateCallback('rsg-hunting:server:getBounties', function(src, cb, vendorIndex)
    local vendor = type(vendorIndex) == 'number' and Config.Vendors[vendorIndex]
    local coords
    if vendor then
        coords = vector3(vendor.coords.x, vendor.coords.y, vendor.coords.z)
    else
        coords = GetEntityCoords(GetPlayerPed(src))
    end
    cb(HuntingBounty.List(HuntingBounty.RegionAt(coords)))
end)

exports('GetDailyBounties', HuntingBounty.List)
