'use strict';

// Deterministic lifecycle tests. The fake pool models capacity, persistent
// connection state and transaction ownership; it does not prove MySQL behavior.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { Driver } = require('../bridge/driver');

function deferred() {
    let resolve, reject;
    const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
    return { promise, resolve, reject };
}
const turn = () => new Promise(resolve => setImmediate(resolve));
const sqlError = code => Object.assign(new Error('Sensitive database detail'), { code });
const row = value => [[{ value }], [{ name: 'value' }]];
const write = () => [{ affectedRows: 1, insertId: 1 }, undefined];

// Models mysql2: with queueLimit 0 the pool rejects immediately when full
// (waitForConnections:false); otherwise waiters queue FIFO and are handed a
// connection directly when one is released or a slot frees up.
class FakePool {
    constructor(limit = 4, queueLimit = 16) {
        this.limit = limit;
        this.queueLimit = queueLimit;
        this.waiters = [];
        this.connections = [];
        this.events = [];
        this.rows = new Map();
        this.hook = async () => {};
        this.acquireHook = async () => {};
        this.getCalls = 0;
        this.endCalls = 0;
        this.closed = false;
    }

    get live() { return this.connections.filter(item => !item.destroyed).length; }

    open() {
        const connection = new FakeConnection(this, this.connections.length + 1);
        this.connections.push(connection);
        return connection;
    }

    async getConnection() {
        this.getCalls++;
        if (this.closed) throw new Error('Pool is closed.');
        let connection = this.connections.find(item => !item.busy && !item.destroyed);
        if (!connection && this.live < this.limit) connection = this.open();
        if (!connection) {
            if (!this.queueLimit) throw new Error('No connections available.');
            if (this.waiters.length >= this.queueLimit) throw new Error('Queue limit reached.');
            connection = await new Promise((resolve, reject) => this.waiters.push({ resolve, reject }));
        }
        connection.busy = true;
        await this.acquireHook(connection);
        return connection;
    }

    // A connection was released: give it to the longest-waiting request.
    handoff(connection) {
        const waiter = this.waiters.shift();
        if (waiter) { connection.busy = true; waiter.resolve(connection); }
    }

    // A connection was destroyed: a queued request may open a replacement.
    capacityFreed() {
        if (this.waiters.length && this.live < this.limit) {
            const waiter = this.waiters.shift();
            const connection = this.open();
            connection.busy = true;
            waiter.resolve(connection);
        }
    }

    async end() {
        this.endCalls++;
        this.closed = true;
        for (const waiter of this.waiters.splice(0)) waiter.reject(new Error('Pool is closed.'));
        for (const connection of this.connections) {
            if (!connection.destroyed) connection.destroy();
        }
    }

    get checkedOut() { return this.connections.filter(item => item.busy && !item.destroyed).length; }
}

class FakeConnection {
    constructor(pool, id) {
        this.pool = pool;
        this.threadId = id;
        this.busy = false;
        this.destroyed = false;
        this.releases = 0;
        this.destroys = 0;
        this.resets = 0;
        this.session = 'default';
        this.draft = null;
    }

    async command(kind, sql, parameters = []) {
        assert.equal(this.destroyed, false, 'Cannot issue a command on a retired connection');
        assert.equal(this.busy, true, 'Cannot issue a command on a free connection');
        this.pool.events.push({ kind, sql, parameters, id: this.threadId });
        await this.pool.hook({ connection: this, kind, sql, parameters });
        // Late completions after transport cancellation cannot change stored data.
        if (this.destroyed) throw sqlError('PROTOCOL_CONNECTION_LOST');
        const command = sql.toUpperCase();
        if (command === 'START TRANSACTION' || command === 'BEGIN') {
            assert.equal(this.draft, null, 'Transaction must begin on a clean connection');
            this.draft = new Map();
            return write();
        }
        if (command === 'COMMIT') {
            assert.ok(this.draft, 'COMMIT must have a transaction');
            for (const [key, value] of this.draft) this.pool.rows.set(key, value);
            this.draft = null;
            return write();
        }
        if (command === 'ROLLBACK') { this.draft = null; return write(); }
        if (command === 'WRITE') {
            (this.draft || this.pool.rows).set(parameters[0], parameters[1]);
            return write();
        }
        if (command === 'READ') {
            return row(this.draft?.has(parameters[0]) ? this.draft.get(parameters[0]) : this.pool.rows.get(parameters[0]));
        }
        if (command === 'SET SESSION') { this.session = parameters[0]; return write(); }
        if (command === 'GET SESSION') return row(this.session);
        if (command === 'CONNECTION_ID') return row(this.threadId);
        return row(parameters[0] ?? 1);
    }

    execute(sql, parameters) { return this.command('execute', sql, parameters); }
    query(sql, parameters) { return this.command('query', sql, parameters); }
    async changeUser(options) {
        this.resets++;
        await this.command('reset', 'RESET');
        this.session = 'default';
        this.draft = null;
    }
    release() {
        assert.equal(this.destroyed, false, 'Destroyed connection must not be released');
        assert.equal(this.busy, true, 'Connection must only be released once');
        this.releases++;
        this.busy = false;
        this.pool.events.push({ kind: 'release', id: this.threadId });
        this.pool.handoff(this);
    }
    destroy() {
        assert.equal(this.destroyed, false, 'Connection must only be destroyed once');
        this.destroys++;
        this.destroyed = true;
        this.busy = false;
        this.draft = null;
        this.pool.events.push({ kind: 'destroy', id: this.threadId });
        this.pool.capacityFreed();
    }
}

