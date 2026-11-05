'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');

const turn = () => new Promise(resolve => setImmediate(resolve));

function runtime({ missingDriver = false, failQuery = false, convars = {}, mysql = null, clock = Date.now } = {}) {
    const exported = {}, events = {}, commands = {}, scheduled = [], calls = [], logs = [], errors = [], probes = [], monitors = [], ticks = new Map();
    let nextTickId = 0;
    let settings;
    let caller = 'feather-mysql';
    class FakeDriver {
        constructor(pool, queryTimeout, transactionTimeout, logTransaction, options) {
            settings = { pool, queryTimeout, transactionTimeout, logTransaction, options };
        }
        run(...args) { calls.push(args); return Promise.resolve({ kind: 'rows', rows: [] }); }
        begin(...args) { calls.push(['begin', ...args]); return Promise.resolve({ id: 'transaction-1' }); }
        transactionQuery(...args) {
            calls.push(['transactionQuery', ...args]);
            if (failQuery) return Promise.reject(Object.assign(new Error('secret SQL and values'),
                { code: 'ER_DUP_ENTRY', errno: 1062, sqlState: '23000', sqlMessage: "Duplicate entry 'secret' for key 'x'" }));
            return Promise.resolve({ kind: 'rows', rows: [{ answer: 42 }], firstColumn: 'answer' });
        }
        transactionBatch(...args) {
            calls.push(['transactionBatch', ...args]);
            return Promise.resolve([{kind:'rows',rows:[],first:null}]);
        }
        finish(...args) { calls.push(['finish', ...args]); return Promise.resolve(args[2]); }
        abortOwner(...args) { calls.push(['abortOwner', ...args]); }
        readiness() { return { ready: true, code: null }; }
        // The probe is reported through `probes`, not `calls`, so the exact-call assertions stay simple.
        awaitDatabase(report) { probes.push(report); return Promise.resolve(true); }
        // Started after awaitDatabase() succeeds; never resolves on its own, like the real one.
        monitor(report) { monitors.push(report); return new Promise(() => {}); }
        diagnostics() { return { activeRequests: 1, acquiring: 0, checkedOut: 2, transactions: 1 }; }
        close() { calls.push('closed'); return Promise.resolve(); }
    }
    const context = {
        Date: { now: clock },
        setTick: fn => { const id = nextTickId++; ticks.set(id, fn); return id; },
        clearTick: id => ticks.delete(id),
        GetResourcePath: () => root, GetCurrentResourceName: () => 'feather-mysql',
        GetInvokingResource: () => caller,
        GetConvar: (name, fallback) => convars[name] ?? (name === 'mysql_connection_string' ? 'mysql://test@localhost/game' : fallback),
        exports: (name, callback) => { exported[name] = callback; },
        on: (name, callback) => { events[name] = callback; },
        RegisterCommand: (name, callback, restricted) => { commands[name] = { callback, restricted }; },
        setImmediate: callback => scheduled.push(callback),
        console: { log(message) { logs.push(message); }, error(message) { errors.push(message); } },
        require: name => {
            if (name.endsWith('/node_modules/mysql2/promise')) {
                if (missingDriver) throw new Error('Dependency missing');
                return mysql || { createPool: () => ({}) };
            }
            if (name.endsWith('/bridge/driver.js')) return { Driver: FakeDriver };
            return require(name);
        },
    };
    vm.runInNewContext(fs.readFileSync(path.join(root, 'bridge/index.js'), 'utf8'), context);
    return { exported, events, commands, calls, scheduled, logs, errors, probes, monitors, settings, ticks, setCaller: name => { caller = name; } };
}

