local windowStart, windowCount, suppressed = 0, 0, 0

-- Errors always log, but never faster than the configured rate.
local function withinErrorBudget(limit)
    if limit <= 0 then return true end
    local now = GetGameTimer()
    if now - windowStart >= 1000 or now < windowStart then
        if suppressed > 0 then
            print(('[%s] %d error log lines suppressed'):format(GetCurrentResourceName(), suppressed))
            suppressed = 0
        end
        windowStart, windowCount = now, 0
    end
    windowCount = windowCount + 1
    if windowCount > limit then suppressed = suppressed + 1; return false end
    return true
end

function FeatherMySQL.log(context, elapsed, err)
    local config = FeatherMySQL.config
    local slow = config.slowMs > 0 and elapsed >= config.slowMs
    if not (err or slow or config.logQueries) then return end
    if err and not slow and not config.logQueries and not withinErrorBudget(config.errorLogLimit) then return end
    local entry = {
        resource = context.resource, method = context.method, queryId = context.id,
        durationMs = elapsed, slow = slow, code = err and err.code or 'OK',
        driverCode = err and err.driverCode, sqlState = err and err.sqlState,
        outcome = err and err.outcome,
        -- Present only when the operator enabled feather_mysql_error_detail.
        detail = err and err.detail,
    }
    if config.logSql and type(context.sql) == 'string' then entry.sql = context.sql end
    -- Parameters, connection strings and raw driver errors are never logged.
    print(('[%s] '):format(GetCurrentResourceName()) .. json.encode(entry))
end