function fixture(t, { limit = 4, queryTimeout = 1000, transactionTimeout = 1000, queueLimit = 16, options = {} } = {}) {
    const pool = new FakePool(limit, queueLimit);
    const driver = new Driver(pool, queryTimeout, transactionTimeout, undefined, options);
    t.after(() => driver.close());
    return { pool, driver };
}

async function idle(driver, pool) {
    // Answers are sent before session cleanup, so wait for the cleanup too.
    await driver.drain();
    await turn();
    const state = driver.diagnostics();
    assert.equal(state.activeRequests, 0, 'No pending request should remain');
    assert.equal(state.acquiring, 0, 'No acquisition should remain');
    assert.equal(state.checkedOut, 0, 'No driver lease should remain');
    assert.equal(state.transactions, 0, 'No transaction should remain');
    assert.equal(pool.checkedOut, 0, 'The pool must agree that no connection is checked out');
}

function closed(error) {
    assert.ok(['TRANSACTION_CLOSED', 'TRANSACTION_TIMEOUT', 'QUERY_TIMEOUT', 'RESOURCE_STOPPED',
        'ER_PARSE_ERROR', 'ER_DUP_ENTRY', 'ER_LOCK_DEADLOCK'].includes(error.code), `Unexpected closed-handle error: ${error.code}`);
    return true;
}

test('stress: concurrent query waves return isolated results and retire every lease', async t => {
    const { pool, driver } = fixture(t, { limit: 8 });
    for (let wave = 0; wave < 12; wave++) {
        const gate = deferred();
        pool.hook = async ({ sql }) => { if (sql === 'SELECT ?') await gate.promise; };
        const pending = Array.from({ length: 8 }, (_, index) => driver.run('SELECT ?', [wave * 8 + index], `consumer-${index % 2}`));
        await turn();
        assert.equal(pool.checkedOut, 8);
        gate.resolve();
        const values = await Promise.all(pending);
        assert.deepEqual(values.map(value => value.rows[0].value), Array.from({ length: 8 }, (_, index) => wave * 8 + index));
        await idle(driver, pool);
    }
    assert.equal(pool.connections.length, 8, 'Successful waves should reuse clean connections');
    assert.equal(pool.events.filter(event => event.kind === 'execute').length, 96);
});

test('stress: a full wait queue rejects without executing and capacity returns after release', async t => {
    const { pool, driver } = fixture(t, { limit: 2, queueLimit: 1 });
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'BLOCK') await gate.promise; };
    const occupied = [driver.run('BLOCK', [1]), driver.run('BLOCK', [2])];
    await turn();
    const queued = driver.run('SELECT ?', [7]);
    await turn();
    await assert.rejects(driver.run('REJECTED', []), { code: 'POOL_EXHAUSTED' });
    assert.equal(pool.events.some(event => event.sql === 'REJECTED'), false);
    gate.resolve();
    await Promise.all(occupied);
    assert.equal((await queued).rows[0].value, 7, 'The queued request runs once a connection is free');
    assert.equal((await driver.run('SELECT ?', [9])).rows[0].value, 9);
    await idle(driver, pool);
});

test('stress: a pool that does not queue is reported as POOL_EXHAUSTED', async t => {
    const { pool, driver } = fixture(t, { limit: 1, queueLimit: 0 });
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'BLOCK') await gate.promise; };
    const occupied = driver.run('BLOCK', []);
    await turn();
    await assert.rejects(driver.run('REJECTED', []), { code: 'POOL_EXHAUSTED' });
    assert.equal(driver.diagnostics().totals.poolExhausted, 1);
    gate.resolve();
    await occupied;
    await idle(driver, pool);
});

test('stress: requests beyond the pool size wait in arrival order and all succeed', async t => {
    const { pool, driver } = fixture(t, { limit: 2, queueLimit: 100 });
    const order = [];
    pool.hook = async ({ kind, parameters }) => { if (kind === 'execute') order.push(parameters[0]); };
    const results = await Promise.all(Array.from({ length: 50 }, (_, i) => driver.run('SELECT ?', [i])));
    assert.deepEqual(results.map(result => result.rows[0].value), Array.from({ length: 50 }, (_, i) => i));
    assert.equal(pool.live <= 2, true, 'The pool never exceeds its limit');
    assert.deepEqual(order, Array.from({ length: 50 }, (_, i) => i), 'FIFO order');
    await idle(driver, pool);
});

test('stress: a queued request whose deadline passes never executes and its late connection is returned', async t => {
    const { pool, driver } = fixture(t, { limit: 1, queryTimeout: 25, transactionTimeout: 1000 });
    const holder = await driver.begin('holder');
    await assert.rejects(driver.run('MUST NOT EXECUTE', []), { code: 'QUERY_TIMEOUT' });
    assert.equal(driver.diagnostics().acquiring, 1, 'The abandoned wait stays visible until it is served');
    assert.equal(await driver.finish('holder', holder.id, false), false);
    await idle(driver, pool);
    assert.equal(pool.events.some(event => event.sql === 'MUST NOT EXECUTE'), false);
    assert.equal(pool.connections.length, 1, 'The late connection went back to the pool');
    assert.equal((await driver.run('SELECT ?', [3])).rows[0].value, 3);
    await idle(driver, pool);
});

