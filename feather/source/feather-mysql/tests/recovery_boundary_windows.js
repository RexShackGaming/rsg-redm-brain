'use strict';
// Standalone Windows/Linux acceptance runner; never loaded by the resource.
const assert = require('node:assert/strict');
const { fork } = require('node:child_process');
const crypto = require('node:crypto');
const mysql = require('mysql2/promise');
const { Driver } = require('../bridge/driver');
const { publicError } = require('../bridge/errors');
const { parseConnectionString, connectionOptions } = require('../bridge/config');
const { commitReplyProxy } = require('./commit_reply_proxy');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let stage = 'configuration';
const options = () => {
    assert.equal(process.env.FEATHER_RECOVERY_DEDICATED, 'YES', 'Dedicated test database opt-in required');
    assert.ok(process.env.FEATHER_RECOVERY_URL, 'Set FEATHER_RECOVERY_URL privately; it is never printed');
    const config = connectionOptions(parseConnectionString(process.env.FEATHER_RECOVERY_URL));
    assert.ok(!config.ssl, 'This local test proxy requires a non-TLS dedicated test connection');
    return config;
};
const driver = config => new Driver(mysql.createPool({ ...config, connectionLimit: 1, rowsAsArray: true }), 5000, 15000,
    undefined, { sessionOptions: { database: config.database, charset: config.charset } });

async function worker() {
    const db = driver(options());
    const table = process.env.FEATHER_RECOVERY_TABLE;
    assert.match(table, /^feather_recovery_[a-f0-9]{16}$/);
    const tx = await db.begin('crash-fixture');
    const id = (await db.transactionQuery('crash-fixture', tx.id, 'SELECT CONNECTION_ID()', [])).first;
    await db.transactionQuery('crash-fixture', tx.id, `UPDATE ${table} SET value=200 WHERE id=1`, []);
    process.send({ phase: 'uncommitted', connectionId: id });
    // Parent terminates this process. No COMMIT, rollback, or retry is requested.
    setInterval(() => {}, 1000);
}

async function main() {
    const config = options();
    stage = 'database_connection';
    const admin = await mysql.createConnection(config);
    if (process.argv.includes('--check')) {
        try {
            stage = 'readonly_connection_check';
            await admin.query('SELECT 1');
            const [rows] = await admin.query("SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME REGEXP '^feather_recovery_[a-f0-9]{16}$'");
            console.log('PASS read-only database connection check; no writes or fault injection');
            console.log('Remaining isolated fixture tables:', JSON.stringify(rows.map(row => row.TABLE_NAME)));
        } finally { await admin.end(); }
        return;
    }
    const table = `feather_recovery_${crypto.randomBytes(8).toString('hex')}`;
    console.log(`Isolated fixture table: ${table} (only this generated table is created/dropped)`);
    let proxy, db, child, created = false;
    try {
        stage = 'fixture_create';
        await admin.query(`CREATE TABLE ${table} (id INT PRIMARY KEY, value INT NOT NULL) ENGINE=InnoDB`); created = true;
        stage = 'fixture_seed';
        await admin.query(`INSERT INTO ${table} VALUES (1,100)`);
        stage = 'proxy_start';
        proxy = await commitReplyProxy(config.socketPath ? { path: config.socketPath } : { host: config.host || 'localhost', port: config.port || 3306 });
        db = driver({ ...config, socketPath: undefined, host: '127.0.0.1', port: proxy.port });
        stage = 'proxied_transaction_begin';
        const tx = await db.begin('commit-reply-loss');
        stage = 'proxied_transaction_update';
        await db.transactionQuery('commit-reply-loss', tx.id, `UPDATE ${table} SET value=101 WHERE id=1`, []);
        stage = 'commit_reply_loss';
        // Match bridge/index.js: mysql2 transport errors are classified at the
        // public error boundary; the raw driver Error need not have outcome.
        await assert.rejects(db.finish('commit-reply-loss', tx.id, true), error => publicError(error).outcome === 'unknown');
        stage = 'commit_independent_readback';
        assert.deepEqual(proxy.evidence, { commitsForwarded: 1, repliesDropped: 1 });
        assert.equal((await admin.query(`SELECT value FROM ${table} WHERE id=1`))[0][0].value, 101);
        console.log('PASS real COMMIT reply loss: caller unknown, independent row committed once, no retry');
        await db.close(); db = undefined; await proxy.close(); proxy = undefined;
        stage = 'worker_start';
        child = fork(__filename, ['--worker'], { env: { ...process.env, FEATHER_RECOVERY_TABLE: table }, stdio: ['ignore','ignore','ignore','ipc'] });
        const ready = await new Promise((resolve, reject) => {
            const timeout = setTimeout(() => reject(new Error('Worker readiness timeout')), 15000);
            child.once('message', value => { clearTimeout(timeout); resolve(value); });
            child.once('exit', () => { clearTimeout(timeout); reject(new Error('Worker exited before readiness')); });
            child.once('error', error => { clearTimeout(timeout); reject(error); });
        });
        assert.equal(ready.phase, 'uncommitted');
        const exited = new Promise(resolve => child.once('exit', resolve));
        stage = 'worker_termination';
        child.kill('SIGKILL'); await exited;
        stage = 'worker_independent_readback';
        let gone = false;
        for (let i=0; i<100; i++) {
            gone = (await admin.query('SELECT ID FROM information_schema.PROCESSLIST WHERE ID=?', [ready.connectionId]))[0].length === 0;
            if (gone) break;
            await delay(50);
        }
        assert.ok(gone, 'Worker database connection must be gone before readback');
        assert.equal((await admin.query(`SELECT value FROM ${table} WHERE id=1`))[0][0].value, 101);
        console.log('PASS abrupt worker death: connection gone, independent row unchanged, no retry');
    } finally {
        if (child && child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
        if (db) await db.close();
        if (proxy) await proxy.close();
        if (created) {
            try { await admin.query(`DROP TABLE ${table}`); console.log('Fixture cleanup confirmed'); }
            catch (error) { stage = 'fixture_cleanup'; throw error; }
        }
        await admin.end();
    }
}
(process.argv.includes('--worker') ? worker() : main()).catch(error => {
    // Do not print driver errors, connection strings, or credentials.
    const code = typeof error.code === 'string' && /^[A-Z0-9_]{1,80}$/.test(error.code) ? error.code : 'UNCLASSIFIED';
    console.error(`FAIL recovery boundary test: stage=${stage} code=${code}; no automatic retry. SQL, credentials and error messages withheld.`);
    process.exitCode = 1;
});