test('bridge binds NULL/false parameters and defers Lua callback to main-thread scheduling', async () => {
    const { exported, calls, scheduled } = runtime();
    let result;
    exported.DriverExecuteV1({ sql: 'SELECT ?, ?, ?', count: 3, parameters: [{ value: 'safe' }, { isNull: true }, { value: false }] }, response => { result = response; });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(result, undefined);
    assert.equal(scheduled.length, 1);
    scheduled.shift()();
    assert.equal(result.ok, true);
    assert.equal(calls[0][0], 'SELECT ?, ?, ?');
    assert.deepEqual(Array.from(calls[0][1]), ['safe', null, false]);
});
test('bridge accepts an empty Lua parameter table without assuming array methods', async () => {
    const { exported, calls, scheduled } = runtime();
    exported.DriverExecuteV1({ sql: 'SELECT 1', count: 0, parameters: {} }, () => {});
    await new Promise(resolve => setImmediate(resolve));
    scheduled.shift()();
    assert.equal(calls[0][1].length, 0);
});
test('other resources cannot bypass the Lua dispatcher, and are told so instead of being ignored', async () => {
    const { exported, calls, scheduled, setCaller } = runtime();
    setCaller('unrelated-resource');
    const answers = [];
    const record = response => answers.push(response);
    exported.DriverExecuteV1({ sql: 'SELECT 1' }, record);
    exported.DriverTransactionBeginV1('forged-owner', record);
    exported.DriverTransactionQueryV1('forged-owner', 'transaction-1', { sql: 'SELECT 1' }, record);
    exported.DriverTransactionFinishV1('forged-owner', 'transaction-1', true, record);
    exported.DriverSelfCheckV1(record);
    exported.DriverReadyV1(record);
    await turn();
    while (scheduled.length) scheduled.shift()();
    assert.equal(calls.length, 0, 'No driver call is made for an unauthorized caller');
    assert.equal(answers.length, 6, 'Every request is answered; none is silently dropped');
    for (const answer of answers) {
        assert.equal(answer.ok, false);
        assert.equal(answer.error.code, 'INVALID_CALLER');
        assert.equal(answer.error.outcome, 'not_executed');
    }
});
test('missing dependency returns a safe configuration error', async () => {
    const { exported, scheduled, errors } = runtime({ missingDriver: true });
    let result;
    exported.DriverExecuteV1({}, response => { result = response; });
    await turn();
    scheduled.shift()();
    assert.equal(result.error.code, 'CONFIG_ERROR');
    assert.equal(result.error.outcome, 'not_executed');
    assert.match(errors[0], /CONFIG_ERROR/);
});
test('bridge aborts stopped consumers individually and closes only on provider stop', () => {
    const { events, calls } = runtime();
    events.onResourceStop('other-resource');
    assert.deepEqual(calls, [['abortOwner', 'other-resource']]);
    events.onResourceStop('feather-mysql');
    assert.deepEqual(calls, [['abortOwner', 'other-resource'], 'closed']);
});

test('bridge forwards server-derived query attribution to the driver', async () => {
    const { exported, calls, scheduled } = runtime();
    exported.DriverExecuteV1({ resource: 'consumer-a', sql: 'SELECT 1', count: 0, parameters: {} }, () => {});
    await new Promise(resolve => setImmediate(resolve));
    scheduled.shift()();
    assert.equal(calls[0][2], 'consumer-a');
});

test('bridge routes begin, parameterized transaction query and finish with unchanged owner and ID', async () => {
    const { exported, calls, scheduled } = runtime();
    let begun, queried, finished;
    exported.DriverTransactionBeginV1('consumer-a', response => { begun = response; });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(begun, undefined);
    scheduled.shift()();
    assert.equal(begun.value.id, 'transaction-1');
    exported.DriverTransactionQueryV1('consumer-a', begun.value.id, {
        sql: 'SELECT ?, ?, ?', count: 3,
        parameters: [{ value: "O'Brien" }, { isNull: true }, { value: false }],
    }, response => { queried = response; });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(queried, undefined);
    scheduled.shift()();
    assert.equal(queried.ok, true);
    assert.equal(queried.value.rows[0].answer, 42);
    assert.deepEqual(calls[0], ['begin', 'consumer-a']);
    assert.deepEqual(calls[1].slice(0, 4), ['transactionQuery', 'consumer-a', 'transaction-1', 'SELECT ?, ?, ?']);
    assert.deepEqual(Array.from(calls[1][4]), ["O'Brien", null, false]);
    exported.DriverTransactionFinishV1('consumer-a', 'transaction-1', false, response => { finished = response; });
    await new Promise(resolve => setImmediate(resolve));
    scheduled.shift()();
    assert.equal(finished.ok, true);
    assert.equal(finished.value, false, 'Intentional rollback is a successful false result');
    assert.deepEqual(calls[2], ['finish', 'consumer-a', 'transaction-1', false]);
});

