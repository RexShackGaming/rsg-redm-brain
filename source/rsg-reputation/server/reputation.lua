-- rsg-reputation: tiers, honor/standing changes, actions, exports, callbacks
RSGRep = RSGRep or {}
local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------
-- helpers
------------------------------------------
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function round(v)
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end

local function trunc(v)
    if v >= 0 then return math.floor(v) end
    return math.ceil(v)
end

local function validNumber(v)
    return type(v) == 'number' and v == v and v > -math.huge and v < math.huge
end

-- sorted copies of the tier lists (ascending by min)
local function sortedTiers(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    table.sort(out, function(a, b) return a.min < b.min end)
    return out
end

local HonorTiers = sortedTiers(Config.Honor.Tiers)
local StandingTiers = sortedTiers(Config.Standing.Tiers)

local function tierIndex(tiers, value)
    local idx = 1
    for i = 1, #tiers do
        if value >= tiers[i].min then idx = i end
    end
    return idx
end

local function buildTier(tiers, value)
    local idx = tierIndex(tiers, value)
    local t = tiers[idx]
    return {
        index = idx,
        labelKey = t.label,
        label = locale(t.label),
        min = t.min,
        priceModifier = t.priceModifier or 0.0,
        hostile = t.hostile == true,
    }
end

local function regionLabel(region)
    local r = Config.Regions[region]
    return locale(r and r.label or region)
end

local function notify(src, description, ntype, id)
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('notify_title'),
        description = description,
        type = ntype or 'inform',
        duration = 3500,
        id = id,
    })
end

local function signed(n)
    if n > 0 then return '+' .. n end
    return tostring(n)
end

------------------------------------------
-- client mirror
------------------------------------------
function RSGRep.SyncClient(src)
    local c
    for _, v in pairs(RSGRep.Cache) do
        if v.src == src then c = v break end
    end
    if not c then return end
    TriggerClientEvent('rsg-reputation:client:sync', src, { honor = c.honor, standing = c.standing })
end

------------------------------------------
-- changing values (server only)
------------------------------------------
function RSGRep.SetHonor(src, value, reason, quiet)
    if not validNumber(value) then return nil end
    local c = RSGRep.Load(src)
    if not c then return nil end
    local new = clamp(round(value), Config.Honor.Min, Config.Honor.Max)
    local old = c.honor
    if new == old then return new end
    c.honor = new
    c.dirtyHonor = true

    local oldTier, newTier = buildTier(HonorTiers, old), buildTier(HonorTiers, new)
    if Config.NotifyChanges and not quiet then
        notify(src, locale('notify_honor_changed', signed(new - old)), new > old and 'success' or 'error', 'rep_honor')
    end
    if oldTier.index ~= newTier.index then
        if Config.NotifyTierChange and not quiet then
            notify(src, locale('notify_tier_honor', newTier.label), new > old and 'success' or 'warning', 'rep_honor_tier')
        end
        TriggerEvent('rsg-reputation:server:tierChanged', src, 'honor', nil, oldTier, newTier)
    end
    TriggerEvent('rsg-reputation:server:honorChanged', src, new, old, reason)
    RSGRep.SyncClient(src)
    return new
end

function RSGRep.SetStanding(src, region, value, reason, quiet)
    if type(region) ~= 'string' or not Config.Regions[region] then return nil end
    if not validNumber(value) then return nil end
    local c = RSGRep.Load(src)
    if not c then return nil end
    local new = clamp(round(value), Config.Standing.Min, Config.Standing.Max)
    local old = c.standing[region] or Config.Standing.Start
    if new == old then return new end
    c.standing[region] = new
    c.dirtyStanding[region] = true

    local oldTier, newTier = buildTier(StandingTiers, old), buildTier(StandingTiers, new)
    if Config.NotifyChanges and not quiet then
        notify(src, locale('notify_standing_changed', regionLabel(region), signed(new - old)), new > old and 'success' or 'error', 'rep_st_' .. region)
    end
    if oldTier.index ~= newTier.index then
        if Config.NotifyTierChange and not quiet then
            notify(src, locale('notify_tier_standing', regionLabel(region), newTier.label), new > old and 'success' or 'warning', 'rep_sttier_' .. region)
        end
        TriggerEvent('rsg-reputation:server:tierChanged', src, 'standing', region, oldTier, newTier)
    end
    TriggerEvent('rsg-reputation:server:standingChanged', src, region, new, old, reason)
    RSGRep.SyncClient(src)
    return new
end

local function limitDelta(amount)
    local cap = tonumber(Config.MaxChangePerCall) or 200
    return clamp(amount, -cap, cap)
end

function RSGRep.AddHonor(src, amount, reason, quiet)
    if not validNumber(amount) then return nil end
    local c = RSGRep.Load(src)
    if not c then return nil end
    return RSGRep.SetHonor(src, c.honor + limitDelta(amount), reason, quiet)
end

-- a change in a town also moves its state (Config.Standing.ParentSpill)
function RSGRep.AddStanding(src, region, amount, reason, quiet, noSpill)
    if type(region) ~= 'string' or not Config.Regions[region] then return nil end
    if not validNumber(amount) then return nil end
    local c = RSGRep.Load(src)
    if not c then return nil end
    amount = limitDelta(amount)
    local cur = c.standing[region] or Config.Standing.Start
    local result = RSGRep.SetStanding(src, region, cur + amount, reason, quiet)

    local parent = Config.Regions[region].parent
    local ratio = tonumber(Config.Standing.ParentSpill) or 0
    if not noSpill and parent and Config.Regions[parent] and ratio > 0 then
        local spill = trunc(amount * ratio)
        if spill ~= 0 then
            local pc = c.standing[parent] or Config.Standing.Start
            RSGRep.SetStanding(src, parent, pc + spill, reason, quiet)
        end
    end
    return result
