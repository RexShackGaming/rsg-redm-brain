# Using feather-mysql from another resource

You use this database layer by importing one Lua file into your resource. You do not call the provider's exports yourself: `lib/DB.lua` does that for you, and adds argument handling, waiting, error formatting and a watchdog. The exports the provider registers (`ExecuteV1` and friends) are an internal protocol, not a public API.

Reference material (all convars, every error code, architecture) is in the [README](../README.md). This page is about *writing code*.

## 1. Add it to your resource

`fxmanifest.lua` of **your** resource:

```lua
fx_version 'cerulean'
game 'rdr3'   -- or 'gta5'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

dependency 'feather-mysql'

server_scripts {
    '@feather-mysql/lib/DB.lua',   -- defines the global DB, once per resource
    'server.lua',
}
```

Rules:

- `DB.lua` is **server-only**. Do not list it under `client_scripts` or `shared_scripts`.
- Load it once per resource. It defines the global `DB` and raises an error if `DB` already exists.
- `dependency` makes the provider start first. In `server.cfg`, `ensure feather-mysql` must come before your resource.

## 2. Where you may call it

Queries, transactions and `DB.awaitReady` wait by yielding the current coroutine; `DB.isReady()` is a synchronous readiness check. Event handlers, `RegisterCommand` handlers, `CreateThread` bodies and your own exported functions all run as coroutines in Cfx, so they work. Code at the top level of a script file does not:

```lua
-- WRONG: top level of the file, not yieldable. Raises INVALID_CONTEXT.
local row = DB.one('SELECT 1')

-- RIGHT
CreateThread(function()
    local row = DB.one('SELECT 1')
end)

AddEventHandler('onResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end
    DB.exec([[
        CREATE TABLE IF NOT EXISTS example_accounts (
            identifier VARCHAR(64) NOT NULL PRIMARY KEY,
            balance    BIGINT      NOT NULL DEFAULT 0
        ) ENGINE=InnoDB
    ]])
end)
```

## 3. The five query functions

Pass values as separate arguments after the SQL. Never build SQL by concatenating values.

```lua
CreateThread(function()
    -- DB.query: all rows (an empty table when there are none)
    local items = DB.query('SELECT id, name FROM items WHERE owner = ?', identifier)
    for _, item in ipairs(items) do print(item.id, item.name) end

    -- DB.one: the first row, or nil
    local account = DB.one('SELECT identifier, balance FROM example_accounts WHERE identifier = ?', identifier)
    if account then print(account.balance) end

    -- DB.value: first column of the first row, or nil (no row, or SQL NULL)
    local count = DB.value('SELECT COUNT(*) FROM items WHERE owner = ?', identifier)   -- a number
    if count == 0 then print('no items') end

    -- DB.insert: the generated id (0 if the table has none)
    local id = DB.insert('INSERT INTO items (owner, name) VALUES (?, ?)', identifier, "O'Brien's hat")

    -- DB.exec: number of matched/affected rows (0 is a valid success)
    local changed = DB.exec('UPDATE items SET name = ? WHERE id = ?', 'Renamed', id)
end)
```

| Function | Returns | Use for |
| --- | --- | --- |
| `DB.query` | array of rows | `SELECT` returning several rows |
| `DB.one` | row or `nil` | `SELECT` by key |
| `DB.value` | value or `nil` | `COUNT`, `SUM`, one column |
| `DB.insert` | insert id | `INSERT` |
| `DB.exec` | affected rows | `UPDATE`, `DELETE`, DDL |

Use the function that matches the statement. `DB.query('UPDATE ...')` **runs the update** and then raises `RESULT_TYPE`.

### Parameters

```lua
DB.exec('UPDATE characters SET job = ?, grade = ? WHERE id = ?', nil, 0, charId)   -- nil binds NULL
DB.one('SELECT ? AS flag', false)      -- false, 0 and '' are real values, not NULL
DB.value('SELECT 42')                  -- no placeholders, no arguments
```

- Integers must lie within ±(2^53−1). Pass bigger ids as decimal strings.
- Tables and functions are rejected. NaN and infinity are rejected.
- `IN (...)` lists are not expanded for you. Build the placeholders yourself (they are the only thing you may format into the SQL):

```lua
local function inList(sqlStart, ids)
    if #ids == 0 then return {} end
    local marks = string.rep('?', #ids, ', ')
    return DB.query(('%s (%s)'):format(sqlStart, marks), table.unpack(ids, 1, #ids))
end

CreateThread(function()
    local rows = inList('SELECT id, name FROM items WHERE id IN', { 3, 7, 9 })
end)
```

- A call such as `DB.query(sql, text:gsub('a', 'b'))` passes **two** values (`gsub` returns a count too). Wrap it: `DB.query(sql, (text:gsub('a', 'b')))`.

### What comes back