test('stress: concurrent transactions retain distinct connections and isolated uncommitted data', async t => {
    const { pool, driver } = fixture(t, { limit: 3 });
    const transactions = await Promise.all(['a', 'b', 'c'].map(owner => driver.begin(owner)));
    const ids = await Promise.all(transactions.map((tx, index) => driver.transactionQuery('abc'[index], tx.id, 'CONNECTION_ID', [])));
    assert.equal(new Set(ids.map(value => value.rows[0].value)).size, 3);
    assert.equal(driver.diagnostics().transactions, 3);
    await Promise.all(transactions.map((tx, index) => driver.transactionQuery('abc'[index], tx.id, 'WRITE', [index, index + 10])));
    assert.equal(pool.rows.size, 0, 'No uncommitted writes should become globally visible');
    for (let index = 0; index < transactions.length; index++) {
        const value = await driver.transactionQuery('abc'[index], transactions[index].id, 'READ', [index]);
        assert.equal(value.rows[0].value, index + 10);
        const connection = await driver.transactionQuery('abc'[index], transactions[index].id, 'CONNECTION_ID', []);
        assert.equal(connection.rows[0].value, ids[index].rows[0].value);
    }
    assert.deepEqual(await Promise.all(transactions.map((tx, index) => driver.finish('abc'[index], tx.id, true))), [true, true, true]);
    assert.deepEqual([...pool.rows.values()].sort((a, b) => a - b), [10, 11, 12]);
    await idle(driver, pool);
});

test('stress: normal queries inside a transaction use a separate connection', async t => {
    const { pool, driver } = fixture(t, { limit: 2 });
    const tx = await driver.begin('consumer');
    const retained = await driver.transactionQuery('consumer', tx.id, 'CONNECTION_ID', []);
    const normal = await driver.run('CONNECTION_ID', [], 'consumer');
    assert.notEqual(normal.rows[0].value, retained.rows[0].value);
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['transaction', 1]);
    await driver.run('WRITE', ['independent', 2], 'consumer');
    assert.equal(await driver.finish('consumer', tx.id, false), false);
    assert.equal(pool.rows.has('transaction'), false);
    assert.equal(pool.rows.get('independent'), 2);
    await idle(driver, pool);
});

test('stress: explicit rollback and Lua-error cleanup restore data and return capacity', async t => {
    const { pool, driver } = fixture(t, { limit: 1 });
    pool.rows.set('balance', 100);
    // Lua callbacks returning false/nil or throwing all request rollback here.
    for (const reason of ['false', 'nil', 'Lua callback error']) {
        const tx = await driver.begin('consumer');
        await driver.transactionQuery('consumer', tx.id, 'WRITE', ['balance', reason]);
        assert.equal(await driver.finish('consumer', tx.id, false), false);
        assert.equal(pool.rows.get('balance'), 100);
        await idle(driver, pool);
    }
    assert.equal(pool.connections.length, 1);
    assert.equal(pool.events.filter(event => event.sql === 'ROLLBACK').length, 3);
});

test('stress: failed BEGIN exposes no transaction handle and returns pool capacity', async t => {
    const { pool, driver } = fixture(t, { limit: 1 });
    pool.hook = async ({ sql }) => { if (['BEGIN', 'START TRANSACTION'].includes(sql)) throw sqlError('ECONNRESET'); };
    await assert.rejects(driver.begin('consumer'), { code: 'ECONNRESET' });
    await idle(driver, pool);
    assert.equal(pool.connections[0].releases, 0);
    pool.hook = async () => {};
    const tx = await driver.begin('consumer');
    assert.equal(await driver.finish('consumer', tx.id, true), true);
});

test('stress: a transaction acquisition cannot consume a connection already reserved by another transaction', async t => {
    const { pool, driver } = fixture(t, { limit: 1, queueLimit: 0 });
    const tx = await driver.begin('consumer-a');
    await assert.rejects(driver.begin('consumer-b'), { code: 'POOL_EXHAUSTED' });
    assert.equal(driver.diagnostics().transactions, 1);
    assert.equal(await driver.finish('consumer-a', tx.id, false), false);
    await idle(driver, pool);
});

for (const code of ['ER_PARSE_ERROR', 'ER_DUP_ENTRY', 'ER_LOCK_DEADLOCK']) {
    test(`stress: ${code} fails the transaction, never retries, and cannot later commit`, async t => {
        const { pool, driver } = fixture(t, { limit: 1 });
        const tx = await driver.begin('consumer');
        await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
        pool.hook = async ({ sql }) => { if (sql === 'FAIL') throw sqlError(code); };
        await assert.rejects(driver.transactionQuery('consumer', tx.id, 'FAIL', []), { code });
        await assert.rejects(driver.finish('consumer', tx.id, true), closed);
        await assert.rejects(driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 2]), closed);
        assert.equal(pool.events.filter(event => event.sql === 'FAIL').length, 1);
        assert.equal(pool.events.some(event => event.sql === 'COMMIT'), false);
        assert.equal(pool.rows.has('key'), false);
        await idle(driver, pool);
        assert.equal((await driver.run('SELECT ?', [3])).rows[0].value, 3);
    });
}

