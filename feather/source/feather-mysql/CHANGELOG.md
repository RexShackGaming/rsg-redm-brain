# Changelog

## 0.3.1-alpha.1 — Recovery regression tooling

- Add isolated COMMIT reply-loss and uncommitted worker-termination tests.
- Add wire-proxy coverage, safe diagnostics and Windows recovery instructions.
- Keep runtime provider behavior and dependencies unchanged.

## 0.1.0 — Initial release

- Standalone FiveM/RedM database resource with a Lua API and a pinned mysql2 transport.
- Positional `DB.query`, `DB.one`, `DB.value`, `DB.insert`, `DB.exec` and `DB.raw` calls.
- Callback transactions with explicit commit, automatic rollback on failure, and one connection for all `tx.*` calls.
- Bounded connection pooling, request deadlines, session reset before reuse and best-effort cancellation.
- Structured errors with database outcomes and rollback confirmation; optional bounded retries for deadlocks and lock-wait timeouts.
- Database readiness checks, health monitoring, configurable logging and console diagnostics.
- Usage examples, Node and Lua tests, isolated MariaDB integration tests and a local benchmark.
