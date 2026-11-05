-- What a caller may assume about the database when an error is raised locally.
-- Errors coming from the driver carry their own outcome (see bridge/errors.js).
local defaultOutcome = {
    INVALID_ARGUMENT = 'not_executed', INVALID_CONTEXT = 'not_executed', UNAVAILABLE = 'not_executed',
    RESULT_TYPE = 'executed', RESOURCE_STOPPED = 'unknown', BRIDGE_ERROR = 'unknown',
}

function FeatherMySQL.error(code, message, resource, method, id, driverCode, extra)
    if type(extra) ~= 'table' then extra = {} end
    return {
        code = code, message = message, resource = resource,
        method = method, queryId = id, driverCode = driverCode,
        outcome = type(extra.outcome) == 'string' and extra.outcome or defaultOutcome[code],
        sqlState = type(extra.sqlState) == 'string' and extra.sqlState or nil,
        detail = type(extra.detail) == 'string' and extra.detail or nil,
        rollbackConfirmed = extra.rollbackConfirmed == true,
        rollbackError = type(extra.rollbackError) == 'table' and extra.rollbackError or nil,
    }
end