test('stress: plain SQL failure retires its connection and a later query reconnects without retry', async t => {
    const { pool, driver } = fixture(t, { limit: 1 });
    pool.hook = async ({ sql }) => { if (sql === 'DISCONNECT') throw sqlError('PROTOCOL_CONNECTION_LOST'); };
    await assert.rejects(driver.run('DISCONNECT', []), { code: 'PROTOCOL_CONNECTION_LOST' });
    await idle(driver, pool);
    assert.equal(pool.connections[0].destroys, 1);
    assert.equal((await driver.run('SELECT ?', [8])).rows[0].value, 8);
    assert.equal(pool.connections.length, 2);
    assert.equal(pool.events.filter(event => event.sql === 'DISCONNECT').length, 1);
});

test('stress: acquisition timeout reports cleanup still pending and late acquisition never executes', async t => {
    const { pool, driver } = fixture(t, { queryTimeout: 25 });
    const gate = deferred();
    pool.acquireHook = () => gate.promise;
    await assert.rejects(driver.run('MUST NOT EXECUTE', []), { code: 'QUERY_TIMEOUT' });
    assert.equal(driver.diagnostics().acquiring, 1, 'An unsettled driver acquisition must remain visible');
    gate.resolve();
    await idle(driver, pool);
    assert.equal(pool.events.some(event => event.sql === 'MUST NOT EXECUTE'), false);
});

test('stress: query timeout destroys once and ignores late completion', async t => {
    const { pool, driver } = fixture(t, { queryTimeout: 25 });
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'WRITE') await gate.promise; };
    await assert.rejects(driver.run('WRITE', ['key', 1]), { code: 'QUERY_TIMEOUT' });
    gate.resolve();
    await idle(driver, pool);
    assert.equal(pool.connections[0].destroys, 1);
    assert.equal(pool.connections[0].releases, 0);
});

for (const cause of ['timeout', 'consumer stop']) {
    test(`stress: transaction ${cause} during acquisition never sends BEGIN on late delivery`, async t => {
        const { pool, driver } = fixture(t, { transactionTimeout: cause === 'timeout' ? 25 : 1000 });
        const gate = deferred();
        pool.acquireHook = () => gate.promise;
        const pending = driver.begin('consumer');
        const rejected = assert.rejects(pending, { code: cause === 'timeout' ? 'TRANSACTION_TIMEOUT' : 'RESOURCE_STOPPED' });
        await turn();
        if (cause === 'consumer stop') driver.abortOwner('consumer');
        await rejected;
        assert.equal(driver.diagnostics().transactions, 0);
        assert.equal(driver.diagnostics().acquiring, 1);
        gate.resolve();
        await idle(driver, pool);
        assert.equal(pool.events.some(event => event.sql === 'START TRANSACTION'), false);
        assert.equal(pool.connections[0].releases, 1);
    });
}

test('stress: overlapping operations on one transaction abort instead of racing COMMIT', async t => {
    const { pool, driver } = fixture(t);
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'BLOCK') await gate.promise; };
    const pending = driver.transactionQuery('consumer', tx.id, 'BLOCK', []);
    const rejected = assert.rejects(pending, { code: 'TRANSACTION_BUSY' });
    await turn();
    await assert.rejects(driver.finish('consumer', tx.id, true), { code: 'TRANSACTION_BUSY' });
    await rejected;
    gate.resolve();
    await idle(driver, pool);
    assert.equal(pool.rows.has('key'), false);
    assert.equal(pool.events.some(event => event.sql === 'COMMIT'), false);
});

test('stress: transaction query timeout rolls back or retires without late COMMIT', async t => {
    const { pool, driver } = fixture(t, { queryTimeout: 25, transactionTimeout: 500 });
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'BLOCK') await gate.promise; };
    await assert.rejects(driver.transactionQuery('consumer', tx.id, 'BLOCK', []), error => {
        assert.ok(['QUERY_TIMEOUT', 'TRANSACTION_TIMEOUT'].includes(error.code)); return true;
    });
    gate.resolve();
    await assert.rejects(driver.finish('consumer', tx.id, true), closed);
    assert.equal(pool.events.some(event => event.sql === 'COMMIT'), false);
    assert.equal(pool.rows.has('key'), false);
    await idle(driver, pool);
});

test('stress: idle transaction expires without a Lua caller needing to resume', async t => {
    const { pool, driver } = fixture(t, { transactionTimeout: 25 });
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
    await new Promise(resolve => setTimeout(resolve, 55));
    await assert.rejects(driver.transactionQuery('consumer', tx.id, 'SELECT 1', []), closed);
    await assert.rejects(driver.finish('consumer', tx.id, true), closed);
    assert.equal(pool.rows.has('key'), false);
    assert.equal(pool.events.some(event => event.sql === 'COMMIT'), false);
    await idle(driver, pool);
});

test('stress: timeout during COMMIT never reports success or releases an uncertain connection', async t => {
    const { pool, driver } = fixture(t, { queryTimeout: 1000, transactionTimeout: 30 });
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'COMMIT') await gate.promise; };
    await assert.rejects(driver.finish('consumer', tx.id, true), { code: 'TRANSACTION_TIMEOUT' });
    gate.resolve();
    await idle(driver, pool);
    assert.equal(pool.connections[0].destroys, 1);
    assert.equal(pool.connections[0].releases, 0);
    assert.equal(pool.events.filter(event => event.sql === 'COMMIT').length, 1);
});

