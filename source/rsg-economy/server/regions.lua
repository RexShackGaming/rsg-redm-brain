-- rsg-economy: towns edited in the admin panel. They are saved in the database and applied over Config.Regions.
-- Towns from shared/config.lua can be overridden (and put back); towns made here can be removed once their treasury is empty.
RSGEcon = RSGEcon or {}

-- the config's own towns, so an override can be undone
local base = {}
for id, r in pairs(Config.Regions) do
    local officials = {}
    for i, o in ipairs(r.officials or {}) do officials[i] = { job = o.job, minGrade = o.minGrade } end
    base[id] = { label = r.label, order = r.order, coords = r.coords, lawJob = r.lawJob, officials = officials }
end

local function copyBase(id)
    local b = base[id]
    local officials = {}
    for i, o in ipairs(b.officials) do officials[i] = { job = o.job, minGrade = o.minGrade } end
    return { label = b.label, order = b.order, coords = b.coords, lawJob = b.lawJob, officials = officials }
end

local function text(s, max)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('%c', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    local len = utf8.len(s)
    if not len or len < 1 then return nil end
    if len > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

local function jobName(s)
    if type(s) ~= 'string' or #s < 1 or #s > 50 or not s:match('^[%w_%-]+$') then return nil end
    return s
end

-- turns a database row into a live town
function RSGEcon.ApplyRegionRow(r)
    local ok, list = pcall(json.decode, r.officials or '[]')
    local officials = {}
    if ok and type(list) == 'table' then
        for _, o in ipairs(list) do
            if jobName(o.job) then officials[#officials + 1] = { job = o.job, minGrade = tonumber(o.minGrade) or 0 } end
        end
    end
    local law = r.law_job
    Config.Regions[r.id] = {
        label = r.label, order = tonumber(r.ord) or 99, coords = vector3(tonumber(r.x) or 0.0, tonumber(r.y) or 0.0, tonumber(r.z) or 0.0),
        lawJob = (type(law) == 'string' and law ~= '') and law or nil, officials = officials,
        custom = base[r.id] == nil, overridden = base[r.id] ~= nil,
    }
end

-- list for the admin tab
function RSGEcon.AdminList()
    local out = {}
    for id, r in pairs(Config.Regions) do
        local officials = {}
        for i, o in ipairs(r.officials or {}) do officials[i] = { job = o.job, minGrade = o.minGrade } end
        out[#out + 1] = {
            id = id, label = r.label, order = r.order or 99, lawJob = r.lawJob or '',
            x = r.coords and r.coords.x or 0.0, y = r.coords and r.coords.y or 0.0, z = r.coords and r.coords.z or 0.0,
            officials = officials, custom = base[id] == nil, overridden = r.overridden == true,
        }
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    return out
end

-- returns ok, message key (a locale key, ready for locale())
function RSGEcon.AdminSaveRegion(src, data)
    if type(data) ~= 'table' then return false, 'msg_region_invalid' end
    local id = type(data.id) == 'string' and data.id:lower() or ''
    if #id < 2 or #id > 30 or not id:match('^[a-z0-9_]+$') then return false, 'msg_region_invalid' end
    local label = text(data.label, 40)
    if not label then return false, 'msg_region_invalid' end
    local order = math.floor(tonumber(data.order) or 99)
    if order < 1 or order > 999 then return false, 'msg_region_invalid' end

    local lawJob = ''
    if data.lawJob ~= nil and data.lawJob ~= '' then
        lawJob = jobName(data.lawJob)
        if not lawJob then return false, 'msg_region_invalid' end
    end

    local officials = {}
    if type(data.officials) ~= 'table' or #data.officials > 6 then return false, 'msg_region_invalid' end
    for _, o in ipairs(data.officials) do
        local job = type(o) == 'table' and jobName(o.job)
        local grade = type(o) == 'table' and tonumber(o.minGrade)
        if not job or not grade or grade < 0 or grade > 50 or grade % 1 ~= 0 then return false, 'msg_region_invalid' end
        officials[#officials + 1] = { job = job, minGrade = grade }
    end

    local current = Config.Regions[id]
    local x, y, z
    if data.useMyPosition == true then
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false, 'msg_region_invalid' end
        local c = GetEntityCoords(ped)
        x, y, z = c.x, c.y, c.z
    elseif current and current.coords then
        x, y, z = current.coords.x, current.coords.y, current.coords.z
    else
        return false, 'msg_region_invalid' -- a new town needs a position
    end

    local ok = pcall(function()
        MySQL.insert.await('INSERT INTO rsg_economy_region (id, label, ord, x, y, z, law_job, officials) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE label = VALUES(label), ord = VALUES(ord), x = VALUES(x), y = VALUES(y), z = VALUES(z), law_job = VALUES(law_job), officials = VALUES(officials)',
            { id, label, order, x, y, z, lawJob ~= '' and lawJob or nil, json.encode(officials) })
    end)
    if not ok then return false, 'msg_failed' end

    RSGEcon.ApplyRegionRow({ id = id, label = label, ord = order, x = x, y = y, z = z, law_job = lawJob, officials = json.encode(officials) })
    pcall(RSGEcon.SyncProjects)
    return true, 'msg_region_saved', label
end

function RSGEcon.AdminDeleteRegion(id)
    local r = type(id) == 'string' and Config.Regions[id]
    if not r then return false, 'msg_region_invalid' end
    if base[id] then
        -- a town from the config: drop the override and go back to the config values
        if not r.overridden then return false, 'msg_region_invalid' end
        local ok = pcall(function() MySQL.query.await('DELETE FROM rsg_economy_region WHERE id = ?', { id }) end)
        if not ok then return false, 'msg_failed' end
        Config.Regions[id] = copyBase(id)
        return true, 'msg_region_restored', Config.Regions[id].label
    end
    if (RSGEcon.Treasury[id] or 0) >= 1 then return false, 'msg_region_not_empty' end
    local ok = pcall(function() MySQL.query.await('DELETE FROM rsg_economy_region WHERE id = ?', { id }) end)
    if not ok then return false, 'msg_failed' end
    local label = r.label
    Config.Regions[id] = nil
    pcall(RSGEcon.SyncProjects)
    return true, 'msg_region_deleted', label
end
