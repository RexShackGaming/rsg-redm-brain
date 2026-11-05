'use strict';
const { randomUUID } = require('node:crypto');
const { isStatementError } = require('./errors');

// Faults raised by the driver itself. `outcome` tells the bridge what the caller
// may assume about the database (see errors.js).
function fault(code, outcome) {
    return Object.assign(new Error(code), { code, outcome });
}

// ER_PARSE_ERROR and ER_UNSUPPORTED_PS. Both are raised while the server is preparing a statement,
// before anything runs, so trying again another way cannot apply a write twice.
const PREPARE_REFUSED = new Set([1064, 1295]);
// Standalone statements retry only after session cleanup. Transaction callbacks are retried
// by the Lua library after a confirmed ROLLBACK: a lock-wait timeout alone does not guarantee
// that the whole transaction was rolled back. Jitter reduces repeated lock collisions.
const RETRYABLE_LOCK_CODES = new Set(['ER_LOCK_DEADLOCK', 'ER_LOCK_WAIT_TIMEOUT']);
function retryDelayMs(attempt) {
    return Math.min(200, (attempt + 1) * 20) + Math.floor(Math.random() * 20);
}
// Client-side escaping backslashes quotes, which is not sound when the connection character set
// can swallow the backslash as part of a multibyte character.
const MULTIBYTE_CHARSETS = /^(gbk|gb2312|gb18030|big5|sjis|cp932|euckr|eucjpms|ujis)/i;

// How many placeholders the text protocol will substitute. Returns -1 when the statement uses `??`
// (identifier placeholders), which values must never be able to reach.
function placeholderCount(sql) {
    let count = 0;
    for (const run of sql.match(/\?+/g) ?? []) {
        if (run.length > 1) return -1;
        count++;
    }
    return count;
}

function firstValue(rows) {
    const row = rows?.[0];
    return Array.isArray(row) ? row[0] : Object.values(row ?? {})[0];
}

// Bounded recent-sample percentiles for one phase (acquiring a connection, running a statement,
// or resetting a session for reuse). A fixed-size ring buffer, not a proper streaming quantile
// estimator -- enough to answer "is this slow right now", not for long-term trend analysis.
class Latencies {
    constructor(capacity = 200) {
        this.capacity = capacity;
        this.samples = [];
        this.next = 0;
    }
    record(ms) {
        if (this.samples.length < this.capacity) this.samples.push(ms);
        else { this.samples[this.next] = ms; this.next = (this.next + 1) % this.capacity; }
    }
    percentile(p) {
        if (this.samples.length === 0) return null;
        const sorted = [...this.samples].sort((a, b) => a - b);
        return sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))];
    }
    summary() {
        return { count: this.samples.length, p50: this.percentile(0.5), p95: this.percentile(0.95), p99: this.percentile(0.99) };
    }
}
// How many of the most recent completed run() calls decide "degraded" (see healthState).
const RECENT_OUTCOMES_CAPACITY = 50;

// One lease owns one physical connection until protocol cleanup is complete.
class ConnectionLease {
    constructor(connection, onClose = () => {}, sessionOptions = {}) {
        this.connection = connection; this.closed = false; this.onClose = onClose;
        this.sessionOptions = sessionOptions;
        this.onTextFallback = () => {};
    }
    // Values are bound by the server (prepared statement). A few statements cannot be prepared with
    // a placeholder, for example SHOW COLUMNS ... LIKE ?; those are retried once as text.
    execute(sql, parameters) {
        if (this.closed) throw new Error('Connection lease is closed');
        return this.connection.execute(sql, parameters).catch(error => this.retryAsText(sql, parameters, error));
    }
    // The retry keeps every rule the prepared path had: values only, the same placeholder count, and
    // only when client-side escaping is sound on this connection. Anything else keeps the first error.
    async retryAsText(sql, parameters, error) {
        if (!PREPARE_REFUSED.has(error?.errno) || this.closed || !Array.isArray(parameters)) throw error;
        if (MULTIBYTE_CHARSETS.test(this.sessionOptions.charset ?? '')) throw error;
        if (placeholderCount(sql) !== parameters.length) throw error;
        const [modes] = await this.connection.query('SELECT @@SESSION.sql_mode');
        if (/NO_BACKSLASH_ESCAPES/i.test(String(firstValue(modes) ?? ''))) throw error;
        this.onTextFallback();
        return this.connection.query(sql, parameters);
    }
    command(sql) {
        if (this.closed) throw new Error('Connection lease is closed');
        return this.connection.query(sql);
    }
    reset() {
        if (this.closed) throw new Error('Connection lease is closed');
        // COM_RESET_CONNECTION alone does not restore the selected database,
        // and MySQL resets charset variables to server defaults. mysql2's
        // changeUser reuses its credentials, restores the configured
        // database/charset and clears session state without replacing the
        // physical connection. The startup values are passed explicitly because
        // mysql2 session tracking can mutate its own charset configuration.
        return this.connection.changeUser(this.sessionOptions);
    }
    // Server-side connection ID, used to cancel a statement that is still running.
    threadId() {
        return this.connection.threadId ?? this.connection.connection?.threadId;
    }
    release() {
        if (this.closed) return;
        try { this.connection.release(); }
        catch (error) { this.destroy(); throw error; }
        this.closed = true;
        this.onClose();
    }
    destroy() {
        if (this.closed) return;
        try { this.connection.destroy(); }
        finally {
            // mysql2 3.24.4 destroy() half-closes its stream. Retire the transport
            // too, so cancellation does not leave a client socket waiting on SQL.
            try { this.connection.connection?.stream?.destroy(); }
            finally { this.closed = true; this.onClose(); }
        }
    }
}