test('stress: the answer is sent before session cleanup, and a dirty connection is never lent', async t => {
    const { pool, driver } = fixture(t, { limit: 1 });
    const gate = deferred();
    pool.hook = async ({ kind }) => { if (kind === 'reset') await gate.promise; };
    const answer = await driver.run('SET SESSION', ['dirty']);
    assert.equal(answer.kind, 'write', 'The caller is answered while cleanup is still running');
    assert.equal(driver.diagnostics().cleaning, 1);
    let settled = false;
    const next = driver.run('GET SESSION', []).then(result => { settled = true; return result; });
    await turn();
    assert.equal(settled, false, 'The next request waits instead of receiving the dirty connection');
    gate.resolve();
    assert.equal((await next).rows[0].value, 'default');
    await idle(driver, pool);
});

test('stress: a hung cleanup is abandoned at the cleanup deadline and the connection retired', async t => {
    const { pool, driver } = fixture(t, { limit: 1, options: { cleanupTimeoutMs: 25 } });
    pool.hook = async ({ kind }) => { if (kind === 'reset') await new Promise(() => {}); };
    await driver.run('SELECT ?', [1]);
    await idle(driver, pool);
    assert.equal(pool.connections[0].destroys, 1);
    assert.equal(pool.connections[0].releases, 0);
    assert.equal(driver.diagnostics().resetFailures, 1);
    pool.hook = async () => {};
    assert.equal((await driver.run('SELECT ?', [2])).rows[0].value, 2, 'A replacement connection serves later work');
    await idle(driver, pool);
});

test('stress: a cleanup error after success does not turn the answer into a failure', async t => {
    const { pool, driver } = fixture(t);
    pool.hook = async ({ kind }) => { if (kind === 'reset') throw sqlError('ECONNRESET'); };
    assert.equal((await driver.run('SELECT ?', [5])).rows[0].value, 5);
    await idle(driver, pool);
    assert.equal(pool.connections[0].destroys, 1);
    assert.equal(pool.connections[0].releases, 0);
    assert.equal(driver.diagnostics().resetFailures, 1);
});

test('stress: cleanup after an acknowledged COMMIT cannot change the outcome', async t => {
    const { pool, driver } = fixture(t, { transactionTimeout: 1000, options: { cleanupTimeoutMs: 25 } });
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['committed', 42]);
    pool.hook = async ({ kind }) => { if (kind === 'reset') await new Promise(() => {}); };
    assert.equal(await driver.finish('consumer', tx.id, true), true);
    assert.equal(pool.rows.get('committed'), 42);
    await idle(driver, pool);
    assert.equal(pool.connections[0].releases, 0);
    assert.equal(pool.connections[0].destroys, 1);
});

test('stress: a server statement error keeps the connection; a transport error retires it', async t => {
    const { pool, driver } = fixture(t, { limit: 1 });
    const rejectedByServer = Object.assign(new Error('secret'), { code: 'ER_DUP_ENTRY', errno: 1062, sqlState: '23000' });
    pool.hook = async ({ sql }) => { if (sql === 'DUP') throw rejectedByServer; };
    await assert.rejects(driver.run('DUP', []), { code: 'ER_DUP_ENTRY' });
    await idle(driver, pool);
    assert.equal(pool.connections.length, 1);
    assert.equal(pool.connections[0].destroys, 0, 'Constraint errors are routine and must not cost a reconnect');
    assert.equal(pool.connections[0].resets, 1, 'The session is reset before reuse');
    assert.equal((await driver.run('SELECT ?', [1])).rows[0].value, 1);
    pool.hook = async ({ sql }) => { if (sql === 'LOST') throw Object.assign(new Error('gone'), { code: 'PROTOCOL_CONNECTION_LOST', fatal: true }); };
    await assert.rejects(driver.run('LOST', []), { code: 'PROTOCOL_CONNECTION_LOST' });
    await idle(driver, pool);
    assert.equal(pool.connections[0].destroys, 1);
});

test('stress: a query timeout cancels the statement on the server', async t => {
    const killed = [];
    const { pool, driver } = fixture(t, { queryTimeout: 25, options: { killQuery: id => killed.push(id) } });
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'SLOW') await gate.promise; };
    await assert.rejects(driver.run('SLOW', []), { code: 'QUERY_TIMEOUT' });
    assert.deepEqual(killed, [pool.connections[0].threadId]);
    assert.equal(driver.diagnostics().totals.killRequests, 1);
    assert.equal(driver.diagnostics().totals.timeouts, 1);
    gate.resolve();
    await idle(driver, pool);
});

test('stress: only a transaction with a statement in flight needs a server-side kill', async t => {
    const killed = [];
    const { pool, driver } = fixture(t, { queryTimeout: 1000, transactionTimeout: 30, options: { killQuery: id => killed.push(id) } });
    const idleTx = await driver.begin('a');
    await new Promise(resolve => setTimeout(resolve, 60));
    await assert.rejects(driver.finish('a', idleTx.id, true), { code: 'TRANSACTION_TIMEOUT' });
    assert.deepEqual(killed, [], 'An idle transaction is rolled back by the disconnect alone');
    const busyTx = await driver.begin('b');
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'SLOW') await gate.promise; };
    await assert.rejects(driver.transactionQuery('b', busyTx.id, 'SLOW', []), { code: 'TRANSACTION_TIMEOUT' });
    assert.equal(killed.length, 1, 'A running statement is cancelled with its connection');
    gate.resolve();
    await idle(driver, pool);
});