| SQL | Lua |
| --- | --- |
| `INT`, `BIGINT` within ±(2^53−1), `COUNT(*)` | number |
| `BIGINT` outside that range | string (exact) |
| `DECIMAL`, and `SUM()` of integers | string (exact, never rounded) |
| `FLOAT`, `DOUBLE` | number |
| dates, times, JSON | string |
| `NULL` | `nil` (the key is absent in a row) |

Compare money as `BIGINT` cents. If you use `DECIMAL`, convert deliberately with `tonumber()` and remember it is a string until you do.

## 4. Handling errors

Failures are raised as a table, so use `pcall`. Printing the table gives readable text with the call site.

```lua
CreateThread(function()
    local ok, result = pcall(DB.one, 'SELECT * FROM characters WHERE id = ?', charId)
    if not ok then
        print(result)   -- readable: code, message, resource, sqlState, outcome, traceback
        return
    end
    -- result is the row or nil
end)
```

Decide what to do from `err.outcome`:

| `err.outcome` | Meaning | What to do |
| --- | --- | --- |
| `not_executed` | Never sent (queue full, provider unavailable, bad argument) | Safe to retry later, or report |
| `failed` | The database rejected the statement (constraint, syntax, deadlock) | Fix the input or handle the constraint; inside a transaction it was rolled back |
| `rolled_back` | A transaction was abandoned | Nothing was applied |
| `executed` | It ran, but the result shape did not match the function you used | Use the right function; do not retry |
| `unknown` | Timeout, disconnect, or the provider stopped | It may or may not have been applied. Do **not** blindly retry a write; use an idempotency key (section 6) |

Useful fields: `err.code` (for example `POOL_EXHAUSTED`, `QUERY_TIMEOUT`), `err.driverCode` (for example `ER_DUP_ENTRY`), `err.sqlState`.

A common, useful pattern is handling a duplicate key on purpose:

```lua
local ok, err = pcall(DB.insert, 'INSERT INTO names (identifier, name) VALUES (?, ?)', identifier, name)
if not ok then
    if type(err) == 'table' and err.driverCode == 'ER_DUP_ENTRY' then
        print('name already taken')
    else
        error(err, 0)   -- anything else is a real problem: rethrow
    end
end
```

## 5. Player events

Capture `source` before the first database call, because `source` changes when the coroutine yields. Never trust values sent by the client for *who* is acting; derive identity on the server.

```lua
RegisterNetEvent('example:requestBalance', function()
    local src = source                                    -- capture first
    local identifier = GetPlayerIdentifierByType(src, 'license')
    if not identifier then return end

    local balance = DB.value('SELECT balance FROM example_accounts WHERE identifier = ?', identifier)
    TriggerClientEvent('example:balance', src, balance or 0)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = GetPlayerIdentifierByType(src, 'license')
    -- save whatever your resource keeps in memory for this player
    if identifier then
        local ok, err = pcall(DB.exec, 'UPDATE characters SET last_seen = NOW() WHERE identifier = ?', identifier)
        if not ok then print(err) end
    end
end)
```

A burst of these is fine: requests beyond the pool size wait in a queue instead of failing.

## 6. Transactions: several statements that succeed or fail together

Use `DB.transaction` when a change spans several statements (money, inventory, anything where half an update is a bug). Use `tx.*` inside; it has the same five functions.

```lua
-- Move `amount` from one account to another, exactly once per `key`.
local function transfer(fromId, toId, amount, key)
    if math.type(amount) ~= 'integer' or amount <= 0 then return false, 'invalid_amount' end
    local reason

    local ok, committed = pcall(DB.transaction, function(tx)
        reason = nil                                             -- the callback may run again after a deadlock
        -- A repeated `key` violates the UNIQUE index, which aborts the transaction before money moves.
        tx.insert('INSERT INTO example_transfers (idempotency_key, from_identifier, to_identifier, amount) VALUES (?, ?, ?, ?)',
            key, fromId, toId, amount)

        -- Lock both rows, always in the same order, so two transfers cannot deadlock each other.
        tx.query('SELECT identifier FROM example_accounts WHERE identifier IN (?, ?) ORDER BY identifier FOR UPDATE', fromId, toId)

        local balance = tx.value('SELECT balance FROM example_accounts WHERE identifier = ?', fromId)
        if not balance or balance < amount then reason = 'insufficient_funds'; return false end

        tx.exec('UPDATE example_accounts SET balance = balance - ? WHERE identifier = ?', amount, fromId)
        if tx.exec('UPDATE example_accounts SET balance = balance + ? WHERE identifier = ?', amount, toId) ~= 1 then
            reason = 'unknown_recipient'; return false           -- rolls back the debit too
        end
        return true                                              -- commit
    end)

    if not ok then
        local err = committed
        if type(err) == 'table' and err.driverCode == 'ER_DUP_ENTRY' then return true, 'already_done' end
        return false, err
    end
    return committed, reason
end
```

The schema for this example:

