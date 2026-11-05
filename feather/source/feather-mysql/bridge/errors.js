'use strict';

// What a caller may safely assume about the database after an error:
//   not_executed  the statement was never sent
//   failed        the server rejected the statement (nothing was applied by it)
//   rolled_back   a transaction was abandoned and will not commit
//   executed      the statement ran but its result shape is unsupported
//   unknown       the outcome cannot be determined (timeout, disconnect, stop)
const MAX_DETAIL = 512;

// A statement the server understood and rejected (syntax, constraint, deadlock,
// lock timeout, ...). These leave the connection usable once its session is reset.
function isStatementError(error) {
    return Number.isInteger(error?.errno) && typeof error?.sqlState === 'string'
        && /^[0-9A-Z]{5}$/.test(error.sqlState) && error.fatal !== true;
}

const KNOWN = {
    QUERY_TIMEOUT: ['Database request timed out; write outcome may be unknown', 'unknown'],
    TRANSACTION_TIMEOUT: ['Database transaction timed out; it was rolled back unless a COMMIT was in flight', 'rolled_back'],
    TRANSACTION_CLOSED: ['Database transaction is already closed', 'not_executed'],
    TRANSACTION_OWNER: ['Database transaction belongs to another resource', 'not_executed'],
    TRANSACTION_BUSY: ['Concurrent operations on one transaction are not supported', 'not_executed'],
    TRANSACTION_LIMIT: ['This resource has too many open transactions; the request was not executed', 'not_executed'],
    POOL_EXHAUSTED: ['All database connections are busy and the wait queue is full; request was not executed', 'not_executed'],
    RESOURCE_STOPPED: ['Database resource stopped; write outcome may be unknown', 'unknown'],
    CONFIG_ERROR: ['Invalid database configuration or missing mysql2 dependency', 'not_executed'],
    INVALID_CALLER: ['Only this resource may call the internal database bridge', 'not_executed'],
    RESULT_TYPE: ['Unsupported result set; statement may already have executed', 'executed'],
};

function publicError(error, { detail = false, includeRollback = true } = {}) {
    const code = error?.code;
    let result;
    if (Object.hasOwn(KNOWN, code)) {
        const [message, outcome] = KNOWN[code];
        result = { code, message, outcome };
        // A transaction that timed out mid-COMMIT has an unknown outcome.
        if (code === 'TRANSACTION_TIMEOUT' && error.outcome === 'unknown') {
            result.outcome = 'unknown';
            result.message = 'Database transaction timed out while committing; the COMMIT outcome may be unknown';
        }
    } else if (isStatementError(error)) {
        result = { code: 'DATABASE_ERROR', message: 'Database rejected the statement', outcome: 'failed', sqlState: error.sqlState };
    } else {
        result = { code: 'DATABASE_ERROR', message: 'Database operation failed; write outcome may be unknown', outcome: 'unknown' };
    }
    // Raw driver messages can contain SQL, values and credentials, so they are
    // opt-in (feather_mysql_error_detail) and never logged by default.
    if (!Object.hasOwn(KNOWN, code) && typeof code === 'string' && /^[A-Z][A-Z0-9_]{0,63}$/.test(code)) result.driverCode = code;
    if (detail && typeof error?.sqlMessage === 'string') result.detail = error.sqlMessage.slice(0, MAX_DETAIL);
    if (typeof error?.rollbackConfirmed === 'boolean') {
        result.rollbackConfirmed = error.rollbackConfirmed;
        result.outcome = error.rollbackConfirmed ? 'rolled_back' : 'unknown';
    }
    if (includeRollback && error?.rollbackError) {
        result.rollbackError = publicError(error.rollbackError, { detail, includeRollback: false });
    }
    return result;
}

module.exports = { publicError, isStatementError };
