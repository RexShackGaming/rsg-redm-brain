local RSGCore = Soc.Core

-- Brings the data of the old resources over. It only ever reads their tables and writes society tables:
-- nothing is deleted, and every step runs once (re-running skips whatever already exists).

local function getMeta(key)
    return MySQL.scalar.await('SELECT v FROM rsg_society_meta WHERE k = ? LIMIT 1', { key })
end
local function setMeta(key, value)
    MySQL.insert.await('INSERT INTO rsg_society_meta (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)', { key, tostring(value) })
end
local function tableExists(name)
    return (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })) or 0) > 0
end
local function say(msg) print(('^3[rsg-society] migration: %s^7'):format(msg)) end

local function decode(text)
    if type(text) ~= 'string' or text == '' then return nil end
    local ok, value = pcall(json.decode, text)
    return ok and value or nil
end

-----------------------------------------------------------------------
-- rsg-bossmenu and rsg-gangmenu accounts (management_funds)
-----------------------------------------------------------------------
local function importFunds()
    local gangFunds = {}
    if not tableExists('management_funds') then return gangFunds end
    local imported = 0
    for _, row in ipairs(MySQL.query.await('SELECT job_name, amount, type FROM management_funds') or {}) do
        local cents = math.floor((tonumber(row.amount) or 0) * 100 + 0.5)
        if row.type == 'gang' then
            gangFunds[row.job_name] = cents
        elseif not Soc.JobExists(row.job_name) then
            say(('boss account "%s" skipped: no such job in rsg-core'):format(row.job_name))
        else
            local job = Soc.JobDef(row.job_name)
            if not Soc.S[row.job_name] then
                Soc.RegisterRow(row.job_name, 'job', job.label or row.job_name, { await = true })
            end
            -- a society for this job may already exist (created from Config.Jobs), so the old balance is added once
            local done = MySQL.scalar.await("SELECT 1 FROM rsg_society_ledger WHERE society = ? AND kind = 'migration' AND note = 'rsg-bossmenu' LIMIT 1", { row.job_name })
            if cents > 0 and not done then
                MySQL.update.await('UPDATE rsg_societies SET balance_cents = balance_cents + ? WHERE name = ?', { cents, row.job_name })
                local balance = tonumber(MySQL.scalar.await('SELECT balance_cents FROM rsg_societies WHERE name = ?', { row.job_name })) or cents
                MySQL.insert.await("INSERT INTO rsg_society_ledger (society, actor, kind, amount_cents, balance_cents, note) VALUES (?, 'migration', 'migration', ?, ?, ?)", { row.job_name, cents, balance, 'rsg-bossmenu' })
                imported = imported + 1
            end
        end
    end
    if imported > 0 then say(('%d boss account(s) imported'):format(imported)) end
    return gangFunds
end

