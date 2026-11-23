-- Optional integrations: rsg-skills (XP + perks), rsg-reputation (honor/standing), rsg-economy (market prices).
-- Every call is guarded: a missing or restarting resource never breaks rsg-drugs.
local function running(name) return GetResourceState(name) == 'started' end

---------------------------------------------------------------------
-- rsg-skills
---------------------------------------------------------------------
DrugsSkills = {}

local function skillsOn() return Config.Skills.Enabled and running('rsg-skills') end

function DrugsSkills.Register()
    if not skillsOn() then return end
    local ok, err = pcall(function() exports['rsg-skills']:RegisterSkill(Config.Skills.Key, Config.Skills.Definition) end)
    if not ok then print(('^1[rsg-drugs] could not register the rsg-skills skill: %s^7'):format(tostring(err))) end
end

function DrugsSkills.AddXP(src, amount, reason)
    if not skillsOn() then return end
    amount = math.floor((tonumber(amount) or 0) * (Config.Skills.XPScale or 1.0))
    if amount <= 0 then return end
    pcall(function() exports['rsg-skills']:AddXP(src, Config.Skills.Key, amount, 'rsg-drugs ' .. tostring(reason or '')) end)
end

function DrugsSkills.Reset(src)
    if not skillsOn() then return end
    pcall(function() exports['rsg-skills']:SetXP(src, Config.Skills.Key, 0) end)
end

-- perk value at the player's skill level (0 when rsg-skills is off)
function DrugsSkills.Perk(src, perk)
    if not skillsOn() or not src then return 0 end
    local ok, v = pcall(function() return exports['rsg-skills']:GetPerk(src, Config.Skills.Key, perk) end)
    return ok and tonumber(v) or 0
end

AddEventHandler('rsg-skills:server:ready', DrugsSkills.Register)
CreateThread(function()
    for _ = 1, 30 do
        if running('rsg-skills') then DrugsSkills.Register() return end
        Wait(1000)
    end
end)

---------------------------------------------------------------------
-- rsg-economy: region of a player (town) and the town's market price for an item
---------------------------------------------------------------------
DrugsEcon = {}

function DrugsEcon.Region(src)
    if not running('rsg-economy') then return nil end
    local ok, region = pcall(function() return exports['rsg-economy']:GetRegionAt(GetEntityCoords(GetPlayerPed(src))) end)
    return ok and region or nil
end

function DrugsEcon.Multiplier(src, item)
    if not Config.Economy.Enabled then return 1.0 end
    local region = DrugsEcon.Region(src)
    if not region then return 1.0 end
    local ok, m = pcall(function() return exports['rsg-economy']:GetMarketMultiplier(item, region) end)
    return ok and tonumber(m) or 1.0
end

-- call only after the sale really happened
function DrugsEcon.Record(src, item, qty)
    if not Config.Economy.Enabled then return end
    local region = DrugsEcon.Region(src)
    if region then pcall(function() exports['rsg-economy']:RecordTrade(item, region, qty, 'sell') end) end
end

---------------------------------------------------------------------
-- rsg-reputation
---------------------------------------------------------------------
DrugsRep = {}

local function repOn() return Config.Reputation.Enabled and running('rsg-reputation') end

-- key = an entry of Config.Reputation.Events
function DrugsRep.Apply(src, key)
    if not repOn() then return end
    local ev = Config.Reputation.Events[key]
    if not ev then return end
    local reason = 'rsg-drugs ' .. key
    if (ev.honor or 0) ~= 0 then
        pcall(function() exports['rsg-reputation']:AddHonor(src, ev.honor, reason, true) end)
    end
    if (ev.standing or 0) ~= 0 then
        local region = DrugsEcon.Region(src)
        if region then pcall(function() exports['rsg-reputation']:AddStanding(src, region, ev.standing, reason, true) end) end
    end
end

-- true when the town the player is in has turned hostile to them
function DrugsRep.Hostile(src)
    if not repOn() then return false end
    local region = DrugsEcon.Region(src)
    if not region then return false end
    local ok, hostile = pcall(function() return exports['rsg-reputation']:IsHostile(src, region) end)
    return ok and hostile == true
end
