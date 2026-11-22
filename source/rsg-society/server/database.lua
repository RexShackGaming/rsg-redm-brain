-- Namespace shared by every server file of this resource.
Soc = {
    S = {},            -- [society name] = { name, type, label, color, tag, owner, balance (cents), payroll }
    Ranks = {},        -- [society name] = { [level] = { name, payment (cents), boss } }   gang ranks only
    Perms = {},        -- [society name] = { [level] = { perm = true } }                    permission overrides
    Members = {},      -- [society name] = { [citizenid] = { level, name } }               gang members only
    GangOf = {},       -- [citizenid] = gang society name
    Locations = {},    -- [id] = { id, name, society, coords, showblip, db }
    Ready = false,
}

local function printErr(msg) print(('^1[rsg-society] %s^7'):format(msg)) end
local function printOk(msg) print(('^2[rsg-society] %s^7'):format(msg)) end

--- Runs every statement of install.sql (CREATE TABLE IF NOT EXISTS), so the database and the file never drift apart.
local function ensureDatabase()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'install.sql')
    if not sql or sql == '' then
        printErr('install.sql is missing, cannot build the database')
        return false
    end

    -- drop comment lines, then split on the semicolon that ends each statement
    local cleaned = {}
    for line in (sql .. '\n'):gmatch('(.-)\r?\n') do
        if not line:match('^%s*%-%-') then cleaned[#cleaned + 1] = line end
    end
    local body = table.concat(cleaned, '\n')

    local ok, err = pcall(function()
        for raw in body:gmatch('([^;]+);') do
            local statement = raw:gsub('^%s+', ''):gsub('%s+$', '')
            if statement ~= '' then MySQL.query.await(statement) end
        end
    end)
    if not ok then
        printErr(('database setup failed: %s'):format(tostring(err)))
        return false
    end
    printOk('database tables ready')
    return true
end

Soc.EnsureDatabase = ensureDatabase
