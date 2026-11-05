# feather-mysql

Version 0.3.1. Standalone Lua database API with a minimal mysql2 transport

A standalone MySQL/MariaDB resource for FiveM and RedM. Use plain Lua `DB.*` calls backed by a pooled mysql2 transport. local user = DB.one('SELECT * FROM users WHERE identifier = ?', identifier) - **Five small functions** (`query`, `one`, `value`, `insert`, `exec`) and real **transactions**.

Source: https://github.com/FeatherFramework/feather-mysql

**Dependencies:** `feather-mysql`

## Exports (call as exports['feather-mysql']:Name)

**server:** `BeginTransactionV1(callback)`, `ExecuteV1(method, sql, parameters, callback)`, `FinishTransactionV1(id, commit, callback)`, `ReadyV1(callback)`, `TransactionBatchV1(id, statements, callback)`, `TransactionQueryV1(id, method, sql, parameters, callback)`

## Public (table) functions

**lib/DB.lua:** `DB.query(sql, ...)`, `DB.one(sql, ...)`, `DB.value(sql, ...)`, `DB.insert(sql, ...)`, `DB.exec(sql, ...)`, `DB.raw(sql, ...)`, `DB.isReady()`, `DB.awaitReady(timeoutMs)`, `DB.transaction(callback)`, `tx.query(sql, ...)`, `tx.one(sql, ...)`, `tx.value(sql, ...)`, `tx.insert(sql, ...)`, `tx.exec(sql, ...)`, `tx.raw(sql, ...)`, `tx.batch(statements)`, `DB.stmt(sql, ...)`, `DB.batchTransaction(statements)`

**server/errors.lua:** `FeatherMySQL.error(code, message, resource, method, id, driverCode, extra)`

**server/logger.lua:** `FeatherMySQL.log(context, elapsed, err)`

**server/main.lua:** `FeatherMySQL.execute(method, sql, parameters, callback)`, `FeatherMySQL.ready(callback)`

**server/results.lua:** `FeatherMySQL.result(method, payload)`

**server/validation.lua:** `FeatherMySQL.validate(method, sql, parameters)`, `FeatherMySQL.validateBatch(statements)`
