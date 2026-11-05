-- Migrations: first run, rerun, checksum drift, ledger contents, plan tables.
return function(t)
    local J = Justice
    local ledger = J.MigrationLedger()
    local expected = J.ExpectedMigrations()
    t.check('seven plan migrations ledgered', #expected == 7 and ledger ~= nil)
    for _, migration in ipairs(expected) do
        t.check(migration.id .. ' checksum matches the database digest', ledger[migration.id] == migration.checksum)
    end
    local present = J.SchemaTables()
    for _, name in ipairs(J.Tables) do t.check('table ' .. name .. ' exists', present[name] == true) end
    t.check('migration rerun is a no-op', pcall(J.Migrate))
    t.sql.exec("UPDATE justice_schema_migrations SET checksum=REPEAT('0',64) WHERE migration_id='003_charges_warrants'")
    local ok, err = pcall(J.Migrate)
    t.check('checksum drift stops startup', not ok and tostring(err):find('migration_checksum_mismatch', 1, true) ~= nil, err)
    t.sql.exec('UPDATE justice_schema_migrations SET checksum=? WHERE migration_id=?', expected[3].checksum, '003_charges_warrants')
    t.check('ledger restored', pcall(J.Migrate))
    -- Smoke test command logic (read-only) passes on a correct schema.
    local report = J.MigrationSmoke()
    t.check('JusticeMigrationSmokeTest passes', report.failed == 0, report.failed)
    -- Development layout tables are retired only when empty.
    t.sql.exec('CREATE TABLE feather_justice_records (record_id CHAR(36) PRIMARY KEY)')
    t.sql.exec("INSERT INTO feather_justice_records VALUES ('x')")
    local blocked = pcall(J.Migrate)
    t.check('non-empty development schema is never dropped', not blocked and t.sql.value('SELECT COUNT(*) FROM feather_justice_records') == 1)
    t.sql.exec('DELETE FROM feather_justice_records')
    t.check('empty development schema retired', pcall(J.Migrate) and J.SchemaTables().feather_justice_records == nil)
    -- A migration that fails part-way leaves no ledger row; the rerun completes it.
    t.sql.exec('DROP TABLE justice_workflows')
    t.sql.exec("DELETE FROM justice_schema_migrations WHERE migration_id='007_operations'")
    t.fault.match = 'CREATE TABLE IF NOT EXISTS justice_workflows'
    t.check('partial DDL failure reported', not pcall(J.Migrate))
    t.check('partial DDL leaves no ledger row', J.MigrationLedger()['007_operations'] == nil)
    t.check('rerun completes the migration', pcall(J.Migrate) and J.MigrationLedger()['007_operations'] == expected[7].checksum
        and J.SchemaTables().justice_workflows == true)
    -- Core restart: Justice degrades, then recovers and re-declares its events.
    local before = t.declarations()
    t.handlers.onResourceStop('feather-core')
    t.check('Core stop degrades Justice', J.Health().value.state == 'degraded')
    t.advance(6000)
    t.handlers.onResourceStart('feather-core')
    t.check('Core restart recovers readiness', J.Ready())
    t.check('events re-declared after Core restart', t.declarations() - before == #J.Facts, t.declarations() - before)
    local capabilities = J.Capabilities().value
    t.check('capability document follows the plan', capabilities.contract == 'feather.justice' and capabilities.version == 1
        and capabilities.features.rulings == 1 and capabilities.features.evidenceLinks == 1 and capabilities.features.restrictions == 0)
end
