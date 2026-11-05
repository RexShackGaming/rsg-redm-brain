'use strict';
// Invoked only by run_benchmark.py, against a disposable private MariaDB (never server.cfg).
//
// Measures the real driver alongside a minimal mysql2 text-query baseline. The baseline
// releases connections without resetting session state and is not feature-equivalent.
// Both use the same mysql2 version, pool size and private MariaDB, one after the other.
// This excludes Cfx/Lua transport, date type conversion, text fallback and deadlock retries.
const path = require('node:path');
const mysql = require('mysql2/promise');
const { Driver, Latencies } = require('../bridge/driver');
const { parseConnectionString } = require('../bridge/config');

const directory = process.env.FEATHER_MYSQL_PRIVATE_DIR;
if (!directory || !path.basename(directory).startsWith('feather-mysql-benchmark-')) {
    throw new Error('Run through python3 tests/run_benchmark.py with an isolated database');
}
const socketPath = path.join(directory, 'mysql.sock');
const database = 'feather_mysql_benchmark';
const POOL_SIZE = 8;
const WARMUP = 50;
const ITERATIONS = Number(process.env.BENCH_ITERATIONS || 1000);
const CONCURRENCY = Number(process.env.BENCH_CONCURRENCY || 20);

// A minimal driver holding only what the benchmarked scenarios exercise: acquire, run one
// statement as text, release without a reset, run a 3-statement transaction the same way.
class PlainMysql2 {
    constructor(pool) { this.pool = pool; }
    async run(sql, parameters) {
        const connection = await this.pool.getConnection();
        try { return await connection.query(sql, parameters); }
        finally { connection.release(); }
    }
    async transaction(statements) {
        const connection = await this.pool.getConnection();
        try {
            await connection.beginTransaction();
            for (const { sql, parameters } of statements) await connection.query(sql, parameters);
            await connection.commit();
        } catch (error) { await connection.rollback().catch(() => {}); throw error; }
        finally { connection.release(); }
    }
}

function statsLine(label, latencies) {
    const s = latencies.summary();
    const fmt = ms => (ms === null ? '-' : ms.toFixed(2).padStart(7));
    return `${label.padEnd(34)} n=${String(s.count).padStart(5)}  p50=${fmt(s.p50)}ms  p95=${fmt(s.p95)}ms  p99=${fmt(s.p99)}ms`;
}

// Runs `work()` WARMUP+ITERATIONS times sequentially, discards the warm-up, times the rest.
async function timeSequential(work) {
    const latencies = new Latencies(ITERATIONS);
    for (let i = 0; i < WARMUP; i++) await work(i);
    for (let i = 0; i < ITERATIONS; i++) {
        const started = process.hrtime.bigint();
        await work(i);
        latencies.record(Number(process.hrtime.bigint() - started) / 1e6);
    }
    return latencies;
}
// Runs `work()` CONCURRENCY at a time until ITERATIONS have completed, timing the whole batch of
// each wave -- a rough throughput figure alongside the per-call latency from timeSequential.
async function timeConcurrent(work) {
    for (let i = 0; i < WARMUP; ) { await Promise.all(Array.from({ length: Math.min(CONCURRENCY, WARMUP - i) }, () => work(i++))); }
    const started = process.hrtime.bigint();
    let issued = 0;
    while (issued < ITERATIONS) {
        const wave = Math.min(CONCURRENCY, ITERATIONS - issued);
        await Promise.all(Array.from({ length: wave }, () => work(WARMUP + issued++)));
    }
    const elapsedMs = Number(process.hrtime.bigint() - started) / 1e6;
    return { elapsedMs, perSecond: (ITERATIONS / elapsedMs) * 1000 };
}

async function scenarios(name, run, transaction) {
    console.log(`\n-- ${name} --`);
    console.log(statsLine('point SELECT (sequential)', await timeSequential(i => run('SELECT id, value, sample FROM bench_records WHERE id = ?', [(i % 1000) + 1]))));
    console.log(statsLine('single INSERT (sequential)', await timeSequential(i => run('INSERT INTO bench_records (value, sample) VALUES (?, ?)', [i, `row-${i}`]))));
    console.log(statsLine('repeated identical SELECT (sequential)', await timeSequential(() => run('SELECT value FROM bench_records WHERE id = ?', [1]))));
    console.log(statsLine('3-statement transaction (sequential)', await timeSequential(i => transaction([
        { sql: 'SELECT value FROM bench_records WHERE id = ? FOR UPDATE', parameters: [(i % 1000) + 1] },
        { sql: 'UPDATE bench_records SET value = value + 1 WHERE id = ?', parameters: [(i % 1000) + 1] },
        { sql: 'UPDATE bench_records SET value = value - 1 WHERE id = ?', parameters: [((i + 1) % 1000) + 1] },
    ]))));
    const burst = await timeConcurrent(i => run('SELECT id, value, sample FROM bench_records WHERE id = ?', [(i % 1000) + 1]));
    console.log(`point SELECT, ${CONCURRENCY} concurrent`.padEnd(34) +
        `${burst.elapsedMs.toFixed(0).padStart(7)}ms total, ${burst.perSecond.toFixed(0).padStart(6)} req/s`);
}

(async () => {
    const admin = await mysql.createConnection({ socketPath, user: 'root' });
    await admin.query(`CREATE DATABASE ${database}`);
    await admin.query(`CREATE TABLE ${database}.bench_records (id INT PRIMARY KEY AUTO_INCREMENT, value INT NOT NULL, sample VARCHAR(255) NULL) ENGINE=InnoDB`);
    const seedValues = Array.from({ length: 1000 }, (_, i) => `(${i + 1}, 0, 'seed-${i + 1}')`).join(',');
    await admin.query(`INSERT INTO ${database}.bench_records (id, value, sample) VALUES ${seedValues}`);
    await admin.end();

    console.log(`feather-mysql vs a plain mysql2 baseline, pool size ${POOL_SIZE}, ${ITERATIONS} iterations (${WARMUP} warm-up, discarded), ${CONCURRENCY}-way concurrent burst.`);

    {
        const config = parseConnectionString(`mysql://root@localhost/${database}?connectionLimit=${POOL_SIZE}`);
        const driver = new Driver(mysql.createPool({ ...config, socketPath }), 5000, 5000, undefined,
            { sessionOptions: { database: config.database, charset: config.charset } });
        await scenarios('feather-mysql (prepared statements, changeUser reset before reuse)',
            (sql, parameters) => driver.run(sql, parameters, 'benchmark'),
            async statements => {
                const tx = await driver.begin('benchmark');
                for (const { sql, parameters } of statements) await driver.transactionQuery('benchmark', tx.id, sql, parameters);
                return driver.finish('benchmark', tx.id, true);
            });
        await driver.drain();
        await driver.close();
    }
    {
        const config = parseConnectionString(`mysql://root@localhost/${database}?connectionLimit=${POOL_SIZE}`);
        const pool = mysql.createPool({ ...config, socketPath });
        const equivalent = new PlainMysql2(pool);
        await scenarios('plain mysql2 (text protocol, plain release, no reset)',
            (sql, parameters) => equivalent.run(sql, parameters),
            statements => equivalent.transaction(statements));
        await pool.end();
    }
    console.log('\nRe-run with the two blocks swapped (or BENCH_ITERATIONS/BENCH_CONCURRENCY changed) to sanity-check ordering effects on this one machine.');
})().catch(error => { console.error('BENCHMARK FAILURE', error); process.exit(1); });
