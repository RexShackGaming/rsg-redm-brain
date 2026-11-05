---
title: Feather MySQL
---

# Feather MySQL

Feather MySQL is Feather Framework's native server-side database layer for FiveM and RedM. It provides a small Lua API backed by a pooled MySQL/MariaDB transport with parameter binding, structured errors, transactions, timeouts, diagnostics, and resource attribution.

## Installation

Start Feather MySQL before resources that use it:

```cfg
set mysql_connection_string "mysql://user:password@127.0.0.1:3306/database?charset=utf8mb4"

ensure feather-mysql
ensure feather-core
```

Install the database library in the consuming resource:

```lua
dependency 'feather-mysql'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'server.lua',
}
```

`DB.lua` is server-only and defines the global `DB` API for that resource.

Database calls yield the current coroutine and should be made from a `CreateThread`, event handler, command handler, or another yieldable server context.

## Query API

```lua
DB.query(sql, ...)  -> rows
DB.one(sql, ...)    -> row | nil
DB.value(sql, ...)  -> value | nil
DB.insert(sql, ...) -> insertId
DB.exec(sql, ...)   -> affectedRows
DB.raw(sql, ...)    -> rows | writeResult
```

Pass parameter values as separate arguments after the SQL:

```lua
local character = DB.one(
    'SELECT * FROM characters WHERE id = ?',
    characterId
)
```

Do not concatenate dynamic values into SQL.

### Query

Returns all rows. An empty table is returned when no rows match.

```lua
local characters = DB.query(
    'SELECT id, firstname, lastname FROM characters WHERE account_id = ?',
    accountId
)

for _, character in ipairs(characters) do
    print(character.firstname, character.lastname)
end
```

### One

Returns the first row or `nil`.

```lua
local character = DB.one(
    'SELECT * FROM characters WHERE id = ?',
    characterId
)

if character then
    print(character.firstname)
end
```

### Value

Returns the first column of the first row or `nil`.

```lua
local count = DB.value(
    'SELECT COUNT(*) FROM characters WHERE account_id = ?',
    accountId
)
```

### Insert

Returns the generated insert id.

```lua
local id = DB.insert(
    'INSERT INTO characters (account_id, firstname, lastname) VALUES (?, ?, ?)',
    accountId,
    'Arthur',
    'Morgan'
)
```

### Exec

Returns the number of affected rows.

```lua
local affected = DB.exec(
    'UPDATE characters SET money = ? WHERE id = ?',
    150,
    characterId
)
```

Use the function that matches the SQL operation. For example, using `DB.query` for an `UPDATE` executes the statement but raises `RESULT_TYPE` because the result does not match the requested query type.

### Raw

`DB.raw` is available for code that cannot know the statement type in advance.

```lua
local result = DB.raw(sql, ...)
```

It returns rows for statements that produce rows, or a write result containing fields such as `affectedRows` and `insertId`.

Prefer `query`, `one`, `value`, `insert`, or `exec` when the expected result type is known.

## Parameters

Values are bound separately from the SQL:

```lua
DB.exec(
    'UPDATE characters SET job = ?, grade = ? WHERE id = ?',
    nil,
    0,
    characterId
)
```

An explicit `nil` binds SQL `NULL`.

`false`, `0`, and `''` are ordinary values and are not converted to `NULL`.

Integers must be within JavaScript's safe integer range of ±(2^53−1). Larger integer identifiers should be passed as decimal strings.

## Result Types

| SQL value | Lua value |
| --- | --- |
| `INT` | `number` |
| safe `BIGINT` | `number` |
| large `BIGINT` | exact `string` |
| `DECIMAL` | exact `string` |
| `FLOAT`, `DOUBLE` | `number` |
| dates and times | `string` |
| JSON | `string` |
| `NULL` | `nil` |

Large integer and decimal values are returned without silently losing precision.

## Transactions

Use `DB.transaction` when several statements must succeed or fail together.

