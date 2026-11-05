'use strict';

// Only this file knows about Cfx. Required modules are ordinary Node modules.
const resource = GetCurrentResourceName();
const root = GetResourcePath(resource);
const tag = `[${resource}]`;
const { parseConnectionString, connectionOptions, integer, ConfigError } = require(`${root}/bridge/config.js`);
const { Driver } = require(`${root}/bridge/driver.js`);
const { publicError } = require(`${root}/bridge/errors.js`);

// Side connections used to cancel abandoned statements are bounded so a database
// that is already struggling is not also flooded with kill attempts.
const MAX_CONCURRENT_KILLS = 2;
const KILL_CONNECT_TIMEOUT_MS = 2000;

let driver;
let errorDetail = false;
let activeKills = 0;

// Closing the client socket does not stop a statement that is already running,
// so a timed-out UPDATE could still be applied afterwards. KILL QUERY interrupts
// it. The user may always kill their own threads; failure is tolerated.
async function killQuery(mysql, config, threadId) {
    if (!Number.isSafeInteger(threadId) || threadId < 1 || activeKills >= MAX_CONCURRENT_KILLS) return;
    activeKills++;
    let connection;
    try {
        connection = await mysql.createConnection({ ...connectionOptions(config), connectTimeout: KILL_CONNECT_TIMEOUT_MS });
        await connection.query(`KILL QUERY ${threadId}`);
    } catch (_) { /* Best effort: the client side is already cancelled. */ }
    finally {
        activeKills--;
        try { connection?.destroy(); } catch (_) { /* nothing left to release */ }
    }
}

try {
    const mysql = require(`${root}/node_modules/mysql2/promise`);
    const config = parseConnectionString(GetConvar('mysql_connection_string', ''));
    const timeout = integer(GetConvar('feather_mysql_query_timeout_ms', '30000'), 30000, 1, 300000, 'feather_mysql_query_timeout_ms');
    // The _ms name is canonical; the older unsuffixed convar is still honoured.
    const transactionTimeout = integer(
        GetConvar('feather_mysql_transaction_timeout_ms', '') || GetConvar('feather_mysql_transaction_timeout', '10000'),
        10000, 1, 300000, 'feather_mysql_transaction_timeout_ms');
    const cleanupTimeout = integer(GetConvar('feather_mysql_cleanup_timeout_ms', '5000'), 5000, 1, 60000, 'feather_mysql_cleanup_timeout_ms');
    // Transaction duration includes every statement and time spent in the Lua callback.
    // Give it its own warning threshold instead of applying the single-query threshold.
    const slowTransactionMs = integer(GetConvar('feather_mysql_slow_transaction_ms', '1000'),
        1000, 0, 3600000, 'feather_mysql_slow_transaction_ms');
    // 0 removes the per-resource limit; by default one resource may use at most
    // half of the pool for transactions, which hold a connection while Lua runs.
    const transactionCap = integer(GetConvar('feather_mysql_max_transactions_per_resource', ''),
        Math.max(1, Math.floor(config.connectionLimit / 2)), 0, 1000, 'feather_mysql_max_transactions_per_resource');
    const devMode = GetConvar('feather_mysql_devmode', 'false') === 'true';
    const logTransactions = GetConvar('feather_mysql_log_transactions', String(devMode)) === 'true';
    errorDetail = GetConvar('feather_mysql_error_detail', 'false') === 'true';
    // Off by default: retrying replays the statement (or, for a Lua DB.transaction, the whole
    // callback) as-is, which is only safe when the caller has no side effects outside the database.
    const retryDeadlocks = GetConvar('feather_mysql_retry_deadlocks', 'false') === 'true';
    const retryDeadlocksMax = integer(GetConvar('feather_mysql_retry_deadlocks_max', '3'), 3, 0, 20, 'feather_mysql_retry_deadlocks_max');
    driver = new Driver(mysql.createPool(config), timeout, transactionTimeout, entry => {
        const finished = entry.event === 'COMMIT' || entry.event === 'ROLLBACK' || entry.event === 'ABORT';
        const slow = finished && slowTransactionMs > 0 && entry.durationMs >= slowTransactionMs;
        if (logTransactions || entry.code || slow) {
            setImmediate(() => console.log(`${tag} TX ${JSON.stringify(slow ? { ...entry, slow: true } : entry)}`));
        }
    }, {
        maxTransactionsPerOwner: transactionCap || Infinity,
        cleanupTimeoutMs: cleanupTimeout,
        killQuery: threadId => killQuery(mysql, config, threadId),
        sessionOptions: { database: config.database, charset: config.charset },
        retryDeadlocks, retryDeadlocksMax,
    });
    console.log(`${tag} Driver configured (pool ${config.connectionLimit}, queue ${config.queueLimit}).`);
    if (devMode) console.log(`${tag} Devmode is on: logging every query and transaction. Turn it off for production.`);
    // Reach the database once at start (retrying while it is down) so readiness
    // is known, and report it once instead of on the first unlucky query. Once reachable, keep
    // probing periodically for the life of the driver -- otherwise readiness()/healthState()
    // would only ever reflect this first connection, never a later outage or recovery.
    driver.awaitDatabase((ready, code, attempt) => {
        if (ready) console.log(`${tag} Database reachable${attempt > 1 ? ` after ${attempt} attempts` : ''}.`);
        else console.error(`${tag} Database not reachable yet (${code}); retrying.`);
    }).then(ready => {
        if (!ready) return;
        driver.monitor((nowReady, code) => {
            console.log(nowReady ? `${tag} Database reachable again.` : `${tag} Database unreachable (${code}).`);
        }).catch(() => {});
    }).catch(() => {});
} catch (error) {
    console.error(`${tag} CONFIG_ERROR: ${error instanceof ConfigError
        ? error.message : 'check mysql_connection_string and the npm ci installation'}`);
}

