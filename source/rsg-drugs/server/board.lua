-- Dealer leaderboard: lifetime units sold, money earned and best potency sold per character (corner selling and
-- brick exports). Persisted in rsg_drugs_state (key 'board'), no extra table. The lab panel shows the top of it.
local RSGCore = exports['rsg-core']:GetCoreObject()

DrugsBoard = {}

local KEY = 'board'
local Rows, dirty, loaded = {}, false, false -- Rows[citizenid] = { name, sold, earned, best }

local function save()
    if not loaded or not dirty then return end
    dirty = false
    MySQL.prepare('INSERT INTO rsg_drugs_state (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)', { KEY, json.encode(Rows) })
end

CreateThread(function()
    if not DrugsEnsureDatabase() then return end
    local raw = MySQL.scalar.await('SELECT `value` FROM rsg_drugs_state WHERE `key` = ?', { KEY })
    local ok, data = pcall(json.decode, raw or 'null')
    if ok and type(data) == 'table' then Rows = data end
    loaded = true
    while true do Wait(60000) save() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then save() end
end)

-- call after a real sale: units sold, money earned, potency of what was sold (0-100, optional)
function DrugsBoard.Record(Player, units, earned, potency)
    local B = Config.Board
    if not B or not B.Enabled or not loaded then return end
    local cid = Player.PlayerData.citizenid
    local ci = Player.PlayerData.charinfo or {}
    local row = Rows[cid]
    if not row then row = { sold = 0, earned = 0, best = 0 } Rows[cid] = row end
    row.name = ('%s %s'):format(ci.firstname or '?', ci.lastname or '')
    row.sold = (row.sold or 0) + units
    row.earned = math.floor(((row.earned or 0) + earned) * 100 + 0.5) / 100
    if potency and potency > (row.best or 0) then row.best = math.floor(potency + 0.5) end
    dirty = true
end

-- the top `n` by money earned, plus the asking player's own place { rank, row }
function DrugsBoard.Top(cid, n)
    local list = {}
    for id, r in pairs(Rows) do list[#list + 1] = { cid = id, name = r.name or '?', sold = r.sold or 0, earned = r.earned or 0, best = r.best or 0 } end
    table.sort(list, function(a, b) if a.earned ~= b.earned then return a.earned > b.earned end return a.cid < b.cid end)
    local top, mine = {}, nil
    for i, r in ipairs(list) do
        if r.cid == cid then mine = { rank = i, sold = r.sold, earned = r.earned, best = r.best } end
        if i <= n then top[i] = { rank = i, name = r.name, sold = r.sold, earned = r.earned, best = r.best, you = r.cid == cid or nil } end
    end
    return top, mine
end