test('stress: a resource cannot hold more transactions than its limit', async t => {
    const { pool, driver } = fixture(t, { limit: 4, options: { maxTransactionsPerOwner: 2 } });
    const first = await driver.begin('greedy');
    const second = await driver.begin('greedy');
    await assert.rejects(driver.begin('greedy'), { code: 'TRANSACTION_LIMIT' });
    const other = await driver.begin('polite');
    assert.equal(pool.live, 3, 'The rejected request never took a connection');
    assert.equal(await driver.finish('greedy', first.id, false), false);
    const third = await driver.begin('greedy');
    for (const [owner, tx] of [['greedy', second], ['greedy', third], ['polite', other]]) await driver.finish(owner, tx.id, false);
    await idle(driver, pool);
});

test('stress: finishing gets its own deadline, so late work is not cut off mid-COMMIT', async t => {
    const { pool, driver } = fixture(t, { transactionTimeout: 80 });
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
    await new Promise(resolve => setTimeout(resolve, 55));
    pool.hook = async ({ sql }) => { if (sql === 'COMMIT') await new Promise(resolve => setTimeout(resolve, 55)); };
    assert.equal(await driver.finish('consumer', tx.id, true), true, 'Work plus COMMIT exceed one window but not each');
    assert.equal(pool.rows.get('key'), 1);
    await idle(driver, pool);
});

test('stress: a transaction that times out mid-COMMIT reports an unknown outcome', async t => {
    const { pool, driver } = fixture(t, { transactionTimeout: 30 });
    const tx = await driver.begin('consumer');
    pool.hook = async ({ sql }) => { if (sql === 'COMMIT') await new Promise(() => {}); };
    await assert.rejects(driver.finish('consumer', tx.id, true), error => {
        assert.equal(error.code, 'TRANSACTION_TIMEOUT');
        assert.equal(error.outcome, 'unknown');
        return true;
    });
    await idle(driver, pool);
});

for (const statement of ['COMMIT', 'ROLLBACK']) {
    test(`stress: failed ${statement} rejects after retiring its uncertain connection`, async t => {
        const { pool, driver } = fixture(t);
        const tx = await driver.begin('consumer');
        await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
        pool.hook = async ({ sql }) => { if (sql === statement) throw sqlError('ECONNRESET'); };
        await assert.rejects(driver.finish('consumer', tx.id, statement === 'COMMIT'), { code: 'ECONNRESET' });
        await idle(driver, pool);
        assert.equal(pool.connections[0].destroys, 1);
        assert.equal(pool.connections[0].releases, 0);
        assert.equal(pool.events.filter(event => event.sql === statement).length, 1);
    });
}

test('stress: consumer stop during a transaction query cancels it without later committing', async t => {
    const { pool, driver } = fixture(t);
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'BLOCK') await gate.promise; };
    const pending = driver.transactionQuery('consumer', tx.id, 'BLOCK', []);
    const rejected = assert.rejects(pending, { code: 'RESOURCE_STOPPED' });
    await turn();
    driver.abortOwner('consumer');
    await rejected;
    gate.resolve();
    await assert.rejects(driver.finish('consumer', tx.id, true), closed);
    assert.equal(pool.events.some(event => event.sql === 'COMMIT'), false);
    assert.equal(pool.rows.has('key'), false);
    await idle(driver, pool);
});

test('stress: successful release resets session state before the next borrower', async t => {
    const { pool, driver } = fixture(t, { limit: 1 });
    await driver.run('SET SESSION', ['consumer-a'], 'consumer-a');
    assert.equal((await driver.run('GET SESSION', [], 'consumer-b')).rows[0].value, 'default');
    const tx = await driver.begin('consumer-a');
    await driver.transactionQuery('consumer-a', tx.id, 'SET SESSION', ['transaction-state']);
    assert.equal(await driver.finish('consumer-a', tx.id, true), true);
    assert.equal((await driver.run('GET SESSION', [], 'consumer-b')).rows[0].value, 'default');
    assert.equal(pool.connections.length, 1);
    await idle(driver, pool);
});

test('stress: consumer stop cancels only owned queries and transactions', async t => {
    const { pool, driver } = fixture(t, { limit: 4 });
    const txA = await driver.begin('consumer-a');
    const txB = await driver.begin('consumer-b');
    await driver.transactionQuery('consumer-a', txA.id, 'WRITE', ['a', 1]);
    await driver.transactionQuery('consumer-b', txB.id, 'WRITE', ['b', 2]);
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'BLOCK') await gate.promise; };
    const queryA = driver.run('BLOCK', [3], 'consumer-a');
    const queryB = driver.run('BLOCK', [4], 'consumer-b');
    const rejectedA = assert.rejects(queryA, { code: 'RESOURCE_STOPPED' });
    await turn();
    driver.abortOwner('consumer-a');
    await rejectedA;
    await assert.rejects(driver.finish('consumer-a', txA.id, true), closed);
    gate.resolve();
    assert.equal((await queryB).rows[0].value, 4);
    assert.equal(await driver.finish('consumer-b', txB.id, true), true);
    assert.equal(pool.rows.has('a'), false);
    assert.equal(pool.rows.get('b'), 2);
    await idle(driver, pool);
    assert.equal((await driver.run('SELECT ?', [5], 'consumer-a')).rows[0].value, 5, 'A restarted consumer can submit fresh work');
});