test('bridge transaction failures retain the safe driver code without exposing SQL or values', async () => {
    const { exported, scheduled } = runtime({ failQuery: true });
    let result;
    exported.DriverTransactionQueryV1('consumer', 'transaction-1', {
        sql: 'SELECT ?', count: 1, parameters: [{ value: 'secret' }],
    }, response => { result = response; });
    await new Promise(resolve => setImmediate(resolve));
    scheduled.shift()();
    assert.equal(result.ok, false);
    assert.equal(result.error.driverCode, 'ER_DUP_ENTRY');
    assert.equal(result.error.sqlState, '23000');
    assert.equal(result.error.outcome, 'failed');
    assert.doesNotMatch(JSON.stringify(result), /secret|SELECT|Duplicate/);
});

test('driver error messages are shared only when the operator opts in', async () => {
    const { exported, scheduled } = runtime({ failQuery: true, convars: { feather_mysql_error_detail: 'true' } });
    let result;
    exported.DriverTransactionQueryV1('consumer', 'transaction-1', { sql: 'SELECT ?', count: 0, parameters: [] }, response => { result = response; });
    await turn();
    scheduled.shift()();
    assert.match(result.error.detail, /Duplicate entry/);
});

test('diagnostics command is restricted and refuses player invocation', () => {
    const { commands, logs } = runtime();
    const command = commands.feather_mysql_diagnostics;
    assert.equal(command.restricted, true);
    const before = logs.length;
    command.callback(17);
    assert.equal(logs.length, before);
    command.callback(0);
    const output = JSON.parse(logs.at(-1).slice('[feather-mysql] '.length));
    assert.deepEqual(output, { activeRequests: 1, acquiring: 0, checkedOut: 2, transactions: 1 });
});

test('missing driver diagnostics and stop events stay safe', () => {
    const { commands, events, calls, logs } = runtime({ missingDriver: true });
    commands.feather_mysql_diagnostics.callback(0);
    assert.match(logs.at(-1), /CONFIG_ERROR/);
    events.onResourceStop('consumer');
    events.onResourceStop('feather-mysql');
    assert.equal(calls.length, 0);
});

test('unavailable consumer callback is contained after database completion', async () => {
    const { exported, scheduled, errors } = runtime();
    exported.DriverTransactionBeginV1('consumer', () => { throw new Error('Consumer stopped'); });
    await new Promise(resolve => setImmediate(resolve));
    assert.doesNotThrow(() => scheduled.shift()());
    assert.deepEqual(errors, ['[feather-mysql] Lua response callback unavailable.']);
});

test('query and transaction deadline configuration reach the driver separately', () => {
    const { settings, scheduled, logs } = runtime({ convars: {
        feather_mysql_query_timeout_ms: '300', feather_mysql_transaction_timeout: '500',
        feather_mysql_log_transactions: 'true',
    } });
    assert.equal(settings.queryTimeout, 300);
    assert.equal(settings.transactionTimeout, 500, 'The older convar name is still honoured');
    settings.logTransaction({ transactionId: 'test', event: 'COMMIT', resource: 'consumer', durationMs: 3 });
    assert.equal(scheduled.length, 1);
    scheduled.shift()();
    assert.match(logs.at(-1), /"event":"COMMIT"/);
});

