# Feather MySQL

A standalone MySQL/MariaDB resource for FiveM and RedM. Use plain Lua `DB.*` calls backed by a pooled mysql2 transport.

```lua
local user = DB.one('SELECT * FROM users WHERE identifier = ?', identifier)
```

- **Five small functions** (`query`, `one`, `value`, `insert`, `exec`) and real **transactions**.
- **Safe by default.** Values are always sent as parameters, never pasted into SQL.
- **Bounded requests.** A busy pool queues requests up to its configured limit. Deadlines stop waiting, and cancellation on the database server is best effort.
- **Structured errors.** Errors identify the caller and failure, and report when a write outcome is unknown.

Includes automated Node, Lua and isolated MariaDB checks. Validate startup, shutdown and your resource workflows on a staging server before deployment. See [Limits](#limits).

## Install

1. Put this folder at `resources/[feather]/feather-mysql`. Keep the name.
2. Install the one dependency inside the folder:

   ```sh
   npm ci --omit=dev --ignore-scripts
   ```

3. In `server.cfg`, set the connection string **before** the ensure lines, and ensure this resource before the ones that use it:

   ```cfg
   set mysql_connection_string "mysql://user:password@127.0.0.1:3306/database?charset=utf8mb4"
   ensure feather-mysql
   ensure your-resource
   ```

   Percent-encode special characters in the user name or password (`@` is `%40`, `;` is `%3B`).

4. Start the server. You should see these lines:

   ```text
   [feather-mysql] Database reachable.
   [feather-mysql] Bridge self-check OK.
   ```

   If the self-check says `FAILED`, database calls will not work, and the message says why.

Requires an FXServer artifact with Node 22 and a MySQL or MariaDB server. The database and user must already exist.

## Use it in your resource

`fxmanifest.lua`:

```lua
dependency 'feather-mysql'
server_scripts {
    '@feather-mysql/lib/DB.lua',
    'server.lua',
}
```

`server.lua`. Calls must run inside `CreateThread`, an event handler, or a command; they wait for the database without blocking the server.

```lua
CreateThread(function()
    local rows  = DB.query('SELECT id, name FROM items WHERE owner = ?', identifier)   -- all rows
    local user  = DB.one('SELECT * FROM users WHERE id = ?', 42)                        -- first row or nil
    local count = DB.value('SELECT COUNT(*) FROM items WHERE owner = ?', identifier)   -- one value
    local id    = DB.insert('INSERT INTO items (owner, name) VALUES (?, ?)', identifier, "O'Brien")
    local n     = DB.exec('UPDATE items SET name = ? WHERE id = ?', 'Renamed', id)      -- affected rows
end)
```

| Function | Returns |
| --- | --- |
| `DB.query(sql, ...)` | Array of rows (empty when none) |
| `DB.one(sql, ...)` | First row, or `nil` |
| `DB.value(sql, ...)` | First column of the first row, or `nil` |
| `DB.insert(sql, ...)` | The new row's id |
| `DB.exec(sql, ...)` | Number of affected rows |

Use the function that matches the statement. Pass values as separate arguments after the SQL. An explicit `nil` binds SQL `NULL`; `false`, `0` and `''` are ordinary values. Integers must be within ±(2^53−1); pass larger ids as strings.

Also available: `DB.raw(sql, ...)` (rows for a read, `{ affectedRows, insertId }` for a write), `DB.isReady()` and `DB.awaitReady(timeoutMs)`.

More examples, including player events and exporting your own API, are in [docs/USAGE.md](docs/USAGE.md).

### What comes back

| SQL type | Lua value |
| --- | --- |
| `INT`, `BIGINT` within ±(2^53−1), `COUNT(*)` | number |
| `BIGINT` outside that range | string (exact) |
| `DECIMAL`, and `SUM()` of integers | string (exact, never rounded) |
| `FLOAT`, `DOUBLE` | number |
| dates, times, JSON | string |
| `NULL` | `nil` |

## Transactions

Use a transaction when several statements must succeed or fail together.

```lua
local ok, committed = pcall(DB.transaction, function(tx)
    local balance = tx.value('SELECT balance FROM accounts WHERE id = ? FOR UPDATE', fromId)
    if not balance or balance < amount then return false end       -- roll back
    tx.exec('UPDATE accounts SET balance = balance - ? WHERE id = ?', amount, fromId)
    tx.exec('UPDATE accounts SET balance = balance + ? WHERE id = ?', amount, toId)
    return true                                                     -- commit
end)
```

- `tx` has the same query functions as `DB`, including `raw`. All run on the connection that began the transaction.
- Return `true` to commit. Returning `false` **or nothing** rolls back, so check the result.
- Any error prevents commit, attempts rollback and is raised. Catching a query error inside the callback does not let it commit. A failed rollback confirmation reports `outcome = 'unknown'`.
- Use `tx.*`, not `DB.*`, inside the callback: `DB.*` runs on a different connection and is not part of the transaction. A warning names the file and line of the call, once per place (every time with `feather_mysql_devmode`).
- Keep transactions short. Each holds a connection, and a resource may hold at most half the pool by default.
- Do not nest `DB.transaction` in the same coroutine.
- Set `feather_mysql_retry_deadlocks true` to enable bounded retries for deadlocks and lock-wait timeouts. It is off by default. Transactions retry only after rollback is confirmed, using a fresh connection lease and `BEGIN`. A provider stop cancels pending retries.
- A retry runs the **whole callback again**. Use this option only when callbacks have no side effects outside `tx.*`, such as events or changes to shared Lua tables. The same switch also retries standalone statements. `feather_mysql_retry_deadlocks_max` (default `3`, range `0–20`) counts retries after the first attempt.

### Declarative batches

For several independent statements that must all succeed or all roll back together, where no statement's result feeds into another, `DB.batchTransaction` avoids writing a callback:

```lua
local results = DB.batchTransaction({
    DB.stmt('INSERT INTO accounts (owner, balance) VALUES (?, ?)', ownerId, 0),
    DB.stmt('UPDATE accounts SET balance = balance + ? WHERE owner = ?', amount, otherOwnerId),
})
```

- Build each statement with `DB.stmt(sql, ...)`, not a bare `{sql, ...}` table - a plain table constructor cannot reliably keep a `nil` parameter in the middle or at the end, `DB.stmt` can.
- All statements run atomically on the same connection, in order, inside one transaction; a `SELECT` later in the array sees the array's own earlier, not-yet-committed writes.
- Returns one result per statement, each shaped like `DB.raw`'s: rows for a statement that returns rows, otherwise `{ affectedRows, insertId, warningStatus }`.
- Any statement failing rolls back the whole batch and raises, the same as `DB.transaction`.
- If a later statement needs a value produced by an earlier one (such as an insert ID), use `DB.transaction` directly instead - a batch has no way to pass data between its statements.

## Errors

Failures are raised as a table, so use `pcall`. Printing the table gives a readable report with the place in your code. An error you do not catch is shown by the server only as `error object is not a string`, with no reason and no place, so wrap `DB.*` calls in `pcall` wherever a failure is possible.

```lua
local ok, err = pcall(DB.insert, 'INSERT INTO names (identifier, name) VALUES (?, ?)', identifier, name)
if not ok then
    if err.driverCode == 'ER_DUP_ENTRY' then print('name already taken')
    else print(err) end
end
```

Fields: `code`, `message`, `resource`, `method`, `queryId`, `driverCode`, `sqlState`, `outcome`, `traceback`. Where available, `rollbackConfirmed` records an acknowledged rollback and `rollbackError` describes a failure during rollback.

`outcome` tells you what to assume about the database:

| `outcome` | Meaning |
| --- | --- |
| `not_executed` | Never sent (queue full, provider unavailable, bad argument). Safe to retry later. |
| `failed` | The database rejected the statement. Nothing was applied by it. |
| `rolled_back` | A transaction was abandoned and will not commit. |
| `executed` | It ran, but the result did not match the function you used. |
| `unknown` | Timeout, disconnect or stop. It may or may not have been applied: do not blindly retry a write. |

Codes: `INVALID_ARGUMENT`, `INVALID_CONTEXT`, `INVALID_CALLER`, `UNAVAILABLE`, `CONFIG_ERROR`, `DATABASE_ERROR`, `RESULT_TYPE`, `QUERY_TIMEOUT`, `POOL_EXHAUSTED`, `RESOURCE_STOPPED`, `BRIDGE_ERROR`, `WATCHDOG_TIMEOUT`, and for transactions `TRANSACTION_TIMEOUT`, `TRANSACTION_CLOSED`, `TRANSACTION_OWNER`, `TRANSACTION_BUSY`, `TRANSACTION_LIMIT`, `NESTED_TRANSACTION`, `LUA_ERROR`.

## Configuration

`mysql_connection_string` takes a URL, or `key=value` pairs separated by `;`:

```cfg
set mysql_connection_string "host=127.0.0.1;port=3306;user=app;password=secret;database=game;charset=utf8mb4;connectionLimit=10;queueLimit=512"
```

Keys: `host`, `port`, `user`, `password`, `database`, `charset`, `connectionLimit` (default 10), `queueLimit` (default 512), `connectTimeout` (ms, default 10000), `ssl` (`true` verifies the server certificate). `user` and `database` are required. Unknown keys are rejected, and errors never print the connection string.

Optional convars are read at startup. Lua transaction retry settings and Lua development warnings are also read live:

| Convar | Default | Meaning |
| --- | --- | --- |
| `feather_mysql_query_timeout_ms` | `30000` | Deadline for one query, queue wait included |
| `feather_mysql_transaction_timeout_ms` | `10000` | Deadline for a transaction's work; COMMIT/ROLLBACK get their own window |
| `feather_mysql_cleanup_timeout_ms` | `5000` | Deadline for resetting a connection after use |
| `feather_mysql_max_transactions_per_resource` | half the pool | Open transactions one resource may hold; `0` removes the limit |
| `feather_mysql_retry_deadlocks` | `false` | `true` automatically retries a standalone statement, or a whole `DB.transaction` callback, once the database reports a deadlock or a lock-wait timeout |
| `feather_mysql_retry_deadlocks_max` | `3` | Retries on top of the first attempt, when the above is on. Bounded to 0-20 |
| `feather_mysql_devmode` | `false` | `true` turns on every log below by default (queries, transactions, SQL text) and reports each misused call every time. An explicit setting of any of them still wins. Leave it off in production |
| `feather_mysql_slow_query_ms` | `200` | Log individual requests at or above this; `0` disables slow-request logging |
| `feather_mysql_slow_transaction_ms` | `1000` | Log completed transactions at or above this, including all statements and Lua callback time; `0` disables slow-transaction logging. Errors still log |
| `feather_mysql_log_queries` | `false` | Log every request (metadata only) |
| `feather_mysql_log_transactions` | `false` | Log every transaction event |
| `feather_mysql_log_sql` | `false` | Include the SQL text in logs |
| `feather_mysql_max_error_logs_per_second` | `20` | Cap on error log lines, so an outage cannot flood the console; `0` removes the cap |
| `feather_mysql_error_detail` | `false` | Add the database's own message to errors as `detail` (it can contain values) |

Bound parameters and connection strings are not logged by default. SQL logging exposes literals written into SQL text; `feather_mysql_error_detail` can expose values in database error messages. Keep these options off in production.

## Public service contract

Importing `@feather-mysql/lib/DB.lua` is the only supported way to use this resource. `ExecuteV1`, `ReadyV1`, `BeginTransactionV1`, `TransactionQueryV1` and `FinishTransactionV1` are reachable through `exports['feather-mysql']`, but they are the internal protocol `lib/DB.lua` uses to talk to this resource, not a stable API: call `DB.*` instead of calling those directly.

## Diagnostics

- **Console command** `feather_mysql_diagnostics` prints pool, queue, transaction and counter state as JSON, including:
  - `health`: `starting` (never reached the database yet), `connected`, `degraded` (reachable, but a
    meaningful share of recent requests have failed), or `unavailable` (was reachable, isn't now).
  - `latencies`: `acquireMs`/`executeMs`/`cleanupMs`, each as `{ count, p50, p95, p99 }` over a rolling
    window of recent calls — acquiring a connection, running the statement on the server, and the
    session reset after answering, measured separately.
- **Slow queries** and every error are logged with the calling resource, method, duration, `driverCode`, `sqlState` and `outcome`.

## Tests

```sh
npm run verify
```

This runs the Node tests, the Lua tests (Lua 5.4 library required; `python3 tests/run_lua.py`), and a suite against a private throwaway MariaDB that it starts and stops itself. That last part needs `mariadbd` and `mariadb-install-db` installed, and a short temporary directory path (Unix socket paths are limited to 107 characters). It never touches your real database.

The companion `feather-mysql-test` resource adds console checks that run on a real server and database: `feather_mysql_test` and `feather_mysql_test_transactions`. Use a test database.

`npm run bench` uses the same private-MariaDB setup to measure driver latency and throughput alongside a minimal mysql2 text-query baseline. The baseline skips session resets and is not feature-equivalent. Measurements exclude Cfx/Lua transport overhead and do not establish a production performance ranking.

## Limits

- One statement per call. Multi-statement SQL and stored procedures that return several result sets are not supported. Results are held in memory, not streamed.
- A statement the server cannot prepare with a placeholder (for example `SHOW COLUMNS ... LIKE ?`) is retried once as text, with the values escaped by the driver. The retry is refused for `??` placeholders, mismatched value counts, multibyte connection character sets and servers using `NO_BACKSLASH_ESCAPES`.
- Binary values cannot be sent as parameters; binary results arrive as arrays of bytes.
- Automated integration coverage uses MariaDB. Live Cfx startup/restart behavior, FiveM, MySQL 8 and TLS require deployment validation.
- Transaction rollback guarantees require transactional tables such as InnoDB. Avoid DDL and other implicit-commit statements inside callbacks.
- Cancellation is not immediate server cancellation. A timed-out write or COMMIT may have an unknown outcome; do not blindly retry it.
- Caching and a public prepared-statement API are not included.

## License

GPL v3. See [LICENSE](LICENSE).


### Read-only CFX scheduling comparison

Server console: `feather_mysql_bridge_probe` (no arguments). Runs three samples
per fixed mode: inline synchronous export callback, setImmediate, promise
then setImmediate, tick queue, and promise then tick queue. Reports Lua round-trip
and JS-local promise/queue durations.
It does not issue SQL or change normal database response delivery. Player callers,
extra arguments and overlapping commands are refused; samples time out after five
seconds. Inline is a diagnostic only, not a replacement for safe delivery after I/O.

See the authoritative [latency investigation](../feather-framework-docs/feather-mysql/FEATHER_MYSQL_LATENCY_INVESTIGATION.md).
Controlled live probe: inline 0 ms, setImmediate median 61 ms, promise-plus-setImmediate median 64 ms (promise stage 0 ms). This is diagnostic evidence, not a production scheduling fix. Deploy existing bridge/index.js
and server/main.lua together and use a full server restart for this shared resource;
no consumer DB.lua or manifest change is required.

The tick comparison is diagnostic-only: at most 16 pending completions, eight per
tick, snapshot batches, no ticker while idle, and queued work discarded on stop.
Normal query response scheduling remains unchanged. Live tick comparison showed no convincing repeatable gain (tick median 65 ms;
existing immediate path 57 ms in that run). Asynchronous-I/O completion-context
acceptance remains pending; synchronous inline
success does not establish safety for database I/O callbacks.


### Independent statements inside a transaction: tx.batch

`tx.batch({ DB.stmt(sql, ...), ... })` runs 1�32 already-known independent
statements on the existing transaction connection in one Lua/JS bridge call.
It returns one `DB.raw`-shaped result per statement. Inspect those results in the
callback and return true to commit, or false to roll back. Statements inside a
batch cannot depend on an earlier result; use normal tx methods for that case.

```
DB.transaction(function(tx)
    local results = tx.batch({
        DB.stmt('SELECT event_id FROM example_events WHERE horse_id=?', horseId),
        DB.stmt('SELECT generation_id FROM example_slots WHERE character_id=?', characterId)
    })
    -- Validate both results before deciding whether this transaction may commit.
    return validateResults(results)
end)
```

Every statement is validated before execution. Inputs are dense DB.stmt arrays,
limited to 32 statements, 128 KiB SQL and 1024 total parameters. SQL NULL, false
and raw result shapes retain existing semantics. A failed statement stops the
batch and taints/rolls back the enclosing transaction even if caught in Lua.
Ownership, deadline, stop, rollback confirmation and outer retry rules remain.
A batch reserves the connection against interleaving queries/finish operations.
Existing DB.batchTransaction remains its Lua convenience loop and is unchanged.

This additive API requires lib/DB.lua, server/validation.lua, server/main.lua,
bridge/index.js and bridge/driver.js together. Consumer libraries reload on a
full server restart. Controlled live read batching passed: three separate transaction queries totaled
314 ms versus 196 ms with tx.batch in one paired sample. Broader failure/write/
concurrency and latency-distribution acceptance remain pending.