test('stress: wrong owners cannot query or finish another resource transaction', async t => {
    const { pool, driver } = fixture(t);
    const tx = await driver.begin('owner');
    await assert.rejects(driver.transactionQuery('intruder', tx.id, 'WRITE', ['key', 1]), { code: 'TRANSACTION_OWNER' });
    await assert.rejects(driver.finish('intruder', tx.id, true), { code: 'TRANSACTION_OWNER' });
    assert.equal(pool.events.some(event => event.sql === 'WRITE'), false);
    assert.equal(await driver.finish('owner', tx.id, false), false);
    await idle(driver, pool);
});

test('stress: committed and rolled-back handles reject every subsequent operation', async t => {
    const { pool, driver } = fixture(t);
    for (const commit of [true, false]) {
        const tx = await driver.begin('consumer');
        assert.equal(await driver.finish('consumer', tx.id, commit), commit);
        await driver.drain();
        const before = pool.events.length;
        await assert.rejects(driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]), closed);
        await assert.rejects(driver.finish('consumer', tx.id, true), closed);
        assert.equal(pool.events.length, before);
    }
    await idle(driver, pool);
});

test('stress: provider shutdown cancels leases, is awaitably idempotent, and rejects fresh work', async t => {
    const { pool, driver } = fixture(t);
    const tx = await driver.begin('consumer');
    await driver.transactionQuery('consumer', tx.id, 'WRITE', ['key', 1]);
    const gate = deferred();
    pool.hook = async ({ sql }) => { if (sql === 'BLOCK') await gate.promise; };
    const pending = driver.run('BLOCK', [], 'consumer');
    const rejected = assert.rejects(pending, { code: 'RESOURCE_STOPPED' });
    await turn();
    const first = driver.close();
    const second = driver.close();
    assert.equal(first, second, 'Shutdown callers must await the same completion promise');
    await Promise.all([first, second, rejected]);
    gate.resolve();
    await assert.rejects(driver.run('SELECT 1', []), { code: 'RESOURCE_STOPPED' });
    await assert.rejects(driver.begin('consumer'), { code: 'RESOURCE_STOPPED' });
    assert.equal(pool.endCalls, 1);
    assert.equal(pool.rows.has('key'), false);
    await idle(driver, pool);
});

test('stress: a clean driver instance accepts work after provider replacement', async t => {
    const first = fixture(t, { limit: 1 });
    await first.driver.run('SELECT 1', []);
    await first.driver.close();
    const second = fixture(t, { limit: 1 });
    assert.equal((await second.driver.run('SELECT ?', [2])).rows[0].value, 2);
    const tx = await second.driver.begin('consumer');
    assert.equal(await second.driver.finish('consumer', tx.id, true), true);
    await idle(second.driver, second.pool);
});

test('readiness: false until a probe reaches the database, and the failure code is kept', async t => {
    const { pool, driver } = fixture(t);
    assert.deepEqual(driver.readiness(), { ready: false, code: null, health: 'starting' }, 'Nothing is probed by construction');
    assert.equal(pool.getCalls, 0, 'No connection is opened until asked');
    pool.hook = async ({ sql }) => { if (sql === 'SELECT 1') throw Object.assign(new Error('refused'), { code: 'ECONNREFUSED' }); };
    assert.equal(await driver.probe(), false);
    assert.deepEqual(driver.readiness(), { ready: false, code: 'ECONNREFUSED', health: 'starting' },
        'Never having reached the database is "starting", not "unavailable"');
    pool.hook = async () => {};
    assert.equal(await driver.probe(), true);
    assert.deepEqual(driver.readiness(), { ready: true, code: null, health: 'connected' });
    assert.equal(driver.diagnostics().ready, true);
    assert.equal(driver.diagnostics().health, 'connected');
    await idle(driver, pool);
});
test('healthState: unavailable once the database was reachable before and is not now', async t => {
    const { pool, driver } = fixture(t);
    assert.equal(await driver.probe(), true);
    assert.equal(driver.healthState(), 'connected');
    pool.hook = async ({ sql }) => { if (sql === 'SELECT 1') throw Object.assign(new Error('down'), { code: 'PROTOCOL_CONNECTION_LOST' }); };
    assert.equal(await driver.probe(), false);
    assert.equal(driver.healthState(), 'unavailable', 'It was connected before, so this is not "starting"');
    await idle(driver, pool);
});
test('healthState: degraded once a meaningful share of recent requests fail, and recovers', async t => {
    const { pool, driver } = fixture(t);
    assert.equal(await driver.probe(), true);
    assert.equal(driver.healthState(), 'connected', 'Too little data yet to call it either way');
    pool.hook = async ({ sql }) => { if (sql === 'WRITE') throw Object.assign(new Error('rejected'), { code: 'ER_PARSE_ERROR', errno: 1064, sqlState: '42000' }); };
    for (let i = 0; i < 4; i++) await assert.rejects(driver.run('WRITE', []));
    assert.equal(driver.healthState(), 'connected', 'Fewer than 5 recent requests: not enough to call it degraded');
    await assert.rejects(driver.run('WRITE', []));
    assert.equal(driver.healthState(), 'degraded', '5 of 5 recent requests failed');
    pool.hook = async () => {};
    for (let i = 0; i < 20; i++) await driver.run('SELECT 1', []);
    assert.equal(driver.healthState(), 'connected', 'The 5 failures are now a small enough share of the 25 recent requests (20%, not over threshold)');
    await idle(driver, pool);
});
test('the health probe itself never counts toward healthState\'s recent-failure ratio', async t => {
    const { pool, driver } = fixture(t);
    pool.hook = async ({ sql }) => { if (sql === 'SELECT 1') throw Object.assign(new Error('down'), { code: 'ECONNREFUSED' }); };
    for (let i = 0; i < 10; i++) await driver.probe();
    assert.equal(driver.totals.errors, 10, 'The general error counter does count the probe');
    assert.equal(driver.recentOutcomes.length, 0, 'But it uses owner "health", so it never reaches the degraded-ratio tracker');
    await idle(driver, pool);
});
test('diagnostics reports acquire/execute/cleanup latency separately', async t => {
    const { pool, driver } = fixture(t);
    assert.deepEqual(driver.diagnostics().latencies.executeMs, { count: 0, p50: null, p95: null, p99: null });
    await driver.run('SELECT 1', []);
    await idle(driver, pool);
    const { latencies } = driver.diagnostics();
    for (const phase of ['acquireMs', 'executeMs', 'cleanupMs']) {
        assert.equal(latencies[phase].count, 1, phase);
        assert.equal(typeof latencies[phase].p50, 'number', phase);
    }
});