```lua
local committed = DB.transaction(function(tx)
    local balance = tx.value(
        'SELECT balance FROM accounts WHERE id = ? FOR UPDATE',
        fromId
    )

    if not balance or balance < amount then
        return false
    end

    tx.exec(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        amount,
        fromId
    )

    tx.exec(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        amount,
        toId
    )

    return true
end)
```

The transaction context exposes:

```lua
tx.query(sql, ...)
tx.one(sql, ...)
tx.value(sql, ...)
tx.insert(sql, ...)
tx.exec(sql, ...)
tx.raw(sql, ...)
```

Return `true` to commit.

Returning `false` or `nil` rolls the transaction back.

An error inside the transaction prevents commit and is raised after rollback is attempted.

Always use `tx.*` inside the callback. Calling `DB.*` inside a transaction uses another database connection and is not part of that transaction.

Nested `DB.transaction` calls in the same coroutine are not supported.

## Readiness

Check whether Feather MySQL has reached the database:

```lua
if DB.isReady() then
    print('Database ready')
end
```

Or wait for readiness:

```lua
local ready = DB.awaitReady(10000)

if not ready then
    print('Database was not ready within 10 seconds')
end
```

`DB.awaitReady(nil)` waits indefinitely.

## Errors

Database failures are raised as structured Lua tables.

Use `pcall` when a database operation can fail:

```lua
local ok, result = pcall(
    DB.one,
    'SELECT * FROM characters WHERE id = ?',
    characterId
)

if not ok then
    print(result)
    return
end
```

Useful error fields include:

```lua
err.code
err.message
err.resource
err.method
err.queryId
err.driverCode
err.sqlState
err.outcome
err.traceback
```

`outcome` describes what is known about the database operation:

| Outcome | Meaning |
| --- | --- |
| `not_executed` | The statement was never sent |
| `failed` | The database rejected the statement |
| `rolled_back` | The transaction was rolled back |
| `executed` | The statement ran but returned the wrong result type |
| `unknown` | The write may or may not have completed |

Do not blindly retry writes with an `unknown` outcome.

## Deadlock Retries

Automatic bounded retries for deadlocks and lock-wait timeouts can be enabled:

```cfg
set feather_mysql_retry_deadlocks true
set feather_mysql_retry_deadlocks_max 3
```

For transactions, the entire callback is executed again after rollback is confirmed.

Transaction callbacks using automatic retries should therefore avoid external side effects such as events or changes to shared Lua state.

## Development Logging

Useful development options include:

```cfg
set feather_mysql_devmode true
set feather_mysql_log_queries true
set feather_mysql_log_transactions true
set feather_mysql_log_sql true
set feather_mysql_slow_query_ms 200
```

Development mode enables query, transaction, and SQL logging by default unless individually overridden.

Keep SQL and detailed error logging disabled in production when they could expose sensitive values.

## Diagnostics

The server console command:

```text
feather_mysql_diagnostics
```

reports database health, pool state, queue state, active transactions, counters, and latency statistics.

Health is reported as:

- `starting`
- `connected`
- `degraded`
- `unavailable`

Latency statistics separate connection acquisition, query execution, and connection cleanup.

## Public API

The supported public API is provided by:

```lua
@feather-mysql/lib/DB.lua
```

and consists of:

```lua
DB.query()
DB.one()
DB.value()
DB.insert()
DB.exec()
DB.raw()

DB.isReady()
DB.awaitReady()

DB.transaction()
```

Exports such as `ExecuteV1`, `ReadyV1`, `BeginTransactionV1`, `TransactionQueryV1`, and `FinishTransactionV1` are the internal protocol used by `DB.lua` and are **not** part of the stable public API.

## Limits

- One SQL statement per call.
- Multi-statement SQL is not supported.
- Result sets are held in memory rather than streamed.
- Binary parameters are not supported.
- Transaction guarantees require transactional tables such as InnoDB.
- Avoid DDL and other implicit-commit statements inside transactions.
- A timed-out write or commit can have an unknown outcome and must not be blindly retried.