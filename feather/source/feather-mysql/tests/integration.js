'use strict';
// Invoked only by run_integration.py. The socket and database are disposable.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const mysql = require('mysql2/promise');
const { Driver } = require('../bridge/driver');
const { parseConnectionString, connectionOptions } = require('../bridge/config');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const directory = process.env.FEATHER_MYSQL_PRIVATE_DIR;
if (!directory || !path.basename(directory).startsWith('feather-mysql-integration-')) {
    throw new Error('Run through python3 tests/run_integration.py with an isolated database');
}
const socketPath = path.join(directory, 'mysql.sock');
const database = 'feather_mysql_robustness';

test('isolated MariaDB integration', async t => {
    let admin = await mysql.createConnection({ socketPath, user: 'root' });
    const drivers = new Set();
    let replacement;
    const factory = (limit = 4, timeout = 3000, transactionTimeout = 5000, poolOptions = {}, driverOptions = {}) => {
        const config = parseConnectionString(`mysql://root@localhost/${database}?connectionLimit=${limit}`);
        const sessionOptions = { database: config.database, charset: poolOptions.charset ?? config.charset };
        const driver = new Driver(mysql.createPool({ ...config, socketPath, ...poolOptions }), timeout, transactionTimeout, undefined,
            { sessionOptions, ...driverOptions });
        drivers.add(driver);
        return driver;
    };
    // The same cancellation the bridge performs, over the private socket.
    const killQuery = async threadId => {
        const options = { ...connectionOptions(parseConnectionString(`mysql://root@localhost/${database}`)), socketPath };
        const connection = await mysql.createConnection(options);
        try { await connection.query(`KILL QUERY ${threadId}`); } finally { connection.destroy(); }
    };
    const status = async name => Number((await admin.query(`SHOW GLOBAL STATUS LIKE '${name}'`))[0][0].Value);
    const query = (db, sql, parameters = [], owner = 'integration') => db.run(sql, parameters, owner);
    const scalar = async (db, sql, parameters = []) => {
        const value = await query(db, sql, parameters);
        return value.first;
    };
    // Answers are sent before session cleanup, so wait for the cleanup first.
    const zero = async db => {
        await db.drain();
        const stats = db.diagnostics();
        assert.equal(stats.activeRequests, 0);
        assert.equal(stats.transactions, 0);
        assert.equal(stats.checkedOut, 0);
        assert.equal(stats.acquiring, 0);
        assert.equal(stats.poolQueued, 0);
        assert.equal(stats.cleanupFailures, 0);
    };
    const seed = async () => {
        await admin.query(`DELETE FROM ${database}.records`);
        await admin.query(`INSERT INTO ${database}.records (id, value) VALUES (1, 100), (2, 100)`);
    };
    try {
        await admin.query('CREATE DATABASE feather_mysql_robustness');
        await admin.query(`CREATE TABLE ${database}.records (id INT PRIMARY KEY AUTO_INCREMENT, value INT, sample VARCHAR(255) NULL) ENGINE=InnoDB`);
        console.log('Database version:', (await admin.query('SELECT VERSION() AS version'))[0][0].version);

        await t.test('real bindings and result shapes survive the reset-before-release path', async () => {
            const db = factory();
            const text = "O'Brien ?; DROP TABLE imaginary; --";
            const inserted = await query(db, 'INSERT INTO records (value, sample) VALUES (?, ?)', [7, text]);
            assert.ok(inserted.header.insertId > 0);
            const rows = await query(db, 'SELECT sample, value FROM records WHERE id = ?', [inserted.header.insertId]);
            assert.equal(rows.rows[0].sample, text);
            assert.equal(rows.firstColumn, 'sample');
            assert.equal(rows.first, text);
            assert.equal(await scalar(db, 'SELECT ?', [null]), null);
            assert.equal(await scalar(db, 'SELECT ?', [false]), 0);
            assert.equal(await scalar(db, 'SELECT ?', ['']), '');
            assert.equal(await scalar(db, 'SELECT CAST(9007199254740993 AS UNSIGNED)'), '9007199254740993');
            assert.equal((await query(db, 'UPDATE records SET value = ? WHERE id = ?', [8, inserted.header.insertId])).header.affectedRows, 1);
            assert.equal((await query(db, 'SELECT id FROM records WHERE 1 = 0')).rows.length, 0);
            await zero(db); await db.close();
        });
        await t.test('configured charset, collation and database survive reset and reuse', async () => {
            // Deliberately differ from the server default to detect reset drift.
            const db = factory(1, 3000, 5000, { charset: 'LATIN1_SWEDISH_CI' });
            for (let i = 0; i < 3; i++) {
                const result = await query(db, 'SELECT @@character_set_client AS client, @@character_set_connection AS connection, @@character_set_results AS results, @@collation_connection AS collation, ? AS sample', ['café']);
                assert.deepEqual({ ...result.rows[0] }, { client: 'latin1', connection: 'latin1', results: 'latin1', collation: 'latin1_swedish_ci', sample: 'café' });
                await query(db, 'USE information_schema');
                assert.equal(await scalar(db, 'SELECT DATABASE()'), database);
            }
            await zero(db); await db.close();
        });
        await t.test('100 concurrent queries in bounded waves have no cross-talk or leases left behind', async () => {
            const db = factory(8);
            for (let offset = 0; offset < 100; offset += 5) {
                const values = await Promise.all(Array.from({ length: 5 }, (_, i) => scalar(db, 'SELECT ? AS value', [offset + i])));
                assert.deepEqual(values, Array.from({ length: 5 }, (_, i) => offset + i));
                await zero(db);
            }
            await db.close();
        });
        await t.test('a burst far above the pool size is queued: every request succeeds and the pool does not grow', async () => {
            const db = factory(10);
            const results = await Promise.all(Array.from({ length: 100 }, (_, i) => scalar(db, 'SELECT ? AS value', [i])));
            assert.deepEqual(results, Array.from({ length: 100 }, (_, i) => i));
            const stats = db.diagnostics();
            assert.equal(stats.poolConnections <= 10, true, `pool grew to ${stats.poolConnections}`);
            assert.equal(stats.totals.poolExhausted, 0);
            await zero(db); await db.close();
        });
        await t.test('a full queue rejects only the overflow, and never executes it', async () => {
            const db = factory(2, 5000, 5000, { queueLimit: 5 });
            const holders = [scalar(db, 'SELECT SLEEP(?)', [0.3]), scalar(db, 'SELECT SLEEP(?)', [0.3])];
            await delay(50);
            const burst = await Promise.allSettled(Array.from({ length: 20 }, (_, i) => scalar(db, 'SELECT ? AS value', [i])));
            const failed = burst.filter(result => result.status === 'rejected');
            assert.equal(burst.length - failed.length, 5, 'Exactly the queue length is served');
            assert.equal(failed.length, 15);
            for (const result of failed) assert.equal(result.reason.code, 'POOL_EXHAUSTED');
            await Promise.all(holders);
            assert.equal(await scalar(db, 'SELECT 1'), 1, 'Capacity recovers');
            await zero(db); await db.close();
        });
        await t.test('transactions hold their connections while queued requests wait, then proceed', async () => {
            const db = factory(2);
            const a = await db.begin('a'); const b = await db.begin('b');
            const waiting = scalar(db, 'SELECT 41 + 1');
            await delay(30);
            assert.equal(db.diagnostics().poolQueued, 1, 'The request waits in the queue');
            await db.finish('a', a.id, false);
            assert.equal(await waiting, 42);
            await db.finish('b', b.id, false);
            await zero(db); await db.close();
        });
        await t.test('integers are numbers; oversized BIGINT and DECIMAL are strings; ids agree with inserts', async () => {
            await admin.query(`CREATE TABLE ${database}.typed (id BIGINT PRIMARY KEY AUTO_INCREMENT, amount DECIMAL(10,2), ratio DOUBLE, small INT) ENGINE=InnoDB`);
            const db = factory();
            const inserted = await query(db, 'INSERT INTO typed (amount, ratio, small) VALUES (?, ?, ?)', [12.5, 0.25, 7]);
            const row = (await query(db, 'SELECT id, amount, ratio, small FROM typed WHERE id = ?', [inserted.header.insertId])).rows[0];
            assert.equal(typeof row.id, 'number');
            assert.equal(row.id, inserted.header.insertId, 'A BIGINT id read back equals the id the insert returned');
            assert.equal(row.amount, '12.50', 'DECIMAL keeps its exact text');
            assert.equal(row.ratio, 0.25);
            assert.equal(row.small, 7);
            assert.strictEqual(await scalar(db, 'SELECT COUNT(*) FROM typed'), 1, 'COUNT(*) is a number, so count == 0 works');
            assert.strictEqual(await scalar(db, 'SELECT @@in_transaction'), 0);
            assert.strictEqual(await scalar(db, 'SELECT 9007199254740991'), 9007199254740991);
            assert.strictEqual(await scalar(db, 'SELECT -9007199254740991'), -9007199254740991);
            assert.strictEqual(await scalar(db, 'SELECT CAST(9007199254740993 AS UNSIGNED)'), '9007199254740993');
            assert.strictEqual(await scalar(db, 'SELECT -9007199254740993'), '-9007199254740993');
            assert.strictEqual(await scalar(db, 'SELECT SUM(small) FROM typed'), '7', 'SUM over integers is a DECIMAL and stays a string');
            await admin.query(`INSERT INTO ${database}.typed (id, amount) VALUES (9007199254740993, 1)`);
            assert.strictEqual(await scalar(db, 'SELECT id FROM typed WHERE amount = ?', ['1.00']), '9007199254740993');
            await zero(db); await db.close();
        });
        await t.test('Unicode, emoji and SQL-special characters round-trip unchanged', async () => {
            const db = factory();
            for (const text of ['h\u00e9llo \u{1F600} \u65e5\u672c\u8a9e', 'right-to-left \u202e mark', "quote ' double \" backslash \\ percent % underscore _",
                'line\nbreak\r\ttab', '; DROP TABLE records; --', '', ' padded ', '\u{10FFFF}', '0']) {
                const inserted = await query(db, 'INSERT INTO records (value, sample) VALUES (?, ?)', [1, text]);
                assert.equal(await scalar(db, 'SELECT sample FROM records WHERE id = ?', [inserted.header.insertId]), text, JSON.stringify(text));
            }
            await zero(db); await db.close();
        });
        await t.test('duplicate column names cannot change which value is first', async () => {
            const db = factory();
            const result = await query(db, 'SELECT 1 AS id, 2 AS id, 3 AS other');
            assert.equal(result.first, 1);
            assert.equal(result.rows[0].other, 3);
            assert.equal(await scalar(db, 'SELECT ?, ?', [10, 20]), 10, 'Unaliased placeholder columns share a name too');
            await zero(db); await db.close();
        });
        await t.test('a timed-out write is cancelled on the server rather than applied afterwards', async () => {
            const slowUpdate = 'UPDATE records SET value = value + 1 WHERE id = 1 AND SLEEP(1) = 0';
            await seed();
            const uncancelled = factory(2, 100);
            await assert.rejects(query(uncancelled, slowUpdate), { code: 'QUERY_TIMEOUT' });
            await delay(1400);
            assert.equal((await admin.query(`SELECT value FROM ${database}.records WHERE id = 1`))[0][0].value, 101,
                'Without cancellation the server finishes the statement after the caller gave up');
            await seed();
            const cancelled = factory(2, 100, 5000, {}, { killQuery });
            await assert.rejects(query(cancelled, slowUpdate), { code: 'QUERY_TIMEOUT' });
            await delay(1400);
            assert.equal((await admin.query(`SELECT value FROM ${database}.records WHERE id = 1`))[0][0].value, 100,
                'KILL QUERY interrupted the statement, so nothing was applied');
            const running = (await admin.query('SHOW PROCESSLIST'))[0].filter(p => p.db === database && /SLEEP/.test(p.Info || ''));
            assert.equal(running.length, 0, 'No abandoned statement is still executing');
            assert.equal(cancelled.diagnostics().totals.killRequests, 1);
            await zero(cancelled); await zero(uncancelled); await cancelled.close(); await uncancelled.close();
        });
        await t.test('constraint errors do not cost a reconnect', async () => {
            await seed(); const db = factory(2);
            await query(db, 'SELECT 1'); await db.drain();
            const opened = await status('Connections'), dropped = await status('Aborted_clients');
            for (let i = 0; i < 30; i++) await assert.rejects(query(db, 'INSERT INTO records (id, value) VALUES (1, 1)'), { code: 'ER_DUP_ENTRY' });
            await zero(db);
            assert.equal((await status('Connections')) - opened <= 1, true, 'At most the pool\'s second connection is opened');
            assert.equal((await status('Aborted_clients')) - dropped, 0, 'No socket was dropped without a proper close');
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 1'), 100, 'The pool is healthy afterwards');
            await db.close();
        });
        await t.test('a server error carries its SQLSTATE and is classified as rejected, not unknown', async () => {
            const { publicError } = require('../bridge/errors');
            const db = factory();
            const error = await query(db, 'SELECT * FROM no_such_table').catch(failure => failure);
            const safe = publicError(error);
            assert.deepEqual({ code: safe.code, outcome: safe.outcome, sqlState: safe.sqlState, driverCode: safe.driverCode },
                { code: 'DATABASE_ERROR', outcome: 'failed', sqlState: '42S02', driverCode: 'ER_NO_SUCH_TABLE' });
            assert.equal(safe.detail, undefined);
            assert.match(publicError(error, { detail: true }).detail, /no_such_table/);
            await zero(db); await db.close();
        });
        await t.test('one resource cannot hold more transactions than its limit', async () => {
            const db = factory(4, 3000, 5000, {}, { maxTransactionsPerOwner: 2 });
            const held = [await db.begin('greedy'), await db.begin('greedy')];
            await assert.rejects(db.begin('greedy'), { code: 'TRANSACTION_LIMIT' });
            const other = await db.begin('polite');
            assert.equal(db.diagnostics().poolConnections, 3, 'The refused request never took a connection');
            for (const tx of held) await db.finish('greedy', tx.id, false);
            await db.finish('polite', other.id, false);
            await zero(db); await db.close();
        });
        await t.test('the SQL patterns the Feather resources use work through transactions', async () => {
            await admin.query(`CREATE TABLE ${database}.receipts (source_resource VARCHAR(40) NOT NULL, request_id VARCHAR(40) NOT NULL,
                request_fingerprint VARCHAR(64) NOT NULL, result_json TEXT NULL, PRIMARY KEY (source_resource, request_id)) ENGINE=InnoDB`);
            await admin.query(`CREATE TABLE ${database}.grants (assignment_id CHAR(36) PRIMARY KEY, role_id INT NOT NULL, revision INT NOT NULL) ENGINE=InnoDB`);
            await admin.query(`CREATE TABLE ${database}.\`cartography_discoveries\` (\`owner_key\` VARCHAR(20), \`x\` DOUBLE, \`y\` DOUBLE, \`z\` DOUBLE,
                PRIMARY KEY (\`owner_key\`, \`x\`, \`y\`)) ENGINE=InnoDB`);
            const db = factory(3);
            const receipt = async () => {
                const tx = await db.begin('authority');
                const q = (sql, p = []) => db.transactionQuery('authority', tx.id, sql, p);
                const first = await q('INSERT IGNORE INTO `receipts` (`source_resource`,`request_id`,`request_fingerprint`) VALUES (?,?,?)', ['res', 'req-1', 'fp']);
                const rows = (await q('SELECT `request_fingerprint`,`result_json` FROM `receipts` WHERE `source_resource`=? AND `request_id`=? FOR UPDATE', ['res', 'req-1'])).rows;
                const total = (await q('SELECT COUNT(*) AS `count` FROM `receipts`')).rows[0].count;
                await db.finish('authority', tx.id, true);
                return { written: first.header.affectedRows, fingerprint: rows[0].request_fingerprint, total };
            };
            const one = await receipt(), again = await receipt();
            assert.deepEqual([one.written, again.written], [1, 0], 'INSERT IGNORE reports whether a row was written');
            assert.equal(one.fingerprint, 'fp');
            assert.strictEqual(one.total, 1, 'COUNT(*) AS `count` is a number');
            assert.equal((await query(db, 'SELECT UUID() AS `id`')).rows[0].id.length, 36);
            // The native equivalent of a fixed statement list, one connection for the whole thing:
            // what a Lua DB.transaction loop (or an exported statement-list transaction, when that
            // still existed) actually does underneath.
            const runAsTransaction = async (owner, statements) => {
                const tx = await db.begin(owner);
                for (const { sql, parameters } of statements) await db.transactionQuery(owner, tx.id, sql, parameters);
                return db.finish(owner, tx.id, true);
            };
            assert.equal(await runAsTransaction('roles', [
                { sql: 'INSERT INTO grants (assignment_id, role_id, revision) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE role_id = VALUES(role_id), revision = VALUES(revision)', parameters: ['a-1', 1, 1] },
                { sql: 'INSERT INTO grants (assignment_id, role_id, revision) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE role_id = VALUES(role_id), revision = VALUES(revision)', parameters: ['a-1', 9, 2] },
            ]), true);
            const grant = (await query(db, 'SELECT role_id, revision FROM grants WHERE assignment_id = ?', ['a-1'])).rows[0];
            assert.deepEqual({ ...grant }, { role_id: 9, revision: 2 });
            const sets = [['o', 1.5, 2.5, 0], ['o', 3.5, 4.5, 0], ['o', 1.5, 2.5, 0]];
            assert.equal(await runAsTransaction('cartography', sets.map(parameters => ({
                sql: 'INSERT IGNORE INTO `cartography_discoveries` (`owner_key`, `x`, `y`, `z`) VALUES (?, ?, ?, ?)', parameters }))), true);
            assert.strictEqual(await scalar(db, 'SELECT COUNT(*) FROM cartography_discoveries'), 2, 'The duplicate set was ignored');
            await zero(db); await db.close();
        });
        await t.test('the start-up probe reaches a real database and reports a missing one without hanging', async () => {
            const reachable = factory(2);
            assert.deepEqual(reachable.readiness(), { ready: false, code: null, health: 'starting' });
            const reports = [];
            assert.equal(await reachable.awaitDatabase((ready, code, attempt) => reports.push([ready, code, attempt])), true);
            assert.deepEqual(reports, [[true, null, 1]]);
            assert.deepEqual(reachable.readiness(), { ready: true, code: null, health: 'connected' });
            await zero(reachable); await reachable.close();
            const missing = factory(1, 3000, 5000, { socketPath: path.join(directory, 'no-such.sock') });
            const seen = [];
            const waiting = missing.awaitDatabase((ready, code) => seen.push([ready, code]));
            await delay(150);
            assert.equal(missing.readiness().ready, false);
            assert.equal(typeof missing.readiness().code, 'string', 'The failure code is kept (for example ENOENT)');
            assert.deepEqual(seen.map(entry => entry[0]), [false], 'The first failure is reported once, not every retry');
            const closing = Date.now();
            await missing.close();
            assert.equal(await waiting, false);
            assert.equal(Date.now() - closing < 1000, true, 'Closing ends the retry loop at once');
        });
        await t.test('SHOW COLUMNS ... LIKE ? works through the text retry, exactly as the Feather scripts send it', async () => {
            await admin.query(`CREATE TABLE ${database}.inventory (id INT PRIMARY KEY, characters_id INT NULL, \`it's\` INT NULL, \`back\\slash\` INT NULL) ENGINE=InnoDB`);
            await admin.query(`CREATE TABLE ${database}.feather_weapon_issuance_requests (id BIGINT PRIMARY KEY, purpose VARCHAR(48)) ENGINE=InnoDB`);
            const db = factory(2);
            // feather-inventory server/services/inventory.lua:52, including its trailing semicolon
            const column = await query(db, 'SHOW COLUMNS FROM `inventory` LIKE ?;', ['characters_id']);
            assert.equal(column.rows.length, 1);
            assert.equal(column.rows[0].Field, 'characters_id');
            assert.equal((await query(db, 'SHOW COLUMNS FROM `inventory` LIKE ?;', ['missing_id'])).rows.length, 0, 'An absent column is an empty result, not an error');
            // feather-weapons server/services/provenance.lua:64
            assert.equal((await query(db, 'SHOW COLUMNS FROM `feather_weapon_issuance_requests` LIKE ?', ['definition_id'])).rows.length, 0);
            assert.equal((await query(db, 'SHOW COLUMNS FROM `feather_weapon_issuance_requests` LIKE ?', ['purpose'])).rows.length, 1);
            assert.equal(db.diagnostics().totals.textFallbacks, 4, 'Each of those statements needed the retry, and only those');
            await query(db, 'SELECT 1 WHERE ? = ?', [1, 1]);
            assert.equal(db.diagnostics().totals.textFallbacks, 4, 'Ordinary statements stay on the prepared path');
            await zero(db); await db.close();
        });
        await t.test('values reaching the text retry are escaped, never interpreted', async () => {
            const db = factory(2);
            assert.equal((await query(db, 'SHOW COLUMNS FROM `inventory` LIKE ?', ["it's"])).rows.length, 1, 'An apostrophe matches a column named with one');
            assert.equal((await query(db, 'SHOW COLUMNS FROM `inventory` LIKE ?', ['back\\\\slash'])).rows.length, 1, 'A backslash survives escaping (LIKE itself reads \\\\ as one backslash)');
            for (const hostile of ["x' OR '1'='1", "x'; DROP TABLE inventory; --", 'x\\\' OR 1=1 -- ', 'x\u0000y', 'x\n\r\u001ay', '\u{1F600}\u65e5\u672c', '%', '_', '']) {
                const result = await query(db, 'SHOW COLUMNS FROM `inventory` LIKE ?', [hostile]);
                // Only LIKE's own behaviour acts: '%' matches all four columns, and so does '' (MariaDB treats
                // even a hand-written LIKE '' as no filter); nothing else matches any.
                assert.equal(result.rows.length, hostile === '%' || hostile === '' ? 4 : 0,
                    `${JSON.stringify(hostile)} must behave as one literal pattern`);
            }
            assert.equal(await scalar(db, 'SELECT COUNT(*) FROM inventory'), 0);
            assert.equal((await admin.query(`SHOW TABLES FROM ${database} LIKE 'inventory'`))[0].length, 1, 'No injected statement dropped the table');
            await zero(db); await db.close();
        });
        await t.test('a transaction can use the text retry too', async () => {
            const db = factory(2); const tx = await db.begin('a');
            const shown = await db.transactionQuery('a', tx.id, 'SHOW COLUMNS FROM `inventory` LIKE ?', ['characters_id']);
            assert.equal(shown.rows.length, 1);
            await db.finish('a', tx.id, true);
            await zero(db); await db.close();
        });
        await t.test('the text retry refuses when the server does not honour backslash escapes', async () => {
            const [[original]] = await admin.query('SELECT @@GLOBAL.sql_mode AS mode');
            await admin.query("SET GLOBAL sql_mode = 'NO_BACKSLASH_ESCAPES'");
            try {
                const db = factory(1);
                await assert.rejects(query(db, 'SHOW COLUMNS FROM `inventory` LIKE ?', ['characters_id']), { code: 'ER_PARSE_ERROR' });
                assert.equal(db.diagnostics().totals.textFallbacks, 0);
                await zero(db); await db.close();
            } finally { await admin.query('SET GLOBAL sql_mode = ?', [original.mode]); }
        });
        await t.test('commit, own-write reads and same-connection affinity', async () => {
            await seed(); const db = factory(); const tx = await db.begin('a');
            const first = await db.transactionQuery('a', tx.id, 'SELECT CONNECTION_ID() AS id', []);
            await db.transactionQuery('a', tx.id, 'UPDATE records SET value = ? WHERE id = ?', [125, 1]);
            const read = await db.transactionQuery('a', tx.id, 'SELECT value, CONNECTION_ID() AS id FROM records WHERE id = ?', [1]);
            assert.equal(read.rows[0].value, 125); assert.equal(read.rows[0].id, first.rows[0].id);
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = ?', [1]), 100);
            assert.equal(await db.finish('a', tx.id, true), true);
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = ?', [1]), 125);
            await zero(db); await db.close();
        });
        await t.test('explicit rollback restores data and concurrent transactions have distinct sessions', async () => {
            await seed(); const db = factory();
            const [a, b] = await Promise.all([db.begin('a'), db.begin('b')]);
            const [ra, rb] = await Promise.all([
                db.transactionQuery('a', a.id, 'SELECT CONNECTION_ID() AS id', []),
                db.transactionQuery('b', b.id, 'SELECT CONNECTION_ID() AS id', []),
            ]);
            assert.notEqual(ra.rows[0].id, rb.rows[0].id);
            await Promise.all([
                db.transactionQuery('a', a.id, 'UPDATE records SET value = value + 1 WHERE id = ?', [1]),
                db.transactionQuery('b', b.id, 'UPDATE records SET value = value + 2 WHERE id = ?', [2]),
            ]);
            await db.finish('a', a.id, false); await db.finish('b', b.id, true);
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 1'), 100);
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 2'), 102);
            await zero(db); await db.close();
        });
        for (const [name, sql, code] of [
            ['SQL syntax', 'SELECT * FROM', 'ER_PARSE_ERROR'],
            ['duplicate key', 'INSERT INTO records (id, value) VALUES (1, 999)', 'ER_DUP_ENTRY'],
        ]) await t.test(`${name} failure rolls back prior writes and poisons the transaction`, async () => {
            await seed(); const db = factory(); const tx = await db.begin('a');
            await db.transactionQuery('a', tx.id, 'UPDATE records SET value = 999 WHERE id = 2', []);
            await assert.rejects(db.transactionQuery('a', tx.id, sql, []), { code });
            await assert.rejects(db.finish('a', tx.id, true), { code });
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 2'), 100);
            await assert.rejects(query(db, sql), { code });
            assert.equal(await scalar(db, 'SELECT 1'), 1);
            await zero(db); await db.close();
        });
        await t.test('real InnoDB deadlock victim rolls back and the surviving transaction can commit', async () => {
            await seed(); const db = factory(); const a = await db.begin('a'); const b = await db.begin('b');
            await db.transactionQuery('a', a.id, 'UPDATE records SET value = value + 1 WHERE id = 1', []);
            await db.transactionQuery('b', b.id, 'UPDATE records SET value = value + 1 WHERE id = 2', []);
            const results = await Promise.allSettled([
                db.transactionQuery('a', a.id, 'UPDATE records SET value = value + 1 WHERE id = 2', []),
                db.transactionQuery('b', b.id, 'UPDATE records SET value = value + 1 WHERE id = 1', []),
            ]);
            assert.equal(results.filter(r => r.status === 'rejected').length, 1);
            const loser = results.findIndex(r => r.status === 'rejected');
            assert.equal(results[loser].reason.code, 'ER_LOCK_DEADLOCK');
            assert.equal(results[loser].reason.outcome, 'rolled_back');
            assert.equal(results[loser].reason.rollbackConfirmed, true);
            const owners = ['a', 'b'], handles = [a, b];
            await assert.rejects(db.finish(owners[loser], handles[loser].id, false),
                { code: 'ER_LOCK_DEADLOCK', rollbackConfirmed: true, outcome: 'rolled_back' });
            await db.finish(owners[1 - loser], handles[1 - loser].id, true);
            assert.equal(await scalar(db, 'SELECT SUM(value) FROM records'), '202');
            await zero(db); await db.close();
        });
        await t.test('idle transaction timeout rolls back before a late COMMIT attempt', async () => {
            await seed(); const db = factory(2, 3000, 100); const tx = await db.begin('a');
            await db.transactionQuery('a', tx.id, 'UPDATE records SET value = 999 WHERE id = 1', []);
            await delay(150);
            await assert.rejects(db.finish('a', tx.id, true), { code: 'TRANSACTION_TIMEOUT' });
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 1'), 100);
            await zero(db); await db.close();
        });
        await t.test('timeout during transaction SQL retires the lease and the server eventually rolls back', async () => {
            await seed(); const db = factory(2, 3000, 100); const tx = await db.begin('a');
            const id = (await db.transactionQuery('a', tx.id, 'SELECT CONNECTION_ID() AS id', [])).rows[0].id;
            await db.transactionQuery('a', tx.id, 'UPDATE records SET value = 999 WHERE id = 1', []);
            await assert.rejects(db.transactionQuery('a', tx.id, 'SELECT SLEEP(?)', [0.3]), { code: 'TRANSACTION_TIMEOUT' });
            await zero(db);
            let processes = (await admin.query('SHOW PROCESSLIST'))[0];
            const stillExecuting = processes.some(p => p.Id === id);
            console.log('Transaction timeout: server session still present at client cancellation:', stillExecuting);
            for (let i = 0; i < 100 && processes.some(p => p.Id === id); i++) {
                await delay(20);
                processes = (await admin.query('SHOW PROCESSLIST'))[0];
            }
            assert.equal(processes.some(p => p.Id === id), false, 'Server session must eventually disappear');
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 1'), 100);
            await assert.rejects(db.finish('a', tx.id, true), { code: 'TRANSACTION_TIMEOUT' });
            await zero(db); await db.close();
        });
        await t.test('query timeout closes the client transport and later requests reconnect', async () => {
            const db = factory(1, 40);
            await assert.rejects(query(db, 'SELECT SLEEP(?)', [0.1]), { code: 'QUERY_TIMEOUT' });
            assert.equal(await scalar(db, 'SELECT 1'), 1);
            await zero(db); await db.close();
        });
        await t.test('consumer stop cancels owned work and rolls back its open transaction', async () => {
            await seed(); const db = factory(); const tx = await db.begin('consumer');
            await db.transactionQuery('consumer', tx.id, 'UPDATE records SET value = 999 WHERE id = 1', []);
            const pending = query(db, 'SELECT SLEEP(?)', [0.1], 'consumer');
            const failed = assert.rejects(pending, { code: 'RESOURCE_STOPPED' });
            await delay(10); db.abortOwner('consumer'); await failed;
            await assert.rejects(db.finish('consumer', tx.id, true), { code: 'RESOURCE_STOPPED' });
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 1'), 100);
            await zero(db); await db.close();
        });
        await t.test('server-side disconnect rolls back and new requests reconnect without retry', async () => {
            await seed(); const db = factory(); const tx = await db.begin('a');
            const id = (await db.transactionQuery('a', tx.id, 'SELECT CONNECTION_ID() AS id', [])).rows[0].id;
            await db.transactionQuery('a', tx.id, 'UPDATE records SET value = 999 WHERE id = 1', []);
            await admin.query('KILL CONNECTION ?', [id]);
            await delay(10);
            await assert.rejects(db.transactionQuery('a', tx.id, 'SELECT 1', []));
            assert.equal(await scalar(db, 'SELECT value FROM records WHERE id = 1'), 100);
            await zero(db); await db.close();
        });
        await t.test('session variables and raw BEGIN do not survive ordinary query release', async () => {
            const db = factory(1);
            await query(db, 'SET @feather_test_variable = 42');
            assert.equal(await scalar(db, 'SELECT @feather_test_variable'), null);
            await query(db, 'START TRANSACTION');
            assert.equal(String(await scalar(db, 'SELECT @@in_transaction')), '0');
            await zero(db); await db.close();
        });
        await t.test('provider stop retires connections; a replacement driver starts cleanly', async () => {
            await seed(); const db = factory(); const tx = await db.begin('a');
            await db.transactionQuery('a', tx.id, 'UPDATE records SET value = 999 WHERE id = 1', []);
            const pending = query(db, 'SELECT SLEEP(?)', [0.1]);
            const failed = assert.rejects(pending, { code: 'RESOURCE_STOPPED' });
            await delay(10); await db.close(); await failed; await zero(db);
            await assert.rejects(query(db, 'SELECT 1'), { code: 'RESOURCE_STOPPED' });
            const next = factory();
            assert.equal(await scalar(next, 'SELECT value FROM records WHERE id = 1'), 100);
            await zero(next); await next.close();
        });
        await t.test('database process stop/restart fails pending work and restores connectivity', async () => {
            const db = factory();
            const pending = query(db, 'SELECT SLEEP(?)', [2]);
            const failed = assert.rejects(pending);
            await delay(20);
            const pid = Number(fs.readFileSync(path.join(directory, 'mysql.pid'), 'utf8'));
            process.kill(pid, 'SIGTERM');
            await failed;
            for (let i = 0; i < 100 && fs.existsSync(socketPath); i++) await delay(50);
            replacement = spawn('/usr/sbin/mariadbd', ['--no-defaults', `--datadir=${directory}/data`,
                `--socket=${socketPath}`, `--pid-file=${directory}/mysql.pid`, `--log-error=${directory}/server.log`,
                '--skip-networking', '--skip-log-bin', '--innodb-buffer-pool-size=32M', '--innodb-log-file-size=16M',
                '--innodb-use-native-aio=0', '--max-connections=32'], { stdio: 'ignore' });
            for (let i = 0; i < 100 && !fs.existsSync(socketPath); i++) await delay(50);
            assert.ok(fs.existsSync(socketPath), 'Database restarted');
            assert.equal(await scalar(db, 'SELECT 1'), 1);
            await zero(db); await db.close();
            admin.destroy(); admin = await mysql.createConnection({ socketPath, user: 'root' });
        });
        await t.test('batched statements retain connection affinity and allow validation before commit', async () => {
            await seed(); const db=factory(); const tx=await db.begin('batch');
            const values=await db.transactionBatch('batch',tx.id,[
                {sql:'SELECT CONNECTION_ID() AS id',parameters:[]},
                {sql:'UPDATE records SET value=? WHERE id=1',parameters:[777]},
                {sql:'SELECT CONNECTION_ID() AS id',parameters:[]}
            ]);
            assert.equal(values[0].first,values[2].first);
            assert.equal(values[1].header.affectedRows,1);
            await db.finish('batch',tx.id,false);
            assert.equal(await scalar(db,'SELECT value FROM records WHERE id=1'),100);
            await zero(db); await db.close();
        });
        await t.test('batched SQL failure rolls prior writes back and stops later statements', async () => {
            await seed(); const db=factory(); const tx=await db.begin('batch');
            await assert.rejects(db.transactionBatch('batch',tx.id,[
                {sql:'UPDATE records SET value=777 WHERE id=1',parameters:[]},
                {sql:'SELECT * FROM missing_batch_table',parameters:[]},
                {sql:'UPDATE records SET value=999 WHERE id=1',parameters:[]}
            ]),e=>e.rollbackConfirmed===true && e.outcome==='rolled_back');
            assert.equal(await scalar(db,'SELECT value FROM records WHERE id=1'),100);
            await zero(db); await db.close();
        });
        // Driver counters alone are insufficient evidence: check actual server sessions.
        await delay(200);
        const processes = (await admin.query('SHOW PROCESSLIST'))[0];
        assert.equal(processes.filter(p => p.db === database).length, 0, 'No test pool sessions left on MariaDB');
        console.log('Leak audit: no active operations, checked-out leases, transactions or remaining test DB sessions.');
    } finally {
        await Promise.allSettled([...drivers].map(db => db.close()));
        await admin.end().catch(() => {});
        if (replacement && replacement.exitCode === null) replacement.kill('SIGTERM');
    }
});