test('readiness: the start-up loop retries with a pause, reports transitions, then stops', async t => {
    const { pool, driver } = fixture(t);
    let failures = 0;
    pool.hook = async ({ sql }) => { if (sql === 'SELECT 1' && failures++ < 1) throw Object.assign(new Error('down'), { code: 'ECONNREFUSED' }); };
    const reports = [];
    const started = Date.now();
    assert.equal(await driver.awaitDatabase((ready, code, attempt) => reports.push([ready, code, attempt])), true);
    assert.deepEqual(reports, [[false, 'ECONNREFUSED', 1], [true, null, 2]]);
    assert.equal(Date.now() - started >= 900, true, 'It waits about a second before retrying');
    await idle(driver, pool);
});

test('readiness: closing the provider ends a waiting probe loop promptly', async t => {
    const { pool, driver } = fixture(t);
    pool.hook = async ({ sql }) => { if (sql === 'SELECT 1') throw Object.assign(new Error('down'), { code: 'ECONNREFUSED' }); };
    const waiting = driver.awaitDatabase();
    await new Promise(resolve => setTimeout(resolve, 50));
    const started = Date.now();
    await driver.close();
    assert.equal(await waiting, false);
    assert.equal(Date.now() - started < 500, true, 'It did not sleep out its retry interval');
});

test('monitor: a later outage and recovery are reflected in readiness()/healthState(), not just the first connection', async t => {
    const { pool, driver } = fixture(t);
    assert.equal(await driver.probe(), true, 'Reachable at start, like a real awaitDatabase() success');
    assert.deepEqual(driver.readiness(), { ready: true, code: null, health: 'connected' });

    const reports = [];
    const running = driver.monitor((ready, code) => reports.push([ready, code]), 10);

    pool.hook = async ({ sql }) => { if (sql === 'SELECT 1') throw Object.assign(new Error('down'), { code: 'PROTOCOL_CONNECTION_LOST' }); };
    while (driver.readiness().ready) await turn();
    assert.deepEqual(driver.readiness(), { ready: false, code: 'PROTOCOL_CONNECTION_LOST', health: 'unavailable' },
        'The outage is now visible without any caller traffic and without a manual probe() call');

    pool.hook = async () => {};
    while (!driver.readiness().ready) await turn();
    assert.deepEqual(driver.readiness(), { ready: true, code: null, health: 'connected' }, 'Recovery is visible the same way');

    assert.deepEqual(reports, [[false, 'PROTOCOL_CONNECTION_LOST'], [true, null]], 'Reported exactly on the two transitions, nothing in between');

    await driver.close();
    await running;
    await idle(driver, pool);
});

test('monitor: a probe that does not change reachability reports nothing', async t => {
    const { pool, driver } = fixture(t);
    assert.equal(await driver.probe(), true);
    const reports = [];
    const running = driver.monitor((ready, code) => reports.push([ready, code]), 10);
    await new Promise(resolve => setTimeout(resolve, 55));
    await driver.close();
    await running;
    assert.deepEqual(reports, [], 'Still reachable on every tick: nothing to report');
    await idle(driver, pool);
});

test('monitor: closing the provider ends it promptly instead of waiting out the interval', async t => {
    const { pool, driver } = fixture(t);
    assert.equal(await driver.probe(), true);
    const running = driver.monitor(() => {}, 10000);
    await turn();
    const started = Date.now();
    await driver.close();
    await running;
    assert.equal(Date.now() - started < 500, true, 'It did not sleep out the 10s interval');
    await idle(driver, pool);
});