-----------------------------------------------------------------------
-- Gangs from rsg-core's gang table (the ones rsg-gangmenu managed)
-----------------------------------------------------------------------
local function importCoreGangs(gangFunds)
    local imported = 0
    for name, def in pairs(RSGCore.Shared.Gangs) do
        if name ~= 'none' and not Soc.S[name] and type(def) == 'table' and type(def.grades) == 'table' then
            local rows = MySQL.query.await("SELECT citizenid, charinfo, gang FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(gang, '$.name')) = ?", { name }) or {}
            local funds = gangFunds[name] or 0
            if #rows > 0 or funds > 0 then
                -- ranks follow the core grades, level by level
                local levels = {}
                for key in pairs(def.grades) do
                    if tonumber(key) then levels[#levels + 1] = tonumber(key) end
                end
                table.sort(levels)
                local defs, levelAt = {}, {}
                for i, level in ipairs(levels) do
                    local g = def.grades[tostring(level)] or def.grades[level]
                    defs[i] = { name = g.name or tostring(level), payment = tonumber(g.payment) or 0, perms = Config.Migration.ImportedRankPerms, boss = g.isboss == true }
                    levelAt[level] = i - 1
                end
                if #defs > 0 then
                    local owner
                    Soc.RegisterRow(name, 'gang', def.label or name, { color = Config.Gang.Colors[1], balance = funds, await = true })
                    Soc.Members[name] = {}
                    Soc.SeedRanks(name, defs, true)
                    for _, p in ipairs(rows) do
                        local gang = decode(p.gang) or {}
                        local lvl = levelAt[tonumber(gang.grade and gang.grade.level) or 0] or 0
                        local info = decode(p.charinfo)
                        MySQL.insert.await('INSERT INTO rsg_society_members (citizenid, society, level, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE society = VALUES(society), level = VALUES(level), name = VALUES(name)', { p.citizenid, name, lvl, Soc.Trunc(Soc.FullName(info), 100) })
                        if defs[lvl + 1] and defs[lvl + 1].boss and not owner then owner = p.citizenid end
                    end
                    if owner then MySQL.update.await('UPDATE rsg_societies SET owner = ? WHERE name = ?', { owner, name }) end
                    if funds > 0 then
                        MySQL.insert.await("INSERT INTO rsg_society_ledger (society, actor, kind, amount_cents, balance_cents, note) VALUES (?, 'migration', 'migration', ?, ?, ?)", { name, funds, funds, 'rsg-gangmenu' })
                    end
                    imported = imported + 1
                end
            end
        end
    end
    if imported > 0 then say(('%d rsg-core gang(s) imported'):format(imported)) end
end

-----------------------------------------------------------------------
-- rsg-gangs (its own tables)
-----------------------------------------------------------------------
local function normaliseRank(name)
    return (tostring(name):lower():gsub('[^%w]', ''))
end

local function importRsgGangs()
    if not tableExists('rsg_gangs') then return end
    local levelOf = {}
    for i, r in ipairs(Config.Gang.DefaultRanks) do levelOf[normaliseRank(r.name)] = i - 1 end

    local imported = 0
    for _, g in ipairs(MySQL.query.await('SELECT name, label, color, bank, owner, tag, created_at FROM rsg_gangs') or {}) do
        if Soc.S[g.name] then
            say(('rsg-gangs gang "%s" skipped: a society with that name already exists'):format(g.name))
        else
            local cents = math.floor((tonumber(g.bank) or 0) * 100 + 0.5)
            Soc.RegisterRow(g.name, 'gang', g.label, { color = g.color, tag = g.tag, owner = g.owner, balance = cents, payroll = Config.Payroll.DefaultGangPayroll, await = true })
            Soc.Members[g.name] = {}
            Soc.SeedRanks(g.name, Config.Gang.DefaultRanks, true)

            local members = 0
            for _, m in ipairs(MySQL.query.await('SELECT citizenid, `rank`, name, joined_at FROM rsg_gang_members WHERE gang_name = ?', { g.name }) or {}) do
                local level = levelOf[normaliseRank(m.rank)]
                if level == nil then
                    say(('member %s of "%s" has the unknown rank "%s" and was set to the lowest rank'):format(m.citizenid, g.name, tostring(m.rank)))
                    level = 0
                end
                MySQL.insert.await('INSERT INTO rsg_society_members (citizenid, society, level, name, joined_at) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE society = VALUES(society), level = VALUES(level), name = VALUES(name)', { m.citizenid, g.name, level, Soc.Trunc(m.name, 100), m.joined_at })
                members = members + 1
            end
            if cents > 0 then
                MySQL.insert.await("INSERT INTO rsg_society_ledger (society, actor, kind, amount_cents, balance_cents, note) VALUES (?, 'migration', 'migration', ?, ?, ?)", { g.name, cents, cents, 'rsg-gangs' })
            end
            if tableExists('rsg_gang_logs') then
                MySQL.update.await('INSERT INTO rsg_society_audit (society, actor_name, action, target_cid, detail, created_at) SELECT gang_name, actor, action, citizenid, detail, created_at FROM rsg_gang_logs WHERE gang_name = ? ORDER BY id DESC LIMIT 1000', { g.name })
            end
            imported = imported + 1
            say(('rsg-gangs gang "%s" imported (%d members)'):format(g.name, members))
        end
    end
    if imported > 0 then say(('%d rsg-gangs gang(s) imported. rsg-gangs keeps its own copy; see DOCS.md before running both'):format(imported)) end
end

-----------------------------------------------------------------------
-- Run
-----------------------------------------------------------------------
function Soc.Migrate(force)
    if not Config.Migration.Enabled then return end
    local changed = false
    local gangFunds = {}

    if Config.Migration.ImportManagementFunds and (force or getMeta('migrated_funds') ~= 'done') then
        gangFunds = importFunds()
        setMeta('migrated_funds', 'done')
        changed = true
    elseif Config.Migration.ImportCoreGangs and tableExists('management_funds') then
        for _, row in ipairs(MySQL.query.await("SELECT job_name, amount FROM management_funds WHERE type = 'gang'") or {}) do
            gangFunds[row.job_name] = math.floor((tonumber(row.amount) or 0) * 100 + 0.5)
        end
    end
    if Config.Migration.ImportCoreGangs and (force or getMeta('migrated_core_gangs') ~= 'done') then
        importCoreGangs(gangFunds)
        setMeta('migrated_core_gangs', 'done')
        changed = true
    end
    if Config.Migration.ImportRsgGangs and (force or getMeta('migrated_rsg_gangs') ~= 'done') then
        importRsgGangs()
        setMeta('migrated_rsg_gangs', 'done')
        changed = true
    end
    if changed then Soc.Load() end
end

Soc.OnStart(10, function() Soc.Migrate(false) end)
