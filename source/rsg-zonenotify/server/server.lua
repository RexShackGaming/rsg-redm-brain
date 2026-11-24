local RSGCore = exports['rsg-core']:GetCoreObject()

local cache   = {} -- [citizenid] = entry (online characters only)
local online  = {} -- [src] = citizenid, so the cache can be cleaned even after rsg-core dropped the player
local buckets = {} -- [src] = { tokens, last } rate limit for discovery events
local lb      = { at = 0, rows = nil } -- leaderboard cache
local calls   = {} -- [src] = { [callbackName] = GetGameTimer() } so a client cannot spam the callbacks

local BURST   <const> = 5     -- discoveries a player can send in a burst
local REFILL  <const> = 1000  -- ms to earn one more

local SCHEMAS <const> = {
[[
CREATE TABLE IF NOT EXISTS `zonenotify_discoveries` (
    `citizenid` VARCHAR(50) NOT NULL,
    `zone` VARCHAR(64) NOT NULL,
    `discovered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]],
[[
CREATE TABLE IF NOT EXISTS `zonenotify_milestones` (
    `citizenid` VARCHAR(50) NOT NULL,
    `milestone` VARCHAR(32) NOT NULL,
    `claimed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `milestone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]],
}

local dbReady = false

local function ensureDatabase()
    for _, sql in ipairs(SCHEMAS) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then
            print('^1[rsg-zonenotify] could not create database table: ' .. tostring(err) .. '^7')
            return false
        end
    end
    print('^2[rsg-zonenotify] database tables ready^7')
    return true
end

CreateThread(function()
    if not Config.Discovery.Enabled then return end
    if Config.AutoDatabase and not ensureDatabase() then return end
    dbReady = true
end)

----------------------------------------------------------------
-- other resources (all optional)
----------------------------------------------------------------
local function Started(name) return GetResourceState(name) == 'started' end

local function RegisterExplorerSkill()
    local xp = Config.Rewards.XP
    if not Config.Rewards.Enabled or not xp or not xp.Skill or not Started('rsg-skills') then return end
    local ok, err = pcall(function()
        exports['rsg-skills']:RegisterSkill(xp.Skill, { label = xp.Label or 'Explorer', order = 120 })
    end)
    if not ok then print('^3[rsg-zonenotify] could not register the ' .. xp.Skill .. ' skill: ' .. tostring(err) .. '^7') end
end

CreateThread(function() Wait(1500) RegisterExplorerSkill() end)
AddEventHandler('rsg-skills:server:ready', RegisterExplorerSkill) -- again if rsg-skills restarts

local function GiveCash(Player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount > 0 then Player.Functions.AddMoney('cash', amount, reason) end
    return amount
end

local function GiveXP(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    local skill = Config.Rewards.XP and Config.Rewards.XP.Skill
    if amount <= 0 or not skill or not Started('rsg-skills') then return 0 end
    local ok = pcall(function() exports['rsg-skills']:AddXP(src, skill, amount, reason) end)
    return ok and amount or 0
end

local function GiveStanding(src, zone)
    local st = Config.Rewards.Standing
    local region = st and st.Regions and st.Regions[zone]
    if not region or (tonumber(st.Amount) or 0) == 0 or not Started('rsg-reputation') then return end
    pcall(function() exports['rsg-reputation']:AddStanding(src, region, st.Amount, 'zonenotify-discovery', true) end)
end

----------------------------------------------------------------
-- discovery data
----------------------------------------------------------------
-- only keys that exist in shared/zones.lua count (ignores junk rows from older versions)
local function QueryEntry(cid)
    local entry = { set = {}, count = 0, kinds = {}, claimed = {}, today = 0 }
    local rows = MySQL.query.await('SELECT zone, (discovered_at >= CURDATE()) AS today FROM zonenotify_discoveries WHERE citizenid = ?', { cid }) or {}
    for _, r in ipairs(rows) do
        if Zones.Keys[r.zone] and not entry.set[r.zone] then
            entry.set[r.zone] = true
            entry.count = entry.count + 1
            local kind = Zones.Kind[r.zone]
            entry.kinds[kind] = (entry.kinds[kind] or 0) + 1
            if tonumber(r.today) == 1 then entry.today = entry.today + 1 end
        end
    end
    local claims = MySQL.query.await('SELECT milestone FROM zonenotify_milestones WHERE citizenid = ?', { cid }) or {}
    for _, r in ipairs(claims) do entry.claimed[r.milestone] = true end
    return entry
end

-- online characters are cached; lookups for offline characters (exports) are not, so the cache cannot grow forever
local function Load(cid, persist)
    if cache[cid] then return cache[cid] end
    local entry = QueryEntry(cid)
    if persist then cache[cid] = entry end
    return entry
end

local function Release(src)
    local cid = online[src]
    if cid then cache[cid] = nil end
    online[src], buckets[src], calls[src] = nil, nil, nil
end

-- true when this player may call the callback again (cb limit in ms)
local function CallAllowed(src, name, limit)
    local now = GetGameTimer()
    local c = calls[src]
    if not c then c = {}; calls[src] = c end
    if c[name] and now - c[name] < limit then return false end
    c[name] = now
    return true
end

-- token bucket: short bursts are fine (town + landmark banner back to back), sustained spam is dropped
local function AllowDiscover(src)
    local now = GetGameTimer()
    local b = buckets[src]
    if not b then b = { tokens = BURST, last = now }; buckets[src] = b end
    b.tokens = math.min(BURST, b.tokens + (now - b.last) / REFILL)
    b.last = now
    if b.tokens < 1 then return false end
    b.tokens = b.tokens - 1
    return true
end

----------------------------------------------------------------
-- rewards and milestones
----------------------------------------------------------------
-- a reward is only paid when the report looks like real exploration (see Config.Rewards)
local function RewardAllowed(src, entry, coords)
    local R = Config.Rewards
    if not R.Enabled or type(coords) ~= 'vector3' then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    if #(GetEntityCoords(ped) - coords) > (R.MaxCoordGap or 60.0) then return false end
    local now = GetGameTimer()
    if entry.lastPaid and now - entry.lastPaid < (R.MinInterval or 0) * 1000 then return false end
    if entry.lastPaidCoords and #(coords - entry.lastPaidCoords) < (R.MinTravel or 0.0) then return false end
    if entry.today >= (R.MaxPerDay or 1e9) then return false end
    return true
end

local function PayDiscovery(src, Player, entry, zone, kind, coords)
    local R = Config.Rewards
    local cash = GiveCash(Player, R.Cash and R.Cash[kind], 'zonenotify-discovery')
    local xp = GiveXP(src, R.XP and R.XP.Amounts and R.XP.Amounts[kind], 'zonenotify-discovery')
    GiveStanding(src, zone)
    entry.lastPaid, entry.lastPaidCoords = GetGameTimer(), coords
    if cash > 0 or xp > 0 then
        TriggerClientEvent('rsg-zonenotify:client:reward', src, { key = zone, cash = cash, xp = xp })
    end
end

local function ClaimMilestone(src, Player, cid, entry, id, info, reward)
    entry.claimed[id] = true
    MySQL.insert('INSERT IGNORE INTO zonenotify_milestones (citizenid, milestone) VALUES (?, ?)', { cid, id })
    local cash = GiveCash(Player, reward.cash, 'zonenotify-milestone')
    local xp = GiveXP(src, reward.xp, 'zonenotify-milestone')
    info.id, info.cash, info.xp = id, cash, xp
    TriggerClientEvent('rsg-zonenotify:client:milestone', src, info)
    TriggerEvent('rsg-zonenotify:server:milestoneReached', src, cid, id)
end

local function CheckMilestones(src, Player, cid, entry)
    local M = Config.Milestones
    if not M.Enabled then return end

    for kind, reward in pairs(M.Categories or {}) do
        local id, total = 'cat_' .. kind, Zones.KindCount[kind]
        if total and total > 0 and not entry.claimed[id] and (entry.kinds[kind] or 0) >= total then
            ClaimMilestone(src, Player, cid, entry, id, { kind = kind }, reward)
        end
    end

    local percent = math.floor(entry.count / math.max(Zones.KeyCount, 1) * 100)
    local thresholds = {}
    for t in pairs(M.Overall or {}) do thresholds[#thresholds + 1] = t end
    table.sort(thresholds)
    for _, t in ipairs(thresholds) do
        local id = 'all_' .. t
        if percent >= t and not entry.claimed[id] then
            ClaimMilestone(src, Player, cid, entry, id, { percent = t }, M.Overall[t])
        end
    end
end

----------------------------------------------------------------
-- leaderboard
----------------------------------------------------------------
local ZONE_LIST, ZONE_MARKS = {}, nil
for key in pairs(Zones.Keys) do ZONE_LIST[#ZONE_LIST + 1] = key end
ZONE_MARKS = ('?,'):rep(#ZONE_LIST):sub(1, -2)

local function DisplayName(charinfo, mode)
    if mode == 'anonymous' or type(charinfo) ~= 'table' then return nil end
    local first, last = tostring(charinfo.firstname or ''), tostring(charinfo.lastname or '')
    if first == '' and last == '' then return nil end
    if mode == 'full' then return (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '') end
    return (first .. (last ~= '' and (' ' .. last:sub(1, 1) .. '.') or '')):gsub('^%s+', '')
end

local function BuildLeaderboard()
    local cfg = Config.Leaderboard
    local size = math.max(1, math.min(25, math.floor(tonumber(cfg.Size) or 10)))
    local params = {}
    for i, key in ipairs(ZONE_LIST) do params[i] = key end
    params[#params + 1] = size
    local top = MySQL.query.await(('SELECT citizenid, COUNT(*) AS found FROM zonenotify_discoveries WHERE zone IN (%s) GROUP BY citizenid ORDER BY found DESC, MIN(discovered_at) ASC LIMIT ?'):format(ZONE_MARKS), params) or {}

    local names = {}
    if #top > 0 and cfg.Names ~= 'anonymous' then
        local ids, marks = {}, {}
        for i, r in ipairs(top) do ids[i] = r.citizenid; marks[i] = '?' end
        local people = MySQL.query.await(('SELECT citizenid, charinfo FROM players WHERE citizenid IN (%s)'):format(table.concat(marks, ',')), ids) or {}
        for _, p in ipairs(people) do
            local ok, info = pcall(json.decode, p.charinfo or '')
            names[p.citizenid] = DisplayName(ok and info or nil, cfg.Names)
        end
    end

    local rows = {}
    for i, r in ipairs(top) do
        rows[i] = { citizenid = r.citizenid, rank = i, name = names[r.citizenid], found = tonumber(r.found) or 0 }
    end
    return rows
end

local function GetLeaderboard()
    if not Config.Leaderboard.Enabled or not dbReady then return {} end
    local now = os.time()
    if not lb.rows or now - lb.at >= (tonumber(Config.Leaderboard.CacheSeconds) or 300) then
        local ok, rows = pcall(BuildLeaderboard)
        if ok then lb.rows, lb.at = rows, now else print('^1[rsg-zonenotify] leaderboard failed: ' .. tostring(rows) .. '^7') lb.rows, lb.at = lb.rows or {}, now end
    end
    return lb.rows
end

----------------------------------------------------------------
-- callbacks and events
----------------------------------------------------------------
RSGCore.Functions.CreateCallback('rsg-zonenotify:server:getDiscoveries', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not dbReady or not CallAllowed(source, 'discoveries', 1000) then return cb({}) end
    local cid = Player.PlayerData.citizenid
    online[source] = cid
    local list = {}
    for zone in pairs(Load(cid, true).set) do list[#list + 1] = zone end
    cb(list)
end)

-- everything the journal needs in one call
RSGCore.Functions.CreateCallback('rsg-zonenotify:server:getJournal', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not dbReady or not CallAllowed(source, 'journal', 1000) then return cb(nil) end
    local cid = Player.PlayerData.citizenid
    online[source] = cid
    local entry = Load(cid, true)

    local discovered = {}
    for zone in pairs(entry.set) do discovered[#discovered + 1] = zone end

    local board = {}
    for i, r in ipairs(GetLeaderboard()) do
        board[i] = { rank = r.rank, name = r.name, found = r.found, me = r.citizenid == cid or nil }
    end

    cb({ discovered = discovered, claimed = entry.claimed, leaderboard = board, found = entry.count })
end)

RegisterNetEvent('rsg-zonenotify:server:discover', function(zone, coords)
    local src = source
    if not dbReady or not Config.Discovery.Enabled then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(zone) ~= 'string' or #zone > 64 then return end
    zone = zone:lower()
    if not Zones.Keys[zone] then return end -- not a real place
    if not AllowDiscover(src) then return end

    local cid = Player.PlayerData.citizenid
    online[src] = cid
    local entry = Load(cid, true)
    if entry.set[zone] or entry.count >= Config.Discovery.MaxPerPlayer then return end

    local kind = Zones.Kind[zone]
    local paid = RewardAllowed(src, entry, coords) -- must be checked before the counters move

    entry.set[zone] = true
    entry.count = entry.count + 1
    entry.today = entry.today + 1
    entry.kinds[kind] = (entry.kinds[kind] or 0) + 1
    MySQL.insert('INSERT IGNORE INTO zonenotify_discoveries (citizenid, zone) VALUES (?, ?)', { cid, zone })

    if paid then PayDiscovery(src, Player, entry, zone, kind, coords) end
    TriggerEvent('rsg-zonenotify:server:placeDiscovered', src, cid, zone, kind)
    CheckMilestones(src, Player, cid, entry)
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) Release(src) end)
AddEventHandler('playerDropped', function() Release(source) end)

----------------------------------------------------------------
-- exports
----------------------------------------------------------------
-- show a custom banner to one player (or -1 for everyone)
exports('ShowBanner', function(target, title, subtitle, duration)
    target = tonumber(target)
    if not target or type(title) ~= 'string' or title == '' then return false end
    if type(subtitle) ~= 'string' then subtitle = nil end
    TriggerClientEvent('rsg-zonenotify:client:showBanner', target, { title = title:sub(1, 64), subtitle = subtitle and subtitle:sub(1, 120), duration = tonumber(duration) })
    return true
end)

exports('GetDiscoveryCount', function(citizenid)
    if not dbReady or type(citizenid) ~= 'string' then return 0 end
    return Load(citizenid).count
end)

exports('HasDiscovered', function(citizenid, zone)
    if not dbReady or type(citizenid) ~= 'string' or type(zone) ~= 'string' then return false end
    return Load(citizenid).set[zone:lower()] == true
end)

-- { found, total, percent, kinds = { town = { found, total }, ... } }
exports('GetProgress', function(citizenid)
    if not dbReady or type(citizenid) ~= 'string' then return nil end
    local entry = Load(citizenid)
    local kinds = {}
    for _, kind in ipairs(Zones.KindOrder) do kinds[kind] = { found = entry.kinds[kind] or 0, total = Zones.KindCount[kind] } end
    return { found = entry.count, total = Zones.KeyCount, percent = math.floor(entry.count / math.max(Zones.KeyCount, 1) * 100), kinds = kinds }
end)

exports('GetLeaderboard', function()
    local out = {}
    for i, r in ipairs(GetLeaderboard()) do out[i] = { rank = r.rank, citizenid = r.citizenid, name = r.name, found = r.found } end
    return out
end)