```sql
CREATE TABLE IF NOT EXISTS example_accounts (
    identifier VARCHAR(64) NOT NULL PRIMARY KEY,
    balance    BIGINT      NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS example_transfers (
    id               BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    idempotency_key  VARCHAR(64) NOT NULL UNIQUE,
    from_identifier  VARCHAR(64) NOT NULL,
    to_identifier    VARCHAR(64) NOT NULL,
    amount           BIGINT      NOT NULL,
    created_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
```

How the result works:

- `return true` commits and `DB.transaction` returns `true`.
- `return false` **or returning nothing** rolls back and returns `false`. Forgetting `return true` silently rolls back, so check the return value.
- Any error inside `tx.*` (SQL error, duplicate key, timeout) rolls back and raises. Catching it inside the callback does not save the transaction: it can no longer commit.
- An error thrown by your own Lua code inside the callback also rolls back and raises `LUA_ERROR`.

Rules of thumb:

- Use `tx.*`, not `DB.*`, inside the callback. A `DB.*` call runs on a **different** connection, is not rolled back, and can wait on locks your transaction holds. The library prints a warning if you do it.
- Keep transactions short. Each holds a database connection while your Lua runs, and a resource may hold only a few at once (by default half the pool). Do not `Wait()`, call other resources, or do slow work inside the callback.
- Do not nest `DB.transaction` in the same coroutine.
- Do not run `START TRANSACTION`, `COMMIT`, `SET autocommit`, `USE` or DDL yourself inside a transaction.

### Retrying after a deadlock

A deadlock aborts the whole transaction, so running it again is safe. Retry only for that, and only around the transaction itself:

```lua
local function inTransaction(attempts, callback)
    for attempt = 1, attempts do
        local ok, result = pcall(DB.transaction, callback)
        if ok then return true, result end
        local retryable = type(result) == 'table'
            and (result.driverCode == 'ER_LOCK_DEADLOCK' or result.driverCode == 'ER_LOCK_WAIT_TIMEOUT')
        if not retryable or attempt == attempts then return false, result end
        Wait(50 * attempt)
    end
end
```

In `transfer`, replace `pcall(DB.transaction, function(tx) ... end)` with `inTransaction(3, function(tx) ... end)`. The callback must not depend on state left over from an earlier attempt, which is why it starts with `reason = nil`.

### When the outcome is unknown

If `err.outcome == 'unknown'` (for example a timeout while committing), the transfer may or may not have happened. Because `transfer` uses an idempotency key, you can safely run it again with the **same key**: a second run returns `true, 'already_done'` if the first one went through, and performs the transfer if it did not.

## 7. Exposing your own API to other resources

Other resources should call **your** resource, not the database. Keep the SQL inside your resource and export domain functions. In Cfx, exported functions run as coroutines, so they may call `DB.*` (if you ever see `INVALID_CONTEXT` inside one, run the body in `CreateThread` and return the result through a callback):

```lua
-- your resource: server.lua
exports('GetBalance', function(identifier)
    if type(identifier) ~= 'string' then return nil end
    return DB.value('SELECT balance FROM example_accounts WHERE identifier = ?', identifier) or 0
end)

exports('Transfer', function(fromId, toId, amount, key)
    local done, reason = transfer(fromId, toId, amount, key)     -- from section 6
    return done, type(reason) == 'table' and reason.code or reason
end)
```

```lua
-- another resource
CreateThread(function()
    local balance = exports['example-bank']:GetBalance('license:aaa')
    local done, reason = exports['example-bank']:Transfer('license:aaa', 'license:bbb', 500, 'order-1234')
end)
```

Return plain values and short reason strings across resources rather than raw error tables, and validate every argument: an export can be called by any server resource.

## 8. Common mistakes

| Mistake | What happens | Fix |
| --- | --- | --- |
| Calling `DB.*` at the top level of a file | `INVALID_CONTEXT` | Move it into `CreateThread` or an event handler |
| Concatenating values into SQL | SQL injection | Use `?` placeholders |
| Using `DB.query` for `UPDATE` | The update runs, then `RESULT_TYPE` is raised | Use `DB.exec` |
| Forgetting `return true` in a transaction | Silent rollback | Return `true`, and check the result |
| `DB.*` inside `DB.transaction` | Runs outside the transaction, warning printed | Use `tx.*` |
| Retrying a write after `outcome == 'unknown'` | Possible double application | Use an idempotency key |
| Using `#values` when a value may be `nil` | Wrong argument count | Pass `table.unpack(values, 1, count)` |
| Reading `source` after the first `DB` call | Wrong player | `local src = source` first |
| Not catching errors in a player event | The event's coroutine dies with a table error | `pcall` and log |

## 9. Checking that it works

- On start the provider prints `Bridge self-check OK.` If it prints `FAILED`, database calls will not work and the message says why.
- `feather_mysql_diagnostics` (server console) prints pool, queue, transaction and counter state.
- The optional companion resource `feather-mysql-test` exercises the API against your configured database; use a dedicated test database: `ensure feather-mysql-test`, then `feather_mysql_test`.
