-- rsg-mdt database setup.
-- Runs sql/mdt.sql on start (CREATE TABLE IF NOT EXISTS + INSERT IGNORE defaults), so nobody has to import it by hand.
-- Safe on every start: nothing is dropped or overwritten. Set Config.AutoDatabase = false to import sql/mdt.sql manually.

local function ensureDatabase()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/mdt.sql')
    if not sql then
        print('^1[rsg-mdt]^7 could not read sql/mdt.sql - import it manually.')
        return false
    end

    sql = sql:gsub('%-%-[^\n]*', '')
    local failed = 0
    for statement in sql:gmatch('([^;]+);') do
        local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then
            local ok, err = pcall(MySQL.query.await, trimmed)
            if not ok then
                failed = failed + 1
                print(('^1[rsg-mdt]^7 database statement failed: %s'):format(tostring(err)))
            end
        end
    end

    if failed > 0 then
        print('^1[rsg-mdt]^7 some tables could not be created automatically, import sql/mdt.sql manually.')
        return false
    end
    print('^2[rsg-mdt]^7 database tables ready.')
    return true
end

MySQL.ready(function()
    if Config.AutoDatabase == false then return end
    ensureDatabase()
end)