end

-- applies a named action from Config.Actions; region is optional (needed for the standing part)
function RSGRep.ApplyAction(src, action, region)
    local def = Config.Actions[action]
    if not def then return false end
    if def.honor and def.honor ~= 0 then RSGRep.AddHonor(src, def.honor, action) end
    if region and def.standing and def.standing ~= 0 then RSGRep.AddStanding(src, region, def.standing, action) end
    return true
end

function RSGRep.Reset(src)
    local c = RSGRep.Load(src)
    if not c then return false end
    c.honor = Config.Honor.Start
    c.dirtyHonor = true
    for region in pairs(c.standing) do
        c.standing[region] = Config.Standing.Start
        c.dirtyStanding[region] = true
    end
    RSGRep.SyncClient(src)
    return true
end

------------------------------------------
-- reading values
------------------------------------------
function RSGRep.GetHonor(src)
    local c = RSGRep.Load(src)
    return c and c.honor or nil
end

function RSGRep.GetHonorTier(src)
    local c = RSGRep.Load(src)
    if not c then return nil end
    return buildTier(HonorTiers, c.honor)
end

function RSGRep.GetStanding(src, region)
    if type(region) ~= 'string' or not Config.Regions[region] then return nil end
    local c = RSGRep.Load(src)
    if not c then return nil end
    return c.standing[region] or Config.Standing.Start
end

function RSGRep.GetStandingTier(src, region)
    local v = RSGRep.GetStanding(src, region)
    if v == nil then return nil end
    return buildTier(StandingTiers, v)
end

-- fraction to add to prices in a region, 0.0 when unknown
function RSGRep.GetPriceModifier(src, region)
    local t = RSGRep.GetStandingTier(src, region)
    return t and t.priceModifier or 0.0
end

function RSGRep.IsHostile(src, region)
    local t = RSGRep.GetStandingTier(src, region)
    return t ~= nil and t.hostile
end

-- offline lookup of honor by citizenid (online players come from the cache)
function RSGRep.GetHonorByCitizenId(cid)
    if type(cid) ~= 'string' then return nil end
    local c = RSGRep.Cache[cid]
    if c then return c.honor end
    if not RSGRep.WaitReady() then return nil end
    local row = MySQL.single.await('SELECT honor FROM rsg_reputation WHERE citizenid = ?', { cid })
    return row and tonumber(row.honor) or Config.Honor.Start
end

------------------------------------------
-- exports
------------------------------------------
exports('AddHonor', RSGRep.AddHonor)
exports('SetHonor', RSGRep.SetHonor)
exports('GetHonor', RSGRep.GetHonor)
exports('GetHonorTier', RSGRep.GetHonorTier)
exports('HasHonor', function(src, min)
    local v = RSGRep.GetHonor(src)
    return v ~= nil and validNumber(min) and v >= min
end)
exports('AddStanding', RSGRep.AddStanding)
exports('SetStanding', RSGRep.SetStanding)
exports('GetStanding', RSGRep.GetStanding)
exports('GetStandingTier', RSGRep.GetStandingTier)
exports('HasStanding', function(src, region, min)
    local v = RSGRep.GetStanding(src, region)
    return v ~= nil and validNumber(min) and v >= min
end)
exports('GetPriceModifier', RSGRep.GetPriceModifier)
exports('IsHostile', RSGRep.IsHostile)
exports('ApplyAction', RSGRep.ApplyAction)
exports('ResetReputation', RSGRep.Reset)
exports('GetHonorByCitizenId', RSGRep.GetHonorByCitizenId)
exports('GetRegions', function() return Config.Regions end)

------------------------------------------
-- panel data (read-only)
------------------------------------------
local lastPanel = {}

RSGCore.Functions.CreateCallback('rsg-reputation:server:getReputation', function(source, cb)
    local now = GetGameTimer()
    if lastPanel[source] and now - lastPanel[source] < 1000 then return cb(nil) end
    lastPanel[source] = now

    local c = RSGRep.Load(source)
    if not c then return cb(nil) end

    local honorTier = buildTier(HonorTiers, c.honor)
    local regions = {}
    for id, r in pairs(Config.Regions) do
        local v = c.standing[id] or Config.Standing.Start
        local t = buildTier(StandingTiers, v)
        regions[#regions + 1] = {
            id = id, label = locale(r.label), type = r.type, parent = r.parent, order = r.order or 0,
            standing = v, tier = t.label, tierIndex = t.index, priceModifier = t.priceModifier, hostile = t.hostile,
        }
    end
    table.sort(regions, function(a, b) return a.order < b.order end)

    cb({
        honor = c.honor, honorMin = Config.Honor.Min, honorMax = Config.Honor.Max,
        honorTier = honorTier.label, honorTierIndex = honorTier.index, honorTierCount = #HonorTiers,
        standingMin = Config.Standing.Min, standingMax = Config.Standing.Max,
        regions = regions,
    })
end)

AddEventHandler('playerDropped', function() lastPanel[source] = nil end)

-- sends the mirror to a player once their reputation is loaded
local function loadAndSync(src)
    if RSGRep.Load(src) then RSGRep.SyncClient(src) end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if src then CreateThread(function() loadAndSync(src) end) end
end)

RSGCore.Functions.CreateCallback('rsg-reputation:server:requestSync', function(source, cb)
    loadAndSync(source)
    cb(true)
end)
