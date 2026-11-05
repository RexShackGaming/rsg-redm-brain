FeatherMySQL = {}
local function integer(name, default, minimum)
    local value = tonumber(GetConvar(name, tostring(default)))
    assert(value and value % 1 == 0 and value >= minimum, 'Invalid convar: ' .. name)
    return value
end
local function flag(name, default)
    return GetConvar(name, default and 'true' or 'false') == 'true'
end
-- feather_mysql_devmode only changes the defaults of the log switches; one set explicitly still wins.
local devMode = flag('feather_mysql_devmode', false)
FeatherMySQL.config = {
    devMode = devMode,
    logQueries = flag('feather_mysql_log_queries', devMode),
    logSql = flag('feather_mysql_log_sql', devMode),
    slowMs = integer('feather_mysql_slow_query_ms', 200, 0),
    -- During an outage every request fails; cap the error lines per second (0 = no cap).
    errorLogLimit = integer('feather_mysql_max_error_logs_per_second', 20, 0),
}
