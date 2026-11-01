local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------
-- daily bounties: a few animals each (UTC) day pay extra at the
-- butcher and give extra xp. the pick is the same all day and
-- survives restarts (worked out from the day number, no storage)
------------------------------------------
HuntingBounty = {}

local Cfg = Config.Bounty or {}
local today, todayList, todaySet = nil, {}, {}

local function dayNumber()
    return os.time() // 86400
end

local function pick(day)
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
    local seed = (day * 2654435761) % 4294967296 -- small LCG so math.random isn't reseeded
    for _ = 1, math.min(Cfg.Count or 1, #pool) do
        seed = (seed * 1103515245 + 12345) % 2147483648
        local a = table.remove(pool, seed % #pool + 1)
        list[#list + 1] = a
        set[a.model] = a
    end
    return list, set
end

local function refresh()
    local day = dayNumber()
    if day ~= today then
        today = day
        todayList, todaySet = pick(day)
    end
end

-- bounty entry for a model, or nil
function HuntingBounty.Get(model)
    if not Cfg.Enabled then return nil end
    refresh()
    return todaySet[model]
end

-- labels for the ui / notify
function HuntingBounty.List()
    if not Cfg.Enabled then return {} end
    refresh()
    local out = {}
    for i, a in ipairs(todayList) do out[i] = a.label end
    return out
end

function HuntingBounty.XPMultiplier(model)
    return HuntingBounty.Get(model) and (Cfg.XPMultiplier or 1) or 1
end

function HuntingBounty.ButcherBonus(model)
    return HuntingBounty.Get(model) and (Cfg.ButcherBonus or 0) / 100 or 0
end

RSGCore.Functions.CreateCallback('rsg-hunting:server:getBounties', function(src, cb)
    cb(HuntingBounty.List())
end)

exports('GetDailyBounties', HuntingBounty.List)
