-- Angler's journal, server records and top anglers board.
-- Loaded before server.lua; server.lua calls Journal.OnCatch after a fish was stored.
local RSGCore = exports['rsg-core']:GetCoreObject()

Journal = {}

local SPECIES_TOTAL = 0
for _ in pairs(Config.Species) do SPECIES_TOTAL = SPECIES_TOTAL + 1 end

local Records = {}      -- [family] = { weight, citizenid, name }
local Loaded  = {}      -- [citizenid] = { [family] = { caught, best } }
local CidBySrc = {}     -- [src] = citizenid, so the cache can be dropped on disconnect
local ready = false
local boardCache = { at = 0, anglers = nil }
local lastAsk = {}      -- [src] = time of the last board / journal request (throttle)

-- ---------------------------------------------------------
-- database
-- ---------------------------------------------------------
local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `rsg_fishing_journal` (
      `citizenid` VARCHAR(50) NOT NULL,
      `species` VARCHAR(60) NOT NULL,
      `name` VARCHAR(100) NOT NULL DEFAULT '',
      `caught` INT NOT NULL DEFAULT 0,
      `best_weight` DECIMAL(8,2) NOT NULL DEFAULT 0,
      `first_caught` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `last_caught` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`citizenid`, `species`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `rsg_fishing_records` (
      `species` VARCHAR(60) NOT NULL,
      `citizenid` VARCHAR(50) NOT NULL,
      `name` VARCHAR(100) NOT NULL DEFAULT '',
      `weight` DECIMAL(8,2) NOT NULL DEFAULT 0,
      `caught_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`species`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function ensureDatabase()
    local ok, err = pcall(function()
        for i = 1, #TABLES do MySQL.query.await(TABLES[i]) end
    end)
    if not ok then
        print(('^1[rsg-fishing] could not create the database tables: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-fishing] database tables ready^7')
    return true
end

CreateThread(function()
    if Config.AutoDatabase and not ensureDatabase() then return end
    local rows = MySQL.query.await('SELECT species, citizenid, name, weight FROM rsg_fishing_records') or {}
    for i = 1, #rows do
        local r = rows[i]
        if Config.Species[r.species] then
            Records[r.species] = { weight = tonumber(r.weight) or 0, citizenid = r.citizenid, name = r.name }
        end
    end
    ready = true
end)

-- ---------------------------------------------------------
-- helpers
-- ---------------------------------------------------------
local function throttled(src)
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < 1000 then return true end
    lastAsk[src] = now
    return false
end

local function loadJournal(Player)
    local cid = Player.PlayerData.citizenid
    CidBySrc[Player.PlayerData.source] = cid
    if Loaded[cid] then return Loaded[cid] end
    local data = {}
    local rows = MySQL.query.await('SELECT species, caught, best_weight FROM rsg_fishing_journal WHERE citizenid = ?', { cid }) or {}
    for i = 1, #rows do
        local r = rows[i]
        if Config.Species[r.species] then data[r.species] = { caught = r.caught, best = tonumber(r.best_weight) or 0 } end
    end
    Loaded[cid] = data
    return data
end

local function countFound(data)
    local n = 0
    for _ in pairs(data) do n = n + 1 end
    return n
end

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('cl_fishing'), description = desc, type = ntype or 'inform', duration = 6000 })
end

local function reputation(src, action, region)
    if not Config.Reputation.Enabled or not action or GetResourceState('rsg-reputation') ~= 'started' then return end
    exports['rsg-reputation']:ApplyAction(src, action, region)
end

-- ---------------------------------------------------------
-- called by server.lua once a fished fish is in the inventory
-- ---------------------------------------------------------
function Journal.OnCatch(src, Player, family, kg, region)
    if not ready or not Config.Species[family] then return end
    local cid = Player.PlayerData.citizenid
    local ci = Player.PlayerData.charinfo
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    local data = loadJournal(Player)

    local row = data[family]
    local isNew = row == nil
    if isNew then row = { caught = 0, best = 0 }; data[family] = row end
    row.caught = row.caught + 1
    if kg > row.best then row.best = kg end

    MySQL.insert([[INSERT INTO rsg_fishing_journal (citizenid, species, name, caught, best_weight) VALUES (?, ?, ?, 1, ?)
        ON DUPLICATE KEY UPDATE caught = caught + 1, best_weight = GREATEST(best_weight, VALUES(best_weight)),
        name = VALUES(name), last_caught = CURRENT_TIMESTAMP]], { cid, family, name, kg })

    if isNew then
        notify(src, locale('sv_new_species', Config.Species[family]), 'success')
        reputation(src, Config.Reputation.NewSpecies, region)
        if countFound(data) >= SPECIES_TOTAL then
            notify(src, locale('sv_journal_complete'), 'success')
            reputation(src, Config.Reputation.Complete, region)
        end
    end

    if not Config.Records.Enabled then return end
    local rec = Records[family]
    if rec and kg <= rec.weight then return end

    Records[family] = { weight = kg, citizenid = cid, name = name }
    MySQL.insert('REPLACE INTO rsg_fishing_records (species, citizenid, name, weight) VALUES (?, ?, ?, ?)', { family, cid, name, kg })
    boardCache.at = 0

    if not rec then return end -- the first fish of a species sets the record quietly

    if Config.Records.Announce then
        TriggerClientEvent('RSGCore:Client:Notify', -1, {
            title = locale('cl_fishing'), description = locale('sv_new_record', name, Config.Species[family], string.format('%.2f', kg)),
            type = 'inform', duration = 8000,
        })
    end
    if Config.Records.Reward > 0 and Player.Functions.AddMoney('cash', Config.Records.Reward, 'rsg-fishing:record') then
        notify(src, locale('sv_record_reward', Config.Records.Reward), 'success')
    end
    reputation(src, Config.Reputation.Record, region)
    -- other scripts can listen: (src, family, kg, previousHolderName)
    TriggerEvent('rsg-fishing:server:newRecord', src, family, kg, rec.name)
end

-- ---------------------------------------------------------
-- callbacks (read only, throttled)
-- ---------------------------------------------------------
-- one callback for the whole journal window (own journal, records, top anglers)
RSGCore.Functions.CreateCallback('rsg-fishing:server:getJournal', function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or not ready or throttled(source) then return cb(nil) end
    local data = loadJournal(Player)

    local list, records = {}, {}
    for i = 1, #Config.SpeciesOrder do
        local key = Config.SpeciesOrder[i]
        local row, r = data[key], Records[key]
        list[i] = { label = Config.Species[key], caught = row and row.caught or 0, best = row and row.best or 0, legendary = key:find('legendary') ~= nil }
        records[i] = { label = Config.Species[key], weight = r and r.weight or 0, name = r and r.name or '' }
    end

    local now = GetGameTimer()
    if not boardCache.anglers or now - boardCache.at > 30000 then
        boardCache.anglers = MySQL.query.await([[SELECT MAX(name) AS name, SUM(caught) AS fish, COUNT(*) AS species
            FROM rsg_fishing_journal GROUP BY citizenid ORDER BY fish DESC LIMIT ?]], { Config.Records.TopCount }) or {}
        boardCache.at = now
    end

    cb({ species = list, found = countFound(data), total = SPECIES_TOTAL, records = records, anglers = boardCache.anglers })
end)

AddEventHandler('playerDropped', function()
    local src = source
    local cid = CidBySrc[src]
    if cid then Loaded[cid] = nil end
    CidBySrc[src], lastAsk[src] = nil, nil
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    if not src then return end
    local cid = CidBySrc[src]
    if cid then Loaded[cid] = nil end
    CidBySrc[src] = nil
end)