// Runs `work`, then hands the outcome to the Lua callback on a later turn so the
// function reference is invoked from the Cfx main thread.
function answer(callback, work) {
    const deliver = response => setImmediate(() => {
        try { callback(response); }
        catch (_) { console.error(`${tag} Lua response callback unavailable.`); }
    });
    try {
        Promise.resolve(work()).then(
            value => deliver({ ok: true, value }),
            error => deliver({ ok: false, error: publicError(error, { detail: errorDetail }) }),
        );
    } catch (error) { deliver({ ok: false, error: publicError(error, { detail: errorDetail }) }); }
}

// Internal exports: consumers must go through Lua validation and attribution.
// A refused caller is answered rather than ignored, so a legitimate caller can
// never end up waiting forever on a request that was silently dropped.
function dispatch(callback, operation) {
    if (typeof callback !== 'function') return;
    if (GetInvokingResource() !== resource) return answer(callback, () => Promise.reject({ code: 'INVALID_CALLER' }));
    if (!driver) return answer(callback, () => Promise.reject({ code: 'CONFIG_ERROR' }));
    answer(callback, () => operation(driver));
}

function parameters(request) {
    const values = [];
    for (let i = 0; i < request.count; i++) {
        const parameter = request.parameters[i];
        values.push(parameter.isNull === true ? null : parameter.value);
    }
    return values;
}

exports('DriverExecuteV1', (request, callback) => {
    dispatch(callback, db => db.run(request.sql, parameters(request), request.resource || resource));
});
exports('DriverTransactionBeginV1', (owner, callback) => {
    dispatch(callback, db => db.begin(owner));
});
exports('DriverTransactionQueryV1', (owner, id, request, callback) => {
    dispatch(callback, db => db.transactionQuery(owner, id, request.sql, parameters(request)));
});
exports('DriverTransactionBatchV1', (owner, id, batch, callback) => {
    dispatch(callback, db => {
        if (!batch || !Number.isInteger(batch.count) || batch.count < 1 || batch.count > 32) {
            throw { code: 'INVALID_ARGUMENT' };
        }
        const statements = [];
        for (let i = 0; i < batch.count; i++) {
            const request = batch.statements[i];
            statements.push({ sql: request.sql, parameters: parameters(request) });
        }
        return db.transactionBatch(owner, id, statements);
    });
});
exports('DriverTransactionFinishV1', (owner, id, commit, callback) => {
    dispatch(callback, db => db.finish(owner, id, commit));
});
exports('DriverReadyV1', callback => {
    dispatch(callback, db => db.readiness());
});