test('devmode logs every transaction by default and an explicit convar still wins', () => {
    const emit = ({ logs, scheduled, settings }) => {
        settings.logTransaction({ transactionId: 't', event: 'BEGIN', resource: 'consumer', durationMs: 1 });
        while (scheduled.length) scheduled.shift()();
        return logs.filter(line => line.includes(' TX '));
    };
    assert.equal(emit(runtime()).length, 0, 'A quiet server does not log a plain BEGIN');
    const dev = runtime({ convars: { feather_mysql_devmode: 'true' } });
    assert.equal(emit(dev).length, 1);
    assert.ok(dev.logs.some(line => line.includes('Devmode is on')), 'Start-up says devmode is on');
    assert.equal(emit(runtime({ convars: { feather_mysql_devmode: 'true', feather_mysql_log_transactions: 'false' } })).length, 0);
    assert.ok(!runtime().logs.some(line => line.includes('Devmode')));
});

test('the _ms transaction convar wins and the new limits get sensible defaults', () => {
    const { settings } = runtime({ convars: {
        feather_mysql_transaction_timeout_ms: '700', feather_mysql_transaction_timeout: '500',
    } });
    assert.equal(settings.transactionTimeout, 700);
    assert.equal(settings.options.maxTransactionsPerOwner, 5, 'Half of the default pool of 10');
    assert.equal(settings.options.cleanupTimeoutMs, 5000);
    assert.equal(typeof settings.options.killQuery, 'function');
    assert.equal(settings.options.retryDeadlocks, false, 'Off by default');
    assert.equal(settings.options.retryDeadlocksMax, 3);
    assert.deepEqual({ ...settings.options.sessionOptions }, { database: 'game', charset: 'utf8mb4' },
        'Cleanup restores the configured database and charset');
    const configured = runtime({ convars: { feather_mysql_max_transactions_per_resource: '0', mysql_connection_string: 'mysql://u@h/db?connectionLimit=4' } });
    assert.equal(configured.settings.options.maxTransactionsPerOwner, Infinity, '0 removes the limit');
    const small = runtime({ convars: { mysql_connection_string: 'mysql://u@h/db?connectionLimit=1' } });
    assert.equal(small.settings.options.maxTransactionsPerOwner, 1, 'Never below one');
});
test('deadlock retry is opt-in and its limit is configurable', () => {
    const on = runtime({ convars: { feather_mysql_retry_deadlocks: 'true', feather_mysql_retry_deadlocks_max: '7' } });
    assert.equal(on.settings.options.retryDeadlocks, true);
    assert.equal(on.settings.options.retryDeadlocksMax, 7);
    const bad = runtime({ convars: { feather_mysql_retry_deadlocks_max: '-1' } });
    assert.match(bad.errors[0], /retry_deadlocks_max/);
});

test('slow transactions are logged without enabling transaction logging', () => {
    const { settings, scheduled, logs } = runtime({ convars: { feather_mysql_slow_transaction_ms: '100' } });
    settings.logTransaction({ transactionId: 't', event: 'COMMIT', resource: 'consumer', durationMs: 50 });
    settings.logTransaction({ transactionId: 't', event: 'QUERY', resource: 'consumer', durationMs: 500 });
    assert.equal(scheduled.length, 0, 'Fast transactions and individual queries stay quiet');
    settings.logTransaction({ transactionId: 't', event: 'COMMIT', resource: 'consumer', durationMs: 150 });
    scheduled.shift()();
    assert.match(logs.at(-1), /"slow":true/);
});

test('the startup self-check answers with the value shapes a result carries, without the database', async () => {
    const { exported, scheduled } = runtime({ missingDriver: true });
    let result;
    exported.DriverSelfCheckV1(response => { result = response; });
    await turn();
    scheduled.shift()();
    assert.equal(result.ok, true);
    const row = result.value.rows[0];
    assert.equal(row.text, 'h\u00e9llo \u{1F600} \u65e5\u672c\u8a9e');
    assert.equal(row.number, 42);
    assert.equal(row.nothing, null);
    assert.deepEqual(Array.from(row.bytes), [0, 255]);
    assert.equal(row.big, '9007199254740993');
    assert.equal(row.flag, false);
    assert.equal(result.value.first, row.text);
});

