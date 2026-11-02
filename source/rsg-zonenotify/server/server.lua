local RSGCore = exports['rsg-core']:GetCoreObject()

local cache    = {} -- [citizenid] = { set = {[zone]=true}, count = n }
local lastHit  = {} -- [src] = GetGameTimer()

local SCHEMA <const> = [[
CREATE TABLE IF NOT EXISTS `zonenotify_discoveries` (
    `citizenid` VARCHAR(50) NOT NULL,
    `zone` VARCHAR(64) NOT NULL,
    `discovered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `zone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local dbReady = false

local function ensureDatabase()
    local ok, err = pcall(MySQL.query.await, SCHEMA)
    if not ok then
        print('^1[rsg-zonenotify] could not create database table: ' .. tostring(err) .. '^7')
        return false
    end
    print('^2[rsg-zonenotify] database tables ready^7')
    return true
end

CreateThread(function()
    if not Config.Discovery.Enabled then return end
    if Config.AutoDatabase and not ensureDatabase() then return end
    dbReady = true
end)

local function Load(cid)
    if cache[cid] then return cache[cid] end
    local rows = MySQL.query.await('SELECT zone FROM zonenotify_discoveries WHERE citizenid = ?', { cid }) or {}
    local entry = { set = {}, count = 0 }
    for _, r in ipairs(rows) do entry.set[r.zone] = true; entry.count = entry.count + 1 end
    cache[cid] = entry
    return entry
end

RSGCore.Functions.CreateCallback('rsg-zonenotify:server:getDiscoveries', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not dbReady then return cb({}) end
    local list = {}
    for zone in pairs(Load(Player.PlayerData.citizenid).set) do list[#list + 1] = zone end
    cb(list)
end)

RegisterNetEvent('rsg-zonenotify:server:discover', function(zone)
    local src = source
    if not dbReady or not Config.Discovery.Enabled then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    if type(zone) ~= 'string' or #zone > 64 or not zone:match('^[%w_]+$') then return end

    local now = GetGameTimer()
    if lastHit[src] and now - lastHit[src] < 1000 then return end -- one discovery per second is plenty
    lastHit[src] = now

    zone = zone:lower()
    local cid = Player.PlayerData.citizenid
    local entry = Load(cid)
    if entry.set[zone] or entry.count >= Config.Discovery.MaxPerPlayer then return end
    entry.set[zone] = true
    entry.count = entry.count + 1
    MySQL.insert('INSERT IGNORE INTO zonenotify_discoveries (citizenid, zone) VALUES (?, ?)', { cid, zone })
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastHit[src] = nil
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then cache[Player.PlayerData.citizenid] = nil end
end)

----------------------------------------------------------------
-- exports
----------------------------------------------------------------
-- show a custom banner to one player (or -1 for everyone)
exports('ShowBanner', function(target, title, subtitle, duration)
    target = tonumber(target)
    if not target or type(title) ~= 'string' or title == '' then return false end
    TriggerClientEvent('rsg-zonenotify:client:showBanner', target, { title = title, subtitle = subtitle, duration = duration })
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