// Startup self-check (no database needed): returns the value shapes a query
// result contains so Lua can confirm the Cfx boundary carries them intact and
// that the caller identity assumption holds.
exports('DriverSelfCheckV1', callback => {
    if (typeof callback !== 'function') return;
    if (GetInvokingResource() !== resource) return answer(callback, () => Promise.reject({ code: 'INVALID_CALLER' }));
    answer(callback, () => {
        const row = Object.create(null);
        row.text = 'héllo \u{1F600} 日本語';
        row.number = 42; row.nothing = null; row.bytes = [0, 255]; row.big = '9007199254740993'; row.flag = false;
        return { kind: 'rows', rows: [row], firstColumn: 'text', first: row.text };
    });
});

// Diagnostic queue only: normal database completions still use answer().
// Start/stop the CFX ticker from main-thread export/tick/stop callbacks, never
// from an asynchronous I/O completion. Empty diagnostics leave no active ticker.
const PROBE_QUEUE_LIMIT = 16;
const PROBE_TICK_BATCH = 8;
let probeTick = null;
let probePending = 0;
let probeQueue = [];
let probeStopped = false;
function startProbeTick() {
    if (probeTick !== null) return;
    probeTick = setTick(() => {
        // Snapshot the batch so callback reentry cannot drain new work recursively.
        const batch = probeQueue.splice(0, PROBE_TICK_BATCH);
        for (const work of batch) {
            if (probeStopped) break;
            probePending--;
            work(); // deliver() isolates a callback exception.
        }
        if (probePending === 0 && probeTick !== null) {
            clearTick(probeTick);
            probeTick = null;
        }
    });
}
function stopProbeTick() {
    probeStopped = true;
    if (probeTick !== null) clearTick(probeTick);
    probeTick = null;
    probePending = 0;
    probeQueue = [];
}

// Fixed no-I/O scheduling diagnostic; private to this resource. Inline delivery
// is safe only here, while still inside the original main-thread export call.
// Never use that branch for asynchronous driver/database completion.
exports('DriverSchedulingProbeV1', (mode, callback) => {
    if (typeof callback !== 'function') return;
    if (GetInvokingResource() !== resource) return answer(callback, () => Promise.reject({ code: 'INVALID_CALLER' }));
    if (!['inline', 'immediate', 'promise_immediate', 'tick', 'promise_tick'].includes(mode)) {
        return answer(callback, () => Promise.reject({ code: 'INVALID_ARGUMENT' }));
    }
    const started = Date.now();
    const deliver = (promiseMs, queued) => {
        const value = { mode, probe: true, flag: false, promiseMs, queueMs: Date.now() - queued };
        try { callback({ ok: true, value }); }
        catch (_) { console.error(`${tag} Scheduling probe callback unavailable.`); }
    };
    if (mode === 'tick' || mode === 'promise_tick') {
        if (probeStopped) return answer(callback, () => Promise.reject({ code: 'PROBE_STOPPED' }));
        if (probePending >= PROBE_QUEUE_LIMIT) return answer(callback, () => Promise.reject({ code: 'PROBE_BUSY' }));
        probePending++;
        try { startProbeTick(); }
        catch (_) {
            probePending--;
            return answer(callback, () => Promise.reject({ code: 'PROBE_SCHEDULER_UNAVAILABLE' }));
        }
        const enqueue = () => {
            if (probeStopped) return; // resource stopped before the promise resumed.
            const queued = Date.now();
            const promiseMs = mode === 'promise_tick' ? queued - started : 0;
            probeQueue.push(() => deliver(promiseMs, queued));
        };
        if (mode === 'tick') enqueue();
        else Promise.resolve().then(enqueue);
        return;
    }
    if (mode === 'inline') return deliver(0, Date.now());
    if (mode === 'immediate') {
        const queued = Date.now();
        return setImmediate(() => deliver(0, queued));
    }
    Promise.resolve().then(() => {
        const queued = Date.now();
        setImmediate(() => deliver(queued - started, queued));
    });
});

// One command per provider name, so two providers can coexist on a server.
RegisterCommand(`${resource.replace(/[^A-Za-z0-9]+/g, '_')}_diagnostics`, source => {
    if (source !== 0) return;
    console.log(`${tag} ${JSON.stringify(driver ? driver.diagnostics() : { code: 'CONFIG_ERROR' })}`);
}, true);

on('onResourceStop', name => {
    if (name === resource) stopProbeTick();
    if (!driver) return;
    if (name === resource) driver.close().catch(() => console.error(`${tag} Pool shutdown failed.`));
    else driver.abortOwner(name);
});