test('the database is probed once at start and the result is reported without secrets', async () => {
    const { probes, monitors, logs, errors } = runtime();
    assert.equal(probes.length, 1, 'One probe loop starts with the driver');
    probes[0](false, 'ECONNREFUSED', 1);
    probes[0](true, null, 3);
    assert.match(errors.at(-1), /Database not reachable yet \(ECONNREFUSED\); retrying/);
    assert.match(logs.at(-1), /Database reachable after 3 attempts\./);
    probes[0](true, null, 1);
    assert.match(logs.at(-1), /Database reachable\.$/);
    await turn();
    assert.equal(monitors.length, 1, 'Periodic monitoring starts once startup succeeds, so a later outage is not missed');
    monitors[0](false, 'PROTOCOL_CONNECTION_LOST');
    assert.match(logs.at(-1), /Database unreachable \(PROTOCOL_CONNECTION_LOST\)\./);
    monitors[0](true, null);
    assert.match(logs.at(-1), /Database reachable again\./);
    const { probes: missingProbes, monitors: missingMonitors } = runtime({ missingDriver: true });
    assert.equal(missingProbes.length, 0, 'Nothing is probed without a driver');
    await turn();
    assert.equal(missingMonitors.length, 0, 'Nothing is monitored without a driver');
});

test('readiness is routed to the driver and the value shape reaches the caller', async () => {
    const { exported, scheduled } = runtime();
    let ready;
    exported.DriverReadyV1(response => { ready = response; });
    await turn();
    while (scheduled.length) scheduled.shift()();
    assert.deepEqual({ ...ready.value }, { ready: true, code: null });
});

test('configuration errors print only static, credential-free text', () => {
    const secret = 'hunter2-secret';
    for (const connection of [`mysql://user:${secret}@host:70000/db?bogus=1`, `mysql://user:${secret}@[bad/db`,
        `host=h;user=u;password=${secret};database=d;unknown=1`, `mysql://user:%E0%A4%A@host/db`]) {
        const { errors } = runtime({ convars: { mysql_connection_string: connection } });
        assert.equal(errors.length, 1);
        assert.match(errors[0], /CONFIG_ERROR/);
        assert.doesNotMatch(errors[0], new RegExp(secret));
    }
    assert.match(runtime({ convars: { mysql_connection_string: 'mysql://u@h/db?queueLimit=0' } }).errors[0], /queueLimit/,
        'A static message may name the offending setting');
});

test('cancelling a statement uses a separate short-lived connection without pool-only options', async () => {
    const opened = [], queries = [];
    let destroyed = 0;
    const mysql = {
        createPool: () => ({}),
        createConnection: async options => {
            opened.push(options);
            return { query: async sql => { queries.push(sql); }, destroy: () => { destroyed++; } };
        },
    };
    const { settings } = runtime({ mysql, convars: { mysql_connection_string: 'mysql://kill:pw@localhost/game?connectionLimit=4' } });
    await settings.options.killQuery(4242);
    assert.deepEqual(queries, ['KILL QUERY 4242']);
    assert.equal(destroyed, 1);
    for (const key of ['connectionLimit', 'queueLimit', 'waitForConnections', 'rowsAsArray']) assert.equal(key in opened[0], false, key);
    assert.equal(opened[0].user, 'kill');
    assert.equal(opened[0].connectTimeout, 2000);
    await settings.options.killQuery('4242; DROP TABLE x');
    await settings.options.killQuery(-1);
    assert.equal(queries.length, 1, 'Only positive integer connection IDs are ever sent');
});

test('kill attempts are bounded so a struggling database is not flooded', async () => {
    let running = 0, peak = 0;
    const mysql = {
        createPool: () => ({}),
        createConnection: async () => {
            running++; peak = Math.max(peak, running);
            await turn();
            return { query: async () => { await turn(); }, destroy: () => { running--; } };
        },
    };
    const { settings } = runtime({ mysql });
    await Promise.all(Array.from({ length: 10 }, (_, i) => settings.options.killQuery(i + 1)));
    assert.equal(peak <= 2, true, `peak side connections ${peak}`);
});


