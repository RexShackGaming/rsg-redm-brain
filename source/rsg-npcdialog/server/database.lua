-- Storage: editor NPCs and per-character progress
DB = { ready = false }

local schema = {
[[CREATE TABLE IF NOT EXISTS `rsg_npcdialog_npcs` (
  `id` VARCHAR(50) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
)]],
[[CREATE TABLE IF NOT EXISTS `rsg_npcdialog_progress` (
  `citizenid` VARCHAR(50) NOT NULL,
  `kind` VARCHAR(8) NOT NULL,
  `name` VARCHAR(160) NOT NULL,
  `value` BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`, `kind`, `name`)
)]],
[[CREATE TABLE IF NOT EXISTS `rsg_npcdialog_quests` (
  `id` VARCHAR(50) NOT NULL,
  `data` LONGTEXT NOT NULL,
  `updated_by` VARCHAR(50) DEFAULT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
)]],
[[CREATE TABLE IF NOT EXISTS `rsg_npcdialog_quest_progress` (
  `citizenid` VARCHAR(50) NOT NULL,
  `quest_id` VARCHAR(50) NOT NULL,
  `data` TEXT NOT NULL,
  PRIMARY KEY (`citizenid`, `quest_id`)
)]],
}

function DB.Setup()
    local ok, err = pcall(function()
        if Config.AutoDatabase then
            for _, q in ipairs(schema) do MySQL.query.await(q) end
        end
        -- proves the tables exist for manual installs too
        MySQL.scalar.await('SELECT COUNT(*) FROM rsg_npcdialog_npcs')
        MySQL.scalar.await('SELECT COUNT(*) FROM rsg_npcdialog_progress')
        MySQL.scalar.await('SELECT COUNT(*) FROM rsg_npcdialog_quests')
        MySQL.scalar.await('SELECT COUNT(*) FROM rsg_npcdialog_quest_progress')
    end)
    if not ok then
        print('^1[rsg-npcdialog] database error: ' .. tostring(err) .. '^7')
        return false
    end
    DB.ready = true
    print('^2[rsg-npcdialog] database tables ready^7')
    return true
end

function DB.LoadNPCs()
    return MySQL.query.await('SELECT id, data FROM rsg_npcdialog_npcs') or {}
end

function DB.SaveNPC(id, data, by)
    MySQL.query.await('INSERT INTO rsg_npcdialog_npcs (id, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
        { id, json.encode(data), by })
end

function DB.DeleteNPC(id)
    MySQL.query.await('DELETE FROM rsg_npcdialog_npcs WHERE id = ?', { id })
end

function DB.LoadQuests()
    return MySQL.query.await('SELECT id, data FROM rsg_npcdialog_quests') or {}
end

function DB.SaveQuest(id, data, by)
    MySQL.query.await('INSERT INTO rsg_npcdialog_quests (id, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
        { id, json.encode(data), by })
end

function DB.DeleteQuest(id)
    MySQL.query.await('DELETE FROM rsg_npcdialog_quests WHERE id = ?', { id })
end

-------------------------------------------------
-- quest progress cache: id -> { active, progress = { objectiveId = n }, started, times, completedAt }
-------------------------------------------------
local questCache = {}

---@return table|nil nil means "could not load"
function DB.QuestStates(cid)
    if questCache[cid] then return questCache[cid] end
    if not DB.ready then return nil end
    local ok, rows = pcall(MySQL.query.await, 'SELECT quest_id, data FROM rsg_npcdialog_quest_progress WHERE citizenid = ?', { cid })
    if not ok or not rows then return nil end
    if questCache[cid] then return questCache[cid] end
    local out = {}
    for _, r in ipairs(rows) do
        local decoded, data = pcall(json.decode, r.data)
        if not decoded or type(data) ~= 'table' then return nil end -- never treat unreadable progress as empty
        if type(data.progress) ~= 'table' then data.progress = {} end
        out[r.quest_id] = data
    end
    questCache[cid] = out
    return out
end

function DB.SaveQuestState(cid, questId, state)
    local all = DB.QuestStates(cid)
    if not all then return false end
    all[questId] = state
    if not state then
        MySQL.query('DELETE FROM rsg_npcdialog_quest_progress WHERE citizenid = ? AND quest_id = ?', { cid, questId })
    else
        MySQL.query('INSERT INTO rsg_npcdialog_quest_progress (citizenid, quest_id, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { cid, questId, json.encode(state) })
    end
    return true
end

-------------------------------------------------
-- progress cache: kind = 'flag' | 'once' | 'cd'
-------------------------------------------------
local cache = {}

---@return table|nil nil means "could not load": callers must refuse rather than assume empty
function DB.Progress(cid)
    if cache[cid] then return cache[cid] end
    if not DB.ready then return nil end
    local ok, rows = pcall(MySQL.query.await, 'SELECT kind, name, value FROM rsg_npcdialog_progress WHERE citizenid = ?', { cid })
    if not ok or not rows then return nil end
    if cache[cid] then return cache[cid] end -- another thread loaded it while we waited
    local p = { flag = {}, once = {}, cd = {} }
    for _, r in ipairs(rows) do
        if p[r.kind] then p[r.kind][r.name] = tonumber(r.value) end
    end
    cache[cid] = p
    return p
end

-- cache first (so checks see it immediately), then write
function DB.Set(cid, kind, name, value)
    local p = DB.Progress(cid)
    if not p then return false end
    p[kind][name] = value
    if value == nil then
        MySQL.query('DELETE FROM rsg_npcdialog_progress WHERE citizenid = ? AND kind = ? AND name = ?', { cid, kind, name })
    else
        MySQL.query('INSERT INTO rsg_npcdialog_progress (citizenid, kind, name, value) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
            { cid, kind, name, value })
    end
    return true
end

function DB.Reset(cid, npcId)
    if not DB.ready then return false end
    if npcId then
        -- '_' is a LIKE wildcard, so compare the prefix exactly
        local prefix = npcId .. ':'
        MySQL.query.await("DELETE FROM rsg_npcdialog_progress WHERE citizenid = ? AND kind IN ('once','cd') AND LEFT(name, ?) = ?",
            { cid, #prefix, prefix })
    else
        MySQL.query.await('DELETE FROM rsg_npcdialog_progress WHERE citizenid = ?', { cid })
        MySQL.query.await('DELETE FROM rsg_npcdialog_quest_progress WHERE citizenid = ?', { cid })
        questCache[cid] = nil
    end
    cache[cid] = nil
    return true
end

function DB.Unload(cid) cache[cid], questCache[cid] = nil, nil end