function plain(value) {
    // Cfx msgpack does not carry Node Buffer prototypes to Lua.
    return Buffer.isBuffer(value) ? Array.from(value) : value;
}

// Rows arrive positionally (rowsAsArray) so duplicate column names cannot
// collapse and the first column is always known. Object rows are still accepted.
function normalize(rows, fields) {
    if (Array.isArray(rows)) {
        // CALL/multiple result sets are outside the result contract.
        if (fields?.some(Array.isArray)) throw Object.assign(new Error(), { code: 'RESULT_TYPE' });
        const names = (fields || []).map(field => field.name);
        const normalized = rows.map(row => {
            const result = Object.create(null);
            if (Array.isArray(row)) {
                for (let i = 0; i < names.length; i++) result[names[i]] = plain(row[i]);
            } else {
                for (const [key, value] of Object.entries(row)) result[key] = plain(value);
            }
            return result;
        });
        const head = rows[0];
        const first = head === undefined ? null : plain(Array.isArray(head) ? head[0] : head[names[0]]);
        return { kind: 'rows', rows: normalized, firstColumn: names[0], first };
    }
    return { kind: 'write', header: {
        insertId: rows.insertId, affectedRows: rows.affectedRows,
        warningStatus: rows.warningStatus,
    } };
}

class Driver {
    // options:
    //   maxTransactionsPerOwner  concurrent transactions one resource may hold
    //   cleanupTimeoutMs         deadline for session cleanup after an answer was sent
    //   killQuery(threadId)      best-effort cancellation of a statement on the server
    //   sessionOptions           { database, charset } restored by every session cleanup
    //   retryDeadlocks           retry a standalone statement or batch() once InnoDB reports
    //                            ER_LOCK_DEADLOCK/ER_LOCK_WAIT_TIMEOUT (default off)
    //   retryDeadlocksMax        attempts on top of the first (default 3)
    constructor(pool, timeoutMs, transactionTimeoutMs = 10000, onTransaction = () => {}, options = {}) {
        this.pool = pool;
        this.timeoutMs = timeoutMs;
        this.stopped = false;
        this.active = new Set();
        this.leases = new Set();
        this.cleanups = new Set();
        this.acquiring = 0;
        this.transactions = new Map();
        this.closedTransactions = new Map();
        this.transactionTimeoutMs = transactionTimeoutMs;
        this.onTransaction = onTransaction;
        this.maxTransactionsPerOwner = options.maxTransactionsPerOwner ?? Infinity;
        this.cleanupTimeoutMs = options.cleanupTimeoutMs ?? 5000;
        this.killQuery = options.killQuery ?? null;
        this.retryDeadlocks = options.retryDeadlocks ?? false;
        this.retryDeadlocksMax = options.retryDeadlocksMax ?? 3;
        // Copied so a later change to the caller's object cannot alter cleanup.
        this.sessionOptions = { ...(options.sessionOptions ?? {}) };
        this.instance = randomUUID();
        this.sequence = 0;
        this.cleanupFailures = 0;
        this.resetFailures = 0;
        this.totals = { queries: 0, errors: 0, timeouts: 0, poolExhausted: 0, killRequests: 0, maxAcquireMs: 0, textFallbacks: 0, deadlockRetries: 0 };
        this.database = { ready: false, code: null, everReady: false };
        this.latencies = { acquire: new Latencies(), execute: new Latencies(), cleanup: new Latencies() };
        // Outcome (true/false) of each recently completed caller request (not the internal health
        // probe), oldest overwritten first. See healthState().
        this.recentOutcomes = [];
        this.readyTimer = null;
        this.wakeReady = null;
        this.closing = null;
    }
    // "Ready" means a probe has reached the database since start. Probing begins
    // only when the bridge asks for it, so a driver that is never probed (or is
    // built by a test) opens no connection. `health` is the coarser status in
    // healthState(); `ready` stays a plain boolean for existing callers.
    readiness() { return { ready: this.database.ready, code: this.database.code, health: this.healthState() }; }
    recordOutcome(ok) {
        this.recentOutcomes.push(ok);
        if (this.recentOutcomes.length > RECENT_OUTCOMES_CAPACITY) this.recentOutcomes.shift();
    }
    // starting: the database has never been reached since this driver started. unavailable: it was
    // reached before and cannot be reached right now. degraded: reachable, but a meaningful share of
    // recent caller requests (not the health probe itself) have failed. connected: none of those.
    healthState() {
        if (!this.database.ready) return this.database.everReady ? 'unavailable' : 'starting';
        const total = this.recentOutcomes.length;
        if (total >= 5) {
            const failures = this.recentOutcomes.filter(ok => !ok).length;
            if (failures / total > 0.2) return 'degraded';
        }
        return 'connected';
    }
    async probe() {
        try {
            await this.run('SELECT 1', [], 'health');
            this.database.ready = true; this.database.code = null; this.database.everReady = true;
        } catch (error) {
            this.database.ready = false;
            this.database.code = typeof error?.code === 'string' ? error.code : 'DATABASE_ERROR';
        }
        return this.database.ready;
    }
    // Interruptible sleep shared by the startup and monitor loops below: close() wakes it at once
    // instead of leaving it to run out its interval.
    sleep(ms) {
        return new Promise(resolve => {
            this.wakeReady = resolve;
            this.readyTimer = setTimeout(resolve, ms);
        });
    }
    // Probe until the database answers: one second apart, doubling up to ten.
    // report(ready, code, attempt) is called on the first failure, every tenth
    // failure after that, and on success.
    async awaitDatabase(report = () => {}) {
        for (let attempt = 1; !this.stopped; attempt++) {
            if (await this.probe()) { report(true, null, attempt); return true; }
            if (attempt === 1 || attempt % 10 === 0) report(false, this.database.code, attempt);
            await this.sleep(Math.min(10000, 1000 * 2 ** Math.min(attempt - 1, 4)));
        }
        return false;
    }
    // Keeps probing after the database first becomes reachable, so a later outage or recovery is
    // reflected in readiness()/healthState() -- not just in the failure ratio of real caller
    // traffic, which healthState() only ever raises to "degraded", and which can be slow to
    // accumulate for a low-traffic resource. Call once awaitDatabase() succeeds; runs for the
    // life of the driver. report(ready, code) is called only when reachability actually changes.
    async monitor(report = () => {}, intervalMs = 5000) {
        while (!this.stopped) {
            await this.sleep(intervalMs);
            if (this.stopped) return;
            const wasReady = this.database.ready;
            const nowReady = await this.probe();
            if (nowReady !== wasReady) report(nowReady, this.database.code);
        }
    }
    async acquire() {
        this.acquiring++;
        const started = Date.now();
        try {
            const connection = await this.pool.getConnection();
            const waited = Date.now() - started;
            if (waited > this.totals.maxAcquireMs) this.totals.maxAcquireMs = waited;
            this.latencies.acquire.record(waited);
            const lease = new ConnectionLease(connection, () => this.leases.delete(lease), this.sessionOptions);
            lease.onTextFallback = () => { this.totals.textFallbacks++; };
            this.leases.add(lease);
            return lease;
        } catch (error) {
            // The pinned mysql2 pool reports a full queue (or a full pool when it
            // does not queue) and a closed pool with uncoded errors.
            if (error?.message === 'No connections available.' || error?.message === 'Queue limit reached.') {
                error.code = 'POOL_EXHAUSTED';
                this.totals.poolExhausted++;
            } else if (error?.message === 'Pool is closed.') error.code = 'RESOURCE_STOPPED';
            throw error;
        } finally { this.acquiring--; }
    }
    // Destroy a lease. With kill, a statement that may still be executing is also
    // cancelled on the server: closing the client socket alone does not stop it.
    destroy(lease, { kill = false } = {}) {
        if (!lease || lease.closed) return;
        const threadId = kill ? lease.threadId() : undefined;
        try { lease.destroy(); }
        catch (_) { this.cleanupFailures++; }
        if (threadId && this.killQuery) {
            this.totals.killRequests++;
            try { Promise.resolve(this.killQuery(threadId)).catch(() => {}); } catch (_) { /* best effort */ }
        }
    }
    // Restore a healthy connection to the pool after the caller has been answered.
    // The connection is not lent again until the session is clean; failure or a
    // hung cleanup retires it. This can never change an answer already delivered.
    cleanup(lease) {
        const work = (async () => {
            let timer;
            const started = Date.now();
            try {
                await Promise.race([
                    lease.reset(),
                    new Promise((_, reject) => { timer = setTimeout(() => reject(fault('CLEANUP_TIMEOUT')), this.cleanupTimeoutMs); }),
                ]);
                this.latencies.cleanup.record(Date.now() - started);
                lease.release();
            } catch (_) {
                this.resetFailures++;
                this.destroy(lease);
            } finally { clearTimeout(timer); }
        })().finally(() => this.cleanups.delete(work));
        this.cleanups.add(work);
        return work;
    }
    // Resolves once every connection returned after an answer has been cleaned.
    async drain() {
        while (this.cleanups.size) await Promise.allSettled([...this.cleanups]);
    }
    run(sql, parameters, owner = 'unknown') {
        if (this.stopped) return Promise.reject(fault('RESOURCE_STOPPED', 'unknown'));
        this.totals.queries++;
        return new Promise((resolve, reject) => {
            let lease, settled = false;
            const finish = (error, result) => {
                if (settled) return;
                settled = true;
                clearTimeout(timer);
                this.active.delete(operation);
                // The health probe measures the database, not a caller; it must not count toward
                // the caller-traffic error rate healthState() uses to decide "degraded".
                if (owner !== 'health') this.recordOutcome(!error);
                if (error) { this.totals.errors++; reject(error); } else resolve(result);
            };
            const cancel = code => {
                if (code === 'QUERY_TIMEOUT') this.totals.timeouts++;
                this.destroy(lease, { kill: true });
                finish(fault(code, 'unknown'));
            };
            const operation = { owner, cancel };
            const timer = setTimeout(() => cancel('QUERY_TIMEOUT'), this.timeoutMs);
            this.active.add(operation);
            (async () => {
                // One iteration per attempt. With retryDeadlocks off, attempt 0 always finishes the
                // loop (canRetry is always false), so behavior is identical to before this existed.
                for (let attempt = 0; ; attempt++) {
                    try {
                        lease = await this.acquire();
                        // Acquisition can complete after cancellation. Never execute then.
                        if (settled) {
                            if (this.stopped) this.destroy(lease); else lease.release();
                            return;
                        }
                        let value, executeTimed = false;
                        const executeStarted = Date.now();
                        try {
                            const [rows, fields] = await lease.execute(sql, parameters);
                            this.latencies.execute.record(Date.now() - executeStarted);
                            executeTimed = true;
                            value = normalize(rows, fields);
                        } catch (error) {
                            if (!executeTimed) this.latencies.execute.record(Date.now() - executeStarted);
                            // A cancelled operation already destroyed its lease.
                            if (settled) return;
                            // The server answered with a statement error, or the result shape was
                            // unsupported: the session is intact once reset. Anything else (transport,
                            // protocol) leaves it uncertain.
                            if (isStatementError(error) || error.code === 'RESULT_TYPE') await this.cleanup(lease);
                            else this.destroy(lease);
                            const canRetry = this.retryDeadlocks && attempt < this.retryDeadlocksMax
                                && RETRYABLE_LOCK_CODES.has(error?.code);
                            if (canRetry) {
                                this.totals.deadlockRetries++;
                                await new Promise(resolve => setTimeout(resolve, retryDelayMs(attempt)));
                                if (settled) return;
                                continue;
                            }
                            finish(error);
                            return;
                        }
                        if (settled) return;
                        // Answer first: session cleanup must not delay the caller, nor
                        // turn an applied statement into a reported failure.
                        finish(null, value);
                        await this.cleanup(lease);
                        return;
                    } catch (error) {
                        finish(error);
                        return;
                    } finally {
                        if (lease && !lease.closed) this.destroy(lease);
                    }
                }
            })();
        });
    }
    logTransaction(tx, event, error) {
        try {
            this.onTransaction({ transactionId: tx.id, resource: tx.owner, event,
                durationMs: Date.now() - tx.started, queries: tx.queries, code: error?.code });
        } catch (_) { /* Diagnostics must not change database outcomes. */ }
    }
    retire(tx, error) {
        if (!tx.active) return;
        tx.active = false;
        clearTimeout(tx.timer);
        this.transactions.delete(tx.id);
        this.closedTransactions.set(tx.id, { owner: tx.owner, error });
        // Keep bounded tombstones for late timeout/error replies, never connections.
        if (this.closedTransactions.size > 1024) this.closedTransactions.delete(this.closedTransactions.keys().next().value);
    }
    abort(tx, error) {
        if (!tx.active) return;
        tx.failure = error;
        if (error.code === 'TRANSACTION_TIMEOUT') this.totals.timeouts++;
        // A statement still running on the server is cancelled with the connection.
        this.destroy(tx.lease, { kill: tx.busy });
        this.retire(tx, error);
        tx.rejectCancellation(error);
        this.logTransaction(tx, 'ABORT', error);
    }
    // The deadline fires from a timer, so the outcome is decided when it fires:
    // only a COMMIT that was already sent can have an unknown result.
    armDeadline(tx) {
        clearTimeout(tx.timer);
        tx.timer = setTimeout(() => this.abort(tx,
            fault('TRANSACTION_TIMEOUT', tx.phase === 'commit' ? 'unknown' : 'rolled_back')), this.transactionTimeoutMs);
    }
    transaction(owner, id) {
        const tx = this.transactions.get(id);
        const closed = this.closedTransactions.get(id);
        if ((tx || closed) && (tx || closed).owner !== owner) throw fault('TRANSACTION_OWNER', 'not_executed');
        if (!tx) throw closed?.error || fault('TRANSACTION_CLOSED', 'not_executed');
        return tx;
    }
    ownedBy(owner) {
        let count = 0;
        for (const tx of this.transactions.values()) if (tx.owner === owner) count++;
        return count;
    }
    race(tx, work) { return Promise.race([work, tx.cancellation]); }
    async begin(owner) {
        if (this.stopped) throw fault('RESOURCE_STOPPED', 'unknown');
        // One resource holding every connection would starve all the others.
        if (this.ownedBy(owner) >= this.maxTransactionsPerOwner) throw fault('TRANSACTION_LIMIT', 'not_executed');
        const tx = { id: `${this.instance}:${++this.sequence}`, owner, active: true,
            started: Date.now(), phase: 'acquiring', busy: false, queries: 0 };
        tx.cancellation = new Promise((_, reject) => { tx.rejectCancellation = reject; });
        tx.cancellation.catch(() => {});
        this.armDeadline(tx);
        this.transactions.set(tx.id, tx);
        try {
            tx.lease = await this.race(tx, this.acquire().then(lease => {
                if (!tx.active) {
                    if (this.stopped) this.destroy(lease); else lease.release();
                    throw tx.failure || fault('TRANSACTION_CLOSED', 'not_executed');
                }
                tx.lease = lease;
                return lease;
            }));
            tx.phase = 'begin';
            await this.race(tx, tx.lease.command('START TRANSACTION'));
            tx.phase = 'active';
            this.logTransaction(tx, 'BEGIN');
            return { id: tx.id };
        } catch (error) { this.abort(tx, error); throw error; }
    }
    async transactionQuery(owner, id, sql, parameters, batchToken) {
        const tx = this.transaction(owner, id);
        if (tx.busy || tx.phase !== 'active' || (tx.batchToken && tx.batchToken !== batchToken)) {
            const error = fault('TRANSACTION_BUSY', 'not_executed'); this.abort(tx, error); throw error;
        }
        tx.busy = true;
        tx.phase = 'query';
        try {
            const [rows, fields] = await this.race(tx, tx.lease.execute(sql, parameters));
            const value = normalize(rows, fields);
            tx.queries++;
            this.logTransaction(tx, 'QUERY');
            return value;
        } catch (error) {
            tx.busy = false;
            if (tx.active) return this.complete(tx, false, error);
            throw tx.failure || error;
        } finally {
            if (tx.active && tx.phase === 'query') { tx.busy = false; tx.phase = 'active'; }
        }
    }
    async transactionBatch(owner, id, statements) {
        if (!Array.isArray(statements) || statements.length < 1 || statements.length > 32
            || statements.some(s => !s || typeof s.sql !== 'string' || !Array.isArray(s.parameters))) {
            throw fault('INVALID_ARGUMENT', 'not_executed');
        }
        const tx = this.transaction(owner, id);
        if (tx.busy || tx.phase !== 'active' || tx.batchToken) {
            const error = fault('TRANSACTION_BUSY', 'not_executed'); this.abort(tx, error); throw error;
        }
        // Reserve across awaits and between statements. Ordinary query/finish
        // cannot interleave while one batch owns this same retained connection.
        const token = {};
        tx.batchToken = token;
        try {
            const results = [];
            for (const statement of statements) {
                results.push(await this.transactionQuery(owner, id, statement.sql, statement.parameters, token));
            }
            return results;
        } finally {
            if (tx.batchToken === token) delete tx.batchToken;
        }
    }
    // COMMIT or ROLLBACK, then hand the connection to background cleanup. The
    // work deadline stops here: finishing gets a fresh window so a transaction
    // that used its whole budget is not cut off mid-COMMIT for no reason.
    async complete(tx, commit, originalError) {
        tx.busy = true;
        tx.phase = commit ? 'commit' : 'rollback';
        this.armDeadline(tx);
        try {
            await this.race(tx, tx.lease.command(commit ? 'COMMIT' : 'ROLLBACK'));
        } catch (error) {
            if (originalError) {
                originalError.outcome = 'unknown';
                originalError.rollbackConfirmed = false;
                originalError.rollbackError = error;
            }
            this.abort(tx, originalError || error);
            throw originalError || error;
        }
        // The statement is acknowledged, so the outcome is decided. Session
        // cleanup can no longer change what the caller is told.
        const lease = tx.lease;
        if (originalError) {
            originalError.outcome = 'rolled_back';
            originalError.rollbackConfirmed = true;
        }
        this.retire(tx, originalError);
        this.logTransaction(tx, commit ? 'COMMIT' : 'ROLLBACK', originalError);
        this.cleanup(lease);
        if (originalError) throw originalError;
        return commit;
    }
    async finish(owner, id, commit) {
        const tx = this.transaction(owner, id);
        if (tx.busy || tx.phase !== 'active' || tx.batchToken) {
            const error = fault('TRANSACTION_BUSY', 'not_executed'); this.abort(tx, error); throw error;
        }
        return this.complete(tx, commit === true);
    }
    abortOwner(owner) {
        for (const operation of [...this.active]) if (operation.owner === owner) operation.cancel('RESOURCE_STOPPED');
        for (const tx of [...this.transactions.values()]) if (tx.owner === owner) this.abort(tx, fault('RESOURCE_STOPPED', 'unknown'));
    }
    diagnostics() {
        const pool = this.pool.pool;
        return { stopped: this.stopped, activeRequests: this.active.size, acquiring: this.acquiring,
            checkedOut: this.leases.size, cleaning: this.cleanups.size, transactions: this.transactions.size,
            cleanupFailures: this.cleanupFailures, resetFailures: this.resetFailures, totals: { ...this.totals },
            ready: this.database.ready, readyCode: this.database.code, health: this.healthState(),
            poolConnections: pool?._allConnections?.length ?? null,
            poolFree: pool?._freeConnections?.length ?? null, poolQueued: pool?._connectionQueue?.length ?? null,
            // Milliseconds. acquire: waiting for a free connection. execute: the statement on the
            // server. cleanup: changeUser() after an answer was already sent (see cleanup()).
            latencies: { acquireMs: this.latencies.acquire.summary(), executeMs: this.latencies.execute.summary(),
                cleanupMs: this.latencies.cleanup.summary() },
            transactionDetails: [...this.transactions.values()].map(tx => ({ id: tx.id, resource: tx.owner,
                phase: tx.phase, durationMs: Date.now() - tx.started, queries: tx.queries })) };
    }
    close() {
        if (this.closing) return this.closing;
        this.stopped = true;
        clearTimeout(this.readyTimer);
        this.wakeReady?.();
        for (const operation of [...this.active]) operation.cancel('RESOURCE_STOPPED');
        for (const tx of [...this.transactions.values()]) this.abort(tx, fault('RESOURCE_STOPPED', 'unknown'));
        // Connections still finishing session cleanup are retired with the pool.
        for (const lease of [...this.leases]) this.destroy(lease);
        this.closing = Promise.resolve().then(() => this.pool.end());
        return this.closing;
    }
}

module.exports = { Driver, ConnectionLease, normalize, Latencies };