test('scheduler probe compares inline immediate and promise delivery without calling the driver', async () => {
    let now = 10;
    const { exported, calls, scheduled } = runtime({ missingDriver: true, clock: () => now });
    const results = [];
    exported.DriverSchedulingProbeV1('inline', r => results.push(r));
    assert.equal(results.length, 1);
    assert.equal(results[0].value.flag, false);
    assert.equal(results[0].value.queueMs, 0);
    exported.DriverSchedulingProbeV1('immediate', r => results.push(r));
    assert.equal(results.length, 1);
    now = 25; scheduled.shift()();
    assert.equal(results[1].value.queueMs, 15);
    exported.DriverSchedulingProbeV1('promise_immediate', r => results.push(r));
    assert.equal(scheduled.length, 0);
    now = 35; await turn();
    assert.equal(results.length, 2);
    now = 80; scheduled.shift()();
    assert.equal(results[2].value.promiseMs, 10);
    assert.equal(results[2].value.queueMs, 45);
    assert.equal(results[2].value.mode, 'promise_immediate');
    assert.equal(calls.length, 0);
});

test('scheduler probe refuses foreign callers and invalid scheduling modes', async () => {
    const { exported, calls, scheduled, setCaller } = runtime();
    const replies = [];
    setCaller('unrelated-resource');
    for (const mode of ['inline', 'immediate', 'promise_immediate']) exported.DriverSchedulingProbeV1(mode, r => replies.push(r));
    await turn();
    while (scheduled.length) scheduled.shift()();
    assert.equal(replies.length, 3);
    for (const r of replies) assert.equal(r.error.code, 'INVALID_CALLER');
    setCaller('feather-mysql');
    exported.DriverSchedulingProbeV1('arbitrary', r => replies.push(r));
    await turn(); scheduled.shift()();
    assert.equal(replies.at(-1).ok, false);
    assert.equal(calls.length, 0);
});

test('scheduler probe isolates failed callbacks without retry or driver access', async () => {
    const { exported, calls, scheduled, errors } = runtime();
    let attempted = 0;
    const fail = () => { attempted++; throw new Error('callback unavailable'); };
    for (const mode of ['inline', 'immediate', 'promise_immediate']) exported.DriverSchedulingProbeV1(mode, fail);
    await turn();
    while (scheduled.length) scheduled.shift()();
    assert.equal(attempted, 3);
    assert.equal(errors.length, 3);
    assert.equal(calls.length, 0);
});


test('tick diagnostics deliver only on tick and remove the empty ticker including ID zero', async () => {
    let now = 10;
    const { exported, ticks, calls } = runtime({ clock: () => now });
    const replies = [];
    exported.DriverSchedulingProbeV1('tick', r => replies.push(r));
    assert.equal(replies.length, 0);
    assert.equal(ticks.has(0), true);
    now = 25; ticks.get(0)();
    assert.equal(replies[0].value.queueMs, 15);
    assert.equal(ticks.size, 0);
    exported.DriverSchedulingProbeV1('promise_tick', r => replies.push(r));
    now = 30; await turn();
    assert.equal(replies.length, 1);
    now = 40; [...ticks.values()][0]();
    assert.equal(replies[1].value.promiseMs, 5);
    assert.equal(replies[1].value.queueMs, 10);
    assert.equal(ticks.size, 0);
    assert.equal(calls.length, 0);
});

test('tick diagnostics bound pending work and drain only eight completions per tick', async () => {
    const { exported, ticks, scheduled, calls } = runtime();
    const replies = [];
    for (let i = 0; i < 17; i++) exported.DriverSchedulingProbeV1('tick', r => replies.push(r));
    assert.equal(ticks.size, 1);
    await turn(); scheduled.shift()();
    assert.equal(replies.length, 1);
    assert.equal(replies[0].error.driverCode, 'PROBE_BUSY');
    [...ticks.values()][0]();
    assert.equal(replies.length, 9);
    assert.equal(ticks.size, 1);
    [...ticks.values()][0]();
    assert.equal(replies.length, 17);
    assert.equal(ticks.size, 0);
    assert.equal(calls.length, 0);
});

test('tick diagnostics defer reentrant work to a later tick and isolate callback failure', () => {
    const { exported, ticks, errors } = runtime();
    let delivered = 0;
    exported.DriverSchedulingProbeV1('tick', () => {
        delivered++;
        exported.DriverSchedulingProbeV1('tick', () => delivered++);
        throw new Error('callback unavailable');
    });
    [...ticks.values()][0]();
    assert.equal(delivered, 1);
    assert.equal(errors.length, 1);
    assert.equal(ticks.size, 1);
    [...ticks.values()][0]();
    assert.equal(delivered, 2);
    assert.equal(ticks.size, 0);
});

test('resource stop discards diagnostic work and pending promise continuation without a driver', async () => {
    const { exported, ticks, events } = runtime({ missingDriver: true });
    let replies = 0;
    exported.DriverSchedulingProbeV1('tick', () => replies++);
    exported.DriverSchedulingProbeV1('promise_tick', () => replies++);
    events.onResourceStop('feather-mysql');
    await turn();
    assert.equal(ticks.size, 0);
    assert.equal(replies, 0);
});

test('foreign tick diagnostics cannot start a ticker', async () => {
    const { exported, ticks, scheduled, setCaller } = runtime();
    setCaller('bcc-stables');
    const replies = [];
    for (const mode of ['tick', 'promise_tick']) exported.DriverSchedulingProbeV1(mode, r => replies.push(r));
    await turn(); while (scheduled.length) scheduled.shift()();
    assert.equal(ticks.size, 0);
    assert.equal(replies.length, 2);
    for (const r of replies) assert.equal(r.error.code, 'INVALID_CALLER');
});


test('resource stop during a diagnostic callback prevents later batch delivery', () => {
    const { exported, ticks, events } = runtime({ missingDriver: true });
    let replies = 0;
    exported.DriverSchedulingProbeV1('tick', () => { replies++; events.onResourceStop('feather-mysql'); });
    exported.DriverSchedulingProbeV1('tick', () => replies++);
    [...ticks.values()][0]();
    assert.equal(replies, 1);
    assert.equal(ticks.size, 0);
});


test('transaction batch bridge keeps attributed owner connection ID and normalized NULL parameters', async () => {
    const { exported, calls, scheduled } = runtime();
    let response;
    exported.DriverTransactionBatchV1('consumer', 'tx-1', { count: 1,
        statements: [{ sql: 'SELECT ?, ?', count: 2, parameters: [{ isNull: true }, { value: false }] }] }, r => response=r);
    await turn(); scheduled.shift()();
    assert.equal(response.ok, true);
    assert.equal(calls[0][0], 'transactionBatch');
    assert.equal(calls[0][1], 'consumer');
    assert.equal(calls[0][2], 'tx-1');
    assert.deepEqual(Array.from(calls[0][3][0].parameters), [null, false]);
});

test('transaction batch bridge refuses foreign callers and oversized counts before driver access', async () => {
    const { exported, calls, scheduled, setCaller } = runtime();
    const replies=[];
    setCaller('untrusted');
    exported.DriverTransactionBatchV1('forged', 'tx', { count: 1 }, r => replies.push(r));
    await turn(); scheduled.shift()();
    assert.equal(replies[0].error.code, 'INVALID_CALLER');
    setCaller('feather-mysql');
    exported.DriverTransactionBatchV1('consumer', 'tx', { count: 33 }, r => replies.push(r));
    await turn(); scheduled.shift()();
    assert.equal(replies[1].ok, false);
    assert.equal(calls.length, 0);
});
